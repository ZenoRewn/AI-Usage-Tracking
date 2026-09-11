// Author: Zeno Ren
import SwiftUI
import UsageCore

struct ClientModelsView: View {
    @Bindable var model: AppModel
    @State private var sortByCost = false
    var body: some View {
        let clients = sortedClients(model.clientAnalysis)
        let records = clients.reduce(0) { $0 + $1.metrics.recordCount }
        HStack(spacing:14) {
            Text("客户端").font(.subheadline)
            Picker("客户端",selection:$model.selectedClient) {
                Text("全部已观测客户端").tag("all")
                ForEach(model.clientOptions,id:\.id) { client in Text(client.title).tag(client.id) }
            }.labelsHidden().frame(width:245)
            Spacer()
            Picker("排序",selection:$sortByCost) { Text("按 Token").tag(false); Text("按成本").tag(true) }.pickerStyle(.segmented).frame(width:180)
        }
        HStack(spacing:14) {
            MetricCard(title:"已观测客户端",value:String(clients.count),note:"按工具与实际入口分别统计",symbol:"desktopcomputer")
            MetricCard(title:"客户端 × 模型",value:String(clients.reduce(0){$0+$1.models.count}),note:"同一模型在不同入口分别计量",symbol:"square.stack.3d.up")
            MetricCard(title:"用量记录",value:records.formatted(),note:"汇总记录不视作单次 API 调用",symbol:"list.bullet.rectangle")
        }
        if clients.isEmpty {
            SurfaceCard(title:"") {
                ContentUnavailableView("当前范围没有客户端用量",systemImage:"desktopcomputer",description:Text("调整时间、工具或客户端筛选；尚未采集的入口可在“数据源”中连接。"))
            }
        }
        ForEach(clients) { client in
            SurfaceCard(title:client.client,subtitle:"\(client.models.count) 个模型组合",tool:client.tool) {
                HStack(alignment:.top,spacing:24) {
                    VStack(alignment:.leading,spacing:5) {
                        Text(Display.tokens(client.metrics.tokens)).font(.system(size:28,weight:.semibold,design:.rounded))
                        Text("输入 \(Display.tokens(client.metrics.input)) · 输出 \(Display.tokens(client.metrics.output))").font(.caption).foregroundStyle(.secondary)
                    }
                    VStack(alignment:.leading,spacing:5) {
                        Text(cost(client.metrics)).font(.system(size:22,weight:.semibold,design:.rounded)).foregroundStyle(Display.color(client.tool))
                        Text("参考成本 · 价格覆盖 \(Int(client.metrics.priceCoverage*100))%").font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    VStack(alignment:.trailing,spacing:6) {
                        Text("\(client.metrics.sessionCount) 会话 · \(client.metrics.projectCount) 项目").font(.subheadline)
                        if let last = client.metrics.lastSeen { Text(last,format:.dateTime.month().day().hour().minute()).font(.caption).foregroundStyle(.secondary) }
                    }
                }
                Divider()
                HStack(spacing:12) {
                    Text("模型 / 客户端内占比").frame(maxWidth:.infinity,alignment:.leading)
                    Text("Token").frame(width:115,alignment:.trailing)
                    Text("缓存读占比").frame(width:75,alignment:.trailing)
                    Text("参考成本").frame(width:115,alignment:.trailing)
                    Text("记录 / 会话").frame(width:90,alignment:.trailing)
                }.font(.system(size:11)).foregroundStyle(.secondary)
                ForEach(sortedModels(client.models)) { row in
                    Button { model.showClientModel(client,row) } label: {
                        HStack(spacing:12) {
                            VStack(alignment:.leading,spacing:7) {
                                Text(row.displayName).font(.system(size:13,weight:.medium)).lineLimit(1).help(row.displayName)
                                HStack(spacing:7) {
                                    GeometryReader { geometry in
                                        Capsule().fill(Display.color(client.tool).opacity(0.10)).overlay(alignment:.leading) {
                                            Capsule().fill(Display.color(client.tool)).frame(width:geometry.size.width * share(row,client))
                                        }
                                    }.frame(width:72,height:4)
                                    Text(share(row,client).formatted(.percent.precision(.fractionLength(1)))).font(.system(size:10)).foregroundStyle(.secondary)
                                }
                            }.frame(maxWidth:.infinity,alignment:.leading)
                            VStack(alignment:.trailing,spacing:4) {
                                Text(Display.tokens(row.metrics.tokens)).font(.system(.subheadline,design:.rounded).weight(.semibold))
                                Text("in \(Display.tokens(row.metrics.input)) / out \(Display.tokens(row.metrics.output))").font(.system(size:9)).foregroundStyle(.secondary)
                            }.frame(width:115,alignment:.trailing)
                            Text(row.metrics.cacheHitRate.map { $0.formatted(.percent.precision(.fractionLength(1))) } ?? "—").font(.subheadline).monospacedDigit().frame(width:75,alignment:.trailing).help("缓存读取 Token ÷ 全部输入 Token")
                            Text(cost(row.metrics)).font(.system(size:12,design:.rounded)).frame(width:115,alignment:.trailing)
                                .help("价格覆盖 \(Int(row.metrics.priceCoverage*100))% · GitHub Copilot 公价参考，非实际账单")
                            Text("\(row.metrics.recordCount) / \(row.metrics.sessionCount)").font(.system(size:12,design:.rounded)).frame(width:90,alignment:.trailing)
                        }.padding(.vertical,7).contentShape(Rectangle())
                    }.buttonStyle(.plain)
                    Divider()
                }
                HStack {
                    Text("\(client.metrics.preciseCallRecords) 条逐响应/调用记录 · \(client.metrics.aggregateRecords) 条累计/会话汇总").font(.caption2).foregroundStyle(.secondary)
                    Spacer(); Text("点击模型查看明细 ›").font(.caption).foregroundStyle(Display.accent)
                }
            }
        }
        Notice(text:"统计按实际客户端来源分组，不根据模型名称反推入口。“其他/未识别”保持不确定状态；缺失入口不显示伪零值。* 表示成本仅覆盖部分记录。")
    }
    private func share(_ row: ClientModelUsage,_ client: ClientUsage) -> Double { client.metrics.tokens == 0 ? 0 : Double(row.metrics.tokens)/Double(client.metrics.tokens) }
    private func cost(_ metrics: ClientMetrics) -> String {
        guard let amount = metrics.estimatedCost else { return "未定价" }
        return "≈" + amount.formatted(.currency(code:"USD")) + (metrics.pricedRecords < metrics.recordCount ? "*" : "")
    }
    private func sortedClients(_ rows: [ClientUsage]) -> [ClientUsage] {
        guard sortByCost else { return rows }
        return rows.sorted { ($0.metrics.estimatedCost ?? -1) > ($1.metrics.estimatedCost ?? -1) }
    }
    private func sortedModels(_ rows: [ClientModelUsage]) -> [ClientModelUsage] {
        guard sortByCost else { return rows }
        return rows.sorted { ($0.metrics.estimatedCost ?? -1) > ($1.metrics.estimatedCost ?? -1) }
    }
}
