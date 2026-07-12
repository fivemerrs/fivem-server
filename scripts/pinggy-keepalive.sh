#!/usr/bin/env bash
set -euo pipefail
tail -f fivem.log &
# Pinggy daemon owns tunnels; keep job alive and restart if gone
while true; do
  if ! ./pinggy ps 2>/dev/null | grep -qiE 'tcp|udp|running|listening|active|forward'; then
    echo "[keepalive] tunnels missing — restarting"
    ./pinggy --token "${PINGGY_TOKEN}" --type tcp -l "127.0.0.1:${LOCAL_PORT:-30120}" --force --b || true
    ./pinggy --token "${PINGGY_TOKEN}" --type udp -l "127.0.0.1:${LOCAL_PORT:-30120}" --force --b || true
  fi
  sleep 30
done
