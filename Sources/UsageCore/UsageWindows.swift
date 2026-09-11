// Author: Zeno Ren
import Foundation

public struct PeriodUsage: Codable, Sendable, Identifiable {
    public let days: Int
    public var tokens: Int64 = 0
    public var eventCount = 0
    public var estimatedCost: Double = 0
    public var pricedTokens: Int64 = 0
    public var id: Int { days }
    public var costCoverage: Double { tokens == 0 ? 0 : Double(pricedTokens)/Double(tokens) }
}
public struct ToolWindowUsage: Codable, Sendable, Identifiable {
    public let tool: Tool
    public var periods: [PeriodUsage]
    public var id: Tool { tool }
}
public enum UsageWindows {
    /// Calendar-day windows, inclusive of today; independent of dashboard filters.
    public static func summarize(_ events: [UsageEvent], catalog: PriceCatalog = .init(), calendar: Calendar = .current, now: Date = Date()) -> [ToolWindowUsage] {
        let days = [1,7,30]
        let starts = days.map { calendar.date(byAdding:.day,value:-($0-1),to:calendar.startOfDay(for:now))! }
        var result = Tool.allCases.map { ToolWindowUsage(tool:$0,periods:days.map { PeriodUsage(days:$0) }) }
        let indices = Dictionary(uniqueKeysWithValues:Tool.allCases.enumerated().map { ($0.element,$0.offset) })
        for event in events {
            let date = event.date
            guard date <= now, date >= starts[2], let i = indices[event.tool] else { continue }
            let cost = catalog.quote(event,pricedAt:now)?.amount
            for window in days.indices where date >= starts[window] {
                result[i].periods[window].tokens += event.tokens.total
                result[i].periods[window].eventCount += 1
                if let cost {
                    result[i].periods[window].estimatedCost += cost
                    result[i].periods[window].pricedTokens += event.tokens.total
                }
            }
        }
        return result
    }
}
