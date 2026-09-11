// Author: Zeno Ren
import XCTest
import UsageCore
@testable import UsageTracking

final class MenuQuotaSummaryTests: XCTestCase {
    let now = Date(timeIntervalSince1970: 10_000)
    func quota(_ id: String, tool: Tool = .codex, percent: Double, age: Double = 0, reset: Date? = nil, amounts: QuotaAmounts? = nil) -> QuotaWindow {
        .init(id:id, tool:tool, title:id, usedPercent:percent, resetsAt:reset, capturedAt:now.addingTimeInterval(-age), source:"test", amounts:amounts)
    }
    func testUsesHighestWindowWithoutAddingPercentagesAndKeepsAllDetails() {
        let summary = MenuQuotaSummary(tool:.codex, quotas:[quota("5 小时",percent:20),quota("每周",percent:60),quota("other",tool:.claude,percent:99)], now:now)
        XCTAssertEqual(summary.primary?.usedPercent,60)
        XCTAssertEqual(summary.ringFraction,0.6)
        XCTAssertEqual(summary.windows.count,2)
        XCTAssertTrue(summary.details.contains("20.0%"))
        XCTAssertTrue(summary.details.contains("60.0%"))
        XCTAssertTrue(summary.details.contains("最高"))
    }
    func testPrefersFreshWindowButDoesNotHideStaleWindowInDetails() {
        let summary = MenuQuotaSummary(tool:.codex, quotas:[quota("old",percent:90,age:901),quota("fresh",percent:40)], now:now)
        XCTAssertEqual(summary.primary?.id,"fresh")
        XCTAssertTrue(summary.hasStaleWindows)
        XCTAssertTrue(summary.details.contains("old"))
        XCTAssertTrue(summary.details.contains("快照较旧"))
    }
    func testCreditsShowCompactTotalsAndExactHoverDetails() {
        let q = quota("AI Credits",tool:.copilot,percent:0.7,amounts:.init(unit:.credits,total:10_000_000,used:70_000))
        let summary = MenuQuotaSummary(tool:.copilot,quotas:[q],now:now)
        XCTAssertEqual(summary.amountText,"70K / 10M")
        XCTAssertEqual(summary.amountCaption,"已用 / 总 Credits")
        XCTAssertTrue(summary.details.contains("已用 70,000 / 总额度 10,000,000 Credits"))
        XCTAssertTrue(summary.details.contains("剩余 9,930,000 Credits"))
    }
    func testUnknownDoesNotBecomeZeroAndRequestUnitIsPreserved() {
        let empty = MenuQuotaSummary(tool:.copilot,quotas:[],now:now)
        XCTAssertNil(empty.primary)
        XCTAssertNil(empty.ringFraction)
        XCTAssertEqual(empty.percentText,"—")
        XCTAssertTrue(empty.details.contains("尚未获取"))
        let q = quota("Premium",tool:.copilot,percent:10,amounts:.init(unit:.requests,total:300,used:nil))
        let summary = MenuQuotaSummary(tool:.copilot,quotas:[q],now:now)
        XCTAssertEqual(summary.amountText,"— / 300")
        XCTAssertEqual(summary.amountCaption,"已用 / 总 Requests")
    }
    func testExpiredResetIsExplainedAndOveruseIsRetainedButRingClamped() {
        let q = quota("AI Credits",tool:.copilot,percent:125,reset:now.addingTimeInterval(-1))
        let summary = MenuQuotaSummary(tool:.copilot,quotas:[q],now:now)
        XCTAssertEqual(summary.percentText,"125.0%")
        XCTAssertEqual(summary.ringFraction,1)
        XCTAssertTrue(summary.details.contains("重置时间已过"))
        XCTAssertTrue(summary.details.contains("采集于"))
    }
}
