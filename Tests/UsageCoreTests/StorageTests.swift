// Author: Zeno Ren
import XCTest
@testable import UsageCore

final class StorageTests: XCTestCase {
    func testFailedEncodingRollsBackEventsAndCheckpointTogether() throws {
        let db = try UsageDatabase(path:":memory:")
        var checkpoint = FileCheckpoint(); checkpoint.offset = 42
        try db.save(file:"a",events:[event()],state:.init(),checkpoint:checkpoint,reset:true)
        var invalid = event("bad"); invalid.costUSD = .infinity
        XCTAssertThrowsError(try db.save(file:"a",events:[invalid],state:.init(),checkpoint:.init(),reset:true))
        XCTAssertEqual(try db.events().map(\.id),["one"])
        XCTAssertEqual(try db.checkpoint(file:"a")?.1.offset,42)
    }
    func testWorktreeResolvesSharedGitRoot() throws {
        let base = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString,isDirectory:true)
        defer { try? FileManager.default.removeItem(at:base) }
        let repo = base.appendingPathComponent("repo",isDirectory:true), work = base.appendingPathComponent("work",isDirectory:true)
        let metadata = repo.appendingPathComponent(".git/worktrees/test",isDirectory:true)
        try FileManager.default.createDirectory(at:metadata,withIntermediateDirectories:true)
        try FileManager.default.createDirectory(at:work,withIntermediateDirectories:true)
        try Data("../..\n".utf8).write(to:metadata.appendingPathComponent("commondir"))
        try Data("gitdir: \(metadata.path)\n".utf8).write(to:work.appendingPathComponent(".git"))
        XCTAssertEqual(ProjectResolver.canonicalRoot(work.path),repo.resolvingSymlinksInPath().path)
    }
    func testVSCodeReadableSpanUsesPrivateSpanContextAndHrTime() {
        let parser = SessionParser(tool:.copilot)
        parser.consume(Data(#"{"_spanContext":{"traceId":"trace","spanId":"child"},"endTime":[1788951600,123000000],"attributes":{"gen_ai.operation.name":"chat","gen_ai.conversation.id":"session","gen_ai.usage.input_tokens":10,"gen_ai.usage.output_tokens":2}}"#.utf8),offset:0)
        XCTAssertEqual(parser.result().events.first?.tokens.total,12)
    }
    func event(_ id: String = "one") -> UsageEvent {
        .init(id: id, tool: .claude, surface: "Claude Code CLI", session: "s", project: "/repo/a", model: "m", timestamp: "2026-09-09T10:00:00Z", tokens: .init(input: 10, output: 2), precision: .response)
    }
    func testRepeatedImportAndCopiedFileDoNotDoubleCount() throws {
        let db = try UsageDatabase(path: ":memory:")
        try db.save(file: "a", events: [event()], state: .init(), checkpoint: .init(), reset: true)
        try db.save(file: "a", events: [event()], state: .init(), checkpoint: .init(), reset: false)
        try db.save(file: "b", events: [event()], state: .init(), checkpoint: .init(), reset: true)
        XCTAssertEqual(try db.events().count, 1)
        try db.save(file: "a", events: [], state: .init(), checkpoint: .init(), reset: true)
        XCTAssertEqual(try db.events().count, 1)
    }
    func testModernEventSuppressesLegacySnapshot() throws {
        let db = try UsageDatabase(path: ":memory:")
        var legacy = event("snapshot"); legacy.tool = .codex; legacy.precision = .snapshot
        var modern = event("response"); modern.tool = .codex
        try db.save(file: "a", events: [legacy], state: .init(), checkpoint: .init(), reset: true)
        try db.save(file: "b", events: [modern], state: .init(), checkpoint: .init(), reset: true)
        XCTAssertEqual(try db.events().map(\.id), ["response"])
    }
    func testReaderDoesNotCommitPartialLine() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: url) }
        try Data("one\ntw".utf8).write(to: url)
        var lines: [String] = []
        let end = try JSONLReader.read(url: url, offset: 0) { line, _ in lines.append(String(decoding: line, as: UTF8.self)) }
        XCTAssertEqual(end, 4); XCTAssertEqual(lines, ["one"])
        try Data("one\ntwo\n".utf8).write(to: url)
        let next = try JSONLReader.read(url: url, offset: end) { line, _ in lines.append(String(decoding: line, as: UTF8.self)) }
        XCTAssertEqual(next, 8); XCTAssertEqual(lines, ["one", "two"])
    }
    func testOTelParentAndChildAreNotAddedTogether() {
        let parser = SessionParser(tool: .copilot)
        let rows = [
            #"{"traceId":"trace","spanId":"parent","endTimeUnixNano":"1788951600000000000","attributes":{"gen_ai.operation.name":"invoke_agent","gen_ai.conversation.id":"s","gen_ai.usage.input_tokens":30}}"#,
            #"{"traceId":"trace","spanId":"one","endTimeUnixNano":"1788951600000000000","attributes":{"gen_ai.operation.name":"chat","gen_ai.conversation.id":"s","gen_ai.usage.input_tokens":10}}"#,
            #"{"traceId":"trace","spanId":"two","endTimeUnixNano":"1788951600000000000","attributes":{"gen_ai.operation.name":"chat","gen_ai.conversation.id":"s","gen_ai.usage.input_tokens":20}}"#
        ]
        for row in rows { parser.consume(Data(row.utf8), offset: 0) }
        XCTAssertEqual(parser.result().events.reduce(0) { $0 + $1.tokens.total }, 30)
    }
    func testExportIsRedactedAndDoesNotExecuteSpreadsheetFormulas() throws {
        var e = event(); e.project = "/private/person/secret"; e.model = "=CMD()"
        let json = try UsageExporter.json([e], includePaths: false)
        XCTAssertFalse(String(decoding: json, as: UTF8.self).contains("/private/person"))
        let csv = UsageExporter.csv([e], includePaths: false)
        XCTAssertTrue(csv.contains("'=CMD()")); XCTAssertTrue(csv.contains("Zeno Ren"))
    }
}
