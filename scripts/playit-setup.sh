#!/usr/bin/env bash
# Runner-only playit: start agent + reuse/create UDP tunnel for FiveM
set -euo pipefail

API="https://api.playit.gg"
LOCAL_PORT="${LOCAL_PORT:-30120}"
AGENT_IMAGE="${PLAYIT_AGENT_IMAGE:-ghcr.io/playit-cloud/playit-agent:0.17}"

log() { echo "[playit] $*"; }

require_cmd() { command -v "$1" >/dev/null 2>&1 || { apt-get update -qq && apt-get install -y -qq "$1"; }; }
require_cmd curl
require_cmd jq
command -v docker >/dev/null || { log "docker missing"; exit 1; }

: "${PLAYIT_EMAIL:?}"
: "${PLAYIT_PASSWORD:?}"

log "Signing in..."
LOGIN=$(curl -sf -X POST "${API}/login/signin" \
  -H "Content-Type: application/json" \
  -d "{\"email\":\"${PLAYIT_EMAIL}\",\"password\":\"${PLAYIT_PASSWORD}\"}")
SESSION_KEY=$(echo "$LOGIN" | jq -r '.data.session_key // empty')
[ -n "$SESSION_KEY" ] || { log "login failed: $LOGIN"; exit 1; }

api() {
  curl -sf -X POST "${API}$1" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer ${SESSION_KEY}" \
    -d "${2:-{}}"
}

# Prefer existing PLAYIT_SECRET (fivem-gh) so we reuse the known tunnel
if [ -n "${PLAYIT_SECRET:-}" ]; then
  SECRET_KEY="$PLAYIT_SECRET"
  log "Using PLAYIT_SECRET for existing agent"
else
  AGENT_NAME="fivem-gh-$(date +%s)"
  log "Creating docker agent $AGENT_NAME"
  CREATE=$(api "/agents/docker/create" "{\"name\":\"${AGENT_NAME}\"}")
  SECRET_KEY=$(echo "$CREATE" | jq -r '.data.secret_key // empty')
  [ -n "$SECRET_KEY" ] || { log "create agent failed: $CREATE"; exit 1; }
fi

docker rm -f playit 2>/dev/null || true
log "Starting agent container..."
docker run -d --name playit --net=host \
  -e "SECRET_KEY=${SECRET_KEY}" \
  "$AGENT_IMAGE" >/dev/null

# Wait until ANY agent is online
AGENT_ID=""
log "Waiting for agent online..."
for i in $(seq 1 45); do
  AGENTS=$(api "/agents/list" "{}")
  AGENT_ID=$(echo "$AGENTS" | jq -r '
    .data.agents[]
    | select((.status.state // .status // "") | tostring | test("connect|online"; "i"))
    | .id' | head -1)
  if [ -n "$AGENT_ID" ]; then
    NAME=$(echo "$AGENTS" | jq -r --arg id "$AGENT_ID" '.data.agents[] | select(.id==$id) | .name')
    log "Agent online: $NAME ($AGENT_ID)"
    break
  fi
  # show latest statuses
  echo "$AGENTS" | jq -r '.data.agents[] | "  [\($i)/45] \(.name): \(.status.state // .status)"' 2>/dev/null || true
  sleep 2
done

if [ -z "$AGENT_ID" ]; then
  log "Agent never came online — docker logs:"
  docker logs playit --tail 40 2>&1 || true
  exit 1
fi

# Prefer existing UDP tunnel address
TUNNELS=$(api "/v1/tunnels/list" "{}")
CONNECT_ADDR=$(echo "$TUNNELS" | jq -r '
  .data.tunnels[]?
  | select(.port_type=="udp" or .port_type=="both")
  | .connect_addresses[]?
  | select(.type=="auto")
  | .value.address' | head -1)

if [ -z "$CONNECT_ADDR" ] || [ "$CONNECT_ADDR" = "null" ]; then
  log "No existing tunnel — creating UDP (free tier)..."
  BODY=$(jq -n --arg agent "$AGENT_ID" --arg port "$LOCAL_PORT" '{
    name: "FiveM-udp",
    enabled: true,
    protocol: {
      type: "raw-ports",
      details: { port_type: "udp", port_count: 1, software_description: "FiveM" }
    },
    origin: {
      type: "agent",
      data: {
        agent_id: $agent,
        config: { fields: [
          {name:"local_ip", value:"127.0.0.1"},
          {name:"local_port", value:$port}
        ]}
      }
    },
    endpoint: { type: "region", details: { region: "global", port: null } }
  }')
  CREATE_T=$(api "/v1/tunnels/create" "$BODY" || true)
  log "create: $CREATE_T"
  for i in $(seq 1 40); do
    TUNNELS=$(api "/v1/tunnels/list" "{}")
    CONNECT_ADDR=$(echo "$TUNNELS" | jq -r '
      .data.tunnels[]?
      | .connect_addresses[]?
      | select(.type=="auto")
      | .value.address' | head -1)
    [ -n "$CONNECT_ADDR" ] && [ "$CONNECT_ADDR" != "null" ] && break
    sleep 3
  done
fi

[ -n "$CONNECT_ADDR" ] && [ "$CONNECT_ADDR" != "null" ] || { log "No connect address"; exit 1; }

CONNECT_HOST="${CONNECT_ADDR%%:*}"
CONNECT_PORT="${CONNECT_ADDR##*:}"

echo ""
echo "========== CONNECT NOW =========="
echo "Backend:  playit (UDP free)"
echo "Connect:  $CONNECT_ADDR"
echo "FiveM F8: connect $CONNECT_ADDR"
echo "NOTE: free playit is UDP-only — TCP join may still fail"
echo "================================="

if [ -n "${GITHUB_OUTPUT:-}" ]; then
  {
    echo "connect_address=$CONNECT_ADDR"
    echo "connect_host=$CONNECT_HOST"
    echo "connect_port=$CONNECT_PORT"
    echo "tunnel_backend=playit"
  } >> "$GITHUB_OUTPUT"
fi
