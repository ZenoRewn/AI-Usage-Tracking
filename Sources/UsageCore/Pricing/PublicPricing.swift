// Author: Zeno Ren
import Foundation

public struct TokenPrice: Sendable {
    public let input: Double
    public let cacheRead: Double
    public let cacheWrite: Double?
    public let output: Double
    func cost(_ tokens: TokenCounts) -> Double {
        // A model without a separate cache-write tariff bills those input tokens at its input rate.
        (Double(tokens.uncachedInput)*input + Double(tokens.cacheRead)*cacheRead + Double(tokens.cacheWrite)*(cacheWrite ?? input) + Double(tokens.output)*output)/1_000_000
    }
}
public struct PublicModelPrice: Sendable, Identifiable {
    public let id: String
    public let displayName: String
    public let provider: String
    public let standard: TokenPrice
    public let contextThreshold: Int64?
    public let longContext: TokenPrice?
    public let promotionThrough: String?
}
public struct CostQuote: Sendable {
    public let amount: Double
    public let model: String
    public let source: String
    public let asOf: String
    public let tier: String
    public let note: String
    public var basis: String { "\(source) · \(asOf) · \(tier)" + (note.isEmpty ? "" : " · \(note)") }
}

extension CopilotPublicPricing {
    private static let index: [String:PublicModelPrice] = Dictionary(uniqueKeysWithValues: models.flatMap { model in
        let keys = Set([normalized(model.id),normalized(model.displayName)])
        return keys.map { ($0,model) }
    })
    public static func normalized(_ value: String) -> String {
        var name = value.lowercased().trimmingCharacters(in:.whitespacesAndNewlines)
        if let slash = name.firstIndex(of:"/"), ["openai","anthropic","google","copilot","github-copilot","xai","moonshot","microsoft"].contains(String(name[..<slash])) { name = String(name[name.index(after:slash)...]) }
        if name.count > 9, name.suffix(9).first == "-", name.suffix(8).allSatisfy(\.isNumber) { name.removeLast(9) }
        return name.replacingOccurrences(of:".",with:"-").replacingOccurrences(of:" ",with:"-")
    }
    public static func model(_ identifier: String, mode: String? = nil) -> PublicModelPrice? {
        var key = normalized(identifier)
        if mode == "fast" && !key.hasSuffix("-fast") { key += "-fast" }
        return index[key]
    }
}

extension PriceCatalog {
    public func quote(_ event: UsageEvent, pricedAt: Date = Date()) -> CostQuote? {
        quote(model:event.model,tool:event.tool,tokens:event.tokens,at:event.date,precision:event.precision,mode:event.pricingMode,pricedAt:pricedAt)
    }
    public func quote(model: String, tool: Tool, tokens: TokenCounts, at: Date, precision: Precision = .response, mode: String? = nil, pricedAt: Date = Date()) -> CostQuote? {
        guard [tokens.input,tokens.output,tokens.cacheRead,tokens.cacheWrite].allSatisfy({ $0 >= 0 }), tokens.cacheRead + tokens.cacheWrite <= tokens.input else { return nil }
        let day = String(TimeCodec.string(at).prefix(10))
        if let custom = rates.filter({ $0.model == model && $0.tool == tool && $0.effectiveFrom <= day }).max(by:{ $0.effectiveFrom < $1.effectiveFrom }) {
            guard [custom.input,custom.output,custom.cacheRead,custom.cacheWrite].allSatisfy({ $0.isFinite && $0 >= 0 }) else { return nil }
            let price = TokenPrice(input:custom.input,cacheRead:custom.cacheRead,cacheWrite:custom.cacheWrite,output:custom.output)
            return .init(amount:price.cost(tokens),model:model,source:"自定义价格",asOf:custom.effectiveFrom,tier:"自定义档",note:"")
        }
        guard let published = CopilotPublicPricing.model(model,mode:mode) else { return nil }
        if let expiry = published.promotionThrough, String(TimeCodec.string(pricedAt).prefix(10)) > expiry { return nil }
        let perRequest = precision == .response || precision == .telemetry
        let long = perRequest && published.contextThreshold.map { tokens.input > $0 } == true
        let point = long ? published.longContext ?? published.standard : published.standard
        let approximation = !perRequest && published.contextThreshold != nil ? "汇总缺少单次输入长度，按标准档估算" : ""
        return .init(amount:point.cost(tokens),model:published.displayName,source:"GitHub Copilot 公价",asOf:CopilotPublicPricing.asOf,tier:long ? "长上下文档" : "标准档",note:approximation)
    }
}
