#!/usr/bin/env bash
set -euo pipefail
tail -f fivem.log &
PID=$(cat pinggy.pid 2>/dev/null || echo "")
if [ -n "$PID" ] && kill -0 "$PID" 2>/dev/null; then
  wait "$PID"
else
  exec python3 -u scripts/pinggy_run.py
fi
