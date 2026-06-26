import Testing
import Foundation
@testable import Salehman_AI

// MARK: - Capital allocator (pure) — half-Kelly, edge-weighted, heat-capped.
// All literals python-verified (halfKelly fraction, whole-share floor, heat cap).

struct StockSageCapitalAllocatorTests {
    typealias Alloc = StockSageCapitalAllocator

    private func idea(_ symbol: String, price: Double, stop: Double, target: Double,
                      conviction: Double, action: TradeAdvice.Action = .buy) -> StockSageIdea {
        StockSageIdea(symbol: symbol, market: "TEST", price: price,
                      advice: TradeAdvice(action: action, conviction: conviction, regime: .bullTrend,
                                          rationale: [], stopPrice: stop, targetPrice: target,
                                          suggestedWeight: 0, caveat: "x"),
                      spark: [])
    }

    @Test func halfKellyIsAFractionNotDividedByAccount() {
        // conviction 0.5, 100/90/130 (payoff 3, p 0.465) → half-Kelly 0.14333…; account 10k,
        // maxHeat 0.50 (no scaling) → 143 shares, $1430 at risk. (python-verified)
        let a = Alloc.allocate(ideas: [idea("AAPL", price: 100, stop: 90, target: 130, conviction: 0.5)],
                               account: 10_000, maxHeat: 0.50)
        #expect(a.positions.count == 1)
        #expect(abs(a.positions[0].halfKelly - 0.1433333333) < 1e-6)
        #expect(abs(a.positions[0].riskFraction - 0.1433333333) < 1e-6)   // no scaling under the cap
        #expect(abs(a.scaleApplied - 1.0) < 1e-9)
        #expect(a.positions[0].shares == 143)
        #expect(abs(a.positions[0].dollarsAtRisk - 1430) < 1e-9)
        // Whole-share floor keeps realized risk ≤ the scaled target.
        #expect(a.positions[0].dollarsAtRisk <= a.positions[0].riskFraction * 10_000 + 1e-9)
    }

    @Test func capBindsAndTotalHeatNeverExceedsMax() {
        // Three high-conviction 6:1 buys (each half-Kelly ≈ 0.2416, Σ ≈ 0.725 ≫ 0.08).
        let ideas = [idea("AAA", price: 100, stop: 90,  target: 160, conviction: 0.9),
                     idea("BBB", price: 50,  stop: 45,  target: 80,  conviction: 0.9),
                     idea("CCC", price: 200, stop: 180, target: 320, conviction: 0.9)]
        let a = Alloc.allocate(ideas: ideas, account: 100_000, maxHeat: 0.08)
        #expect(a.positions.count == 3)
        #expect(a.scaleApplied < 1.0)                              // the cap bound
        #expect(a.totalHeat <= 0.08 + 1e-9)                        // realized heat never exceeds the cap
        #expect(abs(a.totalHeat - 0.07985) < 1e-4)                 // python-verified
        #expect(a.positions.allSatisfy { $0.shares > 0 })
        #expect(abs(a.maxHeat - 0.08) < 1e-9)
        // Deterministic order: desc by riskFraction (ties broken by symbol).
        #expect(zip(a.positions, a.positions.dropFirst()).allSatisfy { $0.riskFraction >= $1.riskFraction })
    }

    @Test func noSinglePositionExceedsTheKellyCap() {
        // A lone very-strong idea (raw half-Kelly ≈ 0.28 > 0.20) under a generous maxHeat must
        // still be capped at Kelly's 20% per-position limit — not sit at ~half-Kelly (up to 50%).
        let a = Alloc.allocate(ideas: [idea("AAA", price: 100, stop: 90, target: 400, conviction: 0.99)],
                               account: 100_000, maxHeat: 0.50)
        #expect(a.positions.count == 1)
        #expect(a.positions[0].riskFraction <= 0.20 + 1e-9)   // capped, not up to 0.50
        #expect(a.positions[0].halfKelly > 0.20)              // raw half-Kelly WAS above the cap (transparency)
    }

    @Test func unscaledWhenRequestedHeatBelowCap() {
        // A weak-edge buy whose half-Kelly is under the cap → no scaling, riskFraction == halfKelly.
        let a = Alloc.allocate(ideas: [idea("LOW", price: 100, stop: 95, target: 110, conviction: 0.3)],
                               account: 10_000, maxHeat: 0.08)
        #expect(a.positions.count == 1)
        #expect(abs(a.scaleApplied - 1.0) < 1e-9)
        #expect(abs(a.positions[0].riskFraction - a.positions[0].halfKelly) < 1e-12)
    }

    @Test func allocatorVolTargetsHighVolNames() {
        func ideaVol(_ vol: Double?) -> StockSageIdea {
            StockSageIdea(symbol: "X", market: "M", price: 100,
                          advice: TradeAdvice(action: .buy, conviction: 0.6, regime: .bullTrend, rationale: [],
                                              stopPrice: 90, targetPrice: 130, suggestedWeight: 0, caveat: "x"),
                          spark: [], dailyMove: nil, realizedVol: vol)
        }
        func rf(_ vol: Double?) -> Double {
            Alloc.allocate(ideas: [ideaVol(vol)], account: 100_000, maxHeat: 0.5).positions.first?.riskFraction ?? 0
        }
        let calm = rf(0.15)       // ≤ 0.20 baseline → scaler 1 → no shrink
        #expect(calm > 0)
        #expect(rf(nil) == calm)  // no vol known → no shrink
        #expect(rf(0.80) < calm * 0.5)   // 0.80/0.20 = 4× → ~quarter the deployed risk
    }

    @Test func regimeSizingBiasScalesTheBook() {
        let i = idea("LOW", price: 100, stop: 95, target: 110, conviction: 0.3)
        func regime(_ bias: Double, _ state: MarketRegime.State) -> MarketRegime {
            MarketRegime(state: state, riskScore: 0, signals: [], sizingBias: bias, caveat: "x")
        }
        func rf(_ r: MarketRegime?) -> Double {
            Alloc.allocate(ideas: [i], account: 100_000, maxHeat: 0.5, regime: r).positions.first?.riskFraction ?? 0
        }
        let baseline = rf(nil)
        #expect(baseline > 0)
        #expect(rf(regime(1.25, .trendingBull)) > baseline)   // strong bull sizes the book up
        #expect(rf(regime(0.25, .crisis)) < baseline)         // risk-off sizes it down
        let crisis = Alloc.allocate(ideas: [i], account: 100_000, maxHeat: 0.5, regime: regime(0.25, .crisis))
        #expect(crisis.caveat.contains("Sized ×0.25"))
    }

    @Test func excludesNetNegativeAfterCostSetups() {
        // Same thin geometry, two cost regimes. A crypto flip (~70bps round-trip) that's +EV on GROSS
        // but net-negative after costs must NOT be deployed (mirrors the boards' cost gate)…
        let crypto = idea("X-USD", price: 100, stop: 99, target: 101.5, conviction: 0.6)
        #expect(Alloc.allocate(ideas: [crypto], account: 100_000, maxHeat: 0.5).positions.isEmpty)
        // …while the same setup on a low-cost large-cap (13bps) clears and funds.
        let equity = idea("AAPL", price: 100, stop: 99, target: 101.5, conviction: 0.6)
        #expect(!Alloc.allocate(ideas: [equity], account: 100_000, maxHeat: 0.5).positions.isEmpty)
    }

    @Test func excludesNonBuyAndNonPositiveEVAndInvalidInputs() {
        let sell = idea("SELL", price: 100, stop: 110, target: 80, conviction: 0.9, action: .sell)
        let noEV = idea("FLAT", price: 100, stop: 99, target: 100.5, conviction: 0.0)   // tiny reward, EV ≤ 0
        #expect(Alloc.allocate(ideas: [sell, noEV], account: 10_000).positions.isEmpty)
        // Invalid account/heat → empty plan, never a crash.
        #expect(Alloc.allocate(ideas: [idea("X", price: 100, stop: 90, target: 130, conviction: 0.8)],
                               account: 0).positions.isEmpty)
        #expect(Alloc.allocate(ideas: [], account: 10_000).positions.isEmpty)
    }
}
