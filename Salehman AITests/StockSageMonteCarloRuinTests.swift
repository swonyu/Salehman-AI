import Testing
import Foundation
@testable import Salehman_AI

// MARK: - Monte-Carlo ruin / drawdown distribution (seeded, deterministic)

struct StockSageMonteCarloRuinTests {

    /// Long entry 100 / stop 90 (risk 10) → exit sets the R-multiple: 90→−1R, 105→+0.5R, 110→+1R.
    private func tr(_ exit: Double) -> TradeRecord {
        TradeRecord(symbol: "X", side: .long, entry: 100, stop: 90, target: nil,
                    shares: 10, openedAt: Date(timeIntervalSince1970: 0),
                    exitPrice: exit, closedAt: Date(timeIntervalSince1970: 100))
    }

    @Test func ruinDistributionIsHonestAndDeterministic() {
        // Too thin to resample honestly → nil (a 1-trade log can't manufacture a ruin number).
        #expect(StockSageMonteCarloRuin.simulate([tr(90)], riskFraction: 0.1, minTrades: 20) == nil)
        // 20 always-losing (−1R) trades at 10% risk → ruin is certain.
        let losers = Array(repeating: tr(90), count: 20)
        #expect(StockSageMonteCarloRuin.simulate(losers, riskFraction: 0.10, sims: 2000)?.pRuin == 1.0)
        // 20 always-winning (+0.5R) trades → never ruins.
        let winners = Array(repeating: tr(105), count: 20)
        #expect(StockSageMonteCarloRuin.simulate(winners, riskFraction: 0.10, sims: 2000)?.pRuin == 0.0)
        // Determinism: same seed → byte-identical result.
        let mix = (0..<24).map { tr($0 % 2 == 0 ? 110 : 90) }
        let a = StockSageMonteCarloRuin.simulate(mix, riskFraction: 0.02, sims: 1500, seed: 42)
        let b = StockSageMonteCarloRuin.simulate(mix, riskFraction: 0.02, sims: 1500, seed: 42)
        #expect(a == b)
        // More risk never lowers ruin; the 95th-pct drawdown is never below the median.
        let hi = StockSageMonteCarloRuin.simulate(mix, riskFraction: 0.10, sims: 1500, seed: 42)
        #expect((hi?.pRuin ?? 0) >= (a?.pRuin ?? 0))
        if let a { #expect(a.p95MaxDD >= a.medianMaxDD) }
        // The honesty caveat is present and names the i.i.d. limitation.
        #expect(StockSageMonteCarloRuin.caveat.lowercased().contains("independent"))
    }
}
