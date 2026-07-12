#!/usr/bin/env bash
set -euo pipefail
TUNNEL_ID="${1:?tunnel id required}"
mkdir -p "$HOME/.portwarp"
echo "${PORTWARP_CREDENTIALS:?}" | base64 -d > "$HOME/.portwarp/credentials.json"
echo "[pwrp] connect $TUNNEL_ID"
exec pwrp connect "$TUNNEL_ID"
