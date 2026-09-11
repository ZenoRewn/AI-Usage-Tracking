# Usage Tracking v0.4.5

Author: Zeno Ren

首个公开预览版：原生 macOS 菜单栏应用，在本机查看 Codex、Claude Code、GitHub Copilot 的已观测用量、账户额度、项目与参考成本。

- 三家账户额度横向显示，Copilot 支持独立手动刷新及已用 / 总 Credits。
- 今天 / 7 / 30 天用量与今日 Top 3 项目整合展示；点击数字切换 Token / 参考 USD，悬停查看明细。
- 主窗口提供项目、会话、客户端与模型、成本、数据源和 Provider 价格筛选。
- 启动默认只在菜单栏运行；打开工作台时显示 Dock 图标，关闭窗口后继续采集。
- 个人数据保存在本机，导出默认脱敏；MIT 许可证。

## 下载

推荐下载 `Usage-Tracking-0.4.5-arm64.dmg`，打开后将 App 拖入 Applications。也可使用 ZIP。仅支持 Apple Silicon（M 系列，arm64）和 macOS 14+，无需 Rosetta，不提供 Intel 版本；无需安装 Xcode、Python、Node 或 Docker。

**此预览版尚未经过 Apple Developer ID 签名和公证**，使用本地 ad-hoc 签名。首次打开可能出现无法验证开发者的系统提示；核对本仓库来源后，按 [安装说明](https://github.com/ZenoRewn/AI-Usage-Tracking/blob/main/INSTALL.md) 使用“系统设置 → 隐私与安全性 → 仍要打开”。不需要关闭系统全局安全功能。

下载页提供 DMG、ZIP 与 SHA-256 校验文件。启动后在顶部菜单栏寻找图标，不会自动弹出主窗口。

## 验证与范围

62 项测试通过；App 与辅助程序均仅包含 arm64，打包、签名和 Apple Silicon 启动检查通过。

账户查询需要相应 CLI 已安装并登录。Claude 配额依赖可选 statusLine 桥接；Copilot 部分入口需配置本地遥测。Token 为已采集记录，参考成本不是订阅账单，未连接入口不会虚构用量。完整范围见 README。
