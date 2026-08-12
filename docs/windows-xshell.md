# Windows + Xshell 部署指南

本指南适用于在 Windows 10/11 上使用 Xshell 8，通过 SSH 管理 Ubuntu VPS。Xshell 只是远程终端；安装脚本实际运行在 Linux VPS 上，因此 Windows 不需要安装 Bash、Go、GOST 或 Docker。

## 准备信息

- VPS 公网 IP
- SSH 端口，通常为 `22`
- SSH 用户名，通常为 `root`
- SSH 密码或私钥
- 云安全组允许你的工作出口 IP 访问 `22/TCP`

## 方式一：在 Xshell 中从 GitHub 下载（推荐）

### 1. 建立 SSH 会话

在 Xshell 新建会话：

```text
协议：SSH
主机：VPS 公网 IP
端口：22
用户名：root
```

登录成功后，命令提示符应类似：

```text
root@server:~#
```

如果看到的是 `Xshell:\>`，说明仍在 Windows 本地提示符，不要在那里运行 Linux 安装命令。

### 2. 下载固定版本

在服务器提示符中逐行执行：

```bash
apt-get update
apt-get install -y git ca-certificates
git clone --branch v1.5.0 --depth 1 https://github.com/wkx176617-sys/GIT.git /root/socks5-toolkit
cd /root/socks5-toolkit
```

使用固定版本标签可以避免后续代码变化影响已记录的操作流程。

### 3. 安装节点

```bash
bash xshell-install.sh --port 31080
```

节点名称会自动使用 VPS 公网 IP。安装结束会显示服务器、端口、用户名和密码。立即保存到密码管理器，不要截图发到聊天群，也不要写进 Git。

## 方式二：使用 Xshell/Xftp 上传

如果服务器无法访问 GitHub：

1. 在 Windows 下载本项目 `v1.5.0` 源码压缩包并解压。
2. 在已连接的 Xshell 中选择“窗口 → 新建文件传输”，或者打开远程文件管理器。
3. 将整个项目文件夹上传到 `/root/socks5-toolkit`。
4. 回到 Xshell 执行：

```bash
cd /root/socks5-toolkit
bash xshell-install.sh --port 31080
```

安装入口会先进行只读质检。如果旧 sing-box 已经占用 `31080` 且报告“可迁移”，确认旧配置
备份说明后运行：

```bash
bash xshell-install.sh --port 31080 --overwrite
```

它会保留旧 SOCKS5 账号密码。若报告 x-ui、Xray、v2ray 或未知程序占用端口，不要强行
覆写，先确认旧服务用途。

Xshell 8 官方支持远程文件管理器，并可与 Xftp 通过 SFTP 上传文件。

## 可选 BBR 插件

BBR 插件不会随 SOCKS5 自动启用。需要时在 Xshell 中单独执行：

```bash
cd /root/socks5-toolkit/addons/bbr
bash install.sh
bbrctl check
bbrctl enable
```

恢复原设置运行 `bbrctl restore`。完整说明见项目中的 `addons/bbr/README.md`。

## 云安全组

安装完成后只保留：

```text
22/TCP      来源：固定工作出口 IP/32
31080/TCP   来源：固定工作出口 IP/32
```

如果工作时必须常开 VPN，来源应填写 VPN 的固定出口 IP。VPN 换节点或出口变化后，需要同步修改这两条规则。

## 比特浏览器

```text
代理类型：SOCKS5
主机：VPS 公网 IP
端口：31080
用户名：安装结果中的用户名
密码：安装结果中的密码
```

检查代理后，再验证公网 IP、WebRTC 和 DNS。不要在检测通过前登录业务账号。

## Xshell 日常维护

每次通过 Xshell 登录服务器后，可以执行：

```bash
socksctl status
socksctl check
socksctl info
socksctl export
socksctl logs
socksctl restart
```

只有需要查看完整密码时才执行：

```bash
socksctl credentials
```

导入 v2rayN 时运行：

```bash
socksctl export v2rayn
```

复制输出的完整 `socks://...` 一行，在 v2rayN 中选择“从剪贴板导入批量 URL”。建议使用
[v2rayN 官方当前稳定版](https://github.com/2dust/v2rayN/releases)。导入 Shadowrocket 时运行
`socksctl qr shadowrocket`，再用手机扫码。以上链接和二维码包含完整密码，不要发给他人。

## 更新项目

第一版部署完成后不要直接跟随 `main`。需要升级时，先查看新版本说明，再执行：

```bash
cd /root/socks5-toolkit
git fetch --tags
git switch --detach 新版本标签
bash xshell-install.sh --port 31080
```

重复安装会保留现有节点名称、端口、用户名和密码。

## 常见问题

### `git: command not found`

```bash
apt-get update
apt-get install -y git ca-certificates
```

### `TCP 端口 31080 已被其他程序占用`

```bash
ss -lntp | grep :31080
```

不要直接删除程序或重装系统；先确认占用端口的是 sing-box、x-ui、Xray 还是其他服务。

### Xshell 断线后命令找不到

重新连接服务器，确认提示符是 `root@server:~#`，再执行 Linux 命令。`Xshell:\>` 和 Windows PowerShell 都不是 VPS 终端。
