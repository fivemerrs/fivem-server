#!/usr/bin/env bash
# One-time setup on a FREE public VM (Oracle Cloud Always Free recommended).
# Run as root on Ubuntu 22.04/24.04: curl -fsSL ... | bash
set -euo pipefail

FRP_VERSION="${FRP_VERSION:-0.61.1}"
FRP_TOKEN="${FRP_TOKEN:-$(openssl rand -hex 16)}"
FRP_BIND_PORT="${FRP_BIND_PORT:-7000}"
FRP_PUBLIC_PORT="${FRP_PUBLIC_PORT:-30120}"

echo "=== frps setup (FiveM relay) ==="
echo "Token (save as GitHub secret FRP_TOKEN): ${FRP_TOKEN}"
echo "Public connect port: ${FRP_PUBLIC_PORT}"

apt-get update -qq
apt-get install -y -qq curl ufw

curl -fsSL "https://github.com/fatedier/frp/releases/download/v${FRP_VERSION}/frp_${FRP_VERSION}_linux_amd64.tar.gz" \
  | tar -xz -C /usr/local/bin --strip-components=1 "frp_${FRP_VERSION}_linux_amd64/frps"
chmod +x /usr/local/bin/frps

mkdir -p /etc/frp
cat > /etc/frp/frps.toml <<EOF
bindPort = ${FRP_BIND_PORT}
auth.method = "token"
auth.token = "${FRP_TOKEN}"
EOF

cat > /etc/systemd/system/frps.service <<EOF
[Unit]
Description=frp server (FiveM relay)
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/frps -c /etc/frp/frps.toml
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now frps

ufw allow "${FRP_BIND_PORT}/tcp" || true
ufw allow "${FRP_PUBLIC_PORT}/tcp" || true
ufw allow "${FRP_PUBLIC_PORT}/udp" || true

PUBLIC_IP=$(curl -fsSL https://api.ipify.org || hostname -I | awk '{print $1}')
echo ""
echo "=== DONE ==="
echo "Add these GitHub secrets on fivemerrs/fivem-server:"
echo "  FRP_SERVER_ADDR = ${PUBLIC_IP}"
echo "  FRP_TOKEN       = ${FRP_TOKEN}"
echo "  FRP_SERVER_PORT = ${FRP_BIND_PORT}   (optional, default 7000)"
echo "  FRP_PUBLIC_PORT = ${FRP_PUBLIC_PORT} (optional, default 30120)"
echo ""
echo "Open Oracle Cloud security list / firewall for TCP ${FRP_BIND_PORT}, TCP+UDP ${FRP_PUBLIC_PORT}"
echo "Players connect: connect ${PUBLIC_IP}:${FRP_PUBLIC_PORT}"
