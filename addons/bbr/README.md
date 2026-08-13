# 可选 BBR + FQ 加速插件

插件版本：`1.1.1`

主程序兼容范围：`v1.4.0` 至所有 `v1.x` 版本；不承诺兼容未来 `v2.x`。

本插件与 SOCKS5 主程序完全分离。主程序的 `deploy.sh`、`install.sh`、`xshell-install.sh`、
质检和覆写流程都不会调用本插件。插件不增加端口、不修改 GOST 配置、不更换节点 IP 或凭据。

## 适用范围

- Ubuntu 20.04、22.04、24.04
- `amd64`、`arm64`
- 内核已经提供 BBR
- 跨国 TCP 线路确实存在高延迟、丢包或吞吐下降

正常使用 `cubic` 时不必启用。BBR 不能改善 IP 质量、DNS/WebRTC 隔离或 SOCKS5 加密。

## 安装（默认不启用）

在已经下载主项目的服务器中执行：

```bash
cd /root/socks5-toolkit/addons/bbr
bash install.sh
bbrctl check
```

确认质检通过后：

```bash
bbrctl enable
```

启用时会保存当时的拥塞算法和队列规则，然后写入独立文件
`/etc/sysctl.d/99-gost-socks-bbr.conf`。无需重启服务器；重新建立的 TCP 连接会使用新设置。

## 查询

```bash
bbrctl status
bbrctl health
```

理想结果：

```text
当前拥塞算法：bbr
当前队列规则：fq
插件状态：已写入持久配置
```

## 恢复与卸载

只恢复首次启用前的设置：

```bash
bbrctl restore
```

根据提示输入 `RESTORE-BBR`；非交互环境会停止，不会直接改动网络设置。

恢复并卸载插件：

```bash
cd /root/socks5-toolkit/addons/bbr
bash uninstall.sh
```

根据提示输入 `UNINSTALL-BBR`。卸载会先恢复原设置，恢复失败时不会继续删除插件。

卸载不会触碰 GOST、SOCKS5 凭据、端口、安全组或 sing-box 备份。

重复执行 `enable` 或 `restore` 会被识别并安全跳过。持久配置存在但实际设置失效时运行：

```bash
bbrctl repair
```

如果 `/etc/sysctl.conf` 或 `/etc/sysctl.d/` 中另有文件管理相同参数，插件会停止启用或修复，
避免两个加速工具反复覆盖。插件不会创建定时“重复加速”任务。

## 更新规则

主项目每次发布新 `v1.x` 时，发布检查会同时检查本目录的脚本语法、插件版本和兼容声明。
插件若发生变化，必须在主项目 `CHANGELOG.md` 和该次版本说明中记录；真实服务器是否启用
插件仍由用户单独决定，不会随主程序升级自动开启。
