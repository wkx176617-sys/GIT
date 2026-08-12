<div align="center">

![柔和奶油粉色的安全网络连接插画](assets/readme-hero.jpg)

# softly connected · GOST SOCKS5

**给第一次接触服务器的你，一条轻盈、清楚、可以回头的搭建路线。**

[![stable v1.7.6](https://img.shields.io/badge/stable-v1.7.6-E5B8BE?style=flat-square)](https://github.com/wkx176617-sys/GIT/releases/tag/v1.7.6)
[![checks](https://img.shields.io/github/actions/workflow/status/wkx176617-sys/GIT/validate.yml?label=checks&style=flat-square&labelColor=F3E8E4&color=A9B8A1)](https://github.com/wkx176617-sys/GIT/actions/workflows/validate.yml)
[![Ubuntu](https://img.shields.io/badge/Ubuntu-20.04_·_22.04_·_24.04-C98F96?style=flat-square)](docs/tutorial.md)
[![GOST](https://img.shields.io/badge/GOST-3.2.6-A9B8A1?style=flat-square)](https://github.com/go-gost/gost/releases/tag/v3.2.6)

[开始搭建](#开始搭建)　·　[日常使用](#日常使用)　·　[可选插件](#可选插件)　·　[遇到问题](#遇到问题)

</div>

> 当前推荐稳定版本：`v1.7.6`。生产节点只使用稳定标签，不直接部署开发中的 `main`。

每台 Ubuntu VPS 运行一个轻量 GOST SOCKS5 节点，默认使用 `31080/TCP`。Mac 或 Windows
只负责连接服务器和使用浏览器，不需要运行本项目后台服务。

## 写在开始之前

> 让第一次接触服务器的人，也能用尽量少的步骤安全搭建和维护 SOCKS5；让功能可以扩展，
> 但不让核心变成笨重的全权调度平台；让问题有记录、有回退、有复盘，项目因此持续变好。

`一条主线`　`中文防呆`　`轻量运行`　`谨慎维修`　`可恢复复盘`　`插件化扩展`

## 开始搭建

第一次使用时，只选择与你电脑对应的一条路线。

| 我使用的电脑 | 从这里开始 | 你会完成什么 |
|---|---|---|
| Mac | [macOS 部署指南](docs/macos.md) | Terminal、SSH、部署和下一步 |
| Windows | [Windows + Xshell 教程](docs/windows-xshell.md) | Xshell 登录、安装和下一步 |
| 还不知道选什么 | [第一次搭建总路线](docs/tutorial.md) | 从 VPS 准备到客户端验收 |

<details>
<summary><strong>Windows + Xshell 三行安装命令</strong></summary>

SSH 登录 Ubuntu VPS，看到 `root@...#` 后，每次只复制一行：

```bash
apt-get update && apt-get install -y git ca-certificates
git clone --branch v1.7.6 --depth 1 https://github.com/wkx176617-sys/GIT.git /root/socks5-toolkit
bash /root/socks5-toolkit/xshell-install.sh --port 31080
```

</details>

<details>
<summary><strong>macOS 已下载项目时的部署命令</strong></summary>

```bash
./deploy.sh root@你的VPS公网IP --port 31080
```

</details>

安装成功后，进入[客户端导入与网络验收](docs/clients.md)，可填写比特浏览器，也可复制
v2rayN、小火箭链接或显示二维码。

## 日常使用

以后无论使用 Mac 还是 Windows，SSH 登录对应 VPS 后只记住：

```bash
socksctl guide
```

它会打开中文菜单。熟悉后可以按需使用：

| 想做什么 | 命令 |
|---|---|
| 查看节点，隐藏密码 | `socksctl info` |
| 严格只读诊断 | `socksctl doctor --no-record` |
| 复制客户端链接 | `socksctl export` |
| 生成脱敏报告 | `socksctl report` |

## 可选插件

> 首次搭建不需要插件。没有明确问题时，保持不安装就是推荐选择。

| 当前插件 | 适合 | 不负责 | 入口 |
|---|---|---|---|
| BBR + FQ `1.1.0` | 部分高延迟、丢包 TCP 线路 | IP质量、DNS、WebRTC、加密、平台风控 | [查看插件](addons/bbr/README.md) |

所有扩展统一登记在[可选插件中心](addons/README.md)。插件不会被主程序自动安装或启用。

## 遇到问题

先不要重装、删服务或反复粘贴安装命令。依次运行：

```bash
socksctl note
socksctl doctor --no-record
socksctl report
```

把事件编号、实际现象和人工检查后的脱敏报告提供给 Codex。完整步骤见
[故障处理教程](docs/troubleshooting.md)。不要公开密码、Token、私钥、二维码或导入链接。

## 轻量，但不是简单粗暴

```text
比特浏览器 / 客户端 → VPS公网IP:31080 → GOST SOCKS5 → 互联网
```

- 正常运行只有 GOST 作为业务常驻进程。
- 不安装 Web 面板、数据库、Docker、cron、systemd timer 或额外管理端口。
- 安装和升级先保存快照；只有原因明确的白名单故障才允许自动维修。
- 端口被未知程序占用时停止，不擅自删除旧服务。
- SOCKS5 是 TCP 代理，不是加密隧道；安全组应把 `31080/TCP` 限制为工作出口 IP `/32`。

<details>
<summary><strong>查看项目模块</strong></summary>

| 模块 | 入口 | 运行方式 |
|---|---|---|
| 代理核心 | GOST `3.2.6` | 唯一常驻业务进程 |
| 安装部署 | `deploy.sh`、`xshell-install.sh` | 按需 |
| 统一管理 | `socksctl` | 按需 |
| 健康诊断 | `socks-doctor` | 按需、可严格只读 |
| 安全恢复 | `socks-safety` | 按需 |
| 可选插件 | [插件中心](addons/README.md) | 用户明确启用 |

更完整的职责和扩展边界见[模块索引](docs/modules.md)。

</details>

<details>
<summary><strong>维护与版本资料</strong></summary>

- [网络检测网站公告](docs/announcements/network-check-links.md)
- [更新记录](CHANGELOG.md) · [各版本说明](docs/releases/)
- [开发规则](AGENTS.md) · [项目宗旨](docs/project-principles.md) · [轻量架构](docs/architecture.md) · [视觉规范](docs/visual-style.md)
- [版本规则](docs/version-policy.md) · [发布清单](RELEASING.md)

</details>

<div align="center">

**不追求功能最多，只希望新手更少出错，稳定节点不被打扰。**

Ubuntu `20.04 / 22.04 / 24.04` · `amd64 / arm64` · SOCKS5 TCP

</div>
