# 公告：常用网络检测网站与使用方法

更新日期：2026-08-12

这份公告用于检查两类网络：

1. 当前电脑、PowerShell 或 Xshell 实际使用的网络。
2. 搭建完成后的比特浏览器窗口实际使用的 SOCKS5 网络。

两类检测必须分开进行。普通浏览器检测通过，不代表 PowerShell、Xshell 或比特窗口也走相同出口。

## 一、快速入口

| 用途 | 网站 | 在哪里打开 | 正常结果 |
|---|---|---|---|
| 快速查看当前出口 IP | [ipify](https://api.ipify.org/) | 普通浏览器或比特窗口 | 显示当前窗口的公网 IP |
| 中文查看 IP 和运营商 | [IPIP](https://myip.ipip.net/) | 普通浏览器、PowerShell | 显示 IP、国家、地区和运营商 |
| 综合检查 IP、IPv6、DNS、WebRTC | [BrowserLeaks IP](https://browserleaks.com/ip) | 比特窗口 | IPv4 为节点 IP；不得暴露本地 IPv6/IP |
| 单独检查 WebRTC | [BrowserLeaks WebRTC](https://browserleaks.com/webrtc) | 比特窗口 | `No Leak`，或不显示本地公网 IP |
| 单独检查 DNS | [DNSLeakTest](https://www.dnsleaktest.com/) | 比特窗口 | 不出现本地运营商 DNS |
| 一页综合复核 | [IPLeak](https://ipleak.net/) | 比特窗口 | IP、WebRTC、DNS 都不暴露本地网络 |
| 查询位置、ASN 和网络类型 | [IPinfo](https://ipinfo.io/) | 普通浏览器或比特窗口 | 国家/地区符合采购信息；记录 ASN/组织 |

检测网站属于第三方服务，结果可能因数据库、缓存和定位精度不同而不完全一致。不要只依赖一个网站判断住宅、机房、VPN 或代理属性。

## 二、检查当前设备的网络

### 普通浏览器

先在普通 Edge、Chrome 或 Safari 打开：

1. [ipify](https://api.ipify.org/)
2. [IPIP](https://myip.ipip.net/)

用途：确定浏览器当前看到的 VPN 出口或本地公网 IP。

### Windows PowerShell

浏览器插件型 VPN 可能只代理浏览器，不代理 PowerShell 和 Xshell。因此还要在 PowerShell 执行：

```powershell
curl.exe -4 https://myip.ipip.net
```

如果 IPv4 查询失败，可以先查看系统是否只能直接访问 IPv6：

```powershell
curl.exe https://myip.ipip.net
```

检测服务器 SSH 端口：

```powershell
Test-NetConnection VPS公网IP -Port 22
```

看到下面结果才表示当前 Windows 网络能够连接 SSH：

```text
TcpTestSucceeded : True
```

注意：`192.168.x.x`、`10.x.x.x` 和 `172.16.x.x` 至 `172.31.x.x` 是局域网地址，不能填入云安全组作为公网来源。

### macOS 终端

```bash
curl -4 https://api.ipify.org
echo
```

检测 SSH：

```bash
ssh root@VPS公网IP
```

## 三、检查搭建好的比特窗口

以下网站必须在“对应的比特浏览器窗口”内打开，不能用普通浏览器代替。

### 1. 出口 IPv4

打开 [ipify](https://api.ipify.org/) 或 [BrowserLeaks IP](https://browserleaks.com/ip)。

正常：

- IPv4 等于该窗口绑定的 VPS 公网 IP。
- 关闭并重新打开窗口后仍然相同。

异常：

- 显示本地宽带 IP。
- 显示工作 VPN IP，而不是 SOCKS5 节点 IP。
- 页面打不开或显示其他节点 IP。

### 2. IPv6

在 [BrowserLeaks IP](https://browserleaks.com/ip) 查看 IPv6。

正常：不显示本地 IPv6，或者显示与代理环境一致的 IPv6。

异常：出现电脑真实网络的 IPv6。SOCKS5 节点只有 IPv4 时，建议在比特窗口中禁用或保护 IPv6，避免绕过代理。

### 3. WebRTC

打开 [BrowserLeaks WebRTC](https://browserleaks.com/webrtc)。

正常：

- 显示 `No Leak`；或
- WebRTC 公网 IP 不显示；或
- 只显示代理节点 IP。

异常：显示本地宽带公网 IP、工作 VPN IP，或其他不属于该窗口的公网 IP。此时回到比特窗口设置，开启 WebRTC 保护并重启窗口。

局域网地址是否显示取决于浏览器实现；核心是不能暴露本地公网 IP。

### 4. DNS

打开 [DNSLeakTest](https://www.dnsleaktest.com/)，点击 `Standard test`。

正常：DNS 不属于当前电脑的本地电信、联通、移动或其他本地运营商。

异常：代理是海外节点，但结果出现本地运营商 DNS，说明 DNS 可能没有随代理请求发送。

DNS 服务器所在城市不一定与代理城市完全相同。公共 DNS、云服务商 DNS 或邻近地区 DNS 不一定代表泄漏，重点是不能出现本地网络的解析器。

### 5. 一页复核

打开 [IPLeak](https://ipleak.net/)，等待 IP、WebRTC 和 DNS 全部加载。

如果网站显示本地 ISP IP 或本地 ISP DNS，应停止登录业务账号，先修正网络配置。

### 6. 地区和网络类型

打开 [IPinfo](https://ipinfo.io/) 查看：

- 国家、城市、时区
- ISP/Organization
- ASN
- Hosting、VPN、Proxy 等网络属性（部分信息可能需要账号）

云服务器搭建的 SOCKS5 通常仍会被识别为托管/机房网络，不会自动变成住宅 IP。不同数据库判断不一致时，记录结果并结合采购方提供的信息确认。

## 四、推荐验收顺序

每个新比特窗口第一次使用时：

1. 用 ipify 确认 IPv4 等于 VPS IP。
2. 用 BrowserLeaks 检查 IPv6。
3. 用 BrowserLeaks WebRTC 检查公网 IP 泄漏。
4. 用 DNSLeakTest 执行 Standard test。
5. 用 IPLeak 做一次综合复核。
6. 用 IPinfo 记录国家、ASN 和网络组织。
7. 关闭并重开比特窗口，再确认一次出口 IP。

只有全部通过后，再登录业务账号。

## 五、常见误判

- 普通浏览器显示 VPN IP，不代表 PowerShell/Xshell 也经过 VPN。
- Xshell 中的 `[C:\~]$` 是 Windows 本地提示符，不是服务器。
- Linux 登录后的 `root@主机名:~#` 不一定显示公网 IP。
- DNS 城市与代理城市不同，不一定是 DNS 泄漏。
- 检测网站显示 `Hosting` 不代表 SOCKS5 配置失败，它描述的是 IP 网络属性。
- 单个网站打不开不等于代理失效，应至少用两个检测站点交叉验证。

## 六、隐私提醒

- 截图前遮挡业务账号、密码、订单号和个人信息。
- SOCKS5 密码不要输入到任何检测网站。
- 检测网站只需在浏览器中打开，不需要安装扩展或下载程序。
- 不要在公开群聊中长期分享真实节点 IP 和安全组来源 IP。
