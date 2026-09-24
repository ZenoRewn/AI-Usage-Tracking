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

    func testPressureThresholdsAndUnknownAreDistinctFromZero() {
        XCTAssertEqual(MenuQuotaSummary(tool:.codex,quotas:[],now:now).pressure,.unknown)
        for (value, expected) in [(0.0,QuotaPressure.normal),(79.9,.normal),(80,.warning),(89.9,.warning),(90,.critical),(125,.critical)] {
            XCTAssertEqual(MenuQuotaSummary(tool:.codex,quotas:[quota("5 小时",percent:value)],now:now).pressure,expected)
        }
        let stale = MenuQuotaSummary(tool:.codex,quotas:[quota("每周",percent:99,age:901)],now:now)
        XCTAssertEqual(stale.pressure,.stale)
        XCTAssertEqual(stale.statusText(loading:false,error:nil),"旧快照")
        XCTAssertEqual(stale.percentText,"99.0%", "Keep the last reading without presenting it as current")
    }

    func testRingRepresentsReportedUsageRegardlessOfBrand() throws {
        for tool in Tool.allCases {
            for (percent,fraction) in [(0.0,0.0),(2.7,0.027),(21,0.21),(52,0.52),(86,0.86),(100,1.0),(125,1.0)] {
                let summary = MenuQuotaSummary(tool:tool,quotas:[quota("window",tool:tool,percent:percent)],now:now)
                XCTAssertEqual(try XCTUnwrap(summary.ringFraction),fraction,accuracy:0.000001)
            }
        }
    }

    func testResetCountdownBoundariesAndMissingTime() {
        for (seconds, expected) in [(30.0,"不到 1 分钟后重置"),(60,"1m 后重置"),(3060,"51m 后重置"),(8280,"2h 18m 后重置"),(86399,"1 天后重置"),(86400,"1 天后重置"),(93600,"1 天 2h 后重置")] {
            let summary = MenuQuotaSummary(tool:.codex,quotas:[quota("5 小时",percent:20,reset:now.addingTimeInterval(seconds))],now:now)
            XCTAssertEqual(summary.resetText,expected)
        }
        let missing = MenuQuotaSummary(tool:.codex,quotas:[quota("5 小时",percent:0)],now:now)
        XCTAssertEqual(missing.resetText,"未提供重置时间")
        let expired = MenuQuotaSummary(tool:.codex,quotas:[quota("5 小时",percent:100,reset:now)],now:now)
        XCTAssertEqual(expired.resetText,"等待新窗口")
        let stale = MenuQuotaSummary(tool:.codex,quotas:[quota("每周",percent:60,age:901,reset:now.addingTimeInterval(3600))],now:now)
        XCTAssertEqual(stale.resetText,"重置时间待确认")
    }

    func testVisibleStatusDoesNotMislabelUnknownAsDisconnectedOrHideFailure() {
        let empty = MenuQuotaSummary(tool:.claude,quotas:[],now:now)
        XCTAssertEqual(empty.statusText(loading:false,error:nil),"等待额度快照")
        XCTAssertEqual(empty.statusText(loading:true,error:nil),"正在查询")
        XCTAssertEqual(empty.statusText(loading:false,error:"offline"),"刷新失败")
        let partial = MenuQuotaSummary(tool:.codex,quotas:[quota("5 小时",percent:20),quota("每周",percent:99,age:901)],now:now)
        XCTAssertEqual(partial.pressure,.normal)
        XCTAssertEqual(partial.statusText(loading:false,error:nil),"含旧窗口")
        XCTAssertEqual(partial.windowText,"5 小时 · 最高有效窗口")
    }

    func testOutOfRangeResetTimeIsReportedInsteadOfCrashingTheMenu() {
        let invalid = MenuQuotaSummary(tool:.codex,quotas:[quota("5 小时",percent:20,reset:Date(timeIntervalSince1970:1e30))],now:now)
        XCTAssertEqual(invalid.resetText,"重置时间无效")
    }
}
