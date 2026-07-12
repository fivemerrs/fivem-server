#!/usr/bin/env bash
# Keep Pinggy tunnel + FXServer alive for the job
set -euo pipefail

tail -f fivem.log &
TUNNEL_PID=$(cat pinggy.pid 2>/dev/null || echo "")

if [ -n "$TUNNEL_PID" ] && kill -0 "$TUNNEL_PID" 2>/dev/null; then
  echo "[pinggy] tunnel pid $TUNNEL_PID — waiting"
  wait "$TUNNEL_PID"
else
  echo "[pinggy] restarting tunnel in foreground..."
  exec python3 scripts/pinggy_run.py
fi
