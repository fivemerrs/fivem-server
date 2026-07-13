#!/usr/bin/env bash
# Localtonet agent-only. Tunnel must be UDP/TCP in dashboard → 127.0.0.1:30120.
set -euo pipefail

: "${LOCALTONET_AUTHTOKEN:?}"
: "${LOCALTONET_CONNECT:?}"
LOCAL_PORT="${LOCAL_PORT:-30120}"

log() { echo "[localtonet] $*"; }

echo "$LOCALTONET_CONNECT" | grep -Eq '^[A-Za-z0-9._-]+:[0-9]+$' || {
  log "bad LOCALTONET_CONNECT='$LOCALTONET_CONNECT'"
  exit 1
}

log "install CLI"
if ! command -v localtonet >/dev/null 2>&1; then
  curl -fsSL https://localtonet.com/install.sh | sh || true
fi
if ! command -v localtonet >/dev/null 2>&1; then
  curl -fsSL -o /tmp/lt.zip https://localtonet.com/download/localtonet-linux-x64.zip
  mkdir -p "$HOME/localtonet"
  unzip -qo /tmp/lt.zip -d "$HOME/localtonet"
  chmod 755 "$HOME/localtonet/localtonet"
  export PATH="$HOME/localtonet:$PATH"
fi
command -v localtonet >/dev/null
localtonet --help 2>&1 | head -n 40 || true

pkill -x localtonet 2>/dev/null || true
sleep 1
rm -f localtonet-agent.log
# unbuffered-ish: stdbuf if present
if command -v stdbuf >/dev/null 2>&1; then
  nohup stdbuf -oL -eL localtonet --authtoken "$LOCALTONET_AUTHTOKEN" > localtonet-agent.log 2>&1 &
else
  nohup localtonet --authtoken "$LOCALTONET_AUTHTOKEN" > localtonet-agent.log 2>&1 &
fi
echo $! > localtonet.pid
log "agent pid $(cat localtonet.pid)"

for i in $(seq 1 40); do
  if ! kill -0 "$(cat localtonet.pid)" 2>/dev/null; then
    log "agent died"
    cat localtonet-agent.log
    exit 1
  fi
  sleep 2
done
log "agent still running"
tail -n 80 localtonet-agent.log || true
ps aux | grep -i '[l]ocaltonet' || true

CONNECT="$LOCALTONET_CONNECT"
printf '%s\n' "$CONNECT" > connect.txt
log "CONNECT=$CONNECT"
echo "========== CONNECT NOW =========="
echo "FiveM F8: connect $CONNECT"
echo "In Localtonet: Stop then Start the UDP/TCP tunnel after agent is online"
echo "Tunnel local target MUST be 127.0.0.1:${LOCAL_PORT}"
echo "================================="

{
  echo "connect_address=$CONNECT"
  echo "connect_host=${CONNECT%%:*}"
  echo "tunnel_backend=localtonet"
} >> "$GITHUB_OUTPUT"
