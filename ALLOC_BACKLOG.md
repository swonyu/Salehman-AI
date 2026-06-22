# Capital-allocation specs (wmfbefkkc, 2026-06-22)

6 specs. Implement top sound items engine-first + test.

## Top 3
- StockSageCapitalAllocator.allocate — fractional-Kelly multi-idea allocator, heat-capped (rank 1): the core engine, edge-weights deployment by half-Kelly and hard-caps total heat under maxHeat; medium effort, pure composition of ExpectedValue + Kelly + PositionSizer, and the single highest risk-adjusted-growth lever. NOTE the load-bearing fix: KellyResult.halfKelly is a FRACTION already — do NOT divide it by account (the source proposal's `halfKelly/account` is a bug), and rebuild Proposal 1's body which has literal syntax errors (`let actual risk$`, `riskDollars`/`idea` referenced outside the loop).
- StockSageCapitalAllocator.suggestAdd — marginal allocation against the live book (rank 2): answers the day-to-day question 'I have ONE new idea + an open book, how much do I add?' Heat-headroom capped and correlation-gated via the existing StockSageClusterCheck; medium effort; wires straight into the Size-it-now button.
- StockSageCapitalAllocator.allocateDeCorrelated — cluster-merged heat-capped allocator (rank 3): the survival upgrade over rank 1 — greedily merges ideas with correlation >= threshold so two crypto names don't count as two bets, penalizing cluster capital, with a clean fallback to allocate() when no return history exists; large effort, the de-correlation that keeps positive-EV ideas from all crashing together.

### ⬜ #1 — StockSageCapitalAllocator.allocate — fractional-Kelly multi-idea allocator, heat-capped  [medium]
**signature:** ```swift
struct AllocationPlan: Sendable, Equatable, Identifiable {
    let symbol: String
    let shares: Int           // whole shares, rounded DOWN (never over-risk)
    let notional: Double      // shares * entry
    let riskDollars: Double   // shares * |entry-stop| (actual $ lost on a stop-out)
    let riskFraction: Double  // riskDollars / account (the heat this position adds)
    let evR: Double           // estimated EV in R (ranking key)
    var id: String { symbol }
}

enum StockSageCapitalAllocator {
    /// Deploy capital across N ideas, edge-weighted by half-Kelly, then scaled so
    /// total open heat <= maxHeat. Returns nil for invalid account/heat or when no
    /// idea has positive EV. Pure + deterministic.
    nonisolated static func allocate(
        ideas: [(symbol: String, entry: Double, stop: Double, target: Double, conviction: Double)],
        account: Double,
        maxHeat: Double = 0.08
    ) -> [AllocationPlan]?
}
```
Mechanics (corrects the proposal's bugs): for each idea call `StockSageExpectedValue.ev(conviction:entry:stop:target:)`, keep only `isPositive`. Kelly fraction = `StockSageKelly.compute(winRate: ExpectedValue.winProbEstimate, payoffRatio: ev.rewardR, accountSize: account).halfKelly` — note `.halfKelly` is ALREADY a FRACTION (do not divide by account; the proposal's `halfKelly/account` is wrong). Sum raw risk fractions; if `Σf > maxHeat`, scale every f by `maxHeat/Σf`. Then size each at `StockSagePositionSizer.size(account:, riskFraction: scaledF, entry:, stop:)` to get whole shares + true riskDollars. Sort by evR desc.
**testIdea:** Three ideas (BTC edge high / AAPL mid / SPY low), account $10k, maxHeat 0.08. Assert: (a) every plan.riskFraction>0 and Σ riskDollars <= $800 + one-share rounding tolerance; (b) higher-evR idea gets >= riskDollars of lower-evR idea when stop distances are equal; (c) maxHeat=0.20 with raw heat 0.04 → NO rescale, fractions pass through (scaleFactor==1); (d) all-negative-EV ideas → nil; (e) account<=0 or maxHeat>1 → nil; (f) shares are floored (never fractional, never over-risk).

### ⬜ #2 — StockSageCapitalAllocator.suggestAdd — marginal allocation against the live book  [medium]
**signature:** ```swift
struct AddSuggestion: Sendable, Equatable {
    let symbol: String
    let approved: Bool
    let riskFraction: Double      // suggested heat to add (0 if blocked)
    let shares: Int
    let riskDollars: Double
    let heatBefore: Double        // current portfolio heat
    let heatHeadroom: Double      // maxHeat - heatBefore
    let nearestCorrelation: Double?
    let reason: String            // why this size / why blocked
    let caveat: String
}

enum StockSageCapitalAllocator {
    /// Marginal sizing for ONE new idea given the open book. Heat-headroom capped,
    /// correlation-gated. nil if the idea has no defined R (no stop/target) or
    /// account<=0. Pure + deterministic.
    nonisolated static func suggestAdd(
        idea: StockSageIdea,
        openTrades: [(shares: Double, entry: Double, stop: Double)],
        holdings: [(symbol: String, returns: [Double])],
        candidateReturns: [Double],
        account: Double,
        maxHeat: Double = 0.10,
        correlationThreshold: Double = 0.80
    ) -> AddSuggestion?
}
```
Composes existing engines: EV via `StockSageExpectedValue.ev(for: idea)`; current heat via `StockSagePortfolioHeat.compute(openTrades:accountSize:)`; correlation gate via `StockSageClusterCheck.check(candidate:candidateReturns:holdings:threshold:)`. Suggested fraction = min(halfKelly, remaining heat headroom). Block (approved=false, riskFraction=0) when `ClusterCheck.isConcentrating`.
**testIdea:** (1) +EV idea, book at 0% heat, uncorrelated → approved, riskFraction≈min(halfKelly, 0.10); (2) book already at 9.5% heat → riskFraction capped to ≈0.005 headroom; (3) candidate corr 0.82 to an open name (>=0.80) → approved=false, riskFraction 0, reason names the cluster peer; (4) idea whose advice has nil stop OR nil target → nil; (5) account<=0 → nil. Integration: prefill the Size-it-now button on the best-opportunity card.

### ⬜ #3 — StockSageCapitalAllocator.allocateDeCorrelated — cluster-merged heat-capped allocator  [large]
**signature:** ```swift
enum StockSageCapitalAllocator {
    /// Like allocate(), but first merges ideas whose pairwise correlation >= threshold
    /// into one cluster (highest-EV idea represents it, capital penalized by cluster
    /// size) so correlated bets don't double the same risk. Falls back to plain
    /// allocate() when historicalReturns is nil/empty. nil on invalid inputs or no
    /// surviving positive-EV cluster.
    nonisolated static func allocateDeCorrelated(
        ideas: [(symbol: String, entry: Double, stop: Double, target: Double, conviction: Double)],
        account: Double,
        historicalReturns: [String: [Double]]? = nil,
        maxHeat: Double = 0.08,
        correlationThreshold: Double = 0.75,
        clusterPenalty: Double = 0.5
    ) -> [AllocationPlan]?  // returns the rank-1 AllocationPlan type, with effectiveIdeas count in a sibling field/return
}
```
Clusters via `StockSagePortfolioAnalytics.correlation(_:_:)` (greedy single-link at threshold). Per cluster keep the max-evR idea; penalty factor `1/(1 + (clusterSize-1)*clusterPenalty)`. Allocate penalized-edge-weighted, then heat-normalize as in rank 1. Reuses `correlation`, `ExpectedValue.ev`, `PositionSizer.size`.
**testIdea:** (1) BTC+ETH corr 0.9 (>=0.75) cluster, AAPL corr 0.3 standalone → only highest-EV of {BTC,ETH} allocated, at penalty 1/(1+0.5)=0.667; AAPL un-penalized; effectiveIdeas==2 not 3. (2) clusterPenalty=0 → no penalty even when clustered. (3) historicalReturns nil → identical output to allocate(). (4) perfect anti-correlation (-0.95) → no merge, both sized. (5) Σ riskDollars <= maxHeat*account.

### ⬜ #4 — StockSageCapitalAllocator.rebalanceByRiskParity — whole-book equal-risk reweight  [medium]
**signature:** ```swift
enum StockSageCapitalAllocator {
    /// Reweight the whole book from current dollars toward inverse-vol (equal-risk)
    /// targets, emitting buy/sell trades with a no-trade band. Does NOT add net new
    /// risk — pure reallocation. nil if nothing invested or no positive-vol holding.
    nonisolated static func rebalanceByRiskParity(
        holdings: [RiskParityHolding],          // symbol, currentValue, annualized vol
        band: Double = 0.03,
        avgCorrelation: Double? = nil           // optional, to flag crash-regime risk
    ) -> (plan: RebalancePlan, note: String)?
}
```
Thin composition: `StockSageRiskParity.targets(holdings)` → dict of `targetWeight` → `StockSageRebalance.plan(holdings:targets:band:)`. If `avgCorrelation` (from `PortfolioAnalytics.compute(...).avgCorrelation`) is high (e.g. >=0.7), append a 'correlation-shock — risk-parity benefit shrinks; hold a cash sleeve' note. Reuses RiskParityHolding, targets(), RebalancePlan, Rebalance.plan().
**testIdea:** (1) AAPL vol 25% / BND 5% / GOLD 15%, equal dollars → targets ∝ 1/vol (BND heaviest); plan sells AAPL, buys BND; deltas sum ≈0. (2) all drifts < band → plan.isBalanced==true, no trades. (3) avgCorrelation 0.9 → note contains the cash-sleeve warning. (4) single positive-vol holding → no rebalance (nil or empty). (5) a holding with vol<=0 is dropped by targets() and excluded from the plan.

### ⬜ #5 — StockSageCapitalAllocator.rebalanceToEdge — edge-weighted whole-book reweight with no-trade band  [medium]
**signature:** ```swift
enum StockSageCapitalAllocator {
    /// Reweight held symbols + new ideas toward EV-edge-weighted targets, suppressing
    /// churn with a band. New ideas enter only if positive-EV and not correlation-
    /// blocked. nil if nothing invested or no positive edge anywhere.
    nonisolated static func rebalanceToEdge(
        holdings: [(symbol: String, value: Double)],
        ideas: [StockSageIdea],
        band: Double = 0.03,
        maxHeat: Double = 0.10
    ) -> RebalancePlan?
}
```
Targets = normalized positive `StockSageExpectedValue.ev(for: idea).evR` across held+new symbols (held symbols with no current idea get edge 0 → trimmed). Feed to `StockSageRebalance.plan(holdings:targets:band:)`. Reuses ev(for:), Rebalance.plan, RebalancePlan. Note: edge-weighting differs from risk-parity (rank 4) — this chases EV, rank 4 chases equal risk; ship both, they answer different questions.
**testIdea:** (1) AAPL (idea EV -0.2R) + MSFT (EV +0.5R) held, new NVDA (EV +0.3R): plan trims AAPL, grows MSFT, adds NVDA. (2) all drifts < band → isBalanced true. (3) a new idea correlated/blocked → excluded with a note (compose ClusterCheck if returns supplied, else size-only). (4) zero positive edge → nil. Honesty: edge decays; targets are EV estimates not fills.

### ⬜ #6 — StockSageAllocationOptimizer.optimizeSharpeDeCorrelated — Sharpe-max QP allocator (stretch)  [large]
**signature:** ```swift
enum StockSageAllocationOptimizer {
    struct OptimizationResult: Sendable, Equatable {
        let allocations: [AllocationPlan]   // reuse rank-1 type
        let estPortfolioSharpe: Double?
        let estPortfolioVol: Double?
        let converged: Bool
        let iterations: Int
        let bindingConstraints: [String]    // any of: heat, kelly, decorr
        let note: String
    }
    /// Maximize w·mu - lambda*w·Sigma·w subject to wi<=halfKelly_i, paired decorr
    /// caps, and Σheat<=heatCap. Simple projected-gradient/barrier solver (LOCAL
    /// optimum only). nil on invalid inputs.
    nonisolated static func optimizeSharpeDeCorrelated(
        ideas: [(symbol: String, entry: Double, stop: Double, target: Double, conviction: Double)],
        correlations: [(a: String, b: String, rho: Double)],
        account: Double,
        heatCap: Double = 0.08,
        corrThreshold: Double = 0.75,
        maxIterations: Int = 100,
        convergenceTol: Double = 1e-6
    ) -> OptimizationResult?
}
```
Builds mu from `ExpectedValue.ev` evR, Sigma from supplied rho + per-idea vol (derive from spark/returns). Reuses correlation, ev, PositionSizer for final share sizing. Heavier and only locally optimal — lowest rank because ranks 1-5 already give most of the survival benefit far cheaper.
**testIdea:** (1) Same 3-idea setup as rank 1 → allocations close to greedy allocate() but lower heat burn / higher Sharpe. (2) low-EV-high-Sharpe vs high-EV-low-Sharpe pair → optimizer tilts toward the Sharpe improver where Kelly-only would not. (3) 10 ideas at 0.95 pairwise, total Kelly ask 50%, heatCap 8% → converges, Σheat<=8%, bindingConstraints contains 'heat'. (4) invalid account → nil. Honesty: local solver, no global-optimum guarantee; Sigma is backward-looking.

## Notes
All referenced symbols VERIFIED to exist (read the source):\n- StockSageKelly.compute(winRate:payoffRatio:accountSize:) -> KellyResult{edge,fullKelly,halfKelly,quarterKelly,suggestedFraction(capped 0.20),dollarsToRisk,note,caveat}. CRITICAL: halfKelly/quarterKelly/suggestedFraction are FRACTIONS (0-1); dollarsToRisk is the only dollar field. Several proposals misuse `halfKelly/account` or treat halfKelly as dollars — that is a bug; sizes must come from a fraction fed to PositionSizer.size, or from dollarsToRisk directly.\n- StockSageExpectedValue: ev(conviction:entry:stop:target:)->ExpectedValue? and ev(for: StockSageIdea)->ExpectedValue?; ExpectedValue{winProbEstimate,rewardR,evR,isPositive}; winProbEstimate(conviction:) maps 0->0.35,1->0.58. There is NO `ev.edge` or `ev.isPositive` mismatch — use evR/rewardR/isPositive as named. Proposal 1's `ev.evR // edge` comment and Proposal 2's `ev.evR` are fine; but `StockSageExpectedValue.ev(...).ev.isPositive` chaining and the field `edge`/`rewardR` aliases in the proposals must map to evR/rewardR.\n- StockSagePositionSizer.size(account:riskFraction:entry:stop:)->PositionSize?{shares(Int, floored),dollarsAtRisk,notional,pctOfAccount,riskPerShare}. Use this for all share sizing so rounding is consistent and never over-risks.\n- StockSagePortfolioHeat.compute(openTrades:[(shares:Double,entry:Double,stop:Double)], accountSize:)->PortfolioHeat?{dollarsAtRisk,heatPct,level(cool<5%/warm<10%/hot>=10%)}.\n- StockSageClusterCheck.check(candidate:candidateReturns:holdings:[(symbol:,returns:)] ,threshold:0.8)->ClusterCheck?{isConcentrating,highlyCorrelated,nearest,note}. Needs RETURN SERIES, not closes.\n- StockSagePortfolioAnalytics.correlation(_:[Double],_:[Double])->Double (Pearson, aligned on common tail), plus datedReturns/alignByDate/correlationMatrix/averageCorrelation/compute(...).avgCorrelation — all present and usable for the de-correlated and risk-parity specs.\n- StockSageRiskParity.targets([RiskParityHolding{symbol,currentValue,volatility}])->[RiskParityTarget{currentWeight,targetWeight,deltaWeight}]; rebalanceAmounts; vsEqualWeight. Drops vol<=0 holdings.\n- StockSageRebalance.plan(holdings:[(symbol:,value:)], targets:[String:Double], band:0.02)->RebalancePlan?{trades,isBalanced}; equalWeightTargets.\n- StockSageIdea{symbol,market,price,advice:TradeAdvice,spark:[Double]} in StockSageStore.swift. TradeAdvice has action:Action(.buy/.strongBuy/.hold/...), conviction:Double(0-1), stopPrice:Double?, targetPrice:Double?. So ev(for:) returns nil when stop OR target is nil — every spec must handle that.\n- TradeRecord exists (StockSageJournal.swift); StockSageAllocation.assetClass(_:) exists.\n\nPROPOSAL DEDUP/MERGE: the 11 proposals collapse to 6 distinct engines. 'Fractional-Kelly heat-cap allocator', 'Heat-aware Kelly w/ correlation', 'CorrelatedKellyAllocator', 'EdgeAllocation', and 'Kelly-Weighted Multi-Idea' / 'Heat-Capped Correlation-Neutral' are the SAME two engines (plain heat-capped = rank 1; correlation-merged = rank 3) under different names — do NOT build them separately. rank 2 (suggestAdd) and ranks 4-5 (whole-book rebalancers) are genuinely distinct surfaces. rank 6 (Sharpe QP) is a stretch.\n\nNAMING: I unified everything under one `enum StockSageCapitalAllocator` (+ a separate `StockSageAllocationOptimizer` for the QP) so the AllocationPlan struct is shared and there isn't a zoo of allocator types. Reuse one AllocationPlan struct (rank 1) across ranks 1/3/6.\n\nHONESTY (carry verbatim into every engine's caveat string): EV's pWin is winProbEstimate(conviction) — an ESTIMATE in a 35-58% band, NOT a real probability; Kelly is only as good as W and R, which run optimistic, so ship fractional (half/quarter) + the existing 20% hard cap. Correlation/Sigma are BACKWARD-LOOKING and rise toward 1.0 in crashes — exactly when de-correlation is needed most; cluster thresholds (0.75/0.8) are heuristics, not laws. Heat assumes every stop fills AT its level; a correlated gap loses more. Rebalancers ignore spread/slippage/tax/min-lot. NEVER promise growth — the cap prevents ruin, it does not guarantee profit; backtest across real ideas before any live use.\n\nVERIFICATION method: read all 9 named source files + StockSageStore/Advisor for the Idea/Advice shapes; confirmed every called symbol's exact signature and return-field names. No symbol in the final 6 specs is invented. Build/test commands are the canonical xcodebuild scheme 'Salehman AI'; new .swift under 'Salehman AI/StockSage/' auto-compiles (no pbxproj edit). Per repo rules a DEVELOPMENT_LOG.md entry is required after implementing any of these — that's an implementation-time step, not part of this spec task.