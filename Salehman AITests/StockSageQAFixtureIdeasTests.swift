import Testing
import Foundation
@testable import Salehman_AI

// MARK: - QA fixture-ideas contract test
//
// Pins the same 5 pinned outcomes the QA capture seam (StockSageStore.seedQAIdeas,
// QASnapshots.swift's --qa path) depends on. Calls buildIdeas directly with the fixture
// builders — never touches StockSageStore.shared — so it's parallel-test safe. All
// assertions restate pins that already exist elsewhere in this suite
// (StockSageAdvisorTests / StockSageBuildIdeasDirectTests); no new derivations.

struct StockSageQAFixtureIdeasTests {
    @Test func qaFixturesProduceExpectedActionsPerCard() async {
        let ideas = await StockSageStore.buildIdeas(defs: StockSageStore.qaFixtureDefs(),
                                                    histories: StockSageStore.qaFixtureHistories())
        #expect(ideas.count == 5)

        func idea(_ symbol: String) -> StockSageIdea? {
            ideas.first { $0.symbol == symbol }
        }

        let nvda = idea("NVDA")
        #expect(nvda?.advice.action == .strongBuy)

        let aapl = idea("AAPL")
        #expect(aapl?.advice.action == .buy)

        let sr1120 = idea("1120.SR")
        #expect(sr1120?.advice.action == .sell || sr1120?.advice.action == .reduce)
        if let stop = sr1120?.advice.stopPrice, let price = sr1120?.price {
            #expect(stop > price)   // short setup: stop sits above entry
        }

        let btc = idea("BTC-USD")
        #expect(btc?.advice.action == .strongBuy)

        let sr7010 = idea("7010.SR")
        #expect(sr7010?.advice.rationale.contains { $0.contains("⚠") } == true)
    }
}
