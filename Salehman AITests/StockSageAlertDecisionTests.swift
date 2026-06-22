import Testing
import Foundation
@testable import Salehman_AI

// MARK: - Alert decision (pure)

struct StockSageAlertDecisionTests {
    typealias AD = StockSageAlertDecision

    @Test func newStrongSignalAlertsOnceThenDedupes() {
        // First time we see a Strong Buy (nothing alerted before) → fire.
        let a = AD.evaluate(symbol: "AAPL", recommendation: .strongBuy, price: 100, priorPrice: 100,
                            stop: 90, target: 120, lastAlertedRecommendation: nil)
        #expect(a?.kind == .newStrongBuy)
        // Same Strong Buy already alerted → silent (dedupe).
        #expect(AD.evaluate(symbol: "AAPL", recommendation: .strongBuy, price: 101, priorPrice: 100,
                            stop: 90, target: 120, lastAlertedRecommendation: .strongBuy) == nil)
    }

    @Test func flipFiresWhenStrongReverses() {
        let a = AD.evaluate(symbol: "T", recommendation: .strongBuy, price: 100, priorPrice: 100,
                            stop: 90, target: 120, lastAlertedRecommendation: .strongSell)
        #expect(a?.kind == .flip)
    }

    @Test func nonStrongSignalsStaySilent() {
        for rec in [StockSageRecommendation.buy, .hold, .sell] {
            #expect(AD.evaluate(symbol: "X", recommendation: rec, price: 100, priorPrice: 100,
                                stop: 90, target: 120, lastAlertedRecommendation: nil) == nil)
        }
    }

    @Test func stopCrossFiresOnceOnTheCrossing() {
        // Crossed DOWN through 90 this update (95 → 89): fire.
        #expect(AD.evaluate(symbol: "X", recommendation: .buy, price: 89, priorPrice: 95,
                            stop: 90, target: 120, lastAlertedRecommendation: nil)?.kind == .stopBreach)
        // Already below before (89 → 88): no fresh cross → silent.
        #expect(AD.evaluate(symbol: "X", recommendation: .buy, price: 88, priorPrice: 89,
                            stop: 90, target: 120, lastAlertedRecommendation: nil) == nil)
    }

    @Test func shortStopAndTargetCrossesAreSideAware() {
        // SHORT (sell/strongSell): stop ABOVE (110), target BELOW (80).
        // Stop-out = price crosses UP through the stop (105 → 111): fire.
        #expect(AD.evaluate(symbol: "X", recommendation: .sell, price: 111, priorPrice: 105,
                            stop: 110, target: 80, lastAlertedRecommendation: nil)?.kind == .stopBreach)
        // A WINNING short falling toward target (105 → 99) must NOT fire a stop breach.
        #expect(AD.evaluate(symbol: "X", recommendation: .sell, price: 99, priorPrice: 105,
                            stop: 110, target: 80, lastAlertedRecommendation: nil) == nil)
        // Target = price crosses DOWN through the target (82 → 79): fire targetHit.
        #expect(AD.evaluate(symbol: "X", recommendation: .strongSell, price: 79, priorPrice: 82,
                            stop: 110, target: 80, lastAlertedRecommendation: nil)?.kind == .targetHit)
    }

    @Test func targetCrossFiresOnceOnTheCrossing() {
        #expect(AD.evaluate(symbol: "X", recommendation: .buy, price: 121, priorPrice: 115,
                            stop: 90, target: 120, lastAlertedRecommendation: nil)?.kind == .targetHit)
        // Already above before → silent.
        #expect(AD.evaluate(symbol: "X", recommendation: .buy, price: 122, priorPrice: 121,
                            stop: 90, target: 120, lastAlertedRecommendation: nil) == nil)
    }

    @Test func stopBreachOutranksASignalChange() {
        // Both a fresh stop cross AND a new strong-sell signal → the stop breach wins (more actionable).
        let a = AD.evaluate(symbol: "X", recommendation: .strongSell, price: 89, priorPrice: 95,
                            stop: 90, target: 120, lastAlertedRecommendation: nil)
        #expect(a?.kind == .stopBreach)
    }
}
