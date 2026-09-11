// Author: Zeno Ren
import XCTest
@testable import UsageTracking

final class MenuUsageAmountTests: XCTestCase {
    func testSameUsageCanDisplayTokensOrReferenceCost() {
        let amount = MenuUsageAmount(tokens:1_000_000,eventCount:1,estimatedCost:2.2,pricedTokens:1_000_000)
        XCTAssertEqual(amount.text(for:.tokens),"1.00M")
        XCTAssertEqual(amount.text(for:.cost),"≈$2.20")
    }
    func testUnknownCostAndAbsentUsageAreNeverDisplayedAsFree() {
        let unknown = MenuUsageAmount(tokens:100,eventCount:1,estimatedCost:0,pricedTokens:0)
        let absent = MenuUsageAmount(tokens:0,eventCount:0,estimatedCost:0,pricedTokens:0)
        XCTAssertEqual(unknown.text(for:.cost),"未定价")
        XCTAssertEqual(absent.text(for:.cost),"—")
        XCTAssertEqual(absent.text(for:.tokens),"—")
    }
    func testPartialCostIsMarkedAndExplicitZeroPriceIsPreserved() {
        let partial = MenuUsageAmount(tokens:200,eventCount:2,estimatedCost:0.5,pricedTokens:100)
        let free = MenuUsageAmount(tokens:100,eventCount:1,estimatedCost:0,pricedTokens:100)
        XCTAssertEqual(partial.text(for:.cost),"≈$0.50*")
        XCTAssertEqual(free.text(for:.cost),"≈$0.00")
    }
}
