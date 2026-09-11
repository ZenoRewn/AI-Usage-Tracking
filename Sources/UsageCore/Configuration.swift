// Author: Zeno Ren
import Foundation

public struct ModelRate: Codable, Identifiable, Sendable {
    public var id: String { tool.rawValue + ":" + model + ":" + effectiveFrom }
    public var model: String
    public var tool: Tool
    public var input: Double
    public var cacheRead: Double
    public var cacheWrite: Double
    public var output: Double
    public var effectiveFrom: String
    public init(model: String, tool: Tool, input: Double, cacheRead: Double, cacheWrite: Double, output: Double, effectiveFrom: String) {
        self.model = model; self.tool = tool; self.input = input; self.cacheRead = cacheRead; self.cacheWrite = cacheWrite; self.output = output; self.effectiveFrom = effectiveFrom
    }
}
public struct PriceCatalog: Codable, Sendable {
    public var rates: [ModelRate]
    public init(rates: [ModelRate] = []) { self.rates = rates }
    public func estimate(model: String, tool: Tool, tokens: TokenCounts, at: Date) -> Double? {
        quote(model:model,tool:tool,tokens:tokens,at:at)?.amount
    }
}

public struct AppConfiguration: Codable, Sendable {
    public var sources: [SourceFolder]
    public var prices = PriceCatalog()
    public var refreshSeconds = 30
    public var notifications = false
    public var projectNames: [String: String] = [:]
    public init(dataDirectory: URL) { sources = SourceFolder.defaults(dataDirectory: dataDirectory) }
    public static func load(from directory: URL) -> AppConfiguration {
        guard let data = try? Data(contentsOf: directory.appendingPathComponent("settings.json")), let config = try? JSONDecoder().decode(Self.self, from: data) else { return .init(dataDirectory: directory) }
        return config
    }
    public func save(to directory: URL) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted,.sortedKeys]
        let path = directory.appendingPathComponent("settings.json")
        try encoder.encode(self).write(to: path, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: path.path)
    }
}

public enum ConfigurationError: Error, LocalizedError {
    case invalidJSON, changedSincePreview
    public var errorDescription: String? { switch self { case .invalidJSON: "无法安全解析设置文件，原文件未修改。"; case .changedSincePreview: "设置文件在预览后发生变化，请重新预览。" } }
}

/// A lexical JSONC editor: preserve original bytes except selected top-level values.
public enum JSONCSettings {
    private struct Token { var text: String; var range: Range<Int> }
    private static func lex(_ source: String) throws -> [Token] {
        let bytes = Array(source.utf8); var i = 0; var tokens: [Token] = []
        while i < bytes.count {
            let c = bytes[i]
            if [9,10,13,32].contains(c) { i += 1; continue }
            if c == 47 && i+1 < bytes.count && bytes[i+1] == 47 { while i < bytes.count && bytes[i] != 10 { i += 1 }; continue }
            if c == 47 && i+1 < bytes.count && bytes[i+1] == 42 {
                i += 2
                while i+1 < bytes.count && !(bytes[i] == 42 && bytes[i+1] == 47) { i += 1 }
                guard i+1 < bytes.count else { throw ConfigurationError.invalidJSON }; i += 2; continue
            }
            let start = i
            if c == 34 {
                i += 1; var ended = false
                while i < bytes.count {
                    if bytes[i] == 92 { i += 2; continue }
                    if bytes[i] == 34 { i += 1; ended = true; break }; i += 1
                }
                guard ended else { throw ConfigurationError.invalidJSON }
            } else if [123,125,91,93,58,44].contains(c) { i += 1 }
            else { while i < bytes.count && ![9,10,13,32,123,125,91,93,58,44,47].contains(bytes[i]) { i += 1 } }
            guard i > start else { throw ConfigurationError.invalidJSON }
            tokens.append(Token(text: String(decoding: bytes[start..<i], as: UTF8.self), range: start..<i))
        }
        return tokens
    }
    public static func object(_ source: String) throws -> [String: Any] {
        let tokens = try lex(source)
        let clean = tokens.enumerated().filter { i,t in !(t.text == "," && i+1 < tokens.count && ["}","]"].contains(tokens[i+1].text)) }.map { $0.element.text }.joined()
        guard let result = try JSONSerialization.jsonObject(with: Data(clean.utf8)) as? [String: Any] else { throw ConfigurationError.invalidJSON }
        return result
    }
    public static func updating(_ source: String, values: [String: Any]) throws -> String {
        _ = try object(source)
        let tokens = try lex(source); guard tokens.first?.text == "{", tokens.last?.text == "}" else { throw ConfigurationError.invalidJSON }
        var edits: [(Range<Int>, [UInt8])] = [], remaining = values, i = 1
        while i < tokens.count - 1 {
            if tokens[i].text == "," { i += 1; continue }
            guard let key = try JSONSerialization.jsonObject(with: Data(tokens[i].text.utf8), options: [.fragmentsAllowed]) as? String, tokens[i+1].text == ":" else { throw ConfigurationError.invalidJSON }
            let start = i+2; var end = start; var depth = 0
            repeat {
                if ["{","["].contains(tokens[end].text) { depth += 1 }
                if ["}","]"].contains(tokens[end].text) { depth -= 1 }
                end += 1
            } while end < tokens.count - 1 && (depth > 0 || ![",","}"].contains(tokens[end].text))
            if let value = remaining.removeValue(forKey: key) {
                let encoded = try JSONSerialization.data(withJSONObject: value, options: [.fragmentsAllowed,.sortedKeys])
                edits.append((tokens[start].range.lowerBound..<tokens[end-1].range.upperBound, Array(encoded)))
            }
            i = end
        }
        var bytes = Array(source.utf8)
        if !remaining.isEmpty {
            let comma = tokens.count > 2 && tokens[tokens.count-2].text != "," ? "," : ""
            let entries = try remaining.sorted(by: { $0.key < $1.key }).map { k,v in
                let key = String(decoding: try JSONSerialization.data(withJSONObject: k, options: .fragmentsAllowed), as: UTF8.self)
                let value = String(decoding: try JSONSerialization.data(withJSONObject: v, options: [.fragmentsAllowed,.sortedKeys]), as: UTF8.self)
                return "  \(key): \(value)"
            }.joined(separator: ",\n")
            let at = tokens.last!.range.lowerBound
            edits.append((at..<at, Array((comma + "\n" + entries + "\n").utf8)))
        }
        for (range,replacement) in edits.sorted(by: { $0.0.lowerBound > $1.0.lowerBound }) { bytes.replaceSubrange(range, with: replacement) }
        let result = String(decoding: bytes, as: UTF8.self); _ = try object(result); return result
    }
}

public struct SettingsChange: Sendable {
    public var path: URL
    public var original: String
    public var updated: String
    public var existed: Bool
    public init(path: URL, values: [String: any Sendable]) throws {
        self.path = path; existed = FileManager.default.fileExists(atPath: path.path)
        original = existed ? try String(contentsOf: path, encoding: .utf8) : "{}"
        updated = try JSONCSettings.updating(original, values: values)
    }
    public func apply() throws -> URL {
        let current = FileManager.default.fileExists(atPath: path.path) ? try String(contentsOf: path, encoding: .utf8) : "{}"
        guard current == original else { throw ConfigurationError.changedSincePreview }
        try FileManager.default.createDirectory(at: path.deletingLastPathComponent(), withIntermediateDirectories: true)
        let backup = path.appendingPathExtension("usage-tracking-" + UUID().uuidString + ".backup")
        try Data(original.utf8).write(to: backup, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: backup.path)
        try Data(updated.utf8).write(to: path, options: .atomic)
        return backup
    }
}
