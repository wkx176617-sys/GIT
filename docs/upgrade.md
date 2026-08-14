# 安全切换稳定版本

本页只负责“已经确认服务器运行本项目，想保留节点信息并切换工具版本”的情况。SOCKS5 协议
本身没有 `v1.10.0`；这里切换的是本项目的安装、管理、诊断和安全工具版本。

## 先分清入口

| 你的情况 | 应该去哪里 |
|---|---|
| 不知道是否搭建过 | 回到[智能安装 / 升级路线](tutorial.md) |
| `socks-upgrade --current` 能显示当前版本 | 继续本页 |
| 服务器没有 `socks-upgrade`，但确认是本项目早期节点 | 先执行下面的“首次引入版本切换器” |
| 使用的是 sing-box、x-ui、Xray、v2ray 或未知程序 | 不使用本页；进入[故障处理教程](troubleshooting.md) |

版本切换器不会首次安装、迁移其他代理或改变端口、账号、密码。不能确认节点身份时会停止。

## 首次引入版本切换器

早期版本没有 `socks-upgrade`。在 SSH/Xshell 的 `root@...#` 后逐行运行一次：

```bash
apt-get update
```

```bash
apt-get install -y git ca-certificates
```

```bash
git clone --branch v1.10.0 --depth 1 https://github.com/wkx176617-sys/GIT.git /root/socks5-toolkit-v1.10.0
```

然后只运行这一条推荐命令，自动选择 GitHub 最新稳定标签：

```bash
bash /root/socks5-toolkit-v1.10.0/scripts/socks-upgrade latest
```

命令会先自动完成只读检查，通过后直接执行，不再要求输入第二个确认口令。完成后服务器会安装
永久命令，今后统一通过 `socksctl` 管理。

## 已安装节点：直接到最新版

先阅读最新[版本说明](releases/)，然后复制这一条推荐命令：

```bash
socksctl upgrade latest
```

`latest` 只从 `v主版本.次版本.修订版本` 格式的稳定 Git 标签中选择最高版本，不使用 `main`
或预发布名称。输入正式命令即视为授权；程序仍先检查节点身份、目标版本和保留字段，但不重复
询问。指定稳定标签只需要一次下载，不再先查询同一标签再下载。

## 可选：切换到指定新版本

需要固定版本时，在最新版命令旁使用：

```bash
socksctl upgrade v目标版本号
```

必须填写完整稳定标签，例如 `v1.10.0`，不能填写 `main` 或省略版本号。

## 可选：恢复到较旧版本

降版只允许恢复本机已经保存且完整性、节点身份、端口和凭据全部一致的健康快照。先查看：

```bash
socksctl snapshots
```

确认 `last-good` 或 `previous-good` 显示目标旧版本后，在同一条命令中明确授权：

```bash
socksctl upgrade v旧版本号 --allow-downgrade
```

命令不会再要求第二个口令，也不会下载旧安装包。没有匹配的健康快照时会停止，不能强制覆盖。

## 可选：只读体检

只想提前检查而暂时不切换时，按需运行其中一种：

```bash
socksctl upgrade --check latest
```

```bash
socksctl upgrade --check v目标版本号
```

`--check` 严格只读，不是正式切换的必需步骤。

## 切换后验收

逐行运行：

```bash
socksctl version
```

```bash
socksctl doctor --no-record
```

```bash
socksctl check
```

事务会强制核对节点名称、服务器 IP 记录、端口、账号和密码，任何一项意外变化都会失败并恢复
切换前状态。核心版本未变化时复用现有 GOST，避免重复下载；必须更新核心时才下载官方归档并
校验 SHA-256。切换会重启一次 GOST，现有连接可能短暂中断，但比特浏览器代理资料不需要修改。

下一步只有一个：回到[客户端导入与网络验收](clients.md)确认实际出口。
