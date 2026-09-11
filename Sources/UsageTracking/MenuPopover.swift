// Author: Zeno Ren
import SwiftUI
import UsageCore

struct MenuPopover: View {
    @Bindable var model: AppModel
    var showWorkbench: (AppPage) -> Void
    var body: some View {
        VStack(alignment:.leading,spacing:13) {
            HStack(spacing:8) {
                Image(systemName:"chart.bar.fill").foregroundStyle(Display.purple)
                Text("Usage Tracking").font(.headline)
                Circle().fill(model.paused ? Color.orange : Display.blue).frame(width:6,height:6)
                Spacer()
                Button { model.togglePause() } label: { Image(systemName:model.paused ? "play.fill" : "pause.fill") }.help(model.paused ? "继续采集" : "暂停采集")
                Button { model.refreshAll() } label: { Image(systemName:"arrow.clockwise") }.disabled(model.isScanning && model.quotaLoading).help("刷新本地用量与账户额度")
            }.buttonStyle(.borderless)
            VStack(alignment:.leading,spacing:8) {
                HStack { Text("订阅额度 · 已用").font(.caption.weight(.semibold)); Spacer(); Button("详情 ›") { show(.quotas) }.font(.caption).buttonStyle(.plain).foregroundStyle(Display.blue) }
                TimelineView(.periodic(from:.now,by:30)) { context in
                    HStack(spacing:6) {
                        ForEach(Tool.allCases) { tool in
                            MenuQuotaCard(summary:MenuQuotaSummary(tool:tool,quotas:model.displayedQuotas,now:context.date),
                                          loading:model.quotaIsLoading(tool), error:model.quotaErrors[tool],
                                          refreshStatus:tool == .claude ? "Claude 额度随 statusLine 更新。" : model.refreshStatus(tool == .copilot ? .copilot : .codex),
                                          refresh:{ model.refreshQuota(tool:tool) })
                        }
                    }
                    .onChange(of:Calendar.current.startOfDay(for:context.date),initial:true) { _, _ in
                        model.refreshMenuDayIfNeeded(at:context.date)
                    }
                }
            }
            Divider()
            MenuUsageOverview(usage:model.windowUsage,projects:model.todayProjects,projectName:model.projectName)
            Divider()
            HStack {
                Button("打开工作台") { show(.overview) }.buttonStyle(.borderedProminent).tint(Display.purple)
                Spacer()
                Text("Author: Zeno Ren").font(.system(size:9)).foregroundStyle(.secondary)
                Button { NSApp.terminate(nil) } label: { Image(systemName:"power") }.buttonStyle(.borderless).help("退出 Usage Tracking")
            }
        }.padding(16).frame(width:440)
        .background(Display.sky.opacity(0.035))
    }
    private func show(_ page: AppPage) {
        showWorkbench(page)
    }
}
