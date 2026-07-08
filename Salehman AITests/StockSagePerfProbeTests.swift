import Testing
import Foundation
@testable import Salehman_AI

// MARK: - PLAN_2026-07-08_equity2000 Stage 3 — perf probe at n≈2,400
//
// Builds a deterministic ~2,400-idea synthetic set (SageFix.idea, no RNG) and MEASURES
// wall time of the displayedIdeas-equivalent work: rankByVelocity (the default sort's
// decorate-sort path), ×3 to simulate a hover-render worst case (three re-sorts of the
// same board — e.g. body re-evaluated on hover state changes). This is a MEASUREMENT,
// not a spec fixture — the assertion is a generous regression-catcher bound, not a
// timing pin (ponytail: no memoization added unless the number crosses ~30ms/sort —
// our dropped-frame operationalization of the plan's "if a keystroke-lag shows"
// criterion, not a number the plan itself names; see DEVELOPMENT_LOG for the branch taken).
struct StockSagePerfProbeTests {

    /// ~2,400 synthetic ideas: conviction/stop/target/class (via symbol pattern) vary
    /// across the set via a deterministic loop (no RNG — reproducible byte-for-byte).
    private func syntheticIdeas(count: Int = 2_400) -> [StockSageIdea] {
        let actions: [TradeAdvice.Action] = [.strongBuy, .buy, .hold, .reduce, .sell]
        let regimes: [TradeAdvice.Regime] = [.bullTrend, .bearTrend, .range]
        // Symbol suffix rotates through equity/Saudi/crypto-shaped tickers so the set
        // isn't monotonically one asset class (mirrors the mixed worldwide universe).
        let suffixes = ["", ".SR", "-USD"]
        return (0..<count).map { i in
            let conviction = Double(i % 100) / 100.0                         // 0.00...0.99 cycling
            let action = actions[i % actions.count]
            let regime = regimes[i % regimes.count]
            let price = 10.0 + Double(i % 500)                               // varied price levels
            let riskDistance = 1.0 + Double(i % 20) * 0.5                    // varied stop distance
            let suffix = suffixes[i % suffixes.count]
            return SageFix.idea("SYM\(i)\(suffix)", conviction: conviction, action: action,
                                regime: regime, rr: 1.5 + Double(i % 5) * 0.5,
                                price: price, riskDistance: riskDistance)
        }
    }

    @Test func rankByVelocityAt2400ScaleIsWithinSanityBound() {
        let ideas = syntheticIdeas()
        #expect(ideas.count == 2_400)

        let clock = ContinuousClock()
        // ×3 to simulate a hover-render worst case (displayedIdeas re-evaluated
        // multiple times per interaction burst).
        let elapsed = clock.measure {
            for _ in 0..<3 {
                _ = StockSageExpectedValue.rankByVelocity(ideas)
            }
        }
        let totalMs = Double(elapsed.components.seconds) * 1_000
            + Double(elapsed.components.attoseconds) / 1e15
        let perSortMs = totalMs / 3

        print("[PERF] rankByVelocity ×3 at n=\(ideas.count): total \(totalMs)ms, per-sort \(perSortMs)ms")

        // Generous sanity bound — a regression catcher (e.g. an accidental O(n²) path),
        // NOT a flaky timing pin. See DEVELOPMENT_LOG for the measured number and the
        // memoization decision it drove.
        //
        // MEASURED (Debug build, .dd-isolated, 5 runs): per-sort ≈16.7–18.3ms at n=2,400 —
        // under the ~30ms/sort line (our dropped-frame operationalization of the plan's
        // keystroke-lag criterion). Adversarial worst case (independent review measurement,
        // all-buy-family mix so every idea pays the NetEdge evals): ≈24.8–26.1ms/sort —
        // still under, but the margin to re-check if the universe grows again.
        // DECISION: memoization NOT justified — the honest null. displayedIdeas is left
        // unmemoized; ship the probe only (PLAN_2026-07-08_equity2000 Stage 3).
        #expect(totalMs < 5_000)
    }
}
