import Foundation

// MARK: - Expected value (the "what's the best BET" score)
//
// Signal strength ranks how confident the RULES are; expected value ranks how much
// you can EXPECT to make. EV (in R) = pWin·rewardR − (1−pWin)·1, where the loss is
// −1R (a stop-out) and rewardR is the reward:risk ratio. The catch: pWin is an
// ESTIMATE — the advisor's conviction is NOT a probability, so we map it into a
// deliberately conservative band and SAY it's an estimate. EV ranks opportunities
// by payoff, but it is not a promise; over-betting a positive-EV edge still ruins.

struct ExpectedValue: Sendable, Equatable {
    let winProbEstimate: Double   // 0–1, an ESTIMATE derived from conviction
    let rewardR: Double           // reward:risk
    let evR: Double               // expected R per trade
    nonisolated var isPositive: Bool { evR > 0 }
}

/// How concentrated the top fast-lane setups are by asset class — the honest check on
/// chasing velocity (which tends to crowd into one fast-turnover class, e.g. crypto).
struct FastLaneConcentration: Sendable, Equatable {
    let dominantClass: String
    let count: Int        // how many of the top-N are the dominant class
    let total: Int        // size of the top-N considered
    nonisolated var isConcentrated: Bool { total >= 2 && count == total }
}

/// Tunable per-asset-class holding-period assumptions feeding velocity (EV/day), so
/// the owner can match it to his real holding periods. Defaults equal the original
/// hardcoded values (crypto 3d, equity 12d) so nothing shifts silently.
struct VelocityHoldDays: Sendable, Equatable {
    var crypto: Double
    var equity: Double
    nonisolated static let defaults = VelocityHoldDays(crypto: 3, equity: 12)
}

/// One-glance money-velocity rollup for the top-of-Markets header. Every field is a
/// value computed by a dedicated, tested helper — this just gathers them.
struct MoneyVelocitySummary: Sendable, Equatable {
    let bestSymbol: String?       // highest positive-EV buy
    let bestEV: Double?
    let fastestSymbol: String?    // highest EV/day (fast lane)
    let fastestVelocity: Double?
    let weeklyR: Double?          // est. weekly R running the top setups
    let worstRunLosses: Int?      // worst losing streak in the journal (the brake)
    let worstRunDrawdownPct: Double?  // that streak at the modeled risk % → account drawdown
    let riskFraction: Double      // the per-trade risk the drawdown brake was modeled at (so the label can't drift)
    nonisolated var hasContent: Bool { bestSymbol != nil || fastestSymbol != nil || weeklyR != nil }

    nonisolated init(bestSymbol: String? = nil, bestEV: Double? = nil, fastestSymbol: String? = nil,
                     fastestVelocity: Double? = nil, weeklyR: Double? = nil, worstRunLosses: Int? = nil,
                     worstRunDrawdownPct: Double? = nil, riskFraction: Double = 0.01) {
        self.bestSymbol = bestSymbol; self.bestEV = bestEV
        self.fastestSymbol = fastestSymbol; self.fastestVelocity = fastestVelocity
        self.weeklyR = weeklyR; self.worstRunLosses = worstRunLosses
        self.worstRunDrawdownPct = worstRunDrawdownPct; self.riskFraction = riskFraction
    }
}

enum StockSageExpectedValue {
    /// Conviction (0–1) → an estimated win probability in a conservative band:
    /// 0 → 35%, 1 → 58%. Never claims high certainty; conviction ≠ probability.
    nonisolated static func winProbEstimate(conviction: Double) -> Double {
        0.35 + Swift.max(0, Swift.min(1, conviction)) * 0.23
    }

    /// Expected value in R: pWin·rewardR − (1−pWin)·1. nil if there's no defined
    /// risk or reward (entry==stop or no target).
    nonisolated static func ev(conviction: Double, entry: Double, stop: Double, target: Double) -> ExpectedValue? {
        let risk = abs(entry - stop), reward = abs(target - entry)
        guard risk > 0, reward > 0 else { return nil }
        // Cap reward:risk at a sane ceiling. A hair-thin stop (risk → 0) otherwise makes rewardR
        // unbounded, which overruns the FIXED regime/cost/conviction demotion constants in the rank
        // key (−1_000_000 / −500_000 / −1000) and lets a BANNED side rank #1. No real setup exceeds
        // 50:1 reward:risk; beyond it the stop is degenerate, not a genuine edge.
        let rewardR = Swift.min(reward / risk, 50)
        let p = winProbEstimate(conviction: conviction)
        return ExpectedValue(winProbEstimate: p, rewardR: rewardR, evR: p * rewardR - (1 - p))
    }

    /// Typical hold in days by asset class — crypto turns over fast (24/7), equities
    /// swing. nil for index/FX (not traded for velocity here). A rough default, not
    /// a per-symbol measurement.
    nonisolated static func expectedHoldDays(forSymbol symbol: String, holds: VelocityHoldDays = .defaults) -> Double? {
        switch StockSageAllocation.assetClass(symbol) {
        case "Crypto": return holds.crypto
        case "Equity": return holds.equity
        default: return nil
        }
    }

    /// Velocity = EV ÷ expected hold = expected R PER DAY, so a fast-turnover setup
    /// beats a slow swing of equal EV (more compounding cycles). nil if no EV or no
    /// hold estimate. An estimate on an estimate — the UI says so.
    nonisolated static func velocity(for idea: StockSageIdea, holds: VelocityHoldDays = .defaults) -> Double? {
        guard let e = ev(for: idea), let hold = expectedHoldDays(forSymbol: idea.symbol, holds: holds), hold > 0 else { return nil }
        return e.evR / hold
    }

    /// Ideas ranked by velocity (EV/day) desc; ideas without a velocity fall last (stable).
    /// A near-zero-CONVICTION idea with a fantasy wide target inflates EV (winProb only
    /// spans 35–58%, but reward:risk is unbounded), so it could out-rank a REAL
    /// high-conviction setup. These RANKING keys down-weight by conviction (mirroring the
    /// advisor's 0.4+0.6 size scaler) and demote anything below the conviction floor — so a
    /// junk idea can never top the board. The DISPLAYED EV/velocity stays the raw estimate.
    nonisolated static let minConvictionToRank = 0.40
    private nonisolated static func qualityWeight(_ conviction: Double) -> Double {
        0.4 + 0.6 * Swift.max(0, Swift.min(1, conviction))
    }
    /// Quality-adjusted EV — the ranking key (the raw `ev` is still shown to the user).
    nonisolated static func qualityAdjustedEVR(for idea: StockSageIdea) -> Double? {
        ev(for: idea).map { $0.evR * qualityWeight(idea.advice.conviction) }
    }
    /// Does the idea's conviction-mapped win prob clear its AFTER-COST break-even? A thin,
    /// high-cost flip can be positive-EV on paper yet net-negative once frictions are paid.
    /// No defined R (no stop/target) ⇒ treated as clearing (don't demote — unchanged).
    private nonisolated static func clearsCostAfterFrictions(_ idea: StockSageIdea) -> Bool {
        guard let stop = idea.advice.stopPrice, let target = idea.advice.targetPrice else { return true }
        let c = StockSageNetEdge.defaultCosts(forSymbol: idea.symbol)
        guard let ne = StockSageNetEdge.evaluate(entry: idea.price, stop: stop, target: target,
                                                 spreadBps: c.spreadBps, slippageBps: c.slippageBps) else { return true }
        return ne.clearsCost(estWinProb: winProbEstimate(conviction: idea.advice.conviction))
    }

    private nonisolated static func evRankKey(for idea: StockSageIdea) -> Double? {
        guard let base = qualityAdjustedEVR(for: idea) else { return nil }
        var key = base
        if idea.advice.conviction < minConvictionToRank { key -= 1000 }       // low-conviction band
        if !clearsCostAfterFrictions(idea) { key -= 500_000 }                 // costs eat the edge → below clean setups
        return key
    }

    // Regime gate: don't crown a BUY in a crisis/bear tape, or a SHORT in a bull. A banned side
    // is demoted by 1_000_000 (an order of magnitude past the conviction band) so it always ranks
    // below every non-banned idea. The DISPLAYED EV never changes — only the ranking key.
    private enum RankSide { case buyFamily, sellFamily, neutral }
    private nonisolated static func side(_ idea: StockSageIdea) -> RankSide {
        switch idea.advice.action {
        case .buy, .strongBuy: return .buyFamily
        case .sell, .reduce:   return .sellFamily
        case .hold, .avoid:    return .neutral
        }
    }
    private nonisolated static func bannedFromTopRank(_ s: RankSide, regime: MarketRegime.State) -> Bool {
        switch regime {
        case .crisis, .trendingBear:                            // no BUY ranks #1 in a risk-off tape
            if case .buyFamily = s { return true }; return false
        case .trendingBull:                                     // no SHORT ranks #1 in a bull
            if case .sellFamily = s { return true }; return false
        case .ranging:               return false               // neutral regime gates nothing
        }
    }
    private nonisolated static func regimeAdjustedEVRankKey(for idea: StockSageIdea, regime: MarketRegime?) -> Double? {
        guard let base = evRankKey(for: idea) else { return nil }   // nil-EV ideas still fall last, unchanged
        guard let r = regime else { return base }                   // nil regime → IDENTICAL to today
        return bannedFromTopRank(side(idea), regime: r.state) ? base - 1_000_000 : base
    }
    private nonisolated static func velocityRankKey(for idea: StockSageIdea, holds: VelocityHoldDays) -> Double? {
        // Velocity is the BUY-side compounding lane (matches bestOpportunity / CapitalAllocator) —
        // a short does not compound the same way, so only buy-family ideas qualify. (Fixes a short
        // topping the Fast Lane while it is correctly barred from the best-opportunity card.)
        guard case .buyFamily = side(idea) else { return nil }
        guard let q = qualityAdjustedEVR(for: idea),
              let hold = expectedHoldDays(forSymbol: idea.symbol, holds: holds), hold > 0 else { return nil }
        let v = q / hold
        // After-cost screen (mirrors evRankKey): a setup net-negative after frictions can't lead the
        // velocity board either — otherwise a thin, high-cost crypto flip tops it on gross EV.
        if !clearsCostAfterFrictions(idea) { return v - 500_000 }
        return idea.advice.conviction >= minConvictionToRank ? v : v - 1000
    }

    nonisolated static func rankByVelocity(_ ideas: [StockSageIdea], holds: VelocityHoldDays = .defaults) -> [StockSageIdea] {
        ideas.enumerated().sorted { a, b in
            switch (velocityRankKey(for: a.element, holds: holds), velocityRankKey(for: b.element, holds: holds)) {
            case let (x?, y?): return x == y ? a.offset < b.offset : x > y
            case (_?, nil): return true
            case (nil, _?): return false
            case (nil, nil): return a.offset < b.offset
            }
        }.map(\.element)
    }

    /// EV for a ranked idea, or nil when it lacks a stop/target (no defined R:R).
    nonisolated static func ev(for idea: StockSageIdea) -> ExpectedValue? {
        guard let stop = idea.advice.stopPrice, let target = idea.advice.targetPrice else { return nil }
        return ev(conviction: idea.advice.conviction, entry: idea.price, stop: stop, target: target)
    }

    /// Ideas sorted by EV (best bet first). Ideas without a defined EV fall to the
    /// bottom keeping their original relative order (stable).
    nonisolated static func rankByEV(_ ideas: [StockSageIdea], regime: MarketRegime? = nil) -> [StockSageIdea] {
        ideas.enumerated().sorted { a, b in
            switch (regimeAdjustedEVRankKey(for: a.element, regime: regime), regimeAdjustedEVRankKey(for: b.element, regime: regime)) {
            case let (x?, y?): return x == y ? a.offset < b.offset : x > y
            case (_?, nil): return true
            case (nil, _?): return false
            case (nil, nil): return a.offset < b.offset
            }
        }.map(\.element)
    }

    /// The single best BET right now: the buy-family idea with the highest POSITIVE
    /// expected value. nil if no buy idea has positive EV (don't manufacture one).
    nonisolated static func bestOpportunity(_ ideas: [StockSageIdea], regime: MarketRegime? = nil) -> (idea: StockSageIdea, ev: ExpectedValue)? {
        // No "best buy" in a risk-off tape — a crisis/bear is sometimes exactly when an intraday
        // stop gets gapped through. (nil regime → no gate, identical to before.)
        if let r = regime, bannedFromTopRank(.buyFamily, regime: r.state) { return nil }
        return ideas.compactMap { idea -> (StockSageIdea, ExpectedValue)? in
            guard idea.advice.action == .buy || idea.advice.action == .strongBuy,
                  idea.advice.conviction >= minConvictionToRank,   // a #1 pick can't be a low-conviction bet
                  clearsCostAfterFrictions(idea),                  // …nor a setup that's net-negative after costs
                  let e = ev(for: idea), e.evR > 0 else { return nil }
            return (idea, e)
        }
        .max { (qualityAdjustedEVR(for: $0.0) ?? 0) < (qualityAdjustedEVR(for: $1.0) ?? 0) }
        .map { (idea: $0.0, ev: $0.1) }
    }

    /// Fast lane: positive-EV ideas that HAVE a velocity (crypto/equity), ranked by
    /// velocity (EV/day) desc — the fastest-compounding opportunities. Index/FX (no
    /// hold) and non-positive-EV ideas are excluded. Faster turnover = more cycles
    /// AND more chances to be wrong; the UI carries that caveat.
    nonisolated static func fastLane(_ ideas: [StockSageIdea], holds: VelocityHoldDays = .defaults) -> [StockSageIdea] {
        ideas.enumerated().compactMap { idx, idea -> (Int, StockSageIdea, Double)? in
            guard let e = ev(for: idea), e.evR > 0, let v = velocityRankKey(for: idea, holds: holds) else { return nil }
            return (idx, idea, v)
        }
        .sorted { $0.2 == $1.2 ? $0.0 < $1.0 : $0.2 > $1.2 }
        .map { $0.1 }
    }

    /// A heavily-caveated estimate of weekly R IF you actually run AND re-cycle the
    /// top `maxConcurrent` fast-lane setups: sum of their velocities (EV/day) × trading
    /// days. nil if the fast lane is empty. NOT a promise — it assumes you take these,
    /// each carries variance, and it ignores fills/slippage/correlation.
    nonisolated static func expectedWeeklyR(_ ideas: [StockSageIdea], maxConcurrent: Int = 3, tradingDays: Double = 5,
                                            holds: VelocityHoldDays = .defaults) -> Double? {
        let vels = fastLane(ideas, holds: holds).prefix(Swift.max(0, maxConcurrent)).compactMap { velocity(for: $0, holds: holds) }
        guard !vels.isEmpty else { return nil }
        return vels.reduce(0, +) * tradingDays
    }

    /// Account-aware weekly $ estimate: expected weekly R × the dollar value of 1R
    /// (account × riskFraction). nil without an account, risk, or a non-empty fast
    /// lane. An ESTIMATE that assumes you take & re-cycle the top setups — NOT income.
    nonisolated static func expectedWeeklyDollars(_ ideas: [StockSageIdea], account: Double, riskFraction: Double,
                                                  maxConcurrent: Int = 3, tradingDays: Double = 5,
                                                  holds: VelocityHoldDays = .defaults) -> Double? {
        guard account > 0, riskFraction > 0,
              let wkR = expectedWeeklyR(ideas, maxConcurrent: maxConcurrent, tradingDays: tradingDays, holds: holds) else { return nil }
        return wkR * account * riskFraction
    }

    /// Trading days per week for the fast lane. Equities trade ~5 days; crypto is 24/7 (~7).
    /// Blends by the crypto share of the fast lane: round(5 + 2·cryptoFraction) — all-crypto → 7,
    /// equity-only → 5 (so nothing shifts for the existing equity case), 1-of-3 crypto → 6.
    /// Empty lane → 5. NOTE: more trading days ≠ more edge — crypto's extra cadence carries
    /// extra variance, which `cryptoRiskScaler` sizes DOWN for.
    nonisolated static func tradingDaysForLane(_ ideas: [StockSageIdea], holds: VelocityHoldDays = .defaults) -> Double {
        let lane = fastLane(ideas, holds: holds)
        guard !lane.isEmpty else { return 5 }
        let crypto = lane.filter { StockSageAllocation.assetClass($0.symbol) == "Crypto" }.count
        return (5 + 2 * Double(crypto) / Double(lane.count)).rounded()
    }

    /// How much to SHRINK per-trade risk for an asset's realized volatility: max(1, vol/baseline).
    /// FLOORED at 1 so it can only reduce risk, never inflate it — even fast money needs brakes.
    /// e.g. 70%-vol crypto vs a 20% baseline → 3.5× (size 1%/3.5 ≈ 0.29%/trade). Feed `vol` from
    /// `StockSageIndicators.annualizedVolatility`.
    nonisolated static func cryptoRiskScaler(annualizedVol: Double, baseline: Double = 0.20) -> Double {
        guard baseline > 0 else { return 1 }
        return Swift.max(1, annualizedVol / baseline)
    }

    /// A one-glance money-velocity rollup: the best bet now, the fastest-compounding
    /// setup, and the estimated weekly R — each a value already computed elsewhere,
    /// composed for a single header. All optional; `hasContent` gates the card.
    nonisolated static func summary(_ ideas: [StockSageIdea], trades: [TradeRecord] = [],
                                    fraction: Double = 0.01, holds: VelocityHoldDays = .defaults,
                                    regime: MarketRegime? = nil) -> MoneyVelocitySummary {
        // Regime-aware so the card's displayed "best bet" matches the regime-gated nav target
        // (a risk-off tape suppresses the best-buy on BOTH). nil regime → identical to before.
        let best = bestOpportunity(ideas, regime: regime)
        let fastest = fastLane(ideas, holds: holds).first
        // The brake: the owner's worst losing streak, compounded down at the risk fraction.
        let dd = StockSageJournal.equityRisk(trades)
            .flatMap { StockSageRiskOfRuin.scenario(losses: $0.maxConsecutiveLosses, fraction: fraction) }
        return MoneyVelocitySummary(
            bestSymbol: best?.idea.symbol,
            bestEV: best?.ev.evR,
            fastestSymbol: fastest?.symbol,
            fastestVelocity: fastest.flatMap { velocity(for: $0, holds: holds) },
            // Honest cadence: an all-crypto lane re-cycles ~7 days/week, equity ~5.
            weeklyR: expectedWeeklyR(ideas, tradingDays: tradingDaysForLane(ideas, holds: holds), holds: holds),
            worstRunLosses: dd?.losses,
            worstRunDrawdownPct: dd?.drawdownPct,
            riskFraction: fraction)
    }

    /// A short, ordered, copyable action list built from the summary — best bet, fastest,
    /// est. weekly, and a hard risk rule. Every line is hedged; it is NOT advice.
    nonisolated static func playbook(_ s: MoneyVelocitySummary) -> String {
        var lines = ["Money-velocity playbook — estimates, not advice. Size every entry with a stop."]
        var n = 1
        if let sym = s.bestSymbol, let ev = s.bestEV {
            lines.append("\(n). Best bet now: \(sym) — est. EV \(String(format: "%+.2f", ev))R. Enter only with a defined stop.")
            n += 1
        }
        if let sym = s.fastestSymbol, let v = s.fastestVelocity {
            lines.append("\(n). Fastest compounding: \(sym) — est. \(String(format: "%+.2f", v))R/day (faster turnover, more variance).")
            n += 1
        }
        if let wk = s.weeklyR {
            lines.append("\(n). Run the top setups: ~\(String(format: "%+.1f", wk))R/week — an estimate assuming you take and re-cycle them, not income.")
            n += 1
        }
        if let losses = s.worstRunLosses, let dd = s.worstRunDrawdownPct {
            let pct = Int((s.riskFraction * 100).rounded())
            lines.append("\(n). Risk control: your worst run (\(losses)) at \(pct)%/trade ≈ −\(String(format: "%.1f", dd * 100))%. Keep risk small enough to survive it.")
            n += 1
        }
        lines.append("\(n). Rule: risk ≤1% per trade, always a stop, never chase. Speed compounds only if you stay in the game.")
        return lines.joined(separator: "\n")
    }

    /// Concentration of the top fast-lane setups by asset class. Chasing velocity
    /// (shortest holds) tends to pile into crypto — so the "diversification" of the
    /// fast lane can be an illusion. `isConcentrated` = the top-N are ALL one class.
    nonisolated static func fastLaneConcentration(_ ideas: [StockSageIdea], topN: Int = 3,
                                                  holds: VelocityHoldDays = .defaults) -> FastLaneConcentration? {
        let top = Array(fastLane(ideas, holds: holds).prefix(Swift.max(0, topN)))
        guard top.count >= 2 else { return nil }
        let counts = Dictionary(grouping: top.map { StockSageAllocation.assetClass($0.symbol) }, by: { $0 })
            .mapValues(\.count)
        guard let dominant = counts.max(by: { $0.value < $1.value }) else { return nil }
        return FastLaneConcentration(dominantClass: dominant.key, count: dominant.value, total: top.count)
    }

    nonisolated static let caveat =
        "EV uses an ESTIMATED win probability from conviction (not a real probability) and a −1R loss. It ranks payoff, it doesn't predict it — size with the cap and a stop."
}
