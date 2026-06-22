import Testing
import Foundation
@testable import Salehman_AI

// MARK: - Portfolio risk analytics (pure)

struct StockSagePortfolioAnalyticsTests {

    typealias PA = StockSagePortfolioAnalytics

    @Test func dailyReturnsComputeCorrectly() {
        let r = PA.dailyReturns([100, 110, 99])
        #expect(r.count == 2)
        #expect(abs(r[0] - 0.10) < 1e-9)     // +10%
        #expect(abs(r[1] + 0.10) < 1e-9)     // −10%
    }

    @Test func maxDrawdownIsPeakToTrough() {
        // equity: 1.1 → 1.21 → 0.605 → DD = (1.21−0.605)/1.21 = 0.5
        #expect(abs(PA.maxDrawdown([0.1, 0.1, -0.5]) - 0.5) < 1e-9)
        #expect(PA.maxDrawdown([0.01, 0.01, 0.01]) == 0)   // monotonic up → no drawdown
    }

    @Test func correlationExtremes() {
        #expect(abs(PA.correlation([0.1, 0.2, 0.3], [0.1, 0.2, 0.3]) - 1) < 1e-9)
        #expect(abs(PA.correlation([0.1, -0.1, 0.1, -0.1], [-0.1, 0.1, -0.1, 0.1]) + 1) < 1e-9)
    }

    @Test func averageCorrelationOfSingleHoldingIsOne() {
        #expect(PA.averageCorrelation([[0.1, 0.2, 0.3]]) == 1)          // concentrated
        #expect(abs(PA.averageCorrelation([[0.1, 0.2], [0.1, 0.2]]) - 1) < 1e-9)
    }

    @Test func percentileNearestRank() {
        #expect(PA.percentile([1, 2, 3, 4, 5], 0.0) == 1)
        #expect(PA.percentile([1, 2, 3, 4, 5], 1.0) == 5)
    }

    @Test func computeRejectsTooLittleHistory() {
        #expect(PA.compute(holdings: [(1.0, [100, 101, 102])]) == nil)   // 2 returns < 5
        #expect(PA.compute(holdings: []) == nil)
    }

    @Test func computeReturnsSuiteWithCorrectMetadata() {
        let rising = (0..<12).map { 100.0 + Double($0) }
        let a = PA.compute(holdings: [(1000, rising), (1000, rising)])
        #expect(a != nil)
        #expect(a?.holdingsAnalyzed == 2)
        #expect(a?.observations == 11)                  // 12 closes → 11 returns
        #expect(abs((a?.avgCorrelation ?? 0) - 1) < 1e-6)   // identical → fully correlated
        #expect((a?.diversificationScore ?? 100) < 20)      // two identical names = poorly diversified
        #expect(a?.maxDrawdown == 0)                    // monotonic up
    }

    @Test func ratioMetricsAreConsistentWithTheirComponents() {
        // Single holding → portfolio returns == its daily returns, so the ratio
        // metrics can be pinned against the public helpers (no magic annualized
        // numbers). Guards the Sharpe/Sortino/Calmar/VaR formulas from regression.
        let closes: [Double] = [100, 110, 105, 115, 108, 120, 112, 118]   // up & down days
        let a = PA.compute(holdings: [(1000, closes)])!
        let rets = PA.dailyReturns(closes)

        #expect(abs(a.maxDrawdown - PA.maxDrawdown(rets) * 100) < 1e-6)
        #expect(abs(a.valueAtRisk95 - max(0, -PA.percentile(rets, 0.05) * 100)) < 1e-6)
        #expect(a.annualizedVolatility > 0)
        #expect(abs(a.sharpe - a.annualizedReturn / a.annualizedVolatility) < 1e-6)
        #expect(a.maxDrawdown > 0)
        #expect(abs(a.calmar - a.annualizedReturn / a.maxDrawdown) < 1e-6)
        // Sortino's downside deviation is normalized over ALL observations (the fix);
        // reverting to ÷down-day-count would break this.
        let n = Double(rets.count)
        let downSq = rets.reduce(0.0) { $0 + min($1, 0) * min($1, 0) }
        let downDev = (downSq / n).squareRoot() * (252.0).squareRoot() * 100
        #expect(downDev > 0)
        #expect(abs(a.sortino - a.annualizedReturn / downDev) < 1e-6)
    }

    @Test func correlationMatrixIsSymmetricWithUnitDiagonal() {
        let a: [Double] = [0.1, 0.2, 0.3]
        let b: [Double] = [-0.1, -0.2, -0.3]            // perfectly anti-correlated with a
        let m = PA.correlationMatrix([a, b])
        #expect(m.count == 2 && m[0].count == 2)
        #expect(m[0][0] == 1 && m[1][1] == 1)           // unit diagonal
        #expect(abs(m[0][1] - m[1][0]) < 1e-12)         // symmetric
        #expect(abs(m[0][1] + 1) < 1e-9)                // a vs b = −1
        #expect(PA.correlationMatrix([[0.1, 0.2]]) == [[1.0]])   // single series → identity
    }

    @Test func antiCorrelatedHoldingsScoreWellDiversified() {
        let a: [Double] = [100, 110, 100, 110, 100, 110, 100]   // alternating
        let b: [Double] = [110, 100, 110, 100, 110, 100, 110]   // opposite phase
        let r = PA.compute(holdings: [(1000, a), (1000, b)])
        #expect(r != nil)
        #expect((r?.avgCorrelation ?? 1) < -0.9)        // strongly anti-correlated
        #expect((r?.diversificationScore ?? 0) > 70)    // genuine diversification
    }
}
