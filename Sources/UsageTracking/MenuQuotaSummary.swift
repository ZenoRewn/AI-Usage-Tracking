// Author: Zeno Ren
import Foundation
import UsageCore

enum QuotaPressure { case unknown, normal, warning, critical, stale }

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
    var pressure: QuotaPressure {
        guard let primary else { return .unknown }
        if primary.isStale(at:now) { return .stale }
        return primary.usedPercent >= 90 ? .critical : primary.usedPercent >= 80 ? .warning : .normal
    }
    var windowText: String {
        guard let primary else { return "尚未获取账户额度" }
        return primary.title + (windows.count > 1 ? (primary.isStale(at:now) ? " · 旧窗口" : " · 最高有效窗口") : "")
    }
    func statusText(loading: Bool, error: String?) -> String {
        if loading { return "正在查询" }
        if error != nil { return "刷新失败" }
        switch pressure {
        case .unknown: return tool == .claude ? "等待额度快照" : "暂无额度"
        case .stale: return "旧快照"
        default:
            if hasStaleWindows { return "含旧窗口" }
            return pressure == .critical ? "接近或达到上限" : pressure == .warning ? "接近上限" : "已用"
        }
    }
    var resetText: String {
        guard let primary else { return "查看获取方式" }
        return resetText(for:primary)
    }
    func resetText(for quota: QuotaWindow) -> String {
        if quota.hasUnconfirmedReset { return "重置时间待确认" }
        guard let reset = quota.resetsAt else { return "未提供重置时间" }
        let seconds = reset.timeIntervalSince(now)
        guard let minutes = Int(exactly:ceil(seconds / 60)) else { return "重置时间无效" }
        guard seconds > 0 else { return "等待新窗口" }
        guard !quota.isStale(at:now) else { return "重置时间待确认" }
        if seconds < 60 { return "不到 1 分钟后重置" }
        if minutes < 60 { return "\(minutes)m 后重置" }
        if minutes < 1440 {
            return "\(minutes / 60)h" + (minutes % 60 == 0 ? "" : " \(minutes % 60)m") + " 后重置"
        }
        let hours = minutes / 60
        return "\(hours / 24) 天" + (hours % 24 == 0 ? "后重置" : " \(hours % 24)h 后重置")
    }
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
                if quota.hasUnconfirmedReset {
                    lines.append("服务未提供可确认的下次重置时间；重置时间待确认。")
                    lines.append("服务返回时间：" + reset.formatted(.dateTime.month().day().hour().minute()))
                } else {
                    lines.append(reset <= now ? "服务返回的重置时间已过，新窗口尚待确认。" : "重置：" + reset.formatted(.dateTime.month().day().hour().minute()))
                }
            }
            sections.append(lines.joined(separator:"\n"))
        }
        return sections.joined(separator:"\n\n")
    }
    static func percent(_ value: Double) -> String {
        value.formatted(.number.locale(Locale(identifier:"en_US")).precision(.fractionLength(1))) + "%"
    }
    static func exact(_ value: Double?) -> String {
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
