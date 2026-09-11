// Author: Zeno Ren
import Foundation
import CSQLite

public struct SourceFolder: Codable, Sendable, Identifiable {
    public var id: String
    public var tool: Tool
    public var title: String
    public var paths: [String]
    public var scope: String
    public var surface: String?
    public init(id: String, tool: Tool, title: String, paths: [String], scope: String, surface: String? = nil) {
        self.id = id; self.tool = tool; self.title = title; self.paths = paths; self.scope = scope; self.surface = surface
    }
    public static func defaults(dataDirectory: URL) -> [SourceFolder] {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let env = ProcessInfo.processInfo.environment
        let codex = env["CODEX_HOME"] ?? home + "/.codex"
        let claude = env["CLAUDE_CONFIG_DIR"] ?? home + "/.claude"
        let copilot = home + "/.copilot"
        return [
            .init(id: "codex", tool: .codex, title: "Codex App / 本地会话", paths: [codex + "/sessions",codex + "/archived_sessions"], scope: StableID.hash(codex)),
            .init(id: "claude", tool: .claude, title: "Claude Code CLI", paths: [claude + "/projects"], scope: StableID.hash(claude)),
            .init(id: "copilot-history", tool: .copilot, title: "Copilot App / CLI 历史", paths: [copilot + "/session-state",copilot + "/history-session-state"], scope: StableID.hash(copilot)),
            .init(id: "copilot-vscode", tool: .copilot, title: "Copilot VS Code 遥测", paths: [dataDirectory.appendingPathComponent("telemetry/vscode.jsonl").path], scope: StableID.hash(copilot), surface: "Copilot VS Code"),
            .init(id: "copilot-cli", tool: .copilot, title: "Copilot CLI 遥测", paths: [dataDirectory.appendingPathComponent("telemetry/cli.jsonl").path], scope: StableID.hash(copilot), surface: "Copilot CLI")
        ]
    }
}

public struct SourceHealth: Codable, Sendable, Identifiable {
    public var id: String
    public var title: String
    public var tool: Tool
    public var files: Int
    public var changed: Int
    public var eventCount: Int
    public var latestEvent: Date?
    public var state: String
    public var detail: String
    public var warnings: [String]
}

public struct ScanSnapshot: Sendable {
    public var events: [UsageEvent] = []
    public var quotas: [QuotaWindow] = []
    public var sources: [SourceHealth] = []
    public var scannedAt = Date()
    public init() {}
}

public actor UsageScanner {
    private let database: UsageDatabase
    private let dataDirectory: URL
    private var projectCache: [String: String] = [:]
    private var warningsBySource: [String: Set<String>] = [:]
    public init(dataDirectory: URL) throws {
        self.dataDirectory = dataDirectory
        try FileManager.default.createDirectory(at: dataDirectory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        database = try UsageDatabase(path: dataDirectory.appendingPathComponent("usage.sqlite").path)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: dataDirectory.appendingPathComponent("usage.sqlite").path)
    }
    public func cached() throws -> ScanSnapshot {
        var s = ScanSnapshot(); s.events = try database.events(); s.quotas = try database.quotas(); return s
    }
    public func scan(sources: [SourceFolder], progress: (@Sendable (String) -> Void)? = nil) throws -> ScanSnapshot {
        var health: [SourceHealth] = []
        let sessionPaths = Self.copilotProjectPaths()
        for source in sources {
            var files: [URL] = [], changed = 0, warnings = warningsBySource[source.id] ?? [], errors = 0
            for path in source.paths {
                let root = URL(fileURLWithPath: (path as NSString).expandingTildeInPath)
                if root.pathExtension == "jsonl" {
                    if FileManager.default.fileExists(atPath: root.path) { files.append(root) }; continue
                }
                if let iterator = FileManager.default.enumerator(at: root, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles]) {
                    while let url = iterator.nextObject() as? URL {
                        if url.pathExtension == "jsonl" && (source.tool != .copilot || url.lastPathComponent == "events.jsonl") { files.append(url) }
                    }
                }
            }
            files.sort { $0.path < $1.path }
            for (index, url) in files.enumerated() {
                if Task<Never, Never>.isCancelled { break }
                progress?("\(source.title) · \(index + 1)/\(files.count)")
                do {
                    let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
                    let size = (attributes[.size] as? NSNumber)?.int64Value ?? 0
                    let modified = (attributes[.modificationDate] as? Date)?.timeIntervalSince1970 ?? 0
                    let identity = String(describing: attributes[.systemFileNumber] ?? "")
                    let old = try database.checkpoint(file: url.path)
                    warnings.formUnion(old?.1.warnings ?? [])
                    if let old, old.1.parserVersion == 2, old.1.size == size, old.1.modified == modified, old.1.offset <= size, old.1.identity == identity { continue }
                    let h = try FileHandle(forReadingFrom: url); let prefix = try h.read(upToCount: Int(min(size, 256))) ?? Data(); try h.close()
                    let fingerprint = StableID.hash(prefix.base64EncodedString())
                    let reset = old == nil || old?.1.parserVersion != 2 || size < (old?.1.offset ?? 0) || old?.1.identity != identity || (old?.1.fingerprint != fingerprint && (old?.1.size ?? 0) >= 256) || (size == old?.1.size && modified != old?.1.modified)
                    var state = reset ? ParserState() : old!.0
                    if state.session.isEmpty { state.session = url.deletingPathExtension().lastPathComponent }
                    if let surface = source.surface { state.surface = surface }
                    let parser = SessionParser(tool: source.tool, state: state, scope: source.scope)
                    let start = reset ? 0 : old!.1.offset
                    let offset = try JSONLReader.read(url: url, offset: start) { line, position in parser.consume(line, offset: position) }
                    var result = parser.result()
                    for i in result.events.indices {
                        let path = result.events[i].project.isEmpty && source.tool == .copilot ? sessionPaths[result.events[i].session] ?? "" : result.events[i].project
                        if projectCache[path] == nil { projectCache[path] = ProjectResolver.canonicalRoot(path) }
                        result.events[i].project = projectCache[path] ?? ""
                    }
                    var cp = FileCheckpoint(); cp.offset = offset; cp.size = size; cp.modified = offset < size - 16 * 1024 * 1024 ? 0 : modified; cp.identity = identity; cp.fingerprint = fingerprint; cp.warnings = result.warnings.sorted(); cp.parserVersion = 2
                    try database.save(file: url.path, events: result.events, state: parser.state, checkpoint: cp, reset: reset, quotas: result.quotas, contexts: result.contexts)
                    warnings.formUnion(result.warnings); changed += 1
                } catch { errors += 1; warnings.insert("file-read-or-schema-failed") }
            }
            warningsBySource[source.id] = warnings
            let state = errors > 0 ? "部分可用" : files.isEmpty ? "待连接" : "已读取"
            let detail = files.isEmpty ? "尚无可读记录。启用数据源后会自动采集。" : errors > 0 ? "\(errors) 个文件暂时无法读取；其他来源继续工作。" : "本机增量读取 · \(files.count) 个文件"
            health.append(.init(id: source.id, title: source.title, tool: source.tool, files: files.count, changed: changed, eventCount: 0, latestEvent: nil, state: state, detail: detail, warnings: warnings.sorted()))
        }
        try readClaudeQuota()
        var snapshot = try cached()
        for i in health.indices {
            let source = sources[i]
            let matching = snapshot.events.filter { $0.tool == source.tool && (source.surface == nil ? $0.precision != .telemetry : $0.surface == source.surface! && $0.precision == .telemetry) }
            health[i].eventCount = matching.count; health[i].latestEvent = matching.first?.date
            if matching.isEmpty && health[i].files > 0 && health[i].state == "已读取" { health[i].state = "等待用量" }
        }
        snapshot.sources = health; snapshot.scannedAt = Date(); return snapshot
    }

    private func readClaudeQuota() throws {
        let home = ProcessInfo.processInfo.environment["CLAUDE_CONFIG_DIR"] ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".claude").path
        let candidates = [home + "/usage-status.json",home + "/tt-status.json",dataDirectory.appendingPathComponent("claude-status.json").path]
        for path in candidates {
            guard let attrs = try? FileManager.default.attributesOfItem(atPath: path), let date = attrs[.modificationDate] as? Date,
                  let data = try? Data(contentsOf: URL(fileURLWithPath: path)), data.count < 2_000_000,
                  let row = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { continue }
            let limits = row.object("rate_limits")
            for (key, title) in [("five_hour","5 小时"),("seven_day","每周")] {
                let b = limits.object(key)
                guard let pct = b["used_percentage"] as? Double, pct.isFinite else { continue }
                let reset = (b["resets_at"] as? Double).map { Date(timeIntervalSince1970: $0) }
                try database.putQuota(.init(id: "claude:\(StableID.hash(home)):\(key)", tool: .claude, title: title, usedPercent: pct, resetsAt: reset, capturedAt: date, source: "本地 statusLine 快照"))
            }
        }
    }
    public func saveQuotas(_ quotas: [QuotaWindow]) throws { try database.replaceRemoteQuotas(quotas) }

    /// Whitelisted metadata only; never query summaries, messages, accounts, or credential tables.
    private static func copilotProjectPaths() -> [String:String] {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        var result: [String:String] = [:]
        for path in [home + "/.copilot/session-store.db",home + "/Library/Application Support/Code/User/globalStorage/github.copilot-chat/session-store.db"] where FileManager.default.fileExists(atPath:path) {
            var db: OpaquePointer?, query: OpaquePointer?
            guard sqlite3_open_v2(path,&db,SQLITE_OPEN_READONLY|SQLITE_OPEN_FULLMUTEX,nil) == SQLITE_OK else { sqlite3_close(db); continue }
            defer { sqlite3_finalize(query); sqlite3_close(db) }
            sqlite3_busy_timeout(db,100)
            guard sqlite3_prepare_v2(db,"SELECT id,cwd FROM sessions WHERE cwd IS NOT NULL LIMIT 100000",-1,&query,nil) == SQLITE_OK else { continue }
            while sqlite3_step(query) == SQLITE_ROW {
                guard let id = sqlite3_column_text(query,0), let cwd = sqlite3_column_text(query,1) else { continue }
                let value = String(cString:cwd)
                if value.hasPrefix("/") { result[String(cString:id)] = value }
            }
        }
        return result
    }
}
