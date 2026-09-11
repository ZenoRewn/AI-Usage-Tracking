// Author: Zeno Ren
import Foundation
import UsageCore

enum MenuUsageMetric {
    case tokens, cost
    var title: String { self == .tokens ? "Token" : "参考 USD" }
    var toggleHint: String { self == .tokens ? "点击切换为参考成本（USD）" : "点击切换为 Token" }
    mutating func toggle() { self = self == .tokens ? .cost : .tokens }
}

struct MenuUsageAmount {
    let tokens: Int64
    let eventCount: Int
    let estimatedCost: Double
    let pricedTokens: Int64

    init(tokens: Int64, eventCount: Int, estimatedCost: Double, pricedTokens: Int64) {
        self.tokens = tokens; self.eventCount = eventCount
        self.estimatedCost = estimatedCost; self.pricedTokens = pricedTokens
    }
    init(_ period: PeriodUsage) {
        self.init(tokens:period.tokens,eventCount:period.eventCount,estimatedCost:period.estimatedCost,pricedTokens:period.pricedTokens)
    }
    init(_ project: TodayProjectUsage) {
        self.init(tokens:project.tokens,eventCount:project.eventCount,estimatedCost:project.estimatedCost,pricedTokens:project.pricedTokens)
    }
    init(_ tool: TodayProjectToolUsage) {
        self.init(tokens:tool.tokens,eventCount:tool.eventCount,estimatedCost:tool.estimatedCost,pricedTokens:tool.pricedTokens)
    }
    func text(for metric: MenuUsageMetric) -> String {
        guard eventCount > 0 else { return "—" }
        if metric == .tokens { return Display.tokens(tokens) }
        guard pricedTokens > 0 else { return "未定价" }
        return "≈" + estimatedCost.formatted(.currency(code:"USD").locale(Locale(identifier:"en_US")).precision(.fractionLength(2)))
            + (pricedTokens < tokens ? "*" : "")
    }
}
