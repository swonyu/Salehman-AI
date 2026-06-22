import Testing
import Foundation
@testable import Salehman_AI

// MARK: - Technical indicators (pure, known-value)
//
// These pin each indicator to a hand-computable result so a future tweak is a
// conscious change. Evidence/intent: MARKETS_INTELLIGENCE_RESEARCH.md.

struct StockSageAdvisorStopTargetTests {
    typealias A = StockSageAdvisor

    @Test func stopTargetIsSymmetricForLongsAndShorts() {
        // Long with ATR: stop BELOW, target ABOVE, 2:1.
        let long = A.stopTarget(action: .strongBuy, price: 100, atr: 5)
        #expect(long.stop == 90 && long.target == 120)
        // Short (sell) with ATR: stop ABOVE, target BELOW, 2:1 — the mirror.
        let short = A.stopTarget(action: .sell, price: 100, atr: 5)
        #expect(short.stop == 110 && short.target == 80)
        // 8% stop fallback when no ATR.
        #expect(A.stopTarget(action: .buy, price: 100, atr: nil).stop == 92)
        #expect(A.stopTarget(action: .reduce, price: 100, atr: nil).stop == 108)
        // Non-actionable actions get nothing.
        #expect(A.stopTarget(action: .hold, price: 100, atr: 5).stop == nil)
        #expect(A.stopTarget(action: .avoid, price: 100, atr: 5).target == nil)
    }
}

struct StockSageIndicatorTests {

    @Test func smaAveragesTheWindow() {
        #expect(StockSageIndicators.sma([1, 2, 3, 4, 5], period: 5) == 3)
        #expect(StockSageIndicators.sma([2, 4, 6], period: 2) == 5)
        #expect(StockSageIndicators.sma([1, 2], period: 5) == nil)   // not enough data
    }

    @Test func emaOfConstantIsThatConstant() {
        #expect(StockSageIndicators.ema([7, 7, 7, 7, 7], period: 3) == 7)
    }

    @Test func rsiExtremes() {
        let up = (1...20).map(Double.init)            // only gains
        let down = (1...20).reversed().map(Double.init) // only losses
        #expect(StockSageIndicators.rsi(up) == 100)
        #expect(StockSageIndicators.rsi(down) == 0)
    }

    @Test func macdOfConstantIsZero() {
        let flat = Array(repeating: 5.0, count: 40)
        let m = StockSageIndicators.macd(flat)
        #expect(m == StockSageIndicators.MACDValue(macd: 0, signal: 0, histogram: 0))
    }

    @Test func atrOfConstantRange() {
        // high-low = 2 every bar, closes flat → ATR == 2.
        let highs = Array(repeating: 11.0, count: 6)
        let lows  = Array(repeating: 9.0, count: 6)
        let closes = Array(repeating: 10.0, count: 6)
        #expect(StockSageIndicators.atr(highs: highs, lows: lows, closes: closes, period: 3) == 2)
    }

    @Test func efficiencyRatioTrendVsChop() {
        let trend = (1...6).map(Double.init)          // clean trend → 1
        let chop: [Double] = [1, 2, 1, 2, 1, 2]       // pure chop → 0.2
        #expect(StockSageIndicators.efficiencyRatio(trend, period: 5) == 1)
        #expect(abs((StockSageIndicators.efficiencyRatio(chop, period: 5) ?? -1) - 0.2) < 1e-9)
    }

    @Test func volatilityOfConstantIsZero() {
        #expect(StockSageIndicators.annualizedVolatility(Array(repeating: 100.0, count: 10)) == 0)
    }

    @Test func returnOverPeriodComputes() {
        #expect(StockSageIndicators.returnOverPeriod([10, 11, 12], period: 2) == 20)
    }

    /// The indicators are TOTAL — insufficient/malformed input must yield nil, never
    /// a crash or NaN (the advisor/backtester rely on this; pin the guards).
    @Test func indicatorsGuardInsufficientOrMalformedInput() {
        #expect(StockSageIndicators.sma([1, 2], period: 5) == nil)            // not enough data
        #expect(StockSageIndicators.sma([1, 2, 3], period: 0) == nil)         // non-positive period
        #expect(StockSageIndicators.rsi([1, 2, 3]) == nil)                    // count < default period
        #expect(StockSageIndicators.rsi((1...14).map(Double.init)) == nil)    // count == period (needs > )
        #expect(StockSageIndicators.macd((1...34).map(Double.init)) == nil)   // < slow+signal (35)
        #expect(StockSageIndicators.macd((1...40).map(Double.init)) != nil)   // just enough
        // ATR rejects mismatched array lengths even when long enough.
        let n20 = Array(repeating: 1.0, count: 20)
        let n19 = Array(repeating: 1.0, count: 19)
        #expect(StockSageIndicators.atr(highs: n19, lows: n20, closes: n20) == nil)
        #expect(StockSageIndicators.efficiencyRatio([1, 2, 3], period: 20) == nil)
        #expect(StockSageIndicators.annualizedVolatility([1]) == nil)
        #expect(StockSageIndicators.returnOverPeriod([1, 2], period: 5) == nil)
    }
}

// MARK: - Advisor (what / when / how much / when-to-sell)

struct StockSageAdvisorTests {

    @Test func shortHistoryHoldsWithNoSize() {
        let a = StockSageAdvisor.advise(closes: [1, 2, 3])
        #expect(a.action == .hold)
        #expect(a.conviction == 0)
        #expect(a.suggestedWeight == 0)
        #expect(a.stopPrice == nil)
    }

    @Test func cleanUptrendIsABuyWithStopTargetAndSize() {
        let closes = (1...250).map(Double.init)
        let a = StockSageAdvisor.advise(closes: closes)
        #expect(a.action == .strongBuy)
        #expect(a.conviction > 0.5)
        #expect(a.regime == .bullTrend)
        #expect(a.suggestedWeight > 0)
        if let stop = a.stopPrice, let target = a.targetPrice {
            #expect(stop < 250)
            #expect(target > 250)
        } else {
            Issue.record("uptrend should produce a stop and target")
        }
    }

    @Test func cleanDowntrendIsASellWithNoLongSize() {
        let closes = (1...250).reversed().map(Double.init)
        let a = StockSageAdvisor.advise(closes: closes)
        #expect(a.action == .sell)
        #expect(a.suggestedWeight == 0)          // no long-side size on a downtrend
        #expect(a.stopPrice == nil)
    }

    @Test func positionSizeIsHardCapped() {
        // A very tight ATR stop would size huge; the cap must clamp it to maxWeight.
        let closes = (1...250).map(Double.init)
        let highs = closes.map { $0 + 1 }
        let lows  = closes.map { $0 - 1 }
        let a = StockSageAdvisor.advise(closes: closes, highs: highs, lows: lows)
        #expect(a.suggestedWeight == StockSageAdvisor.maxWeight)
    }

    @Test func everyAdviceCarriesTheHonestCaveat() {
        let a = StockSageAdvisor.advise(closes: (1...60).map(Double.init))
        #expect(a.caveat.contains("not a guarantee"))
    }

    /// Regression for the review fix: 50–200 bars has a real 50DMA but no true
    /// 200DMA, so the trend term uses the lighter 50DMA-only read (not a fake 200DMA).
    @Test func shortHistoryUsesFiftyDMAOnlyBranch() {
        let a = StockSageAdvisor.advise(closes: (1...120).map(Double.init))
        #expect(a.action == .buy || a.action == .strongBuy)
        #expect(a.rationale.contains { $0.contains("50DMA") })
    }
}
