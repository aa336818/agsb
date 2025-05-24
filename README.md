### agsb一键无交互脚本

#### 安装最新sing-box内核+最新Cloudflared-Argo内核，支持Argo临时/固定隧道

脚本如下，默认安装为Argo临时隧道（UUID、主协议vmess端口未设变量时，为随机生成）
```
bash <(wget -qO- https://raw.githubusercontent.com/aa336818/agsb/main/a.sh)
```
或者
```
bash <(curl -Ls https://raw.githubusercontent.com/aa336818/agsb/main/a.sh)
```
---------------------------------------------------------

### 相关快捷方式：

1、查看Argo的固定域名、固定域名的token、临时域名、当前节点信息：

```agsb``` 或者 原完整脚本

2、升级ArgoSB脚本：

```agsb up``` 或者 ```bash <(wget -qO- https://raw.githubusercontent.com/aa336818/agsb/main/a.sh) up```

3、卸载ArgoSB脚本：

```agsb del``` 或者 ```bash <(wget -qO- https://raw.githubusercontent.com/aa336818/agsb/main/a.sh) del```

----------------------------------------------------------

### 可自定义设置相关变量参数

1、Argo临时隧道自定义UUID:
```
uuid=你的uuid bash <(wget -qO- https://raw.githubusercontent.com/aa336818/agsb/main/a.sh)
```

2、Argo临时隧道自定义主协议vmess端口：
```
vmpt=vps可使用的端口 bash <(wget -qO- https://raw.githubusercontent.com/aa336818/agsb/main/a.sh)
```

3、Argo临时隧道自定义UUID、主协议vmess端口：
```
uuid=你的uuid vmpt=vps可使用的端口 bash <(wget -qO- https://raw.githubusercontent.com/aa336818/agsb/main/a.sh)
```

4、Argo固定隧道 【 脚本前必须要有端口(vmpt)、固定域名(agn)、token(agk)三个变量，uuid可选 】：
```
vmpt=VPS可使用的端口 agn=固定域名 agk=ey开头的token bash <(wget -qO- https://raw.githubusercontent.com/aa336818/agsb/main/a.sh)
```
----------------------------------------------------------

