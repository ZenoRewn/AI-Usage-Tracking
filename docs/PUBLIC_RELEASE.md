# Usage Tracking v0.5.3（Build 13）

Author: Zeno Ren

修复真实使用中的 Copilot 额度环颜色与状态栏窗口圆角。

- Copilot 刚查询到的低用量不再因为异常的重置时间被误判为旧快照、显示灰环。用量按实际比例着色，无法确认的下次重置时间单独提示。
- 仍保留真正的过期保护：超过 15 分钟未更新，或跨过已确认的未来重置时间，依然显示旧快照；不自动清零、不补造重置日期。
- 状态栏宿主窗口改为透明背景、20pt 连续圆角裁剪和系统阴影，保留 macOS 26/27 原生 Liquid Glass，消除玻璃内容外的方形底板。
- 保留约 100pt 高的紧凑额度卡片、按比例绘制的进度环、Token / 参考 USD 切换和项目下钻。

## 下载与升级

仅提供 Apple Silicon（arm64）的 DMG、ZIP 和 SHA-256 校验文件。需要 macOS 14+，无需 Rosetta；不提供 Intel 或 Universal 安装包。

推荐下载 `Usage-Tracking-0.5.3-arm64.dmg`。退出旧版后替换 Applications 中的 App，本机历史和配置保留。

**当前为 ad-hoc 签名预览版，未完成 Apple Developer ID 签名和公证。** 首次打开如被系统拦截，请核对来源并遵循 [安装说明](https://github.com/ZenoRewn/AI-Usage-Tracking/blob/main/INSTALL.md)。

## 验证与范围

74 项本地测试通过；修复后的模型已通过真实 Copilot 只读额度查询检查。macOS 27 的原生无标题状态栏样例验证了圆角、玻璃材质和低用量绿环；样例数据与真实账户数据分开。

账户查询需要对应 CLI 已安装并登录；Claude 额度依赖可选 statusLine 桥接，Copilot 部分入口需本地遥测。Token 仅来自已采集记录，参考成本不是订阅账单。
