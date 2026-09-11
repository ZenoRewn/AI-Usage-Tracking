// Author: Zeno Ren
import XCTest
@testable import UsageCore

final class ClientAnalyticsTests: XCTestCase {
    func event(_ id:String, tool:Tool = .codex, client:String, model:String = "gpt-5.4-mini", session:String = "session", tokens:Int64 = 100, precision:Precision = .response) -> UsageEvent {
        .init(id:id,tool:tool,surface:client,session:session,project:"/project",model:model,timestamp:"2026-09-09T00:00:00Z",tokens:.init(input:tokens,output:20,cacheRead:40),precision:precision)
    }
    func testSameModelAcrossClientsStaysSeparateAndTotalsReconcile() {
        let input=[event("a",client:"Codex App",tokens:100),event("b",client:"Codex Exec",tokens:200),event("c",tool:.copilot,client:"Copilot VS Code",tokens:300)]
        let result=ClientAnalytics.summarize(input)
        XCTAssertEqual(result.count,3)
        XCTAssertEqual(result.reduce(0){$0+$1.metrics.tokens},input.reduce(0){$0+$1.tokens.total})
        XCTAssertEqual(result.first{$0.client=="Codex App"}?.models.first?.metrics.tokens,120)
        XCTAssertEqual(result.first{$0.client=="Codex Exec"}?.models.first?.metrics.tokens,220)
    }
    func testOneSessionSwitchingModelsIsNotTwoClientSessions() {
        let result=ClientAnalytics.summarize([event("a",client:"Codex App"),event("b",client:"Codex App",model:"gpt-6-astra")])
        XCTAssertEqual(result[0].metrics.sessionCount,1)
        XCTAssertEqual(result[0].models.count,2)
        XCTAssertEqual(result[0].models.map(\.metrics.sessionCount),[1,1])
    }
    func testUnpricedUsageAndSummariesAreNotCalledFreeOrRequests() {
        let result=ClientAnalytics.summarize([event("a",client:"Codex CLI / 其他",model:"unknown",precision:.snapshot)])
        XCTAssertNil(result[0].metrics.estimatedCost)
        XCTAssertEqual(result[0].metrics.preciseCallRecords,0)
        XCTAssertEqual(result[0].metrics.recordCount,1)
        XCTAssertEqual(result[0].metrics.pricedTokens,0)
        XCTAssertEqual(result[0].client,"Codex CLI / 其他")
    }
    func testCacheIsSubsetAndUnknownClientsArePreserved() {
        let row=event("a",client:"")
        let result=ClientAnalytics.summarize([row])
        XCTAssertEqual(result[0].client,"未识别客户端")
        XCTAssertEqual(result[0].metrics.tokens,120)
        XCTAssertEqual(result[0].metrics.cacheRead,40)
        XCTAssertEqual(result[0].metrics.cacheHitRate!,0.4,accuracy:0.0001)
    }
    func testFastModeRemainsDistinctAndExistingPricesAreUsed() {
        var fast=event("a",tool:.claude,client:"Claude Code CLI",model:"claude-opus-4-8",tokens:100_000);fast.pricingMode="fast"
        let normal=event("b",tool:.claude,client:"Claude Code CLI",model:"claude-opus-4-8",tokens:100_000)
        let result=ClientAnalytics.summarize([fast,normal])
        XCTAssertEqual(result[0].models.count,2)
        let fastRow=result[0].models.first{$0.mode=="fast"}!
        XCTAssertEqual(fastRow.metrics.estimatedCost!,PriceCatalog().quote(fast)!.amount,accuracy:0.00001)
    }
    func testSummaryExportContainsClientModelMetricsButNoPrivatePaths() throws {
        let rows=ClientAnalytics.summarize([event("a",client:"Codex App")])
        let data=try ClientAnalytics.json(rows)
        let string=String(decoding:data,as:UTF8.self)
        XCTAssertTrue(string.contains("Codex App"));XCTAssertTrue(string.contains("gpt-5.4-mini"));XCTAssertTrue(string.contains("Zeno Ren"))
        XCTAssertFalse(string.contains("/project"));XCTAssertFalse(string.contains("session\""))
        XCTAssertTrue(ClientAnalytics.csv(rows).contains("client,model,mode"))
    }
}
