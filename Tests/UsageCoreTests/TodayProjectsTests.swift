// Author: Zeno Ren
import XCTest
@testable import UsageCore

final class TodayProjectsTests: XCTestCase {
    var calendar: Calendar {
        var value = Calendar(identifier:.gregorian)
        value.timeZone = TimeZone(identifier:"Asia/Shanghai")!
        return value
    }
    let now = TimeCodec.date("2026-09-11T04:00:00Z")!
    func event(_ id: String, project: String, tool: Tool = .codex, tokens: Int64, timestamp: String = "2026-09-11T02:00:00Z", precision: Precision = .response) -> UsageEvent {
        .init(id:id,tool:tool,surface:tool.title,session:id,project:project,model:"unknown",timestamp:timestamp,tokens:.init(input:tokens),precision:precision)
    }
    func testRanksTopThreeByCombinedTokensAndKeepsEveryToolBreakdown() {
        let rows = [event("a",project:"/a",tokens:100), event("b",project:"/a",tool:.claude,tokens:90),
                    event("c",project:"/a",tool:.copilot,tokens:10), event("d",project:"/b",tokens:180),
                    event("e",project:"/c",tokens:160), event("f",project:"/d",tokens:140)]
        let summary = TodayProjects.summarize(rows,calendar:calendar,now:now)
        XCTAssertEqual(summary.projects.map(\.project),["/a","/b","/c"])
        XCTAssertEqual(summary.projects.map(\.tokens),[200,180,160])
        XCTAssertEqual(summary.projects[0].tools.map(\.tool),[.codex,.claude,.copilot])
        XCTAssertEqual(summary.projects[0].tools.map(\.tokens),[100,90,10])
        XCTAssertEqual(summary.projectCount,4)
    }
    func testTodayStartsAtLocalMidnightAndExcludesFutureRecords() {
        let rows = [event("old",project:"/a",tokens:1000,timestamp:"2026-09-10T15:59:59Z"),
                    event("midnight",project:"/a",tokens:10,timestamp:"2026-09-10T16:00:00Z"),
                    event("now",project:"/b",tokens:20,timestamp:"2026-09-11T04:00:00Z"),
                    event("future",project:"/c",tokens:2000,timestamp:"2026-09-11T04:00:01Z")]
        let summary = TodayProjects.summarize(rows,calendar:calendar,now:now)
        XCTAssertEqual(summary.projects.map(\.tokens),[20,10])
        XCTAssertEqual(summary.dayStart,TimeCodec.date("2026-09-10T16:00:00Z"))
        XCTAssertTrue(TodayProjects.summarize(rows,calendar:calendar,now:now.addingTimeInterval(86400)).projects.isEmpty)
    }
    func testUnknownProjectIsSeparateAndSameBasenameNeverMerges() {
        let rows = [event("a",project:"/one/app",tokens:100),event("b",project:"/two/app",tokens:100),
                    event("unknown",project:"",tokens:999),event("zero",project:"/zero",tokens:0)]
        let summary = TodayProjects.summarize(rows.reversed(),calendar:calendar,now:now)
        XCTAssertEqual(summary.projects.map(\.project),["/one/app","/two/app"])
        XCTAssertEqual(summary.unassignedTokens,999)
        XCTAssertEqual(summary.projectCount,2)
    }
    func testCacheSubsetsAreNotAddedAgainAndApproximateDatesAreVisible() {
        var row = event("a",project:"/repo",tool:.copilot,tokens:0,precision:.session)
        row.tokens = .init(input:1000,output:100,cacheRead:700,reasoning:50)
        let summary = TodayProjects.summarize([row],calendar:calendar,now:now)
        XCTAssertEqual(summary.projects[0].tokens,1100)
        XCTAssertEqual(summary.projects[0].tools[0].input,1000)
        XCTAssertEqual(summary.projects[0].tools[0].output,100)
        XCTAssertTrue(summary.projects[0].hasApproximateDates)
    }
    func testEmptyTodayDoesNotFabricateProjects() {
        let summary = TodayProjects.summarize([],calendar:calendar,now:now)
        XCTAssertTrue(summary.projects.isEmpty)
        XCTAssertEqual(summary.projectCount,0)
        XCTAssertEqual(summary.unassignedTokens,0)
    }
    func testDSTUsesLocalCalendarDay() {
        var pacific = Calendar(identifier:.gregorian); pacific.timeZone = TimeZone(identifier:"America/Los_Angeles")!
        let date = TimeCodec.date("2026-03-08T20:00:00Z")!
        let rows = [event("before",project:"/repo",tokens:99,timestamp:"2026-03-08T07:59:59Z"),
                    event("after",project:"/repo",tokens:10,timestamp:"2026-03-08T08:00:00Z")]
        XCTAssertEqual(TodayProjects.summarize(rows,calendar:pacific,now:date).projects.first?.tokens,10)
    }
    func testProjectCostsUseConfiguredPricesAndTrackPartialCoverage() {
        var priced = event("priced",project:"/repo",tokens:1_000_000)
        priced.model = "custom"; priced.tokens.cacheRead = 600_000
        let unpriced = event("unpriced",project:"/repo",tool:.claude,tokens:1_000_000)
        let catalog = PriceCatalog(rates:[.init(model:"custom",tool:.codex,input:4,cacheRead:1,cacheWrite:4,output:10,effectiveFrom:"2020-01-01")])
        let summary = TodayProjects.summarize([priced,unpriced],catalog:catalog,calendar:calendar,now:now)
        XCTAssertEqual(summary.projects[0].estimatedCost,2.2,accuracy:0.000001)
        XCTAssertEqual(summary.projects[0].pricedTokens,1_000_000)
        XCTAssertEqual(summary.projects[0].tokens,2_000_000)
        XCTAssertEqual(summary.projects[0].tools[0].estimatedCost,2.2,accuracy:0.000001)
        XCTAssertEqual(summary.projects[0].tools[1].pricedTokens,0)
    }
}
