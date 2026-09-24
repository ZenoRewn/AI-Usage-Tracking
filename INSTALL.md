# 安装 Usage Tracking

Author: Zeno Ren

要求 macOS 14 或更新版本，且为 Apple Silicon（M 系列，arm64）Mac。仅提供原生 arm64 安装包，无需 Rosetta，不支持 Intel Mac。运行 App 不需要安装 Xcode、Python、Node 或 Docker。

1. 从 [GitHub Releases](https://github.com/ZenoRewn/AI-Usage-Tracking/releases/latest) 下载 `.dmg`，或选择 `.zip`。
2. DMG：打开后把 `Usage Tracking.app` 拖到 `Applications`；ZIP：解压后把 App 移到“应用程序”。
3. 从“应用程序”启动。App 默认只显示顶部菜单栏图标，**没有 Dock 图标或主窗口是正常行为**。
4. 点击菜单栏图标查看额度和用量；点击“打开工作台”查看完整分析。关闭工作台会继续在菜单栏运行。

## 首次打开

v0.5.3 使用本地 ad-hoc 签名，**尚未经过 Apple Developer ID 签名和公证**。首次下载打开时，macOS 可能提示无法验证开发者。

确认下载来自本仓库的 Release 后，可在尝试打开 App 后进入“系统设置 → 隐私与安全性”，使用该 App 对应的“仍要打开”。按系统提示完成确认。无需关闭系统的 Gatekeeper 或修改全局安全设置。

Release 附带 SHA-256 校验文件。把校验文件与 DMG、ZIP 放在同一目录后，可运行：

```sh
shasum -a 256 -c Usage-Tracking-0.5.3-arm64-SHA256SUMS.txt
```

## 数据连接

- Codex / Claude：自动发现默认本地记录；自定义目录可在“数据源”选择。
- Codex / Copilot 账户额度：需要对应 CLI 已安装并登录；只使用工具自己的额度接口，不创建推理会话。CLI 未安装时，历史用量分析仍可使用。
- Copilot VS Code / CLI 的详细用量需要按 App“数据源”中的说明连接本地遥测；无法采集的历史不会凭空补齐。
- Claude 账户额度需要可选的 statusLine 桥接；不会替你登录账号。
- 数据保存在本机 `~/Library/Application Support/Usage Tracking/`。升级时替换 App 即可，先退出旧版；数据不会随 App 替换而删除。

## English

Requires macOS 14+ on Apple Silicon (M-series, arm64). Intel Macs are not supported; Rosetta is not required. Download the arm64 DMG or ZIP from this repository's Releases. Drag the app to Applications and launch it. The app starts in the **menu bar only**; choose **打开工作台** to show its main window and Dock icon.

This preview is ad-hoc signed and is **not Apple-notarized**. After verifying the download source, use the app-specific **Open Anyway** option in System Settings → Privacy & Security if macOS blocks the first launch. Do not disable system-wide security protections.

Local history works without a development environment. Account quota lookup requires the corresponding coding-tool CLI to be installed and signed in. Copilot telemetry and Claude statusLine data require the optional connection steps inside the app. Usage data stays on this Mac.
