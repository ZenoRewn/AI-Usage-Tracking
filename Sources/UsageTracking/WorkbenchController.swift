// Author: Zeno Ren
import AppKit
import SwiftUI

/// The menu bar owns app lifetime; the workbench owns Dock visibility.
@MainActor final class WorkbenchController: NSObject, NSWindowDelegate {
    private(set) var window: NSWindow?
    private let makeWindow: () -> NSWindow
    private let setPolicy: (NSApplication.ActivationPolicy) -> Void
    private let activate: () -> Void

    init(makeWindow: @escaping () -> NSWindow,
         setPolicy: @escaping (NSApplication.ActivationPolicy) -> Void = { NSApp.setActivationPolicy($0) },
         activate: @escaping () -> Void = { NSApp.activate(ignoringOtherApps: true) }) {
        self.makeWindow = makeWindow
        self.setPolicy = setPolicy
        self.activate = activate
    }

    func start() { setPolicy(.accessory) }

    func show() {
        setPolicy(.regular)
        if window == nil {
            let created = makeWindow()
            created.isReleasedWhenClosed = false
            created.delegate = self
            window = created
        }
        if window?.isMiniaturized == true { window?.deminiaturize(nil) }
        window?.makeKeyAndOrderFront(nil)
        activate()
    }

    func windowWillClose(_ notification: Notification) {
        guard notification.object as? NSWindow === window else { return }
        setPolicy(.accessory)
    }
}

@MainActor final class AppDelegate: NSObject, NSApplicationDelegate {
    let model = AppModel()
    private lazy var workbench = WorkbenchController { [model] in
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1280, height: 850),
                              styleMask: [.titled, .closable, .miniaturizable, .resizable],
                              backing: .buffered, defer: false)
        window.title = "Usage Tracking"
        window.identifier = NSUserInterfaceItemIdentifier("main")
        window.tabbingMode = .disallowed
        window.contentViewController = NSHostingController(rootView:
            ContentView(model: model).frame(minWidth: 1050, minHeight: 700))
        window.center()
        window.setFrameAutosaveName("UsageTrackingMainWindow")
        return window
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        workbench.start()
        model.start()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        // Repeated launches keep the menu-bar mode; only an explicit workbench action opens UI.
        return false
    }

    func showWorkbench(_ page: AppPage? = nil) {
        if let page { model.selectedPage = page }
        workbench.show()
    }
}
