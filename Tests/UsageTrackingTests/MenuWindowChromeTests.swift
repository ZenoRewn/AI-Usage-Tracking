// Author: Zeno Ren
import AppKit
import XCTest
@testable import UsageTracking

final class MenuWindowChromeTests: XCTestCase {
    @MainActor func testBorderlessMenuHasTransparentHostAndClippedRoundedContent() async {
        _ = NSApplication.shared
        let panel = NSPanel(contentRect:NSRect(x:0,y:0,width:464,height:500),styleMask:[.nonactivatingPanel],backing:.buffered,defer:false)
        panel.isOpaque = true; panel.backgroundColor = .windowBackgroundColor
        XCTAssertTrue(MenuWindowChrome.configure(panel))
        XCTAssertFalse(panel.isOpaque)
        XCTAssertEqual(panel.backgroundColor?.alphaComponent,0)
        XCTAssertEqual(panel.contentView?.layer?.cornerRadius,20)
        XCTAssertEqual(panel.contentView?.layer?.masksToBounds,true)
        XCTAssertTrue(panel.hasShadow)
        XCTAssertTrue(MenuWindowChrome.configure(panel), "Repeated view updates must preserve the same chrome")
        let titledPanel = NSPanel(contentRect:NSRect(x:0,y:0,width:464,height:500),styleMask:[.titled,.nonactivatingPanel,.fullSizeContentView],backing:.buffered,defer:false)
        XCTAssertTrue(MenuWindowChrome.configure(titledPanel), "SwiftUI menu panels may include title-related style flags")
        XCTAssertFalse(titledPanel.isOpaque)
        XCTAssertEqual(titledPanel.contentView?.layer?.cornerRadius,20)
    }

    @MainActor func testTitledWorkbenchIsNotRestyledAsAMenu() async {
        _ = NSApplication.shared
        let window = NSWindow(contentRect:NSRect(x:0,y:0,width:1050,height:700),styleMask:[.titled,.closable,.resizable],backing:.buffered,defer:false)
        window.isOpaque = true; window.backgroundColor = .white
        XCTAssertFalse(MenuWindowChrome.configure(window))
        XCTAssertTrue(window.isOpaque)
        XCTAssertEqual(window.backgroundColor,.white)
    }
}
