// Author: Zeno Ren
import XCTest
@testable import UsageCore

final class UsageWindowTests: XCTestCase {
    func testCalendarWindowsGroupToolsAndIgnoreFutureEvents() {
        var calendar = Calendar(identifier:.gregorian); calendar.timeZone = TimeZone(identifier:"Asia/Shanghai")!
        let now = TimeCodec.date("2026-09-09T04:00:00Z")!
        func e(_ date: String,_ tool: Tool,_ total: Int64) -> UsageEvent {
            .init(id:date,tool:tool,surface:tool.title,session:date,project:"/repo",model:"unknown",timestamp:date,tokens:.init(input:total),precision:.response)
        }
        let rows = [e("2026-09-08T16:00:00Z",.codex,1),e("2026-09-08T15:59:59Z",.codex,2),e("2026-09-02T16:00:00Z",.codex,4),e("2026-09-02T15:59:59Z",.codex,8),e("2026-08-10T16:00:00Z",.codex,16),e("2026-08-10T15:59:59Z",.codex,32),e("2026-09-09T05:00:00Z",.codex,64),e("2026-09-09T02:00:00Z",.claude,128)]
        let result = UsageWindows.summarize(rows,calendar:calendar,now:now)
        XCTAssertEqual(result.first { $0.tool == .codex }?.periods.map(\.tokens),[1,7,31])
        XCTAssertEqual(result.first { $0.tool == .claude }?.periods.map(\.tokens),[128,128,128])
        XCTAssertEqual(result.first { $0.tool == .copilot }?.periods.map(\.eventCount),[0,0,0])
        XCTAssertEqual(result.first { $0.tool == .codex }?.periods[0].pricedTokens,0)
    }
    func testDSTUsesCalendarDayAndPriceCoverageIsIndependent() {
        var calendar = Calendar(identifier:.gregorian); calendar.timeZone = TimeZone(identifier:"America/Los_Angeles")!
        let now = TimeCodec.date("2026-03-08T20:00:00Z")!
        let row = UsageEvent(id:"a",tool:.codex,surface:"Codex App",session:"s",project:"",model:"gpt-5.4-mini",timestamp:"2026-03-08T08:00:00Z",tokens:.init(input:1_000_000),precision:.response)
        let result = UsageWindows.summarize([row],calendar:calendar,now:now)
        let today = result[0].periods[0]
        XCTAssertEqual(today.tokens,1_000_000); XCTAssertEqual(today.estimatedCost,0.75,accuracy:0.000001)
        XCTAssertEqual(today.pricedTokens,1_000_000)
    }
}
