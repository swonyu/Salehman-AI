import Testing
import Foundation
@testable import Salehman_AI

// MARK: - ATR trailing stop (pure)

struct StockSageTrailingStopTests {

    typealias TS = StockSageTrailingStop

    @Test func longTrailingStopIsHighestHighMinusKAtr() {
        // 20 bars, each high 101 / low 99 / close 100 → every TR = 2 → ATR = 2,
        // highest high = 101 → Chandelier level = 101 − 3×2 = 95.
        let n = 20
        let closes = Array(repeating: 100.0, count: n)
        let highs = Array(repeating: 101.0, count: n)
        let lows = Array(repeating: 99.0, count: n)
        let t = TS.suggest(highs: highs, lows: lows, closes: closes, multiple: 3, period: 14)!
        #expect(abs(t.atr - 2) < 1e-9)
        #expect(abs(t.level - 95) < 1e-9)        // 101 − 3×2
        #expect(abs(t.distancePct - 5) < 1e-9)   // (100 − 95) / 100
        #expect(t.level < 100)                   // a trailing stop sits below price
        #expect(t.multiple == 3)
    }

    @Test func widerMultipleGivesMoreRoom() {
        let n = 20
        let closes = Array(repeating: 100.0, count: n)
        let highs = Array(repeating: 101.0, count: n)
        let lows = Array(repeating: 99.0, count: n)
        let tight = TS.suggest(highs: highs, lows: lows, closes: closes, multiple: 2)!
        let wide  = TS.suggest(highs: highs, lows: lows, closes: closes, multiple: 4)!
        #expect(tight.level == 97)   // 101 − 2×2
        #expect(wide.level == 93)    // 101 − 4×2
        #expect(wide.level < tight.level)
    }

    @Test func tooShortHistoryIsNil() {
        #expect(TS.suggest(highs: [101, 102], lows: [99, 100], closes: [100, 101]) == nil)
    }

    @Test func levelThatWouldGoNonPositiveIsNil() {
        // Huge multiple drives the level below 0 → nil, not a negative stop.
        let n = 20
        let closes = Array(repeating: 100.0, count: n)
        let highs = Array(repeating: 101.0, count: n)
        let lows = Array(repeating: 99.0, count: n)
        #expect(TS.suggest(highs: highs, lows: lows, closes: closes, multiple: 60) == nil)  // 100 − 60×2 < 0
    }
}
