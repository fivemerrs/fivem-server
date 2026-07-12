#!/usr/bin/env bash
# Install Pinggy SDK and boot tunnel in background; wait for public URL
set -euo pipefail

: "${PINGGY_TOKEN:?Set PINGGY_TOKEN GitHub secret (free at pinggy.io)}"

LOCAL_PORT="${LOCAL_PORT:-30120}"
log() { echo "[pinggy] $*"; }

log "Installing Pinggy Python SDK..."
python3 -m pip install -q pinggy

rm -f pinggy-urls.txt
log "Starting tunnel (TCP+UDP on :${LOCAL_PORT})..."
python3 scripts/pinggy_run.py &
TUNNEL_PID=$!
echo "$TUNNEL_PID" > pinggy.pid

CONNECT=""
for i in $(seq 1 90); do
  if [ -f pinggy-urls.txt ] && grep -q '^connect=' pinggy-urls.txt; then
    CONNECT=$(grep '^connect=' pinggy-urls.txt | head -1 | cut -d= -f2-)
    break
  fi
  if ! kill -0 "$TUNNEL_PID" 2>/dev/null; then
    log "ERROR: pinggy process exited early"
    exit 1
  fi
  sleep 2
done

[ -n "$CONNECT" ] || { log "ERROR: no public URL after 3 minutes"; exit 1; }

CONNECT_HOST="${CONNECT%%:*}"
CONNECT_PORT="${CONNECT##*:}"

echo ""
echo "========== CONNECT NOW =========="
echo "Backend:  pinggy"
echo "Connect:  $CONNECT"
echo "FiveM F8: connect $CONNECT"
echo "================================="

if [ -n "${GITHUB_OUTPUT:-}" ]; then
  {
    echo "connect_address=$CONNECT"
    echo "connect_host=$CONNECT_HOST"
    echo "connect_port=$CONNECT_PORT"
    echo "tunnel_backend=pinggy"
  } >> "$GITHUB_OUTPUT"
fi
