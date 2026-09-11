// Author: Zeno Ren
import SwiftUI
import UsageCore

@main struct UsageTrackingApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    private var model: AppModel { appDelegate.model }
    var body: some Scene {
        MenuBarExtra { MenuPopover(model: model, showWorkbench: { appDelegate.showWorkbench($0) }) } label: {
            Image(systemName:model.paused ? "chart.bar.xaxis" : "chart.bar.fill")
                .accessibilityLabel("Usage Tracking · 订阅与用量")
                .help("Usage Tracking · 订阅额度与 1 / 7 / 30 天用量")
        }.menuBarExtraStyle(.window)
        .commands {
            CommandGroup(replacing: .appInfo) { Button("关于 Usage Tracking") { NSApp.orderFrontStandardAboutPanel(options: [.applicationName:"Usage Tracking",.applicationVersion:UsageCoreVersion.current,.credits:NSAttributedString(string:"Author: Zeno Ren\n本地 AI 编程工具用量监控")]) } }
            CommandGroup(replacing: .newItem) { Button("打开工作台") { appDelegate.showWorkbench() }.keyboardShortcut("0") }
            CommandGroup(after: .newItem) {
                Button("刷新用量与额度") { model.refreshAll() }.keyboardShortcut("r")
                Button("导出 JSON…") { model.export(json: true) }.keyboardShortcut("e", modifiers: [.command,.shift])
            }
        }
    }
}
