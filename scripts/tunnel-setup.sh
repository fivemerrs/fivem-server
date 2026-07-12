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
  auth() { curl -sf -H "Authorization: Bearer ${PORTWARP_API_KEY}" -H "Content-Type: application/json" "$@"; }

  # CLI auth: credentials blob (one-time device login) or skip if connect works with API
  mkdir -p "$HOME/.portwarp"
  if [ -n "${PORTWARP_CREDENTIALS:-}" ]; then
    echo "$PORTWARP_CREDENTIALS" | base64 -d > "$HOME/.portwarp/credentials.json"
    log "Restored Portwarp CLI credentials"
  fi

  # Find FiveM preset id
  PRESET_ID=$(auth "$API/nodes/presets" -d '{}' 2>/dev/null | jq -r '
    .presets[]? | select(.slug=="fivem" or (.name | test("FiveM"; "i"))) | .id' | head -1)
  [ -z "$PRESET_ID" ] || [ "$PRESET_ID" = "null" ] && PRESET_ID=""

  # Reuse existing FiveM tunnel or create one
  TUNNEL_ID=$(auth "$API/tunnels" -d '{}' 2>/dev/null | jq -r --argjson p "$LOCAL_PORT" '
    .tunnels[]? | select(.local_port == $p) | .id' | head -1)

  if [ -z "$TUNNEL_ID" ] || [ "$TUNNEL_ID" = "null" ]; then
    log "Creating Portwarp FiveM tunnel..."
    BODY=$(jq -n --argjson lp "$LOCAL_PORT" --arg name "FiveM-GHA" --arg pid "$PRESET_ID" '
      if $pid != "" then
        { name: $name, local_port: $lp, game_preset_id: $pid }
      else
        { name: $name, local_port: $lp, protocol: "both" }
      end')
    RESP=$(auth -X POST "$API/tunnels" -d "$BODY")
    TUNNEL_ID=$(echo "$RESP" | jq -r '.tunnel.id // empty')
    [ -z "$TUNNEL_ID" ] && { log "Portwarp create failed: $RESP"; return 1; }
  fi

  log "Tunnel ID: $TUNNEL_ID"

  # Start relay (background daemon)
  if ! pwrp status 2>/dev/null | grep -qi logged; then
    if [ ! -f "$HOME/.portwarp/credentials.json" ]; then
      log "Portwarp CLI not logged in — set PORTWARP_CREDENTIALS secret (base64 of ~/.portwarp/credentials.json after 'pwrp login')"
      return 1
    fi
  fi

  pwrp connect --tunnel "$TUNNEL_ID" -b 2>/dev/null || pwrp connect "$TUNNEL_ID" -b 2>/dev/null || {
    pwrp connect --all -b || pwrp connect -b &
  }
  sleep 5

  INFO=$(auth "$API/tunnels/$TUNNEL_ID" -d '{}' 2>/dev/null || auth "$API/tunnels/$TUNNEL_ID")
  CONNECT_ADDR=$(echo "$INFO" | jq -r '.tunnel.connection_address // empty')
  CONNECT_HOST=$(echo "$INFO" | jq -r '.tunnel.connection_host // empty')
  CONNECT_PORT=$(echo "$INFO" | jq -r '.tunnel.remote_port // empty')
  [ -n "$CONNECT_ADDR" ]
}

# ── playit.gg ─────────────────────────────────────────────────────────────────
setup_playit() {
  log "Using playit.gg"
  TUNNEL_BACKEND="playit"
  API="https://api.playit.gg"

  command -v jq >/dev/null || { apt-get update -qq && apt-get install -y -qq jq; }

  api() {
    curl -sf -X POST "${API}${1}" \
      -H "Content-Type: application/json" \
      -H "Authorization: Bearer ${SESSION_KEY}" \
      -d "${2:-{}}"
  }

  if [ -n "${PLAYIT_SECRET:-}" ]; then
    SECRET_KEY="$PLAYIT_SECRET"
    if [ -n "${PLAYIT_EMAIL:-}" ] && [ -n "${PLAYIT_PASSWORD:-}" ]; then
      LOGIN=$(curl -sf -X POST "${API}/login/signin" \
        -H "Content-Type: application/json" \
        -d "{\"email\":\"${PLAYIT_EMAIL}\",\"password\":\"${PLAYIT_PASSWORD}\"}")
      SESSION_KEY=$(echo "$LOGIN" | jq -r '.data.session_key // empty')
    fi
  elif [ -n "${PLAYIT_EMAIL:-}" ] && [ -n "${PLAYIT_PASSWORD:-}" ]; then
    LOGIN=$(curl -sf -X POST "${API}/login/signin" \
      -H "Content-Type: application/json" \
      -d "{\"email\":\"${PLAYIT_EMAIL}\",\"password\":\"${PLAYIT_PASSWORD}\"}")
    SESSION_KEY=$(echo "$LOGIN" | jq -r '.data.session_key // empty')
    [ -n "$SESSION_KEY" ] || { log "playit login failed"; return 1; }
    CREATE=$(api "/agents/docker/create" "{\"name\":\"fivem-gh-$(date +%s)\"}") || true
    SECRET_KEY=$(echo "$CREATE" | jq -r '.data.secret_key // empty')
    [ -n "$SECRET_KEY" ] || SECRET_KEY="${PLAYIT_SECRET:-}"
  else
    return 1
  fi

  [ -n "$SECRET_KEY" ] || { log "No PLAYIT_SECRET"; return 1; }

  docker rm -f playit 2>/dev/null || true
  docker run -d --name playit --rm --net=host \
    -e "SECRET_KEY=${SECRET_KEY}" \
    ghcr.io/playit-cloud/playit-agent:0.17 >/dev/null

  AGENT_ID=""
  if [ -n "${SESSION_KEY:-}" ]; then
    for i in $(seq 1 30); do
      AGENTS=$(api "/agents/list" "{}")
      AGENT_ID=$(echo "$AGENTS" | jq -r '.data.agents[] | select(.status.state | test("connect"; "i")) | .id' | head -1)
      [ -n "$AGENT_ID" ] && break
      sleep 2
    done

    # Ensure tunnel exists (free tier: UDP works; TCP needs premium)
    TUNNELS=$(api "/v1/tunnels/list" "{}")
    TUNNEL_ID=$(echo "$TUNNELS" | jq -r --argjson p "$LOCAL_PORT" '
      .data.tunnels[]? | select(.port_type=="udp" or .port_type=="both") |
      select(.origin.details.config_data.fields[]? | select(.name=="local_port" and .value==($p|tostring))) | .id' | head -1)

    if [ -z "$TUNNEL_ID" ] || [ "$TUNNEL_ID" = "null" ]; then
      [ -z "$AGENT_ID" ] && AGENT_ID=$(echo "$AGENTS" | jq -r '.data.agents[0].id // empty')
      log "Creating playit UDP tunnel (free tier)..."
      BODY=$(jq -n --arg agent "$AGENT_ID" --argjson port "$LOCAL_PORT" '{
        name: "FiveM-GHA",
        enabled: true,
        protocol: { type: "raw-ports", details: { port_type: "udp", port_count: 1, software_description: "FiveM GTA V multiplayer server" } },
        origin: { type: "agent", data: { agent_id: $agent, config: { fields: [
          { name: "local_ip", value: "127.0.0.1" },
          { name: "local_port", value: ($port|tostring) }
        ]}}},
        endpoint: { type: "region", details: { region: "global", port: null } }
      }')
      CREATE=$(api "/v1/tunnels/create" "$BODY") || CREATE=""
      TUNNEL_ID=$(echo "$CREATE" | jq -r '.data.id // empty')
    fi

    # Poll for connect address
    for i in $(seq 1 60); do
      TUNNELS=$(api "/v1/tunnels/list" "{}")
      CONNECT_ADDR=$(echo "$TUNNELS" | jq -r --argjson p "$LOCAL_PORT" '
        .data.tunnels[]? |
        select(.origin.details.config_data.fields[]? | select(.name=="local_port" and .value==($p|tostring))) |
        .connect_addresses[0].value.address // empty' | head -1)
      if [ -n "$CONNECT_ADDR" ]; then
        CONNECT_HOST="${CONNECT_ADDR%%:*}"
        CONNECT_PORT="${CONNECT_ADDR##*:}"
        break
      fi
      sleep 3
    done
  fi

  [ -n "$CONNECT_ADDR" ]
}

# ── main ──────────────────────────────────────────────────────────────────────
if setup_portwarp 2>/dev/null; then
  :
elif setup_playit; then
  :
else
  log "ERROR: Set PORTWARP_API_KEY (+ PORTWARP_CREDENTIALS) or PLAYIT_SECRET"
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

# GitHub Actions outputs
if [ -n "${GITHUB_OUTPUT:-}" ]; then
  {
    echo "connect_address=$CONNECT_ADDR"
    echo "connect_host=$CONNECT_HOST"
    echo "connect_port=$CONNECT_PORT"
    echo "tunnel_backend=$TUNNEL_BACKEND"
  } >> "$GITHUB_OUTPUT"
fi
