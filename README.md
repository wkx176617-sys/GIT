<div align="center">

# GOST SOCKS5 新手部署工具

**少步骤搭建 · 中文防呆 · 轻量运行 · 可恢复复盘 · 插件化扩展**

[![稳定版本](https://img.shields.io/badge/稳定版本-v1.7.1-1677ff)](https://github.com/wkx176617-sys/GIT/releases/tag/v1.7.1)
[![自动检查](https://github.com/wkx176617-sys/GIT/actions/workflows/validate.yml/badge.svg)](https://github.com/wkx176617-sys/GIT/actions/workflows/validate.yml)
![Ubuntu](https://img.shields.io/badge/Ubuntu-20.04%20%7C%2022.04%20%7C%2024.04-E95420)
![GOST](https://img.shields.io/badge/GOST-3.2.6-2f81f7)
![运行方式](https://img.shields.io/badge/管理工具-按需运行-2ea44f)

[新手安装](#新手安装) · [日常使用](#日常使用) · [模块地图](#模块地图) · [故障求助](#故障求助) · [项目宗旨](#项目宗旨)

</div>

这是一个面向新手的轻量 SOCKS5 部署工具。每台 Ubuntu VPS 运行一个 GOST 节点，默认使用
`31080/TCP`；Mac 或 Windows 只负责 SSH/Xshell 和浏览器，不运行本项目后台服务。

> 当前推荐稳定版本：`v1.7.1`。生产节点只使用稳定标签，不直接部署开发中的 `main`。

## 项目宗旨

> 让第一次接触服务器的人，也能用尽量少的步骤安全搭建和维护 SOCKS5；让功能可以扩展，
> 但不让核心变成笨重的全权调度平台；让问题有记录、有回退、有复盘，项目因此持续变好。

| 原则 | 落地方式 |
|---|---|
| 新手防呆 | 中文菜单、参数拦截、危险操作二次确认 |
| 稳定克制 | 全面检测；只有明确白名单故障才自动维修 |
| 模块化 | 核心、诊断、安全、教程和插件边界清晰 |
| 轻量高效 | 正常运行只有 GOST 常驻，其余工具按需调用 |
| 简便实用 | 一个推荐安装入口，日常只需记住 `socksctl guide` |
| 持续复盘 | 事件编号、脱敏报告、健康快照和独立版本说明 |

完整规则见[项目宗旨与开发边界](docs/project-principles.md)和[轻量模块架构](docs/architecture.md)。

## 新手安装

### Windows + Xshell

SSH 登录 Ubuntu VPS，看到 `root@...#` 后，每次只复制一行：

```bash
apt-get update && apt-get install -y git ca-certificates
git clone --branch v1.7.1 --depth 1 https://github.com/wkx176617-sys/GIT.git /root/socks5-toolkit
bash /root/socks5-toolkit/xshell-install.sh --port 31080
```

不要复制终端前面的 `root@...#`，不要把中文说明粘贴进窗口。完整界面步骤见
[Windows + Xshell 教程](docs/windows-xshell.md)。

### macOS

在本项目目录执行：

```bash
./deploy.sh root@你的VPS公网IP --port 31080
```

完整准备、安全组和验收步骤见[完整搭建教程](docs/tutorial.md)。

## 日常使用

以后无论使用 Mac 还是 Windows，SSH 登录对应 VPS 后只需记住：

```bash
socksctl guide
```

中文菜单可以完成只读检查、记录问题、生成报告、查看快照和受控恢复。无效输入不会修改
配置。熟悉后可直接使用：

```bash
socksctl info                # IP、端口、用户名和服务状态；密码打码
socksctl doctor --no-record  # 严格只读诊断
socksctl export              # 导出 v2rayN / Shadowrocket 信息（包含密码）
socksctl report              # 生成可交给 Codex 的脱敏报告
```

## 模块地图

| 模块 | 入口 | 运行方式 | 作用 |
|---|---|---|---|
| 代理核心 | GOST `3.2.6` | 唯一常驻业务进程 | SOCKS5 TCP 转发和认证 |
| 安装部署 | `deploy.sh`、`xshell-install.sh` | 按需 | 质检、安装、升级和事务回退 |
| 统一管理 | `socksctl` | 按需 | 中文菜单和稳定命令入口 |
| 健康诊断 | `socks-doctor` | 按需、可严格只读 | 服务、端口、资源和有限外部检测 |
| 安全恢复 | `socks-safety` | 按需 | 事件、快照校验、熔断和恢复 |
| 可选插件 | `addons/bbr/` | 用户明确启用 | BBR + FQ，不被主程序自动调用 |
| 教程与版本 | `docs/` | 不运行 | 新手步骤、故障复盘和版本档案 |

详细文件、依赖和扩展规则见[模块索引](docs/modules.md)。

```text
比特浏览器 → VPS公网IP:31080 → GOST SOCKS5 → 互联网
```

协议能力为 SOCKS5 TCP；当前未启用 UDP 转发。项目不安装 Web 面板、数据库、Docker、cron
或 systemd timer，也不额外开放管理端口。

## 安全与恢复

- 默认生成独立用户名和强密码，节点名称使用 VPS 公网 IP。
- 安装器固定 GOST 版本并验证 SHA-256，不使用远程 `curl | bash`。
- 目标端口被未知程序占用时停止，不擅自删除旧服务。
- 安装、升级和密码轮换修改前保存事务快照，验收失败恢复修改前状态。
- `heal` 只处理原因明确的配置白名单故障；外部线路、VPN、安全组和未知故障只记录。
- 相同故障自动恢复一次后进入30分钟熔断，避免新旧状态反复切换。
- 标准 SOCKS5 不是加密隧道，应在云安全组把 `31080/TCP` 限制为固定工作出口IP `/32`。

不要把 `socksctl credentials`、`socksctl export`、二维码、SSH 密码、私钥或 Token 上传 GitHub。

## 故障求助

出现问题时依次运行：

```bash
socksctl note
socksctl doctor --no-record
socksctl report
```

把事件编号、实际现象和人工检查后的脱敏报告提供给 Codex。完整操作和提问模板见
[手动检查、维修与 Codex 求助教程](docs/troubleshooting.md)。

公开提交 GitHub Issue 前必须删除密码、Token、私钥、二维码、客户资料和导入链接。Bug 与
功能建议会由结构化模板引导，避免遗漏版本、时间和复现步骤。

## 文档导航

| 我想做什么 | 查看 |
|---|---|
| 第一次完整搭建 | [完整搭建教程](docs/tutorial.md) |
| 使用 Windows + Xshell | [Windows + Xshell 教程](docs/windows-xshell.md) |
| 检查网络隔离 | [网络检测网站公告](docs/announcements/network-check-links.md) |
| 手动检查或向 Codex 求助 | [故障处理教程](docs/troubleshooting.md) |
| 理解项目模块 | [模块索引](docs/modules.md) |
| 理解开发边界 | [项目宗旨](docs/project-principles.md) · [轻量架构](docs/architecture.md) |
| 查看版本变化 | [更新记录](CHANGELOG.md) · [各版本说明](docs/releases/) |
| 发布新版本 | [版本规则](docs/version-policy.md) · [发布清单](RELEASING.md) |

## 支持范围与定位

- Ubuntu 20.04、22.04、24.04，支持 `amd64` 和 `arm64`。
- 推荐新节点使用 Ubuntu 24.04 LTS `amd64`；现有22.04节点无需为本工具重装。
- 定位为单台 VPS 的轻量 SOCKS5 工具，不提供集中节点控制平台。
- 客户端 IPv4、IPv6、DNS、WebRTC 和时区必须在真实比特浏览器中人工验收。
- 功能增加不等于 `2.0`；只有不兼容的重大架构变化才升级主版本。

本项目的衡量标准不是“功能最多”，而是：**新手更少出错，稳定节点不被打扰，问题更容易
复盘，新增能力不增加无谓的后台负担。**
