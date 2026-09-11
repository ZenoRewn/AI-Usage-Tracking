# 发布维护说明

Author: Zeno Ren

1. 更新 Resources/Info.plist、UsageCoreVersion、README、INSTALL 和 PUBLIC_RELEASE 中的版本与说明。
2. `swift test` 验证后提交源代码。从干净的 checkout 构建，不从包含私人数据或旧 QA 包的目录打包。
3. 执行 `zsh Scripts/package-release.sh`，在 dist 中获得 arm64 DMG、ZIP 和 SHA-256 文件。
4. 检查两份可执行文件的 仅包含 arm64 架构、codesign 验证、DMG 挂载与 ZIP 解包内容，再实际启动验证。发布包不包含测试数据库、个人日志、截图或凭据。
5. 推送与应用版本一致的标签，例如 v0.4.5；用 GitHub Release 上传 dist 中的三个产物。发布后核对远程提交、附件大小及下载后的 SHA-256。

GitHub Actions 的 Build and test 工作流运行测试和 arm64 构建。Build draft release 可手动选择已有版本标签，重新测试、打包并创建草稿 Release，供维护者检查后发布。

## 签名

未设置 USAGE_SIGN_IDENTITY 时使用 ad-hoc 签名。若配置了 Developer ID Application 证书，可通过该环境变量指定证书；私钥及公证凭据应保存在 Keychain / Actions secrets，不进入仓库。

Developer ID 签名后仍须使用 Apple notarytool 提交并等待通过、stapler 装订，再重新生成分发文件及校验值。当前脚本不会将未经公证的包描述为已公证；公开预览版安装说明明确保留首次运行的系统确认步骤。
