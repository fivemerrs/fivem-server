#!/usr/bin/env bash
set -euo pipefail
: "${PINGGY_TOKEN:?}"
LOCAL_PORT="${LOCAL_PORT:-30120}"
log() { echo "[pinggy] $*"; }

log "install pinggy via npm"
sudo npm install -g pinggy@latest 2>&1 | tail -n 20
command -v pinggy
pinggy --version || true

rm -f connect.txt pinggy-tcp.log pinggy-udp.log pinggy-ps.log

log "TCP tunnel..."
# Foreground briefly is unreliable; use --b and parse ps
set +e
pinggy --token "$PINGGY_TOKEN" --type tcp -l "${LOCAL_PORT}" --force --b --vvv > pinggy-tcp.log 2>&1
echo "tcp_rc=$?"
set -e
sleep 4
cat pinggy-tcp.log

log "UDP tunnel..."
set +e
pinggy --token "$PINGGY_TOKEN" --type udp -l "${LOCAL_PORT}" --force --b --vvv > pinggy-udp.log 2>&1
echo "udp_rc=$?"
set -e
sleep 4
cat pinggy-udp.log

pinggy ps > pinggy-ps.log 2>&1 || true
echo "===== ps ====="
cat pinggy-ps.log

# Prefer URL from ps output
CONNECT=$(grep -haoE 'tcp://[a-zA-Z0-9._-]+:[0-9]+' pinggy-ps.log pinggy-tcp.log 2>/dev/null | head -1 | sed 's#tcp://##')
[ -n "$CONNECT" ] || CONNECT=$(grep -haoE '[a-zA-Z0-9.-]+\.run\.pinggy-free\.link:[0-9]+' pinggy-ps.log pinggy-tcp.log 2>/dev/null | head -1 || true)
[ -n "$CONNECT" ] || CONNECT=$(grep -haoE '[a-zA-Z0-9.-]+\.a\.pinggy\.io:[0-9]+' pinggy-ps.log pinggy-tcp.log 2>/dev/null | head -1 || true)
[ -n "$CONNECT" ] || CONNECT=$(grep -haoE '[a-zA-Z0-9.-]+\.free\.pinggy\.link' pinggy-ps.log pinggy-tcp.log 2>/dev/null | head -1 || true)

# If we only got a hostname without port, try extract port separately
if [ -n "$CONNECT" ] && [[ "$CONNECT" != *:* ]]; then
  PORT=$(grep -haoE ':[0-9]{2,5}' pinggy-ps.log pinggy-tcp.log 2>/dev/null | head -1 | tr -d ':')
  [ -n "$PORT" ] && CONNECT="${CONNECT}:${PORT}"
fi

[ -n "$CONNECT" ] || { log "ERROR no public address"; exit 1; }
printf '%s\n' "$CONNECT" > connect.txt
echo "CONNECT=$CONNECT"
echo "FiveM F8: connect $CONNECT"

{
  echo "connect_address=$CONNECT"
  echo "connect_host=${CONNECT%%:*}"
  echo "tunnel_backend=pinggy"
} >> "$GITHUB_OUTPUT"
