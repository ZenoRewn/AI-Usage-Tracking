// Author: Zeno Ren
import XCTest
@testable import UsageCore

final class ConfigurationTests: XCTestCase {
    func testCopilotQuotaSkipsUnlimitedAndDoesNotCallMeteredUnitsTokens() {
        let result: [String:Any] = ["quotaSnapshots":["chat":["isUnlimitedEntitlement":true,"remainingPercentage":100.0],"premium_interactions":["isUnlimitedEntitlement":false,"entitlementRequests":1000,"remainingPercentage":75.0,"tokenBasedBilling":true]]]
        let windows = CopilotQuotaClient.parse(result)
        XCTAssertEqual(windows.count,1); XCTAssertEqual(windows[0].usedPercent,25); XCTAssertEqual(windows[0].title,"AI Credits")
    }
    func testStatusBridgeOnlyKeepsQuotaFields() throws {
        let source: [String:Any] = ["session_id":"private","prompt":"SECRET", "rate_limits":["five_hour":["used_percentage":70,"resets_at":100,"secret":"SECRET"]]]
        let data = try JSONSerialization.data(withJSONObject:StatusLineBridge.snapshot(source))
        let output = String(decoding:data,as:UTF8.self)
        XCTAssertFalse(output.contains("SECRET")); XCTAssertFalse(output.contains("private")); XCTAssertTrue(output.contains("70"))
    }
    func testQuotaParserSupportsMultipleWindowsAndMissingValues() {
        let response: [String:Any] = ["rateLimitsByLimitId":["codex":["primary":["usedPercent":60.0,"windowDurationMins":300,"resetsAt":2000.0],"secondary":["windowDurationMins":10080]],"other":["primary":["usedPercent":25.0,"windowDurationMins":60]]]]
        let windows = CodexQuotaClient.parse(response)
        XCTAssertEqual(windows.count,2); XCTAssertEqual(windows.first { $0.title == "5 小时" }?.usedPercent,60)
    }
    func testJSONCPreservesCommentsAndNestedSettings() throws {
        let source = """
        {
          // keep this comment
          "editor.fontSize": 14,
          "nested": {"github.copilot.chat.otel.enabled": false},
          "github.copilot.chat.otel.enabled": false,
        }
        """
        let output = try JSONCSettings.updating(source, values: ["github.copilot.chat.otel.enabled": true,"github.copilot.chat.otel.outfile":"/safe/local.jsonl"])
        XCTAssertTrue(output.contains("// keep this comment"))
        XCTAssertTrue(output.contains("\"nested\": {\"github.copilot.chat.otel.enabled\": false}"))
        XCTAssertTrue(output.contains("\"github.copilot.chat.otel.enabled\": true"))
        XCTAssertEqual(try JSONCSettings.object(output)["editor.fontSize"] as? Int, 14)
    }
    func testUnknownPriceDoesNotBecomeFree() {
        let catalog = PriceCatalog(rates: [])
        XCTAssertNil(catalog.estimate(model: "unknown", tool: .codex, tokens: .init(input: 100), at: Date()))
    }
    func testPriceCacheSubsetIsPricedOnlyOnce() {
        let rate = ModelRate(model: "m", tool: .codex, input: 10, cacheRead: 1, cacheWrite: 10, output: 20, effectiveFrom: "2020-01-01")
        let catalog = PriceCatalog(rates: [rate])
        XCTAssertEqual(catalog.estimate(model: "m", tool: .codex, tokens: .init(input: 1_000_000, output: 0, cacheRead: 600_000), at: Date())!, 4.6, accuracy: 0.0001)
    }
}
