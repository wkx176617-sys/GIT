# macOS 部署指南

<!-- docs-nav:start -->
[← 返回上一级：第一次搭建总路线](tutorial.md)　·　[⌂ 项目首页](../README.md)　·　[🔎 快速搜索](https://wkx176617-sys.github.io/GIT/)
<!-- docs-nav:end -->

本页只负责 Mac Terminal 连接 Ubuntu VPS 并完成安装。客户端导入、网络验收、故障维修和
核心 BBR 默认自动开启，详细性能判断由专题教程负责。

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
git clone --branch v1.12.1 --depth 1 https://github.com/wkx176617-sys/GIT.git socks5-toolkit-v1.12.1
cd "$HOME/Desktop/socks5-toolkit-v1.12.1"
./deploy.sh root@你的VPS公网IP --port 31080
```

脚本通过 SSH/SCP 上传所需模块，先做只读质检，再安装固定版本 GOST。同一次部署会复用短期
SSH 认证连接并在结束时关闭，避免每次上传都重新登录。安装成功后立即把端口、用户名和密码
保存到密码管理器。

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

## 智能识别旧节点

第三步的同一条部署命令会自动处理安全状态，不需要再复制覆写命令。已有本项目节点会保留凭据；
确认只有旧 sing-box 时会要求输入一次 `OVERWRITE`，随后备份旧配置、停用旧服务并生成全新
代理凭据。检测到 x-ui、Xray、v2ray、混合状态或未知程序时会停止，不要强行删除；进入
[故障处理教程](troubleshooting.md)。

## 可选情况：升级稳定版本

不要重复这里的部署步骤。SSH登录服务器后，统一按照[安全切换稳定版本](upgrade.md)操作。
版本切换器只接受已有本项目节点，不会把其他代理当成本项目覆写。

## 连接问题

- `zsh: command not found: git`：运行 `xcode-select --install`，完成后重新打开终端。
- SSH 超时或关闭：检查 VPS、IP、VPN 出口和 `22/TCP` 安全组。
- 密码反复失败：确认使用的是 VPS 密码，不是 GitHub 密码。
- 已进入服务器才发现位置错误：运行 `exit` 回到以 `%` 或 `$` 结尾的 Mac 提示符。
- 协议安装后异常：不要重复部署，进入[故障处理教程](troubleshooting.md)。

下一步只有一个：[客户端导入与网络验收](clients.md)。

<!-- docs-nav-bottom:start -->
[← 返回上一级：第一次搭建总路线](tutorial.md)　·　[⌂ 项目首页](../README.md)　·　[🔎 快速搜索](https://wkx176617-sys.github.io/GIT/)
<!-- docs-nav-bottom:end -->
