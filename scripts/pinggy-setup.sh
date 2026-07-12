#!/usr/bin/env bash
set -euo pipefail
: "${PINGGY_TOKEN:?}"
LOCAL_PORT="${LOCAL_PORT:-30120}"
log() { echo "[pinggy] $*"; }

# Stop leftover Pinggy daemon only (do NOT pkill -f pinggy — kills this script)
command -v pinggy >/dev/null 2>&1 && pinggy daemon stop 2>/dev/null || true
sleep 1

log "pip install pinggy SDK"
python3 -m pip install -q --upgrade 'pinggy>=0.0.20'

rm -f connect.txt pinggy-urls.txt pinggy-run.log
log "start SAME-tunnel TCP+UDP via SDK"
python3 -u scripts/pinggy_run.py > pinggy-run.log 2>&1 &
echo $! > pinggy.pid

for i in $(seq 1 60); do
  if [ -f connect.txt ] && [ -s connect.txt ]; then
    CONNECT=$(tr -d '\r\n' < connect.txt)
    if [[ "$CONNECT" == *:* ]]; then
      log "got $CONNECT"
      break
    fi
  fi
  if ! kill -0 "$(cat pinggy.pid)" 2>/dev/null; then
    log "SDK died:"
    cat pinggy-run.log
    exit 1
  fi
  if (( i % 5 == 0 )); then
    log "wait $i/60"
    tail -n 8 pinggy-run.log || true
  fi
  sleep 2
done

CONNECT=$(tr -d '\r\n' < connect.txt 2>/dev/null || true)
[ -n "$CONNECT" ] && [[ "$CONNECT" == *:* ]] || {
  log "no connect address"
  cat pinggy-run.log
  exit 1
}

# sanity: must look like a real host:port
echo "$CONNECT" | grep -Eq '^[A-Za-z0-9._-]+:[0-9]+$' || {
  log "bad address format: $CONNECT"
  cat pinggy-run.log
  exit 1
}

printf '%s\n' "$CONNECT" > connect.txt
cp pinggy-run.log pinggy-tcp.log || true
echo "CONNECT=$CONNECT"
echo "========== CONNECT NOW =========="
echo "FiveM F8: connect $CONNECT"
echo "================================="

{
  echo "connect_address=$CONNECT"
  echo "connect_host=${CONNECT%%:*}"
  echo "tunnel_backend=pinggy"
} >> "$GITHUB_OUTPUT"
