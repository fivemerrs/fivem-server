#!/usr/bin/env bash
set -euo pipefail
tail -f fivem.log &
# Keep job alive; restart tunnels if daemon dies
while true; do
  if ! ./pinggy ps 2>/dev/null | grep -qiE 'tcp|udp|running|active'; then
    echo "[keepalive] restarting pinggy tunnels..."
    ./pinggy --token "${PINGGY_TOKEN}" --type tcp -l "127.0.0.1:${LOCAL_PORT:-30120}" --force --b || true
    ./pinggy --token "${PINGGY_TOKEN}" --type udp -l "127.0.0.1:${LOCAL_PORT:-30120}" --force --b || true
  fi
  sleep 45
done
