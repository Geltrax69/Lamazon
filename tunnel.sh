#!/usr/bin/env bash
# Puts the local API on https://api.geltrax.engineer through a named
# Cloudflare Tunnel. The hostname is fixed: cloudflared dials out to
# Cloudflare, so it survives changing wifi, NAT and reboots.
#
#   ./tunnel.sh setup     once, after `cloudflared tunnel login`
#   ./tunnel.sh run       foreground, for a quick test
#   ./tunnel.sh install   run as a background service, starts at boot
#   ./tunnel.sh status    is it up, and is the API answering through it
set -euo pipefail

NAME=lamazon
HOSTNAME=api.geltrax.engineer
PORT="${PORT:-8080}"
CONFIG="$HOME/.cloudflared/config.yml"

case "${1:-status}" in
setup)
  # Creating the tunnel is what mints the UUID the DNS record points at.
  cloudflared tunnel list | grep -q " $NAME " || cloudflared tunnel create "$NAME"
  id=$(cloudflared tunnel list --output json | python3 -c "
import json,sys
print(next(t['id'] for t in json.load(sys.stdin) if t['name']=='$NAME'))")

  cat > "$CONFIG" <<EOF
# Written by tunnel.sh. One hostname in, one local port out; anything else
# gets a 404 rather than reaching the laptop.
tunnel: $id
credentials-file: $HOME/.cloudflared/$id.json

ingress:
  - hostname: $HOSTNAME
    service: http://localhost:$PORT
  - service: http_status:404
EOF
  echo "==> wrote $CONFIG (tunnel $id)"

  # Creates the CNAME api -> <id>.cfargotunnel.com, proxied.
  cloudflared tunnel route dns "$NAME" "$HOSTNAME"
  echo "==> DNS routed: $HOSTNAME"
  ;;

run)
  cloudflared tunnel run "$NAME"
  ;;

install)
  # launchd, so the tunnel comes back after a reboot without anyone asking.
  # `service install` writes the plist but not the config, and the daemon runs
  # as root — so the config and credentials have to be copied where root looks,
  # or the tunnel silently never connects.
  id=$(python3 -c "
import re,sys
print(re.search(r'^tunnel: (\S+)', open('$CONFIG').read(), re.M).group(1))")
  sudo cloudflared service install 2>/dev/null || true
  sudo mkdir -p /etc/cloudflared
  sudo cp "$CONFIG" "$HOME/.cloudflared/$id.json" /etc/cloudflared/

  # `service install` writes a plist that runs cloudflared with no arguments,
  # which exits immediately telling you to use `cloudflared tunnel run`. The
  # daemon looks installed and does nothing, so spell the command out.
  sudo python3 - "$id" <<'PLIST'
import plistlib, sys
path = "/Library/LaunchDaemons/com.cloudflare.cloudflared.plist"
with open(path, "rb") as f:
    p = plistlib.load(f)
p["ProgramArguments"] = [
    "/opt/homebrew/bin/cloudflared", "--no-autoupdate",
    "--config", "/etc/cloudflared/config.yml", "tunnel", "run",
]
p["KeepAlive"] = True
with open(path, "wb") as f:
    plistlib.dump(p, f)
print("  plist: " + " ".join(p["ProgramArguments"]))
PLIST

  sudo launchctl bootout system/com.cloudflare.cloudflared 2>/dev/null || true
  sudo launchctl bootstrap system /Library/LaunchDaemons/com.cloudflare.cloudflared.plist
  sleep 5
  pgrep -f "cloudflared .*tunnel run" >/dev/null \
    && echo "==> daemon running (tunnel $id)" \
    || echo "!! daemon not running — see /Library/Logs/com.cloudflare.cloudflared.err.log"

  # The Mac's own resolver cached the old NXDOMAIN while the domain had no
  # nameservers; without this the hostname works everywhere except here.
  sudo dscacheutil -flushcache
  sudo killall -HUP mDNSResponder 2>/dev/null || true
  echo "==> local DNS cache flushed"
  ;;

status)
  echo "== tunnels"; cloudflared tunnel list || true
  echo "== $HOSTNAME"
  curl -sS -m 10 -o /dev/null -w "  /api/health -> %{http_code} in %{time_total}s\n" \
    "https://$HOSTNAME/api/health" || echo "  not reachable"
  echo "== local"
  curl -sS -m 5 -o /dev/null -w "  localhost:$PORT/api/health -> %{http_code}\n" \
    "http://localhost:$PORT/api/health" || echo "  API not running locally"
  ;;

*)
  echo "usage: $0 {setup|run|install|status}" >&2
  exit 1
  ;;
esac
