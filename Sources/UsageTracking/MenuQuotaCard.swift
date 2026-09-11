// Author: Zeno Ren
import SwiftUI
import UsageCore

struct MenuQuotaCard: View {
    let summary: MenuQuotaSummary
    let loading: Bool
    let error: String?
    let refreshStatus: String
    let refresh: () -> Void
    private var tool: Tool { summary.tool }
    private var tint: Color { summary.primary?.isStale(at:summary.now) == true ? .secondary : Display.color(tool) }
    private var helpText: String {
        summary.details + (error.map { "\n\n刷新失败：" + $0 + "\n已保留最近快照。" } ?? "")
            + "\n\n" + (loading ? "正在查询账户额度…" : refreshStatus)
    }
    private var accessibilitySummary: String {
        tool.title + " 账户额度；" + summary.percentText + " 已用；" + (summary.amountCaption ?? "") + " " + (summary.amountText ?? "")
    }
    var body: some View {
        VStack(alignment:.leading,spacing:4) {
            header
            percentage
            Text(summary.subtitle).font(.system(size:9)).foregroundStyle(.secondary).monospacedDigit().lineLimit(1).minimumScaleFactor(0.85)
        }.padding(8).frame(maxWidth:.infinity,alignment:.leading)
        .background(Display.color(tool).opacity(0.045),in:RoundedRectangle(cornerRadius:9))
        .overlay(RoundedRectangle(cornerRadius:9).strokeBorder(Display.color(tool).opacity(0.1)))
        .contentShape(Rectangle()).help(helpText)
        .accessibilityElement(children:.contain)
        .accessibilityLabel(accessibilitySummary)
    }
    private var header: some View {
        HStack(spacing:5) {
            BrandLogo(tool:tool,size:12)
            Text(Display.shortName(tool)).font(.system(size:11,weight:.medium))
            Spacer(minLength:0)
            if tool != .claude { refreshButton }
        }.frame(height:18)
    }
    private var refreshButton: some View {
        Button(action:refresh) {
            Group {
                if loading { ProgressView().controlSize(.mini).scaleEffect(0.65) }
                else { Image(systemName:"arrow.clockwise").font(.system(size:10,weight:.semibold)) }
            }.frame(width:18,height:18)
        }.buttonStyle(.borderless).disabled(loading)
        .accessibilityLabel("刷新 \(tool.title) 账户额度")
        .help(loading ? "正在查询 \(tool.title) 额度…" : "立即刷新 \(tool.title) 账户额度")
    }
    private var percentage: some View {
        HStack(spacing:6) {
            ring
            Text(summary.percentText).font(.system(size:17,weight:.semibold,design:.rounded)).monospacedDigit()
            Spacer(minLength:0)
            if error != nil || summary.hasStaleWindows {
                Image(systemName:error == nil ? "clock" : "exclamationmark.circle").font(.system(size:9)).foregroundStyle(.orange)
                    .accessibilityLabel(error == nil ? "含待更新快照" : "刷新失败")
            }
        }.frame(height:22)
    }
    private var ring: some View {
        Circle().stroke(Display.color(tool).opacity(0.12),lineWidth:2.5)
            .overlay {
                if let fraction = summary.ringFraction {
                    Circle().trim(from:0,to:CGFloat(fraction)).stroke(tint,style:StrokeStyle(lineWidth:2.5,lineCap:.round)).rotationEffect(.degrees(-90))
                }
            }.frame(width:18,height:18).accessibilityHidden(true)
    }
}
