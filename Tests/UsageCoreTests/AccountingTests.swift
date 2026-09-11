// Author: Zeno Ren
import XCTest
@testable import UsageCore

final class AccountingTests: XCTestCase {
    func testCodexResponseReplacesCumulativeAndDoesNotAddCacheOrReasoning() throws {
        let parser = SessionParser(tool: .codex)
        let rows = [
            #"{"type":"session_meta","payload":{"id":"s","cwd":"/repo/a","source":"vscode"}}"#,
            #"{"type":"turn_context","payload":{"model":"model-a","turn_id":"t"}}"#,
            #"{"timestamp":"2026-09-08T23:59:00Z","type":"event_msg","payload":{"type":"token_count","info":{"total_token_usage":{"input_tokens":100,"cached_input_tokens":60,"output_tokens":20,"reasoning_output_tokens":5,"total_tokens":120}}}}"#,
            #"{"timestamp":"2026-09-08T23:59:00Z","type":"token_usage_record","payload":{"response_id":"r1","thread_id":"s","turn_id":"t","usage":{"input_tokens":100,"cached_input_tokens":60,"output_tokens":20,"reasoning_output_tokens":5,"total_tokens":120}}}"#,
            #"{"timestamp":"2026-09-09T00:01:00Z","type":"token_usage_record","payload":{"response_id":"r2","thread_id":"s","turn_id":"t2","usage":{"input_tokens":50,"output_tokens":10,"total_tokens":60}}}"#
        ]
        for row in rows { parser.consume(Data(row.utf8), offset: 0) }
        let result = parser.result()
        XCTAssertEqual(result.events.count, 2)
        XCTAssertEqual(result.events.reduce(0) { $0 + $1.tokens.total }, 180)
        XCTAssertEqual(result.events.first?.tokens.input, 100)
        XCTAssertEqual(Set(result.events.map { String($0.timestamp.prefix(10)) }).count, 2)
    }

    func testClaudeStreamingRevisionAndCacheAccounting() {
        let parser = SessionParser(tool: .claude)
        for output in [2, 9] {
            let row = """
            {"type":"assistant","timestamp":"2026-09-09T10:00:00Z","sessionId":"s","cwd":"/repo/a","requestId":"req","message":{"id":"msg","model":"claude-test","usage":{"input_tokens":10,"output_tokens":\(output),"cache_read_input_tokens":30,"cache_creation_input_tokens":5},"content":[{"text":"SENSITIVE_SENTINEL"}]}}
            """
            parser.consume(Data(row.utf8), offset: Int64(output))
        }
        let result = parser.result()
        XCTAssertEqual(result.events.count, 1)
        XCTAssertEqual(result.events[0].tokens.total, 54)
        XCTAssertEqual(result.events[0].tokens.input, 45)
        XCTAssertFalse(String(data: try! JSONEncoder().encode(result), encoding: .utf8)!.contains("SENSITIVE_SENTINEL"))
    }

    func testForkWithMissingBaselineIsNotBilledFromCumulative() {
        let parser = SessionParser(tool: .codex)
        parser.consume(Data(#"{"type":"session_meta","payload":{"id":"child","forked_from_id":"parent"}}"#.utf8), offset: 0)
        parser.consume(Data(#"{"type":"event_msg","timestamp":"2026-09-09T00:00:00Z","payload":{"type":"token_count","info":{"total_token_usage":{"input_tokens":120,"output_tokens":0,"total_tokens":120}}}}"#.utf8), offset: 1)
        XCTAssertTrue(parser.result().events.isEmpty)
        XCTAssertTrue(parser.result().warnings.contains("fork-baseline-unavailable"))
    }

    func testCopilotShutdownReplacesPriorSnapshotsAndDoesNotReadContextUsage() {
        let parser = SessionParser(tool: .copilot)
        parser.consume(Data(#"{"type":"session.start","data":{"sessionId":"s","producer":"agency","context":{"cwd":"/repo/a"}}}"#.utf8), offset: 0)
        for value in [100, 120] {
            parser.consume(Data("""
            {"type":"session.shutdown","timestamp":"2026-09-09T01:00:00Z","data":{"modelMetrics":{"model-a":{"usage":{"inputTokens":\(value),"outputTokens":20,"cacheReadTokens":60,"cacheWriteTokens":0},"requests":{"count":2,"cost":1}}}}}
            """.utf8), offset: Int64(value))
        }
        let events = parser.result().events
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events[0].surface, "Copilot App")
        XCTAssertEqual(events[0].precision, .session)
        XCTAssertNil(events[0].costUSD)
    }

    func testQuotaExpiredDoesNotBecomeZero() {
        let q = QuotaWindow(id: "q", tool: .codex, title: "5 小时", usedPercent: 85, resetsAt: Date(timeIntervalSince1970: 5), capturedAt: Date(timeIntervalSince1970: 0), source: "local")
        XCTAssertEqual(q.usedPercent, 85)
        XCTAssertTrue(q.isStale(at: Date(timeIntervalSince1970: 10)))
    }

    func testProjectSameBasenameDoesNotMerge() {
        XCTAssertNotEqual(ProjectResolver.canonicalRoot("/a/repo"), ProjectResolver.canonicalRoot("/b/repo"))
    }
}
