// Author: Zeno Ren
import AppKit
import SwiftUI

/// The glass view alone does not clear or round the MenuBarExtra's backing window.
struct MenuWindowChrome: NSViewRepresentable {
    @discardableResult @MainActor static func configure(_ window: NSWindow) -> Bool {
        // Menu content can be hosted in an NSPanel with title-related style flags.
        // Ordinary titled QA/workbench windows must retain their native chrome.
        guard window is NSPanel || !window.styleMask.contains(.titled) else { return false }
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.identifier = NSUserInterfaceItemIdentifier("usage-menu")
        window.title = "Usage Tracking · 额度与用量"
        if let content = window.contentView {
            content.wantsLayer = true
            content.layer?.isOpaque = false
            content.layer?.backgroundColor = NSColor.clear.cgColor
            content.layer?.cornerRadius = 20
            content.layer?.cornerCurve = .continuous
            content.layer?.masksToBounds = true
        }
        window.invalidateShadow()
        return true
    }

    func makeNSView(context: Context) -> Probe { Probe() }
    func updateNSView(_ view: Probe, context: Context) { view.applyChrome() }

    final class Probe: NSView {
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            applyChrome()
            // SwiftUI finishes configuring its host after attachment.
            DispatchQueue.main.async { [weak self] in self?.applyChrome() }
        }
        func applyChrome() {
            if let window { MenuWindowChrome.configure(window) }
        }
    }
}
