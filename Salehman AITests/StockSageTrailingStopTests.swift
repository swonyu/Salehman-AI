import Testing
import Foundation
@testable import Salehman_AI

// MARK: - ATR trailing stop (pure)

struct StockSageTrailingStopTests {

    typealias TS = StockSageTrailingStop

    @Test func recomputeRatchetsUpOnlyAndStaysUsable() {
        // Clean uptrend, entered at bar 15. The ratcheted Chandelier level is below the last close
        // and positive (a usable stop).
        let upH = (0..<40).map { 100.0 + Double($0) }
        let upL = upH.map { $0 - 2 }, upC = upH.map { $0 - 0.5 }
        let atPeak = TS.recompute(highs: upH, lows: upL, closes: upC, entryIndex: 15)
        #expect(atPeak != nil)
        if let a = atPeak { #expect(a.level > 0 && a.level < upC.last!) }
        // Extend with a SHALLOW pullback that stays above the stop → the stop must NOT drop (up-only).
        let pbH = upH + (1...3).map { upH.last! - Double($0) }
        let pbL = pbH.map { $0 - 2 }, pbC = pbH.map { $0 - 0.5 }
        let after = TS.recompute(highs: pbH, lows: pbL, closes: pbC, entryIndex: 15)
        if let a = atPeak, let b = after { #expect(b.level >= a.level - 1e-9) }   // ratchet held
        // A DEEP pullback that drops price through the trail → no usable stop (you should be out).
        let deepH = upH + (1...10).map { upH.last! - Double($0) }
        let deepL = deepH.map { $0 - 2 }, deepC = deepH.map { $0 - 0.5 }
        #expect(TS.recompute(highs: deepH, lows: deepL, closes: deepC, entryIndex: 15) == nil)
        // Guards: entry at the last bar (no bar after) and out-of-range → nil.
        #expect(TS.recompute(highs: upH, lows: upL, closes: upC, entryIndex: 39) == nil)
        #expect(TS.recompute(highs: upH, lows: upL, closes: upC, entryIndex: 100) == nil)
    }

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
