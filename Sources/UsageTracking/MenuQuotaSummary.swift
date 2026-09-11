// Author: Zeno Ren
import Foundation
import UsageCore

/// Independent quota windows are never summed into a fictional account percentage.
struct MenuQuotaSummary {
    let tool: Tool
    let windows: [QuotaWindow]
    let now: Date
    init(tool: Tool, quotas: [QuotaWindow], now: Date = Date()) {
        self.tool = tool
        self.now = now
        windows = quotas.filter { $0.tool == tool && $0.usedPercent.isFinite && $0.usedPercent >= 0 }.sorted { $0.id < $1.id }
    }
    var primary: QuotaWindow? {
        let fresh = windows.filter { !$0.isStale(at:now) }
        return (fresh.isEmpty ? windows : fresh).max { $0.usedPercent < $1.usedPercent }
    }
    var ringFraction: Double? { primary.map { min(1,max(0,$0.usedPercent / 100)) } }
    var percentText: String { primary.map { Self.percent($0.usedPercent) } ?? "—" }
    var hasStaleWindows: Bool { windows.contains { $0.isStale(at:now) } }
    var amountText: String? {
        primary?.amounts.map { Self.compact($0.used) + " / " + Self.compact($0.total) }
    }
    var amountCaption: String? { primary?.amounts.map { "已用 / 总 " + $0.unit.rawValue } }
    var subtitle: String {
        if let amounts = primary?.amounts, let amountText { return amountText + " " + amounts.unit.rawValue }
        guard let primary else { return "暂无额度" }
        return (windows.count > 1 ? "最高窗口 · " : "") + primary.title
    }
    var details: String {
        guard !windows.isEmpty else {
            return tool.title + "\n尚未获取账户额度，不代表使用量为 0。"
                + (tool == .claude ? "\nClaude 额度随 statusLine 更新。" : "\n点击右上角刷新按钮查询账户。")
        }
        var sections = [tool.title]
        if windows.count > 1 { sections.append("卡片显示有效窗口中最高的已用比例；无有效窗口时保留最高旧快照，各窗口不相加。") }
        for quota in windows {
            var lines = [quota.title + " · " + Self.percent(quota.usedPercent) + " 已用"]
            if let amounts = quota.amounts {
                lines.append("已用 \(Self.exact(amounts.used)) / 总额度 \(Self.exact(amounts.total)) \(amounts.unit.rawValue)")
                lines.append("剩余 \(Self.exact(amounts.remaining)) \(amounts.unit.rawValue)")
            }
            lines.append("采集于 " + quota.capturedAt.formatted(.dateTime.month().day().hour().minute().second()))
            if now.timeIntervalSince(quota.capturedAt) > 900 { lines.append("快照较旧，等待刷新；不会自动归零。") }
            if let reset = quota.resetsAt {
                lines.append(reset <= now ? "服务返回的重置时间已过，新窗口尚待确认。" : "重置：" + reset.formatted(.dateTime.month().day().hour().minute()))
            }
            sections.append(lines.joined(separator:"\n"))
        }
        return sections.joined(separator:"\n\n")
    }
    private static func percent(_ value: Double) -> String {
        value.formatted(.number.locale(Locale(identifier:"en_US")).precision(.fractionLength(1))) + "%"
    }
    private static func exact(_ value: Double?) -> String {
        value?.formatted(.number.locale(Locale(identifier:"en_US")).precision(.fractionLength(0...2))) ?? "—"
    }
    private static func compact(_ value: Double?) -> String {
        guard let value else { return "—" }
        for (threshold, suffix) in [(1_000_000_000.0,"B"),(1_000_000.0,"M"),(1_000.0,"K")] where value >= threshold {
            return exact(value / threshold) + suffix
        }
        return exact(value)
    }
}
