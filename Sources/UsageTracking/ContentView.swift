// Author: Zeno Ren
import SwiftUI
import Charts
import UsageCore

struct ContentView: View {
    @Bindable var model: AppModel
    var body: some View {
        NavigationSplitView {
            VStack(alignment:.leading,spacing:14) {
                HStack(spacing:10) {
                    Image(systemName:"chart.bar.xaxis").font(.system(size:23,weight:.semibold)).foregroundStyle(.white).frame(width:43,height:43).background(Display.accent.gradient,in:RoundedRectangle(cornerRadius:12))
                    VStack(alignment:.leading,spacing:2) { Text("Usage").font(.system(size:21,weight:.bold)); Text("Tracking").font(.system(size:15,weight:.medium)).foregroundStyle(.secondary) }
                }.padding(.top,20).padding(.horizontal,20)
                Text("本机用量工作台").font(.caption).foregroundStyle(.secondary).padding(.horizontal,22)
                List(selection:$model.selectedPage) {
                    Section("概览") {
                        sidebarLink(.overview)
                        sidebarLink(.quotas)
                    }
                    Section("用量分析") {
                        sidebarLink(.projects)
                        sidebarLink(.sessions)
                        sidebarLink(.clients)
                        sidebarLink(.costs)
                    }
                    Section("管理") {
                        sidebarLink(.sources)
                        sidebarLink(.prices)
                        sidebarLink(.settings)
                    }
                }.listStyle(.sidebar)
                VStack(alignment:.leading,spacing:8) {
                    Label(model.paused ? "采集已暂停" : "数据保存在本机",systemImage:model.paused ? "pause.circle" : "lock.shield").font(.caption).foregroundStyle(Display.accent)
                    Text("Author: Zeno Ren").font(.system(size:11)).foregroundStyle(.secondary)
                    Text("v\(UsageCoreVersion.current) · 本地预览版").font(.system(size:10)).foregroundStyle(.tertiary)
                }.padding(20)
            }.navigationSplitViewColumnWidth(min:190,ideal:215,max:250)
        } detail: {
            VStack(spacing:0) {
                header.padding(.top,toolbarClearance)
                if let message = model.statusMessage { HStack { Image(systemName:"checkmark.circle").foregroundStyle(Display.accent); Text(message); Spacer() }.font(.caption).foregroundStyle(.secondary).padding(.horizontal,28).padding(.bottom,12) }
                if model.isScanning { HStack { ProgressView().controlSize(.small); Text(model.scanProgress).font(.caption); Spacer() }.padding(.horizontal,28).padding(.bottom,12) }
                Divider()
                ScrollView {
                    VStack(alignment:.leading,spacing:22) {
                        switch model.selectedPage {
                        case .overview: OverviewView(model:model)
                        case .projects: ProjectListView(model:model)
                        case .sessions: SessionListView(model:model)
                        case .clients: ClientModelsView(model:model)
                        case .quotas: QuotasView(model:model)
                        case .costs: CostsView(model:model)
                        case .sources: SourcesView(model:model)
                        case .prices: ModelPricesView(model:model)
                        case .settings: SettingsContentView(model:model)
                        }
                    }.padding(28).frame(maxWidth:.infinity,alignment:.topLeading)
                }.id(model.selectedPage)
            }.background(Color(nsColor:.windowBackgroundColor))
        }
        .tint(Display.accent)
        .sheet(item:$model.selectedGroup) { group in GroupDetailView(group:group,model:model) }
        .sheet(isPresented:Binding(get:{ model.showConnection != nil },set:{ if !$0 { model.showConnection = nil } })) {
            if let kind = model.showConnection { ConnectionView(kind:kind,model:model) }
        }
        .alert("Usage Tracking",isPresented:Binding(get:{ model.error != nil },set:{ if !$0 { model.error = nil } })) { Button("知道了") { model.error = nil } } message: { Text(model.error ?? "") }
    }
    private func sidebarLink(_ page: AppPage) -> some View {
        Label(page.rawValue,systemImage:page.symbol).font(.system(size:13)).padding(.vertical,4).tag(page)
    }
    // AppKit-hosted split views on macOS 26 extend beneath the compact window toolbar.
    private var toolbarClearance: CGFloat {
        if #available(macOS 26.0, *) { return 24 }
        return 0
    }
    private var header: some View {
        VStack(alignment:.leading,spacing:17) {
            HStack(alignment:.top) {
                VStack(alignment:.leading,spacing:6) { Text(model.selectedPage.rawValue).font(.system(size:25,weight:.bold)); Text(model.selectedPage.subtitle).font(.subheadline).foregroundStyle(.secondary) }
                Spacer()
                if model.selectedPage.isUsageAnalysis {
                    Menu { Button("导出 CSV") { model.export(json:false) }; Button("导出 JSON") { model.export(json:true) } } label: { Label("导出",systemImage:"square.and.arrow.up") }
                }
                Button { model.refreshAll() } label: { Image(systemName:"arrow.clockwise").frame(width:20) }.disabled(model.isScanning && model.quotaLoading).help("刷新本地用量与账户额度 ⌘R")
            }
            if model.selectedPage.isUsageAnalysis {
                HStack(spacing:12) {
                    Picker("时间范围",selection:$model.rangeDays) { Text("今天").tag(1); Text("7 天").tag(7); Text("30 天").tag(30); Text("全部").tag(0) }.pickerStyle(.segmented).frame(width:265)
                    Picker("工具",selection:$model.selectedTool) { Text("全部工具").tag("all"); ForEach(Tool.allCases) { Text($0.title).tag($0.rawValue) } }.labelsHidden().frame(width:165).onChange(of:model.selectedTool) { model.selectedClient = "all" }
                    Spacer()
                    HStack { Image(systemName:"magnifyingglass").foregroundStyle(.secondary); TextField("搜索项目、模型、入口",text:$model.search).textFieldStyle(.plain) }.padding(7).background(.background,in:RoundedRectangle(cornerRadius:7)).frame(maxWidth:240)
                }
            }
        }.padding(28).padding(.bottom,-8)
    }
}

struct SurfaceCard<Content: View>: View {
    var title: String
    var subtitle: String = ""
    var tool: Tool? = nil
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment:.leading,spacing:16) {
            if !title.isEmpty { HStack(spacing:8) { if let tool { BrandLogo(tool:tool,size:20) }; Text(title).font(.headline); Spacer(); if !subtitle.isEmpty { Text(subtitle).font(.caption).foregroundStyle(.secondary) } } }
            content
        }.padding(20).frame(maxWidth:.infinity,alignment:.leading).background(Color(nsColor:.controlBackgroundColor),in:RoundedRectangle(cornerRadius:13)).overlay(RoundedRectangle(cornerRadius:13).strokeBorder(.primary.opacity(0.055)))
    }
}
struct MetricCard: View {
    var title: String; var value: String; var note: String; var symbol: String
    var body: some View {
        SurfaceCard(title:"") {
            HStack { Text(title).font(.caption).foregroundStyle(.secondary); Spacer(); Image(systemName:symbol).foregroundStyle(Display.accent) }
            Text(value).font(.system(size:30,weight:.semibold,design:.rounded)).minimumScaleFactor(0.6).lineLimit(1)
            Text(note).font(.system(size:11)).foregroundStyle(.secondary).lineLimit(2)
        }
    }
}
struct Notice: View {
    var text: String
    var body: some View { Label(text,systemImage:"info.circle").font(.caption).foregroundStyle(.secondary).padding(13).frame(maxWidth:.infinity,alignment:.leading).background(Display.accent.opacity(0.055),in:RoundedRectangle(cornerRadius:9)) }
}

struct OverviewView: View {
    @Bindable var model: AppModel
    var body: some View {
        let events = model.filtered
        let total = events.reduce(0) { $0 + $1.tokens.total }
        let projects = model.projects
        HStack(spacing:14) {
            MetricCard(title:"已观测 Token",value:events.isEmpty ? "—" : Display.tokens(total),note:events.isEmpty ? "所选范围未观察到记录" : "输入含缓存 · 输出含推理子集",symbol:"chart.bar")
            MetricCard(title:"项目",value:String(projects.filter { !$0.id.isEmpty }.count),note:"跨工具归属 · worktree 自动合并",symbol:"folder")
            MetricCard(title:"会话",value:String(model.sessions.count),note:"所选范围内有用量的会话",symbol:"bubble.left.and.bubble.right")
            let priced = model.costCoverage
            MetricCard(title:priced.1 > 0 && priced.1 < total ? "参考成本 · 部分定价" : "参考成本",value:events.isEmpty ? "—" : priced.1 == 0 ? "待定价" : "≈" + priced.0.formatted(.currency(code:"USD")),note:total == 0 ? "按已配置价格计算" : "已定价覆盖 \(Int(Double(priced.1)/Double(max(1,total))*100))% · 非账单",symbol:"dollarsign.circle")
        }
        HStack(alignment:.top,spacing:14) {
            SurfaceCard(title:"用量趋势",subtitle:"按本地时区归账") {
                if events.isEmpty { empty } else {
                    Chart(model.daily) { day in BarMark(x:.value("日期",day.date,unit:.day),y:.value("Tokens",day.tokens)).foregroundStyle(by:.value("工具",day.tool.title)) }
                    .chartForegroundStyleScale(domain:Tool.allCases.map(\.title),range:Tool.allCases.map(Display.color))
                    .chartYAxis { AxisMarks(position:.leading) { value in AxisGridLine(); AxisValueLabel { if let count = value.as(Int64.self) { Text(Display.tokens(count)) } } } }
                    .chartLegend(.hidden).frame(height:208)
                    HStack(spacing:16) { ForEach(Tool.allCases) { tool in BrandLabel(tool:tool,size:13).font(.caption).foregroundStyle(.secondary) } }
                }
            }.frame(maxWidth:.infinity)
            SurfaceCard(title:"工具分布") {
                ForEach(Tool.allCases) { tool in
                    let rows = events.filter { $0.tool == tool }; let count = rows.reduce(Int64(0)) { $0 + $1.tokens.total }
                    VStack(alignment:.leading,spacing:9) {
                        HStack { BrandLogo(tool:tool,size:17); Text(tool.title).font(.subheadline); Spacer(); Text(rows.isEmpty ? "—" : Display.tokens(count)).font(.system(.subheadline,design:.rounded).weight(.semibold)) }
                        GeometryReader { geometry in Capsule().fill(Display.color(tool).opacity(0.10)).overlay(alignment:.leading) { Capsule().fill(Display.color(tool)).frame(width:geometry.size.width * (total == 0 ? 0 : Double(count)/Double(total))) } }.frame(height:5)
                        Text(rows.isEmpty ? "所选范围暂无用量" : "\(Set(rows.map(\.session)).count) 个会话 · \(rows.count.formatted()) 条记录").font(.system(size:10)).foregroundStyle(.secondary)
                    }.padding(.bottom,8)
                }
            }.frame(width:280)
        }
        SurfaceCard(title:"投入最多的项目",subtitle:"点击查看会话与记录") {
            if projects.isEmpty { empty }
            ForEach(projects.prefix(6)) { group in
                Button { model.selectedGroup = group } label: {
                    HStack(spacing:14) {
                        ProjectBrands(tools:group.tools)
                        VStack(alignment:.leading,spacing:3) { Text(group.name).font(.subheadline.weight(.medium)); Text(group.tools.map(\.title).joined(separator:" · ")).font(.caption).foregroundStyle(.secondary) }
                        Spacer()
                        VStack(alignment:.trailing,spacing:3) { Text(Display.tokens(group.total)).font(.system(.body,design:.rounded).weight(.semibold)); Text(model.costLabel(group.events)).font(.caption).foregroundStyle(.secondary) }
                        Image(systemName:"chevron.right").font(.caption).foregroundStyle(.tertiary)
                    }.contentShape(Rectangle())
                }.buttonStyle(.plain)
                if group.id != projects.prefix(6).last?.id { Divider() }
            }
        }
        Notice(text:"统计范围为已采集的本地记录。Copilot 会话汇总的日期为近似归属；未连接入口和缺失历史不计入总量。")
    }
    private var empty: some View { ContentUnavailableView("还没有所选范围的用量",systemImage:"chart.bar",description:Text("尝试“全部”时间范围，或在数据源页面连接工具。")) }
}

struct ProjectListView: View {
    @Bindable var model: AppModel
    var body: some View {
        Notice(text:"项目依据真实工作目录和 Git common-dir 归属；同名不同路径不会合并。无法确定的记录保留在“未归属项目”。")
        SurfaceCard(title:"\(model.projects.count) 个项目") {
            ForEach(model.projects) { group in
                Button { model.selectedGroup = group } label: {
                    HStack {
                        ProjectBrands(tools:group.tools)
                        VStack(alignment:.leading,spacing:4) { Text(group.name).font(.headline); Text(group.id.isEmpty ? "未提供工作目录" : group.id.replacingOccurrences(of:FileManager.default.homeDirectoryForCurrentUser.path,with:"~")).font(.caption).foregroundStyle(.secondary).lineLimit(1) }
                        Spacer(); Text(group.tools.map(\.title).joined(separator:" / ")).font(.caption).foregroundStyle(.secondary).frame(width:200)
                        VStack(alignment:.trailing,spacing:4) { Text(Display.tokens(group.total)).font(.system(.title3,design:.rounded).weight(.semibold)); Text(model.costLabel(group.events)).font(.caption).foregroundStyle(.secondary) }.frame(width:120,alignment:.trailing)
                        Image(systemName:"chevron.right").foregroundStyle(.tertiary)
                    }.padding(.vertical,6).contentShape(Rectangle())
                }.buttonStyle(.plain)
                Divider()
            }
        }
    }
}

struct SessionListView: View {
    @Bindable var model: AppModel
    var body: some View {
        SurfaceCard(title:"最近会话",subtitle:"\(model.sessions.count) 个 · 按最近用量排序") {
            ForEach(model.sessions.prefix(150)) { group in
                Button { model.selectedGroup = group } label: {
                    HStack(alignment:.center,spacing:16) {
                        BrandLogo(tool:group.events[0].tool,size:23)
                        VStack(alignment:.leading,spacing:4) {
                            Text(model.projectName(group.events[0].project)).font(.subheadline.weight(.semibold))
                            Text("\(group.events[0].surface) · \(group.events[0].model) · \(group.name)").font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        VStack(alignment:.trailing,spacing:4) { Text(Display.tokens(group.total)).font(.system(.body,design:.rounded).weight(.semibold)); Text(group.last,format:.dateTime.month().day().hour().minute()).font(.caption).foregroundStyle(.secondary) }
                    }.padding(.vertical,6).contentShape(Rectangle())
                }.buttonStyle(.plain); Divider()
            }
        }
        if model.sessions.count > 150 { Notice(text:"当前展示最近 150 个会话。缩小时间范围或搜索项目，可定位更早记录。导出包含全部筛选结果。") }
    }
}

struct QuotasView: View {
    @Bindable var model: AppModel
    var body: some View {
        HStack { Notice(text:"配额来自账户接口或工具快照。过期数据不会自动归零；账户额度也不会与项目 Token 相加。")
            Menu(model.quotaLoading ? "查询中…" : "刷新账户额度") {
                Button("Codex") { model.refreshQuota() }.disabled(model.quotaIsLoading(.codex))
                Button("GitHub Copilot") { model.refreshQuota(tool:.copilot) }.disabled(model.quotaIsLoading(.copilot))
            }
        }
        HStack {
            Label(RefreshPolicy.label(model.config.refreshSeconds),systemImage:"arrow.triangle.2.circlepath")
            Spacer(); Button("调整刷新间隔") { model.selectedPage = .settings }.buttonStyle(.plain).foregroundStyle(Display.accent)
        }.font(.caption).foregroundStyle(.secondary)
        ForEach(Tool.allCases) { tool in
            SurfaceCard(title:tool.title,subtitle:tool == .copilot ? "按账户实际计费模式显示" : "独立窗口",tool:tool) {
                let quotas = model.displayedQuotas.filter { $0.tool == tool }
                if quotas.isEmpty {
                    HStack {
                        VStack(alignment:.leading,spacing:6) { Text("尚未获取账户额度").font(.subheadline); Text(tool == .copilot ? "可通过“刷新账户额度”查询 Copilot，也可打开官方页面核对。本地 Token 不等于 Credits 余额。" : tool == .claude ? "连接 statusLine 后，Claude 的正常活动会更新配额快照。" : "可通过 Codex 当前登录状态查询，不复制凭据。").font(.caption).foregroundStyle(.secondary) }
                        Spacer()
                        Button(tool == .claude ? "连接说明" : "打开用量页") {
                            if tool == .claude { model.showConnection = "claude" } else { NSWorkspace.shared.open(URL(string: tool == .copilot ? "https://github.com/settings/billing/usage" : "https://chatgpt.com/codex/settings/usage")!) }
                        }
                    }
                }
                ForEach(quotas) { q in
                    VStack(alignment:.leading,spacing:10) {
                        HStack { Text(q.title).font(.subheadline.weight(.semibold)); if q.isStale() { Text("过期快照").font(.caption).foregroundStyle(.orange) }; Spacer(); Text(q.usedPercent.formatted(.number.precision(.fractionLength(1))) + "% 已用").font(.system(.title3,design:.rounded).weight(.semibold)) }
                        ProgressView(value:min(100,max(0,q.usedPercent)),total:100).tint(q.isStale() ? .gray : Display.color(tool))
                        if let amounts = q.amounts {
                            HStack(spacing:32) {
                                amount("总额度",amounts.total,unit:amounts.unit.rawValue)
                                amount("已使用",amounts.used,unit:amounts.unit.rawValue)
                                amount("剩余",amounts.remaining,unit:amounts.unit.rawValue)
                                Spacer(minLength:0)
                            }.padding(.vertical,4)
                        }
                        HStack { Text(q.source); Spacer(); if q.hasUnconfirmedReset { Text("下次重置时间待确认") } else if let reset = q.resetsAt { Text(reset < Date() ? "等待新窗口数据" : "重置：" + reset.formatted(.dateTime.month().day().hour().minute())) } }.font(.caption).foregroundStyle(.secondary)
                        Text("采集于 " + q.capturedAt.formatted(.dateTime.month().day().hour().minute())).font(.system(size:11)).foregroundStyle(.tertiary)
                    }.padding(.vertical,7)
                }
                if tool != .claude {
                    if let error = model.quotaErrors[tool] {
                        Label(error,systemImage:"exclamationmark.circle").font(.caption).foregroundStyle(.orange)
                    }
                    HStack {
                        Text(model.refreshStatus(tool == .copilot ? .copilot : .codex)).font(.caption).foregroundStyle(.secondary)
                        Spacer()
                        Button(model.quotaIsLoading(tool) ? "查询中…" : "立即刷新") { model.refreshQuota(tool:tool) }.disabled(model.quotaIsLoading(tool))
                    }
                } else {
                    Text("随 Claude statusLine 更新；本地快照按设置间隔读取。").font(.caption).foregroundStyle(.secondary)
                }
            }
        }
    }
    private func amount(_ title: String, _ value: Double?, unit: String) -> some View {
        VStack(alignment:.leading,spacing:5) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value.map { $0.formatted(.number.precision(.fractionLength(0...2))) } ?? "—")
                .font(.system(size:20,weight:.semibold,design:.rounded)).monospacedDigit()
            Text(unit).font(.caption2).foregroundStyle(.secondary)
        }.frame(minWidth:130,alignment:.leading)
    }
}

struct GroupDetailView: View {
    let group: UsageGroup
    @Bindable var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var alias = ""
    var body: some View {
        VStack(alignment:.leading,spacing:18) {
            HStack { VStack(alignment:.leading) { Text(group.name).font(.title2.bold()); Text("\(group.events.count.formatted()) 条记录 · \(Display.tokens(group.total)) Tokens · \(model.costLabel(group.events)) 参考成本").foregroundStyle(.secondary) }; Spacer(); Button("完成") { dismiss() }.keyboardShortcut(.cancelAction) }
            HStack(spacing:12) { MetricCard(title:"输入（含缓存）",value:Display.tokens(group.input),note:"缓存是输入的拆分",symbol:"arrow.down"); MetricCard(title:"输出",value:Display.tokens(group.output),note:"推理 Token 属于输出子集",symbol:"arrow.up"); MetricCard(title:"缓存读取",value:Display.tokens(group.cache),note:"不再重复加入总量",symbol:"arrow.triangle.2.circlepath") }
            if group.id.hasPrefix("/") {
                HStack { TextField("项目显示名称",text:$alias); Button("保存名称") { model.config.projectNames[group.id] = alias.isEmpty ? nil : alias; model.save() } }
            }
            ScrollView {
                LazyVStack(alignment:.leading,spacing:14) {
                    ForEach(group.events.prefix(300)) { event in
                        HStack(alignment:.top) {
                            VStack(alignment:.leading,spacing:5) { Text(event.model).font(.subheadline.weight(.semibold)); Text("\(event.surface) · \(event.precision.title)").font(.caption).foregroundStyle(.secondary); Text(event.timestamp).font(.system(size:11,design:.monospaced)).foregroundStyle(.tertiary) }
                            Spacer(); VStack(alignment:.trailing,spacing:5) {
                                Text(Display.tokens(event.tokens.total)).font(.system(.body,design:.rounded).weight(.semibold))
                                Text("in \(Display.tokens(event.tokens.input)) / out \(Display.tokens(event.tokens.output))").font(.caption).foregroundStyle(.secondary)
                                if let quote = model.config.prices.quote(event) { Text("≈" + quote.amount.formatted(.currency(code:"USD"))).font(.caption).foregroundStyle(Display.accent).help(quote.basis) }
                            }
                        }; Divider()
                    }
                }
            }
            Text("展示最近 300 条；导出可包含全部。Author: Zeno Ren").font(.caption).foregroundStyle(.secondary)
        }.padding(26).frame(width:850,height:650).onAppear { alias = model.config.projectNames[group.id] ?? "" }
    }
}
