#!/usr/bin/env bash
# Pinggy TCP via CLI (stays alive) + optional UDP
set -euo pipefail
: "${PINGGY_TOKEN:?}"
LOCAL_PORT="${LOCAL_PORT:-30120}"
log() { echo "[pinggy] $*"; }

log "download CLI"
curl -fsSL -o pinggy "https://github.com/Pinggy-io/cli-js/releases/latest/download/pinggy-linux-x64"
chmod +x ./pinggy
./pinggy --version || true

rm -f connect.txt pinggy-tcp.log pinggy-udp.log
log "start TCP tunnel detached"
./pinggy --token "$PINGGY_TOKEN" --type tcp -l "127.0.0.1:${LOCAL_PORT}" --force --b --vv > pinggy-tcp.log 2>&1 || true
sleep 3
log "start UDP tunnel detached"
./pinggy --token "$PINGGY_TOKEN" --type udp -l "127.0.0.1:${LOCAL_PORT}" --force --b --vv > pinggy-udp.log 2>&1 || true
sleep 3
./pinggy ps > pinggy-ps.log 2>&1 || true
cat pinggy-tcp.log pinggy-udp.log pinggy-ps.log || true

# Extract clean tcp://host:port
CONNECT=$(grep -aoE 'tcp://[a-zA-Z0-9._-]+:[0-9]+' pinggy-tcp.log pinggy-ps.log 2>/dev/null | head -1 | sed 's#tcp://##')
if [ -z "$CONNECT" ]; then
  CONNECT=$(grep -aoE '[a-zA-Z0-9.-]+\.run\.pinggy-free\.link:[0-9]+' pinggy-tcp.log pinggy-ps.log 2>/dev/null | head -1 || true)
fi
if [ -z "$CONNECT" ]; then
  CONNECT=$(grep -aoE '[a-zA-Z0-9.-]+\.a\.pinggy\.io:[0-9]+' pinggy-tcp.log pinggy-ps.log 2>/dev/null | head -1 || true)
fi

[ -n "$CONNECT" ] || { log "failed to parse address"; exit 1; }
printf '%s\n' "$CONNECT" > connect.txt
CONNECT_HOST="${CONNECT%%:*}"

echo "CONNECT=$CONNECT"
echo "========== CONNECT NOW =========="
echo "FiveM F8: connect $CONNECT"
echo "================================="

{
  echo "connect_address=$CONNECT"
  echo "connect_host=$CONNECT_HOST"
  echo "tunnel_backend=pinggy"
} >> "$GITHUB_OUTPUT"
