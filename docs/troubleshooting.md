# 手动检查、维修与向 Codex 求助教程

<!-- docs-nav:start -->
[← 返回上一级：教程导航](navigation.md)　·　[⌂ 项目首页](../README.md)　·　[🔎 快速搜索](https://wkx176617-sys.github.io/GIT/)
<!-- docs-nav:end -->

本教程适用于协议失效、不稳定、延迟升高、比特浏览器检测异常，或者程序提示“自动维修已
停止”的情况。原则是：先保存证据，再做只读检查；原因不明确时不重装、不覆写、不删除。

## 一、出现问题后先不要做什么

在没有确认原因前，不要连续运行安装脚本，不要删除配置，不要关闭云安全组，不要重装系统，
也不要反复启用 BBR。重启电脑、VPN 或 VPS 可能会让现场信息消失，应先完成下面的记录。

不要把以下内容发给 Codex、群聊或 GitHub：

- `socksctl credentials` 的输出；
- `socksctl export` 的链接或二维码；
- SOCKS5 密码、SSH 密码、私钥、GitHub Token；
- `/etc/gost-socks/node.env` 和完整 `gost.yaml`。

## 二、第一步：记录你看到的现象

登录服务器后运行：

```bash
socksctl note
```

按照提示简短输入现象，例如：

```text
比特窗口在 14:20 开始无法打开网页，VPN 开着，其他窗口正常
```

不要在描述中写账号或密码。程序会返回一个 `INC-...` 事件编号，先保存这个编号。

## 三、第二步：只检测，不维修

```bash
socksctl doctor --no-record
```

这会检查配置、权限、服务、端口、重启次数、磁盘、内存、时间同步、OOM、代理出口成功率
和响应耗时。`--no-record` 连事件档案也不写，是严格只读模式。

常见结论：

| 检测代码 | 含义 | 是否自动维修 |
|---|---|---|
| `CONFIG_MISSING` | 协议配置不完整 | 满足白名单条件时允许 |
| `CONFIG_PERMISSION` | 配置权限错误 | 满足白名单条件时允许 |
| `CONFIG_MISMATCH` | 运行配置与凭据记录不一致 | 满足白名单条件时允许 |
| `CONFIG_INVALID` | 凭据记录格式异常，无法安全判断 | 禁止 |
| `SERVICE_DOWN` | 服务没有运行，但原因尚未确定 | 单独出现时禁止 |
| `PORT_NOT_LISTENING` | 目标端口无人监听 | 单独出现时禁止 |
| `PORT_CONFLICT` | 端口被其他程序占用 | 禁止 |
| `DOCTOR_UNKNOWN` | 诊断遇到未识别错误 | 禁止 |
| `EXTERNAL_*` | 线路、DNS、VPN、安全组或检测站异常 | 禁止 |
| 资源或时间警告 | 磁盘、内存、OOM、时间同步异常 | 禁止 |

白名单要求不只是“出现一个允许代码”。必须存在明确的配置根因，并且不能同时出现端口冲突、
未知错误等阻断信号。

## 四、第三步：生成完整脱敏报告

```bash
socksctl report
```

程序会显示报告路径，例如：

```text
/root/gost-socks-report-20260812T120000Z-12345.txt
```

先自己查看：

```bash
cat /root/gost-socks-report-实际时间.txt
```

报告包括系统、服务、端口、健康检查、快照、最近事件和 GOST 日志；文件权限为 `0600`。
程序会隐藏已保存的 SOCKS5 用户名和密码，不读取 SSH 私钥。日志内容来自实际服务器，发送前
仍要人工浏览一次，确认没有自己手工写入的 Token、密码或客户资料。

报告中会保留 VPS 公网 IP，因为判断连接问题需要它。可以在与 Codex 的私密任务中提供，
不要把报告上传到公开 GitHub、群聊或论坛。

服务器最多自动保留最近 5 份报告。可以安全查询或确认后删除：

```bash
socksctl reports
socksctl report-delete
```

删除必须输入 `DELETE-REPORTS` 确认，删除后无法从本工具恢复。

## 五、自动维修应该怎样使用

```bash
socksctl heal
```

只有严格白名单通过时，程序才会恢复 `last-good` 快照并重新验收。以下情况会直接停止：

- 只有服务停止，但没有明确配置故障；
- 端口被其他程序占用；
- 诊断程序出现未知错误；
- VPN、安全组、DNS、线路或检测网站异常；
- 没有足够证据判断恢复快照能解决问题。

恢复前会校验快照。同一种故障成功自动恢复一次后，30 分钟内再次出现会触发熔断，不进行
第二次自动恢复；此时应生成报告并交给 Codex 判断。

停止时会显示中文原因和事件编号，当前协议配置不会被覆写。

## 六、只能在确认后进行的手工操作

查看可用快照：

```bash
socksctl snapshots
```

查看事件和日志：

```bash
socksctl incidents 50
socksctl incidents INC-完整编号
socksctl logs 100
```

只有确认当前配置确实损坏，并且 `last-good` 是正确状态时，才运行：

```bash
socksctl recover
```

程序要求输入 `RESTORE`。需要回到更早的健康状态时才使用：

```bash
socksctl recover previous
```

手工恢复会更换服务器端协议状态，可能导致当前 SSH 之外的代理连接中断。恢复后必须再次运行：

```bash
socksctl doctor
```

不要因为延迟高、VPN 出口变化或单个检测网站打不开而执行恢复。

## 七、SSH 本身无法连接时

服务器内命令无法处理 SSH 入口问题。先在 Windows PowerShell 检查：

```powershell
curl.exe https://myip.ipip.net
Test-NetConnection VPS公网IP -Port 22
Test-NetConnection VPS公网IP -Port 31080
```

然后检查萤光云实例是否开机，以及安全组中 `22/TCP`、`31080/TCP` 的来源地址是否等于当前
VPN 公网 IPv4 `/32`。不要为了测试把所有端口永久开放给 `0.0.0.0/0`。

## 八、怎样把完整问题提供给 Codex

先准备以下信息：

1. `socksctl report` 生成的完整报告；
2. 事件编号；
3. 问题首次出现的时间和时区；
4. 出问题前最后执行了什么，例如升级、改密码、打开 VPN 或修改安全组；
5. 是所有比特窗口异常，还是只有一个窗口异常；
6. Windows/macOS、VPN 是否开启，以及当前公网 IP 是否变化；
7. 比特窗口的 IPv4、DNS、WebRTC 检测结果或截图；
8. 已经尝试过的操作及结果。

可以直接使用下面的模板：

```text
请先诊断，不要直接让我重装或执行破坏性命令。

问题现象：
首次出现时间和时区：
事件编号：
出问题前最后一次操作：
受影响范围（一个窗口/全部窗口/SSH）：
设备系统：
VPN 状态及公网 IP 是否变化：
云安全组最近是否修改：
已经尝试的操作：
比特窗口 IPv4/DNS/WebRTC 结果：

下面是 socksctl report 的完整脱敏报告：
（粘贴报告）

请按“已确认事实、可能原因、下一步只读检查、需要我确认后才能执行的维修”四部分回答。
如果原因不能确定，请明确停止自动维修，并说明还缺少什么证据。
```

截图需要包含完整错误文字和时间，但应遮住密码、Token、私钥和二维码。不要只发送“不能用”
或一张没有上下文的局部截图；完整时间、事件编号和报告可以显著减少误判。

<!-- docs-nav-bottom:start -->
[← 返回上一级：教程导航](navigation.md)　·　[⌂ 项目首页](../README.md)　·　[🔎 快速搜索](https://wkx176617-sys.github.io/GIT/)
<!-- docs-nav-bottom:end -->
