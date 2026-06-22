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
}
