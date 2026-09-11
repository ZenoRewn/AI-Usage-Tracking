# 研究证据与核验边界

Author: Zeno Ren

> 本文件保留构建前的规划与研究。Usage Tracking 0.1 已开始实现，当前交付与限制见 [构建记录](BUILD_STATUS.md) 和 [README](../README.md)。

核查日期：2026-09-09。本文区分源码证据、官方文档、本机抽样与尚未验证的集成能力。不以 README 宣传、安装成功或字段存在代替端到端验收。

## 1. 参考项目快照

通过 HTTPS shallow clone 获取公开源码，仅检查文件；未执行这些项目的安装脚本或应用。临时源码保存在 /tmp/ai-tool-monitor-research/，未纳入产品目录。

| 标识 | 用户提供的仓库 | 本轮 HEAD | 提交时间 | 顶层许可 |
| --- | --- | --- | --- | --- |
| R1 | steipete/CodexBar | 928166f899471bbdcb72210641cdec91324d0154 | 2026-09-08，-07:00 | MIT，Peter Steinberger |
| R2 | stormzhang/token-tracker | 360d29c39cae046c7740be53411d574c28a713e4 | 2026-08-25，-07:00 | MIT，stormzhang |
| R3 | yanowo/usage-monitor | 34dc1c3cc6be7ec7dab2366b2ca9ceebdb7440d4 | 2026-05-27，+08:00 | MIT，lollapalooza；README 标注上游 aqua5230/usage |
| R4 | CooperJiang/coding-tool | a80f2e60cc27b1b511d2aae27b87c97082e77c75 | 2025-12-08，+08:00 | MIT |

部分 README 仍使用历史名称 yanowo/usage、CooperJiang/cc-tool；本轮从用户给定 URL 获取，并以提交 SHA 固定证据。

顶层许可证核查不等于全部依赖许可证审核。当前产物为独立研究与规划，没有复制上游实现代码；后续实际复用需保留相应原版权、许可与文件来源。

## 2. 可复核的源码定位

### R1 CodexBar

- [README 与 Mac 能力](https://github.com/steipete/CodexBar/blob/928166f899471bbdcb72210641cdec91324d0154/README.md)：macOS 14+、Swift、菜单栏、Cost Usage、Usage & Spend、更新与权限说明。
- [Swift Package](https://github.com/steipete/CodexBar/blob/928166f899471bbdcb72210641cdec91324d0154/Package.swift)：Swift tools 6.2、CodexBarCore 可导入库，但核心依赖同时涉及 SweetCookieKit、Crypto、CQuickJS 等，不能假设是纯轻量数据层。
- [Codex 项目和会话聚合](https://github.com/steipete/CodexBar/blob/928166f899471bbdcb72210641cdec91324d0154/Sources/CodexBarCore/Vendored/CostUsage/CostUsageScanner%2BProjects.swift#L16)：buildCodexSessionBreakdownsFromCache；第 88 行起为 buildCodexProjectBreakdownsFromCache。因此不能将 CodexBar 描述成“完全没有项目统计”。
- [分叉覆盖处理](https://github.com/steipete/CodexBar/blob/928166f899471bbdcb72210641cdec91324d0154/Sources/CodexBarCore/Vendored/CostUsage/CostUsageScanner%2BForkCoverage.swift)：缺少父基线的分叉在 priced totals 中被隔离，证明该场景需要明确的覆盖策略。
- [CopilotUsageFetcher](https://github.com/steipete/CodexBar/blob/928166f899471bbdcb72210641cdec91324d0154/Sources/CodexBarCore/Providers/Copilot/CopilotUsageFetcher.swift#L42)：使用 /copilot_internal/user；第 69 行解析 quotaResetDate，第 74 行处理 creditsUsed，第 95 行处理 tokenBasedBilling/unlimited，无真实百分比时不造假条。
- [CopilotUsageModels](https://github.com/steipete/CodexBar/blob/928166f899471bbdcb72210641cdec91324d0154/Sources/CodexBarCore/CopilotUsageModels.swift)：解析 credits_used、token_based_billing、quota_reset_date；区分占位 0/0、无限、缺失百分比。
- [Copilot Provider 文档](https://github.com/steipete/CodexBar/blob/928166f899471bbdcb72210641cdec91324d0154/docs/copilot.md)：Device Flow、内部用量 API、可选 Cookie 预算读取。该文档写“Reset dates are not provided”，但当前 Swift 源码已解析 quotaResetDate；规划以源码能力为准，并把账户实际是否返回重置日期留待验证。
- [Codex Provider](https://github.com/steipete/CodexBar/blob/928166f899471bbdcb72210641cdec91324d0154/docs/codex.md)：OAuth、CLI RPC、Web extras 各自的边界；本产品优先评估 CLI RPC，避免默认跨应用凭据读取。
- [Claude Provider](https://github.com/steipete/CodexBar/blob/928166f899471bbdcb72210641cdec91324d0154/docs/claude.md)：OAuth/PTY/Web/Admin API 路径及各类降级；这些不是都需要进入本产品首版。
- [MIT 许可](https://github.com/steipete/CodexBar/blob/928166f899471bbdcb72210641cdec91324d0154/LICENSE)。

### R2 token-tracker

- [README](https://github.com/stormzhang/token-tracker/blob/360d29c39cae046c7740be53411d574c28a713e4/README.md)：Claude/Codex/Kimi、本地报告、项目/模型/会话、statusLine。
- [Codex adapter](https://github.com/stormzhang/token-tracker/blob/360d29c39cae046c7740be53411d574c28a713e4/src/token_tracker/adapters/codex.py#L210)：读取最后 total_token_usage，并在第 281 行把总量写到 session_ts。这里支持“会话累计”，不能直接拿来做事件发生日的精确统计。
- 同文件从 input_tokens 扣除 cached_input_tokens，再单列 cache；明确 reasoning_output_tokens 为 output_tokens 子集。该处理帮助识别重复计数风险，但不能替代对当前新字段的验证。
- [Claude adapter](https://github.com/stormzhang/token-tracker/blob/360d29c39cae046c7740be53411d574c28a713e4/src/token_tracker/adapters/claude.py)：从 assistant.message.usage 提取 input/output/cache，优先 cwd，并用 message/request ID 去重。
- [types.py](https://github.com/stormzhang/token-tracker/blob/360d29c39cae046c7740be53411d574c28a713e4/src/token_tracker/adapters/types.py#L5)：normalize_pct 在旧重置时刻到达后返回 0。本产品不沿用“到期就自动确认已归零”，改为等待新快照。
- [MIT 许可](https://github.com/stormzhang/token-tracker/blob/360d29c39cae046c7740be53411d574c28a713e4/LICENSE)。

### R3 usage-monitor

- [README](https://github.com/yanowo/usage-monitor/blob/34dc1c3cc6be7ec7dab2366b2ca9ceebdb7440d4/README.md)：Mac/Python/Web、Claude statusLine、Codex 本地日志、价格缓存。
- [usage_statusline.py](https://github.com/yanowo/usage-monitor/blob/34dc1c3cc6be7ec7dab2366b2ca9ceebdb7440d4/usage_statusline.py)：从 stdin 接收 JSON，临时文件 + replace 原子落盘。原样存整份 JSON 的实现不直接照搬，本产品改为白名单字段。
- [codex_loader.py](https://github.com/yanowo/usage-monitor/blob/34dc1c3cc6be7ec7dab2366b2ca9ceebdb7440d4/codex_loader.py)：load_rate_limits 先试 app-server，然后 logs DB 与 session 日志。第 331 行构造 account/rateLimits/read。此行为超出了 README 对“无 API 调用”的简单描述。
- 同文件历史 loader 也有读取会话末尾累计量的实现，不能假定具备精确逐事件时间归账。
- [MIT 许可](https://github.com/yanowo/usage-monitor/blob/34dc1c3cc6be7ec7dab2366b2ca9ceebdb7440d4/LICENSE)。

### R4 coding-tool

- [README](https://github.com/CooperJiang/coding-tool/blob/a80f2e60cc27b1b511d2aae27b87c97082e77c75/README.md)：会话管理、项目、代理、动态渠道、WebSocket 实时用量。
- [codex-parser.js](https://github.com/CooperJiang/coding-tool/blob/a80f2e60cc27b1b511d2aae27b87c97082e77c75/src/server/services/codex-parser.js#L153)：通过末尾 token_count 读取累计统计。
- [codex-sessions.js](https://github.com/CooperJiang/coding-tool/blob/a80f2e60cc27b1b511d2aae27b87c97082e77c75/src/server/services/codex-sessions.js)：cwd/Git 元信息驱动项目和会话组织。
- [proxy-server.js](https://github.com/CooperJiang/coding-tool/blob/a80f2e60cc27b1b511d2aae27b87c97082e77c75/src/server/proxy-server.js)：通过被代理响应流中的 usage 统计请求消耗。这不能直接覆盖绕过代理的原生工具流量。
- [package.json](https://github.com/CooperJiang/coding-tool/blob/a80f2e60cc27b1b511d2aae27b87c97082e77c75/package.json)：Node/Express/ws，版本 2.2.0；根 test 脚本是占位失败脚本。本轮未执行测试，也不据此断言所有子目录都没有测试。
- [MIT 许可](https://github.com/CooperJiang/coding-tool/blob/a80f2e60cc27b1b511d2aae27b87c97082e77c75/LICENSE)。

## 3. 已实际打开的官方文档

| 标识 | 官方来源 | 支持的结论 |
| --- | --- | --- |
| O1 | [Codex App Server](https://learn.chatgpt.com/docs/app-server) | account/rateLimits/read、account/usage/read、活动线程 tokenUsage；账户活动字段可能 null；API-key-only 不适用该活动接口 |
| O2 | [Claude statusLine](https://code.claude.com/docs/en/statusline) | rate_limits、resets_at、cost 与上下文 JSON；本地状态栏不消耗 API Token |
| O3 | [Claude Monitoring](https://code.claude.com/docs/en/monitoring-usage) | 官方 OTel、默认内容捕获边界；transcript 内部格式会变更 |
| O4 | [Copilot 个人用量计费](https://docs.github.com/en/copilot/concepts/billing/usage-based-billing-for-individuals) | AI Credits 与模型/Token 成本；Credits 不是统一 Token 数 |
| O5 | [旧请求计费](https://docs.github.com/en/copilot/reference/copilot-billing/request-based-billing-legacy/copilot-requests) | 特定保留旧计费的年度 Pro/Pro+ 订阅边界；不可拿旧额度代表全部账户 |
| O6 | [Copilot CLI reference](https://docs.github.com/en/copilot/reference/cli-command-reference) | /usage 的模型 Token；OTel file exporter；父子 span；nano_aiu；cost 为倍率非货币 |
| O7 | [VS Code OTel](https://code.visualstudio.com/docs/agents/guides/monitoring-agents) | file exporter、chat span Token、Git 元属性、窗口与 conversation 身份、默认不捕获正文 |
| O8a | [GitHub Copilot App 概念](https://docs.github.com/en/copilot/concepts/agents/github-copilot-app) | App 的项目/多会话能力；未据此确认其本地 Token 出口 |
| O8b | [App Agent Sessions](https://docs.github.com/en/copilot/how-tos/github-copilot-app/agent-sessions) | 每会话独立 workspace；项目选择；不能忽略 worktree/隔离目录归属 |
| O9 | [Copilot Usage Metrics REST](https://docs.github.com/en/rest/copilot/copilot-usage-metrics) | 组织/企业用量报告路线；不能默认个人账户具有组织接口权限或本地项目明细 |
| O10 | [Copilot OpenTelemetry 概念](https://docs.github.com/en/copilot/concepts/enterprise/opentelemetry) | 跨客户端遥测概念与默认内容捕获边界，仍需逐客户端验证 |

取数方式：OpenAI 文档使用官方文档搜索和页面获取；Claude Markdown、GitHub 和 VS Code 文档通过 HTTPS 抓取正文。旧 Copilot 页面部分重定向到 legacy 路径，引用采用已核实的新路径。官方网页会更新，本表为当日状态。

重要的可实现配置线索（仅记录，未修改用户设置）：

- Copilot CLI：COPILOT_OTEL_FILE_EXPORTER_PATH 可开启本地 JSONL exporter；OTEL_INSTRUMENTATION_GENAI_CAPTURE_MESSAGE_CONTENT 默认为 false。
- VS Code：github.copilot.chat.otel.enabled、exporterType=file、outfile；内容捕获开关保持关闭。
- Claude：statusLine 从 stdin 接收 JSON；需兼容用户现有显示与桥接。
- Codex：先初始化 app-server，再探测只读方法支持情况；不创建推理任务。

## 4. 本机有限检查

检查仅包括版本、安装目录/应用包元数据，以及每工具至多三个近期 JSONL 文件的头部/尾部限量抽样。未打印或保存提示词、响应正文、凭据、实际 Token 数量或个人项目路径；仅输出字段名/记录类型。未读取 auth.json、Keychain 或浏览器 Cookie，未启用遥测、安装 hook、启动登录或调用账户 API。

| 项目 | 本轮观察 |
| --- | --- |
| 工作区 | 起始为空目录，没有已有应用实现 |
| 系统 | macOS 26.6.2，arm64 |
| Swift | 6.3.3；xcodebuild 可执行路径存在，尚未验证完整 Xcode 构建 |
| Claude Code CLI | 2.1.266；projects 目录存在 |
| Codex CLI | 0.145.0；sessions、archived_sessions 存在；不能代表 Codex App 内置运行时 |
| Copilot CLI | 1.0.83-5；session-state 存在 |
| VS Code | 1.136.2；尚未核实 Copilot 扩展版本及其当前 OTel 设置 |
| GitHub Copilot App | /Applications/GitHub Copilot.app，1.1.16，bundle ID com.github.githubapp |
| 名称相近的 App | /Applications/Copilot.app 为 Microsoft 365 Copilot；不能误识别为 GitHub Copilot |
| Codex 相关 App | /Applications/CodexMac.app 为 ink.zeno.codexmac，0.1；该包不证明用户所说 Codex App 的实际安装位置，应按正在使用的 App/runtime 发现 |
| 现有 CodexBar | 0.57.0 已安装；安装存在不代表已接通三家账户 |

### 字段抽样

- Claude：发现 assistant.message.usage，包含 input_tokens、output_tokens、cache_read_input_tokens、cache_creation_input_tokens，以及 cache_creation、service_tier、speed 等可选字段。
- Codex：既有 event_msg/token_count，也有顶层 token_usage_record。后者 payload 含 response_id、session_id、thread_id、turn_id、root_turn_id、usage、turn_token_usage、thread_token_usage。
- Codex Token 字段包含 input_tokens、cached_input_tokens、cache_write_input_tokens、output_tokens、reasoning_output_tokens、total_tokens。不能用老解析器忽略新字段后声称完整。
- Copilot：最近三个抽样 events.jsonl 仅观察到 session.start，包含版本/producer/sessionId/startTime。此样本不足以确认历史用量支持或不支持；需真正包含模型调用的样本或开启后的 OTel 验证。

抽样采用文件头尾窗口，可能看到同一行两次，抽样记录数不用于任何用量统计。

## 5. 尚未完成的验证

1. 五个入口的真实会话与本产品采集流水对账。
2. 本机 Codex App 的实际 home、运行时及 account/usage/read 兼容性。
3. Claude 当前账户 rate_limits 是否返回及现有 statusLine 安全组合。
4. Copilot VS Code/CLI 的实际 exporter schema、缓存包含语义与完整性。
5. Copilot App 的 OTel/文件数据出口；应用启动环境与 CLI 环境是否相通。
6. 个人 GitHub 账户当前计费模式、内部 API 可用性及本产品自有 OAuth 的权限条件。
7. 每个来源的身份关联、项目归属、跨入口重复和历史缺失范围。
8. 资源、性能、72 小时稳定性、签名安装和权限恢复。

以上是进入实施的验证任务，不是本轮已经实现的能力。
