#!/usr/bin/env bash
# Tunnel setup for FiveM on GitHub Actions (Portwarp primary, playit fallback)
set -euo pipefail

LOCAL_PORT="${LOCAL_PORT:-30120}"
CONNECT_ADDR=""
CONNECT_HOST=""
CONNECT_PORT=""
TUNNEL_BACKEND=""

log() { echo "[tunnel] $*"; }

# ── Portwarp ──────────────────────────────────────────────────────────────────
setup_portwarp() {
  [ -n "${PORTWARP_API_KEY:-}" ] || return 1
  log "Using Portwarp"
  TUNNEL_BACKEND="portwarp"

  command -v jq >/dev/null || { apt-get update -qq && apt-get install -y -qq jq; }
  curl -fsSL https://portwarp.com/download/install.sh | bash

  API="https://api.portwarp.com/v1"
  pw_api() { curl -sf -H "Authorization: Bearer ${PORTWARP_API_KEY}" -H "Content-Type: application/json" "$@"; }

  # CLI credentials (device login — required on FREE plan)
  mkdir -p "$HOME/.portwarp"
  if [ -n "${PORTWARP_CREDENTIALS:-}" ]; then
    echo "$PORTWARP_CREDENTIALS" | base64 -d > "$HOME/.portwarp/credentials.json"
    log "Restored Portwarp CLI credentials"
  elif [ -n "${PORTWARP_EMAIL:-}" ] && [ -n "${PORTWARP_PASSWORD:-}" ]; then
    log "Authenticating Portwarp CLI via email..."
    AUTH=$(curl -sf -X POST "https://client-api.portwarp.com/api/agent/auth" \
      -H "Content-Type: application/json" \
      -d "{\"email\":\"${PORTWARP_EMAIL}\",\"password\":\"${PORTWARP_PASSWORD}\"}") || return 1
    # Email auth alone lacks device_id on FREE — credentials file from device login is preferred
    echo "$AUTH" | jq '{token, user_id, username, email, plan_name, api_base: "https://client-api.portwarp.com"}' \
      > "$HOME/.portwarp/credentials.json"
  else
    log "Need PORTWARP_CREDENTIALS (base64 of ~/.portwarp/credentials.json after pwrp login)"
    return 1
  fi

  # Reuse existing FiveM BOTH tunnel or create one
  TUNNELS=$(pw_api "${API}/tunnels")
  TUNNEL_ID=$(echo "$TUNNELS" | jq -r --argjson p "$LOCAL_PORT" '
    .data[]? | select(.local_port == $p and .protocol == "both") | .id' | head -1)

  if [ -z "$TUNNEL_ID" ] || [ "$TUNNEL_ID" = "null" ]; then
    log "Creating Portwarp BOTH tunnel (TCP+UDP)..."
    BODY=$(jq -n --argjson lp "$LOCAL_PORT" --arg name "FiveM-GHA" \
      '{name: $name, local_port: $lp, protocol: "both"}')
    RESP=$(pw_api -X POST "${API}/tunnels" -d "$BODY")
    TUNNEL_ID=$(echo "$RESP" | jq -r '.tunnel.id // empty')
    [ -z "$TUNNEL_ID" ] && { log "Create failed: $RESP"; return 1; }
  fi

  log "Tunnel ID: $TUNNEL_ID"

  # Start relay in background (must not block the workflow step)
  nohup pwrp connect "$TUNNEL_ID" -b > /tmp/pwrp-connect.log 2>&1 &
  disown || true
  sleep 12
  tail -20 /tmp/pwrp-connect.log || true
  pwrp ps 2>/dev/null || true

  INFO=$(pw_api "${API}/tunnels/${TUNNEL_ID}")
  CONNECT_ADDR=$(echo "$INFO" | jq -r '.tunnel.connection_address // .data.connection_address // empty')
  if [ -z "$CONNECT_ADDR" ]; then
    # fallback: parse from pwrp tunnels output
    CONNECT_ADDR=$(pwrp tunnels 2>/dev/null | grep -oP '[a-z0-9]+\.pwrp\.cc:\d+' | head -1 || true)
  fi
  CONNECT_HOST="${CONNECT_ADDR%%:*}"
  CONNECT_PORT="${CONNECT_ADDR##*:}"
  [ -n "$CONNECT_ADDR" ]
}

# ── playit.gg (fallback) ───────────────────────────────────────────────────────
setup_playit() {
  log "Using playit.gg (fallback — UDP only on free tier)"
  TUNNEL_BACKEND="playit"
  API="https://api.playit.gg"
  command -v jq >/dev/null || { apt-get update -qq && apt-get install -y -qq jq; }

  api() {
    curl -sf -X POST "${API}${1}" \
      -H "Content-Type: application/json" \
      -H "Authorization: Bearer ${SESSION_KEY}" \
      -d "${2:-{}}"
  }

  if [ -n "${PLAYIT_SECRET:-}" ] && [ -n "${PLAYIT_EMAIL:-}" ] && [ -n "${PLAYIT_PASSWORD:-}" ]; then
    SECRET_KEY="$PLAYIT_SECRET"
    LOGIN=$(curl -sf -X POST "${API}/login/signin" \
      -H "Content-Type: application/json" \
      -d "{\"email\":\"${PLAYIT_EMAIL}\",\"password\":\"${PLAYIT_PASSWORD}\"}")
    SESSION_KEY=$(echo "$LOGIN" | jq -r '.data.session_key // empty')
  else
    return 1
  fi

  docker rm -f playit 2>/dev/null || true
  docker run -d --name playit --rm --net=host \
    -e "SECRET_KEY=${SECRET_KEY}" \
    ghcr.io/playit-cloud/playit-agent:0.17 >/dev/null

  for i in $(seq 1 60); do
    TUNNELS=$(api "/v1/tunnels/list" "{}")
    CONNECT_ADDR=$(echo "$TUNNELS" | jq -r --argjson p "$LOCAL_PORT" '
      .data.tunnels[]? |
      select(.origin.details.config_data.fields[]? | select(.name=="local_port" and .value==($p|tostring))) |
      .connect_addresses[0].value.address // empty' | head -1)
    [ -n "$CONNECT_ADDR" ] && break
    sleep 3
  done
  CONNECT_HOST="${CONNECT_ADDR%%:*}"
  CONNECT_PORT="${CONNECT_ADDR##*:}"
  [ -n "$CONNECT_ADDR" ]
}

# ── main ──────────────────────────────────────────────────────────────────────
if setup_portwarp; then
  :
elif setup_playit; then
  :
else
  log "ERROR: Set PORTWARP_API_KEY + PORTWARP_CREDENTIALS, or PLAYIT secrets"
  exit 1
fi

echo ""
echo "========== FIVEM SERVER READY =========="
echo "Backend:  $TUNNEL_BACKEND"
echo "Connect:  $CONNECT_ADDR"
echo "FiveM F8: connect $CONNECT_ADDR"
echo "Host:     $CONNECT_HOST"
echo "Port:     $CONNECT_PORT"
echo "========================================"

if [ -n "${GITHUB_OUTPUT:-}" ]; then
  {
    echo "connect_address=$CONNECT_ADDR"
    echo "connect_host=$CONNECT_HOST"
    echo "connect_port=$CONNECT_PORT"
    echo "tunnel_backend=$TUNNEL_BACKEND"
  } >> "$GITHUB_OUTPUT"
fi
