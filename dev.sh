#!/usr/bin/env bash
# Runs the whole stack: Postgres, the Go API, then the Flutter web app pointed
# at it. Quitting Flutter (q, or Ctrl-C) stops the API too; Postgres is left
# running in Docker so the next start is instant.
#
# The app talks to the local API by default. Use PUBLIC=1 when you explicitly
# want to exercise the Cloudflare tunnel / deployed hostname.
#
# Usage: ./dev.sh              # Chrome, app talks to localhost
#        ./dev.sh macos        # any flutter device id
#        PUBLIC=1 ./dev.sh     # app talks to api.geltrax.engineer
set -euo pipefail

DEVICE="${1:-chrome}"
PORT="${PORT:-8080}"
LOCAL_API="http://localhost:$PORT"
PUBLIC_API="${PUBLIC_API:-https://api.geltrax.engineer}"
DB_URL="postgres://lamazon:lamazon@localhost:5433/lamazon?sslmode=disable"
cd "$(dirname "$0")"

# Cloudinary credentials live in .env, which is gitignored. Without it the API
# still runs; photo uploads answer 503.
if [ -f .env ]; then
  set -a; . ./.env; set +a
fi

# Postgres: reuse the container across runs, whatever state it is in.
if [ -z "$(docker ps -q -f name=^lamazon-pg$)" ]; then
  if [ -n "$(docker ps -aq -f name=^lamazon-pg$)" ]; then
    echo "==> starting existing lamazon-pg"
    docker start lamazon-pg >/dev/null
  else
    echo "==> creating lamazon-pg"
    # Named volume: without it the data lives in the container's own layer and
    # `docker rm lamazon-pg` takes every user, address and store with it.
    docker run -d --name lamazon-pg \
      -e POSTGRES_USER=lamazon -e POSTGRES_PASSWORD=lamazon -e POSTGRES_DB=lamazon \
      -v lamazon-pgdata:/var/lib/postgresql/data \
      -p 5433:5432 postgres:16-alpine >/dev/null
  fi
fi

echo "==> waiting for Postgres"
for _ in $(seq 30); do
  docker exec lamazon-pg pg_isready -U lamazon -q && break
  sleep 1
done
docker exec lamazon-pg pg_isready -U lamazon -q || { echo "Postgres never came up"; exit 1; }

# A leftover server on the port would answer the health check below and the app
# would silently talk to stale code. An earlier copy of this API is ours to
# replace; anything else is someone else's and gets left alone.
# `|| true` because lsof exits non-zero when it finds nothing, which under
# `set -e` would end the script right here — silently, since it prints nothing.
held=$(lsof -ti "tcp:$PORT" -sTCP:LISTEN 2>/dev/null | tr '\n' ' ' || true)
if [ -n "$held" ]; then
  for pid in $held; do
    case "$(ps -o command= -p "$pid" 2>/dev/null)" in
    *lamazon-api*)
      echo "==> replacing the API already on $PORT (pid $pid)"
      kill "$pid" 2>/dev/null
      ;;
    *)
      echo "Port $PORT is held by pid $pid: $(ps -o command= -p "$pid" 2>/dev/null)"
      echo "Stop it, or run PORT=8081 $0"
      exit 1
      ;;
    esac
  done
  # The port is not free the instant the process dies.
  for _ in $(seq 20); do
    lsof -ti "tcp:$PORT" -sTCP:LISTEN >/dev/null 2>&1 || break
    sleep 0.25
  done
fi

# Built rather than `go run`, so the pid we background is the server itself and
# killing it actually frees the port — go run leaves its child behind.
echo "==> building API"
BIN=$(mktemp -t lamazon-api)
go build -C backend -o "$BIN" .

echo "==> starting API on $PORT"
DATABASE_URL="$DB_URL" PORT="$PORT" "$BIN" &
API_PID=$!
# INT and TERM as well as EXIT: Ctrl-C is how this normally ends, and bash does
# not always reach the EXIT trap on an untrapped signal.
trap 'kill "$API_PID" 2>/dev/null; rm -f "$BIN"; exit' EXIT INT TERM

# Prove the API answers before opening a browser onto something that is still
# compiling or already dead.
echo "==> waiting for $LOCAL_API/api/health"
for _ in $(seq 60); do
  curl -sf "$LOCAL_API/api/health" >/dev/null && break
  kill -0 "$API_PID" 2>/dev/null || { echo "API exited, see the log above"; exit 1; }
  sleep 1
done
curl -sf "$LOCAL_API/api/health" >/dev/null || { echo "API never answered /api/health"; exit 1; }

# Then decide what the app should call. Localhost avoids Cloudflare-generated
# 502 pages that do not carry CORS headers and look like browser CORS bugs.
API="$LOCAL_API"
if [ -n "${PUBLIC:-}" ]; then
  if curl -sf -m 10 "$PUBLIC_API/api/health" >/dev/null 2>&1; then
    API="$PUBLIC_API"
    echo "==> PUBLIC=1, tunnel up: the app will call $PUBLIC_API"
  else
    echo "!! PUBLIC=1 requested, but $PUBLIC_API is not answering."
    echo "   Check it with ./tunnel.sh status."
    exit 1
  fi
else
  echo "==> local dev: the app will call $LOCAL_API"
fi

products=$(curl -sf "$API/api/products" | grep -o '"id"' | wc -l | tr -d ' ')
echo "==> API healthy, catalog has $products products"

cat > frontend/web/firebase-env.js <<EOF
globalThis.lamazonFirebaseConfig = {
  apiKey: "${FIREBASE_API_KEY:-}",
  authDomain: "${FIREBASE_AUTH_DOMAIN:-}",
  projectId: "${FIREBASE_PROJECT_ID:-}",
  storageBucket: "${FIREBASE_STORAGE_BUCKET:-}",
  messagingSenderId: "${FIREBASE_MESSAGING_SENDER_ID:-}",
  appId: "${FIREBASE_APP_ID:-}",
};
EOF

echo "==> flutter run -d $DEVICE"
cd frontend
# Not exec'd: the trap above has to survive Flutter so the API gets cleaned up.
flutter run -d "$DEVICE" --dart-define=API_BASE_URL="$API"
