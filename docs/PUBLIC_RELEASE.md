# Usage Tracking v0.5.0（Build 10）

Author: Zeno Ren

这次更新让菜单栏中的额度更易读、详情更易查看。继续支持 Codex、Claude Code、GitHub Copilot 的本机用量、账户额度、项目与参考成本。

- 三张额度卡片采用 44pt 圆环和居中品牌，直接显示额度压力、窗口、重置倒计时及旧快照/失败状态；Copilot 保留已用 / 总 Credits。
- 点击额度卡片展开各窗口、完整计数、来源和时间；支持独立刷新与 Esc 关闭。
- 今天 / 7 / 30 天用量使用明确的 Token / 参考 USD 分段切换；点击数字查看明细，点击今日 Top 3 项目查看该项目今天的记录。
- 保持未知用量、未定价和真实零值的区别；修复倒计时跨天舍入及异常重置时间导致的崩溃。
- 启动默认只在菜单栏运行；打开工作台时显示 Dock 图标，关闭窗口后继续采集。
- 个人数据保存在本机，导出默认脱敏；MIT 许可证。

## 下载

推荐下载 `Usage-Tracking-0.5.0-arm64.dmg`，打开后将 App 拖入 Applications。也可使用 ZIP。仅支持 Apple Silicon（M 系列，arm64）和 macOS 14+，无需 Rosetta，不提供 Intel 或 Universal 版本；无需安装 Xcode、Python、Node 或 Docker。

升级前退出旧版，替换 App 即可；本机历史数据和配置继续保留。

**此预览版尚未经过 Apple Developer ID 签名和公证**，使用本地 ad-hoc 签名。首次打开可能出现无法验证开发者的系统提示；核对本仓库来源后，按 [安装说明](https://github.com/ZenoRewn/AI-Usage-Tracking/blob/main/INSTALL.md) 使用“系统设置 → 隐私与安全性 → 仍要打开”。不需要关闭系统全局安全功能。

下载页提供 DMG、ZIP 与 SHA-256 校验文件。启动后在顶部菜单栏寻找图标，不会自动弹出主窗口。

## 验证与范围

68 项本地测试通过；App 与辅助程序均仅包含 arm64，构建、签名与实际启动已检查。深浅色、额度边界状态、详情和项目跳转在复用生产视图的隔离原生样例中验证；这些验证不等于所有真实账户服务已完成端到端验收。

账户查询需要相应 CLI 已安装并登录。Claude 配额依赖可选 statusLine 桥接；Copilot 部分入口需配置本地遥测。Token 为已采集记录，参考成本不是订阅账单，未连接入口不会虚构用量。完整范围见 README。
