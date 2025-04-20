#!/bin/bash

green() { echo -e "\033[32m\033[01m$1\033[0m"; }
yellow() { echo -e "\033[33m\033[01m$1\033[0m"; }

show_status() {
  echo -e "\n\033[36m================ 系统状态展示 =================\033[0m"

  # sing-box 和 cloudflared 运行状态
  systemctl is-active --quiet sing-box && sb_status="✅ 运行中" || sb_status="❌ 未运行"
  pgrep cloudflared >/dev/null && cf_status="✅ 运行中" || cf_status="❌ 未运行"

  # 固定隧道域名
  tunnel_domain=$(grep -m1 'hostname:' /root/.cloudflared/config.yml 2>/dev/null | awk '{print $2}')
  [[ -z "$tunnel_domain" ]] && tunnel_domain="（未配置）"

  # 本机 IP
  ip=$(curl -s ipv4.ip.sb || hostname -I | awk '{print $1}')

  # 系统信息
  sys_info=$(uname -o) 
  sys_arch=$(uname -m)
  sys_kernel=$(uname -r)

  # 系统运行时间
  uptime_info=$(uptime -p | sed 's/up //')

  echo "系统信息 : $sys_info $sys_arch | 内核: $sys_kernel"
  echo "运行时长 : $uptime_info"
  echo "公网 IP  : $ip"
  echo "隧道域名 : $tunnel_domain"
  echo "sing-box : $sb_status | cloudflared : $cf_status"
  echo "UUID     : 5255cdc0-d6bf-4e6f-ae6e-b471dfe35f63"
  echo "端口     : 33603 | 路径: /ws"
  echo -e "\033[36m================================================\033[0m"
}

# 模拟菜单结构
while true; do
  clear
  echo -e "\033[36m================ Sing-box 管理菜单 (预览版) ================\033[0m"
  echo "1. 安装 Sing-box 和隧道"
  echo "2. 卸载服务"
  echo "3. 查看节点"
  echo "4. 更改端口 / UUID"
  echo "5. 设置固定隧道"
  echo "6. 退出"
  show_status
  read -p "请输入选项 [1-6]: " choice
  [[ "$choice" == "6" ]] && echo "退出菜单" && break
done
