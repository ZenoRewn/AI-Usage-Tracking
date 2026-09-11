// Author: Zeno Ren
import SwiftUI
import UsageCore

struct ModelPricesView: View {
    @Bindable var model: AppModel
    @State private var adding = false
    var body: some View {
        SurfaceCard(title:"统一参考价格",subtitle:"USD / 百万 Token") {
            HStack {
                Text("\(CopilotPublicPricing.models.count) 个模型 · \(Set(CopilotPublicPricing.models.map(\.provider)).count) 个 Provider")
                Spacer(); Text("价格快照 \(CopilotPublicPricing.asOf)")
            }.font(.caption).foregroundStyle(.secondary)
            Text("对所有工具和历史用量按当前公价折算。逐次调用按上下文阈值分档，汇总记录按标准档估算；自定义价格优先。").font(.caption).foregroundStyle(.secondary)
            PublicPriceTable()
        }
        SurfaceCard(title:"自定义价格表",subtitle:"每百万 Token / USD") {
            HStack { Text("同一模型可保留不同生效日的价格版本。").font(.caption).foregroundStyle(.secondary); Spacer(); Button("添加模型价格") { adding = true }.buttonStyle(.borderedProminent) }
            ForEach(model.config.prices.rates) { rate in
                HStack { VStack(alignment:.leading) { Text("\(rate.tool.title) · \(rate.model)"); Text("\(rate.effectiveFrom) 起 · 输入 $\(rate.input.formatted()) / 缓存读 $\(rate.cacheRead.formatted()) / 写 $\(rate.cacheWrite.formatted()) / 输出 $\(rate.output.formatted())").font(.caption).foregroundStyle(.secondary) }; Spacer(); Button("移除") { model.config.prices.rates.removeAll { $0.id == rate.id }; model.save() } }
                Divider()
            }
        }.sheet(isPresented:$adding) { PriceEditor(model:model) }
    }
}

struct PublicPriceTable: View {
    @State private var search = ""
    @State private var provider = "all"
    private var providers: [String] { Array(Set(CopilotPublicPricing.models.map(\.provider))).sorted() }
    private var prices: [PublicModelPrice] {
        CopilotPublicPricing.models.filter {
            (provider == "all" || $0.provider == provider)
                && (search.isEmpty || ($0.displayName + $0.provider).localizedCaseInsensitiveContains(search))
        }
    }
    var body: some View {
        VStack(alignment:.leading,spacing:12) {
            HStack(spacing:14) {
                Picker("Provider",selection:$provider) {
                    Text("全部 Provider").tag("all")
                    ForEach(providers,id:\.self) { Text($0).tag($0) }
                }.frame(width:240)
                TextField("搜索模型",text:$search).textFieldStyle(.roundedBorder)
                Text("\(prices.count) 个模型").font(.caption).foregroundStyle(.secondary)
            }
            Grid(alignment:.leading,horizontalSpacing:16,verticalSpacing:10) {
                GridRow {
                    Text("模型 / 档位").frame(maxWidth:.infinity,alignment:.leading)
                    Text("输入"); Text("缓存读"); Text("缓存写"); Text("输出")
                }.font(.caption).foregroundStyle(.secondary)
                ForEach(prices) { price in
                    row(price,point:price.standard,isLong:false)
                    if let long = price.longContext { row(price,point:long,isLong:true) }
                }
            }
            if prices.isEmpty { Text("没有匹配的模型，请调整 Provider 或搜索内容。").font(.caption).foregroundStyle(.secondary).padding(.vertical,8) }
            Text("“—”表示未单列缓存写入费，写入 Token 按输入单价折算。Gemini 3.6 / 3.7 / 3.8 Flash 促销价截至 2026-12-31，过期后不自动沿用。").font(.caption2).foregroundStyle(.secondary)
        }
    }
    private func row(_ model: PublicModelPrice,point: TokenPrice,isLong: Bool) -> some View {
        GridRow {
            VStack(alignment:.leading,spacing:2) {
                Text(model.displayName).font(.system(size:12,weight:isLong ? .regular : .medium))
                Text(isLong ? "长上下文 > \(model.contextThreshold ?? 0) 输入 Token" : model.provider + (model.contextThreshold.map { " · ≤ \($0) 输入 Token" } ?? "")).font(.system(size:10)).foregroundStyle(.secondary)
            }.padding(.vertical,3)
            amount(point.input); amount(point.cacheRead); amount(point.cacheWrite); amount(point.output)
        }
    }
    private func amount(_ number: Double?) -> some View {
        Text(number.map { "$" + $0.formatted(.number.precision(.fractionLength(0...3))) } ?? "—").font(.system(size:12,design:.monospaced)).frame(minWidth:54,alignment:.trailing)
    }
}

struct PriceEditor: View {
    @Bindable var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var tool = Tool.codex
    @State private var name = ""
    @State private var input = ""
    @State private var cacheRead = ""
    @State private var cacheWrite = ""
    @State private var output = ""
    @State private var from = "2026-09-09"
    var values: [Double]? {
        let values = [input,cacheRead,cacheWrite,output].compactMap(Double.init)
        return values.count == 4 && values.allSatisfy { $0.isFinite && $0 >= 0 } ? values : nil
    }
    var body: some View {
        VStack(alignment:.leading,spacing:18) {
            Text("添加模型价格").font(.title2.bold())
            Text("单位为 USD / 百万 Token。按所选工具和精确模型 ID 匹配。").font(.caption).foregroundStyle(.secondary)
            Form {
                Picker("工具",selection:$tool) { ForEach(Tool.allCases) { Text($0.title).tag($0) } }
                TextField("模型 ID",text:$name)
                TextField("未缓存输入",text:$input)
                TextField("缓存读取",text:$cacheRead)
                TextField("缓存写入",text:$cacheWrite)
                TextField("输出",text:$output)
                TextField("生效日 YYYY-MM-DD",text:$from)
            }.textFieldStyle(.roundedBorder)
            HStack { Button("取消") { dismiss() }; Spacer(); Button("保存价格") {
                guard let values else { return }
                let rate = ModelRate(model:name.trimmingCharacters(in:.whitespaces),tool:tool,input:values[0],cacheRead:values[1],cacheWrite:values[2],output:values[3],effectiveFrom:from)
                model.config.prices.rates.removeAll { $0.id == rate.id }; model.config.prices.rates.append(rate); model.save(); dismiss()
            }.disabled(values == nil || name.trimmingCharacters(in:.whitespaces).isEmpty || TimeCodec.date(from + "T00:00:00Z") == nil).buttonStyle(.borderedProminent) }
        }.padding(28).frame(width:500)
    }
}
