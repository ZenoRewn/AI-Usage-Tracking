// Author: Zeno Ren
import Foundation
import CSQLite

public struct FileCheckpoint: Codable, Sendable {
    public var offset: Int64 = 0
    public var size: Int64 = 0
    public var modified: Double = 0
    public var identity = ""
    public var fingerprint = ""
    public var warnings: [String]?
    public var parserVersion: Int?
    public init() {}
}

public enum StoreError: Error, LocalizedError {
    case database(String)
    public var errorDescription: String? { if case .database(let s) = self { return "本地数据库：\(s)" }; return nil }
}

/// Owned by UsageScanner's actor. FULLMUTEX also protects standalone CLI/test callers.
public final class UsageDatabase: @unchecked Sendable {
    private var db: OpaquePointer?
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    public init(path: String) throws {
        guard sqlite3_open_v2(path, &db, SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX, nil) == SQLITE_OK else { throw StoreError.database("无法打开") }
        sqlite3_busy_timeout(db, 3000)
        try execute("PRAGMA journal_mode=WAL; PRAGMA foreign_keys=ON; PRAGMA user_version=1;")
        try execute("""
        CREATE TABLE IF NOT EXISTS facts(file TEXT NOT NULL, event_key TEXT NOT NULL, tool TEXT NOT NULL, session TEXT NOT NULL, precision TEXT NOT NULL, priority INTEGER NOT NULL, time REAL NOT NULL, payload TEXT NOT NULL, PRIMARY KEY(file,event_key));
        CREATE INDEX IF NOT EXISTS facts_event ON facts(event_key,priority,time);
        CREATE INDEX IF NOT EXISTS facts_session ON facts(tool,session,priority);
        CREATE TABLE IF NOT EXISTS checkpoints(file TEXT PRIMARY KEY,state TEXT NOT NULL,checkpoint TEXT NOT NULL);
        CREATE TABLE IF NOT EXISTS quotas(id TEXT PRIMARY KEY,time REAL NOT NULL,payload TEXT NOT NULL);
        CREATE TABLE IF NOT EXISTS traces(id TEXT PRIMARY KEY,payload TEXT NOT NULL);
        """)
    }
    deinit { sqlite3_close(db) }
    private func check(_ code: Int32) throws { if code != SQLITE_OK && code != SQLITE_DONE { throw StoreError.database(String(cString: sqlite3_errmsg(db))) } }
    private func execute(_ sql: String) throws { try check(sqlite3_exec(db, sql, nil, nil, nil)) }
    private func statement(_ sql: String) throws -> OpaquePointer {
        var s: OpaquePointer?; try check(sqlite3_prepare_v2(db, sql, -1, &s, nil)); return s!
    }
    private func bind(_ value: String, _ index: Int32, _ statement: OpaquePointer) { value.withCString { _ = sqlite3_bind_text(statement, index, $0, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self)) } }
    private func json<T: Encodable>(_ value: T) throws -> String { String(decoding: try encoder.encode(value), as: UTF8.self) }
    private func column(_ s: OpaquePointer, _ n: Int32) -> String { sqlite3_column_text(s, n).map { String(cString: $0) } ?? "" }

    public func checkpoint(file: String) throws -> (ParserState, FileCheckpoint)? {
        let s = try statement("SELECT state,checkpoint FROM checkpoints WHERE file=?"); defer { sqlite3_finalize(s) }; bind(file, 1, s)
        guard sqlite3_step(s) == SQLITE_ROW else { return nil }
        return (try decoder.decode(ParserState.self, from: Data(column(s, 0).utf8)), try decoder.decode(FileCheckpoint.self, from: Data(column(s, 1).utf8)))
    }

    public func save(file: String, events: [UsageEvent], state: ParserState, checkpoint: FileCheckpoint, reset: Bool, quotas: [QuotaWindow] = [], contexts: [TraceContext] = []) throws {
        try execute("BEGIN IMMEDIATE")
        do {
            if reset {
                let d = try statement("DELETE FROM facts WHERE file=?"); defer { sqlite3_finalize(d) }; bind(file, 1, d); try check(sqlite3_step(d))
            }
            let s = try statement("INSERT INTO facts VALUES(?,?,?,?,?,?,?,?) ON CONFLICT(file,event_key) DO UPDATE SET tool=excluded.tool,session=excluded.session,precision=excluded.precision,priority=excluded.priority,time=excluded.time,payload=excluded.payload WHERE excluded.time>=facts.time")
            defer { sqlite3_finalize(s) }
            for e in events {
                sqlite3_reset(s); sqlite3_clear_bindings(s)
                for (i, v) in [file,e.id,e.tool.rawValue,e.session,e.precision.rawValue].enumerated() { bind(v, Int32(i+1), s) }
                sqlite3_bind_int(s, 6, Int32(e.precision.priority)); sqlite3_bind_double(s, 7, e.time); bind(try json(e), 8, s); try check(sqlite3_step(s))
            }
            let cp = try statement("INSERT OR REPLACE INTO checkpoints VALUES(?,?,?)"); defer { sqlite3_finalize(cp) }
            bind(file, 1, cp); bind(try json(state), 2, cp); bind(try json(checkpoint), 3, cp); try check(sqlite3_step(cp))
            for quota in quotas { try putQuota(quota) }
            for context in contexts where !context.id.isEmpty {
                let c = try statement("INSERT OR REPLACE INTO traces VALUES(?,?)"); defer { sqlite3_finalize(c) }
                bind(context.id, 1, c); bind(try json(context), 2, c); try check(sqlite3_step(c))
            }
            try execute("COMMIT")
        } catch { try? execute("ROLLBACK"); throw error }
    }

    public func putQuota(_ q: QuotaWindow) throws {
        let s = try statement("INSERT INTO quotas VALUES(?,?,?) ON CONFLICT(id) DO UPDATE SET time=excluded.time,payload=excluded.payload WHERE excluded.time>=quotas.time"); defer { sqlite3_finalize(s) }
        bind(q.id, 1, s); sqlite3_bind_double(s, 2, q.capturedAt.timeIntervalSince1970); bind(try json(q), 3, s); try check(sqlite3_step(s))
    }
    public func replaceRemoteQuotas(_ values: [QuotaWindow]) throws {
        guard let tool = values.first?.tool else { return }
        let prefix = tool == .copilot ? "copilot-rpc:%" : "rpc:%"
        try execute("BEGIN IMMEDIATE")
        do {
            let s = try statement("DELETE FROM quotas WHERE id LIKE ?"); defer { sqlite3_finalize(s) }; bind(prefix,1,s); try check(sqlite3_step(s))
            for value in values { try putQuota(value) }
            try execute("COMMIT")
        } catch { try? execute("ROLLBACK"); throw error }
    }
    public func quotas() throws -> [QuotaWindow] {
        let s = try statement("SELECT payload FROM quotas ORDER BY time DESC"); defer { sqlite3_finalize(s) }
        var result: [QuotaWindow] = []
        while sqlite3_step(s) == SQLITE_ROW { result.append(try decoder.decode(QuotaWindow.self, from: Data(column(s, 0).utf8))) }
        return result
    }
    public func events() throws -> [UsageEvent] {
        let s = try statement("""
        WITH ranked AS (
          SELECT *,ROW_NUMBER() OVER(PARTITION BY event_key ORDER BY priority DESC,time DESC,file) AS position FROM facts
        ) SELECT payload FROM ranked r WHERE position=1
        AND NOT (precision IN ('snapshot','session') AND EXISTS (
          SELECT 1 FROM facts better WHERE better.tool=r.tool AND better.session=r.session AND better.priority>=30
        )) ORDER BY time DESC
        """); defer { sqlite3_finalize(s) }
        var contexts: [String: TraceContext] = [:]
        let ts = try statement("SELECT payload FROM traces"); defer { sqlite3_finalize(ts) }
        while sqlite3_step(ts) == SQLITE_ROW {
            let context = try decoder.decode(TraceContext.self, from: Data(column(ts, 0).utf8)); contexts[context.id] = context
        }
        var result: [UsageEvent] = []
        while sqlite3_step(s) == SQLITE_ROW {
            var event = try decoder.decode(UsageEvent.self, from: Data(column(s, 0).utf8))
            if let context = contexts[event.traceID] {
                if event.project.isEmpty { event.project = context.project }
                if event.session.hasPrefix("trace:") && !context.session.isEmpty { event.session = context.session }
            }
            result.append(event)
        }
        return result
    }
}

public enum JSONLReader {
    /// Returns the offset after the last complete line, never after a partial trailing record.
    public static func read(url: URL, offset: Int64, limit: Int = 256 * 1024 * 1024, consume: (Data, Int64) -> Void) throws -> Int64 {
        let handle = try FileHandle(forReadingFrom: url); defer { try? handle.close() }
        try handle.seek(toOffset: UInt64(max(0, offset)))
        var buffer = Data(), committed = offset, consumed = 0, discarded = 0
        while consumed < limit {
            if Task<Never, Never>.isCancelled { break }
            guard let chunk = try handle.read(upToCount: min(64 * 1024, limit - consumed)), !chunk.isEmpty else { break }
            consumed += chunk.count; buffer.append(chunk)
            while let newline = buffer.firstIndex(of: 10) {
                let length = buffer.distance(from: buffer.startIndex, to: newline) + 1
                if discarded > 0 { consume(Data(), committed) } else { consume(Data(buffer.prefix(length - 1)), committed) }
                committed += Int64(length + discarded); discarded = 0; buffer.removeFirst(length)
            }
            if buffer.count > 16 * 1024 * 1024 {
                // A pathological transcript line must not exhaust the menu-bar app's memory.
                discarded += buffer.count; buffer.removeAll(keepingCapacity: false)
            }
        }
        return committed
    }
}
