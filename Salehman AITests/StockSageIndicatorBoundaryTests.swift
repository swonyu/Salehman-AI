import Testing
import Foundation
@testable import Salehman_AI

// MARK: - Indicator nil-boundary (F05 off-by-one companion)
//
// StockSageIndicatorsTests pins macd() nil at 34 bars but nothing pinned non-nil AT exactly
// 35 (= slow 26 + signal 9), so an off-by-one to `>= 36` would pass silently. macd feeds the
// advisor's ±0.10 MACD term (a money-relevant signal), so the exact minimum is worth pinning.

struct StockSageIndicatorBoundaryTests {

    typealias I = StockSageIndicators

    // macd minimum = slow(26) + signalPeriod(9) = 35 bars (StockSageIndicators.swift:70).
    // Rising (non-flat) series so flatness can't be what returns nil — isolating the COUNT guard.
    @Test func macdComputesAtExactly35Bars() {
        let rising35 = (0..<35).map { 100.0 + Double($0) }
        #expect(I.macd(rising35) != nil)     // exactly 35 → non-nil; an off-by-one to `>= 36` fails HERE
        let rising34 = (0..<34).map { 100.0 + Double($0) }
        #expect(I.macd(rising34) == nil)     // 34 (non-flat) → nil: the COUNT guard, not flatness
    }
}
