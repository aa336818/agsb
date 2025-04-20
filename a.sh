#!/bin/bash
set -e

# 输出颜色函数
green() { echo -e "\033[32m\033[01m$1\033[0m"; }
yellow() { echo -e "\033[33m\033[01m$1\033[0m"; }
red() { echo -e "\033[31m\033[01m$1\033[0m"; }

[[ $EUID -ne 0 ]] && red "请以 root 用户运行本脚本。" && exit 1

green "[1/5] 开始安装依赖..."
apt update && apt install -y curl wget tar jq socat

green "[2/5] 检测系统架构..."
ARCH=$(uname -m)
case $ARCH in
  x86_64) ARCH="amd64" ;;
  aarch64) ARCH="arm64" ;;
  *) red "不支持的架构: $ARCH" && exit 1 ;;
esac
green "系统架构为 $ARCH"

green "[3/5] 下载并安装 sing-box..."
SBOX_VERSION=$(curl -s https://api.github.com/repos/SagerNet/sing-box/releases/latest | jq -r .tag_name)
wget -qO- https://github.com/SagerNet/sing-box/releases/download/${SBOX_VERSION}/sing-box-${SBOX_VERSION}-linux-${ARCH}.tar.gz | tar -xz
mkdir -p /etc/sing-box
mv sing-box-${SBOX_VERSION}-linux-${ARCH}/* /etc/sing-box/
ln -sf /etc/sing-box/sing-box /usr/local/bin/sing-box

green "[4/5] 安装 Cloudflare Tunnel 工具..."
wget -O /usr/local/bin/cloudflared https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-${ARCH}
chmod +x /usr/local/bin/cloudflared

green "[5/5] 生成配置模板..."

mkdir -p /root/.cloudflared
cat > /root/.cloudflared/config.yml <<EOF
# Cloudflare Tunnel 配置文件模板
# 请手动替换以下字段：
# - tunnel: 你的 tunnel ID
# - credentials-file: 凭证文件路径
# - hostname: 你的绑定域名（如 bt.9191876.xyz）

tunnel: TUNNEL_ID_PLACEHOLDER
credentials-file: /root/.cloudflared/TUNNEL_ID_PLACEHOLDER.json

ingress:
  - hostname: your.domain.com
    service: https://127.0.0.1:13245
    originRequest:
      noTLSVerify: true
  - service: http_status:404
EOF

cat > /etc/sing-box/config.json <<EOF
{
  "log": {
    "level": "info"
  },
  "inbounds": [],
  "outbounds": []
}
EOF

cat > /etc/systemd/system/cloudflared.service <<EOF
[Unit]
Description=Cloudflare Tunnel
After=network.target

[Service]
ExecStart=/usr/local/bin/cloudflared tunnel run
Restart=on-failure
User=root

[Install]
WantedBy=multi-user.target
EOF

cat > /etc/systemd/system/sing-box.service <<EOF
[Unit]
Description=Sing-box Service
After=network.target

[Service]
ExecStart=/usr/local/bin/sing-box run -c /etc/sing-box/config.json
Restart=always
User=root
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF

green "✅ 安装完成，请根据提示修改配置文件："
yellow "/root/.cloudflared/config.yml"
yellow "/etc/sing-box/config.json"

green "🚀 修改完成后你可以执行以下命令启动服务："
echo "  systemctl daemon-reexec"
echo "  systemctl enable --now cloudflared"
echo "  systemctl enable --now sing-box"

