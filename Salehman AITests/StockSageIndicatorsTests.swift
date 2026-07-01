import Testing
import Foundation
@testable import Salehman_AI

// MARK: - Technical indicators (pure) — the foundation every signal rests on.
// All literals hand-verified; see the per-test comments for the derivation.

struct StockSageIndicatorsTests {
    typealias I = StockSageIndicators

    @Test func smaAveragesLastPeriod() {
        #expect(I.sma([1, 2, 3, 4, 5], period: 3)! == 4)     // (3+4+5)/3
        #expect(I.sma([1, 2], period: 3) == nil)             // not enough data
        #expect(I.sma([], period: 1) == nil)
    }

    @Test func emaSeedsWithSMAThenSmooths() {
        // period 2 (k=2/3): seed (1+2)/2 = 1.5; →3·⅔+1.5·⅓ = 2.5; →4·⅔+2.5·⅓ = 3.5.
        let s = I.emaSeries([1, 2, 3, 4], period: 2)
        #expect(s.count == 3)
        #expect(abs(s[0] - 1.5) < 1e-9)
        #expect(abs(s[1] - 2.5) < 1e-9)
        #expect(abs(s[2] - 3.5) < 1e-9)
        #expect(abs(I.ema([1, 2, 3, 4], period: 2)! - 3.5) < 1e-9)
        #expect(I.ema([1], period: 2) == nil)
    }

    @Test func rsiHitsExtremesAndMidpoint() {
        #expect(abs(I.rsi([1, 2, 3, 4], period: 2)! - 100) < 1e-9)   // all up → 100
        #expect(abs(I.rsi([5, 4, 3, 2], period: 2)! - 0) < 1e-9)     // all down → 0
        #expect(abs(I.rsi([5, 5, 5, 5], period: 2)! - 50) < 1e-9)    // flat → 50
        #expect(I.rsi([1, 2], period: 2) == nil)                     // count must exceed period
    }

    @Test func atrIsWilderTrueRange() {
        // len 3, period 2 → TR₁ max(3,3,0)=3, TR₂ max(2,0,2)=2 → (3+2)/2 = 2.5.
        let atr = I.atr(highs: [10, 12, 11], lows: [8, 9, 9], closes: [9, 11, 10], period: 2)!
        #expect(abs(atr - 2.5) < 1e-9)
        #expect(I.atr(highs: [1, 2], lows: [0, 1], closes: [1, 1], period: 2) == nil)  // n must exceed period
    }

    @Test func efficiencyRatioCleanTrendVsChop() {
        #expect(abs(I.efficiencyRatio([1, 2, 3, 4, 5], period: 4)! - 1) < 1e-9)   // monotonic → 1
        #expect(abs(I.efficiencyRatio([1, 2, 1, 2, 1], period: 4)! - 0) < 1e-9)   // round-trip → 0 (net 0)
    }

    @Test func returnOverPeriodIsPercent() {
        #expect(abs(I.returnOverPeriod([100, 105, 110], period: 2)! - 10) < 1e-9)  // (110−100)/100·100
        #expect(I.returnOverPeriod([100, 110], period: 2) == nil)                  // count must exceed period
    }

    @Test func annualizedVolatilityFromLogReturns() {
        // closes [100,110,100]: rets ±ln(1.1), mean 0, var = 2·ln(1.1)²/(2−1); × √252.
        let v = I.annualizedVolatility([100, 110, 100])!
        let expected = (2 * pow(log(1.1), 2)).squareRoot() * Double(252).squareRoot()
        #expect(abs(v - expected) < 1e-9)
        #expect(I.annualizedVolatility([100, 110]) == nil)   // needs ≥3 closes
    }

    @Test func macdHistogramIsMacdMinusSignalAndGuardsShortData() {
        #expect(I.macd(Array(repeating: 1.0, count: 34)) == nil)   // < slow+signal (26+9=35)
        let closes = (0..<60).map { 100.0 + Double($0) }           // steady ramp, enough data
        let m = I.macd(closes)!
        #expect(abs(m.histogram - (m.macd - m.signal)) < 1e-9)     // histogram is defined as macd − signal
    }

    @Test func volumeConfirmationComparesRecentToPriorRealVolume() {
        let closes = (0..<25).map { Double($0) }                    // 25 bars (content irrelevant)
        // 22 bars at 100 then 3 at 200: prior-20 avg = 100, recent-3 avg = 200 → ratio 2.0.
        let surge = Array(repeating: 100.0, count: 22) + Array(repeating: 200.0, count: 3)
        let up = I.volumeConfirmation(closes: closes, volumes: surge)!
        #expect(abs(up.ratio - 2.0) < 1e-9)
        #expect(up.confirmed)                                       // ≥1 → above-average participation
        // 22 at 100 then 3 at 50 → recent avg 50 / prior 100 = 0.5 → not confirmed.
        let fade = Array(repeating: 100.0, count: 22) + Array(repeating: 50.0, count: 3)
        let down = I.volumeConfirmation(closes: closes, volumes: fade)!
        #expect(abs(down.ratio - 0.5) < 1e-9)
        #expect(!down.confirmed)
        // No real volume (FX/index) → nil, never a fabricated ratio.
        #expect(I.volumeConfirmation(closes: closes, volumes: Array(repeating: 0.0, count: 25)) == nil)
        // Mismatched length and too-short series → nil (no decision, no crash).
        #expect(I.volumeConfirmation(closes: closes, volumes: Array(repeating: 1.0, count: 24)) == nil)
        #expect(I.volumeConfirmation(closes: Array(closes.prefix(10)),
                                     volumes: Array(repeating: 1.0, count: 10)) == nil)
    }

    @Test func relativeStrengthIsSymbolReturnMinusBenchmark() {
        // +30% symbol vs +10% benchmark over the window → RS +20pp (outperforming).
        #expect(abs(I.relativeStrength(symbolCloses: [100, 130], benchmarkCloses: [100, 110], period: 1)! - 20) < 1e-9)
        // Rising in absolute terms but LAGGING the index (+10% vs +30%) → RS −20 (laggard).
        #expect(I.relativeStrength(symbolCloses: [100, 110], benchmarkCloses: [100, 130], period: 1)! < 0)
        // Either series too short to measure the period → nil, never a fabricated number.
        #expect(I.relativeStrength(symbolCloses: [100, 130], benchmarkCloses: [100], period: 1) == nil)
        #expect(I.relativeStrength(symbolCloses: [100], benchmarkCloses: [100, 110], period: 1) == nil)
    }

    @Test func volAdjustedMomentumPrefersTheCalmerClimber() {
        let closes = (1...200).map(Double.init)            // identical % momentum for both
        // Same closes (⇒ same raw momentum), but the jumpy one has a much wider ATR.
        let calm  = I.volAdjustedMomentum(closes: closes, highs: closes.map { $0 + 0.5 }, lows: closes.map { $0 - 0.5 })!
        let jumpy = I.volAdjustedMomentum(closes: closes, highs: closes.map { $0 + 5 },   lows: closes.map { $0 - 5 })!
        #expect(calm > 0 && jumpy > 0)                     // same sign as raw (upward) momentum
        #expect(calm > jumpy)                              // lower ATR ⇒ higher risk-adjusted momentum
        // Insufficient bars → nil; a flat (zero-ATR) series → nil — never a fabricated score.
        let short = (1...10).map(Double.init)
        #expect(I.volAdjustedMomentum(closes: short, highs: short, lows: short) == nil)
        let flat = Array(repeating: 100.0, count: 200)
        #expect(I.volAdjustedMomentum(closes: flat, highs: flat, lows: flat) == nil)
    }

    @Test func timeSeriesMomentumSkipsTheRecentWindow() {
        let up = (1...30).map(Double.init)
        #expect((I.timeSeriesMomentum(up, lookback: 20, skipRecent: 5) ?? -1) > 0)
        let down = (1...30).reversed().map(Double.init)
        #expect((I.timeSeriesMomentum(down, lookback: 20, skipRecent: 5) ?? 1) < 0)
        // Rising over the lookback but DROPPING the last 5 bars → still positive (the skip works):
        // count 30, lookback 20, skip 5 → from closes[9]=10 to closes[24]=25 → +150%.
        let c = (1...25).map(Double.init) + [24.0, 22, 20, 18, 16]
        #expect(abs((I.timeSeriesMomentum(c, lookback: 20, skipRecent: 5) ?? 0) - 150) < 1e-9)
        #expect(I.trendOK(c, lookback: 20, skipRecent: 5) == true)
        #expect(I.trendOK(down, lookback: 20, skipRecent: 5) == false)
        #expect(I.timeSeriesMomentum(up, lookback: 40, skipRecent: 5) == nil)   // not enough bars
    }

    @Test func donchianChannelAndLookAheadFreeBreakout() {
        let highs = (1...30).map(Double.init)            // 1…30
        let lows  = highs.map { $0 - 0.5 }               // 0.5…29.5
        let ch = I.donchian(highs: highs, lows: lows, period: 20)!
        #expect(ch.upper == 30)                          // max of last 20 highs (11…30)
        #expect(ch.lower == 10.5)                        // min of last 20 lows (10.5…29.5)
        #expect(I.donchian(highs: Array(highs.prefix(10)), lows: Array(lows.prefix(10)), period: 20) == nil)
        // Look-ahead-free: channel built on bars [0..<i] (EXCLUDING bar i), then test close[i].
        let prior = I.donchian(highs: Array(highs.prefix(30)), lows: Array(lows.prefix(30)), period: 20)!
        #expect(I.isBreakout(price: 31, channel: prior))   // 31 > prior upper 30 → breakout
        #expect(!I.isBreakout(price: 29, channel: prior))  // below the band → no breakout
        #expect(!I.isBreakout(price: 30, channel: prior))  // equalling the band is NOT a breakout (strict >)
    }

    @Test func returnOverPeriodRejectsZeroPastPrice() {
        #expect(StockSageIndicators.returnOverPeriod([0, 100, 110], period: 2) == nil)
    }

    @Test func macdRejectsFastNotLessThanSlow() {
        let closes = (0..<60).map { 100.0 + Double($0) }
        #expect(StockSageIndicators.macd(closes, fast: 26, slow: 12) == nil)
        #expect(StockSageIndicators.macd(closes, fast: 12, slow: 12) == nil)
    }

    @Test func efficiencyRatioFlatPriceReturnsZero() {
        #expect(StockSageIndicators.efficiencyRatio([5.0, 5.0, 5.0, 5.0, 5.0], period: 3)! == 0.0)
    }

    @Test func emaSeriesRejectsPeriodZero() {
        #expect(StockSageIndicators.emaSeries([1, 2, 3], period: 0) == [])
    }

    @Test func rsiRejectsPeriodZero() {
        #expect(StockSageIndicators.rsi([1, 2, 3], period: 0) == nil)
    }

    @Test func atrRejectsPeriodZero() {
        #expect(StockSageIndicators.atr(highs: [10, 12, 11], lows: [8, 9, 9], closes: [9, 11, 10], period: 0) == nil)
    }

    @Test func efficiencyRatioRejectsPeriodZero() {
        #expect(StockSageIndicators.efficiencyRatio([1, 2, 3], period: 0) == nil)
    }

    @Test func returnOverPeriodRejectsPeriodZero() {
        #expect(StockSageIndicators.returnOverPeriod([100, 110], period: 0) == nil)
    }

    @Test func annualizedVolatilitySkipsZeroPrice() {
        #expect(StockSageIndicators.annualizedVolatility([100.0, 0, 110.0]) == nil)
        #expect(StockSageIndicators.annualizedVolatility([100.0, 100.0, 110.0]) != nil)
    }
}
