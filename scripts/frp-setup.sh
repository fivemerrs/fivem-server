#!/usr/bin/env bash
# Free self-hosted tunnel: GHA runner runs frpc -> your frps (Oracle Always Free VM, etc.)
set -euo pipefail

LOCAL_PORT="${LOCAL_PORT:-30120}"
FRP_VERSION="${FRP_VERSION:-0.61.1}"

log() { echo "[frp] $*"; }

: "${FRP_SERVER_ADDR:?Set FRP_SERVER_ADDR secret (public IP or hostname of frps)}"
: "${FRP_TOKEN:?Set FRP_TOKEN secret (same token as frps)}"

FRP_SERVER_PORT="${FRP_SERVER_PORT:-7000}"
FRP_PUBLIC_PORT="${FRP_PUBLIC_PORT:-30120}"

CONNECT_ADDR="${FRP_SERVER_ADDR}:${FRP_PUBLIC_PORT}"
CONNECT_HOST="${FRP_SERVER_ADDR}"

log "Installing frpc ${FRP_VERSION}..."
curl -fsSL "https://github.com/fatedier/frp/releases/download/v${FRP_VERSION}/frp_${FRP_VERSION}_linux_amd64.tar.gz" \
  | tar -xz --strip-components=1 "frp_${FRP_VERSION}_linux_amd64/frpc"
chmod +x frpc
./frpc --version

mkdir -p frp
cat > frp/frpc.toml <<EOF
serverAddr = "${FRP_SERVER_ADDR}"
serverPort = ${FRP_SERVER_PORT}
auth.method = "token"
auth.token = "${FRP_TOKEN}"

[[proxies]]
name = "fivem-tcp"
type = "tcp"
localIP = "127.0.0.1"
localPort = ${LOCAL_PORT}
remotePort = ${FRP_PUBLIC_PORT}

[[proxies]]
name = "fivem-udp"
type = "udp"
localIP = "127.0.0.1"
localPort = ${LOCAL_PORT}
remotePort = ${FRP_PUBLIC_PORT}
EOF

log "Relay target: ${CONNECT_ADDR} (TCP+UDP -> localhost:${LOCAL_PORT})"

echo ""
echo "========== FIVEM SERVER READY =========="
echo "Backend:  frp (self-hosted, free)"
echo "Connect:  ${CONNECT_ADDR}"
echo "FiveM F8: connect ${CONNECT_ADDR}"
echo "========================================"

if [ -n "${GITHUB_OUTPUT:-}" ]; then
  {
    echo "connect_address=${CONNECT_ADDR}"
    echo "connect_host=${CONNECT_HOST}"
    echo "connect_port=${FRP_PUBLIC_PORT}"
    echo "tunnel_backend=frp"
  } >> "$GITHUB_OUTPUT"
fi
