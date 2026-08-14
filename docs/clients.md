# 客户端导入与网络验收

<!-- docs-nav:start -->
[← 返回上一级：第一次搭建总路线](tutorial.md)　·　[⌂ 项目首页](../README.md)　·　[🔎 快速搜索](https://wkx176617-sys.github.io/GIT/)
<!-- docs-nav:end -->

本页集中说明如何查询同一个 SOCKS5 节点、复制导入链接、显示二维码，以及在比特浏览器中
人工验收。操作系统教程不再分别维护不同版本的导入格式。

## 一次查看全部连接方式

从 Mac Terminal、Windows Xshell 或其他 SSH 工具登录对应 VPS，运行：

```bash
socksctl export
```

输出同时包含：

- VPS 公网 IP、端口、用户名和密码；
- v2rayN 可复制导入链接；
- Shadowrocket（小火箭）可复制导入链接；
- Shadowrocket 手工填写格式。

只查询运行状态且不显示完整密码时使用：

```bash
socksctl info
```

## 二维码

小火箭扫码：

```bash
socksctl qr shadowrocket
```

v2rayN 格式二维码：

```bash
socksctl qr v2rayn
```

二维码由服务器终端本地生成，不上传第三方二维码网站。v1.9.4 及以后会在安装或升级时自动
补齐所需的 `qrencode`，不会增加后台进程或网络端口。如果该系统包后来被人工删除，可以运行：

```bash
apt-get update
apt-get install -y qrencode
```

二维码显示不完整时，先放大终端窗口；仍无法扫描就运行 `socksctl export` 复制完整链接。

## v2rayN

登录 VPS 后运行：

```bash
socksctl export v2rayn
```

复制完整的 `socks://...` 一行，在 v2rayN 中选择“从剪贴板导入批量 URL”。如果客户端无法
识别，先升级 [v2rayN 官方稳定版](https://github.com/2dust/v2rayN/releases)，仍不兼容时
使用同一命令显示的地址、端口、用户名和密码手工添加 SOCKS5。

## Shadowrocket（小火箭）

运行 `socksctl qr shadowrocket` 后直接扫码，或运行：

```bash
socksctl export shadowrocket
```

复制完整的 `socks5://...` 链接导入。如果当前客户端版本无法识别，按输出中的文本配置手工
新增；格式为 `节点名称=socks5,地址,端口,用户,密码`。

## 比特浏览器

运行 `socksctl credentials` 取得完整字段后填写：

```text
代理类型：SOCKS5
主机：VPS 公网 IP
端口：31080
用户名：安装结果中的用户名
密码：安装结果中的密码
```

时区和地理位置选择“根据 IP 自动匹配”，并开启 WebRTC 保护。每个浏览器环境应使用预先
规划的独立节点，不要在验收完成前登录业务账号。

首次配置还必须完成[比特浏览器代理失效时避免裸连](bitbrowser-fail-closed.md)：启用网络不通
停止打开、清空代理直连白名单，并使用无业务账号的测试窗口做一次错误端口验收。

## 人工验收

先在 VPS 运行：

```bash
socksctl status
socksctl check
```

再在对应客户端或比特浏览器中确认：

1. 公网 IPv4 是目标 VPS IP；
2. WebRTC 没有暴露本地公网 IP；
3. DNS 没有出现本地运营商；
4. 时区和地理位置与代理地区合理一致；
5. 关闭并重新打开客户端后代理仍然正常。

隔离验收通过后，还应在同一窗口记录下载、上传、延迟、抖动和丢包基线。简单 IP 页面或
`socksctl check` 成功不等于复杂网页和大流量正常；速度差、网页只显示骨架或多个客户端同时
异常时，统一进入[网络性能与核心 BBR](network-performance.md)，不要直接更换协议配置。

服务器日志中的客户端来源 IP 只说明连接从哪里进入 SOCKS5；目标网站看到的最终出口仍以浏览器
内的公网 IP 检测为准。使用本地 VPN 中转时也必须同时核对最终出口没有改变。

推荐检测入口见[网络检测网站公告](announcements/network-check-links.md)。检测通过只代表当前
网络配置一致，不代表第三方平台一定接受该 IP，也不会把云服务器 IP 变成住宅 IP。

手机使用小火箭或检查 Wi-Fi、流量和 VPN 时，使用[手机网络环境检查](mobile-network-check.md)。

## 凭据安全

二维码和导入链接都包含完整密码，等同于 SOCKS5 账号凭据：

- 不上传 GitHub、网盘或第三方二维码网站；
- 不截图发群或粘贴到公开 Issue；
- 不把完整输出直接提供给 Codex；
- 怀疑泄露时运行 `socksctl rotate`，并立即更新所有客户端。

验收失败时不要切换其他搭建分支，下一步只进入[故障处理教程](troubleshooting.md)。

<!-- docs-nav-bottom:start -->
[← 返回上一级：第一次搭建总路线](tutorial.md)　·　[⌂ 项目首页](../README.md)　·　[🔎 快速搜索](https://wkx176617-sys.github.io/GIT/)
<!-- docs-nav-bottom:end -->
