#!/usr/bin/env bash
# Reliable Pinggy: download CLI, start TCP+UDP tunnels, parse public URL
set -euo pipefail

: "${PINGGY_TOKEN:?}"
LOCAL_PORT="${LOCAL_PORT:-30120}"
log() { echo "[pinggy] $*"; }

log "Downloading Pinggy CLI..."
curl -fsSL -o pinggy "https://github.com/Pinggy-io/cli-js/releases/latest/download/pinggy-linux-x64" \
  || curl -fsSL -o pinggy "https://s3.ap-south-1.amazonaws.com/public.pinggy.io/cli/linux-x64/pinggy"
chmod +x ./pinggy
./pinggy --version || true

rm -f pinggy-out.log pinggy-urls.txt
log "Starting TCP tunnel (foreground capture)..."
# Run TCP in background detached; capture output
set +e
./pinggy --token "$PINGGY_TOKEN" --type tcp -l "127.0.0.1:${LOCAL_PORT}" --force --b --vv > pinggy-tcp.log 2>&1
TCP_RC=$?
set -e
log "tcp exit=$TCP_RC"
cat pinggy-tcp.log || true

log "Starting UDP tunnel..."
set +e
./pinggy --token "$PINGGY_TOKEN" --type udp -l "127.0.0.1:${LOCAL_PORT}" --force --b --vv > pinggy-udp.log 2>&1
UDP_RC=$?
set -e
log "udp exit=$UDP_RC"
cat pinggy-udp.log || true

./pinggy ps > pinggy-ps.log 2>&1 || true
cat pinggy-ps.log || true

# Parse any host:port from logs
CONNECT=$(grep -oE '[a-zA-Z0-9.-]+\.(a\.)?pinggy(\.io|\.online):[0-9]+' pinggy-tcp.log pinggy-udp.log pinggy-ps.log 2>/dev/null | head -1 || true)
if [ -z "$CONNECT" ]; then
  CONNECT=$(grep -oE 'tcp://[^[:space:]]+|udp://[^[:space:]]+' pinggy-tcp.log pinggy-udp.log 2>/dev/null | head -1 | sed -E 's#^[a-z]+://##')
fi

# Prefer TCP address for FiveM connect (same host if possible)
TCP_ADDR=$(grep -oE '[a-zA-Z0-9.-]+\.(a\.)?pinggy(\.io|\.online):[0-9]+' pinggy-tcp.log pinggy-ps.log 2>/dev/null | head -1 || true)
[ -n "$TCP_ADDR" ] && CONNECT="$TCP_ADDR"

[ -n "$CONNECT" ] || { log "ERROR: could not parse public address"; exit 1; }

echo "connect=$CONNECT" > pinggy-urls.txt
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
