#!/usr/bin/env bash
# Keep frpc connected for the whole job (foreground)
set -euo pipefail

log() { echo "[frpc] $*"; }

for i in $(seq 1 90); do
  if curl -sf "http://127.0.0.1:${LOCAL_PORT:-30120}/info.json" >/dev/null 2>&1; then
    log "FXServer responding on :${LOCAL_PORT:-30120}"
    break
  fi
  sleep 2
done

log "Starting frpc (foreground)..."
exec ./frpc -c frp/frpc.toml
