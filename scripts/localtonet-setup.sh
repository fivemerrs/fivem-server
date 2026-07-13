#!/usr/bin/env bash
# Start Localtonet AFTER FXServer is listening on 30120.
set -euo pipefail

: "${LOCALTONET_AUTHTOKEN:?}"
LOCAL_PORT="${LOCAL_PORT:-30120}"
FALLBACK_CONNECT="${LOCALTONET_CONNECT:-}"

log() { echo "[localtonet] $*"; }

curl -sf --max-time 5 "http://127.0.0.1:${LOCAL_PORT}/info.json" >/dev/null || {
  log "FXServer not listening on ${LOCAL_PORT} yet"
  exit 1
}
log "FXServer info.json OK on :${LOCAL_PORT}"

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
rm -f localtonet-agent.log connect.txt
if command -v stdbuf >/dev/null 2>&1; then
  nohup stdbuf -oL -eL localtonet --authtoken "$LOCALTONET_AUTHTOKEN" > localtonet-agent.log 2>&1 &
else
  nohup localtonet --authtoken "$LOCALTONET_AUTHTOKEN" > localtonet-agent.log 2>&1 &
fi
echo $! > localtonet.pid
log "agent pid $(cat localtonet.pid)"

CONNECT=""
for i in $(seq 1 60); do
  if ! kill -0 "$(cat localtonet.pid)" 2>/dev/null; then
    log "agent died"
    cat localtonet-agent.log
    exit 1
  fi
  # ADDED   host:port UDP_TCP -> 127.0.0.1:30120
  ADDED="$(grep -oE '[A-Za-z0-9._-]+:[0-9]+[[:space:]]+UDP_TCP' localtonet-agent.log 2>/dev/null | tail -n1 | awk '{print $1}' || true)"
  if [ -n "$ADDED" ]; then
    CONNECT="$ADDED"
    break
  fi
  sleep 2
done

if [ -z "$CONNECT" ] && [ -n "$FALLBACK_CONNECT" ]; then
  log "no ADDED line yet — using fallback $FALLBACK_CONNECT"
  CONNECT="$FALLBACK_CONNECT"
fi

[ -n "$CONNECT" ] || {
  log "could not determine public address"
  cat localtonet-agent.log
  exit 1
}

# give tunnel a moment, then probe
sleep 3
log "probing public http://$CONNECT/info.json"
if curl -sf --max-time 15 "http://${CONNECT}/info.json" >/tmp/lt-info.json; then
  log "public info.json OK"
  head -c 200 /tmp/lt-info.json; echo
else
  log "public info.json FAILED (CURL $?)"
  curl -sv --max-time 15 "http://${CONNECT}/info.json" 2>&1 | tail -n 40 || true
fi

printf '%s\n' "$CONNECT" > connect.txt
tail -n 80 localtonet-agent.log || true
log "CONNECT=$CONNECT"
echo "========== CONNECT NOW =========="
echo "FiveM F8: connect $CONNECT"
echo "================================="

{
  echo "connect_address=$CONNECT"
  echo "connect_host=${CONNECT%%:*}"
  echo "tunnel_backend=localtonet"
} >> "$GITHUB_OUTPUT"
