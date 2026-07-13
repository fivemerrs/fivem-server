#!/usr/bin/env bash
# Start Localtonet AFTER FXServer is listening on 30120.
# Requires a live public UDP_TCP mapping (no silent dead fallback).
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

start_agent() {
  pkill -x localtonet 2>/dev/null || true
  sleep 1
  : > localtonet-agent.log
  if command -v stdbuf >/dev/null 2>&1; then
    nohup stdbuf -oL -eL localtonet --authtoken "$LOCALTONET_AUTHTOKEN" > localtonet-agent.log 2>&1 &
  else
    nohup localtonet --authtoken "$LOCALTONET_AUTHTOKEN" > localtonet-agent.log 2>&1 &
  fi
  echo $! > localtonet.pid
  log "agent pid $(cat localtonet.pid)"
}

wait_added() {
  CONNECT=""
  for i in $(seq 1 90); do
    if ! kill -0 "$(cat localtonet.pid)" 2>/dev/null; then
      log "agent died"
      cat localtonet-agent.log
      return 1
    fi
    ADDED="$(grep -oE '[A-Za-z0-9._-]+:[0-9]+[[:space:]]+UDP_TCP' localtonet-agent.log 2>/dev/null | tail -n1 | awk '{print $1}' || true)"
    if [ -n "$ADDED" ]; then
      CONNECT="$ADDED"
      echo "$CONNECT"
      return 0
    fi
    sleep 2
  done
  return 1
}

probe_ok() {
  local addr="$1"
  curl -sf --max-time 15 "http://${addr}/info.json" >/tmp/lt-info.json
}

start_agent

CONNECT=""
if CONNECT="$(wait_added)"; then
  log "got ADDED $CONNECT"
else
  log "no ADDED line yet"
  if [ -n "$FALLBACK_CONNECT" ]; then
    log "trying fallback $FALLBACK_CONNECT"
    CONNECT="$FALLBACK_CONNECT"
  fi
fi

[ -n "$CONNECT" ] || {
  log "could not determine public address — open Localtonet dashboard, Start the UDP_TCP tunnel, confirm AuthToken=Default"
  cat localtonet-agent.log
  exit 1
}

sleep 3
log "probing public http://$CONNECT/info.json"
if ! probe_ok "$CONNECT"; then
  log "public probe failed — restarting agent once"
  start_agent
  if NEW="$(wait_added)"; then
    CONNECT="$NEW"
  fi
  sleep 3
  if ! probe_ok "$CONNECT"; then
    log "public info.json STILL FAILED for $CONNECT"
    curl -sv --max-time 15 "http://${CONNECT}/info.json" 2>&1 | tail -n 40 || true
    cat localtonet-agent.log
    log "In Localtonet My Tunnels: click Start on the UDP_TCP tunnel for this AuthToken, then re-run deploy."
    exit 1
  fi
fi

log "public info.json OK"
head -c 200 /tmp/lt-info.json; echo

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
