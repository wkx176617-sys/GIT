# 发布新版本

本文件是维护者发布清单。详细原则见 [版本维护规则](docs/version-policy.md)。

1. 确定新版本号，并更新 `VERSION`。
2. 同步更新 README、完整教程和 Windows/Xshell 教程中的推荐标签。
3. 更新 `CHANGELOG.md`。
4. 创建 `docs/releases/vX.Y.Z.md`。
5. 运行：

   ```bash
   bash scripts/release-check.sh
   ```

6. 审查差异，确认没有真实 IP、密码、密钥或节点清单。
7. 提交并推送 `main`。
8. 创建并推送带说明的标签：

   ```bash
   git tag -a vX.Y.Z -m "版本摘要"
   git push origin main
   git push origin vX.Y.Z
   ```

9. 验证远端标签指向预期提交。

已发布标签不可移动。发布错误时使用新的修订版本修复。
