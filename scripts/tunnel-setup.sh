#!/usr/bin/env bash
# Portwarp tunnel provisioning for FiveM (API create + CLI connect prep)
set -euo pipefail

LOCAL_PORT="${LOCAL_PORT:-30120}"
CONNECT_ADDR=""
CONNECT_HOST=""
CONNECT_PORT=""
TUNNEL_ID=""
TUNNEL_BACKEND=""

log() { echo "[tunnel] $*"; }

setup_portwarp_api() {
  [ -n "${PORTWARP_API_KEY:-}" ] || return 1
  TUNNEL_BACKEND="portwarp"
  command -v jq >/dev/null || { apt-get update -qq && apt-get install -y -qq jq; }

  API="https://api.portwarp.com/v1"
  pw_api() { curl -sf -H "Authorization: Bearer ${PORTWARP_API_KEY}" -H "Content-Type: application/json" "$@"; }

  mkdir -p "$HOME/.portwarp"
  if [ -n "${PORTWARP_CREDENTIALS:-}" ]; then
    echo "$PORTWARP_CREDENTIALS" | base64 -d > "$HOME/.portwarp/credentials.json"
  else
    log "PORTWARP_CREDENTIALS secret required"
    return 1
  fi

  TUNNELS=$(pw_api "${API}/tunnels")
  TUNNEL_ID=$(echo "$TUNNELS" | jq -r --argjson p "$LOCAL_PORT" '
    .data[]? | select(.local_port == $p and .protocol == "both") | .id' | head -1)

  if [ -z "$TUNNEL_ID" ] || [ "$TUNNEL_ID" = "null" ]; then
    log "Creating Portwarp BOTH tunnel..."
    BODY=$(jq -n --argjson lp "$LOCAL_PORT" --arg name "FiveM-GHA" \
      '{name: $name, local_port: $lp, protocol: "both"}')
    RESP=$(pw_api -X POST "${API}/tunnels" -d "$BODY")
    TUNNEL_ID=$(echo "$RESP" | jq -r '.tunnel.id // empty')
    [ -n "$TUNNEL_ID" ] || { log "Create failed: $RESP"; return 1; }
  fi

  INFO=$(pw_api "${API}/tunnels/${TUNNEL_ID}")
  CONNECT_ADDR=$(echo "$INFO" | jq -r '.tunnel.connection_address // empty')
  CONNECT_HOST="${CONNECT_ADDR%%:*}"
  CONNECT_PORT="${CONNECT_ADDR##*:}"
  log "Tunnel ID: $TUNNEL_ID"
  log "Address:   $CONNECT_ADDR"
  [ -n "$CONNECT_ADDR" ]
}

setup_playit() {
  TUNNEL_BACKEND="playit"
  log "playit fallback not used when PORTWARP_API_KEY is set"
  return 1
}

if setup_portwarp_api; then
  :
else
  log "ERROR: PORTWARP_API_KEY + PORTWARP_CREDENTIALS required"
  exit 1
fi

echo ""
echo "========== FIVEM SERVER READY =========="
echo "Backend:  $TUNNEL_BACKEND"
echo "Connect:  $CONNECT_ADDR"
echo "FiveM F8: connect $CONNECT_ADDR"
echo "TunnelID: $TUNNEL_ID"
echo "========================================"

if [ -n "${GITHUB_OUTPUT:-}" ]; then
  {
    echo "connect_address=$CONNECT_ADDR"
    echo "connect_host=$CONNECT_HOST"
    echo "connect_port=$CONNECT_PORT"
    echo "tunnel_id=$TUNNEL_ID"
    echo "tunnel_backend=$TUNNEL_BACKEND"
  } >> "$GITHUB_OUTPUT"
fi
