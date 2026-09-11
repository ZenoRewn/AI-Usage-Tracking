// Author: Zeno Ren
import Foundation

public final class SessionParser {
    public let tool: Tool
    public var state: ParserState
    private var output = ParseResult()
    private var events: [String: UsageEvent] = [:]
    private let scope: String
    public init(tool: Tool, state: ParserState = .init(), scope: String = "local") {
        self.tool = tool; self.state = state; self.scope = scope
    }

    public func consume(_ data: Data, offset: Int64) {
        guard let row = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { output.warnings.insert("invalid-json"); return }
        switch tool { case .codex: codex(row, offset: offset); case .claude: claude(row, offset: offset); case .copilot: copilot(row, offset: offset) }
    }

    public func result() -> ParseResult {
        var r = output
        r.events = events.values.filter { !(tool == .codex && state.modern && $0.precision == .snapshot) }.sorted { $0.timestamp < $1.timestamp }
        return r
    }

    private func add(id: String, timestamp: String, tokens: TokenCounts, precision: Precision, model: String? = nil, cost: Double? = nil, trace: String = "", mode: String? = nil) {
        guard !state.session.isEmpty, TimeCodec.date(timestamp) != nil, tokens.total > 0 else { return }
        let key = "\(tool.rawValue):\(scope):\(id)"
        let event = UsageEvent(id: key, tool: tool, surface: state.surface.isEmpty ? tool.title : state.surface, session: state.session, project: state.project, model: model ?? state.model, timestamp: timestamp, tokens: tokens, precision: precision, costUSD: cost, traceID: trace, pricingMode:mode)
        // Revisions replace their prior value. A replay must never increase the count.
        if let prior = events[key], prior.timestamp > event.timestamp { return }
        events[key] = event
    }

    private func codex(_ row: [String: Any], offset: Int64) {
        let p = row.object("payload")
        let type = row.string("type")
        if type == "session_meta" {
            let id = p.string("id").isEmpty ? p.string("session_id") : p.string("id")
            if !id.isEmpty { state.session = id }
            if !p.string("cwd").isEmpty { state.project = p.string("cwd") }
            let origin = p.string("originator").lowercased()
            state.surface = origin.contains("desktop") ? "Codex App" : p.string("source") == "exec" ? "Codex Exec" : "Codex CLI / 其他"
            state.fork = !p.string("forked_from_id").isEmpty || !p.string("parent_session_id").isEmpty || p["source"] is [String: Any]
        } else if type == "turn_context" {
            if !p.string("model").isEmpty { state.model = p.string("model") }
            if !p.string("turn_id").isEmpty { state.turn = p.string("turn_id") }
        } else if type == "token_usage_record" {
            let usage = p.object("usage")
            guard !usage.isEmpty, !p.string("response_id").isEmpty else { return }
            state.modern = true
            if state.session.isEmpty { state.session = p.string("session_id") }
            if state.session.isEmpty { state.session = p.string("thread_id") }
            add(id: "response:\(p.string("response_id"))", timestamp: row.string("timestamp"), tokens: codexTokens(usage), precision: .response)
        } else if type == "event_msg" && p.string("type") == "token_count" {
            readQuota(p.object("rate_limits"), timestamp: row.string("timestamp"), source: "日志快照 · 当前 profile")
            guard !state.modern else { return }
            let usage = p.object("info").object("total_token_usage")
            guard !usage.isEmpty else { return }
            if state.fork { output.warnings.insert("fork-baseline-unavailable"); return }
            let total = codexTokens(usage)
            if let delta = total.delta(from: state.previous ?? .init()) {
                add(id: "snapshot:\(state.session):\(offset)", timestamp: row.string("timestamp"), tokens: delta, precision: .snapshot)
            } else { output.warnings.insert("counter-reset-or-lineage-change") }
            state.previous = total
        }
    }

    private func codexTokens(_ u: [String: Any]) -> TokenCounts {
        .init(input: u.number("input_tokens"), output: u.number("output_tokens"), cacheRead: u.number("cached_input_tokens"), cacheWrite: u.number("cache_write_input_tokens"), reasoning: u.number("reasoning_output_tokens"), reportedTotal: u["total_tokens"] == nil ? nil : u.number("total_tokens"))
    }

    private func claude(_ row: [String: Any], offset: Int64) {
        guard row.string("type") == "assistant" else { return }
        let m = row.object("message"), u = m.object("usage")
        guard !u.isEmpty else { return }
        state.session = row.string("sessionId").isEmpty ? state.session : row.string("sessionId")
        if !row.string("cwd").isEmpty { state.project = row.string("cwd") }
        state.surface = "Claude Code CLI"
        let cacheRead = u.number("cache_read_input_tokens"), cacheWrite = u.number("cache_creation_input_tokens")
        let t = TokenCounts(input: u.number("input_tokens") + cacheRead + cacheWrite, output: u.number("output_tokens"), cacheRead: cacheRead, cacheWrite: cacheWrite)
        let identity = m.string("id").isEmpty ? "offset:\(offset)" : m.string("id") + ":" + row.string("requestId")
        add(id: "message:\(state.session):\(identity)", timestamp: row.string("timestamp"), tokens: t, precision: .response, model: m.string("model"), cost: row["costUSD"] as? Double, mode:u.string("speed").isEmpty ? nil : u.string("speed"))
    }

    private func copilot(_ row: [String: Any], offset: Int64) {
        let type = row.string("type"), d = row.object("data")
        if type == "session.start" {
            state.session = d.string("sessionId")
            state.project = d.object("context").string("cwd")
            state.surface = d.string("producer") == "agency" ? "Copilot App" : "Copilot CLI"
            state.model = d.string("selectedModel")
        } else if type == "session.shutdown" {
            output.warnings.insert("session-summary-time-approximate")
            for (model, raw) in d.object("modelMetrics") {
                guard let metric = raw as? [String: Any] else { continue }
                let u = metric.object("usage")
                let tokens = TokenCounts(input: u.number("inputTokens"), output: u.number("outputTokens"), cacheRead: u.number("cacheReadTokens"), cacheWrite: u.number("cacheWriteTokens"), reasoning: u.number("reasoningTokens"))
                // SDK shutdown metrics are cumulative across resumes. Do not sum shutdowns.
                add(id: "summary:\(state.session):\(model)", timestamp: row.string("timestamp"), tokens: tokens, precision: .session, model: model)
            }
        } else if type == "session.usage_checkpoint" {
            output.warnings.insert("usage-checkpoint-needs-schema")
        } else if type == "span" || row["resourceSpans"] != nil || row["attributes"] != nil || row["span"] != nil {
            telemetry(row)
        }
    }

    private func attributes(_ value: Any?) -> [String: Any] {
        if let dict = value as? [String: Any] { return dict }
        var result: [String: Any] = [:]
        for a in value as? [[String: Any]] ?? [] {
            let v = a.object("value")
            result[a.string("key")] = v["stringValue"] ?? v["intValue"].flatMap { Int64(String(describing: $0)) } ?? v["doubleValue"] ?? v["boolValue"]
        }
        return result
    }

    private func telemetry(_ row: [String: Any]) {
        var spans: [[String: Any]] = []
        for resource in row["resourceSpans"] as? [[String: Any]] ?? [] {
            for scope in resource["scopeSpans"] as? [[String: Any]] ?? [] { spans += scope["spans"] as? [[String: Any]] ?? [] }
        }
        if spans.isEmpty {
            let d = row.object("data"), span = row.object("span")
            spans = [!span.isEmpty ? span : d["attributes"] != nil ? d : row]
        }
        for span in spans {
            let a = attributes(span["attributes"])
            let context = span.object("spanContext").isEmpty ? span.object("_spanContext") : span.object("spanContext")
            let trace = span.string("traceId").isEmpty ? context.string("traceId") : span.string("traceId")
            let sid = span.string("spanId").isEmpty ? context.string("spanId") : span.string("spanId")
            let operation = a.string("gen_ai.operation.name")
            if operation == "invoke_agent" {
                let path = a.string("usage_tracking.project_path")
                output.contexts.append(.init(id: trace, project: path.hasPrefix("/") ? path : "", session: a.string("gen_ai.conversation.id")))
                continue
            }
            guard operation == "chat", !trace.isEmpty, !sid.isEmpty else { continue }
            state.session = a.string("gen_ai.conversation.id").isEmpty ? "trace:\(trace)" : a.string("gen_ai.conversation.id")
            if state.surface.isEmpty { state.surface = "Copilot 遥测" }
            state.project = a.string("usage_tracking.project_path")
            let tokens = TokenCounts(input: a.number("gen_ai.usage.input_tokens"), output: a.number("gen_ai.usage.output_tokens"), cacheRead: a.number("gen_ai.usage.cache_read.input_tokens"), cacheWrite: a.number("gen_ai.usage.cache_creation.input_tokens"), reasoning: a.number("gen_ai.usage.reasoning.output_tokens"))
            var timestamp = span.string("endTime")
            if let nano = span["endTimeUnixNano"], let value = Double(String(describing: nano)) { timestamp = TimeCodec.string(Date(timeIntervalSince1970: value / 1e9)) }
            if let pair = span["endTime"] as? [Double], pair.count == 2 { timestamp = TimeCodec.string(Date(timeIntervalSince1970: pair[0] + pair[1] / 1e9)) }
            add(id: "otel:\(trace):\(sid)", timestamp: timestamp, tokens: tokens, precision: .telemetry, model: a.string("gen_ai.response.model").isEmpty ? a.string("gen_ai.request.model") : a.string("gen_ai.response.model"), trace: trace)
        }
    }

    private func readQuota(_ p: [String: Any], timestamp: String, source: String) {
        guard let date = TimeCodec.date(timestamp) else { return }
        let limit = p.string("limit_id").isEmpty ? "codex" : p.string("limit_id")
        for key in ["primary", "secondary"] {
            let b = p.object(key)
            guard let pct = b["used_percent"] as? Double, pct.isFinite else { continue }
            let mins = b.number("window_minutes")
            let title = mins == 300 ? "5 小时" : mins == 10080 ? "每周" : "\(mins) 分钟"
            let reset = (b["resets_at"] as? Double).map { Date(timeIntervalSince1970: $0) }
            output.quotas.append(.init(id: "codex:\(scope):\(limit):\(key)", tool: .codex, title: "\(limit == "codex" ? "" : limit + " · ")\(title)", usedPercent: pct, resetsAt: reset, capturedAt: date, source: source))
        }
    }
}
