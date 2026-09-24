// Author: Zeno Ren
import XCTest
@testable import UsageCore
@testable import UsageTracking

final class MenuProjectNavigationTests: XCTestCase {
    @MainActor func testProjectNavigationUsesExactPathTodayAndClearsHiddenFilters() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at:directory) }
        let model = AppModel(dataDirectory:directory)
        var calendar = Calendar(identifier:.gregorian)
        calendar.timeZone = TimeZone(identifier:"Asia/Shanghai")!
        let now = TimeCodec.date("2026-09-24T04:00:00Z")!
        let day = calendar.startOfDay(for:now)
        func event(_ id: String, _ path: String, _ date: Date, _ tool: Tool = .codex) -> UsageEvent {
            .init(id:id,tool:tool,surface:"test",session:id,project:path,model:"unknown",timestamp:TimeCodec.string(date),tokens:.init(input:10),precision:.response)
        }
        model.snapshot.events = [event("old","/one/app",day.addingTimeInterval(-1)),event("first","/one/app",day),
                                 event("same-name","/two/app",now),event("newest","/one/app",now,.claude),
                                 event("future","/one/app",now.addingTimeInterval(1))]
        model.selectedTool = "copilot"; model.selectedClient = "old-client"; model.search = "unrelated"; model.rangeDays = 30
        model.config.projectNames["/one/app"] = "My App"
        model.selectMenuProject("/one/app",dayStart:day,now:now,calendar:calendar)
        XCTAssertEqual(model.selectedPage,.projects)
        XCTAssertEqual(model.rangeDays,1)
        XCTAssertEqual(model.selectedTool,"all")
        XCTAssertEqual(model.selectedClient,"all")
        XCTAssertEqual(model.search,"")
        XCTAssertEqual(model.selectedGroup?.id,"/one/app")
        XCTAssertEqual(model.selectedGroup?.name,"My App")
        XCTAssertEqual(model.selectedGroup?.events.map(\.id),["newest","first"])
    }

    @MainActor func testStaleDayOrMissingProjectNeverOpensAnOldDetail() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at:directory) }
        let model = AppModel(dataDirectory:directory)
        let now = Date()
        model.selectedGroup = UsageGroup(id:"old",name:"old",events:[])
        model.selectMenuProject("/repo",dayStart:Calendar.current.startOfDay(for:now).addingTimeInterval(-86400),now:now)
        XCTAssertNil(model.selectedGroup)
        XCTAssertNotNil(model.statusMessage)
        model.selectMenuProject("/missing",dayStart:Calendar.current.startOfDay(for:now),now:now)
        XCTAssertNil(model.selectedGroup)
    }
}
