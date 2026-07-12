#!/usr/bin/env bash
set -euo pipefail
tail -f fivem.log &
PID=$(cat pinggy.pid)
# Keep SDK process in foreground wait; if it dies, restart
while true; do
  if kill -0 "$PID" 2>/dev/null; then
    wait "$PID" || true
  fi
  echo "[keepalive] restarting pinggy SDK..."
  python3 -u scripts/pinggy_run.py > pinggy-run.log 2>&1 &
  PID=$!
  echo $PID > pinggy.pid
  sleep 5
done
