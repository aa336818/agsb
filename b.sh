#!/bin/bash

echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~" 
echo "agsb SB+CF隧道脚本"
echo "https://raw.githubusercontent.com/aa336818/agsb/main/a.sh"
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
export LANG=en_US.UTF-8
[[ $EUID -ne 0 ]] && echo "请以root模式运行脚本" && exit

# 系统判断
if [[ -f /etc/redhat-release ]]; then
release="Centos"
elif cat /etc/issue | grep -qi "alpine"; then
release="alpine"
elif cat /etc/issue | grep -qi "debian"; then
release="Debian"
elif cat /etc/issue | grep -qi "ubuntu"; then
release="Ubuntu"
elif cat /proc/version | grep -qi "debian"; then
release="Debian"
elif cat /proc/version | grep -qi "ubuntu"; then
release="Ubuntu"
elif cat /proc/version | grep -qi "centos|red hat|redhat"; then
release="Centos"
else 
echo "脚本不支持当前的系统，请选择使用 Ubuntu、Debian 或 CentOS。" && exit
fi

op=$(cat /etc/redhat-release 2>/dev/null || grep -i pretty_name /etc/os-release 2>/dev/null | cut -d " -f2)
if echo "$op" | grep -qi "arch"; then
  echo "脚本不支持当前的 $op 系统，请选择 Ubuntu、Debian 或 CentOS。" && exit
fi

[[ -z $(systemd-detect-virt 2>/dev/null) ]] && vi=$(virt-what 2>/dev/null) || vi=$(systemd-detect-virt 2>/dev/null)
case $(uname -m) in
  aarch64) cpu=arm64;;
  x86_64)  cpu=amd64;;
  *) echo "目前脚本不支持 $(uname -m) 架构" && exit;;
esac

hostname=$(hostname)

# ========== 用户交互 ==========

# 自定义 VMess 端口
read -p "是否自定义 vmess 端口？1.否（随机） 2.是（手动输入） [1/2]：" setvm
if [[ "$setvm" == "2" ]]; then
  while true; do
    read -p "请输入 vmess 端口（10000-65535）:" input_port
    if [[ $input_port =~ ^[0-9]+$ ]] && [ "$input_port" -ge 10000 ] && [ "$input_port" -le 65535 ]; then
      port_vm_ws=$input_port
      break
    else
      echo "❌ 端口无效，请重新输入。"
    fi
  done
else
  port_vm_ws=$(shuf -i 10000-65535 -n 1)
fi

# 自定义 UUID
read -p "是否自定义 UUID？1.否（随机） 2.是（手动输入） [1/2]：" setid
if [[ "$setid" == "2" ]]; then
  while true; do
    read -p "请输入 UUID（xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx）:" input_uuid
    if [[ $input_uuid =~ ^[0-9a-fA-F\-]{36}$ ]]; then
      UUID=$input_uuid
      break
    else
      echo "❌ UUID格式无效，请重新输入。"
    fi
  done
else
  UUID=""
fi

# 选择隧道类型
echo
echo "请选择 Cloudflare 隧道类型："
echo "1. 使用临时隧道（自动获取 trycloudflare 域名）"
echo "2. 使用固定隧道（需要手动输入固定域名与 token）"
read -p "请选择 [1/2]：" settunnel
if [[ "$settunnel" == "2" ]]; then
  read -p "请输入固定域名（如 tunnel.example.com）:" ARGO_DOMAIN
  read -p "请输入固定域名Token：" ARGO_AUTH
else
  ARGO_DOMAIN=""
  ARGO_AUTH=""
fi

# 导出环境变量供后续使用
export UUID
export port_vm_ws
export ARGO_DOMAIN
export ARGO_AUTH

# 后续安装逻辑应接入此处...




# 安装依赖
if command -v apt &> /dev/null; then
apt update -y
apt install curl wget tar gzip cron jq -y
elif command -v yum &> /dev/null; then
yum install -y curl wget jq tar
elif command -v apk &> /dev/null; then
apk update -y
apk add wget curl tar jq tzdata openssl git grep dcron
else
echo "不支持当前系统，请手动安装依赖。"
exit
fi

# 下载 sing-box
mkdir -p /etc/s-box-ag
sbcore=$(curl -Ls https://data.jsdelivr.com/v1/package/gh/SagerNet/sing-box | grep -Eo '"[0-9.]+"' | head -n 1 | tr -d '"')
sbname="sing-box-$sbcore-linux-$cpu"
echo "下载 sing-box 最新版本：$sbcore"
curl -L -o /etc/s-box-ag/sing-box.tar.gz -# --retry 2 https://github.com/SagerNet/sing-box/releases/download/v$sbcore/$sbname.tar.gz
tar xzf /etc/s-box-ag/sing-box.tar.gz -C /etc/s-box-ag
mv /etc/s-box-ag/$sbname/sing-box /etc/s-box-ag
rm -rf /etc/s-box-ag/{sing-box.tar.gz,$sbname}

# 生成 UUID（如为空）
if [ -z "$UUID" ]; then
UUID=$(/etc/s-box-ag/sing-box generate uuid)
fi

echo
echo "当前 vmess 端口：$port_vm_ws"
echo "当前 UUID：$UUID"
echo

# 生成 sb.json 配置文件
cat > /etc/s-box-ag/sb.json <<EOF
{
  "log": {
    "disabled": false,
    "level": "info",
    "timestamp": true
  },
  "inbounds": [
    {
      "type": "vmess",
      "tag": "vmess-in",
      "listen": "::",
      "listen_port": $port_vm_ws,
      "users": [
        {
          "uuid": "$UUID",
          "alterId": 0
        }
      ],
      "transport": {
        "type": "ws",
        "path": "/$UUID-vm"
      }
    }
  ],
  "outbounds": [
    {
      "type": "direct",
      "tag": "direct"
    }
  ]
}
EOF

# 设置服务
if [[ "$release" == "alpine" ]]; then
cat > /etc/init.d/sing-box <<EOF
#!/sbin/openrc-run
description="sing-box service"
command="/etc/s-box-ag/sing-box"
command_args="run -c /etc/s-box-ag/sb.json"
command_background=true
pidfile="/var/run/sing-box.pid"
EOF
chmod +x /etc/init.d/sing-box
rc-update add sing-box default
rc-service sing-box start
else
cat > /etc/systemd/system/sing-box.service <<EOF
[Unit]
Description=Sing-box Service
After=network.target

[Service]
ExecStart=/etc/s-box-ag/sing-box run -c /etc/s-box-ag/sb.json
Restart=always
User=root

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable sing-box
systemctl start sing-box
fi

# 下载并启动 cloudflared 隧道
argocore=$(curl -Ls https://data.jsdelivr.com/v1/package/gh/cloudflare/cloudflared | grep -Eo '"[0-9.]+"' | head -n 1 | tr -d '"')
curl -L -o /etc/s-box-ag/cloudflared -# --retry 2 https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-$cpu
chmod +x /etc/s-box-ag/cloudflared

if [[ -n "$ARGO_DOMAIN" && -n "$ARGO_AUTH" ]]; then
/etc/s-box-ag/cloudflared tunnel --no-autoupdate --edge-ip-version auto --protocol http2 run --token $ARGO_AUTH >/dev/null 2>&1 &
else
/etc/s-box-ag/cloudflared tunnel --url http://localhost:$port_vm_ws --edge-ip-version auto --no-autoupdate --protocol http2 > /etc/s-box-ag/argo.log 2>&1 &
fi

sleep 8

# 获取域名并生成 vmess 链接
if [[ -n "$ARGO_DOMAIN" ]]; then
argodomain=$ARGO_DOMAIN
else
argodomain=$(grep -a trycloudflare.com /etc/s-box-ag/argo.log | awk -F// '{print $2}' | awk '{print $1}' | head -n 1)
fi

echo
echo "Argo 隧道域名：$argodomain"

link="vmess://$(echo -n '{"v":"2","ps":"vmess-argo","add":"'$argodomain'","port":"443","id":"'$UUID'","aid":"0","net":"ws","type":"none","host":"'$argodomain'","path":"/'$UUID'-vm","tls":"tls"}' | base64 -w0)"
echo "节点链接："
echo $link
