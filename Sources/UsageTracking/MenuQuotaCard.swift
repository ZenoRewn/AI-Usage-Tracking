// Author: Zeno Ren
import SwiftUI
import UsageCore

extension QuotaPressure {
    var color: Color {
        switch self {
        case .unknown, .stale: MenuPalette.muted
        case .normal: MenuPalette.good
        case .warning: MenuPalette.warning
        case .critical: MenuPalette.critical
        }
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
        VStack(spacing:3) {
            HStack(spacing:0) {
                Text(Display.shortName(tool)).font(.system(size:12,weight:.semibold))
                Spacer(minLength:0)
                if tool != .claude {
                    Button(action:refresh) {
                        Group {
                            if loading { ProgressView().controlSize(.mini) }
                            else { Image(systemName:"arrow.clockwise").font(.system(size:11,weight:.medium)) }
                        }.frame(width:22,height:22)
                    }.buttonStyle(.borderless).foregroundStyle(MenuPalette.muted).disabled(loading)
                    .accessibilityLabel("刷新 \(tool.title) 账户额度")
                    .help("立即刷新 \(tool.title) 账户额度")
                } else { Color.clear.frame(width:22,height:22).accessibilityHidden(true) }
            }
            Button { showingDetails.toggle() } label: {
                VStack(spacing:3) {
                    HStack(spacing:7) {
                        ZStack {
                            Circle().stroke(MenuPalette.track,lineWidth:3)
                            if let fraction = summary.ringFraction, fraction > 0 {
                                Circle().trim(from:0,to:CGFloat(fraction))
                                    .stroke(summary.pressure.color,style:StrokeStyle(lineWidth:3,lineCap:.round))
                                    .rotationEffect(.degrees(-90))
                            }
                            BrandLogo(tool:tool,size:16,tint:MenuPalette.text)
                        }.frame(width:30,height:30).accessibilityHidden(true)
                        Text(summary.percentText).font(.system(size:21,weight:.semibold,design:.rounded)).monospacedDigit()
                            .lineLimit(1).minimumScaleFactor(0.85)
                    }.frame(height:32)
                    Text(status == "已用" ? (summary.primary?.title ?? status) : status).font(.system(size:11,weight:.medium))
                        .foregroundStyle(error != nil || summary.hasStaleWindows ? MenuPalette.warning : MenuPalette.muted)
                        .lineLimit(1).frame(height:14).help(summary.windowText)
                    Text(summary.primary == nil ? "点击查看获取方式" : summary.resetText)
                        .font(.system(size:11)).foregroundStyle(MenuPalette.text).monospacedDigit()
                        .lineLimit(1).minimumScaleFactor(0.9).frame(height:14)
                }.frame(maxWidth:.infinity).contentShape(Rectangle())
            }.buttonStyle(.plain)
            .accessibilityLabel("\(tool.title)；\(summary.percentText) 已用；\(status)；\(summary.windowText)；\(summary.resetText)；查看额度详情")
            .help(summary.details + "\n点击查看全部窗口、完整计数与刷新状态。")
            .popover(isPresented:$showingDetails,arrowEdge:.bottom) {
                MenuQuotaDetail(summary:summary,loading:loading,error:error,refreshStatus:refreshStatus,refresh:refresh,
                                openAccount:{ showingDetails = false; openAccount() })
            }
        }.padding(.horizontal,8).padding(.vertical,6).frame(maxWidth:.infinity,alignment:.top)
        .foregroundStyle(MenuPalette.text)
        .background(MenuPalette.card.opacity(0.45),in:RoundedRectangle(cornerRadius:12))
        .overlay(RoundedRectangle(cornerRadius:12).strokeBorder(showingDetails ? MenuPalette.accent : .clear))
    }
}
