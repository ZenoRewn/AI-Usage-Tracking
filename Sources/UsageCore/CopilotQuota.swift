// Author: Zeno Ren
import Foundation

public enum CopilotQuotaClient {
    public static func fetch() throws -> [QuotaWindow] {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        guard let path = ["/opt/homebrew/bin/copilot","/usr/local/bin/copilot",home + "/.local/bin/copilot"].first(where:{ FileManager.default.isExecutableFile(atPath:$0) }) else { throw QuotaError.unavailable("未找到 Copilot CLI；可打开官方用量页核对。") }
        let process = Process(), input = Pipe(), output = Pipe()
        process.executableURL = URL(fileURLWithPath:path)
        process.arguments = ["--headless","--no-auto-update","--stdio","--disable-builtin-mcps","--no-remote-export"]
        process.currentDirectoryURL = FileManager.default.temporaryDirectory
        var environment = ProcessInfo.processInfo.environment
        environment["PATH"] = "/opt/homebrew/bin:/usr/local/bin:\(home)/.local/bin:" + (environment["PATH"] ?? "/usr/bin:/bin")
        process.environment = environment
        process.standardInput = input; process.standardOutput = output; process.standardError = FileHandle.nullDevice
        try process.run()
        let timeout = DispatchWorkItem { if process.isRunning { process.terminate() }; DispatchQueue.global().asyncAfter(deadline:.now()+1) { if process.isRunning { kill(process.processIdentifier,SIGKILL) } } }
        DispatchQueue.global().asyncAfter(deadline:.now()+12,execute:timeout)
        defer { timeout.cancel(); try? input.fileHandleForWriting.close(); if process.isRunning { process.terminate() }; try? output.fileHandleForReading.close() }
        let request = try JSONSerialization.data(withJSONObject:["jsonrpc":"2.0","id":1,"method":"account.getQuota","params":[:]])
        try input.fileHandleForWriting.write(contentsOf:Data("Content-Length: \(request.count)\r\n\r\n".utf8) + request)
        var buffer = Data(), count = 0
        let separator = Data("\r\n\r\n".utf8)
        while count < 2_000_000 {
            let chunk = output.fileHandleForReading.availableData
            if chunk.isEmpty { break }; count += chunk.count; buffer.append(chunk)
            while let headerEnd = buffer.range(of:separator) {
                let header = String(decoding:buffer[..<headerEnd.lowerBound],as:UTF8.self)
                guard let lengthLine = header.components(separatedBy:"\r\n").first(where:{$0.lowercased().hasPrefix("content-length:")}),
                      let length = Int(lengthLine.dropFirst(15).trimmingCharacters(in:.whitespaces)), length >= 0, length <= 2_000_000 else { throw QuotaError.unavailable("Copilot RPC 返回不兼容的数据格式。") }
                let start = headerEnd.upperBound
                guard buffer.distance(from:start,to:buffer.endIndex) >= length else { break }
                let end = buffer.index(start,offsetBy:length); let body = Data(buffer[start..<end]); buffer.removeSubrange(..<end)
                guard let row = try? JSONSerialization.jsonObject(with:body) as? [String:Any], (row["id"] as? Int) == 1 else { continue }
                if row["error"] != nil { throw QuotaError.unavailable("Copilot 未提供账户额度；请在 Copilot 中确认登录和当前版本。") }
                return parse(row.object("result"))
            }
        }
        throw QuotaError.unavailable("Copilot 额度查询超时；已保留最近快照。")
    }
    public static func parse(_ result: [String:Any], now: Date = Date()) -> [QuotaWindow] {
        var windows: [QuotaWindow] = []
        for (key,value) in result.object("quotaSnapshots") {
            guard let q = value as? [String:Any], q["isUnlimitedEntitlement"] as? Bool != true,
                  let remaining = q["remainingPercentage"] as? Double, remaining.isFinite,
                  let total = (q["entitlementRequests"] as? NSNumber)?.doubleValue, total.isFinite, total > 0 else { continue }
            // Match VS Code's quota presentation: token billing uses these counters as Credits.
            // No token-price or currency conversion is applied. See docs/QUOTA_SEMANTICS.md.
            let credits = q["tokenBasedBilling"] as? Bool == true
            let title = credits ? "AI Credits" : key == "premium_interactions" ? "Premium Requests" : key == "chat" ? "Chat" : key
            let amounts = QuotaAmounts(unit: credits ? .credits : .requests, total: total, used: (q["usedRequests"] as? NSNumber)?.doubleValue)
            let reset = TimeCodec.date(q.string("resetDate"))
            windows.append(.init(id:"copilot-rpc:\(key)",tool:.copilot,title:title,usedPercent:max(0,100-remaining),resetsAt:reset,capturedAt:now,source:"账户返回 · \(amounts.unit.rawValue)",amounts:amounts))
        }
        return windows
    }
}
