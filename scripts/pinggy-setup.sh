#!/usr/bin/env bash
# Pinggy: prefer Python TCP+UDP; fallback SSH TCP (fixes FiveM info.json)
set -euo pipefail
: "${PINGGY_TOKEN:?}"
LOCAL_PORT="${LOCAL_PORT:-30120}"
log() { echo "[pinggy] $*"; }

export PINGGY_TOKEN LOCAL_PORT

log "pip install pinggy"
python3 -m pip install -q --upgrade 'pinggy>=0.0.20' || true

rm -f connect.txt pinggy-urls.txt pinggy-run.log
log "try SDK TCP+UDP (90s max)..."
python3 -u scripts/pinggy_run.py > pinggy-run.log 2>&1 &
SDK_PID=$!
echo $SDK_PID > pinggy.pid

CONNECT=""
for i in $(seq 1 45); do
  if [ -f connect.txt ] && [ -s connect.txt ]; then
    CONNECT=$(tr -d '\r\n' < connect.txt)
    [[ "$CONNECT" == *:* ]] && break
  fi
  if ! kill -0 "$SDK_PID" 2>/dev/null; then
    log "SDK exited"
    cat pinggy-run.log || true
    break
  fi
  sleep 2
done

if [ -z "${CONNECT:-}" ] || [[ "$CONNECT" != *:* ]]; then
  log "SDK slow/failed — SSH TCP fallback"
  kill "$SDK_PID" 2>/dev/null || true
  # autogenerate key to avoid password prompts
  mkdir -p ~/.ssh
  ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519 -N "" >/dev/null 2>&1 || true
  set +e
  timeout 25 ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    -o PreferredAuthentications=password -o PubkeyAuthentication=no \
    -p 443 -R0:localhost:${LOCAL_PORT} \
    "${PINGGY_TOKEN}@a.pinggy.io" > pinggy-ssh.log 2>&1 &
  SSH_PID=$!
  echo $SSH_PID > pinggy.pid
  set -e
  for i in $(seq 1 30); do
    if grep -qoE '[a-zA-Z0-9.-]+\.(a\.)?free\.pinggy\.link|[a-zA-Z0-9.-]+\.a\.pinggy\.io:[0-9]+|[a-zA-Z0-9.-]+\.pinggy\.io:[0-9]+' pinggy-ssh.log 2>/dev/null; then
      break
    fi
    sleep 1
  done
  cat pinggy-ssh.log || true
  CONNECT=$(grep -oE '[a-zA-Z0-9.-]+\.a\.pinggy\.io:[0-9]+' pinggy-ssh.log | head -1 || true)
  [ -n "$CONNECT" ] || CONNECT=$(grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+:[0-9]+' pinggy-ssh.log | head -1 || true)
  # free http URLs sometimes printed without port for http; for tcp usually host:port
  if [ -z "$CONNECT" ]; then
    HOST=$(grep -oE '[a-zA-Z0-9.-]+\.(a\.)?free\.pinggy\.link' pinggy-ssh.log | head -1 || true)
    [ -n "$HOST" ] && CONNECT="${HOST}:443"
  fi
  echo "$CONNECT" > connect.txt
fi

CONNECT=$(tr -d '\r\n' < connect.txt)
[ -n "$CONNECT" ] && [[ "$CONNECT" == *:* ]] || { log "no address"; cat pinggy-run.log pinggy-ssh.log 2>/dev/null; exit 1; }

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
