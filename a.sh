#!/bin/bash

green() { echo -e "\033[32m\033[01m$1\033[0m"; }
yellow() { echo -e "\033[33m\033[01m$1\033[0m"; }
red() { echo -e "\033[31m\033[01m$1\033[0m"; }

VM_IP=""

prompt_ip() {
  echo
  echo "请选择用于 vmess 节点信息展示的 IP 类型："
  echo "1. 使用 IPv4"
  echo "2. 使用 IPv6"
  read -p "输入选项 [1-2]，默认 1: " ip_choice
  [[ "$ip_choice" == "2" ]] && VM_IP=$(curl -s --max-time 3 ipv6.ip.sb) || VM_IP=$(curl -s --max-time 3 ipv4.ip.sb)
  [[ -z "$VM_IP" ]] && VM_IP="your.server.ip"
}

install_all() {
  if [[ -f /etc/sing-box/config.json ]]; then
    yellow "Sing-box 已安装，跳过安装。"
    return
  fi

  green "🔧 安装 Sing-box + Cloudflared 隧道中..."
  apt update -y && apt install -y curl wget jq tar socat iptables

  ARCH=$(uname -m)
  [[ "$ARCH" == "x86_64" ]] && ARCH="amd64"
  [[ "$ARCH" == "aarch64" ]] && ARCH="arm64"

  VER=$(curl -s https://api.github.com/repos/SagerNet/sing-box/releases/latest | jq -r .tag_name)
  CLEAN_VER=$(echo "$VER" | sed 's/^v//')
  wget -O sb.tar.gz https://github.com/SagerNet/sing-box/releases/download/${VER}/sing-box-${CLEAN_VER}-linux-${ARCH}.tar.gz
  tar -xzf sb.tar.gz
  mkdir -p /etc/sing-box
  mv sing-box-${CLEAN_VER}-linux-${ARCH}/* /etc/sing-box/
  ln -sf /etc/sing-box/sing-box /usr/local/bin/sing-box

  prompt_ip

  cat > /etc/sing-box/config.json <<EOF
{
  "log": {
    "level": "info"
  },
  "inbounds": [
    {
      "type": "vmess",
      "listen": "0.0.0.0",
      "listen_port": 28773,
      "tag": "vmess-in",
      "users": [{ "uuid": "bfd088f7-7376-414c-9502-193c25a86442", "alterId": 0 }],
      "transport": { "type": "ws", "path": "/ws" }
    }
  ],
  "outbounds": [
    { "type": "direct", "tag": "direct" },
    { "type": "block", "tag": "block" }
  ]
}
EOF

  cat > /etc/systemd/system/sing-box.service <<EOF
[Unit]
Description=Sing-box Service
After=network.target

[Service]
ExecStart=/usr/local/bin/sing-box run -c /etc/sing-box/config.json
Restart=always
User=root

[Install]
WantedBy=multi-user.target
EOF

  systemctl daemon-reexec
  systemctl enable --now sing-box

  wget -O /usr/local/bin/cloudflared https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-${ARCH}
  chmod +x /usr/local/bin/cloudflared

  iptables -I INPUT -p tcp --dport 28773 -j ACCEPT
}

view_node() {
  if [[ -f /etc/sing-box/config.json ]]; then
    port=$(jq -r '.inbounds[0].listen_port' /etc/sing-box/config.json)
    uuid=$(jq -r '.inbounds[0].users[0].uuid' /etc/sing-box/config.json)
    vmess_json='{"v":"2","ps":"MyNode","add":"'$VM_IP'","port":"'$port'","id":"'$uuid'","aid":"0","net":"ws","type":"none","host":"","path":"/ws","tls":""}'
    vmess_b64=$(echo -n "$vmess_json" | base64 -w0)
    echo
    green "【完整 Vmess 节点信息】"
    echo "地址: $VM_IP"
    echo "端口: $port"
    echo "UUID : $uuid"
    echo "路径: /ws"
    echo "协议: vmess + ws"
    echo "一键链接:"
    echo "vmess://$vmess_b64"
  else
    red "未找到配置文件"
  fi
}

# 主菜单（精简预览）
while true; do
  clear
  echo -e "\033[36m============= sb_v7 最终预览（完整 vmess 展示） =============\033[0m"
  echo "1. 安装 sing-box + 隧道"
  echo "2. 查看 vmess 节点信息"
  echo "3. 退出"
  echo -e "\033[36m==============================================================\033[0m"
  read -p "请输入选项 [1-3]: " opt
  case "$opt" in
    1) install_all ;;
    2) view_node; read -p "按回车返回菜单..." ;;
    3) echo "退出"; break ;;
    *) echo "无效选项"; sleep 1 ;;
  esac
done
