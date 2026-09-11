// Author: Zeno Ren
import XCTest
@testable import UsageCore

final class RefreshTests: XCTestCase {
    let now = Date(timeIntervalSince1970: 1_000)

    func testDefaultAndLongIntervalsPreserveExistingSettings() throws {
        let data = Data(#"{"sources":[],"prices":{"rates":[]},"refreshSeconds":30,"notifications":true,"projectNames":{"/work":"Work"}}"#.utf8)
        let config = try JSONDecoder().decode(AppConfiguration.self, from: data)
        XCTAssertEqual(config.refreshSeconds, 30)
        XCTAssertEqual(config.projectNames["/work"], "Work")
        XCTAssertTrue(config.notifications)
        XCTAssertEqual(RefreshPolicy.interval(for: .local, seconds: 30), 30)
        XCTAssertEqual(RefreshPolicy.interval(for: .copilot, seconds: 30), 300)
        XCTAssertEqual(RefreshPolicy.options, [30, 300, 1800, 3600, 10800, 21600, 43200, 86400])
        for seconds in RefreshPolicy.options.dropFirst() {
            for target in RefreshTarget.allCases {
                XCTAssertEqual(RefreshPolicy.interval(for: target, seconds: seconds), TimeInterval(seconds))
            }
        }
    }

    func testRefreshDoesNotOverlapAndChangingIntervalRecalculatesDeadline() {
        var schedule = RefreshSchedule()
        XCTAssertTrue(schedule.begin(.copilot, at: now, seconds: 86400))
        XCTAssertFalse(schedule.begin(.copilot, at: now, seconds: 30, forced: true))
        XCTAssertTrue(schedule.begin(.codex, at: now, seconds: 30))
        schedule.finish(.copilot, at: now, succeeded: true)
        XCTAssertFalse(schedule.begin(.copilot, at: now.addingTimeInterval(600), seconds: 86400))
        XCTAssertTrue(schedule.begin(.copilot, at: now.addingTimeInterval(600), seconds: 300))
        XCTAssertNil(schedule.nextDate(.copilot, seconds: 300))
    }

    func testPauseManualRefreshAndBackoff() {
        var schedule = RefreshSchedule()
        schedule.paused = true
        XCTAssertFalse(schedule.begin(.local, at: now, seconds: 30))
        XCTAssertFalse(schedule.begin(.copilot, at: now, seconds: 30))
        XCTAssertTrue(schedule.begin(.copilot, at: now, seconds: 30, forced: true))
        schedule.finish(.copilot, at: now, succeeded: false)
        schedule.paused = false
        XCTAssertEqual(schedule.nextDate(.copilot, seconds: 30), now.addingTimeInterval(300))
        XCTAssertTrue(schedule.begin(.copilot, at: now.addingTimeInterval(300), seconds: 30))
        schedule.finish(.copilot, at: now.addingTimeInterval(300), succeeded: false)
        XCTAssertEqual(schedule.nextDate(.copilot, seconds: 30), now.addingTimeInterval(900))
        XCTAssertTrue(schedule.begin(.copilot, at: now.addingTimeInterval(301), seconds: 30, forced: true))
        schedule.finish(.copilot, at: now.addingTimeInterval(302), succeeded: true)
        XCTAssertEqual(schedule.nextDate(.copilot, seconds: 30), now.addingTimeInterval(602))
    }
}
