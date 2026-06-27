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
    /// Conviction (0–1) → an estimated win probability. With a fitted `calibration` (learned from
    /// realized outcomes) it returns the MEASURED, conservative win rate for that conviction band;
    /// without one it falls back to the conservative linear prior (0 → 35%, 1 → 58%). conviction is
    /// a signal-strength ordinal, NOT inherently a probability — the calibration is what earns the
    /// right to treat it as one.
    nonisolated static func winProbEstimate(conviction: Double,
                                            calibration: StockSageConvictionCalibration? = nil) -> Double {
        if let calibration { return calibration.winProb(conviction) }
        return 0.35 + Swift.max(0, Swift.min(1, conviction)) * 0.23
    }

    /// Expected value in R: pWin·rewardR − (1−pWin)·1. nil if there's no defined
    /// risk or reward (entry==stop or no target). Pass `calibration` to size on a measured
    /// win rate instead of the linear prior.
    nonisolated static func ev(conviction: Double, entry: Double, stop: Double, target: Double,
                               calibration: StockSageConvictionCalibration? = nil) -> ExpectedValue? {
        let risk = abs(entry - stop), reward = abs(target - entry)
        guard risk > 0, reward > 0 else { return nil }
        // Cap reward:risk at a sane ceiling. A hair-thin stop (risk → 0) otherwise makes rewardR
        // unbounded, which overruns the FIXED regime/cost/conviction demotion constants in the rank
        // key (−1_000_000 / −500_000 / −1000) and lets a BANNED side rank #1. No real setup exceeds
        // 50:1 reward:risk; beyond it the stop is degenerate, not a genuine edge.
        let rewardR = Swift.min(reward / risk, 50)
        let p = winProbEstimate(conviction: conviction, calibration: calibration)
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

    /// SETUP-derived expected hold: distance-to-target ÷ the name's typical daily move (from its
    /// recent sparkline). A NEARER target turns over faster than a far one of equal EV — the real
    /// driver of compounding cadence, which a single per-class constant is blind to. Falls back to
    /// the asset-class default when the target or a daily-move estimate is missing, and is clamped
    /// to a sane band around that default so a noisy spark can't yield a 0.1-day or 500-day fantasy.
    /// nil for classes not ranked for velocity (index/FX) — unchanged.
    nonisolated static func expectedHoldDays(for idea: StockSageIdea, holds: VelocityHoldDays = .defaults) -> Double? {
        guard let base = expectedHoldDays(forSymbol: idea.symbol, holds: holds) else { return nil }
        // Prefer the TRUE daily move (raw closes); fall back to the spark (≈2-day spacing, so only
        // used for ideas built without dailyMove, e.g. tests) — never derive a "daily" move from the
        // down-sampled spark when the real one is available, which would halve the hold (2× velocity).
        guard let target = idea.advice.targetPrice, idea.price > 0,
              let daily = idea.dailyMove ?? typicalDailyMove(idea.spark), daily > 0 else { return base }
        let dist = abs(target - idea.price)
        guard dist > 0 else { return base }
        return Swift.max(base * 0.4, Swift.min(base * 3, dist / daily))
    }

    /// Typical one-day move = average absolute close-to-close change of a sparkline. nil if too short.
    nonisolated static func typicalDailyMove(_ spark: [Double]) -> Double? {
        guard spark.count >= 3 else { return nil }
        var sum = 0.0
        for i in 1..<spark.count { sum += abs(spark[i] - spark[i - 1]) }
        let avg = sum / Double(spark.count - 1)
        return avg > 0 ? avg : nil
    }

    /// Velocity = EV ÷ expected hold = expected R PER DAY, so a fast-turnover setup
    /// beats a slow swing of equal EV (more compounding cycles). nil if no EV or no
    /// hold estimate. An estimate on an estimate — the UI says so.
    nonisolated static func velocity(for idea: StockSageIdea, holds: VelocityHoldDays = .defaults,
                                     calibration: StockSageConvictionCalibration? = nil) -> Double? {
        guard let e = ev(for: idea, calibration: calibration),
              let hold = expectedHoldDays(for: idea, holds: holds), hold > 0 else { return nil }
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
    nonisolated static func qualityAdjustedEVR(for idea: StockSageIdea,
                                               calibration: StockSageConvictionCalibration? = nil) -> Double? {
        ev(for: idea, calibration: calibration).map { $0.evR * qualityWeight(idea.advice.conviction) }
    }

    /// Expected per-CYCLE log-growth at half-Kelly — the growth-rate-optimal objective. Arithmetic
    /// EV (p·R − (1−p)) is variance-blind: it over-ranks high-R, low-probability lottery setups,
    /// whose −1 outcome at a meaningful bet fraction craters compound growth. Log-growth
    /// (E[ln(1 + f·outcome)] at f = half-Kelly) penalizes that, so ranking by it favors steady
    /// compounders — exactly "make money fastest" = maximize growth RATE, not arithmetic expectancy.
    /// 0 when there's no positive-edge bet.
    nonisolated static func expectedLogGrowth(winProb: Double, rewardR: Double) -> Double {
        let w = Swift.max(0, Swift.min(1, winProb))
        let r = Swift.max(0.0001, rewardR)
        let f = Swift.max(0, Swift.min(0.5, (w - (1 - w) / r) / 2))   // half-Kelly risk fraction, capped
        guard f > 0 else { return 0 }
        let up = 1 + f * r, down = 1 - f
        guard up > 0, down > 0 else { return 0 }
        return w * Foundation.log(up) + (1 - w) * Foundation.log(down)
    }
    /// Does the idea's conviction-mapped win prob clear its AFTER-COST break-even? A thin,
    /// high-cost flip can be positive-EV on paper yet net-negative once frictions are paid.
    /// No defined R (no stop/target) ⇒ treated as clearing (don't demote — unchanged).
    private nonisolated static func clearsCostAfterFrictions(_ idea: StockSageIdea,
                                                             calibration: StockSageConvictionCalibration? = nil) -> Bool {
        guard let stop = idea.advice.stopPrice, let target = idea.advice.targetPrice else { return true }
        let c = StockSageNetEdge.defaultCosts(forSymbol: idea.symbol)
        guard let ne = StockSageNetEdge.evaluate(entry: idea.price, stop: stop, target: target,
                                                 spreadBps: c.spreadBps, slippageBps: c.slippageBps,
                                                 takerFeeBps: c.takerFeeBps) else { return true }
        // Gate on the SAME win prob the EV/ranking uses (calibrated when fitted) — not the linear prior,
        // which would demote-for-cost on a different probability than the one shown.
        return ne.clearsCost(estWinProb: winProbEstimate(conviction: idea.advice.conviction, calibration: calibration))
    }

    // ── [AUDIT] Net-of-cost EV/day velocity helpers (iter6) ──────────────────────────────────────
    //
    // These five helpers (constant + 3 functions + enum) are the ONLY new surface from iter6.
    // They reuse StockSageNetEdge.evaluate(...).netExpectancyR — the existing net-edge model —
    // so cost is subtracted from EV BEFORE the /hold_days, replacing the binary pass/fail gate.
    // All are nonisolated + Sendable; nil only on no-defined-R (same guard as ev(for:)).

    /// [AUDIT] Minimum NET-of-cost EV/day to surface an idea as a buy on the velocity board.
    /// 0.005R/day = +0.5% of 1R per day. Justification (conservative, honestly chosen):
    ///   • A retail account risking 1%/trade earns 0.005R/day ≈ 0.005% of equity/day on that
    ///     slot — at ~250 trading days that is ~1.25R/yr of pure edge AFTER frictions, the floor
    ///     below which a slot is "dead money" the churn (Barber&Odean −7.1pp/yr) overwhelms.
    ///   • Set on the NET (post-cost) per-day rate, NOT gross, so it bites exactly the
    ///     churny-short-hold ideas the gross sort over-ranks.
    ///   • Deliberately LOW (not a profitability hurdle) so it only skips barely-positive
    ///     dregs — must NOT hide a genuinely high-net idea (Guardrail 2). A slow high-net
    ///     swing clears it by orders of magnitude.
    nonisolated static let minNetEVPerDayFloor = 0.005

    /// [AUDIT] NET-of-cost expected R for an idea: round-trip frictions (spread+slippage+taker,
    /// from StockSageNetEdge.defaultCosts) subtracted from the reward AND added to the risk via
    /// StockSageNetEdge.evaluate(...).netExpectancyR — the EXISTING net edge model, not a new one.
    /// Win prob is the SAME conviction-mapped (calibrated) estimate the gross EV uses, so net and
    /// gross are computed on one probability. nil when there's no defined R (no stop/target) OR the
    /// gross setup is degenerate — the only nil-fallback path.
    nonisolated static func netEVR(for idea: StockSageIdea,
                                   calibration: StockSageConvictionCalibration? = nil) -> Double? {
        guard let stop = idea.advice.stopPrice, let target = idea.advice.targetPrice else { return nil }
        let c = StockSageNetEdge.defaultCosts(forSymbol: idea.symbol)
        let p = winProbEstimate(conviction: idea.advice.conviction, calibration: calibration)
        return StockSageNetEdge.evaluate(entry: idea.price, stop: stop, target: target,
                                         spreadBps: c.spreadBps, slippageBps: c.slippageBps,
                                         takerFeeBps: c.takerFeeBps, winProb: p)?.netExpectancyR
    }

    /// [AUDIT] NET EV/day = net-of-cost EV ÷ expected hold. The honest velocity rate after frictions.
    /// nil when there's no net EV or no hold estimate (index/FX). When cost data nets to nothing
    /// (cost == 0) this equals the gross velocity exactly (Guardrail 4: net==gross when cost=0).
    nonisolated static func netVelocity(for idea: StockSageIdea, holds: VelocityHoldDays = .defaults,
                                        calibration: StockSageConvictionCalibration? = nil) -> Double? {
        guard let ne = netEVR(for: idea, calibration: calibration),
              let hold = expectedHoldDays(for: idea, holds: holds), hold > 0 else { return nil }   // [AUDIT] hold→0 guarded
        return ne / hold
    }

    /// [AUDIT] Is the idea's NET EV/day strictly below the floor? At-floor (==) counts as PASSING
    /// (>= floor) — "below" means strictly under. Ideas with no net velocity (no R / no hold) are
    /// treated as not-below (nil ⇒ the gross path's nil handling already sinks them last; this
    /// floor never resurrects nor newly-buries a nil-key idea).
    nonisolated static func belowNetCostFloor(for idea: StockSageIdea, holds: VelocityHoldDays = .defaults,
                                              calibration: StockSageConvictionCalibration? = nil) -> Bool {
        guard let nv = netVelocity(for: idea, holds: holds, calibration: calibration) else { return false }
        return nv < minNetEVPerDayFloor   // [AUDIT] exactly-at-floor → false (passes)
    }

    /// [AUDIT] Legible companion to the floor de-rank, mirroring earningsRankFlag's pattern so the
    /// on-card badge can never disagree with the actual rank shift. `.belowFloor` fires EXACTLY when
    /// belowNetCostFloor is true.
    enum NetCostFloorFlag: Sendable, Equatable {
        case belowFloor(netVelocity: Double)   // de-ranked: net EV/day under the floor
        case clears                            // at/above floor (or no defined net velocity)
        nonisolated var isDeranked: Bool { if case .belowFloor = self { return true }; return false }
        var badge: String {
            if case .belowFloor = self { return "below net-cost floor" }
            return ""
        }
    }

    nonisolated static func netCostFloorFlag(for idea: StockSageIdea, holds: VelocityHoldDays = .defaults,
                                             calibration: StockSageConvictionCalibration? = nil) -> NetCostFloorFlag {
        guard let nv = netVelocity(for: idea, holds: holds, calibration: calibration),
              nv < minNetEVPerDayFloor else { return .clears }
        return .belowFloor(netVelocity: nv)
    }

    // ─────────────────────────────────────────────────────────────────────────────────────────────

    /// Imminent-earnings (binary-event) demotion for the rank keys. ONLY a real fetched `.imminent`
    /// date (≤3 days) is penalized — an UNKNOWN symbol (no map entry) and `.soon`/`.clear` return 0,
    /// so absence is never assumed dangerous (only-real-data). 2000 sits above the conviction band
    /// (1000) and the max base EV (~28.6) but below the cost (500k) and regime (1M) bands — so an
    /// imminent-earnings idea sinks below every clean same-or-lower-EV peer, yet still ranks above a
    /// cost-failed or regime-banned one. The DISPLAYED EV/velocity never changes — only the rank key.
    /// Rationale: a protective stop is an intraday promise an overnight earnings gap opens through;
    /// ranking such an idea #1 the night before it reports puts the biggest position where the stop
    /// is least likely to hold. The per-idea EarningsProximity.note stays the load-bearing disclosure.
    nonisolated static func earningsRankPenalty(for idea: StockSageIdea,
                                                earnings: [String: EarningsProximity]) -> Double {
        guard let prox = earnings[idea.symbol.uppercased()] else { return 0 }   // unknown → not penalized
        return prox.severity == .imminent ? 2000 : 0
    }

    /// Why an idea sits where it does on the earnings-aware board — the legible companion to
    /// earningsRankPenalty, so the silent re-order shows its reason. Reads the SAME cached
    /// EarningsProximity (no Date math, no network). `isDemoted` mirrors `earningsRankPenalty > 0` exactly,
    /// so the on-card badge can never disagree with the actual rank shift.
    enum EarningsRankFlag: Sendable, Equatable {
        case demoted(daysUntil: Int)      // .imminent (≤3d) — the penalized, ranked-down case
        case approaching(daysUntil: Int)  // .soon (≤10d) — event risk nearing, not yet penalized
        case clear(daysUntil: Int)        // .clear (>10d) — no immediate event risk
        case unknown                      // no fetched date (or not equity) — never assumed dangerous

        var isDemoted: Bool { if case .demoted = self { return true }; return false }
        /// Short on-card badge; empty for the quiet clear/unknown cases (nothing to surface).
        var badge: String {
            switch self {
            case .demoted(let d):     return "⚠︎ earnings ~\(d)d"
            case .approaching(let d): return "earnings ~\(d)d"
            case .clear, .unknown:    return ""
            }
        }
    }

    nonisolated static func earningsRankFlag(for idea: StockSageIdea,
                                             earnings: [String: EarningsProximity]) -> EarningsRankFlag {
        guard let prox = earnings[idea.symbol.uppercased()] else { return .unknown }
        switch prox.severity {
        case .imminent: return .demoted(daysUntil: prox.daysUntil)
        case .soon:     return .approaching(daysUntil: prox.daysUntil)
        case .clear:    return .clear(daysUntil: prox.daysUntil)
        }
    }

    private nonisolated static func evRankKey(for idea: StockSageIdea,
                                              calibration: StockSageConvictionCalibration? = nil) -> Double? {
        guard let base = qualityAdjustedEVR(for: idea, calibration: calibration) else { return nil }
        var key = base
        if idea.advice.conviction < minConvictionToRank { key -= 1000 }       // low-conviction band
        if !clearsCostAfterFrictions(idea, calibration: calibration) { key -= 500_000 }   // costs eat the edge → below clean setups
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
    private nonisolated static func regimeAdjustedEVRankKey(for idea: StockSageIdea, regime: MarketRegime?,
                                                            calibration: StockSageConvictionCalibration? = nil) -> Double? {
        guard let base = evRankKey(for: idea, calibration: calibration) else { return nil }   // nil-EV ideas still fall last
        guard let r = regime else { return base }                   // nil regime → IDENTICAL to today
        return bannedFromTopRank(side(idea), regime: r.state) ? base - 1_000_000 : base
    }
    private nonisolated static func velocityRankKey(for idea: StockSageIdea, holds: VelocityHoldDays,
                                                    calibration: StockSageConvictionCalibration? = nil) -> Double? {
        // Velocity is the BUY-side compounding lane (matches bestOpportunity / CapitalAllocator) —
        // a short does not compound the same way, so only buy-family ideas qualify. (Fixes a short
        // topping the Fast Lane while it is correctly barred from the best-opportunity card.)
        guard case .buyFamily = side(idea) else { return nil }
        // Rank by per-DAY LOG-GROWTH (growth-rate-optimal), not arithmetic EV/day — so a steady
        // compounder beats a high-variance lottery setup of equal raw EV. Displayed velocity is
        // still EV/day; this is only the ordering key.
        guard let e = ev(for: idea, calibration: calibration),
              let hold = expectedHoldDays(for: idea, holds: holds), hold > 0 else { return nil }
        // [AUDIT] NET-of-cost ordering (iter6): rank by per-day log-growth scaled by the NET/gross
        // EV ratio, so round-trip frictions (StockSageNetEdge) shrink the rate CONTINUOUSLY —
        // a churny flip whose gross EV survives but whose NET EV is thin now sorts BELOW a slower
        // high-net idea, instead of keeping its full gross velocity behind a binary pass/fail.
        // Log-growth stays the growth-rate-optimal core; the net ratio is the cost haircut.
        let grossLG = expectedLogGrowth(winProb: e.winProbEstimate, rewardR: e.rewardR)
        let netRatio: Double = {                                  // [AUDIT] net EV ÷ gross EV, clamped ≥ 0
            guard let ne = netEVR(for: idea, calibration: calibration), e.evR > 0 else { return 1 }  // [AUDIT] no net data ⇒ ratio 1 (=gross)
            return Swift.max(0, ne / e.evR)                       // [AUDIT] net≤0 ⇒ ratio 0 ⇒ key 0 (below every +rate peer)
        }()
        let v = grossLG * netRatio / hold                         // [AUDIT] PROXY for net per-day log-growth: gross log-growth scaled by netEV/grossEV arithmetic-cost haircut (not true net log-growth, but correct for ranking).
        // [AUDIT] Min net-EV/day FLOOR: a barely-positive-gross churn idea whose NET EV/day is
        // under the floor is de-ranked below clean setups (−500_000) so it cannot top the board.
        // The old clearsCostAfterFrictions binary gate is SUBSUMED: anything net≤0 has ratio=0
        // ⇒ key=0, and the floor (< 0.005) then adds the −500_000 de-rank. Nothing previously
        // demoted is resurrected. Honest companion label via netCostFloorFlag(for:).
        if belowNetCostFloor(for: idea, holds: holds, calibration: calibration) { return v - 500_000 }
        return idea.advice.conviction >= minConvictionToRank ? v : v - 1000
    }

    nonisolated static func rankByVelocity(_ ideas: [StockSageIdea], holds: VelocityHoldDays = .defaults,
                                           earnings: [String: EarningsProximity] = [:],
                                           calibration: StockSageConvictionCalibration? = nil) -> [StockSageIdea] {
        // Demote imminent-earnings ideas inside the velocity key (empty earnings → 0 → unchanged order).
        func key(_ idea: StockSageIdea) -> Double? {
            velocityRankKey(for: idea, holds: holds, calibration: calibration).map { $0 - earningsRankPenalty(for: idea, earnings: earnings) }
        }
        return ideas.enumerated().sorted { a, b in
            switch (key(a.element), key(b.element)) {
            case let (x?, y?): return x == y ? a.offset < b.offset : x > y
            case (_?, nil): return true
            case (nil, _?): return false
            case (nil, nil): return a.offset < b.offset
            }
        }.map(\.element)
    }

    /// EV for a ranked idea, or nil when it lacks a stop/target (no defined R:R).
    nonisolated static func ev(for idea: StockSageIdea,
                               calibration: StockSageConvictionCalibration? = nil) -> ExpectedValue? {
        guard let stop = idea.advice.stopPrice, let target = idea.advice.targetPrice else { return nil }
        return ev(conviction: idea.advice.conviction, entry: idea.price, stop: stop, target: target,
                  calibration: calibration)
    }

    /// Ideas sorted by EV (best bet first). Ideas without a defined EV fall to the
    /// bottom keeping their original relative order (stable).
    nonisolated static func rankByEV(_ ideas: [StockSageIdea], regime: MarketRegime? = nil,
                                     earnings: [String: EarningsProximity] = [:],
                                     calibration: StockSageConvictionCalibration? = nil) -> [StockSageIdea] {
        // Demote imminent-earnings ideas inside the EV key (empty earnings → 0 → unchanged order).
        func key(_ idea: StockSageIdea) -> Double? {
            regimeAdjustedEVRankKey(for: idea, regime: regime, calibration: calibration).map { $0 - earningsRankPenalty(for: idea, earnings: earnings) }
        }
        return ideas.enumerated().sorted { a, b in
            switch (key(a.element), key(b.element)) {
            case let (x?, y?): return x == y ? a.offset < b.offset : x > y
            case (_?, nil): return true
            case (nil, _?): return false
            case (nil, nil): return a.offset < b.offset
            }
        }.map(\.element)
    }

    /// The single best BET right now: the buy-family idea with the highest POSITIVE
    /// expected value. nil if no buy idea has positive EV (don't manufacture one).
    nonisolated static func bestOpportunity(_ ideas: [StockSageIdea], regime: MarketRegime? = nil,
                                            earnings: [String: EarningsProximity] = [:],
                                            calibration: StockSageConvictionCalibration? = nil) -> (idea: StockSageIdea, ev: ExpectedValue)? {
        // No "best buy" in a risk-off tape — a crisis/bear is sometimes exactly when an intraday
        // stop gets gapped through. (nil regime → no gate, identical to before.)
        if let r = regime, bannedFromTopRank(.buyFamily, regime: r.state) { return nil }
        // Same earnings demotion the EV/velocity boards apply, so the "Best opportunity now" card,
        // Today tile and summary can't crown an imminent-earnings name the boards already sank
        // (empty earnings → 0 → identical to before). Demotion, not exclusion: it can still surface
        // if it's the only positive-EV buy.
        func rankVal(_ idea: StockSageIdea) -> Double {
            (qualityAdjustedEVR(for: idea, calibration: calibration) ?? 0) - earningsRankPenalty(for: idea, earnings: earnings)
        }
        return ideas.compactMap { idea -> (StockSageIdea, ExpectedValue)? in
            guard idea.advice.action == .buy || idea.advice.action == .strongBuy,
                  idea.advice.conviction >= minConvictionToRank,   // a #1 pick can't be a low-conviction bet
                  clearsCostAfterFrictions(idea, calibration: calibration),   // …nor a setup that's net-negative after costs
                  let e = ev(for: idea, calibration: calibration), e.evR > 0 else { return nil }
            return (idea, e)
        }
        .max { rankVal($0.0) < rankVal($1.0) }
        .map { (idea: $0.0, ev: $0.1) }
    }

    /// Fast lane: positive-EV ideas that HAVE a velocity (crypto/equity), ranked by
    /// velocity (EV/day) desc — the fastest-compounding opportunities. Index/FX (no
    /// hold) and non-positive-EV ideas are excluded. Faster turnover = more cycles
    /// AND more chances to be wrong; the UI carries that caveat.
    nonisolated static func fastLane(_ ideas: [StockSageIdea], holds: VelocityHoldDays = .defaults,
                                     calibration: StockSageConvictionCalibration? = nil) -> [StockSageIdea] {
        ideas.enumerated().compactMap { idx, idea -> (Int, StockSageIdea, Double)? in
            guard let e = ev(for: idea, calibration: calibration), e.evR > 0,
                  let v = velocityRankKey(for: idea, holds: holds, calibration: calibration) else { return nil }
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
                                            holds: VelocityHoldDays = .defaults,
                                            calibration: StockSageConvictionCalibration? = nil) -> Double? {
        let vels = fastLane(ideas, holds: holds, calibration: calibration).prefix(Swift.max(0, maxConcurrent)).compactMap { velocity(for: $0, holds: holds, calibration: calibration) }
        guard !vels.isEmpty else { return nil }
        return vels.reduce(0, +) * tradingDays
    }

    /// Account-aware weekly $ estimate: expected weekly R × the dollar value of 1R
    /// (account × riskFraction). nil without an account, risk, or a non-empty fast
    /// lane. An ESTIMATE that assumes you take & re-cycle the top setups — NOT income.
    nonisolated static func expectedWeeklyDollars(_ ideas: [StockSageIdea], account: Double, riskFraction: Double,
                                                  maxConcurrent: Int = 3, tradingDays: Double = 5,
                                                  holds: VelocityHoldDays = .defaults,
                                                  calibration: StockSageConvictionCalibration? = nil) -> Double? {
        guard account > 0, riskFraction > 0, account.isFinite, riskFraction.isFinite,
              let wkR = expectedWeeklyR(ideas, maxConcurrent: maxConcurrent, tradingDays: tradingDays, holds: holds, calibration: calibration) else { return nil }
        return wkR * account * riskFraction   // finite inputs → never "+$inf/week"
    }

    /// Trading days per week for the fast lane. Equities trade ~5 days; crypto is 24/7 (~7).
    /// Blends by the crypto share of the fast lane: round(5 + 2·cryptoFraction) — all-crypto → 7,
    /// equity-only → 5 (so nothing shifts for the existing equity case), 1-of-3 crypto → 6.
    /// Empty lane → 5. NOTE: more trading days ≠ more edge — crypto's extra cadence carries
    /// extra variance, which `cryptoRiskScaler` sizes DOWN for.
    nonisolated static func tradingDaysForLane(_ ideas: [StockSageIdea], holds: VelocityHoldDays = .defaults,
                                               calibration: StockSageConvictionCalibration? = nil) -> Double {
        let lane = fastLane(ideas, holds: holds, calibration: calibration)
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
                                    regime: MarketRegime? = nil,
                                    earnings: [String: EarningsProximity] = [:],
                                    calibration: StockSageConvictionCalibration? = nil) -> MoneyVelocitySummary {
        // Regime-aware so the card's displayed "best bet" matches the regime-gated nav target
        // (a risk-off tape suppresses the best-buy on BOTH). nil regime → identical to before.
        // Earnings-aware so the summary best-bet matches the demoted board (empty → unchanged).
        // Calibration-aware so every headline number (best EV, fastest velocity, weekly R) uses the
        // SAME measured win-prob as the idea cards — no calibrated-next-to-uncalibrated mismatch.
        let best = bestOpportunity(ideas, regime: regime, earnings: earnings, calibration: calibration)
        // Use rankByVelocity (earnings-aware) then skip below-floor and negative-EV ideas —
        // so the "Fastest" headline matches the board's floor-de-ranked, earnings-penalized sort.
        let fastest = rankByVelocity(ideas, holds: holds, earnings: earnings, calibration: calibration)
            .first(where: { (ev(for: $0, calibration: calibration)?.evR ?? -1) > 0
                            && !netCostFloorFlag(for: $0, holds: holds, calibration: calibration).isDeranked })
        // The brake: the owner's worst losing streak, compounded down at the risk fraction.
        let dd = StockSageJournal.equityRisk(trades)
            .flatMap { StockSageRiskOfRuin.scenario(losses: $0.maxConsecutiveLosses, fraction: fraction) }
        return MoneyVelocitySummary(
            bestSymbol: best?.idea.symbol,
            bestEV: best?.ev.evR,
            fastestSymbol: fastest?.symbol,
            fastestVelocity: fastest.flatMap { velocity(for: $0, holds: holds, calibration: calibration) },
            // Honest cadence: an all-crypto lane re-cycles ~7 days/week, equity ~5.
            weeklyR: expectedWeeklyR(ideas, tradingDays: tradingDaysForLane(ideas, holds: holds, calibration: calibration), holds: holds, calibration: calibration),
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
                                                  holds: VelocityHoldDays = .defaults,
                                                  calibration: StockSageConvictionCalibration? = nil) -> FastLaneConcentration? {
        let top = Array(fastLane(ideas, holds: holds, calibration: calibration).prefix(Swift.max(0, topN)))
        guard top.count >= 2 else { return nil }
        let counts = Dictionary(grouping: top.map { StockSageAllocation.assetClass($0.symbol) }, by: { $0 })
            .mapValues(\.count)
        guard let dominant = counts.max(by: { $0.value < $1.value }) else { return nil }
        return FastLaneConcentration(dominantClass: dominant.key, count: dominant.value, total: top.count)
    }

    nonisolated static let caveat =
        "EV uses an ESTIMATED win probability from conviction (not a real probability) and a −1R loss. It ranks payoff, it doesn't predict it — size with the cap and a stop."
}
