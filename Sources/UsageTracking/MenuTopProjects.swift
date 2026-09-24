// Author: Zeno Ren
import SwiftUI
import UsageCore

struct MenuTopProjects: View {
    let summary: TodayProjectSummary
    let projectName: (String) -> String
    let metric: MenuUsageMetric
    let openProject: (String) -> Void
    private var isToday: Bool { Calendar.current.isDateInToday(summary.dayStart) }
    var body: some View {
        VStack(alignment:.leading,spacing:6) {
            HStack {
                Text("今日 Top 3 项目").font(.system(size:11,weight:.medium)).foregroundStyle(MenuPalette.muted)
                Spacer()
                Text("按 Token 排名").font(.system(size:11)).foregroundStyle(MenuPalette.muted)
            }
            if !isToday {
                Text("正在更新今天的统计…").font(.caption).foregroundStyle(.secondary)
            } else if summary.projects.isEmpty {
                Text("今天暂无可归属项目的用量").font(.caption).foregroundStyle(.secondary)
            } else {
                ForEach(Array(summary.projects.enumerated()),id:\.element.id) { index, project in
                    row(project,rank:index+1)
                }
            }
            if isToday && summary.unassignedTokens > 0 {
                Text("另有 \(Display.tokens(summary.unassignedTokens)) Tokens 未归属项目，未参与排名")
                    .font(.system(size:11)).foregroundStyle(.secondary)
            }
        }
    }
    private func row(_ project: TodayProjectUsage, rank: Int) -> some View {
        let amount = (metric == .tokens && project.hasApproximateDates ? "≈" : "") + MenuUsageAmount(project).text(for:metric)
        return Button { openProject(project.project) } label: {
          HStack(spacing:7) {
            Text(String(rank)).font(.system(size:11,weight:.medium,design:.rounded))
                .foregroundStyle(MenuPalette.muted).frame(width:10,alignment:.leading)
            Text(projectName(project.project)).font(.system(size:11,weight:.medium)).lineLimit(1).truncationMode(.middle)
            Spacer(minLength:0)
            HStack(spacing:4) {
                ForEach(project.tools) { tool in
                    BrandLogo(tool:tool.tool,size:11,tint:MenuPalette.muted)
                        .accessibilityLabel("\(tool.tool.title) · \(tool.tokens.formatted()) Tokens")
                }
            }
            Text(amount)
                .font(.system(size:12,weight:.semibold,design:.rounded)).monospacedDigit()
                .lineLimit(1).minimumScaleFactor(0.85).frame(width:74,alignment:.trailing)
            Image(systemName:"chevron.right").font(.system(size:10)).foregroundStyle(.secondary)
          }.frame(height:26).contentShape(Rectangle())
        }.buttonStyle(.plain)
        .accessibilityLabel("查看今日项目 \(projectName(project.project))，\(metric.title) \(amount)")
        .help(details(project) + "\n点击打开该项目今天的记录。")
    }
    private func details(_ project: TodayProjectUsage) -> String {
        let path = project.project.replacingOccurrences(of:FileManager.default.homeDirectoryForCurrentUser.path,with:"~")
        var lines = [projectName(project.project),path,"今日合计：\(project.tokens.formatted()) Tokens"]
        lines.append("参考成本：" + MenuUsageAmount(project).text(for:.cost))
        for tool in project.tools {
            lines.append("\(tool.tool.title)：\(tool.tokens.formatted()) Tokens · \(MenuUsageAmount(tool).text(for:.cost)) · 输入 \(tool.input.formatted()) / 输出 \(tool.output.formatted()) · \(tool.eventCount) 条记录")
        }
        if project.hasApproximateDates { lines.append("≈ 含会话汇总，跨日归属为近似值。") }
        lines.append("本地时区今天零点起，仅统计已采集用量。")
        lines.append("≈ 为估算；* 为部分用量未定价。")
        return lines.joined(separator:"\n")
    }
}
