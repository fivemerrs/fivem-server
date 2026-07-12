#!/usr/bin/env bash
# Keep Portwarp relay alive (run in foreground for entire job)
set -euo pipefail

TUNNEL_ID="${1:?tunnel id required}"

curl -fsSL https://portwarp.com/download/install.sh | bash

mkdir -p "$HOME/.portwarp"
echo "${PORTWARP_CREDENTIALS:?}" | base64 -d > "$HOME/.portwarp/credentials.json"

echo "[pwrp] Connecting tunnel $TUNNEL_ID (foreground)..."
exec pwrp connect "$TUNNEL_ID"
