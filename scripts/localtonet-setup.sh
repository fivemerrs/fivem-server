#!/usr/bin/env bash
# Localtonet agent-only setup. Tunnel must exist in dashboard (UDP/TCP → 127.0.0.1:30120).
set -euo pipefail

: "${LOCALTONET_AUTHTOKEN:?}"
: "${LOCALTONET_CONNECT:?}"   # public host:port from My Tunnels (UDP/TCP)
LOCAL_PORT="${LOCAL_PORT:-30120}"

log() { echo "[localtonet] $*"; }

# sanity-check connect string
echo "$LOCALTONET_CONNECT" | grep -Eq '^[A-Za-z0-9._-]+:[0-9]+$' || {
  log "bad LOCALTONET_CONNECT='$LOCALTONET_CONNECT' (need host:port)"
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

pkill -x localtonet 2>/dev/null || true
sleep 1
rm -f localtonet-agent.log
nohup localtonet --authtoken "$LOCALTONET_AUTHTOKEN" > localtonet-agent.log 2>&1 &
echo $! > localtonet.pid
log "agent pid $(cat localtonet.pid)"

# wait until agent looks alive
for i in $(seq 1 30); do
  if ! kill -0 "$(cat localtonet.pid)" 2>/dev/null; then
    log "agent died"
    cat localtonet-agent.log
    exit 1
  fi
  if grep -qiE 'online|connected|authenticated|started|tunnel' localtonet-agent.log 2>/dev/null; then
    break
  fi
  sleep 2
done
sleep 3
tail -n 30 localtonet-agent.log || true

CONNECT="$LOCALTONET_CONNECT"
printf '%s\n' "$CONNECT" > connect.txt
log "CONNECT=$CONNECT"
echo "========== CONNECT NOW =========="
echo "FiveM F8: connect $CONNECT"
echo "Dashboard: start UDP/TCP tunnel to 127.0.0.1:${LOCAL_PORT} if not already"
echo "================================="

{
  echo "connect_address=$CONNECT"
  echo "connect_host=${CONNECT%%:*}"
  echo "tunnel_backend=localtonet"
} >> "$GITHUB_OUTPUT"
