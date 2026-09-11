// Author: Zeno Ren
import XCTest
@testable import UsageCore

@MainActor final class IngestionTests: XCTestCase {
    func testRealFileAppendReplayAndRestartRemainIdempotent() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString,isDirectory:true)
        defer { try? FileManager.default.removeItem(at:root) }
        let logs = root.appendingPathComponent("logs",isDirectory:true)
        try FileManager.default.createDirectory(at:logs,withIntermediateDirectories:true)
        let file = logs.appendingPathComponent("session.jsonl")
        let meta = #"{"type":"session_meta","payload":{"id":"test","cwd":"/tmp/project","originator":"Codex Desktop"}}"#
        func event(_ id: String) -> String { """
        {"type":"token_usage_record","timestamp":"2026-09-09T01:00:00Z","payload":{"response_id":"\(id)","usage":{"input_tokens":10,"output_tokens":2,"total_tokens":12}}}
        """ }
        try Data((meta + "\n" + event("a") + "\n").utf8).write(to:file)
        let sources = [SourceFolder(id:"test",tool:.codex,title:"test",paths:[logs.path],scope:"test")]
        let data = root.appendingPathComponent("data",isDirectory:true)
        let scanner = try UsageScanner(dataDirectory:data)
        let first = try await scanner.scan(sources:sources)
        XCTAssertEqual(first.events.count,1)
        let replay = try await scanner.scan(sources:sources)
        XCTAssertEqual(replay.sources[0].changed,0)
        let append = try FileHandle(forWritingTo:file); try append.seekToEnd(); try append.write(contentsOf:Data((event("b") + "\n").utf8)); try append.close()
        let second = try await scanner.scan(sources:sources)
        XCTAssertEqual(second.events.reduce(0) { $0 + $1.tokens.total },24)
        let restarted = try UsageScanner(dataDirectory:data)
        let third = try await restarted.scan(sources:sources)
        XCTAssertEqual(third.events.count,2)
        XCTAssertEqual(third.sources[0].changed,0)
    }
}
