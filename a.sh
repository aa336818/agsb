#!/bin/bash

green() { echo -e "\033[32m\033[01m$1\033[0m"; }
yellow() { echo -e "\033[33m\033[01m$1\033[0m"; }
red() { echo -e "\033[31m\033[01m$1\033[0m"; }

prompt_ip() {
  echo
  echo "请选择用于 vmess 节点展示的 IP 类型："
  echo "1. 使用 IPv4"
  echo "2. 使用 IPv6"
  read -p "输入选项 [1-2]，默认 1: " ip_choice

  if [[ "$ip_choice" == "2" ]]; then
    VM_IP=$(curl -s --max-time 3 ipv6.ip.sb)
  else
    VM_IP=$(curl -s --max-time 3 ipv4.ip.sb)
  fi

  [[ -z "$VM_IP" ]] && VM_IP="your.server.ip"
  echo "$VM_IP" > /etc/sing-box/vmess_ip.txt
}

install_all() {
  if [[ -f /etc/sing-box/config.json ]]; then
    yellow "Sing-box 已安装，跳过安装。"
    return
  fi

  green "🔧 安装 Sing-box + Cloudflared 隧道..."
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
      "listen_port": 20702,
      "tag": "vmess-in",
      "users": [{ "uuid": "760affb8-8137-4a53-8ca9-4b2bb2befc54", "alterId": 0 }],
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

  iptables -I INPUT -p tcp --dport 20702 -j ACCEPT
  green "✅ 安装完成，端口 20702 已放行"
}

uninstall_all() {
  systemctl stop sing-box
  pkill -f cloudflared
  systemctl disable sing-box
  rm -rf /usr/local/bin/sing-box /usr/local/bin/cloudflared
  rm -rf /etc/sing-box /root/.cloudflared
  rm -f /etc/systemd/system/sing-box.service
  systemctl daemon-reexec
  green "✅ 已卸载 sing-box 与隧道"
}

view_node() {
  VM_IP=$(cat /etc/sing-box/vmess_ip.txt 2>/dev/null || echo "your.server.ip")
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
}

modify_vmess() {
  read -p "请输入新的端口号: " newport
  read -p "是否生成新 UUID？(y/n): " confirm
  if [[ "$confirm" == "y" ]]; then
    newid=$(uuidgen)
  else
    read -p "请输入新 UUID: " newid
  fi
  jq ".inbounds[0].listen_port=$newport | .inbounds[0].users[0].uuid=\"$newid\"" /etc/sing-box/config.json > /tmp/tmp.json && mv /tmp/tmp.json /etc/sing-box/config.json
  iptables -I INPUT -p tcp --dport $newport -j ACCEPT
  systemctl restart sing-box
  green "✅ 已更新端口 $newport，UUID $newid"
}

set_tunnel() {
  read -p "请输入 Tunnel ID: " tid
  read -p "请输入 credentials.json 文件名: " cred
  read -p "请输入绑定域名 hostname: " host

  mkdir -p /root/.cloudflared
  cat > /root/.cloudflared/config.yml <<EOF
tunnel: $tid
credentials-file: /root/.cloudflared/$cred

ingress:
  - hostname: $host
    service: https://127.0.0.1:20702
    originRequest:
      noTLSVerify: true
  - service: http_status:404
EOF
  echo "✅ 隧道配置已写入 /root/.cloudflared/config.yml"
}

# 状态展示
show_status() {
  systemctl is-active --quiet sing-box && sb="✅" || sb="❌"
  pgrep cloudflared >/dev/null && cf="✅" || cf="❌"
  VM_IP=$(cat /etc/sing-box/vmess_ip.txt 2>/dev/null || echo "your.server.ip")
  uuid=$(jq -r '.inbounds[0].users[0].uuid' /etc/sing-box/config.json 2>/dev/null)
  port=$(jq -r '.inbounds[0].listen_port' /etc/sing-box/config.json 2>/dev/null)
  domain=$(grep -m1 'hostname:' /root/.cloudflared/config.yml 2>/dev/null | awk '{print $2}')
  [[ -z "$domain" ]] && domain="未配置"
  ip4=$(curl -s --max-time 2 ipv4.ip.sb || echo "无")
  ip6=$(curl -s --max-time 2 ipv6.ip.sb || echo "无")
  sys=$(uname -o) && arch=$(uname -m) && kern=$(uname -r)
  up=$(uptime -p | sed 's/up //')

  echo -e "\033[36m========================================================\033[0m"
  echo "系统: $sys $arch | 内核: $kern"
  echo "运行时长: $up"
  echo "IPv4: $ip4"
  echo "IPv6: $ip6"
  echo "sing-box: $sb | cloudflared: $cf"
  echo "UUID: $uuid"
  echo "端口: $port | 路径: /ws"
  echo "隧道域名: $domain"
  echo -e "\033[36m========================================================\033[0m"
}

# 主菜单
while true; do
  clear
  echo -e "\033[36m==================== sb_v7 完整正式版 ====================\033[0m"
  echo "1. 安装 sing-box + 隧道"
  echo "2. 卸载 sing-box 与隧道"
  echo "3. 查看 vmess 节点信息"
  echo "4. 修改端口与 UUID"
  echo "5. 设置固定隧道（Tunnel ID + 域名）"
  echo "6. 退出"
  show_status
  read -p "请输入选项 [1-6]: " opt
  case "$opt" in
    1) install_all ;;
    2) uninstall_all ;;
    3) view_node; read -p "按回车返回菜单..." ;;
    4) modify_vmess; read -p "按回车返回菜单..." ;;
    5) set_tunnel; read -p "按回车返回菜单..." ;;
    6) break ;;
    *) echo "❌ 无效选项"; sleep 1 ;;
  esac
done
