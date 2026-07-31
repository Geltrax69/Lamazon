#!/usr/bin/env bash
# Runs the whole stack: Postgres, the Go API, then the Flutter web app pointed
# at it. Quitting Flutter (q, or Ctrl-C) stops the API too; Postgres is left
# running in Docker so the next start is instant.
#
# Usage: ./dev.sh            # Chrome
#        ./dev.sh macos      # any flutter device id
set -euo pipefail

DEVICE="${1:-chrome}"
PORT="${PORT:-8080}"
API="http://localhost:$PORT"
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
    docker run -d --name lamazon-pg \
      -e POSTGRES_USER=lamazon -e POSTGRES_PASSWORD=lamazon -e POSTGRES_DB=lamazon \
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

# The app talks to the API over HTTP, so prove that link works before opening
# a browser onto a backend that is still compiling or already dead.
echo "==> waiting for $API/api/health"
for _ in $(seq 60); do
  curl -sf "$API/api/health" >/dev/null && break
  kill -0 "$API_PID" 2>/dev/null || { echo "API exited, see the log above"; exit 1; }
  sleep 1
done
curl -sf "$API/api/health" >/dev/null || { echo "API never answered /api/health"; exit 1; }

products=$(curl -sf "$API/api/products" | grep -o '"id"' | wc -l | tr -d ' ')
echo "==> API healthy, catalog has $products products"

echo "==> flutter run -d $DEVICE"
cd frontend
# Not exec'd: the trap above has to survive Flutter so the API gets cleaned up.
flutter run -d "$DEVICE" --dart-define=API_BASE_URL="$API"
