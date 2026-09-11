// Author: Zeno Ren
import SwiftUI
import UsageCore

/// A shared compact surface for time-window totals and today's project ranking.
struct MenuUsageOverview: View {
    let usage: [ToolWindowUsage]
    let projects: TodayProjectSummary
    let projectName: (String) -> String
    @State private var metric = MenuUsageMetric.tokens
    var body: some View {
        VStack(alignment:.leading,spacing:10) {
            HStack {
                Text("用量概览").font(.caption.weight(.semibold))
                Spacer()
                Button { metric.toggle() } label: {
                    HStack(spacing:4) { Text(metric.title); Image(systemName:"arrow.left.arrow.right").font(.system(size:8)) }
                }.font(.system(size:10,weight:.medium)).buttonStyle(.plain).foregroundStyle(Display.blue)
                    .accessibilityLabel("切换用量单位，当前为 " + metric.title).help(metric.toggleHint)
                Image(systemName:"info.circle").font(.system(size:10)).foregroundStyle(.tertiary)
                    .help("点击任意数字可切换整块概览的 Token / 参考成本。≈ 为估算；* 为部分用量未定价。悬停查看完整用量与各工具明细。Top 3 始终按 Token 排名。")
            }
            toolUsage
            Divider().opacity(0.6)
            MenuTopProjects(summary:projects,projectName:projectName,metric:metric,toggleMetric:{ metric.toggle() })
        }.padding(10)
        .background(.primary.opacity(0.025),in:RoundedRectangle(cornerRadius:10))
        .overlay(RoundedRectangle(cornerRadius:10).strokeBorder(.primary.opacity(0.055)))
    }
    private var toolUsage: some View {
        Grid(alignment:.leading,horizontalSpacing:10,verticalSpacing:7) {
            GridRow {
                Text("工具").frame(maxWidth:.infinity,alignment:.leading)
                ForEach([1,7,30],id:\.self) { day in
                    Text(day == 1 ? "今天" : "\(day) 天").frame(width:74,alignment:.trailing)
                }
            }.font(.system(size:10)).foregroundStyle(.secondary)
            ForEach(usage) { row in
                GridRow {
                    HStack(spacing:5) {
                        BrandLogo(tool:row.tool,size:12)
                        Text(Display.shortName(row.tool)).font(.system(size:11,weight:.medium))
                    }.frame(maxWidth:.infinity,alignment:.leading)
                    ForEach(row.periods) { period in
                        Button { metric.toggle() } label: {
                            Text(MenuUsageAmount(period).text(for:metric))
                                .font(.system(size:12,weight:.medium,design:.rounded)).monospacedDigit()
                                .lineLimit(1).minimumScaleFactor(0.85).frame(width:74,height:18,alignment:.trailing)
                                .contentShape(Rectangle())
                        }.buttonStyle(.plain)
                        .accessibilityLabel("\(row.tool.title) \(period.days) 天，\(metric.title) \(MenuUsageAmount(period).text(for:metric))")
                        .help(details(period,tool:row.tool) + "\n" + metric.toggleHint)
                    }
                }.frame(height:18)
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
