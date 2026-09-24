// Author: Zeno Ren
import SwiftUI
import UsageCore

struct MenuQuotaDetail: View {
    let summary: MenuQuotaSummary
    let loading: Bool
    let error: String?
    let refreshStatus: String
    let refresh: () -> Void
    let openAccount: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment:.leading,spacing:14) {
            HStack {
                BrandLogo(tool:summary.tool,size:19,tint:MenuPalette.text)
                Text("\(summary.tool.title) · 额度详情").font(.headline)
                Spacer()
                Button("完成") { dismiss() }.keyboardShortcut(.cancelAction)
            }
            if summary.windows.count > 1 {
                Text("主卡显示有效窗口中最高的已用比例；各窗口独立，不相加。")
                    .font(.caption).foregroundStyle(.secondary)
            }
            ScrollView {
                VStack(alignment:.leading,spacing:18) {
                    if summary.windows.isEmpty {
                        Text("尚未获取账户额度").font(.subheadline.weight(.semibold))
                        Text(summary.tool == .claude ? "在数据源连接 statusLine 后，Claude 的正常活动会更新额度快照。" : "通过工具当前登录账户查询；未返回额度不代表用量为零。")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    ForEach(summary.windows) { quota in window(quota) }
                }.frame(maxWidth:.infinity,alignment:.leading)
            }.frame(height:summary.windows.isEmpty ? 80 : min(280,CGFloat(summary.windows.count) * 190))
            if let error {
                Label("刷新失败：" + error,systemImage:"exclamationmark.circle")
                    .font(.caption).foregroundStyle(QuotaPressure.warning.color).textSelection(.enabled)
                if !summary.windows.isEmpty { Text("已保留上次读数，当前额度待确认。").font(.caption).foregroundStyle(.secondary) }
            }
            Divider()
            Text(loading ? "正在查询账户额度…" : refreshStatus).font(.caption).foregroundStyle(.secondary)
            HStack {
                Button(summary.tool == .claude && summary.windows.isEmpty ? "查看连接说明" : "打开账户额度",action:openAccount)
                Spacer()
                if summary.tool != .claude {
                    Button(loading ? "查询中…" : "立即刷新",action:refresh).disabled(loading)
                }
            }
            Text("Author: Zeno Ren").font(.system(size:11)).foregroundStyle(.secondary)
        }.padding(18).frame(width:360).foregroundStyle(MenuPalette.text).tint(MenuPalette.accent).background(MenuPalette.card)
    }

    private func window(_ quota: QuotaWindow) -> some View {
        let stale = quota.isStale(at:summary.now)
        let pressure = MenuQuotaSummary(tool:quota.tool,quotas:[quota],now:summary.now).pressure
        return VStack(alignment:.leading,spacing:7) {
            HStack(alignment:.firstTextBaseline) {
                Text(quota.title).font(.subheadline.weight(.semibold)).fixedSize(horizontal:false,vertical:true)
                Spacer()
                Text(MenuQuotaSummary.percent(quota.usedPercent) + " 已用").font(.subheadline).monospacedDigit()
            }
            GeometryReader { geometry in
                Capsule().fill(.primary.opacity(0.10)).overlay(alignment:.leading) {
                    Capsule().fill(pressure.color).frame(width:geometry.size.width * min(1,max(0,quota.usedPercent / 100)))
                }
            }.frame(height:5)
                .accessibilityLabel(quota.title + "已用比例")
                .accessibilityValue(MenuQuotaSummary.percent(quota.usedPercent))
            HStack {
                if stale { Label("旧快照",systemImage:"clock").foregroundStyle(QuotaPressure.warning.color) }
                Spacer(minLength:0)
                Text(summary.resetText(for:quota))
            }.font(.caption)
            if let amounts = quota.amounts {
                Text("已用 \(MenuQuotaSummary.exact(amounts.used)) / 总额 \(MenuQuotaSummary.exact(amounts.total)) \(amounts.unit.rawValue)")
                    .font(.caption).textSelection(.enabled)
                Text("剩余 \(MenuQuotaSummary.exact(amounts.remaining)) \(amounts.unit.rawValue)").font(.caption)
            }
            Text(quota.source).font(.caption).foregroundStyle(.secondary)
            Text("采集于 " + quota.capturedAt.formatted(.dateTime.month().day().hour().minute().second()))
                .font(.caption).foregroundStyle(.secondary)
            if let reset = quota.resetsAt {
                Text((reset <= summary.now ? "服务返回的重置时间已过：" : "服务重置时间：") + reset.formatted(.dateTime.month().day().hour().minute()))
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}
