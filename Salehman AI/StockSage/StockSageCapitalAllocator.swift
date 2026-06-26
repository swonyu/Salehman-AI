import Foundation

// MARK: - Capital allocator (half-Kelly, edge-weighted, heat-capped)
//
// Turns a board of ranked ideas into a concrete "how much in each" plan by COMPOSING three
// already-tested engines — StockSageExpectedValue (fundability + edge), StockSageKelly (the
// per-idea fraction), and StockSagePositionSizer (whole shares). No new financial math.
// Total open heat is HARD-CAPPED: the edge-weighted half-Kelly fractions are scaled down
// uniformly so Σ risk ≤ maxHeat, and the whole-share floor keeps REALIZED heat ≤ the cap.
// Pure + deterministic. Honest: half-Kelly off ESTIMATED edges (conviction is NOT a
// probability); the per-position risk is the loss at the stop — a correlated gap can lose more.

struct AllocatedPosition: Sendable, Equatable, Identifiable {
    let symbol: String
    let riskFraction: Double   // account fraction at risk after heat-scaling
    let shares: Int            // whole shares (floored — never over-risk)
    let dollarsAtRisk: Double  // shares × |entry − stop|
    let notional: Double       // shares × entry
    let halfKelly: Double      // raw half-Kelly fraction pre-scale (transparency)
    let evR: Double            // the expected value in R that earned the weight
    var id: String { symbol }
}

struct CapitalAllocation: Sendable, Equatable {
    let positions: [AllocatedPosition]   // desc by riskFraction, tie-break asc symbol
    let totalHeat: Double                // Σ dollarsAtRisk ÷ account — ≤ maxHeat
    let requestedHeat: Double            // Σ of the fundable weights AFTER the correlation haircut, BEFORE heat-scaling
    let scaleApplied: Double             // ≤1 when the cap bound; 1 otherwise
    let account: Double
    let maxHeat: Double
    let caveat: String
}

enum StockSageCapitalAllocator {
    nonisolated static let caveat = "Allocations are HALF-Kelly off ESTIMATED edges (conviction is not a probability); total open heat is hard-capped and whole shares floor each position, so realized heat stays ≤ the cap. Each line sizes the loss at its stop — a correlated gap can lose more."

    /// Deploy capital across the buy-family, positive-EV ideas: weight by half-Kelly (which
    /// already encodes the edge — bigger win·payoff ⇒ bigger fraction), scale uniformly so the
    /// summed risk fits `maxHeat`, then floor to whole shares. Empty plan on invalid inputs or
    /// when nothing is fundable.
    nonisolated static func allocate(ideas: [StockSageIdea], account: Double, maxHeat: Double = 0.08,
                                     calibration: StockSageConvictionCalibration? = nil) -> CapitalAllocation {
        let cap = Swift.min(Swift.max(0, maxHeat), 1)
        func empty() -> CapitalAllocation {
            CapitalAllocation(positions: [], totalHeat: 0, requestedHeat: 0, scaleApplied: 1,
                              account: account, maxHeat: cap, caveat: caveat)
        }
        guard account > 0, cap > 0 else { return empty() }

        // Step 1+2: fund only buy-family ideas with a defined R and positive EV; the raw weight
        // IS half-Kelly (already a FRACTION in [0,0.5] — do NOT divide by account; it also
        // already encodes the edge, so no separate EV multiplier — that would double-count).
        struct Fundable { let symbol: String; let entry: Double; let stop: Double; let weight: Double; let halfKelly: Double; let evR: Double }
        var fundable: [Fundable] = []
        for idea in ideas {
            let a = idea.advice
            guard a.action == .buy || a.action == .strongBuy,
                  let stop = a.stopPrice, let target = a.targetPrice, idea.price > 0,
                  let ev = StockSageExpectedValue.ev(conviction: a.conviction, entry: idea.price, stop: stop, target: target, calibration: calibration),
                  ev.evR > 0 else { continue }
            // COST GATE: don't deploy real dollars into a setup that's net-negative after round-trip
            // frictions (spread+slippage+taker). The rank keys + best-bet already exclude these via
            // clearsCostAfterFrictions, but the allocator — which emits the ACTUAL shares — did not,
            // so a thin high-cost crypto flip the boards hid could still be funded. (Sizing still uses
            // gross Kelly here; net-payoff sizing is a separate change to keep the verified test math.)
            let costs = StockSageNetEdge.defaultCosts(forSymbol: idea.symbol)
            guard let ne = StockSageNetEdge.evaluate(entry: idea.price, stop: stop, target: target,
                                                     spreadBps: costs.spreadBps, slippageBps: costs.slippageBps,
                                                     takerFeeBps: costs.takerFeeBps, winProb: ev.winProbEstimate),
                  ne.clearsCost(estWinProb: ev.winProbEstimate) else { continue }
            let k = StockSageKelly.compute(winRate: ev.winProbEstimate, payoffRatio: ev.rewardR, accountSize: account)
            // Weight off suggestedFraction (= half-Kelly HARD-CAPPED at Kelly's 20% per-position
            // limit), NOT raw half-Kelly — so a lone idea under maxHeat can't sit at up to 50% risk.
            guard k.suggestedFraction > 0 else { continue }
            fundable.append(Fundable(symbol: idea.symbol, entry: idea.price, stop: stop,
                                     weight: k.suggestedFraction, halfKelly: k.halfKelly, evR: ev.evR))
        }
        guard !fundable.isEmpty else { return empty() }

        // Step 2.5 — CORRELATION-AWARE HEAT: a cluster of names that move together is ~1 bet, not N,
        // so down-weight cluster members (each /K) BEFORE heat-scaling. Otherwise a "diversified"
        // plan can be one concentrated bet wearing several tickers (Choueifaty 2013; HRP). Returns
        // come from each idea's sparkline; empty/short sparks → correlation 0 → no clique → no-op.
        let sparkBy = Dictionary(ideas.map { ($0.symbol, $0.spark) }, uniquingKeysWith: { a, _ in a })
        let rawWeights = fundable.map(\.weight)
        let fundReturns = fundable.map { StockSagePortfolioAnalytics.dailyReturns(sparkBy[$0.symbol] ?? []) }
        let adjWeights = StockSageCorrelationCluster.correlationAdjustedWeights(
            symbols: fundable.map(\.symbol), weights: rawWeights, returns: fundReturns)
        let deweightedForCorrelation = zip(rawWeights, adjWeights).contains { $0 - $1 > 1e-12 }
        if deweightedForCorrelation {
            fundable = zip(fundable, adjWeights).map { f, w in
                Fundable(symbol: f.symbol, entry: f.entry, stop: f.stop, weight: w, halfKelly: f.halfKelly, evR: f.evR)
            }
        }

        // Step 3: uniform proportional scaling pins Σ pre-floor heat to min(requested, cap) and
        // preserves the edge ranking.
        let requestedHeat = fundable.reduce(0) { $0 + $1.weight }
        let scaleApplied = requestedHeat > cap ? cap / requestedHeat : 1

        // Step 4: the sizer is the ONLY place dollars/shares are produced; it floors shares DOWN,
        // so realized dollarsAtRisk ≤ scaledFraction·account ⇒ summed realized heat ≤ the cap.
        var positions: [AllocatedPosition] = []
        for f in fundable {
            let scaled = f.weight * scaleApplied
            guard let ps = StockSagePositionSizer.size(account: account, riskFraction: scaled, entry: f.entry, stop: f.stop),
                  ps.shares > 0 else { continue }
            positions.append(AllocatedPosition(symbol: f.symbol, riskFraction: scaled, shares: ps.shares,
                                               dollarsAtRisk: ps.dollarsAtRisk, notional: ps.notional,
                                               halfKelly: f.halfKelly, evR: f.evR))
        }

        // Step 5: realized heat + deterministic order (desc risk, tie-break asc symbol).
        let totalHeat = positions.reduce(0) { $0 + $1.dollarsAtRisk } / account
        let sorted = positions.sorted { $0.riskFraction != $1.riskFraction ? $0.riskFraction > $1.riskFraction : $0.symbol < $1.symbol }
        let finalCaveat = deweightedForCorrelation
            ? caveat + " A correlated cluster was de-weighted to count as ~one bet, not several."
            : caveat
        return CapitalAllocation(positions: sorted, totalHeat: totalHeat, requestedHeat: requestedHeat,
                                 scaleApplied: scaleApplied, account: account, maxHeat: cap, caveat: finalCaveat)
    }
}
