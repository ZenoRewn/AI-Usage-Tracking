# Usage Tracking 0.1 · 构建与验收记录

Author: Zeno Ren

> 本文保留 v0.1 的验收记录。当前发行版见 [v0.4.5 更新](RELEASE_0.4.5.md)，用量整合见 [v0.4.4 更新](RELEASE_0.4.4.md)，今日项目排行见 [v0.4.3 更新](RELEASE_0.4.3.md)，紧凑额度见 [v0.4.2 更新](RELEASE_0.4.2.md)，Dock 行为见 [v0.4.1 更新](RELEASE_0.4.1.md)。

日期：2026-09-09。状态：可运行的本地预览版，已安装到 `/Applications/Usage Tracking.app`。

## 本轮交付

- Swift 6 / SwiftUI / AppKit 原生 App，菜单栏和主窗口共用本地数据。
- 总览、项目、会话、账户额度、成本、数据源、设置七个页面。
- Codex、Claude JSONL 增量解析，Copilot 会话汇总和 OTel 文件适配。
- 本机 SQLite 持久化、幂等与事务；项目/worktree 归属、模型分析、价格配置与导出。
- Codex 与 Copilot 的只读本地 RPC；Claude statusLine 桥接和 VS Code 配置向导。
- 自定义图标、About/界面/导出作者标识、原始研究文档。

## 已验证

| 项目 | 结果 |
| --- | --- |
| Swift 测试 | 21 项通过，0 失败 |
| Release 构建 | 成功；没有外部 Swift Package 依赖 |
| 签名 | ad-hoc 本地签名，codesign --verify --deep --strict 通过 |
| 安装启动 | Applications 中的实际 App 已启动，窗口和真实数据可见；重启保留数据库与项目显示名称 |
| 真实数据 | 已用 Codex、Claude 本地记录与 Copilot 历史汇总验证导入；公开仓库不包含个人用量数据 |
| UI 筛选 | “全部”时间范围和项目搜索已验证，显示对应项目与会话 |
| 项目详情 | Token 输入、输出、缓存及逐响应记录可见；当前项目显示名称已设为 Usage Tracking |
| UI 导出 | 实际导出 JSON 成功；验证样本含作者，未包含原始 home 路径或提示词字段 |
| Claude helper | 独立临时配置下保留原 statusLine stdout；快照未保存测试中的正文/secret 字段 |
| Copilot RPC | 命令行和安装版 UI 均获得账户百分比；未读取或复制凭据文件 |
| Codex RPC | 调用完成但当前 CLI 登录方式未返回账户额度；按不可用处理，未编造百分比 |
| 资源采样 | 一次空闲采样 RSS 164,448 KiB（约 161 MiB），CPU 0.0%；不是长期性能承诺 |
| 本地缓存查询 | 一次 Release CLI 缓存读取约 0.319 秒；不等价于全部查询的 p95 基准 |

Copilot 当前源响应的 `resetDate` 接近查询时刻，无法提供可信的未来重置倒计时。界面保留返回百分比并标记过期/等待新窗口，不自动显示余额恢复。

## 测试覆盖

- Codex 新旧事件不双计，缓存和 reasoning 不重复相加。
- Claude usage 修订取最终值，持久化白名单不包含正文。
- Copilot shutdown 累计快照不重复累加；OTel 父子 span 不双计。
- VS Code 序列化 `_spanContext`、HrTime，以及 OTLP 记录解析。
- 旧额度到期不自动归零，无限或未知配额不伪造百分比。
- 同名不同项目不合并，Git worktree 归入共享仓库。
- 重复导入、文件副本、增量追加和重新启动后幂等。
- 编码失败时用量和游标同时回滚，尾部半行不提前提交。
- JSONC 注释和无关设置保持；未知模型不当作免费；缓存价格不重复。
- 导出脱敏与 CSV 公式字符防护。

## 尚未完成的验收与限制

1. Copilot VS Code 和 CLI 的新增遥测尚未在用户真实会话中启用；源码格式与合成 fixture 已验证，不把它当成真实遥测验收。
2. GitHub Copilot App 已发现 `agency` 来源记录，但当前可读历史没有可计量的 App 汇总；App 明细支持仍需有真实用量的样本验证。
3. 未修改用户 Claude statusLine、VS Code OTel 设置、Shell 启动文件、通知权限或登录启动设置。连接入口已放在 App 中。
4. Copilot 会话汇总只支持近似日期归属；不能将整个会话拆成不存在的逐请求记录。
5. Codex 缺父基线的旧分叉累计量被排除；旧/新记录混合时优先可验证响应，可能缺少早期用量。总数为已观测量，不是账户完整账单。
6. 自动保留周期、多账号严格隔离、账单导入、完整 App 实时生命周期状态、Intel 验证、72 小时运行、睡眠/唤醒和公开分发公证尚未完成。
7. 自定义价格由用户明确配置；本版不内置可能过时的价格，不把 API 等效成本当作订阅实付。

## 开发注意

源代码位于当前工作区；产品名为 Usage Tracking，现有工作区目录名 AI_Tool_Monitor 保留不动。构建通过临时 .app 签名后再替换构建目录，旧构建保存在 build/previous，避免覆写运行中二进制。

更新 `/Applications/Usage Tracking.app` 前退出运行实例，再复制新的完整 .app。产品数据在 `~/Library/Application Support/Usage Tracking/`，与应用包分离。
