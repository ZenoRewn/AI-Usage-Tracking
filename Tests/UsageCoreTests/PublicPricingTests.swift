// Author: Zeno Ren
import XCTest
@testable import UsageCore

final class PublicPricingTests: XCTestCase {
    let when = TimeCodec.date("2026-09-09T12:00:00Z")!
    func testSamePublicPriceAcrossAllToolsAndHistory() throws {
        let catalog = PriceCatalog()
        for tool in Tool.allCases {
            let cost = try XCTUnwrap(catalog.estimate(model:"gpt-5.4-mini",tool:tool,tokens:.init(input:1_000_000,output:1_000_000),at:TimeCodec.date("2026-01-01T00:00:00Z")!))
            XCTAssertEqual(cost,5.25,accuracy:0.000001)
        }
    }
    func testLongContextThresholdUsesPerRequestInputIncludingCache() throws {
        let catalog = PriceCatalog()
        let regular = try XCTUnwrap(catalog.estimate(model:"gpt-6-astra",tool:.codex,tokens:.init(input:272_000,output:1_000,cacheRead:200_000),at:when))
        let long = try XCTUnwrap(catalog.estimate(model:"gpt-6-astra",tool:.codex,tokens:.init(input:272_001,output:1_000,cacheRead:200_000),at:when))
        XCTAssertEqual(regular,0.97,accuracy:0.000001)
        XCTAssertEqual(long,1.91502,accuracy:0.000001)
    }
    func testSessionAggregateDoesNotPretendToBeOneLongContextRequest() throws {
        let quote = try XCTUnwrap(PriceCatalog().quote(model:"gpt-6-astra",tool:.codex,tokens:.init(input:1_000_000),at:when,precision:.session))
        XCTAssertEqual(quote.amount,10,accuracy:0.000001)
        XCTAssertTrue(quote.note.contains("标准档"))
    }
    func testClaudeAliasesCacheWriteAndFastMode() throws {
        let c = PriceCatalog()
        let normal = try XCTUnwrap(c.estimate(model:"anthropic/claude-sonnet-4-6-20260101",tool:.claude,tokens:.init(input:100_000,output:10_000,cacheRead:60_000,cacheWrite:10_000),at:when))
        XCTAssertEqual(normal,0.2955,accuracy:0.000001)
        let fast = try XCTUnwrap(c.quote(model:"claude-opus-4-8",tool:.claude,tokens:.init(input:100_000),at:when,mode:"fast"))
        XCTAssertEqual(fast.amount,1,accuracy:0.000001)
    }
    func testCustomPriceWinsAndUnlistedModelsRemainUnknown() {
        let custom = ModelRate(model:"gpt-6-astra",tool:.codex,input:1,cacheRead:1,cacheWrite:1,output:1,effectiveFrom:"2026-01-01")
        let c = PriceCatalog(rates:[custom])
        XCTAssertEqual(c.estimate(model:"gpt-6-astra",tool:.codex,tokens:.init(input:1_000_000),at:when),1)
        XCTAssertNil(c.estimate(model:"gpt-5.2",tool:.codex,tokens:.init(input:100),at:when))
        XCTAssertNil(c.estimate(model:"claude-opus-4-6-1m",tool:.claude,tokens:.init(input:100),at:when))
    }
    func testPromotionDoesNotContinuePastPublishedEndDate() {
        let c = PriceCatalog()
        XCTAssertNotNil(c.quote(model:"gemini-3.6-flash",tool:.copilot,tokens:.init(input:100),at:when,pricedAt:when))
        XCTAssertNil(c.quote(model:"gemini-3.6-flash",tool:.copilot,tokens:.init(input:100),at:when,pricedAt:TimeCodec.date("2027-01-01T00:00:00Z")!))
    }
    func testPreviouslySavedCustomSettingsStillDecode() throws {
        let config = AppConfiguration(dataDirectory:URL(fileURLWithPath:"/tmp/usage-tracking-settings-fixture"))
        let restored = try JSONDecoder().decode(AppConfiguration.self,from:JSONEncoder().encode(config))
        XCTAssertNotNil(restored.prices.estimate(model:"claude-opus-5",tool:.claude,tokens:.init(input:100),at:when))
    }
}
