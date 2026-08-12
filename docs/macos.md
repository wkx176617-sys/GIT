# macOS 部署指南

本指南只讲 Mac 上的准备、部署和日常连接。VPS、安全组、客户端导入和故障原理的完整说明
分别放在专题文档中，避免在一个页面重复整套流程。

## 准备信息

- Ubuntu VPS 公网 IP；
- SSH 端口，通常为 `22`；
- SSH 用户名，通常为 `root`；
- SSH 密码或私钥；
- 云安全组允许当前工作出口 IP 访问 `22/TCP` 和 `31080/TCP`。

如果工作时必须常开 VPN，安全组来源应填写 VPN 的固定出口 IP `/32`。VPN 出口变化后要同步
更新规则。完整安全组说明见[完整搭建教程](tutorial.md)。

## 一、打开 Mac 终端

按 `Command + 空格`，输入“终端”或 `Terminal` 后回车。也可以使用 VS Code Terminal。

Mac 本地提示符通常以 `%` 或 `$` 结尾，例如：

```text
mcqueen@MacBook-Pro ~ %
```

服务器提示符通常以 `#` 结尾，例如：

```text
root@server:~#
```

`deploy.sh` 必须在 Mac 本地项目目录运行，不要粘贴到已经登录的服务器窗口。

## 二、先测试 SSH

在 Mac 终端运行：

```bash
ssh root@你的VPS公网IP
```

首次连接输入 `yes`，再输入服务器密码。密码输入时不会显示字符，这是正常现象。成功看到
`root@...#` 后运行：

```bash
exit
```

如果连接超时或被关闭，先检查 VPS 是否开机、IP 是否正确，以及安全组 `22/TCP` 的来源 IP；
不要继续运行部署脚本。

## 三、下载固定版本

在 Mac 本地提示符中逐行运行：

```bash
cd "$HOME/Desktop"
git clone --branch v1.7.3 --depth 1 https://github.com/wkx176617-sys/GIT.git socks5-toolkit
cd "$HOME/Desktop/socks5-toolkit"
```

如果 `socks5-toolkit` 文件夹已经存在，不要重复克隆或删除它，直接进入该目录并先查看当前
版本。生产节点只使用稳定标签，不直接部署 `main`。

## 四、部署新节点

仍在 Mac 本地项目目录时运行：

```bash
./deploy.sh root@你的VPS公网IP --port 31080
```

脚本会通过 SSH/SCP 上传所需模块，在服务器执行只读质检，然后安装固定版本的 GOST。根据
SSH 设置，过程中可能需要输入服务器密码。节点名称自动使用 VPS 公网 IP。

安装成功后立即把端口、用户名和密码保存到密码管理器。不要截图发群，也不要上传 GitHub。

## 五、旧节点迁移

如果同一台服务器以前运行过 sing-box、x-ui、Xray、v2ray 或其他代理，仍先运行标准部署命令：

```bash
./deploy.sh root@你的VPS公网IP --port 31080
```

标准部署会先执行只读质检；质检不通过时不会进入安装。只有结果明确显示旧 sing-box SOCKS5
可以迁移时，才运行：

```bash
./deploy.sh root@你的VPS公网IP --port 31080 --overwrite
```

检测到 x-ui、Xray、v2ray 或未知占用者时程序会停止。不要为了继续安装而手动删除未知服务。

## 六、查询和维护

以后在任何 Mac 上都不需要保留本项目文件夹，只要能 SSH 登录服务器即可：

```bash
ssh root@你的VPS公网IP
socksctl guide
```

常用只读命令：

```bash
socksctl info
socksctl doctor --no-record
socksctl export
```

复制链接、显示二维码、配置比特浏览器及验收网络见
[客户端导入与网络验收](clients.md)。原因不明时见[故障处理教程](troubleshooting.md)。

## 七、升级

先阅读更新记录和新版本说明，再在 Mac 项目目录获取指定稳定标签。不要对服务器或本地仓库
使用 `git reset --hard`：

```bash
cd "$HOME/Desktop/socks5-toolkit"
git fetch --tags
git switch --detach 新版本标签
./deploy.sh root@你的VPS公网IP --port 31080
```

重复部署会先检查参数和健康状态；节点健康且参数相同时会安全跳过不必要的覆写。

## 常见问题

### `zsh: command not found: git`

运行 `xcode-select --install`，按 macOS 提示安装命令行工具，完成后重新打开终端。

### `Permission denied` 或密码反复失败

确认 SSH 用户名、密码和服务器允许的认证方式。不要把 GitHub 密码当作 VPS 密码。

### 已经进入服务器才发现命令位置不对

运行 `exit` 回到以 `%` 或 `$` 结尾的 Mac 本地提示符，再执行 `deploy.sh`。
