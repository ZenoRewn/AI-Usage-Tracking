// Author: Zeno Ren
import SwiftUI
import UsageCore

struct MenuTopProjects: View {
    let summary: TodayProjectSummary
    let projectName: (String) -> String
    let metric: MenuUsageMetric
    let toggleMetric: () -> Void
    private var isToday: Bool { Calendar.current.isDateInToday(summary.dayStart) }
    var body: some View {
        VStack(alignment:.leading,spacing:6) {
            HStack {
                Text("今日 Top 3 项目").font(.system(size:10,weight:.medium)).foregroundStyle(.secondary)
                Spacer()
                if metric == .cost { Text("按 Token 排名").font(.system(size:9)).foregroundStyle(.tertiary) }
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
                    .font(.system(size:9)).foregroundStyle(.secondary)
            }
        }
    }
    private func row(_ project: TodayProjectUsage, rank: Int) -> some View {
        HStack(spacing:7) {
            Text(String(rank)).font(.system(size:10,weight:.semibold,design:.rounded))
                .foregroundStyle(Display.purple).frame(width:10,alignment:.leading)
            Text(projectName(project.project)).font(.system(size:11,weight:.medium)).lineLimit(1).truncationMode(.middle)
            Spacer(minLength:0)
            HStack(spacing:4) {
                ForEach(project.tools) { tool in
                    BrandLogo(tool:tool.tool,size:11)
                        .accessibilityLabel("\(tool.tool.title) · \(tool.tokens.formatted()) Tokens")
                }
            }
            amountButton(project)
        }.frame(height:18).contentShape(Rectangle())
        .accessibilityElement(children:.contain).help(details(project) + "\n" + metric.toggleHint)
    }
    private func amountButton(_ project: TodayProjectUsage) -> some View {
        let amount = MenuUsageAmount(project).text(for:metric)
        let prefix = metric == .tokens && project.hasApproximateDates ? "≈" : ""
        let label = projectName(project.project) + " " + metric.title + " " + amount
        let helpText = details(project) + "\n" + metric.toggleHint
        return Button(action:toggleMetric) {
            Text(prefix + amount)
                .font(.system(size:12,weight:.semibold,design:.rounded)).monospacedDigit()
                .lineLimit(1).minimumScaleFactor(0.85).frame(width:74,height:18,alignment:.trailing)
                .contentShape(Rectangle())
        }.buttonStyle(.plain).accessibilityLabel(Text(label)).help(Text(helpText))
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
