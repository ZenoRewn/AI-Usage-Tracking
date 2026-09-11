// Author: Zeno Ren
import Foundation

public struct TodayProjectToolUsage: Sendable, Identifiable {
    public let tool: Tool
    public var tokens: Int64 = 0
    public var input: Int64 = 0
    public var output: Int64 = 0
    public var estimatedCost: Double = 0
    public var pricedTokens: Int64 = 0
    public var eventCount = 0
    public var hasApproximateDates = false
    public var id: Tool { tool }
}

public struct TodayProjectUsage: Sendable, Identifiable {
    public let project: String
    public let tools: [TodayProjectToolUsage]
    public var id: String { project }
    public var tokens: Int64 { tools.reduce(0) { $0 + $1.tokens } }
    public var estimatedCost: Double { tools.reduce(0) { $0 + $1.estimatedCost } }
    public var pricedTokens: Int64 { tools.reduce(0) { $0 + $1.pricedTokens } }
    public var eventCount: Int { tools.reduce(0) { $0 + $1.eventCount } }
    public var hasApproximateDates: Bool { tools.contains { $0.hasApproximateDates } }
}

public struct TodayProjectSummary: Sendable {
    public let dayStart: Date
    public let projects: [TodayProjectUsage]
    public let projectCount: Int
    public let unassignedTokens: Int64
}

public enum TodayProjects {
    /// Input is the scanner's normalized, deduplicated events with canonical project paths.
    public static func summarize(_ events: [UsageEvent], catalog: PriceCatalog = .init(), calendar: Calendar = .current, now: Date = Date()) -> TodayProjectSummary {
        let start = calendar.startOfDay(for:now)
        var projects: [String: [Tool: TodayProjectToolUsage]] = [:]
        var unassigned: Int64 = 0
        for event in events {
            let date = event.date
            guard date >= start, date <= now else { continue }
            guard !event.project.isEmpty else { unassigned += event.tokens.total; continue }
            var tool = projects[event.project]?[event.tool] ?? TodayProjectToolUsage(tool:event.tool)
            tool.tokens += event.tokens.total
            tool.input += event.tokens.input
            tool.output += event.tokens.output
            tool.eventCount += 1
            if let quote = catalog.quote(event,pricedAt:now) {
                tool.estimatedCost += quote.amount
                tool.pricedTokens += event.tokens.total
            }
            tool.hasApproximateDates = tool.hasApproximateDates || event.precision == .session
            projects[event.project,default:[:]][event.tool] = tool
        }
        var ranked: [TodayProjectUsage] = []
        for (path, byTool) in projects {
            let tools: [TodayProjectToolUsage] = Tool.allCases.compactMap { byTool[$0] }
            let project = TodayProjectUsage(project:path,tools:tools)
            if project.tokens > 0 { ranked.append(project) }
        }
        ranked.sort {
            $0.tokens == $1.tokens ? $0.project < $1.project : $0.tokens > $1.tokens
        }
        return TodayProjectSummary(dayStart:start,projects:Array(ranked.prefix(3)),projectCount:ranked.count,unassignedTokens:unassigned)
    }
}
