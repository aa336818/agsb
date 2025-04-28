### ArgoSB一键无交互脚本：为IDX Google VPS专门设计，其他VPS也可安装

#### 安装最新sing-box内核+最新Cloudflared-Argo内核，支持Argo临时/固定隧道

#### 目前仅输出VMESS协议节点：13个端口节点及对应的优选不死IP全覆盖（80系无TLS+443系开TLS，两个IPV6）

脚本如下，默认安装为Argo临时隧道（UUID、主协议vmess端口未设变量时，为随机生成）
```
bash <(wget -qO- https://raw.githubusercontent.com/yonggekkk/argosb/main/argosb.sh)
```
或者
```
bash <(curl -Ls https://raw.githubusercontent.com/yonggekkk/argosb/main/argosb.sh)
```
---------------------------------------------------------

### 相关快捷方式：

1、查看Argo的固定域名、固定域名的token、临时域名、当前节点信息：

```agsb``` 或者 原完整脚本

2、升级ArgoSB脚本：

```agsb up``` 或者 ```bash <(wget -qO- https://raw.githubusercontent.com/yonggekkk/argosb/main/argosb.sh) up```

3、卸载ArgoSB脚本：

```agsb del``` 或者 ```bash <(wget -qO- https://raw.githubusercontent.com/yonggekkk/argosb/main/argosb.sh) del```

----------------------------------------------------------

### 可自定义设置相关变量参数

1、Argo临时隧道自定义UUID:
```
uuid=你的uuid bash <(wget -qO- https://raw.githubusercontent.com/yonggekkk/argosb/main/argosb.sh)
```

2、Argo临时隧道自定义主协议vmess端口：
```
vmpt=vps可使用的端口 bash <(wget -qO- https://raw.githubusercontent.com/yonggekkk/argosb/main/argosb.sh)
```

3、Argo临时隧道自定义UUID、主协议vmess端口：
```
uuid=你的uuid vmpt=vps可使用的端口 bash <(wget -qO- https://raw.githubusercontent.com/yonggekkk/argosb/main/argosb.sh)
```

4、Argo固定隧道 【 脚本前必须要有端口(vmpt)、固定域名(agn)、token(agk)三个变量，uuid可选 】：
```
vmpt=VPS可使用的端口 agn=固定域名 agk=ey开头的token bash <(wget -qO- https://raw.githubusercontent.com/yonggekkk/argosb/main/argosb.sh)
```
----------------------------------------------------------

#### 视频教程：
[Google IDX VPS代理搭建教程（二）：ArgoSB一键代理脚本发布 | 一次回车搞定一切 | 懒人小白最强Argo代理节点脚本](https://youtu.be/OoXJ_jxoEyY)

更新中……

----------------------------------------------------------

### 交流平台：[甬哥博客地址](https://ygkkk.blogspot.com)、[甬哥YouTube频道](https://www.youtube.com/@ygkkk)、[甬哥TG电报群组](https://t.me/+jZHc6-A-1QQ5ZGVl)、[甬哥TG电报频道](https://t.me/+DkC9ZZUgEFQzMTZl)

----------------------------------------------------------
### 感谢支持！微信打赏甬哥侃侃侃ygkkk
![41440820a366deeb8109db5610313a1](https://github.com/user-attachments/assets/e5b1f2c0-bd2c-4b8f-8cda-034d3c8ef73f)

----------------------------------------------------------
### 感谢你右上角的star🌟
[![Stargazers over time](https://starchart.cc/yonggekkk/ArgoSB.svg)](https://starchart.cc/yonggekkk/ArgoSB)
