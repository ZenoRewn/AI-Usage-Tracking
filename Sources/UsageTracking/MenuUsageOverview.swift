// Author: Zeno Ren
import SwiftUI
import UsageCore

/// A shared compact surface for time-window totals and today's project ranking.
struct MenuUsageOverview: View {
    let usage: [ToolWindowUsage]
    let projects: TodayProjectSummary
    let projectName: (String) -> String
    let openProject: (String) -> Void
    @State private var metric = MenuUsageMetric.tokens
    @State private var selectedPeriod: String?
    var body: some View {
        VStack(alignment:.leading,spacing:10) {
            HStack {
                Text("本机用量").font(.caption.weight(.semibold))
                Spacer()
                HStack(spacing:2) {
                    metricButton(.tokens)
                    metricButton(.cost)
                }.padding(2).background(MenuPalette.track.opacity(0.55),in:RoundedRectangle(cornerRadius:8))
                    .accessibilityElement(children:.contain).accessibilityLabel("用量单位")
            }
            toolUsage
            if metric == .cost {
                Text("≈ 公价估算 · * 部分定价 · 非订阅账单").font(.system(size:11)).foregroundStyle(MenuPalette.muted)
            }
            Divider().overlay(MenuPalette.line)
            MenuTopProjects(summary:projects,projectName:projectName,metric:metric,openProject:openProject)
        }.padding(.vertical,5)
    }
    private func metricButton(_ value: MenuUsageMetric) -> some View {
        Button { metric = value } label: {
            Text(value.title).font(.system(size:11,weight:.medium)).padding(.horizontal,10).padding(.vertical,4)
                .foregroundStyle(metric == value ? MenuPalette.text : MenuPalette.muted)
                .background(metric == value ? MenuPalette.card.opacity(0.75) : .clear,in:RoundedRectangle(cornerRadius:6))
                .contentShape(Rectangle())
        }.buttonStyle(.plain).accessibilityValue(metric == value ? "已选" : "未选")
    }
    private var toolUsage: some View {
        Grid(alignment:.leading,horizontalSpacing:10,verticalSpacing:7) {
            GridRow {
                Text("工具").frame(maxWidth:.infinity,alignment:.leading)
                ForEach([1,7,30],id:\.self) { day in
                    Text(day == 1 ? "今天" : "\(day) 天").frame(width:74,alignment:.trailing)
                }
            }.font(.system(size:11)).foregroundStyle(MenuPalette.muted)
            ForEach(usage) { row in
                GridRow {
                    HStack(spacing:5) {
                        BrandLogo(tool:row.tool,size:12,tint:MenuPalette.muted)
                        Text(Display.shortName(row.tool)).font(.system(size:11,weight:.medium))
                    }.frame(maxWidth:.infinity,alignment:.leading)
                    ForEach(row.periods) { period in
                        let key = row.tool.rawValue + ":" + String(period.days)
                        Button { selectedPeriod = key } label: {
                            Text(MenuUsageAmount(period).text(for:metric))
                                .font(.system(size:12,weight:.medium,design:.rounded)).monospacedDigit()
                                .lineLimit(1).minimumScaleFactor(0.85).frame(width:74,height:24,alignment:.trailing)
                                .contentShape(Rectangle())
                        }.buttonStyle(.plain)
                        .accessibilityLabel("\(row.tool.title) \(period.days) 天，\(metric.title) \(MenuUsageAmount(period).text(for:metric))")
                        .help("点击查看用量明细")
                        .popover(isPresented:Binding(get:{ selectedPeriod == key },set:{ if !$0 { selectedPeriod = nil } })) {
                            VStack(alignment:.leading,spacing:14) {
                                HStack { Text("本机用量明细").font(.headline); Spacer(); Button("完成") { selectedPeriod = nil }.keyboardShortcut(.cancelAction) }
                                Text(details(period,tool:row.tool)).font(.callout).textSelection(.enabled).fixedSize(horizontal:false,vertical:true)
                                Text("Author: Zeno Ren").font(.system(size:11)).foregroundStyle(.secondary)
                            }.padding(18).frame(width:330)
                        }
                    }
                }.frame(height:24)
            }
        }
    }
    private func details(_ period: PeriodUsage, tool: Tool) -> String {
        let title = tool.title + " · " + (period.days == 1 ? "今天" : "\(period.days) 天")
        guard period.eventCount > 0 else { return title + "\n所选时段未观察到记录，不代表账户未使用。" }
        let cost = MenuUsageAmount(period).text(for:.cost)
        return "\(title)\n\(period.tokens.formatted()) Tokens · \(period.eventCount) 条记录\n参考成本：\(cost)\n价格覆盖 \(Int(period.costCoverage*100))% · 公价 \(CopilotPublicPricing.asOf)\n7 / 30 天包含今天，按本地时区；金额不等于订阅账单。"
    }
}
