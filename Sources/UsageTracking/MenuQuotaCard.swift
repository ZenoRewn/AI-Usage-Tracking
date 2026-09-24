// Author: Zeno Ren
import SwiftUI
import UsageCore

extension QuotaPressure {
    var color: Color {
        if self == .unknown || self == .stale { return .secondary }
        return Color(nsColor:NSColor(name:nil) { appearance in
            let dark = appearance.bestMatch(from:[.darkAqua,.aqua]) == .darkAqua
            switch self {
            case .normal: return dark ? NSColor(srgbRed:0.44,green:0.80,blue:0.71,alpha:1) : NSColor(srgbRed:0.09,green:0.43,blue:0.37,alpha:1)
            case .warning: return dark ? NSColor(srgbRed:0.96,green:0.69,blue:0.38,alpha:1) : NSColor(srgbRed:0.60,green:0.34,blue:0.05,alpha:1)
            case .critical: return dark ? NSColor(srgbRed:1,green:0.52,blue:0.52,alpha:1) : NSColor(srgbRed:0.70,green:0.20,blue:0.23,alpha:1)
            default: return .secondaryLabelColor
            }
        })
    }
}

struct MenuQuotaCard: View {
    let summary: MenuQuotaSummary
    let loading: Bool
    let error: String?
    let refreshStatus: String
    let refresh: () -> Void
    let openAccount: () -> Void
    @State private var showingDetails = false
    private var tool: Tool { summary.tool }
    private var status: String { summary.statusText(loading:loading,error:error) }

    var body: some View {
        VStack(spacing:4) {
            HStack(spacing:0) {
                Text(Display.shortName(tool)).font(.system(size:12,weight:.semibold))
                Spacer(minLength:0)
                if tool != .claude {
                    Button(action:refresh) {
                        Group {
                            if loading { ProgressView().controlSize(.mini) }
                            else { Image(systemName:"arrow.clockwise").font(.system(size:11,weight:.medium)) }
                        }.frame(width:22,height:22)
                    }.buttonStyle(.borderless).disabled(loading)
                    .accessibilityLabel("刷新 \(tool.title) 账户额度")
                    .help("立即刷新 \(tool.title) 账户额度")
                } else { Color.clear.frame(width:22,height:22).accessibilityHidden(true) }
            }
            Button { showingDetails.toggle() } label: {
                VStack(spacing:4) {
                    HStack(spacing:7) {
                        ZStack {
                            Circle().stroke(.primary.opacity(0.10),lineWidth:3)
                            if let fraction = summary.ringFraction, fraction > 0 {
                                Circle().trim(from:0,to:CGFloat(fraction))
                                    .stroke(summary.pressure.color,style:StrokeStyle(lineWidth:3,lineCap:.round))
                                    .rotationEffect(.degrees(-90))
                            }
                            BrandLogo(tool:tool,size:18)
                        }.frame(width:36,height:36).accessibilityHidden(true)
                        Text(summary.percentText).font(.system(size:22,weight:.semibold,design:.rounded)).monospacedDigit()
                            .lineLimit(1).minimumScaleFactor(0.85)
                    }.frame(height:38)
                    Text(status == "已用" ? (summary.primary?.title ?? status) : status).font(.system(size:11,weight:.medium))
                        .foregroundStyle(error != nil || summary.hasStaleWindows ? QuotaPressure.warning.color : summary.pressure.color)
                        .lineLimit(1).frame(height:15).help(summary.windowText)
                    VStack(spacing:1) {
                        Text(summary.primary == nil ? "点击查看获取方式" : summary.resetText)
                            .lineLimit(1).minimumScaleFactor(0.9)
                        if let amount = summary.amountText, let unit = summary.primary?.amounts?.unit.rawValue {
                            Text(amount + " " + unit).lineLimit(1).minimumScaleFactor(0.85)
                        }
                    }.font(.system(size:11)).foregroundStyle(.secondary).monospacedDigit().frame(height:30,alignment:.top)
                }.frame(maxWidth:.infinity).contentShape(Rectangle())
            }.buttonStyle(.plain)
            .accessibilityLabel("\(tool.title)；\(summary.percentText) 已用；\(status)；\(summary.windowText)；\(summary.resetText)；查看额度详情")
            .help("点击查看全部窗口、数据来源与刷新状态")
            .popover(isPresented:$showingDetails,arrowEdge:.bottom) {
                MenuQuotaDetail(summary:summary,loading:loading,error:error,refreshStatus:refreshStatus,refresh:refresh,
                                openAccount:{ showingDetails = false; openAccount() })
            }
        }.padding(8).frame(maxWidth:.infinity,alignment:.top)
        .background(Color(nsColor:.controlBackgroundColor),in:RoundedRectangle(cornerRadius:12))
        .overlay(RoundedRectangle(cornerRadius:12).strokeBorder(showingDetails ? Display.accent : .primary.opacity(0.06)))
    }
}
