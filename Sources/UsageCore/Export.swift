// Author: Zeno Ren
import Foundation

public enum UsageExporter {
    private struct Report: Encodable {
        let author = "Zeno Ren"
        let product = "Usage Tracking"
        let generatedAt = Date()
        let note = "Observed local usage only. Session summaries have approximate dates. Costs use the recorded costBasis: current GitHub Copilot reference prices or a custom override, not historical invoices."
        var events: [UsageEvent]
    }
    private static func redacted(_ events: [UsageEvent], includePaths: Bool) -> [UsageEvent] {
        events.map { e in
            var x = e
            x.id = String(StableID.hash(e.id).prefix(16)); x.session = String(StableID.hash(e.session).prefix(12)); x.traceID = ""
            if !includePaths { x.project = e.project.isEmpty ? "" : "project-" + String(StableID.hash(e.project).prefix(10)) }
            return x
        }
    }
    public static func json(_ events: [UsageEvent], includePaths: Bool) throws -> Data {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]; encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(Report(events: redacted(events, includePaths: includePaths)))
    }
    public static func csv(_ events: [UsageEvent], includePaths: Bool) -> String {
        func cell(_ value: String) -> String {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            let safe = trimmed.first.map { "=+-@".contains($0) } == true ? "'" + value : value
            return "\"" + safe.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        var lines = ["author,tool,surface,project,session,model,timestamp,input_including_cache,output,cache_read_subset,cache_write_subset,reasoning_subset,total,precision,estimated_cost_usd,cost_basis"]
        for e in redacted(events, includePaths: includePaths) {
            lines.append(["Zeno Ren",e.tool.title,e.surface,e.project,e.session,e.model,e.timestamp,String(e.tokens.input),String(e.tokens.output),String(e.tokens.cacheRead),String(e.tokens.cacheWrite),String(e.tokens.reasoning),String(e.tokens.total),e.precision.rawValue,e.costUSD.map(String.init(describing:)) ?? "",e.costBasis ?? ""].map(cell).joined(separator: ","))
        }
        return lines.joined(separator: "\r\n")
    }
}
