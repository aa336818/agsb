#!/bin/bash

show_menu() {
  clear
  echo -e "\033[36m================ Sing-box 管理菜单 =================\033[0m"
  echo -e "1. 安装 Sing-box + Cloudflare Tunnel"
  echo -e "2. 卸载 Sing-box 与 Cloudflare Tunnel"
  echo -e "3. 设置固定 Cloudflare 隧道配置"
  echo -e "4. 设置节点配置（vmess + hy2）"
  echo -e "0. 退出"
  echo -e "\033[36m====================================================\033[0m"
}

install_singbox() {
  bash <(curl -Ls https://raw.githubusercontent.com/aa336818/a/main/a.sh)
  read -p "按回车键返回菜单..."
}

uninstall_singbox() {
  echo "🧹 正在卸载 sing-box 和 cloudflared..."
  systemctl stop sing-box cloudflared
  systemctl disable sing-box cloudflared
  rm -rf /usr/local/bin/sing-box /usr/local/bin/cloudflared
  rm -rf /etc/sing-box /root/.cloudflared
  rm -f /etc/systemd/system/sing-box.service /etc/systemd/system/cloudflared.service
  systemctl daemon-reload
  echo "✅ 卸载完成"
  read -p "按回车键返回菜单..."
}

set_fixed_tunnel() {
  echo "🔧 设置固定隧道（请按提示填写）"
  read -p "请输入你的 Tunnel ID: " tunnel_id
  read -p "请输入你的 Hostname（如 bt.9191876.xyz）: " hostname
  read -p "请输入你的凭证文件名（如 ${tunnel_id}.json）: " cred_file

  mkdir -p /root/.cloudflared
  cat > /root/.cloudflared/config.yml <<EOF
tunnel: ${tunnel_id}
credentials-file: /root/.cloudflared/${cred_file}

ingress:
  - hostname: ${hostname}
    service: https://127.0.0.1:13245
    originRequest:
      noTLSVerify: true
  - service: http_status:404
EOF

  echo -e "\n✅ 配置文件已写入 /root/.cloudflared/config.yml"
  read -p "按回车键返回菜单..."
}

set_node_config() {
  echo "🛠 设置节点配置（vmess 和 hy2）"
  read -p "请输入 vmess UUID: " uuid
  read -p "请输入 hy2 密码: " hy2pass

  mkdir -p /etc/sing-box
  cat > /etc/sing-box/config.json <<EOF
{
  "log": {
    "level": "info"
  },
  "inbounds": [
    {
      "type": "vmess",
      "listen": "0.0.0.0",
      "listen_port": 10000,
      "tag": "vmess-in",
      "users": [
        {
          "uuid": "${uuid}",
          "alterId": 0
        }
      ],
      "transport": {
        "type": "ws",
        "path": "/ws"
      }
    },
    {
      "type": "hysteria2",
      "listen": "0.0.0.0",
      "listen_port": 10080,
      "tag": "hy2-in",
      "users": [
        {
          "password": "${hy2pass}"
        }
      ]
    }
  ],
  "outbounds": [
    {
      "type": "direct",
      "tag": "direct"
    },
    {
      "type": "block",
      "tag": "block"
    }
  ]
}
EOF

  echo "✅ 节点配置已保存至 /etc/sing-box/config.json"
  read -p "按回车键返回菜单..."
}

while true; do
  show_menu
  read -p "请输入选项 [0-4]: " choice
  case $choice in
    1) install_singbox ;;
    2) uninstall_singbox ;;
    3) set_fixed_tunnel ;;
    4) set_node_config ;;
    0) echo "退出菜单"; exit 0 ;;
    *) echo "❌ 无效选项，请重新输入"; sleep 1 ;;
  esac
done
