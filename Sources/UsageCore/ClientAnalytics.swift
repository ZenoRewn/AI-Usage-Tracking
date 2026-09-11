// Author: Zeno Ren
import Foundation

public struct ClientMetrics: Codable, Sendable {
    public var tokens: Int64 = 0
    public var input: Int64 = 0
    public var output: Int64 = 0
    public var cacheRead: Int64 = 0
    public var cacheWrite: Int64 = 0
    public var recordCount = 0
    public var preciseCallRecords = 0
    public var aggregateRecords = 0
    public var sessionCount = 0
    public var projectCount = 0
    public var pricedRecords = 0
    public var pricedTokens: Int64 = 0
    public var estimatedCost: Double?
    public var lastSeen: Date?
    public var cacheHitRate: Double? { input > 0 && cacheRead <= input ? Double(cacheRead)/Double(input) : nil }
    public var priceCoverage: Double { tokens == 0 ? 0 : Double(pricedTokens)/Double(tokens) }
}

public struct ClientModelUsage: Codable, Sendable, Identifiable {
    public let model: String
    public let mode: String
    public let metrics: ClientMetrics
    public var id: String { StableID.hash(model + "\u{0}" + mode) }
    public var displayName: String { model + (mode == "standard" ? "" : " · " + mode) }
}

public struct ClientUsage: Codable, Sendable, Identifiable {
    public let tool: Tool
    public let client: String
    public let metrics: ClientMetrics
    public let models: [ClientModelUsage]
    public var id: String { tool.rawValue + ":" + client }
}

public enum ClientAnalytics {
    private struct ClientKey: Hashable { let tool: Tool; let client: String }
    private struct ModelKey: Hashable { let client: ClientKey; let model: String; let mode: String }
    private struct Accumulator {
        var metrics = ClientMetrics()
        var sessions = Set<String>()
        var projects = Set<String>()
        mutating func append(_ e: UsageEvent, quote: CostQuote?) {
            metrics.tokens += e.tokens.total; metrics.input += e.tokens.input; metrics.output += e.tokens.output
            metrics.cacheRead += e.tokens.cacheRead; metrics.cacheWrite += e.tokens.cacheWrite
            metrics.recordCount += 1
            if e.precision == .response || e.precision == .telemetry { metrics.preciseCallRecords += 1 } else { metrics.aggregateRecords += 1 }
            if !e.session.isEmpty { sessions.insert(e.session) }
            if !e.project.isEmpty { projects.insert(e.project) }
            metrics.sessionCount = sessions.count; metrics.projectCount = projects.count
            if let quote {
                metrics.pricedRecords += 1; metrics.pricedTokens += e.tokens.total
                metrics.estimatedCost = (metrics.estimatedCost ?? 0) + quote.amount
            }
            if let date = TimeCodec.date(e.timestamp), metrics.lastSeen == nil || date > metrics.lastSeen! { metrics.lastSeen = date }
        }
    }
    public static func clientName(_ event: UsageEvent) -> String {
        let name = event.surface.trimmingCharacters(in:.whitespacesAndNewlines)
        return name.isEmpty ? "未识别客户端" : name
    }
    public static func mode(_ event: UsageEvent) -> String {
        let value = event.pricingMode?.trimmingCharacters(in:.whitespacesAndNewlines) ?? ""
        return value.isEmpty ? "standard" : value
    }
    /// Input is the canonical, already de-duplicated event stream from UsageDatabase.
    public static func summarize(_ events: [UsageEvent], catalog: PriceCatalog = .init()) -> [ClientUsage] {
        var clients: [ClientKey:Accumulator] = [:], models: [ModelKey:Accumulator] = [:]
        for event in events {
            let client = ClientKey(tool:event.tool,client:clientName(event))
            let key = ModelKey(client:client,model:event.model.isEmpty ? "unknown" : event.model,mode:mode(event))
            let quote = catalog.quote(event)
            clients[client,default:Accumulator()].append(event,quote:quote)
            models[key,default:Accumulator()].append(event,quote:quote)
        }
        var result: [ClientUsage] = []
        for (key,accumulator) in clients {
            var rows: [ClientModelUsage] = []
            for (modelKey,value) in models where modelKey.client == key {
                rows.append(ClientModelUsage(model:modelKey.model,mode:modelKey.mode,metrics:value.metrics))
            }
            rows.sort { lhs,rhs in
                if lhs.metrics.tokens == rhs.metrics.tokens { return lhs.displayName < rhs.displayName }
                return lhs.metrics.tokens > rhs.metrics.tokens
            }
            result.append(ClientUsage(tool:key.tool,client:key.client,metrics:accumulator.metrics,models:rows))
        }
        result.sort { lhs,rhs in
            if lhs.metrics.tokens == rhs.metrics.tokens { return lhs.id < rhs.id }
            return lhs.metrics.tokens > rhs.metrics.tokens
        }
        return result
    }
    public static func json(_ clients: [ClientUsage]) throws -> Data {
        struct Report: Encodable {
            let author = "Zeno Ren"
            let product = "Usage Tracking"
            let pricingSource = CopilotPublicPricing.sourceURL
            let priceAsOf = CopilotPublicPricing.asOf
            let note = "Observed client/model usage; record count is not total API call count. Costs are reference estimates; custom prices override the public snapshot."
            let clients: [ClientUsage]
        }
        let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .iso8601; encoder.outputFormatting = [.prettyPrinted,.sortedKeys]
        return try encoder.encode(Report(clients:clients))
    }
    public static func csv(_ clients: [ClientUsage]) -> String {
        func cell(_ value: String) -> String {
            let dangerous = value.trimmingCharacters(in:.whitespacesAndNewlines).first.map { "=+-@".contains($0) } == true
            let escaped = (dangerous ? "'" + value : value).replacingOccurrences(of:"\"",with:"\"\"")
            return "\"" + escaped + "\""
        }
        var rows = ["author,tool,client,model,mode,tokens,input_including_cache,output,cache_read_subset,cache_write_subset,records,precise_call_records,aggregate_records,sessions,projects,estimated_cost_usd,priced_tokens,price_as_of,last_seen"]
        for client in clients {
            for model in client.models {
                let m = model.metrics
                var values: [String] = ["Zeno Ren",client.tool.title,client.client,model.model,model.mode]
                values += [m.tokens,m.input,m.output,m.cacheRead,m.cacheWrite].map { String($0) }
                values += [m.recordCount,m.preciseCallRecords,m.aggregateRecords,m.sessionCount,m.projectCount].map { String($0) }
                values += [m.estimatedCost.map { String($0) } ?? "",String(m.pricedTokens),CopilotPublicPricing.asOf,m.lastSeen.map { TimeCodec.string($0) } ?? ""]
                rows.append(values.map(cell).joined(separator:","))
            }
        }
        return rows.joined(separator:"\r\n")
    }
}
