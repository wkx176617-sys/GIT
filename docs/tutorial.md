# SOCKS5 完整搭建教程

## 推荐版本

- 部署工具：`v1.5.0`（稳定版）
- 代理核心：GOST `3.2.6`（脚本固定版本并验证 SHA-256）
- 推荐系统：Ubuntu 24.04 LTS `amd64`；已有 Ubuntu 22.04 节点可以继续使用
- Windows 终端：Xshell 8
- macOS 终端：系统自带 Terminal 或 VS Code Terminal

生产或长期节点只使用 Git 标签中的稳定版本，不直接使用 `main`。`main` 用于后续开发，可能包含尚未发布的修改。

## 最终结构

```text
比特浏览器 → VPS公网IP:31080 → GOST SOCKS5 → 互联网
```

每台 VPS 使用同一个端口 `31080/TCP`，但必须使用不同的账号密码。节点通过名称和公网 IP 区分。

## 一、准备 VPS

推荐配置：

```text
系统：Ubuntu 24.04 LTS 64位
CPU：1核或以上
内存：1GB或以上
系统盘：20GB或以上
公网 IPv4：一个
```

准备好公网 IP、SSH 用户名、SSH 密码或私钥。旧服务器如果运行 x-ui、Xray、sing-box 或其他代理，先备份并检查端口：

```bash
systemctl --type=service --state=running --no-pager | grep -Ei 'x-ui|xray|v2ray|sing-box|gost' || true
ss -lntp
```

不要在不清楚用途时直接删除旧服务。

## 二、配置云安全组

初次连接至少需要：

```text
22/TCP      来源：固定工作出口IP/32
31080/TCP   来源：固定工作出口IP/32
```

如果工作环境必须常开 VPN，来源填写 VPN 的固定出口 IP。VPN 出口变化后，需要同步更新两条规则。不要开放 `1-65535`，不要为了方便长期使用 `0.0.0.0/0`。

## 三、从 Windows + Xshell 安装

详细界面步骤见 [Windows + Xshell 部署指南](windows-xshell.md)。登录 VPS 并看到 `root@server:~#` 后执行：

```bash
apt-get update
apt-get install -y git ca-certificates
git clone --branch v1.5.0 --depth 1 https://github.com/wkx176617-sys/GIT.git /root/socks5-toolkit
cd /root/socks5-toolkit
bash xshell-install.sh --port 31080
```

## 四、从 macOS 安装

```bash
git clone --branch v1.5.0 --depth 1 git@github.com:wkx176617-sys/GIT.git
cd GIT
./deploy.sh root@VPS公网IP --port 31080
```

脚本会上传安装文件、下载并校验固定 GOST 版本、生成独立账号密码、创建低权限服务账户并启用开机启动。

## 五、旧节点质检和覆写

在运行过老代码的服务器上，先执行：

```bash
bash preflight.sh --port 31080
```

该命令只读取信息，不会停止服务。IP 不会因代码更新而冲突，质检关注的是 Ubuntu 镜像是否
兼容、端口 `31080` 是否被占用，以及占用者是谁。

如果结论是“通过”，运行标准安装。如果明确显示“可迁移：旧 sing-box”，可以执行：

```bash
bash overwrite.sh --port 31080
```

从 Mac 本地项目部署时，对应命令是：

```bash
./deploy.sh root@VPS公网IP --port 31080 --overwrite
```

确认后程序会把旧配置备份到 `/root/gost-socks-backups/时间戳/`，读取旧 SOCKS5 用户名和
密码、停用旧 sing-box、安装 GOST，并保持原端口和凭据。安装后还会验证代理出口；安装或
验收失败时会停止新 GOST 并尝试重新启用旧服务。
如果检测到 x-ui、Xray、v2ray 或未知程序，程序会停止，不会擅自覆写。

## 六、以后查询节点

节点信息保存在对应 VPS 的 `/etc/gost-socks/node.env`，只有 root 可以读取。以后无论使用
Mac 还是 Windows，只要通过 SSH/Xshell 登录该 VPS，就可以查询：

```bash
socksctl info         # IP、端口、用户名、运行状态；密码打码
socksctl credentials  # 完整手工连接信息
socksctl export       # 手工信息和两个客户端导入链接
```

不需要在 Mac 或 Windows 维护 Git 节点清单，也不要把导出结果上传 GitHub。你仍需保存 VPS
公网 IP 和 SSH 登录凭据，否则无法进入服务器查询。

## 七、配置比特浏览器

```text
代理类型：SOCKS5
主机：VPS 公网 IP
端口：31080
用户名：安装结果中的用户名
密码：安装结果中的密码
```

时区和地理位置使用“根据 IP 自动匹配”，开启 WebRTC 保护。

## 八、验收

先在 VPS 检查：

```bash
socksctl status
socksctl check
```

再在对应比特浏览器窗口检查：

1. 公网 IPv4 必须是 VPS IP。
2. WebRTC 不得出现本地公网 IP。
3. DNS 不得出现本地运营商。
4. 时区和地理位置与代理地区合理一致。
5. 关闭并重新打开窗口后，代理仍然正常。

检测通过只代表网络配置一致，不保证任何第三方平台一定接受该 IP；云服务器 IP 也不会因为 SOCKS5 自动变成住宅 IP。

## 九、日常维护

```bash
socksctl status
socksctl check
socksctl info
socksctl logs
socksctl restart
socksctl version
```

显示完整凭据：

```bash
socksctl credentials
```

### 导入 v2rayN（Windows）

建议使用 v2rayN 官方当前稳定版。登录服务器运行：

```bash
socksctl export v2rayn
```

复制完整的 `socks://...` 一行，在 v2rayN 中使用“从剪贴板导入批量 URL”。该链接采用
v2rayN 官方 SOCKS 分享格式；如果旧版无法识别，请先从
[v2rayN 官方发布页](https://github.com/2dust/v2rayN/releases)升级。导入后先测试延迟和出口 IP。

### 导入 Shadowrocket（小火箭）

登录服务器运行：

```bash
socksctl qr shadowrocket
```

用 Shadowrocket 扫描终端二维码即可。也可以执行 `socksctl export shadowrocket`，复制
`socks5://...` 链接后在 Shadowrocket 中导入。如果服务器提示缺少 `qrencode`，执行：

```bash
apt-get update
apt-get install -y qrencode
```

如果当前 Shadowrocket 版本没有自动识别链接，使用同一命令输出的“文本配置”核对后手工新增；
格式为 `节点名称=socks5,地址,端口,用户,密码`。

二维码和链接都包含完整密码，只能由自己扫描或复制，不要通过第三方二维码网站生成。

更换 SOCKS5 密码：

```bash
socksctl rotate
```

更换后立即同步更新比特浏览器。

## 十、升级与回退

升级前阅读 [更新记录](../CHANGELOG.md) 和对应的 [版本说明](releases/)。确认兼容后切换到指定标签并重新运行安装入口。安装器会保留已有节点名称、端口和凭据。

需要回到上一稳定版本时，切换旧标签并重新安装，例如：

```bash
cd /root/socks5-toolkit
git fetch --tags
git switch --detach v1.1.0
bash xshell-install.sh --port 31080
```

不要使用 `git reset --hard` 清理服务器目录。

## 十一、可选 BBR + FQ 插件

BBR 插件位于 `addons/bbr/`，与主程序分离。主程序更新不会自动启用它。只有线路确实存在
高延迟、丢包或吞吐问题时才考虑使用：

```bash
cd /root/socks5-toolkit/addons/bbr
bash install.sh
bbrctl check
bbrctl enable
```

查看状态或恢复：

```bash
bbrctl status
bbrctl restore
```

首次启用会保存当前设置，失败时尝试回退。它不会修改 SOCKS5 节点，也不能改善 IP 质量、
DNS/WebRTC 隔离或加密。完整说明见 [BBR 插件教程](../addons/bbr/README.md)。

## 版本选择依据

- Ubuntu 24.04 LTS 的标准安全维护持续到 2029 年，适合作为新服务器的长期基础系统；Ubuntu 22.04 LTS 仍受支持到 2027 年，无需为了本工具立即升级：[Ubuntu 官方发布周期](https://ubuntu.com/about/release-cycle)。
- GOST 3.2.6 是本项目当前固定并完成校验、配置解析和端到端代理测试的版本：[GOST 官方发布页](https://github.com/go-gost/gost/releases/tag/v3.2.6)。
- Windows 教程以 Xshell 8 为准；Xshell 8 支持 SSH、远程文件管理器以及与 Xftp 的 SFTP 文件传输：[Xshell 8 官方功能](https://www.netsarang.com/en/xshell-all-features/)。
- v2rayN 的 SOCKS 分享链接格式以官方源码中的 [SocksFmt](https://github.com/2dust/v2rayN/blob/master/v2rayN/ServiceLib/Handler/Fmt/SocksFmt.cs) 为依据。
