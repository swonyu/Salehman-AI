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

/// The round-trip cost broken into its real legs (all in price units PER SHARE) so the owner
/// can see WHICH friction eats the edge — not just one collapsed number. Every leg is a LABELED
/// ESTIMATE, never a venue quote. Spread/slippage bps are round-trip by convention; the taker
/// fee is charged on BOTH fills; financing is the overnight/borrow leg (0 for a same-day cash long).
struct AllInCost: Sendable, Equatable {
    let spreadCost: Double
    let slippageCost: Double
    let commissionCost: Double
    let financingCost: Double
    let takerFeeCost: Double
    nonisolated var total: Double { spreadCost + slippageCost + commissionCost + financingCost + takerFeeCost }
    /// The largest single leg — the "what's eating the edge" line for the UI.
    nonisolated var dominantLeg: String {
        let legs: [(String, Double)] = [("spread", spreadCost), ("slippage", slippageCost),
                                        ("commission", commissionCost), ("financing", financingCost),
                                        ("takerFee", takerFeeCost)]
        return legs.max { $0.1 < $1.1 }?.0 ?? "spread"
    }
}

enum StockSageNetEdge {
    /// A LABELED, asset-class default cost assumption — crypto and thin foreign listings
    /// carry far wider spreads than US large-caps or FX majors. Estimates, not quotes.
    struct CostAssumption: Sendable, Equatable {
        let spreadBps: Double
        let slippageBps: Double
        let assetClass: String
        /// Round-trip taker/exchange fee (both fills), bps of entry. Dominant on crypto; ~0 on
        /// commission-free equity brokers. Defaulted so existing constructions stay valid.
        let takerFeeBps: Double
        nonisolated var roundTripBps: Double { spreadBps + slippageBps + takerFeeBps }
        nonisolated init(spreadBps: Double, slippageBps: Double, assetClass: String, takerFeeBps: Double = 0) {
            self.spreadBps = spreadBps; self.slippageBps = slippageBps
            self.assetClass = assetClass; self.takerFeeBps = takerFeeBps
        }
    }

    /// Itemize the round-trip friction per share. ADDITIVE — `evaluate()` is untouched. Financing
    /// is rate·holdDays (0 for a same-day or cash position — the caller passes the borrow rate only
    /// when it applies); the taker fee is charged on BOTH fills (the crypto "GE-2% tax" analog).
    /// All bps/rates are caller-supplied LABELED ESTIMATES, never scraped venue numbers.
    nonisolated static func allInCost(entry: Double, spreadBps: Double = 0, slippageBps: Double = 0,
                                      commissionPerShare: Double = 0, takerFeeBps: Double = 0,
                                      annualFinancingRate: Double = 0, holdDays: Double = 0) -> AllInCost {
        let e = Swift.max(0, entry)
        return AllInCost(
            spreadCost: e * Swift.max(0, spreadBps) / 10_000,
            slippageCost: e * Swift.max(0, slippageBps) / 10_000,
            commissionCost: Swift.max(0, commissionPerShare),
            financingCost: e * Swift.max(0, annualFinancingRate) * Swift.max(0, holdDays) / 365,
            takerFeeCost: e * 2 * Swift.max(0, takerFeeBps) / 10_000)   // both fills
    }

    /// Pick a sensible round-trip cost estimate from the symbol's asset class (suffix).
    /// Crypto widest, FX majors tightest; foreign single-listings wider than US large-caps.
    nonisolated static func defaultCosts(forSymbol symbol: String) -> CostAssumption {
        let s = symbol.uppercased()
        if s.hasSuffix("-USD") { return CostAssumption(spreadBps: 30, slippageBps: 20, assetClass: "crypto", takerFeeBps: 20) } // 70bps incl. ~0.1%/fill taker
        if s.hasSuffix("=X")   { return CostAssumption(spreadBps: 4,  slippageBps: 3,  assetClass: "FX") }          // 7bps
        if s.hasPrefix("^")    { return CostAssumption(spreadBps: 5,  slippageBps: 3,  assetClass: "index") }       // 8bps
        if s.contains(".")     { return CostAssumption(spreadBps: 20, slippageBps: 10, assetClass: "intl") }        // 30bps
        return CostAssumption(spreadBps: 8, slippageBps: 5, assetClass: "US large-cap")                             // 13bps
    }

    /// Net reward:risk for a symbol using its asset-class default round-trip costs — ONE source of
    /// truth so the on-screen trade gate and the copied broker plan can't disagree on go/no-go. nil
    /// when the gross setup is degenerate (then callers fall back to gross). netRR is independent of
    /// winProb, so callers needing only the ratio can omit it. `annualFinancingRate`/`holdDays`
    /// default to 0 (byte-identical to before they existed) — a short-side caller should pass
    /// `StockSageExpectedValue.financingCostInputs(for:)`'s output so this convenience wrapper
    /// can't disagree with the ranking-driving `netEVR`/`netVelocity` figures for the same idea.
    nonisolated static func netRR(symbol: String, entry: Double, stop: Double, target: Double,
                                  annualFinancingRate: Double = 0, holdDays: Double = 0,
                                  winProb: Double? = nil) -> Double? {
        let c = defaultCosts(forSymbol: symbol)
        return evaluate(entry: entry, stop: stop, target: target,
                        spreadBps: c.spreadBps, slippageBps: c.slippageBps,
                        takerFeeBps: c.takerFeeBps,
                        annualFinancingRate: annualFinancingRate, holdDays: holdDays,
                        winProb: winProb)?.netRR
    }

    /// Conservative retail-honest annualized borrow/margin-cost ESTIMATE for a general-collateral
    /// short — a floor, not a promise (a genuinely hard-to-borrow name runs far higher). A cash
    /// long owns the shares outright and pays nothing here; a short is definitionally a margin
    /// transaction and pays this every day it's held, regardless of leverage. Chosen as a
    /// middle ground between the narrow stock-loan fee alone (~0.3-1%/yr for easy-to-borrows,
    /// too optimistic — ignores the margin-account requirement itself) and a full retail margin
    /// rate (5-8%/yr, broker-specific). Evidence + magnitude check:
    /// RESEARCH_2026-07-02_week_horizon_velocity.md ("overnight positions carry structurally
    /// higher costs... margin requirements are higher overnight, and stock-borrow fees are
    /// typically charged only on short positions held overnight").
    nonisolated static let defaultShortBorrowRate = 0.03   // 3%/year

    /// Net reward:risk after round-trip frictions. Works for longs and shorts (uses absolute
    /// distances). `spreadBps`/`slippageBps` are round-trip, in bps of entry price;
    /// `commissionPerShare` is absolute. `annualFinancingRate`/`holdDays` (both default 0 — a
    /// same-day/cash-long position pays nothing, byte-identical to prior behavior) add the
    /// overnight borrow/margin leg `allInCost` already itemizes but this function never
    /// incorporated — callers holding a SHORT position pass `defaultShortBorrowRate` and the
    /// idea's expected hold days so the net figure honestly reflects the cost of holding it.
    /// nil if the gross setup is degenerate.
    nonisolated static func evaluate(entry: Double, stop: Double, target: Double,
                                     spreadBps: Double = 0, slippageBps: Double = 0,
                                     commissionPerShare: Double = 0, takerFeeBps: Double = 0,
                                     annualFinancingRate: Double = 0, holdDays: Double = 0,
                                     winProb: Double? = nil) -> NetEdge? {
        let grossReward = abs(target - entry)
        let grossRisk = abs(entry - stop)
        guard grossReward > 0, grossRisk > 0, entry > 0 else { return nil }

        // Same formula as allInCost's financing leg — one source of truth for the rate·days math.
        let financingCost = entry * Swift.max(0, annualFinancingRate) * Swift.max(0, holdDays) / 365
        let cost = Swift.max(0, spreadBps + slippageBps + takerFeeBps) / 10_000 * entry
            + Swift.max(0, commissionPerShare) + financingCost
        let grossRR = grossReward / grossRisk
        // Net figures (netRR/netExpectancyR/breakEvenWinRate) are derived from the SAME 50:1
        // ceiling StockSageExpectedValue.ev() already applies to rewardR — a hair-thin stop
        // (risk → 0) otherwise makes grossRR unbounded, which blows netRR/netExpectancyR up ~20x
        // past the properly-capped gross figure and collapses breakEvenWinRate toward 0, making
        // the net-cost gate (clearsCost) toothless for exactly the degenerate setups it exists to
        // catch. `grossRR` itself stays the true UNCAPPED ratio (still useful for display).
        let cappedGrossReward = Swift.min(grossRR, 50) * grossRisk
        let netReward = cappedGrossReward - cost
        let netRisk = grossRisk + cost
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

// MARK: - Tier-aware crypto round-trip cost estimate (CRYPTO_RISK #1)
//
// The flat crypto default above (70bps) treats BTC and a microcap alt identically. This richer
// estimate tiers by liquidity and itemizes the legs (half-spread crossed twice + slippage +
// taker fee on BOTH fills — the advisor's stop/target are crossing events, not resting limits).
// NEW ACCESSOR ONLY: `defaultCosts` is deliberately UNTOUCHED (byte-identical production
// ranking/gating — re-pointing it is a future owner-reviewed change; see the wave-2 plan's
// REJECTED register). Every band is a LABELED ESTIMATE midpoint, never a venue quote.
extension StockSageNetEdge {
    enum CryptoLiquidityTier: String, Sendable, CaseIterable {
        case majorBTCETH, large, mid, thin
    }

    struct CryptoCostEstimate: Sendable, Equatable {
        let tier: CryptoLiquidityTier
        let halfSpreadBps: Double        // one crossing; paid twice per round trip
        let slippageBps: Double          // round-trip
        let takerFeeBpsPerSide: Double   // per fill; paid twice per round trip
        let estimateLowBps: Double       // band edges — surfaced so no UI can show a false point
        let estimateHighBps: Double
        let assetClass: String           // always "crypto"
        let isEstimate: Bool             // always true
        nonisolated var roundTripBps: Double { 2 * halfSpreadBps + slippageBps + 2 * takerFeeBpsPerSide }
        nonisolated var disclaimer: String { "ESTIMATE only — your venue/tier/size differ; not a quote and not a promise." }
        /// Bridge into the existing `evaluate()` seam. CostAssumption's spread/slippage/taker are
        /// ROUND-TRIP by convention (see `defaultCosts`' 70bps comment), so: spread = 2·half,
        /// taker = 2·perSide.
        nonisolated var asCostAssumption: CostAssumption {
            CostAssumption(spreadBps: 2 * halfSpreadBps, slippageBps: slippageBps,
                           assetClass: assetClass, takerFeeBps: 2 * takerFeeBpsPerSide)
        }
    }

    /// Liquidity tier from the symbol + (optional) average daily dollar volume. Honesty floor:
    /// an UNKNOWN alt (advDollar nil) is `.mid`, never assumed deep. Reuses the liquidity
    /// engine's existing floors (thinBelow 2M / deepAbove 50M) — no new magic numbers.
    nonisolated static func cryptoTier(forSymbol symbol: String, advDollar: Double?) -> CryptoLiquidityTier {
        let s = symbol.uppercased()
        if s == "BTC-USD" || s == "ETH-USD" { return .majorBTCETH }
        guard let adv = advDollar else { return .mid }
        if adv < StockSageLiquidity.thinBelow { return .thin }
        if adv >= StockSageLiquidity.deepAbove { return .large }
        return .mid
    }

    /// The tier's labeled estimate bands (midpoint anchors hand-derived in the wave-2 plan;
    /// see /tmp/derive_cryptocost.swift): major 37.5bps RT (21–54), large 60 (34–86),
    /// mid 125 (70–180), thin 300 (160–440).
    nonisolated static func cryptoCosts(forSymbol symbol: String, advDollar: Double?) -> CryptoCostEstimate {
        switch cryptoTier(forSymbol: symbol, advDollar: advDollar) {
        case .majorBTCETH:
            return CryptoCostEstimate(tier: .majorBTCETH, halfSpreadBps: 2, slippageBps: 5.5,
                                      takerFeeBpsPerSide: 14, estimateLowBps: 21, estimateHighBps: 54,
                                      assetClass: "crypto", isEstimate: true)
        case .large:
            return CryptoCostEstimate(tier: .large, halfSpreadBps: 5.5, slippageBps: 14,
                                      takerFeeBpsPerSide: 17.5, estimateLowBps: 34, estimateHighBps: 86,
                                      assetClass: "crypto", isEstimate: true)
        case .mid:
            return CryptoCostEstimate(tier: .mid, halfSpreadBps: 17.5, slippageBps: 40,
                                      takerFeeBpsPerSide: 25, estimateLowBps: 70, estimateHighBps: 180,
                                      assetClass: "crypto", isEstimate: true)
        case .thin:
            return CryptoCostEstimate(tier: .thin, halfSpreadBps: 55, slippageBps: 130,
                                      takerFeeBpsPerSide: 30, estimateLowBps: 160, estimateHighBps: 440,
                                      assetClass: "crypto", isEstimate: true)
        }
    }
}
