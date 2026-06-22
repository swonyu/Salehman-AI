import Foundation

// MARK: - Cost-aware R:R (net edge after frictions)
//
// Gross reward:risk flatters every trade — it ignores the spread you cross twice, slippage,
// and commission. On a wide 4:1 setup the costs barely register; on a thin, high-turnover
// flip they can eat the entire edge. This nets them out: round-trip cost shrinks the reward
// AND widens the risk, so the NET R:R is what you actually trade. Pure + deterministic.
// Honest: the cost inputs are ESTIMATES — your real spread/slippage will differ.

struct NetEdge: Sendable, Equatable {
    let grossRR: Double
    let netRR: Double               // after round-trip costs (can be ≤0 if costs exceed the target)
    let costPerShare: Double
    let costAsPctOfReward: Double    // round-trip cost ÷ gross reward (0–1+)
    let netExpectancyR: Double?      // per 1R of gross risk, if a win probability was supplied
    /// The win rate you must BEAT to be positive-EV AFTER costs: p* = 1/(1+netRR). It turns
    /// the cost model into a single falsifiable bar — if your honest hit rate is below this,
    /// the setup loses money no matter how good the gross R:R looks. nil when netRR ≤ 0 (no
    /// win rate profits — costs exceed the target).
    let breakEvenWinRate: Double?
    let verdict: String
    nonisolated var costErodesEdge: Bool { netRR < 1 || costAsPctOfReward > 0.33 }
    /// Does an estimated win probability clear the after-cost break-even bar? Strictly beats
    /// it; false when the setup is unprofitable at any win rate (breakEvenWinRate nil).
    nonisolated func clearsCost(estWinProb: Double) -> Bool {
        guard let p = breakEvenWinRate else { return false }
        return estWinProb > p
    }
}

enum StockSageNetEdge {
    /// A LABELED, asset-class default cost assumption — crypto and thin foreign listings
    /// carry far wider spreads than US large-caps or FX majors. Estimates, not quotes.
    struct CostAssumption: Sendable, Equatable {
        let spreadBps: Double
        let slippageBps: Double
        let assetClass: String
        nonisolated var roundTripBps: Double { spreadBps + slippageBps }
    }

    /// Pick a sensible round-trip cost estimate from the symbol's asset class (suffix).
    /// Crypto widest, FX majors tightest; foreign single-listings wider than US large-caps.
    nonisolated static func defaultCosts(forSymbol symbol: String) -> CostAssumption {
        let s = symbol.uppercased()
        if s.hasSuffix("-USD") { return CostAssumption(spreadBps: 30, slippageBps: 20, assetClass: "crypto") }      // 50bps
        if s.hasSuffix("=X")   { return CostAssumption(spreadBps: 4,  slippageBps: 3,  assetClass: "FX") }          // 7bps
        if s.hasPrefix("^")    { return CostAssumption(spreadBps: 5,  slippageBps: 3,  assetClass: "index") }       // 8bps
        if s.contains(".")     { return CostAssumption(spreadBps: 20, slippageBps: 10, assetClass: "intl") }        // 30bps
        return CostAssumption(spreadBps: 8, slippageBps: 5, assetClass: "US large-cap")                             // 13bps
    }

    /// Net reward:risk after round-trip frictions. Works for longs and shorts (uses absolute
    /// distances). `spreadBps`/`slippageBps` are round-trip, in bps of entry price;
    /// `commissionPerShare` is absolute. nil if the gross setup is degenerate.
    nonisolated static func evaluate(entry: Double, stop: Double, target: Double,
                                     spreadBps: Double = 0, slippageBps: Double = 0,
                                     commissionPerShare: Double = 0,
                                     winProb: Double? = nil) -> NetEdge? {
        let grossReward = abs(target - entry)
        let grossRisk = abs(entry - stop)
        guard grossReward > 0, grossRisk > 0, entry > 0 else { return nil }

        let cost = Swift.max(0, spreadBps + slippageBps) / 10_000 * entry + Swift.max(0, commissionPerShare)
        let netReward = grossReward - cost
        let netRisk = grossRisk + cost
        let grossRR = grossReward / grossRisk
        let netRR = netReward / netRisk
        let costPct = cost / grossReward

        let netExpR: Double? = winProb.map { p in
            let pp = Swift.min(1, Swift.max(0, p))
            return (pp * netReward - (1 - pp) * netRisk) / grossRisk
        }

        let verdict: String
        if netRR <= 0 { verdict = "Costs exceed the target — don't take this." }
        else if netRR < 1 { verdict = "After costs R:R < 1 — skip." }
        else if costPct > 0.33 { verdict = "Costs eat \(Int((costPct * 100).rounded()))% of the target — thin." }
        else { verdict = "Costs take \(Int((costPct * 100).rounded()))% of the target — acceptable." }

        // The win rate that just breaks even after costs (nil if no win rate can profit).
        let breakEven: Double? = netRR > 0 ? 1 / (1 + netRR) : nil

        return NetEdge(grossRR: grossRR, netRR: netRR, costPerShare: cost,
                       costAsPctOfReward: costPct, netExpectancyR: netExpR,
                       breakEvenWinRate: breakEven, verdict: verdict)
    }
}
