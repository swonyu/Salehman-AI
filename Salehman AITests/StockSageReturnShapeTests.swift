import Testing
import Foundation
@testable import Salehman_AI

// MARK: - Downside-skew / left-tail read (pure)

struct StockSageReturnShapeTests {

    typealias RS = StockSageReturnShape

    /// Build a close series from a return series (start at 100), so we control returns directly.
    private func closes(fromReturns rets: [Double]) -> [Double] {
        var px = 100.0
        var out = [px]
        for r in rets { px *= (1 + r); out.append(px) }
        return out
    }

    // Symmetric returns → skew ≈ 0, isLeftTailed == false.
    @Test func symmetricReturnsHaveZeroSkewAndNoLeftTail() {
        // 40 returns alternating +1% / −1% → mean ≈ 0, distribution symmetric.
        let rets = (0..<40).map { $0 % 2 == 0 ? 0.01 : -0.01 }
        let shape = RS.returnShape(closes: closes(fromReturns: rets))
        let s = try! #require(shape)
        #expect(abs(s.skewness) < 0.2)
        #expect(s.isLeftTailed == false)
        #expect(!s.caveat.isEmpty)   // caveat-presence
    }

    // A few large NEGATIVE jumps among small positives → skew < 0, left-tailed,
    // downside95 > 0 and downside95 ≥ |median day|.
    @Test func negativeJumpsAmongSmallPositivesAreLeftTailed() {
        var rets = [Double](repeating: 0.002, count: 36)   // small positives
        rets[7] = -0.12; rets[18] = -0.15; rets[29] = -0.10   // a few big down-days
        let shape = RS.returnShape(closes: closes(fromReturns: rets))
        let s = try! #require(shape)
        #expect(s.skewness < 0)
        #expect(s.isLeftTailed == true)
        #expect(s.downside95 > 0)

        let sorted = rets.sorted()
        let medianDay = sorted[sorted.count / 2]
        #expect(s.downside95 >= abs(medianDay))   // spec: downside95 ≥ |median day|
        #expect(!s.caveat.isEmpty)   // caveat-presence
    }

    // <30 returns → nil.  (29 returns = 30 closes.)
    @Test func tooFewReturnsReturnsNil() {
        let rets29 = [Double](repeating: 0.001, count: 29)
        #expect(RS.returnShape(closes: closes(fromReturns: rets29)) == nil)
        #expect(RS.returnShape(closes: [100, 101, 102]) == nil)
        #expect(RS.returnShape(closes: []) == nil)
    }

    // F05-pattern count-boundary straddle for `guard returns.count >= 30` (StockSageReturnShape.swift:49).
    // The existing test above pins nil BELOW the minimum but nothing pinned non-nil AT it, so an off-by-one
    // to `>= 31`/`> 30` would pass silently. Fixtures carry a non-flat spread (rets[0] = -0.03) so sd > 0 —
    // the SECOND guard (line 57) can't be what flips nil, isolating the COUNT guard. The helper inverts
    // dailyReturns (N returns -> N+1 closes). Derived independently in
    // scratchpad/derive_returnshape_boundary.swift: 29 returns -> nil · 30 returns -> non-nil (sd 0.00574 > 0).
    @Test func returnShapeCountBoundaryStraddlesThirty() {
        var rets29 = [Double](repeating: 0.002, count: 29); rets29[0] = -0.03
        #expect(RS.returnShape(closes: closes(fromReturns: rets29)) == nil)   // below min -> nil (COUNT, not sd)
        var rets30 = [Double](repeating: 0.002, count: 30); rets30[0] = -0.03
        let atMin = RS.returnShape(closes: closes(fromReturns: rets30))
        #expect(atMin != nil)   // exactly at the minimum -> non-nil; off-by-one to `>= 31`/`> 30` fails HERE
    }

    // Invariants: downside95 non-negative; worstDay ≤ −downside95 (most-negative ≤ the threshold).
    @Test func downsideInvariantsHold() {
        var rets = [Double](repeating: 0.003, count: 35)
        rets[10] = -0.08; rets[25] = -0.11
        let s = try! #require(RS.returnShape(closes: closes(fromReturns: rets)))
        #expect(s.downside95 >= 0)                          // non-negative
        #expect(s.worstDay <= -s.downside95 + 1e-12)        // min(returns) ≤ −percentile(0.05)
    }
}
