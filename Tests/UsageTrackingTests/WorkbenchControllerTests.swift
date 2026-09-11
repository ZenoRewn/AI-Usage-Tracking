// Author: Zeno Ren
import AppKit
import XCTest
@testable import UsageTracking

final class WorkbenchControllerTests: XCTestCase {
    @MainActor func testLaunchDoesNotCreateWindowAndOpeningThenClosingChangesDockPresence() async {
        _ = NSApplication.shared
        var policies: [NSApplication.ActivationPolicy] = []
        var created = 0
        let controller = WorkbenchController(makeWindow: {
            created += 1
            return NSWindow(contentRect: NSRect(x: 0, y: 0, width: 200, height: 100), styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
        }, setPolicy: { policies.append($0) }, activate: {})
        controller.start()
        XCTAssertEqual(policies, [.accessory])
        XCTAssertEqual(created, 0, "Background launch must not construct a workbench")
        XCTAssertNil(controller.window)

        controller.show()
        XCTAssertEqual(policies.last, .regular)
        XCTAssertTrue(controller.window?.isVisible == true)
        controller.window?.close()
        XCTAssertEqual(policies.last, .accessory)
        XCTAssertFalse(controller.window?.isVisible == true)

        controller.show()
        XCTAssertEqual(created, 1, "Reopen the existing workbench and keep its state")
        XCTAssertEqual(policies.last, .regular)
        XCTAssertTrue(controller.window?.isVisible == true)
        controller.window?.close()
    }

    @MainActor func testRepeatedOpenUsesOneWindowAndMinimizingKeepsDockAvailable() async {
        _ = NSApplication.shared
        var policies: [NSApplication.ActivationPolicy] = []
        let controller = WorkbenchController(makeWindow: {
            NSWindow(contentRect: NSRect(x: 0, y: 0, width: 200, height: 100), styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
        }, setPolicy: { policies.append($0) }, activate: {})
        controller.start()
        controller.show()
        let original = controller.window
        controller.show()
        XCTAssertTrue(original === controller.window)
        controller.window?.miniaturize(nil)
        XCTAssertEqual(policies.last, .regular, "Minimized workbench should still be reachable from Dock")
        controller.show()
        XCTAssertFalse(controller.window?.isMiniaturized == true)
        controller.window?.close()
        XCTAssertEqual(policies.last, .accessory)
    }
}
