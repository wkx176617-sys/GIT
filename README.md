# GOST SOCKS5 新手部署工具

这是一个面向 macOS + Linux VPS 的简化 SOCKS5 部署工具。目标是让每台 VPS 只提供一个直接 SOCKS5 节点，避免 3x-ui、VLESS、v2rayN 副本和多层本地端口造成混淆。

当前推荐稳定版本：`v1.6.2`。新节点只使用稳定标签，不直接使用开发中的 `main`。

> 网络检测公告：[当前设备与比特窗口网络检测网站](docs/announcements/network-check-links.md)

- [完整搭建教程](docs/tutorial.md)
- [Windows + Xshell 教程](docs/windows-xshell.md)
- [手动检查、维修与 Codex 求助教程](docs/troubleshooting.md)
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

- 服务端：Ubuntu 20.04/22.04/24.04（使用 systemd；支持标准镜像和常见精简镜像）
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

## 旧节点质检与覆写

旧 IP 本身不会与新代码冲突；风险来自相同端口被旧 sing-box、x-ui、Xray 或其他程序占用。
安装入口会先运行只读质检：

```bash
sudo bash preflight.sh --port 31080
```

- 空闲端口：允许全新安装。
- 本工具的 GOST：允许安全升级并保留原凭据。
- 可识别的 sing-box SOCKS5：报告“可迁移”，不会自动改动。
- x-ui、Xray、v2ray 或未知进程：阻止自动安装，不会停用。

只有质检明确显示旧 sing-box 可迁移时，才执行：

```bash
sudo bash overwrite.sh --port 31080
```

从 Mac 远程部署时使用 `./deploy.sh root@VPS公网IP --port 31080 --overwrite`。

覆写程序会先备份到 `/root/gost-socks-backups/`，迁移原 SOCKS5 账号密码，再切换服务并
执行代理出口验收；安装或验收失败会停止新 GOST 并尝试恢复旧 sing-box。不要对未知端口
占用强行覆写。

各版本变化见：[更新记录](CHANGELOG.md)。

## 可选 BBR 加速插件

仓库提供独立的 [BBR + FQ 插件](addons/bbr/README.md)，插件版本为 `1.1.0`。它兼容当前
`main`/`v1.x`，但不属于 SOCKS5 主程序：主程序安装、升级和覆写都不会自动安装或启用它。

```bash
cd /root/socks5-toolkit/addons/bbr
bash install.sh       # 只安装管理命令，不改变网络
bbrctl check          # 只读质检
bbrctl health         # 检查实际状态和配置冲突
bbrctl enable         # 确认需要后才启用
bbrctl repair         # 配置存在但失效时明确修复
bbrctl restore        # 恢复首次启用前的设置
```

插件不开放端口、不改变 IP、GOST、SOCKS5 凭据或安全组。线路正常时继续使用 Ubuntu 默认
`cubic` 即可，不需要为了“已安装插件”而强制开启。

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
sudo socksctl export       # 导出手工信息、v2rayN 和 Shadowrocket 链接
sudo socksctl qr            # 生成 Shadowrocket 扫码二维码
sudo socksctl qr v2rayn     # 生成 v2rayN 扫码二维码
sudo socksctl logs         # 最近 100 行日志
sudo socksctl restart      # 重启服务
sudo socksctl rotate       # 自动生成新密码并重启
sudo socksctl version      # GOST 版本
sudo socksctl doctor       # 脱敏诊断：服务、端口、资源、外部稳定性
sudo socksctl incidents    # 查看最近故障事件及事件编号
sudo socksctl heal         # 本地确定性故障时恢复最后可用状态
sudo socksctl recover      # 经确认后手工恢复最后可用状态
sudo socksctl snapshots    # 查看 last-good 和 previous-good
sudo socksctl note         # 交互式记录暂时说不清的问题
sudo socksctl report       # 生成可交给 Codex 的脱敏故障报告
sudo socksctl reports      # 查看服务器上的报告
sudo socksctl report-delete # 确认后删除全部报告
sudo socksctl guide        # 中文新手菜单，减少复制粘贴错误
```

## 最后可用状态与故障档案

从 `v1.6.0` 起，安装、升级和密码轮换采用事务式保护：修改前保存当前状态，修改后进行本地
与外部验收，通过后才标记为“最后可用状态”。未预料的失败会生成 `INC-...` 事件编号并尝试
恢复修改前状态。相同症状会标记为重复出现，记录可在任何设备登录服务器后查询：

```bash
socksctl incidents              # 最近 20 条
socksctl incidents 50           # 最近 50 条
socksctl incidents INC-事件编号 # 查询指定事件
socksctl snapshots              # 查看两级健康快照
socksctl recover previous       # 退回前一健康版本
socksctl note                   # 输入现象并获得事件编号
```

只有白名单内且证据明确的配置故障允许 `socksctl heal` 回退。VPN 出口变化、云安全组、端口
冲突、VPS 线路和检测网站等问题只记录，不盲目覆写协议。恢复是“尽力恢复”，服务器被删除、
磁盘损坏或 SSH 完全失联时，服务器内快照无法提供保证。
恢复只回退协议二进制、配置、凭据和服务定义；诊断与事件查询工具保持最新版，确保回退后
仍能查看刚刚发生的问题。

`socksctl heal` 使用严格维修白名单：只有配置缺失、配置权限错误或配置与凭据记录不一致，且
没有端口冲突、未知错误等阻断信号时，才允许恢复健康快照。服务单独停止、端口被其他程序
占用、系统资源异常和任何未知故障都会停止自动维修，保持配置不变并显示中文说明。
需要人工处理时请阅读[手动检查、维修与 Codex 求助教程](docs/troubleshooting.md)。

从 `v1.6.2` 起，`doctor --no-record` 提供严格只读检查；外部检测每个目标最多两次、重试间隔
2 秒、单次超时 15 秒。服务 60 秒内最多自动启动 5 次，每次间隔 5 秒。同一种故障自动恢复
一次后，30 分钟内再次出现会触发熔断，不再修改配置。恢复前必须验证快照结构和校验值。
服务器最多自动保留最近 5 份脱敏报告。

更新到本项目当前固定的 GOST 版本：重新运行同一个 `deploy.sh` 命令。已有节点名称、端口和凭据会被保留。新节点名称默认与 VPS 公网 IP 相同，无需额外命名。

如果目标端口已经被 sing-box、x-ui、Xray 或其他程序占用，安装器会停止并显示冲突，不会擅自删除旧服务。先备份和停用旧服务，再重新部署。

卸载：

```bash
sudo socks-uninstall
```

卸载会删除 VPS 上的节点配置和凭据，因此需要再次输入确认。

## 多节点管理规则

所有节点都使用 `31080`，节点名称默认就是 VPS 公网 IP。真实节点信息保存在各自服务器的
`/etc/gost-socks/node.env`，不建立本地节点清单，也不上传 GitHub。在任意 Mac 或 Windows
设备上通过 SSH/Xshell 登录对应服务器后，运行 `sudo socksctl info` 或
`sudo socksctl export` 即可查询。你仍需记住 VPS 的 IP 和 SSH 登录凭据。

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
scripts/socks-doctor     脱敏健康诊断与延迟/稳定性分类
scripts/socks-safety     最后可用快照、恢复和可查询事件档案
preflight.sh             Ubuntu 镜像、旧服务和端口只读质检
overwrite.sh             备份并迁移受支持的旧 sing-box SOCKS5
docs/windows-xshell.md   Windows + Xshell 图文式步骤
docs/tutorial.md         完整搭建、验收与维护教程
docs/announcements/      网络检测网站公告与使用说明
docs/releases/           每个稳定版本的独立说明
docs/version-policy.md   固定版本维护规则
CHANGELOG.md             稳定版本更新记录
RELEASING.md             新版本发布清单
VERSION                  当前推荐版本号
tests/syntax.sh          Shell 语法和帮助信息测试
addons/bbr/              独立可选的 BBR + FQ 插件、兼容声明和说明
```
