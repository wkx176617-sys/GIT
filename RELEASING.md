# 发布新版本

本文件是维护者发布清单。仓库级约束见[开发规则](AGENTS.md)，详细原则见[项目宗旨](docs/project-principles.md)、
[轻量模块架构](docs/architecture.md)和[版本维护规则](docs/version-policy.md)。

1. 确定新版本号，并更新 `VERSION`。
2. 同步更新 README、完整教程、macOS 和 Windows/Xshell 教程中的推荐标签。
3. 更新 `CHANGELOG.md`。
4. 创建 `docs/releases/vX.Y.Z.md`。
5. 如果 `addons/` 中插件发生变化，更新插件版本、兼容声明、独立教程和主版本说明。
6. 在版本说明中加入“复杂度与性能影响”，逐项说明常驻进程、端口、定时任务、依赖、步骤和模块耦合。
7. 确认新功能无法只用教程解决；非核心功能优先放入 `addons/`，主程序不自动启用插件。核心
   BBR 变更必须验证支持、冲突停止、原设置保存、显式关闭和卸载恢复。
8. 确认新手总路线和平台教程保持单一下一步，重复操作只保留一个专题来源。
9. 新手导航发生变化时先运行 `scripts/docs-navigation --write`，确认搜索失效时仍能进入
   `docs/navigation.md` 文字后备导航。
10. 运行：

   ```bash
   bash scripts/release-check.sh
   ```

11. 审查差异，确认没有真实 IP、密码、密钥或节点清单。
12. 提交并推送 `main`。
13. 创建并推送带说明的标签：

   ```bash
   git tag -a vX.Y.Z -m "版本摘要"
   git push origin main
   git push origin vX.Y.Z
   ```

14. 等待 `main` 和标签触发的 GitHub Actions 全部通过；失败时不得继续发布。
15. 验证远端标签指向预期提交。
16. 确认标签工作流已经使用对应 `docs/releases/vX.Y.Z.md` 创建 GitHub Release；若自动创建失败，
    排查工作流后重新运行，禁止跳过校验手工上传未知构建物。
17. 打开 Release 页面，确认标题、版本说明、标签链接正确，并将当前版本标记为 Latest。
18. 从 README 的稳定版本徽章打开 Release，验证公开链接可访问；导航有变化时同时验证 GitHub
    Pages 搜索、返回上一级、项目首页和文字后备入口。

已发布标签不可移动。发布错误时使用新的修订版本修复。
