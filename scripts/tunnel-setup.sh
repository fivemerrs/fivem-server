#!/usr/bin/env bash
# Connect-now: Portwarp (TCP+UDP) -> playit fallback
set -euo pipefail

LOCAL_PORT="${LOCAL_PORT:-30120}"
CONNECT_ADDR=""
CONNECT_HOST=""
CONNECT_PORT=""
TUNNEL_ID=""
TUNNEL_BACKEND=""

log() { echo "[tunnel] $*"; }

setup_portwarp() {
  [ -n "${PORTWARP_API_KEY:-}" ] && [ -n "${PORTWARP_CREDENTIALS:-}" ] || return 1
  TUNNEL_BACKEND="portwarp"
  command -v jq >/dev/null || { apt-get update -qq && apt-get install -y -qq jq; }

  API="https://api.portwarp.com/v1"
  pw_api() { curl -sf -H "Authorization: Bearer ${PORTWARP_API_KEY}" -H "Content-Type: application/json" "$@"; }

  mkdir -p "$HOME/.portwarp"
  echo "$PORTWARP_CREDENTIALS" | base64 -d > "$HOME/.portwarp/credentials.json"

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
  log "Portwarp tunnel: $TUNNEL_ID -> $CONNECT_ADDR"
  [ -n "$CONNECT_ADDR" ]
}

setup_playit() {
  [ -n "${PLAYIT_SECRET:-}" ] || { [ -n "${PLAYIT_EMAIL:-}" ] && [ -n "${PLAYIT_PASSWORD:-}" ]; } || return 1
  log "Falling back to playit..."
  TUNNEL_BACKEND="playit"
  chmod +x scripts/playit-setup.sh
  OUT=$(scripts/playit-setup.sh)
  echo "$OUT"
  CONNECT_ADDR=$(echo "$OUT" | grep -oE 'Connect: [^ ]+' | head -1 | cut -d' ' -f2)
  [ -n "$CONNECT_ADDR" ] || CONNECT_ADDR=$(echo "$OUT" | grep -oE '[a-z0-9-]+\.gl\.at\.ply\.gg:[0-9]+' | head -1)
  CONNECT_HOST="${CONNECT_ADDR%%:*}"
  CONNECT_PORT="${CONNECT_ADDR##*:}"
  [ -n "$CONNECT_ADDR" ]
}

if setup_portwarp || setup_playit; then
  :
else
  log "Need PORTWARP_* or PLAYIT_* secrets"
  exit 1
fi

echo ""
echo "========== CONNECT NOW =========="
echo "Backend:  $TUNNEL_BACKEND"
echo "Connect:  $CONNECT_ADDR"
echo "FiveM F8: connect $CONNECT_ADDR"
echo "TunnelID: ${TUNNEL_ID:-n/a}"
echo "================================="

if [ -n "${GITHUB_OUTPUT:-}" ]; then
  {
    echo "connect_address=$CONNECT_ADDR"
    echo "connect_host=$CONNECT_HOST"
    echo "connect_port=$CONNECT_PORT"
    echo "tunnel_id=${TUNNEL_ID:-}"
    echo "tunnel_backend=$TUNNEL_BACKEND"
  } >> "$GITHUB_OUTPUT"
fi
