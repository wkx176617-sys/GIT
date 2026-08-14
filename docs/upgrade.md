# 安全升级到指定版本

本页只负责“已经确认服务器运行本项目旧版，想保留节点信息并升级工具”的情况。SOCKS5协议
本身没有 `v1.9.5`；这里升级的是本项目的安装、管理、诊断和安全工具版本。

## 先分清入口

| 你的情况 | 应该去哪里 |
|---|---|
| 不知道是否搭建过 | 回到[智能安装 / 升级路线](tutorial.md) |
| `socks-upgrade --current` 能显示当前版本 | 继续本页 |
| 服务器没有 `socks-upgrade`，但有旧版 `socksctl` | 先执行下面的“首次引入升级器” |
| 使用的是 sing-box、x-ui、Xray、v2ray 或未知程序 | 不使用本页；进入[故障处理教程](troubleshooting.md) |

升级器不会首次安装、降级、迁移其他代理或改变端口、账号、密码。不能确认时会停止。

## 首次引入升级器

早期版本没有 `socks-upgrade`。在 SSH/Xshell 的 `root@...#` 后逐行运行一次：

```bash
apt-get update
```

```bash
apt-get install -y git ca-certificates
```

```bash
git clone --branch v1.9.5 --depth 1 https://github.com/wkx176617-sys/GIT.git /root/socks5-toolkit-v1.9.5
```

然后只运行这一条推荐命令：

```bash
bash /root/socks5-toolkit-v1.9.5/scripts/socks-upgrade v1.9.5
```

命令会先自动完成只读检查，显示当前版本、目标版本和保留端口；检查通过后才会提示输入
`UPGRADE-v1.9.5`。完成后服务器会安装永久命令，并统一通过 `socksctl` 管理。

## 以后升级到指定稳定版

先阅读目标[版本说明](releases/)，然后只运行这一条推荐命令：

```bash
socksctl upgrade v目标版本号
```

它会自动先执行只读检查，只有节点身份、升级方向和远端稳定标签全部通过，才会请求人工确认。
必须填写完整稳定标签，例如 `v1.9.5`；不能填写 `main`、`latest` 或省略版本号。独立命令
`socks-upgrade` 继续保留兼容，但日常推荐入口只有 `socksctl upgrade`。

如果只想提前体检而暂时不升级，可以按需运行：

```bash
socksctl upgrade --check v目标版本号
```

`--check` 严格只读，也不会要求随后执行第二条命令；它不是推荐升级流程中的必需步骤。

## 升级后验收

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

升级事务会强制核对节点名称、服务器IP记录、端口、账号和密码，任何一项意外变化都会失败
并恢复升级前状态。升级会重启一次GOST，现有连接可能短暂中断，但比特浏览器中的代理资料
不需要修改。任何验收失败都停止业务使用，运行 `socksctl report`，不要反复执行升级。

下一步只有一个：回到[客户端导入与网络验收](clients.md)确认实际出口。
