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
                Button { model.togglePause() } label: { Image(systemName:model.paused ? "play.fill" : "pause.fill").frame(width:26,height:26) }.accessibilityLabel(model.paused ? "继续采集" : "暂停采集").help(model.paused ? "继续采集" : "暂停采集")
                Button { model.refreshAll() } label: { Image(systemName:"arrow.clockwise").frame(width:26,height:26) }.disabled(model.isScanning && model.quotaLoading).accessibilityLabel("刷新本地用量与账户额度").help("刷新本地用量与账户额度")
            }.buttonStyle(.borderless)
            VStack(alignment:.leading,spacing:8) {
                HStack { Text("订阅额度 · 已用").font(.caption.weight(.semibold)); Spacer(); Button("详情 ›") { show(.quotas) }.font(.caption).buttonStyle(.plain).foregroundStyle(Display.blue) }
                TimelineView(.periodic(from:.now,by:30)) { context in
                    HStack(spacing:6) {
                        ForEach(Tool.allCases) { tool in
                            MenuQuotaCard(summary:MenuQuotaSummary(tool:tool,quotas:model.displayedQuotas,now:context.date),
                                          loading:model.quotaIsLoading(tool), error:model.quotaErrors[tool],
                                          refreshStatus:tool == .claude ? "Claude 额度随 statusLine 更新。" : model.refreshStatus(tool == .copilot ? .copilot : .codex),
                                          refresh:{ model.refreshQuota(tool:tool) },openAccount:{
                                              show(.quotas)
                                              if tool == .claude && model.displayedQuotas.allSatisfy({ $0.tool != .claude }) {
                                                  model.showConnection = "claude"
                                              }
                                          })
                        }
                    }
                    .onChange(of:Calendar.current.startOfDay(for:context.date),initial:true) { _, _ in
                        model.refreshMenuDayIfNeeded(at:context.date)
                    }
                }
            }
            Divider()
            MenuUsageOverview(usage:model.windowUsage,projects:model.todayProjects,projectName:model.projectName,openProject:{ path in
                show(.projects)
                model.selectMenuProject(path,dayStart:model.todayProjects.dayStart)
            })
            Divider()
            HStack {
                Button("打开工作台") { show(.overview) }.buttonStyle(.borderedProminent).tint(Display.purple)
                Spacer()
                Text("Author: Zeno Ren").font(.system(size:11)).foregroundStyle(.secondary)
                Button { NSApp.terminate(nil) } label: { Image(systemName:"power").frame(width:26,height:26) }.buttonStyle(.borderless).accessibilityLabel("退出 Usage Tracking").help("退出 Usage Tracking")
            }
        }.padding(16).frame(width:464)
        .background(Color(nsColor:.windowBackgroundColor))
    }
    private func show(_ page: AppPage) {
        showWorkbench(page)
    }
}
