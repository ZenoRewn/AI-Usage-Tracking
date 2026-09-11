// Author: Zeno Ren
import Foundation

public enum QuotaError: Error, LocalizedError {
    case unavailable(String)
    public var errorDescription: String? { if case .unavailable(let s) = self { return s }; return nil }
}

public enum CodexQuotaClient {
    public static func executable() -> String? {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return [home + "/.local/bin/codex","/opt/homebrew/bin/codex","/usr/local/bin/codex"].first { FileManager.default.isExecutableFile(atPath: $0) }
    }
    /// Calls the tool's own read-only interface; never reads or copies authentication files.
    public static func fetch() throws -> [QuotaWindow] {
        guard let executable = executable() else { throw QuotaError.unavailable("未找到 Codex CLI，可继续查看日志中的配额快照。") }
        let p = Process(), input = Pipe(), output = Pipe()
        p.executableURL = URL(fileURLWithPath: executable)
        p.arguments = ["-s","read-only","-a","never","app-server","--disable","plugins"]
        p.currentDirectoryURL = FileManager.default.temporaryDirectory
        var environment = ProcessInfo.processInfo.environment
        environment["PATH"] = "/opt/homebrew/bin:/usr/local/bin:" + (environment["PATH"] ?? "/usr/bin:/bin")
        p.environment = environment
        p.standardInput = input; p.standardOutput = output; p.standardError = FileHandle.nullDevice
        try p.run()
        let killer = DispatchWorkItem {
            if p.isRunning { p.terminate() }
            DispatchQueue.global().asyncAfter(deadline: .now()+1) { if p.isRunning { kill(p.processIdentifier, SIGKILL) } }
        }
        DispatchQueue.global().asyncAfter(deadline: .now()+12, execute: killer)
        defer { killer.cancel(); try? input.fileHandleForWriting.close(); if p.isRunning { p.terminate() }; try? output.fileHandleForReading.close() }
        func send(_ object: [String: Any]) throws { var d = try JSONSerialization.data(withJSONObject: object); d.append(10); try input.fileHandleForWriting.write(contentsOf: d) }
        try send(["id":1,"method":"initialize","params":["clientInfo":["name":"usage_tracking","version":UsageCoreVersion.current]]])
        var buffer = Data(), read = 0
        while read < 2_000_000 {
            let chunk = output.fileHandleForReading.availableData
            if chunk.isEmpty { break }; read += chunk.count; buffer.append(chunk)
            while let newline = buffer.firstIndex(of: 10) {
                let data = Data(buffer[..<newline]); buffer.removeSubrange(...newline)
                guard let row = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { continue }
                if (row["id"] as? Int) == 1 {
                    guard row["error"] == nil else { throw QuotaError.unavailable("Codex 运行时不支持初始化，请检查 CLI 版本。") }
                    try send(["method":"initialized"])
                    try send(["id":2,"method":"account/rateLimits/read"])
                } else if (row["id"] as? Int) == 2 {
                    guard row["error"] == nil else { throw QuotaError.unavailable("Codex 未返回账户额度。请在 Codex 中确认登录，API Key 模式可能不提供订阅额度。") }
                    return parse(row.object("result"))
                }
            }
        }
        throw QuotaError.unavailable("Codex 额度查询超时或未返回数据；保留最后快照。")
    }
    public static func parse(_ result: [String: Any], now: Date = Date()) -> [QuotaWindow] {
        var groups = result.object("rateLimitsByLimitId")
        if groups.isEmpty { groups = ["codex":result.object("rateLimits")] }
        var windows: [QuotaWindow] = []
        for (limit, object) in groups {
            guard let bucket = object as? [String: Any] else { continue }
            for key in ["primary","secondary"] {
                let b = bucket.object(key)
                guard let pct = b["usedPercent"] as? Double, pct.isFinite else { continue }
                let duration = b.number("windowDurationMins")
                let title = duration == 300 ? "5 小时" : duration == 10080 ? "每周" : "\(duration) 分钟"
                windows.append(.init(id: "rpc:\(limit):\(key)", tool: .codex, title: limit == "codex" ? title : limit + " · " + title, usedPercent: pct, resetsAt: (b["resetsAt"] as? Double).map { Date(timeIntervalSince1970: $0) }, capturedAt: now, source: "Codex 当前登录账户 · RPC"))
            }
        }
        return windows
    }
}
