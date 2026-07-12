#!/usr/bin/env bash
# Runner-only playit tunnel (no local machine)
set -euo pipefail

LOCAL_PORT="${LOCAL_PORT:-30120}"
CONNECT_ADDR=""
CONNECT_HOST=""
CONNECT_PORT=""
TUNNEL_BACKEND="playit"

log() { echo "[tunnel] $*"; }

[ -n "${PLAYIT_SECRET:-}" ] || { [ -n "${PLAYIT_EMAIL:-}" ] && [ -n "${PLAYIT_PASSWORD:-}" ]; } || {
  log "PLAYIT_SECRET or PLAYIT_EMAIL+PLAYIT_PASSWORD required"
  exit 1
}

chmod +x scripts/playit-setup.sh
OUT=$(scripts/playit-setup.sh)
echo "$OUT"

CONNECT_ADDR=$(echo "$OUT" | grep -oE 'Connect: [^ ]+' | head -1 | cut -d' ' -f2)
[ -n "$CONNECT_ADDR" ] || CONNECT_ADDR=$(echo "$OUT" | grep -oE '[a-z0-9-]+\.gl\.at\.ply\.gg:[0-9]+' | head -1)
CONNECT_HOST="${CONNECT_ADDR%%:*}"
CONNECT_PORT="${CONNECT_ADDR##*:}"
[ -n "$CONNECT_ADDR" ] || { log "No playit address"; exit 1; }

echo ""
echo "========== CONNECT NOW =========="
echo "Backend:  playit"
echo "Connect:  $CONNECT_ADDR"
echo "FiveM F8: connect $CONNECT_ADDR"
echo "================================="

if [ -n "${GITHUB_OUTPUT:-}" ]; then
  {
    echo "connect_address=$CONNECT_ADDR"
    echo "connect_host=$CONNECT_HOST"
    echo "connect_port=$CONNECT_PORT"
    echo "tunnel_backend=playit"
  } >> "$GITHUB_OUTPUT"
fi
