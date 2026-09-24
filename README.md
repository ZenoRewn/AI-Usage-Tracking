# Usage Tracking

Author: Zeno Ren

原生 macOS AI 编程工具用量监控：菜单栏查看额度，主窗口分析项目、会话、模型和 Token。个人单机使用，数据保存在本机。

当前版本：**0.5.2 预览版（Build 12）**。独立 Swift 实现，无需 Python、Node、Docker 或云服务来运行 App。

## 下载与安装

**[下载最新 Release](https://github.com/ZenoRewn/AI-Usage-Tracking/releases/latest)** · [DMG 安装包](https://github.com/ZenoRewn/AI-Usage-Tracking/releases/download/v0.5.2/Usage-Tracking-0.5.2-arm64.dmg) · [ZIP 压缩包](https://github.com/ZenoRewn/AI-Usage-Tracking/releases/download/v0.5.2/Usage-Tracking-0.5.2-arm64.zip)

macOS 14+，**仅支持 Apple Silicon（M 系列，arm64）**，无需 Rosetta，不提供 Intel 版本。打开 DMG，把 App 拖到“应用程序”即可安装；启动后默认在**顶部菜单栏**显示图标，点击“打开工作台”查看主界面。运行 App 不需要开发环境。

本次预览版采用 ad-hoc 签名，尚未经过 Apple Developer ID 签名和公证；首次打开可能被 macOS 拦截。请按 [安装说明](INSTALL.md) 核对来源，并使用系统对该 App 提供的“仍要打开”。Release 附带 SHA-256 校验值。

MIT License · Author: Zeno Ren。第三方品牌素材的原始许可见 [第三方声明](THIRD_PARTY_NOTICES.md)。

## 构建与启动

需要 macOS 14+ 和 Swift 6.2+ / Xcode。当前已在 Apple Silicon、macOS 26.6.2、Swift 6.3.3 上构建。

```sh
swift test
zsh Scripts/build-app.sh
open "build/Usage Tracking.app"
```

构建脚本本地签名并验证 .app；会将上一份构建移到 build/previous，避免原位覆写正在运行的二进制。`zsh Scripts/package-release.sh` 构建 arm64 App、DMG、ZIP 和 SHA-256 文件。发布流程见 [发布维护说明](docs/PUBLISHING.md)。

## 已实现

- 原生 SwiftUI/AppKit 主窗口、单图标菜单栏、紧凑订阅摘要、深浅色外观与作者标识；启动仅在菜单栏运行，打开主窗口才显示 Dock 图标。
- “本机用量”对比 Codex、Claude、Copilot 的今天 / 7 / 30 天用量，与今日 Top 3 项目共享明确的 Token / 参考 USD 分段切换；点击数字打开可停留阅读的明细。
- 三张约 100pt 高的额度卡片将 30pt 单色品牌圆环与已用比例并排，保留额度状态及重置倒计时；Copilot 完整 Credits 计数在悬停或点击详情中查看。点击卡片打开独立窗口、完整计数、来源与时间；Codex/Copilot 可独立手动刷新。
- 今日 Top 3 按今天已观测 Token 排名，显示项目名、参与工具和总量。点击项目打开今天该精确路径的记录，并清除工作台原有工具和搜索筛选；同名不同路径不混淆。
- 产品标识：Codex 黑白终端标志、Claude 橙色星形标志、GitHub Copilot 紫色机器人标志；通用界面继续使用紫蓝主题。
- 今日/7天/30天/全部用量；工具和文本筛选；趋势图。
- 项目与 Git worktree 归属、会话与模型下钻、项目显示名称；项目列表显示全部参与工具的品牌标识。
- 独立“客户端与模型”页：按客户端及模型/模式分组，展示 Token、输入/输出、缓存读取占比、成本、记录/会话/项目数，支持筛选、排序、下钻与统计导出。
- 独立“模型价格”页：公价和自定义价格集中管理，按 Provider 和模型名称筛选；来源保留在内部目录、文档和导出中。
- Codex 新响应记录与旧累计记录的去重、Claude 流式用量修订、Copilot 历史累计汇总。
- SQLite 持久化、增量游标、文件替换识别、事务内保存记录与游标。
- 来源诊断：缺失、待连接、部分数据、近似日期、分叉基线缺失等。
- Codex 与 Copilot 本地只读 RPC 额度自动/手动查询；Copilot 显示总/已用/剩余 Credits 或 Requests；Claude statusLine 配额桥接。
- VS Code JSONC 设置连接向导，保留无关设置和注释并创建备份；Copilot CLI 本地遥测启动指令。
- 内置 GitHub Copilot 2026-09-09 公价：30 个模型、38 档价格；支持长上下文、缓存写入、日期后缀别名和已识别的 Claude fast mode。
- 自定义价格优先覆盖；定价覆盖率、项目成本和脱敏 CSV/JSON 导出（包含计价依据）。
- 暂停采集、刷新间隔、可选通知和登录启动。

## 客户端与模型统计

侧栏“客户端与模型”按真实来源分组：Codex App、Codex Exec、Claude Code CLI、Copilot CLI / VS Code / App 等。只展示当前筛选范围内有记录的入口；“CLI / 其他”和未识别来源保留原始不确定性。

同一模型在不同入口独立统计；同一会话切换模型只算一个客户端会话。记录数不等于完整 API 调用次数，逐次调用记录和累计/会话汇总分别计数。缓存比例为缓存读取 Token / 全部输入 Token。该页的 CSV/JSON 导出是客户端与模型统计，不含项目路径和会话 ID。

## 统一价格来源

[GitHub Copilot Models and pricing](https://docs.github.com/en/copilot/reference/copilot-billing/models-and-pricing) · 快照 2026-09-09 · USD / 百万 Token。

价格表和自定义覆盖统一放在侧栏“模型价格”中，不占用成本分析页面。

价格快照保存在 [COPILOT_PRICES_2026-09-09.json](docs/COPILOT_PRICES_2026-09-09.json)，导入脚本为 Scripts/import-copilot-prices.py。内置价格直接编译进 App，离线可用。首次升级会按新的解析版本补齐计价字段。

菜单面板中的 1 天为今天，7 / 30 天包含今天，按本地时区；没有观测记录时显示“—”，成本不足完整覆盖时标星号。

## 入口能力与当前限制

| 入口 | 当前实现 | 本机验证 |
| --- | --- | --- |
| Codex App | 自动读取实际 home 的 sessions/archived_sessions；按单响应优先统计 | 真实记录已导入并在 App 显示；当前 CLI 登录方式未返回订阅额度 |
| Claude Code CLI | JSONL Token；可选 statusLine 桥接获取配额 | 真实 Token 记录已导入；尚未修改用户现有 statusLine |
| Copilot CLI | session.shutdown 累计汇总；OTel file exporter；账户 RPC | 历史汇总已读取；账户 RPC 有响应；新遥测尚未启用 |
| Copilot VS Code | 官方 OTel 文件解析，兼容序列化 ReadableSpan 和 OTLP；会话 cwd 元数据关联 | 已对照本机内置扩展源码修正字段，fixture 通过；未启用用户设置，真实遥测待验收 |
| Copilot App | agency 来源的会话汇总解析；与 CLI 同 session 去重 | 已发现入口记录，但当前可读历史中未观察到可计量的 App 汇总；不以 CLI 用量替代 |

本地用量不是账户全部消费：其他电脑、云任务、未启用的入口、缺失历史可能没有记录。Copilot 会话汇总的日期为近似归属。Codex 分叉缺父基线的旧累计量不计入；存在新响应记录时，以可验证响应明细为准，不与旧累计记录叠加。

## 首次使用

1. 启动 App 后在菜单栏查看摘要；点击“打开工作台”查看主窗口和 Dock 图标。关闭主窗口（红色关闭按钮或 ⌘W）后自动回到菜单栏运行；若近期无记录可切换“全部”。
2. 在“数据源”查看各入口状态，必要时选择自定义数据路径。
3. 使用“连接 VS Code”检查本地遥测的四个设置，再由你点击应用。已有遥测目标会被替换为本地文件；若要保留原管道，选择已有本地导出文件。
4. Copilot CLI 通过连接窗口复制启动命令；正常使用产生记录后自动读取。
5. Claude 额度可安装 statusLine 桥接。它保存白名单额度字段，原状态栏命令继续接收相同输入。配置改动有备份；目前恢复使用对应备份文件，恢复前保留之后的新设置。
6. 启动时自动查询 Codex、Copilot；“账户额度 → 立即刷新”可手动查询。登录/Keychain 提示由对应工具处理；本 App 不读取或复制凭据。源返回异常重置时刻时显示旧快照/等待确认，不自动清零。

首次连接后需要正常使用一次工具，才能验证新增遥测。监控本身不发起模型推理任务。

## 自动刷新

后台采集随 App 启动，不依赖主窗口或菜单面板是否打开。主窗口关闭后继续自动刷新；只有菜单面板中的电源按钮或 ⌘Q 才退出 App。主窗口最小化时保留 Dock 图标，方便恢复；重复启动仍保持菜单栏模式，点击菜单面板的“打开工作台”显示主界面。此行为同样适用于登录启动。

旧版默认每 30 秒刷新本地记录，账户额度需手动查询。v0.4 默认本地 30 秒、Codex/Copilot 账户 5 分钟；设置支持 5 分钟、30 分钟、1 / 3 / 6 / 12 / 24 小时，选择后本地和账户使用相同周期。旧版 15 / 60 秒等已保存设置仍保留，账户查询最短为 5 分钟。

修改间隔立即按上次完成时间重算计划，当前请求不重叠执行。启动/恢复采集立即刷新；暂停阻止新的自动查询，正在进行的账户查询会完成。手动刷新同时覆盖本地与账户，失败保留已有快照，连续失败以 5 / 10 / 20 / 40 / 60 分钟退避，与所选间隔取较长者。账户页显示下次刷新时间和独立错误，不弹出后台错误对话框。

Claude 额度随 statusLine 实际更新，本地读取周期不能让 Claude 主动产生新快照。超过 15 分钟或达到服务返回重置时刻的额度仍标为旧快照，即使主动选择了较长刷新周期。

Copilot 在 `tokenBasedBilling` 开启时按照本机 VS Code 的展示口径，将账户返回的额度计数显示为 Credits，不从 Token/参考 USD 换算，不猜测缩放系数。缺失绝对计数显示“—”。[字段依据与边界](docs/QUOTA_SEMANTICS.md)。

菜单面板中的 Copilot / Codex 刷新箭头只查询对应账户，可在暂停自动刷新时使用；正在查询时防止重复点击。多个额度窗口采用有效窗口中最高的已用比例，无有效窗口时保留最高旧快照，不把窗口百分比相加。Credits 的 K / M / B 分别为千 / 百万 / 十亿，悬停可看完整数字。“旧快照 / 含旧窗口”提示代表存在待更新快照；刷新后若服务仍返回已过期的重置时间，提示会保留并说明原因。

今日 Top 3 从本地时区零点统计到当前时间，独立于主窗口筛选，沿用已归一化的项目路径和自定义名称。同名不同路径不合并；未归属项目的用量单独注明，不占榜单名额；不足三个项目显示实际数量。跨日打开面板时重新计算当天统计。包含会话汇总的项目以“≈”提醒日期归属近似。

“本机用量”右上角使用 Token / 参考 USD 分段控件，所有金额同步切换，Top 3 排名仍按 Token 保持稳定。点击用量数字显示明细，点击项目显示该项目今天的记录。成本沿用统一价格与自定义覆盖；金额前“≈”表示估算，“*”表示仅部分用量已定价，无价格显示“未定价”，没有记录显示“—”。

额度环在低于 80% 时为常规色，80–89% 为提醒色，90% 及以上为警示色，同时显示状态文字；通知阈值仍为原有的 90%。旧快照弱化圆环并标识，缺少额度不显示为 0%。倒计时只用于新鲜且重置时间有效的快照；重置时刻已过显示“等待新窗口”，不会自动清零。完整窗口名、服务重置时间与采集时间可在点击详情中核对。

菜单保留 macOS 26/27 的原生 Liquid Glass，较旧系统采用超薄材质。设计稿的灰阶用于半透明叠层，进度环采用随使用比例变化的薄荷绿、暖黄和红色；品牌图标保持中性色。

开发者可运行 `zsh Scripts/build-menu-preview.sh`，再打开 `build/Usage Menu Preview.app`，在独立窗口检查深浅色、正常/缺失/未就绪/旧快照/异常状态。它使用虚构数据、独立临时目录，禁用采集器与账户查询；验收范围为展示与导航，不执行连接安装或系统设置。它用于原生视图验收，不代表真实账户服务已验收。

## 数据与隐私

- 数据目录：`~/Library/Application Support/Usage Tracking/`。
- 默认源：Codex/Claude 的本地 JSONL；Copilot session-state/history-session-state；选定 OTel 文件。
- 为关联 Copilot 项目，仅只读查询本机 Copilot/VS Code session-store.db 的 `sessions.id,cwd` 字段。
- 数据库不保存提示词、回答、工具参数或凭据。元信息包含项目路径，只保存在本机；导出默认哈希化路径和会话标识。
- 额度查询通过工具自己的 RPC 联网；普通历史解析与图表离线运行。
- 所有工具及历史用量统一按当前内置 Copilot 公价折算，属于可比参考成本，不代表原始账单；自定义价格仍优先。
- 官方表未列出的历史模型仍显示“未定价”；不把 GPT-5.2 或 Claude Opus 4.6 等旧模型套用其他型号价格。
- 会话/快照汇总缺少单次上下文长度时按标准档估算；仅逐响应/调用数据应用长上下文阈值。Gemini 3.6 / 3.7 / 3.8 Flash 促销价到 2026-12-31 结束后不自动延续。
- 当前保留所有已导入历史；自动保留周期、正式多账号隔离、真实账单导入和 72 小时稳定性验收尚未完成。

## 命令行

```sh
swift run -c release usage-tracking scan
swift run -c release usage-tracking status
swift run -c release usage-tracking clients
swift run -c release usage-tracking export /tmp/usage-report.json
```

`--data-dir PATH` 可使用独立验证数据库。`quota` 查询当前 Codex RPC 额度。

## 文档

- [v0.5.2 菜单配色与进一步紧凑化](docs/RELEASE_0.5.2.md)
- [v0.5.1 紧凑额度与工作台信息层级](docs/RELEASE_0.5.1.md)
- [v0.5.0 菜单面板与交互优化](docs/RELEASE_0.5.0.md)
- [v0.4.5 Apple Silicon 公开发行版](docs/RELEASE_0.4.5.md)
- [v0.4.4 用量概览整合与成本切换](docs/RELEASE_0.4.4.md)
- [v0.4.3 今日 Top 3 项目](docs/RELEASE_0.4.3.md)
- [v0.4.2 紧凑额度卡片与手动刷新](docs/RELEASE_0.4.2.md)
- [v0.4.1 菜单栏运行与 Dock 行为](docs/RELEASE_0.4.1.md)
- [v0.4 更新与验证](docs/RELEASE_0.4.md)
- [v0.3 更新与验证](docs/RELEASE_0.3.md)
- [v0.2 更新与验证](docs/RELEASE_0.2.md)
- [系统规划](docs/SYSTEM_PLAN.md)
- [规划阅读页](docs/PLAN.html)
- [原始研究证据](docs/RESEARCH_EVIDENCE.md)
- [构建与验收记录](docs/BUILD_STATUS.md)
- [第三方声明](THIRD_PARTY_NOTICES.md)

规划文档记录完整目标；已实现能力以本 README 和构建记录为准。
