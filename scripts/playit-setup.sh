#!/usr/bin/env bash
# Fully autonomous playit.gg setup: login → create agent → start tunnel → expose FiveM (30120 UDP+TCP)
set -euo pipefail

API="https://api.playit.gg"
LOCAL_PORT="${PLAYIT_LOCAL_PORT:-30120}"
REGION="${PLAYIT_REGION:-global}"
AGENT_IMAGE="${PLAYIT_AGENT_IMAGE:-ghcr.io/playit-cloud/playit-agent:0.17}"

api() {
  local path="$1"
  local body="${2:-{}}"
  curl -sf -X POST "${API}${path}" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer ${SESSION_KEY}" \
    -d "$body"
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || { echo "Missing required command: $1" >&2; exit 1; }
}

require_cmd curl
require_cmd jq
require_cmd docker

# --- credentials (GitHub secrets or env) ---
if [ -n "${PLAYIT_SECRET:-}" ]; then
  SECRET_KEY="$PLAYIT_SECRET"
  echo "Using pre-configured PLAYIT_SECRET"
elif [ -n "${PLAYIT_EMAIL:-}" ] && [ -n "${PLAYIT_PASSWORD:-}" ]; then
  echo "Signing in to playit.gg..."
  LOGIN=$(curl -sf -X POST "${API}/login/signin" \
    -H "Content-Type: application/json" \
    -d "{\"email\":\"${PLAYIT_EMAIL}\",\"password\":\"${PLAYIT_PASSWORD}\"}") || {
    echo "Login failed — check PLAYIT_EMAIL / PLAYIT_PASSWORD" >&2
    exit 1
  }
  SESSION_KEY=$(echo "$LOGIN" | jq -r '.data.session_key // empty')
  if [ -z "$SESSION_KEY" ]; then
    echo "No session_key in login response: $LOGIN" >&2
    exit 1
  fi

  AGENT_NAME="fivem-gh-$(date +%s)"
  echo "Creating Docker agent: $AGENT_NAME"
  CREATE=$(api "/agents/docker/create" "{\"name\":\"${AGENT_NAME}\"}")
  SECRET_KEY=$(echo "$CREATE" | jq -r '.data.secret_key // empty')
  AGENT_ID=$(echo "$CREATE" | jq -r '.data.agent_id // .data.id // empty')
  if [ -z "$SECRET_KEY" ]; then
    echo "Failed to create Docker agent: $CREATE" >&2
    exit 1
  fi
  echo "Agent secret created"
else
  echo "Set PLAYIT_SECRET or PLAYIT_EMAIL+PLAYIT_PASSWORD" >&2
  exit 1
fi

# Resolve agent_id when only PLAYIT_SECRET was provided
if [ -z "${AGENT_ID:-}" ]; then
  if [ -z "${SESSION_KEY:-}" ]; then
    echo "PLAYIT_SECRET only — cannot create tunnel without PLAYIT_EMAIL+PLAYIT_PASSWORD for API access" >&2
    echo "Either provide credentials or pre-create a tunnel in the playit dashboard." >&2
    exit 1
  fi
  echo "Looking up agent id from agents/list..."
  AGENTS=$(api "/agents/list" "{}")
  AGENT_ID=$(echo "$AGENTS" | jq -r '.data.agents[] | select(.status | test("connect"; "i")) | .id' | head -1)
  if [ -z "$AGENT_ID" ]; then
    AGENT_ID=$(echo "$AGENTS" | jq -r '.data.agents[-1].id // empty')
  fi
fi

if [ -z "${AGENT_ID:-}" ]; then
  echo "Could not determine agent_id" >&2
  exit 1
fi
echo "Agent ID: $AGENT_ID"

# --- start playit agent ---
docker rm -f playit 2>/dev/null || true
echo "Starting playit agent container..."
docker run -d --name playit --rm --net=host \
  -e "SECRET_KEY=${SECRET_KEY}" \
  "$AGENT_IMAGE" >/dev/null

# Wait for agent to connect
echo "Waiting for agent to connect..."
for i in $(seq 1 30); do
  AGENTS=$(api "/agents/list" "{}")
  STATUS=$(echo "$AGENTS" | jq -r --arg id "$AGENT_ID" '.data.agents[] | select(.id == $id) | .status // "unknown"')
  echo "  [$i/30] status: ${STATUS:-not found}"
  if echo "$STATUS" | grep -qi connect; then
    break
  fi
  sleep 2
done

# --- create FiveM tunnel (UDP+TCP on 30120) ---
TUNNEL_NAME="FiveM-$(date +%s)"
echo "Creating tunnel via /v1/tunnels/create..."
CREATE_BODY=$(jq -n \
  --arg name "$TUNNEL_NAME" \
  --arg agent "$AGENT_ID" \
  --arg port "$LOCAL_PORT" \
  --arg region "$REGION" \
  '{
    name: $name,
    enabled: true,
    protocol: {
      type: "raw-ports",
      details: {
        port_type: "both",
        port_count: 1,
        software_description: "FiveM GTA V multiplayer server"
      }
    },
    origin: {
      type: "agent",
      data: {
        agent_id: $agent,
        config: {
          fields: [
            { name: "local_ip", value: "127.0.0.1" },
            { name: "local_port", value: $port }
          ]
        }
      }
    },
    endpoint: {
      type: "region",
      details: { region: $region, port: null }
    }
  }')

CREATE_TUNNEL=$(api "/v1/tunnels/create" "$CREATE_BODY") || CREATE_TUNNEL=""
TUNNEL_ID=$(echo "$CREATE_TUNNEL" | jq -r '.data.id // empty')

# Fallback: legacy /tunnels/create
if [ -z "$TUNNEL_ID" ]; then
  echo "v1 create failed, trying legacy /tunnels/create..."
  echo "v1 response: $CREATE_TUNNEL"
  LEGACY_BODY=$(jq -n \
    --arg name "$TUNNEL_NAME" \
    --arg agent "$AGENT_ID" \
    --argjson port "$LOCAL_PORT" \
    --arg region "$REGION" \
    '{
      name: $name,
      tunnel_description: "FiveM GTA V multiplayer server",
      port_type: "both",
      port_count: 1,
      enabled: true,
      origin: {
        type: "agent",
        data: {
          agent_id: $agent,
          local_ip: "127.0.0.1",
          local_port: $port
        }
      },
      alloc: {
        type: "region",
        details: { region: $region }
      }
    }')
  CREATE_TUNNEL=$(api "/tunnels/create" "$LEGACY_BODY")
  TUNNEL_ID=$(echo "$CREATE_TUNNEL" | jq -r '.data.id // empty')
fi

if [ -z "$TUNNEL_ID" ]; then
  echo "Tunnel creation failed: $CREATE_TUNNEL" >&2
  docker logs playit --tail 30 2>&1 || true
  exit 1
fi
echo "Tunnel ID: $TUNNEL_ID"

# --- poll for public address ---
echo "Waiting for public address..."
PUBLIC_ADDR=""
for i in $(seq 1 60); do
  # Try v1 list first
  TUNNELS=$(api "/v1/tunnels/list" "{}" 2>/dev/null || echo '{}')
  PUBLIC_ADDR=$(echo "$TUNNELS" | jq -r --arg id "$TUNNEL_ID" '
    .data.tunnels[]? | select(.id == $id) | .display_address // empty' | head -1)

  if [ -z "$PUBLIC_ADDR" ]; then
    TUNNELS=$(api "/tunnels/list" "{}" 2>/dev/null || echo '{}')
    PUBLIC_ADDR=$(echo "$TUNNELS" | jq -r --arg id "$TUNNEL_ID" '
      .data.tunnels[]? | select(.id == $id) | .display_address // empty' | head -1)
  fi

  if [ -n "$PUBLIC_ADDR" ]; then
    break
  fi
  echo "  [$i/60] waiting..."
  sleep 3
done

echo ""
echo "========== PLAYIT TUNNEL READY =========="
if [ -n "$PUBLIC_ADDR" ]; then
  echo "Connect: $PUBLIC_ADDR"
  echo "public_address=$PUBLIC_ADDR" >> "${GITHUB_OUTPUT:-/dev/null}" 2>/dev/null || true
else
  echo "Tunnel created but address not ready yet. Check playit dashboard or logs."
  docker logs playit --tail 20 2>&1 || true
fi
echo "Agent ID:  $AGENT_ID"
echo "Tunnel ID: $TUNNEL_ID"
echo "========================================="
