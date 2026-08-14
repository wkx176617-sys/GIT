# Windows + Xshell 部署指南

<!-- docs-nav:start -->
[← 返回上一级：第一次搭建总路线](tutorial.md)　·　[⌂ 项目首页](../README.md)　·　[🔎 快速搜索](https://wkx176617-sys.github.io/GIT/)
<!-- docs-nav:end -->

本页只负责 Windows 10/11 使用 Xshell 8 连接 Ubuntu VPS 并完成安装。客户端导入、网络验收、
故障维修和 BBR 分别由专题教程负责。

## 首次安装主线

```text
新建SSH会话 → 登录VPS → 下载固定版本 → 运行安装 → 进入客户端教程
```

只按以下四步操作。首次安装成功前不要进入后面的可选情况。

## 第一步：准备连接信息

- VPS 公网 IP；
- SSH 端口，通常为 `22`；
- SSH 用户名，通常为 `root`；
- SSH 密码或私钥；
- 云安全组允许当前工作出口 IP `/32` 访问 `22/TCP` 和 `31080/TCP`。

## 第二步：在 Xshell 登录 VPS

新建会话并填写：

```text
协议：SSH
主机：VPS公网IP
端口：22
用户名：root
```

登录成功后必须看到类似：

```text
root@server:~#
```

如果看到 `Xshell:\>`，说明仍在 Windows 本地提示符，不要运行 Linux 命令。每次只复制一个
代码框中的一行，等重新出现 `root@...#` 后再复制下一行；不要复制提示符、序号或中文说明。

## 第三步：下载并安装

在 `root@...#` 后逐行运行：

```bash
apt-get update
apt-get install -y git ca-certificates
git clone --branch v1.11.0 --depth 1 https://github.com/wkx176617-sys/GIT.git /root/socks5-toolkit-v1.11.0
bash /root/socks5-toolkit-v1.11.0/xshell-install.sh --port 31080
```

程序会先做只读质检，再安装固定版本 GOST。节点名称自动使用 VPS 公网 IP。安装成功后立即
把端口、用户名和密码保存到密码管理器，不要截图发群或上传 GitHub。

## 第四步：进入客户端教程

服务器端安装完成后，不要继续寻找其他搭建分支。直接进入
[客户端导入与网络验收](clients.md)，选择比特浏览器、v2rayN 或小火箭中的一个小节。

首次搭建到这里结束。日常再次登录服务器时只需运行：

```bash
socksctl guide
```

## 可选情况：服务器无法访问 GitHub

只有第三步的 `git clone` 明确失败时才使用：

1. 在 Windows 下载本项目 `v1.11.0` 源码压缩包并解压。
2. 使用 Xshell 远程文件管理器或 Xftp，把整个目录上传到 `/root/socks5-toolkit-v1.11.0`。
3. 回到 `root@...#` 运行：

```bash
bash /root/socks5-toolkit-v1.11.0/xshell-install.sh --port 31080
```

## 可选情况：旧节点已经占用端口

标准安装会先质检。只有报告明确显示“可迁移：旧 sing-box SOCKS5”时才运行：

```bash
bash /root/socks5-toolkit-v1.11.0/xshell-install.sh --port 31080 --overwrite
```

它会备份并保留可识别的旧凭据。检测到 x-ui、Xray、v2ray 或未知程序时会停止；不要强行
删除占用者。原因不清楚时进入[故障处理教程](troubleshooting.md)。

## 可选情况：升级稳定版本

不要重复这里的安装步骤。统一按照[安全切换稳定版本](upgrade.md)操作；版本切换器只接受已有
本项目节点，降版只恢复本机健康快照，不会执行首次安装或其他代理迁移。

## 连接问题

- 无法连接 `22`：检查 VPS 是否开机、IP、VPN 出口和云安全组。
- `git: command not found`：重新执行 `apt-get install -y git ca-certificates`。
- Xshell 断线：重新连接，确认看到 `root@...#` 后再运行服务器命令。
- 协议安装后异常：不要重复粘贴安装命令，进入[故障处理教程](troubleshooting.md)。

下一步只有一个：[客户端导入与网络验收](clients.md)。

<!-- docs-nav-bottom:start -->
[← 返回上一级：第一次搭建总路线](tutorial.md)　·　[⌂ 项目首页](../README.md)　·　[🔎 快速搜索](https://wkx176617-sys.github.io/GIT/)
<!-- docs-nav-bottom:end -->
