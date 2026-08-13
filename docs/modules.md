# 模块索引

本页用于快速判断“某个问题应该改哪里”，防止所有功能继续堆进 `socksctl` 或安装器。

## 核心模块

| 模块 | 文件 | 状态 | 常驻 | 允许依赖 | 主要测试 |
|---|---|---|---|---|---|
| Mac部署 | `deploy.sh` | 核心入口 | 否 | SSH、SCP | 参数和帮助测试 |
| Xshell部署 | `xshell-install.sh` | 核心入口 | 否 | Ubuntu基础命令 | 错误参数拦截 |
| 安装升级 | `install.sh` | 核心 | 否 | systemd、curl、基础工具 | 版本、锁、服务边界 |
| 指定版本升级 | `scripts/socks-upgrade` | 生命周期模块 | 否 | git、timeout、install | 身份、超时、确认、完整流程验收 |
| 旧节点质检 | `preflight.sh` | 核心只读 | 否 | systemd、ss | 镜像和端口分类 |
| 受控迁移 | `overwrite.sh` | 兼容模块 | 否 | install、旧sing-box | 备份和回退标记 |
| 日常入口 | `scripts/socksctl` | 核心接口 | 否 | doctor、safety | 导出、白名单、菜单 |
| 健康诊断 | `scripts/socks-doctor` | 核心诊断 | 否 | systemd、ss、curl | 只读和有限重试 |
| 安全状态 | `scripts/socks-safety` | 核心安全 | 否 | 文件系统、systemd | 快照、篡改、熔断 |
| 公网IP更新 | `scripts/socks-refresh-ip` | 生命周期模块 | 否 | safety、doctor、curl | 多目标一致、确认、回退 |
| 卸载 | `uninstall.sh` | 核心生命周期 | 否 | systemd | 确认和清理范围 |

正常运行时，上述脚本都不会驻留；只有 GOST 由 systemd 管理并持续提供 SOCKS5 服务。

## 可选插件

| 插件 | 版本 | 兼容主程序 | 自动启用 | 影响 |
|---|---:|---|---|---|
| BBR + FQ | `1.1.1` | `v1.4.0` 至当前 `v1.x` | 否 | 修改明确的 sysctl；不增加端口和常驻进程 |

插件必须留在 `addons/插件名/`，提供独立说明、安装、健康检查、恢复/卸载和兼容声明。主程序
不得直接调用或自动启用插件，并且必须登记到 `addons/README.md` 插件中心。

## 文档模块

| 目录或文件 | 用途 |
|---|---|
| `AGENTS.md` | 整个仓库必须遵守的开发规则和决策顺序 |
| `README.md` | GitHub首页，只保留定位、快速入口、模块地图和导航 |
| `addons/README.md` | 所有稳定可选插件的统一登记和用户入口 |
| `docs/tutorial.md` | 第一次搭建的单一总路线和专题入口，不复制专题细节 |
| `docs/macos.md` | Mac Terminal、SSH、部署、迁移和升级步骤 |
| `docs/windows-xshell.md` | Windows新手逐步操作和粘贴防错 |
| `docs/clients.md` | v2rayN、小火箭、比特浏览器导入和人工验收 |
| `docs/change-public-ip.md` | 同一台VPS只更换公网IP的安全流程 |
| `docs/mobile-network-check.md` | 手机Wi-Fi、流量、VPN和客户端出口检查 |
| `docs/bitbrowser-fail-closed.md` | 比特浏览器网络错误停止、白名单和破坏性验收 |
| `docs/upgrade.md` | 已有本项目节点升级到指定稳定版本的唯一教程 |
| `docs/visual-style.md` | GitHub公开界面的配色、层级、文案和图片预算 |
| `docs/troubleshooting.md` | 故障检查、恢复边界和Codex提问模板 |
| `docs/project-principles.md` | 宗旨、性能预算和功能准入规则 |
| `docs/architecture.md` | 模块职责和依赖方向 |
| `docs/releases/` | 每个稳定版本的独立档案 |

## 修改路由

- 安装失败或镜像兼容：先看 `preflight.sh`、`install.sh`。
- Xshell复制粘贴错误：先看 `xshell-install.sh` 和 Xshell 教程。
- Mac连接或本地部署错误：先看 `deploy.sh` 和 macOS教程。
- 客户端导入、二维码或浏览器验收：只改客户端专题，不复制到平台教程。
- VPS公网IP替换：改 `socks-refresh-ip` 和换IP专题，不并入安装器。
- 已有本项目节点指定版本升级：改 `socks-upgrade` 和升级专题，不复制到平台教程。
- 服务、端口、资源或线路检测：改 `socks-doctor`，不要写入安装器。
- 快照、事件、校验、熔断：改 `socks-safety`，不要让 `socksctl` 自己保存状态。
- 用户命令和菜单：改 `socksctl`，复杂实现应下沉到对应模块。
- 可选加速或未来非必要能力：进入 `addons/`，不得并入默认安装。
- 只需解释的偶发问题：优先更新教程，不增加代码。

## 模块变更验收

任何模块修改至少需要：

1. 保持已有稳定命令兼容，或按语义化版本明确迁移。
2. 没有把凭据写入日志、报告、测试或Git历史。
3. 不新增不必要的常驻进程、端口、定时任务和依赖。
4. 故障路径能够停止并输出中文说明。
5. 补充与改动风险相称的行为测试。
6. 同步模块索引、教程、更新记录和版本说明。
