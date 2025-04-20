#!/bin/bash

green() { echo -e "\033[32m\033[01m$1\033[0m"; }
yellow() { echo -e "\033[33m\033[01m$1\033[0m"; }
red() { echo -e "\033[31m\033[01m$1\033[0m"; }

check_status() {
  systemctl is-active --quiet sing-box && sb_status="✅ 运行中" || sb_status="❌ 未运行"
  pgrep cloudflared >/dev/null && cf_status="✅ 运行中" || cf_status="❌ 未运行"
  tunnel_domain=$(grep -m1 'hostname:' /root/.cloudflared/config.yml 2>/dev/null | awk '{print $2}')
  [[ -z "$tunnel_domain" ]] && tunnel_domain="（未配置）"
  ip4=$(curl -s --max-time 2 ipv4.ip.sb || echo "无")
  ip6=$(curl -s --max-time 2 ipv6.ip.sb || echo "无")
  sys_info=$(uname -o)
  sys_arch=$(uname -m)
  sys_kernel=$(uname -r)
  uptime_info=$(uptime -p | sed 's/up //')
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

  cat > /etc/sing-box/config.json <<EOF
{
  "log": {
    "level": "info"
  },
  "inbounds": [
    {
      "type": "vmess",
      "listen": "0.0.0.0",
      "listen_port": 23147,
      "tag": "vmess-in",
      "users": [{ "uuid": "4b6c1130-a829-41e3-920a-156dd6ae1052", "alterId": 0 }],
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

  green "✅ Sing-box 安装完成，服务已启动"

  wget -O /usr/local/bin/cloudflared https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-${ARCH}
  chmod +x /usr/local/bin/cloudflared

  green "✅ Cloudflared 隧道工具安装完成"

  iptables -I INPUT -p tcp --dport 23147 -j ACCEPT
  green "✅ 已自动放行 vmess 端口: 23147"
}

uninstall_all() {
  echo "🧹 正在卸载 sing-box 与 cloudflared..."
  systemctl stop sing-box
  pkill -f cloudflared
  systemctl disable sing-box
  rm -rf /etc/sing-box /usr/local/bin/sing-box /usr/local/bin/cloudflared
  rm -f /etc/systemd/system/sing-box.service
  systemctl daemon-reexec
  green "✅ 卸载完成"
}

view_node() {
  if [[ -f /etc/sing-box/config.json ]]; then
    port=$(jq -r '.inbounds[0].listen_port' /etc/sing-box/config.json)
    uuid=$(jq -r '.inbounds[0].users[0].uuid' /etc/sing-box/config.json)
    echo
    green "【Vmess 节点信息】"
    echo "地址: your.domain.com"
    echo "端口: $port"
    echo "UUID : $uuid"
    echo "path : /ws"
    echo "协议: vmess + ws"
    echo "一键复制:"
    echo "vmess://$(echo -n '{"v":"2","ps":"节点","add":"your.domain.com","port":"$port","id":"$uuid","aid":"0","net":"ws","type":"none","host":"","path":"/ws","tls":""}' | base64 -w0)"
  else
    red "⚠️ 未找到配置文件"
  fi
}

modify_vmess() {
  read -p "请输入新的端口号: " newport
  read -p "是否随机生成新的 UUID？(y/n): " confirm
  if [[ "$confirm" == "y" ]]; then
    newid=$(uuidgen)
  else
    read -p "请输入新的 UUID: " newid
  fi

  jq ".inbounds[0].listen_port=$newport | .inbounds[0].users[0].uuid=\"$newid\"" /etc/sing-box/config.json > /tmp/tmp.json && mv /tmp/tmp.json /etc/sing-box/config.json
  iptables -I INPUT -p tcp --dport $newport -j ACCEPT
  systemctl restart sing-box
  green "✅ 已修改并重启服务，新端口: $newport, UUID: $newid"
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
    service: https://127.0.0.1:23147
    originRequest:
      noTLSVerify: true
  - service: http_status:404
EOF

  echo "✅ 配置完成，若未下载凭证，请手动放置 $cred 到 /root/.cloudflared/"
}

# 主菜单
while true; do
  check_status
  clear
  echo -e "\033[36m================ Sing-box 管理菜单 v7 =================\033[0m"
  echo "1. 安装 Sing-box + 隧道"
  echo "2. 卸载 Sing-box 与隧道"
  echo "3. 查看节点信息并复制"
  echo "4. 更改端口与 UUID"
  echo "5. 设置固定隧道"
  echo "6. 退出"
  echo -e "\033[36m=======================================================\033[0m"
  echo "系统信息 : $sys_info $sys_arch | 内核: $sys_kernel"
  echo "运行时长 : $uptime_info"
  echo "IPv4     : $ip4"
  echo "IPv6     : $ip6"
  echo "sing-box : $sb_status | cloudflared : $cf_status"
  echo "UUID     : 4b6c1130-a829-41e3-920a-156dd6ae1052"
  echo "端口     : 23147 | 路径: /ws"
  echo "隧道域名 : $tunnel_domain"
  echo -e "\033[36m=======================================================\033[0m"
  read -p "请输入选项 [1-6]: " input
  case "$input" in
    1) install_all ;;
    2) uninstall_all ;;
    3) view_node; read -p "按回车返回菜单..." ;;
    4) modify_vmess; read -p "按回车返回菜单..." ;;
    5) set_tunnel; read -p "按回车返回菜单..." ;;
    6) echo "退出菜单"; break ;;
    *) echo "❌ 无效选项"; sleep 1 ;;
  esac
done
