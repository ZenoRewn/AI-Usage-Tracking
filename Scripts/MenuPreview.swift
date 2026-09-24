// Author: Zeno Ren
// Isolated native UI preview. Uses production views with synthetic data; no scanner or RPC.
import AppKit
import SwiftUI
@testable import UsageCore
@testable import UsageTracking

@MainActor final class PreviewDelegate: NSObject, NSApplicationDelegate {
    let model = AppModel(dataDirectory:FileManager.default.temporaryDirectory.appendingPathComponent("usage-preview-" + UUID().uuidString),collectsUsage:false)
    var preview: NSWindow?
    lazy var workbench = WorkbenchController(makeWindow:{ [self] in
        let window = NSWindow(contentRect:NSRect(x:0,y:0,width:1280,height:850),styleMask:[.titled,.closable,.miniaturizable,.resizable],backing:.buffered,defer:false)
        window.title = "Usage Tracking · 示例工作台"
        window.toolbarStyle = .unifiedCompact
        window.contentViewController = NSHostingController(rootView:ContentView(model:model).frame(minWidth:1050,minHeight:700))
        window.center()
        return window
    })

    func sample(_ scenario: String) {
        let now = Date()
        model.snapshot.quotas = [
            .init(id:"rpc:codex:primary",tool:.codex,title:"5 小时",usedPercent:21,resetsAt:now.addingTimeInterval(8280),capturedAt:now,source:"示例账户 RPC"),
            .init(id:"rpc:codex:secondary",tool:.codex,title:"每周",usedPercent:12,resetsAt:now.addingTimeInterval(259200),capturedAt:now,source:"示例账户 RPC"),
            .init(id:"claude:primary",tool:.claude,title:"5 小时",usedPercent:86,resetsAt:now.addingTimeInterval(3060),capturedAt:now,source:"示例 statusLine 快照"),
            .init(id:"claude:weekly",tool:.claude,title:"每周",usedPercent:7,resetsAt:now.addingTimeInterval(345600),capturedAt:now,source:"示例 statusLine 快照"),
            .init(id:"copilot-rpc:credits",tool:.copilot,title:"AI Credits",usedPercent:52,resetsAt:now.addingTimeInterval(518400),capturedAt:now,source:"示例账户 RPC",amounts:.init(unit:.credits,total:1000,used:520))
        ]
        model.quotaErrors = [:]
        switch scenario {
        case "无额度": model.snapshot.quotas = []
        case "未就绪":
            model.snapshot.quotas.removeAll { $0.tool != .copilot }
            model.snapshot.quotas[0].capturedAt = now.addingTimeInterval(-1320)
            model.snapshot.quotas[0].resetsAt = now.addingTimeInterval(-60)
            model.quotaErrors[.codex] = "示例：暂时未能查询额度。"
        case "旧快照":
            for i in model.snapshot.quotas.indices { model.snapshot.quotas[i].capturedAt = now.addingTimeInterval(-1320) }
        case "异常":
            model.snapshot.quotas[0].resetsAt = now.addingTimeInterval(-1)
            model.snapshot.quotas[1].capturedAt = now.addingTimeInterval(-1320)
            model.snapshot.quotas[2].resetsAt = nil
            model.snapshot.quotas[2].usedPercent = 105
            model.snapshot.quotas[2].title = "这是一个很长的额度窗口名称，用于验证换行与详情完整性"
            model.quotaErrors[.copilot] = "示例：连接暂时不可用。"
        default: break
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        let now = Date()
        let start = Calendar.current.startOfDay(for:now)
        model.config.sources = []
        model.config.prices.rates = [.init(model:"demo-priced",tool:.codex,input:1.5,cacheRead:0.5,cacheWrite:1.5,output:5,effectiveFrom:"2020-01-01")]
        model.snapshot.events = [
            .init(id:"demo-a",tool:.codex,surface:"示例客户端",session:"demo-a",project:"/demo/Atlas",model:"demo-priced",timestamp:TimeCodec.string(start.addingTimeInterval(1)),tokens:.init(input:2_800_000),precision:.response),
            .init(id:"demo-b",tool:.claude,surface:"示例客户端",session:"demo-b",project:"/demo/Studio",model:"unknown",timestamp:TimeCodec.string(start.addingTimeInterval(2)),tokens:.init(input:1_500_000),precision:.response),
            .init(id:"demo-c",tool:.codex,surface:"示例客户端",session:"demo-c",project:"/demo/Notes",model:"demo-priced",timestamp:TimeCodec.string(start.addingTimeInterval(3)),tokens:.init(input:750_000),precision:.response)
        ]
        model.windowUsage = UsageWindows.summarize(model.snapshot.events,catalog:model.config.prices,now:now)
        model.todayProjects = TodayProjects.summarize(model.snapshot.events,catalog:model.config.prices,now:now)
        sample("正常")
        let window = NSWindow(contentRect:NSRect(x:0,y:0,width:464,height:680),styleMask:[.titled,.closable],backing:.buffered,defer:false)
        window.title = "Usage Tracking \(UsageCoreVersion.current) · 示例验收"
        window.isReleasedWhenClosed = false
        window.contentViewController = NSHostingController(rootView:PreviewView(owner:self))
        window.setContentSize(window.contentView!.fittingSize)
        print("Sample menu window content: \(window.contentView!.fittingSize)")
        window.center(); window.makeKeyAndOrderFront(nil)
        preview = window
        NSApp.activate(ignoringOtherApps:true)
    }
}

struct PreviewView: View {
    let owner: PreviewDelegate
    @State private var scenario = "正常"
    @State private var dark = true
    var body: some View {
        VStack(spacing:0) {
            HStack {
                Text("虚构数据").font(.caption)
                Picker("状态",selection:$scenario) { ForEach(["正常","无额度","未就绪","旧快照","异常"],id:\.self) { Text($0) } }.frame(width:170)
                    .onChange(of:scenario) { owner.sample(scenario) }
                Toggle("深色",isOn:$dark)
            }.padding(12)
            Divider()
            MenuPopover(model:owner.model,showWorkbench:{ page in owner.model.selectedPage = page; owner.workbench.show() })
        }.preferredColorScheme(dark ? .dark : .light)
    }
}

@main enum PreviewMain {
    @MainActor static func main() {
        let application = NSApplication.shared
        let delegate = PreviewDelegate()
        application.delegate = delegate
        application.run()
    }
}
