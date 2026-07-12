#!/usr/bin/env bash
# Pinggy TCP+UDP via Python SDK + CLI fallback
set -euo pipefail

: "${PINGGY_TOKEN:?Set PINGGY_TOKEN}"
LOCAL_PORT="${LOCAL_PORT:-30120}"
log() { echo "[pinggy] $*" >&2; }

log "pip install pinggy..."
python3 -m pip install -q --upgrade pinggy 2>&1 | tail -n 5

rm -f pinggy-urls.txt
log "starting tunnel..."
python3 -u scripts/pinggy_run.py > pinggy-run.log 2>&1 &
TUNNEL_PID=$!
echo "$TUNNEL_PID" > pinggy.pid
log "pid=$TUNNEL_PID"

CONNECT=""
for i in $(seq 1 60); do
  if [ -f pinggy-urls.txt ] && grep -q '^connect=' pinggy-urls.txt; then
    CONNECT=$(grep '^connect=' pinggy-urls.txt | head -1 | cut -d= -f2-)
    break
  fi
  if ! kill -0 "$TUNNEL_PID" 2>/dev/null; then
    log "process died — log:"
    cat pinggy-run.log || true
    # CLI TCP fallback
    log "trying Pinggy CLI TCP..."
    curl -fsSL -o pinggy.bin "https://github.com/Pinggy-io/pinggy-release/releases/download/v0.5.1/pinggy_linux_amd64" \
      || curl -fsSL -o pinggy.bin "https://s3.ap-south-1.amazonaws.com/public.pinggy.io/pinggy/linux/amd64/pinggy"
    chmod +x pinggy.bin
    ./pinggy.bin --token "$PINGGY_TOKEN" --type tcp -l "$LOCAL_PORT" --force --b --noTui > pinggy-cli.log 2>&1 || true
    sleep 5
    cat pinggy-cli.log || true
    CONNECT=$(grep -oE '[a-zA-Z0-9.-]+\.pinggy\.io:[0-9]+|[a-zA-Z0-9.-]+\.a\.pinggy\.io:[0-9]+|tcp://[^ ]+' pinggy-cli.log pinggy-run.log 2>/dev/null | head -1 | sed 's|tcp://||')
    [ -n "$CONNECT" ] || exit 1
    break
  fi
  # show progress every 10s
  if [ $((i % 5)) -eq 0 ]; then
    log "waiting for URL... ($i/60)"
    tail -n 3 pinggy-run.log 2>/dev/null || true
  fi
  sleep 2
done

[ -n "$CONNECT" ] || {
  log "no URL — dump:"
  cat pinggy-run.log || true
  exit 1
}

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
