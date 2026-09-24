# Copilot 账户额度字段依据

Author: Zeno Ren

检查日期：2026-09-09。账户额度独立于本地 Token 和统一参考价格。

对照版本：本机 VS Code 1.136.2。workbench 文件 SHA-256：`7ca53e1a79fe46d5288d568a41a1cc22d7a8b33c139ed6174989194a1f91a718`。函数名和本地化索引仅对应此版本。

## 数据入口

应用通过本机 Copilot CLI 的 `account.getQuota` 只读 RPC 查询当前工具已登录账户。请求不创建会话、不触发推理、不读取认证文件。`quotaSnapshots` 中的 `entitlementRequests`、`usedRequests`、`remainingPercentage`、`tokenBasedBilling` 是本次解析所用的计费字段。

Copilot SDK 的部分类型声明仍以 Requests 描述这些字段；不能只凭字段名字或套餐价格推断 Credits 比例。因此本次对照了本机 VS Code 实际的账户额度显示实现：

- 文件：`/Applications/Visual Studio Code.app/Contents/Resources/app/out/vs/workbench/workbench.desktop.main.js`。
- `oJi`：将 RPC `entitlementRequests` 直接映射至 `entitlement`，将 `entitlementRequests - usedRequests` 映射至 `quotaRemaining`；保留 `tokenBasedBilling` 为 `usageBasedBilling`。
- `ton`：把 premium quota 的 `tokenBasedBilling` 传入账户的 `usageBasedBilling`。
- `renderUsageContent`：开启 usage-based billing 时使用本地化标签 `Credits`。
- `yBi` 和 `createQuotaIndicator`：以 `entitlement - quotaRemaining` / `entitlement` 展示已用/总量，`quotaCreditsFormatter` 仅格式化数字至两位小数，没有单位缩放。
- 同目录 `out/nls.messages.json` 中 `11388 = Credits`，`11416 = {0} / {1}`。

本 App 独立实现相同映射，不复制上述代码；使用 RPC 的 `usedRequests` 原值而非由百分比反推。若 used 超过 total，保留已用值、剩余显示 0。未提供的计数显示缺失，绝不自动记为 0。

## 边界

- `tokenBasedBilling = true` 显示 Credits；其他情形按 RPC 的 Requests 口径。
- 只显示有有限正总量与有效百分比的窗口；无限额度不伪装成有限 Credits 总量。
- 不将总量大小解释为 Token，不套用套餐定价来缩放，不折算金额。
- SDK `AutopilotObjectiveCreditLimit.creditsUsedNanoAiu` 是单个 autopilot 目标的预算，与账户总额度无关，未用于本 App 的账户计数。
- 重置时间原样保留。Copilot RPC 若返回不晚于本次采集时刻的 `resetDate`，它不能作为已确认的下次重置时间：近期用量仍按返回比例显示，重置时间单独标为待确认，不自造月度重置时间。
- 若采集之后跨过一个当时有效的未来重置时刻，仍显示旧快照；超过 15 分钟未更新也仍为旧快照。其他来源的过期判断保持原有规则。
- 未确认的重置提示不作为通知窗口标识，避免每次查询返回不同的当前时间时重复触发提醒。
- 每次查询仅代表当前登录账户；未实现多个账号历史的隔离或合并。
