#!/usr/bin/env bash
# Builds the API for the Hetzner box and restarts it there.
#
# Usage: ./deploy.sh
#
# The server has no Go toolchain and does not need the source: schema.sql is
# go:embed'ed into the binary, and the web app is deployed by Vercel. So this
# ships one file. Nothing on the server is built or pulled.
set -euo pipefail
cd "$(dirname "$0")"

HOST="${HOST:-root@46.62.157.163}"
BIN="${BIN:-/var/www/Lamazon/bin/lamazon-api}"
SVC="${SVC:-lamazon-api}"
HEALTH="${HEALTH:-https://api.geltrax.engineer/api/health}"

# Deploying code that only exists on this laptop is how the server ends up on a
# commit nobody can find again — the binary is built from the working tree, so a
# dirty tree means the running API matches no commit.
[ -z "$(git status --porcelain backend)" ] || { echo "backend has uncommitted changes — commit them first"; exit 1; }
git push

echo "==> building for linux/amd64"
OUT=$(mktemp -t lamazon-api)
trap 'rm -f "$OUT"' EXIT
GOOS=linux GOARCH=amd64 CGO_ENABLED=0 go build -C backend -o "$OUT" .

# Two steps, not one: scp straight onto the path would fail with "text file
# busy" while the old binary is running. A same-filesystem mv swaps it out
# atomically instead, and systemd picks it up on restart.
echo "==> shipping to $HOST"
scp -q "$OUT" "$HOST:$BIN.new"
ssh "$HOST" "mv $BIN.new $BIN && systemctl restart $SVC"

# Prove it. A crash-looping unit leaves nginx answering 502, and a restart that
# failed outright leaves the *old* binary serving — which from here looks
# exactly like a successful deploy.
echo "==> waiting for $HEALTH"
for _ in $(seq 20); do
  curl -sf "$HEALTH" >/dev/null && { echo "==> deployed, API healthy"; exit 0; }
  sleep 1
done
echo "!! API not answering — check: ssh $HOST journalctl -u $SVC -n 50"
exit 1
