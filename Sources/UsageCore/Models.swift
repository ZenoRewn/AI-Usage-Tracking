// Author: Zeno Ren
import Foundation
import CryptoKit

public enum Tool: String, Codable, CaseIterable, Sendable, Identifiable {
    case codex, claude, copilot
    public var id: String { rawValue }
    public var title: String { switch self { case .codex: "Codex"; case .claude: "Claude Code"; case .copilot: "GitHub Copilot" } }
}

public enum Precision: String, Codable, Sendable {
    case response, telemetry, snapshot, session
    public var title: String { switch self { case .response: "逐响应"; case .telemetry: "调用遥测"; case .snapshot: "快照增量"; case .session: "会话汇总 · 日期近似" } }
    public var priority: Int { switch self { case .response: 40; case .telemetry: 30; case .snapshot: 20; case .session: 10 } }
}

public struct TokenCounts: Codable, Sendable, Equatable {
    public var input: Int64 = 0
    public var output: Int64 = 0
    public var cacheRead: Int64 = 0
    public var cacheWrite: Int64 = 0
    public var reasoning: Int64 = 0
    public var reportedTotal: Int64?
    public var total: Int64 { reportedTotal ?? (input + output) }
    public var uncachedInput: Int64 { max(0, input - cacheRead - cacheWrite) }
    public init(input: Int64 = 0, output: Int64 = 0, cacheRead: Int64 = 0, cacheWrite: Int64 = 0, reasoning: Int64 = 0, reportedTotal: Int64? = nil) {
        self.input = input; self.output = output; self.cacheRead = cacheRead; self.cacheWrite = cacheWrite; self.reasoning = reasoning; self.reportedTotal = reportedTotal
    }
    public func delta(from previous: TokenCounts) -> TokenCounts? {
        guard input >= previous.input, output >= previous.output, cacheRead >= previous.cacheRead, cacheWrite >= previous.cacheWrite else { return nil }
        return .init(input: input - previous.input, output: output - previous.output, cacheRead: cacheRead - previous.cacheRead, cacheWrite: cacheWrite - previous.cacheWrite, reasoning: max(0, reasoning - previous.reasoning))
    }
}

public struct UsageEvent: Codable, Sendable, Identifiable {
    public var id: String
    public var tool: Tool
    public var surface: String
    public var session: String
    public var project: String
    public var model: String
    public var timestamp: String
    public var tokens: TokenCounts
    public var precision: Precision
    public var costUSD: Double?
    public var traceID: String = ""
    public var pricingMode: String?
    public var costBasis: String?
    public var time: Double { TimeCodec.date(timestamp)?.timeIntervalSince1970 ?? 0 }
    public var date: Date { Date(timeIntervalSince1970: time) }
    public var projectName: String { project.isEmpty ? "未归属项目" : URL(fileURLWithPath: project).lastPathComponent }
}

public struct QuotaAmounts: Codable, Sendable {
    public enum Unit: String, Codable, Sendable { case credits = "Credits", requests = "Requests" }
    public var unit: Unit
    public var total: Double?
    public var used: Double?
    public var remaining: Double? {
        guard let total, let used else { return nil }
        return max(0, total - used)
    }
    public init(unit: Unit, total: Double?, used: Double?) {
        self.unit = unit
        self.total = total.flatMap { $0.isFinite && $0 >= 0 ? $0 : nil }
        self.used = used.flatMap { $0.isFinite && $0 >= 0 ? $0 : nil }
    }
}

public struct QuotaWindow: Codable, Sendable, Identifiable {
    public var id: String
    public var tool: Tool
    public var title: String
    public var usedPercent: Double
    public var resetsAt: Date?
    public var capturedAt: Date
    public var source: String
    public var amounts: QuotaAmounts?
    public init(id: String, tool: Tool, title: String, usedPercent: Double, resetsAt: Date?, capturedAt: Date, source: String, amounts: QuotaAmounts? = nil) {
        self.id = id; self.tool = tool; self.title = title; self.usedPercent = usedPercent; self.resetsAt = resetsAt; self.capturedAt = capturedAt; self.source = source
        self.amounts = amounts
    }
    /// Copilot RPC can return the query time as resetDate. That is not a confirmed
    /// upcoming reset and does not invalidate the usage returned by that same read.
    public var hasUnconfirmedReset: Bool {
        tool == .copilot && id.hasPrefix("copilot-rpc:") && (resetsAt.map { $0 <= capturedAt } ?? false)
    }
    public var confirmedResetsAt: Date? { hasUnconfirmedReset ? nil : resetsAt }
    public func isStale(at now: Date = Date()) -> Bool {
        now.timeIntervalSince(capturedAt) > 900 || (confirmedResetsAt.map { $0 <= now } ?? false)
    }
    public static func mergingScan(_ scanned: [QuotaWindow], current: [QuotaWindow]) -> [QuotaWindow] {
        var result = scanned
        for prefix in ["rpc:", "copilot-rpc:"] {
            let existing = current.filter { $0.id.hasPrefix(prefix) }
            let incoming = scanned.filter { $0.id.hasPrefix(prefix) }
            if let latest = existing.map(\.capturedAt).max(), latest > (incoming.map(\.capturedAt).max() ?? .distantPast) {
                result.removeAll { $0.id.hasPrefix(prefix) }
                result.append(contentsOf: existing)
            }
        }
        return result
    }
}

public struct TraceContext: Codable, Sendable {
    public var id: String
    public var project: String
    public var session: String
}

public struct ParseResult: Codable, Sendable {
    public var events: [UsageEvent] = []
    public var quotas: [QuotaWindow] = []
    public var contexts: [TraceContext] = []
    public var warnings: Set<String> = []
}

public struct ParserState: Codable, Sendable {
    public var session = ""
    public var project = ""
    public var model = "unknown"
    public var turn = ""
    public var surface = ""
    public var fork = false
    public var modern = false
    public var previous: TokenCounts?
    public init() {}
}

public enum TimeCodec {
    public static func date(_ text: String) -> Date? {
        if let d = try? Date.ISO8601FormatStyle(includingFractionalSeconds: true).parse(text) { return d }
        return try? Date.ISO8601FormatStyle().parse(text)
    }
    public static func string(_ date: Date) -> String { date.ISO8601Format() }
}

public enum StableID {
    public static func hash(_ text: String) -> String { SHA256.hash(data: Data(text.utf8)).map { String(format: "%02x", $0) }.joined() }
}

public enum ProjectResolver {
    public static func canonicalRoot(_ path: String) -> String {
        guard path.hasPrefix("/") else { return "" }
        let original = URL(fileURLWithPath: path).standardizedFileURL.resolvingSymlinksInPath()
        var root = original
        for _ in 0..<30 {
            let git = root.appendingPathComponent(".git")
            var dir: ObjCBool = false
            if FileManager.default.fileExists(atPath: git.path, isDirectory: &dir) {
                if dir.boolValue { return root.path }
                if let s = try? String(contentsOf: git, encoding: .utf8), s.hasPrefix("gitdir:") {
                    let p = String(s.dropFirst(7)).trimmingCharacters(in: .whitespacesAndNewlines)
                    let gitdir = URL(fileURLWithPath: p, relativeTo: root).standardizedFileURL
                    if let common = try? String(contentsOf: gitdir.appendingPathComponent("commondir"), encoding: .utf8) {
                        let target = URL(fileURLWithPath: common.trimmingCharacters(in: .whitespacesAndNewlines), relativeTo: gitdir).standardizedFileURL
                        if target.lastPathComponent == ".git" { return target.deletingLastPathComponent().path }
                    }
                }
                return root.path
            }
            let parent = root.deletingLastPathComponent()
            if parent == root { break }; root = parent
        }
        return original.path
    }
}

extension Dictionary where Key == String, Value == Any {
    func object(_ key: String) -> [String: Any] { self[key] as? [String: Any] ?? [:] }
    func string(_ key: String) -> String { self[key] as? String ?? "" }
    func number(_ key: String) -> Int64 {
        guard let n = self[key] as? NSNumber, CFGetTypeID(n) != CFBooleanGetTypeID(), n.doubleValue.isFinite, n.doubleValue >= 0, n.doubleValue < 1e15 else { return 0 }
        return n.int64Value
    }
}
import CoreFoundation
