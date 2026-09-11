// Author: Zeno Ren
import Foundation

public enum StatusLineBridge {
    /// CLI helper: bounded, local, metadata-only capture; stdout remains owned by the original command.
    public static func run(directory: URL) {
        var data = Data()
        while data.count < 2_000_000 {
            guard let chunk = try? FileHandle.standardInput.read(upToCount: min(64*1024,2_000_000-data.count)), !chunk.isEmpty else { break }
            data.append(chunk)
        }
        if let row = try? JSONSerialization.jsonObject(with:data) as? [String:Any] {
            let sanitized = snapshot(row)
            if let encoded = try? JSONSerialization.data(withJSONObject:sanitized,options:.sortedKeys) {
                try? FileManager.default.createDirectory(at:directory,withIntermediateDirectories:true,attributes:[.posixPermissions:0o700])
                let path = directory.appendingPathComponent("claude-status.json")
                try? encoded.write(to:path,options:.atomic)
                try? FileManager.default.setAttributes([.posixPermissions:0o600],ofItemAtPath:path.path)
            }
        }
        guard let config = try? Data(contentsOf:directory.appendingPathComponent("bridge-config.json")),
              let row = try? JSONSerialization.jsonObject(with:config) as? [String:Any],
              let command = row.object("originalStatusLine")["command"] as? String, !command.isEmpty,
              !command.contains("--claude-statusline") else { return }
        let process = Process(), stdin = Pipe()
        process.executableURL = URL(fileURLWithPath:"/bin/zsh"); process.arguments = ["-c",command]
        process.standardInput = stdin; process.standardOutput = FileHandle.standardOutput; process.standardError = FileHandle.nullDevice
        do {
            try process.run()
            let timeout = DispatchWorkItem { if process.isRunning { process.terminate() }; DispatchQueue.global().asyncAfter(deadline:.now()+0.3) { if process.isRunning { kill(process.processIdentifier,SIGKILL) } } }
            DispatchQueue.global().asyncAfter(deadline:.now()+2,execute:timeout)
            try stdin.fileHandleForWriting.write(contentsOf:data); try stdin.fileHandleForWriting.close(); process.waitUntilExit(); timeout.cancel()
        } catch { /* Never interrupt the coding tool because monitoring failed. */ }
    }
    public static func snapshot(_ row: [String:Any]) -> [String:Any] {
        var limits: [String:Any] = [:]
        for key in ["five_hour","seven_day"] {
            let b = row.object("rate_limits").object(key)
            var item: [String:Any] = [:]
            for field in ["used_percentage","resets_at"] { if let n = b[field] as? NSNumber { item[field] = n } }
            if !item.isEmpty { limits[key] = item }
        }
        return ["author":"Zeno Ren","rate_limits":limits,"captured_at":TimeCodec.string(Date())]
    }
}
