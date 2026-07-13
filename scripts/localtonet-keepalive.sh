#!/usr/bin/env bash
# Hold GHA job open; restart Localtonet when public mapping dies.
set -euo pipefail

: "${LOCALTONET_AUTHTOKEN:?}"
LOCAL_PORT="${LOCAL_PORT:-30120}"

log() { echo "[localtonet-keep] $*"; }

parse_added() {
  grep -oE '[A-Za-z0-9._-]+:[0-9]+[[:space:]]+UDP_TCP' localtonet-agent.log 2>/dev/null \
    | tail -n1 | awk '{print $1}' || true
}

restart_agent() {
  log "restart agent"
  pkill -x localtonet 2>/dev/null || true
  sleep 1
  if command -v stdbuf >/dev/null 2>&1; then
    nohup stdbuf -oL -eL localtonet --authtoken "$LOCALTONET_AUTHTOKEN" >> localtonet-agent.log 2>&1 &
  else
    nohup localtonet --authtoken "$LOCALTONET_AUTHTOKEN" >> localtonet-agent.log 2>&1 &
  fi
  echo $! > localtonet.pid
  sleep 5
  NEW="$(parse_added)"
  if [ -n "$NEW" ]; then
    printf '%s\n' "$NEW" > connect.txt
    log "NEW CONNECT: $NEW"
    echo "========== CONNECT NOW =========="
    echo "FiveM F8: connect $NEW"
    echo "================================="
  fi
}

ensure_fivem() {
  if curl -sf --max-time 5 "http://127.0.0.1:${LOCAL_PORT}/info.json" >/dev/null 2>&1; then
    return 0
  fi
  log "FXServer down — trying screen restart"
  if ! screen -list 2>/dev/null | grep -q fivem; then
    screen -dmS fivem bash -lc 'cd server-data && bash ../fxserver/run.sh +exec server.cfg 2>&1 | tee -a ../fivem.log'
    sleep 8
  fi
}

log "holding open (FXServer + Localtonet agent)"
CONNECT="$(tr -d '\r\n' < connect.txt 2>/dev/null || true)"
[ -n "$CONNECT" ] && echo "FiveM F8: connect $CONNECT"

END=$((SECONDS + 350*60))
FAILS=0
while (( SECONDS < END )); do
  ensure_fivem
  CONNECT="$(tr -d '\r\n' < connect.txt 2>/dev/null || true)"
  if [ -z "$CONNECT" ]; then
    restart_agent
    CONTINUE=1
  else
    CONTINUE=0
  fi
  if (( CONTINUE == 0 )); then
    if curl -sf --max-time 12 "http://${CONNECT}/info.json" >/dev/null 2>&1; then
      FAILS=0
    else
      FAILS=$((FAILS + 1))
      log "public http://$CONNECT/info.json failed (streak=$FAILS)"
      if (( FAILS >= 2 )); then
        restart_agent
        FAILS=0
      fi
    fi
  fi
  if ! pgrep -x localtonet >/dev/null 2>&1; then
    restart_agent
  fi
  sleep 20
done

log "timeout reached"
