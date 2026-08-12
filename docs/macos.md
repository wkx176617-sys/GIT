# macOS 部署指南

本页只负责 Mac Terminal 连接 Ubuntu VPS 并完成安装。客户端导入、网络验收、故障维修和
BBR 分别由专题教程负责。

## 首次安装主线

```text
打开终端 → 测试SSH → 下载固定版本 → 本地运行deploy.sh → 进入客户端教程
```

只按以下四步操作。首次安装成功前不要进入后面的可选情况。

## 第一步：准备连接信息

- VPS 公网 IP；
- SSH 端口，通常为 `22`；
- SSH 用户名，通常为 `root`；
- SSH 密码或私钥；
- 云安全组允许当前工作出口 IP `/32` 访问 `22/TCP` 和 `31080/TCP`。

按 `Command + 空格`，输入 `Terminal` 后回车。Mac 本地提示符通常以 `%` 或 `$` 结尾；
服务器提示符通常以 `#` 结尾。`deploy.sh` 必须在 Mac 本地提示符中运行。

## 第二步：测试 SSH

在 Mac 终端运行：

```bash
ssh root@你的VPS公网IP
```

首次连接输入 `yes`，再输入服务器密码；密码输入时不显示字符是正常现象。成功看到
`root@...#` 后运行 `exit` 回到 Mac。连接失败时先检查 VPS、IP、VPN 出口和安全组，不要继续。

## 第三步：下载并安装

在 Mac 本地提示符中逐行运行：

```bash
cd "$HOME/Desktop"
git clone --branch v1.7.5 --depth 1 https://github.com/wkx176617-sys/GIT.git socks5-toolkit
cd "$HOME/Desktop/socks5-toolkit"
./deploy.sh root@你的VPS公网IP --port 31080
```

脚本通过 SSH/SCP 上传所需模块，先做只读质检，再安装固定版本 GOST。过程中可能需要再次
输入服务器密码。安装成功后立即把端口、用户名和密码保存到密码管理器。

## 第四步：进入客户端教程

服务器端安装完成后，不要继续寻找其他搭建分支。直接进入
[客户端导入与网络验收](clients.md)，选择比特浏览器、v2rayN 或小火箭中的一个小节。

首次搭建到这里结束。以后在任何 Mac 上只要能 SSH 登录服务器，就可以运行：

```bash
socksctl guide
```

Mac 不需要长期保留本项目文件夹，也不需要保存本地节点清单。

## 可选情况：本地项目已经存在

不要重复克隆或删除现有目录。进入原项目，运行 `git status` 确认没有未保存修改，再按“升级
稳定版本”操作。不清楚现有改动用途时停止，不要清理文件夹。

## 可选情况：旧节点已经占用端口

标准部署会先质检并在不安全时停止。只有报告明确显示旧 sing-box SOCKS5 可以迁移时才运行：

```bash
./deploy.sh root@你的VPS公网IP --port 31080 --overwrite
```

检测到 x-ui、Xray、v2ray 或未知程序时不要强行删除；进入[故障处理教程](troubleshooting.md)。

## 可选情况：升级稳定版本

阅读对应版本说明后，在 Mac 项目目录逐行运行：

```bash
cd "$HOME/Desktop/socks5-toolkit"
git fetch --tags
git switch --detach 新版本标签
./deploy.sh root@你的VPS公网IP --port 31080
```

不要部署 `main`，不要使用 `git reset --hard`。健康且参数相同时会安全跳过不必要的覆写。

## 连接问题

- `zsh: command not found: git`：运行 `xcode-select --install`，完成后重新打开终端。
- SSH 超时或关闭：检查 VPS、IP、VPN 出口和 `22/TCP` 安全组。
- 密码反复失败：确认使用的是 VPS 密码，不是 GitHub 密码。
- 已进入服务器才发现位置错误：运行 `exit` 回到以 `%` 或 `$` 结尾的 Mac 提示符。
- 协议安装后异常：不要重复部署，进入[故障处理教程](troubleshooting.md)。

下一步只有一个：[客户端导入与网络验收](clients.md)。
