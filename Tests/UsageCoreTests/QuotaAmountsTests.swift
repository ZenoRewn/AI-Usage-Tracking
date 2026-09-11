// Author: Zeno Ren
import XCTest
@testable import UsageCore

final class QuotaAmountsTests: XCTestCase {
    func testCopilotCreditsUseReportedCountersWithoutInventingScale() throws {
        let result: [String: Any] = ["quotaSnapshots": ["premium_interactions": ["entitlementRequests": 10_000_000, "usedRequests": 50_000, "remainingPercentage": 99.5, "tokenBasedBilling": true]]]
        let quota = try XCTUnwrap(CopilotQuotaClient.parse(result).first)
        XCTAssertEqual(quota.amounts?.unit, .credits)
        XCTAssertEqual(quota.amounts?.total, 10_000_000)
        XCTAssertEqual(quota.amounts?.used, 50_000)
        XCTAssertEqual(quota.amounts?.remaining, 9_950_000)
        XCTAssertEqual(quota.usedPercent, 0.5)
    }

    func testMissingCountersRemainUnknownAndRequestsKeepTheirUnit() throws {
        let result: [String: Any] = ["quotaSnapshots": ["premium_interactions": ["entitlementRequests": 300, "remainingPercentage": 80.0, "tokenBasedBilling": false]]]
        let quota = try XCTUnwrap(CopilotQuotaClient.parse(result).first)
        XCTAssertEqual(quota.amounts?.unit, .requests)
        XCTAssertEqual(quota.amounts?.total, 300)
        XCTAssertNil(quota.amounts?.used)
        XCTAssertNil(quota.amounts?.remaining)
    }

    func testAbsentBillingFlagDoesNotAssumeCreditsAndZeroUsedIsKnown() throws {
        let result: [String: Any] = ["quotaSnapshots": ["premium_interactions": ["entitlementRequests": 300, "usedRequests": 0, "remainingPercentage": 100.0]]]
        let quota = try XCTUnwrap(CopilotQuotaClient.parse(result).first)
        XCTAssertEqual(quota.amounts?.unit, .requests)
        XCTAssertEqual(quota.amounts?.used, 0)
        XCTAssertEqual(quota.amounts?.remaining, 300)
    }

    func testInvalidCountsAreNotPersistedAndOveruseIsNotClamped() throws {
        let result: [String: Any] = ["quotaSnapshots": ["premium_interactions": ["entitlementRequests": 300, "usedRequests": -5, "remainingPercentage": 80.0, "tokenBasedBilling": true]]]
        XCTAssertNil(CopilotQuotaClient.parse(result).first?.amounts?.used)
        let over = QuotaAmounts(unit: .credits, total: 300, used: 350)
        XCTAssertEqual(over.used, 350)
        XCTAssertEqual(over.remaining, 0)
    }

    func testOldStoredQuotaStillDecodesWithoutAmounts() throws {
        let old = Data(#"{"id":"q","tool":"copilot","title":"AI 用量","usedPercent":0.5,"capturedAt":1000,"source":"local"}"#.utf8)
        let q = try JSONDecoder().decode(QuotaWindow.self, from: old)
        XCTAssertNil(q.amounts)
        let roundTrip = try JSONDecoder().decode(QuotaWindow.self, from: JSONEncoder().encode(q))
        XCTAssertEqual(roundTrip.usedPercent, 0.5)
    }

    func testLocalScanCannotOverwriteNewerRemoteWindowsOrRestoreRemovedOnes() {
        func quota(_ id: String, _ captured: Double) -> QuotaWindow {
            .init(id: id, tool: .copilot, title: "Credits", usedPercent: 10, resetsAt: nil, capturedAt: Date(timeIntervalSince1970: captured), source: "rpc")
        }
        let merged = QuotaWindow.mergingScan([quota("copilot-rpc:old", 10)], current: [quota("copilot-rpc:new", 20)])
        XCTAssertEqual(merged.map(\.id), ["copilot-rpc:new"])
    }
}
