# GOST SOCKS5 新手部署工具

这是一个面向 macOS + Linux VPS 的简化 SOCKS5 部署工具。目标是让每台 VPS 只提供一个直接 SOCKS5 节点，避免 3x-ui、VLESS、v2rayN 副本和多层本地端口造成混淆。

当前推荐稳定版本：`v1.2.1`。新节点只使用稳定标签，不直接使用开发中的 `main`。

> 网络检测公告：[当前设备与比特窗口网络检测网站](docs/announcements/network-check-links.md)

- [完整搭建教程](docs/tutorial.md)
- [Windows + Xshell 教程](docs/windows-xshell.md)
- [各版本详细说明](docs/releases/)
- [版本维护规则](docs/version-policy.md)
- [发布新版本清单](RELEASING.md)

## 推荐架构

```text
比特浏览器 → VPS_IP:31080 → GOST SOCKS5 → 互联网
```

- 每台 VPS 使用相同端口：`31080`
- 每个比特浏览器环境永久绑定一台 VPS
- 节点通过名称和 IP 区分，不通过不同端口区分
- Mac 不运行 GOST、v2rayN 或系统代理
- VPS 不开放 Web 管理面板

## 支持范围

- 服务端：Ubuntu 20.04/22.04/24.04、Debian 11/12/13（使用 systemd）
- 架构：Linux `amd64`、`arm64`
- GOST：固定使用官方稳定版 `3.2.6`，下载后校验 SHA-256
- 协议：标准 SOCKS5、用户名/密码、TCP

新服务器优先选择 Ubuntu 24.04 LTS `amd64`；现有 Ubuntu 22.04 LTS 节点不需要为了本工具重装或升级系统。

## Mac 准备

需要：

- VS Code
- VS Code Remote - SSH 扩展（推荐但不是部署必需）
- macOS 自带的 `ssh`、`scp` 和 Git

不需要安装 Xshell、v2rayN、3x-ui、GOST、Go 或 Docker。

## Windows + Xshell

Windows 用户可以使用 Xshell 8 登录 VPS，然后运行项目中的 `xshell-install.sh`。Windows 本机不需要 Bash、Go、GOST 或 Docker。

完整步骤见：[Windows + Xshell 部署指南](docs/windows-xshell.md)。

各版本变化见：[更新记录](CHANGELOG.md)。

## 第一次部署

### 1. 确认 VPS 信息

你需要知道：

- VPS 公网 IP
- SSH 用户名（通常是 `root`）
- SSH 密码或 SSH 私钥
- VPS 是 Ubuntu 或 Debian

不要把 SSH 密码、SOCKS5 密码或私钥写入本仓库。

### 2. 从 Mac 部署

在 VS Code 终端进入本项目，然后执行：

```bash
./deploy.sh root@你的VPS_IP
```

例子：

```bash
./deploy.sh root@203.0.113.10
```

脚本会：

1. 通过 SSH 将安装文件临时上传到 VPS。
2. 下载并校验 GOST 官方二进制文件。
3. 创建低权限系统用户。
4. 使用 VPS 公网 IP 作为节点名称，并自动生成 SOCKS5 用户名和强密码。
5. 创建并启动 `gost-socks.service`。
6. 输出一张节点连接卡片。

自定义端口（一般不要改）：

```bash
./deploy.sh root@你的VPS_IP --port 31080
```

### 3. 配置萤光云安全组

只新增一条业务入站规则：

```text
协议：TCP
端口：31080
来源：填写允许连接节点的公网 IP，例如 198.51.100.25/32
```

不要开放 UDP，也不要一次性开放 `1-65535`。使用 VPN 作为固定工作入口时，安全组来源应填写 VPN 的固定出口 IP；VPN 出口发生变化后需要同步更新规则。

SSH 端口也应尽量限制来源 IP。部署工具不会自动修改系统或云平台防火墙，以免误操作导致 SSH 失联。

### 4. 配置比特浏览器

```text
代理类型：SOCKS5
代理主机：VPS 公网 IP
代理端口：31080
代理账号：安装结果中的用户名
代理密码：安装结果中的密码
```

不要填写 `127.0.0.1`，不要开启本机 v2rayN，不要使用系统代理。

## VPS 日常管理

通过 SSH 登录 VPS 后使用：

```bash
sudo socksctl status       # 服务状态
sudo socksctl check        # 检查端口并通过代理访问测试站点
sudo socksctl info         # 节点信息（密码打码）
sudo socksctl credentials  # 显示完整账号密码
sudo socksctl logs         # 最近 100 行日志
sudo socksctl restart      # 重启服务
sudo socksctl rotate       # 自动生成新密码并重启
sudo socksctl version      # GOST 版本
```

更新到本项目当前固定的 GOST 版本：重新运行同一个 `deploy.sh` 命令。已有节点名称、端口和凭据会被保留。新节点名称默认与 VPS 公网 IP 相同，无需额外命名。

如果目标端口已经被 sing-box、x-ui、Xray 或其他程序占用，安装器会停止并显示冲突，不会擅自删除旧服务。先备份和停用旧服务，再重新部署。

卸载：

```bash
sudo socks-uninstall
```

卸载会删除 VPS 上的节点配置和凭据，因此需要再次输入确认。

## 多节点管理规则

推荐命名：

```text
MX-01  墨西哥节点 1
US-01  美国节点 1
US-02  美国节点 2
```

所有节点都使用 `31080`。建议在密码管理器中保存：

```text
VPS IP（同时作为节点名称）/ 国家 / 端口 / SOCKS5 用户名 / SOCKS5 密码 / 绑定的浏览器环境
```

不要将真实节点表提交到 Git。

## DNS 与隔离验收

SOCKS5 服务端只有在客户端发送“域名”请求时才能代为解析 DNS。本工具的 `socksctl check` 使用远程域名解析方式验证代理，但不能替代比特浏览器自身的检查。

每个比特浏览器环境第一次使用前检查：

1. 出口 IPv4 是指定 VPS。
2. 没有暴露本机 IPv6。
3. WebRTC 公网地址与代理一致，或已禁用。
4. DNS 结果中不包含本地运营商。
5. 时区、语言与出口地区合理匹配。

检测通过后再登录业务账号。任何检测网站都不能保证“100% 防关联”；请同时遵守所使用平台的规则。

## 安全说明

- 标准 SOCKS5 本身不是加密隧道，用户名/密码认证也不是端到端加密。
- HTTPS 网站内容仍由 HTTPS 加密，但应优先使用安全组来源 IP 白名单。
- 每台 VPS 使用不同的自动生成密码。
- 凭据保存在 VPS 的 `/etc/gost-socks/node.env`，仅 root 可读；运行配置仅允许 root 和服务账户读取。
- 不提供公网 Web 管理面板，减少暴露端口与攻击面。
- 安装器不会执行远程 `curl | bash`；它下载固定版本归档并核对官方 SHA-256。

## 项目文件

```text
deploy.sh                Mac 端部署入口
xshell-install.sh        Windows Xshell 登录后的部署入口
install.sh               VPS 安装/升级脚本
uninstall.sh             VPS 卸载脚本
scripts/socksctl         VPS 管理命令
docs/windows-xshell.md   Windows + Xshell 图文式步骤
docs/tutorial.md         完整搭建、验收与维护教程
docs/announcements/      网络检测网站公告与使用说明
docs/releases/           每个稳定版本的独立说明
docs/version-policy.md   固定版本维护规则
CHANGELOG.md             稳定版本更新记录
RELEASING.md             新版本发布清单
VERSION                  当前推荐版本号
tests/syntax.sh          Shell 语法和帮助信息测试
```
