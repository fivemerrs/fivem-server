#!/usr/bin/env bash
# Hold GHA job open with Localtonet agent + FXServer.
set -euo pipefail

: "${LOCALTONET_AUTHTOKEN:?}"

log() { echo "[localtonet-keep] $*"; }

ensure_agent() {
  if ! pgrep -x localtonet >/dev/null 2>&1; then
    log "restart agent"
    nohup localtonet --authtoken "$LOCALTONET_AUTHTOKEN" >> localtonet-agent.log 2>&1 &
    echo $! > localtonet.pid
    sleep 4
  fi
}

log "holding open (FXServer + Localtonet agent)"
if [ -f connect.txt ]; then
  echo "FiveM F8: connect $(tr -d '\r\n' < connect.txt)"
fi

END=$((SECONDS + 350*60))
while (( SECONDS < END )); do
  ensure_agent
  if ! curl -sf http://127.0.0.1:30120/info.json >/dev/null 2>&1; then
    log "FXServer not responding on 30120"
  fi
  # free tunnels expire ~30m — remind in logs
  if (( SECONDS % 1500 == 0 )) && (( SECONDS > 0 )); then
    log "free tunnel may have timed out — re-Start in Localtonet My Tunnels if connect fails"
    if [ -f connect.txt ]; then
      echo "connect $(tr -d '\r\n' < connect.txt)"
    fi
  fi
  sleep 30
done

log "timeout reached"
