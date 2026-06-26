import Testing
import Foundation
@testable import Salehman_AI

// MARK: - Expected value (pure)

struct StockSageExpectedValueTests {

    typealias EV = StockSageExpectedValue

    @Test func winProbBandIsConservative() {
        #expect(abs(EV.winProbEstimate(conviction: 0) - 0.35) < 1e-9)
        #expect(abs(EV.winProbEstimate(conviction: 1) - 0.58) < 1e-9)
        #expect(EV.winProbEstimate(conviction: 5) == 0.58)    // clamped
        #expect(EV.winProbEstimate(conviction: -1) == 0.35)   // clamped
    }

    @Test func evCombinesProbabilityAndReward() {
        // conviction 1 → p 0.58; R:R = 20/10 = 2 → EV = 0.58·2 − 0.42 = 0.74.
        let high = EV.ev(conviction: 1, entry: 100, stop: 90, target: 120)!
        #expect(abs(high.rewardR - 2) < 1e-9)
        #expect(abs(high.evR - 0.74) < 1e-9)
        #expect(high.isPositive)
        // conviction 0 → p 0.35; same 2:1 → EV = 0.70 − 0.65 = 0.05 (barely positive).
        let low = EV.ev(conviction: 0, entry: 100, stop: 90, target: 120)!
        #expect(abs(low.evR - 0.05) < 1e-9)
        // A higher-EV setup ranks above a lower one.
        #expect(high.evR > low.evR)
    }

    @Test func noDefinedRiskOrRewardIsNil() {
        #expect(EV.ev(conviction: 0.8, entry: 100, stop: 100, target: 120) == nil)   // no risk
        #expect(EV.ev(conviction: 0.8, entry: 100, stop: 90, target: 100) == nil)    // no reward
    }

    private func idea(_ symbol: String, action: TradeAdvice.Action = .buy, conviction: Double,
                      stop: Double?, target: Double?) -> StockSageIdea {
        StockSageIdea(symbol: symbol, market: "M", price: 100,
                      advice: TradeAdvice(action: action, conviction: conviction, regime: .bullTrend, rationale: [],
                                          stopPrice: stop, targetPrice: target, suggestedWeight: 0.05, caveat: "x"),
                      spark: [])
    }

    @Test func velocityRewardsFastTurnover() {
        // Same EV (1.228), but crypto hold 3 beats equity hold 12.
        let equity = idea("AAPL", conviction: 0.9, stop: 90, target: 130)
        let crypto = idea("BTC-USD", conviction: 0.9, stop: 90, target: 130)
        let ve = EV.velocity(for: equity)!, vc = EV.velocity(for: crypto)!
        #expect(abs(ve - 1.228 / 12) < 1e-9)
        #expect(abs(vc - 1.228 / 3) < 1e-9)
        #expect(vc > ve)
        #expect(EV.expectedHoldDays(forSymbol: "^GSPC") == nil)                            // index → no velocity
        #expect(EV.velocity(for: idea("EURUSD=X", conviction: 0.9, stop: 90, target: 130)) == nil)
    }

    @Test func fastLaneEmptyWhenNoVelocity() {
        // Index/FX have no asset-class hold → no velocity → excluded from every velocity surface.
        let idx = idea("^GSPC", conviction: 0.9, stop: 90, target: 130)
        let fx = idea("EURUSD=X", conviction: 0.9, stop: 90, target: 130)
        #expect(EV.fastLane([idx, fx]).isEmpty)
        #expect(EV.expectedWeeklyR([idx, fx]) == nil)
        #expect(EV.fastLaneConcentration([idx, fx]) == nil)
    }

    @Test func fastLaneRanksByVelocityCryptoFirst() {
        let equity = idea("AAPL", conviction: 0.9, stop: 90, target: 130)    // EV 1.228, vel 0.1023
        let crypto = idea("BTC-USD", conviction: 0.9, stop: 90, target: 130) // EV 1.228, vel 0.4093
        let index = idea("^GSPC", conviction: 0.9, stop: 90, target: 130)    // EV but no velocity → excluded
        let neg = idea("D", conviction: 0.0, stop: 90, target: 110)          // EV −0.30 → excluded
        let lane = EV.fastLane([equity, index, neg, crypto])
        #expect(lane.map(\.symbol) == ["BTC-USD", "AAPL"])                    // crypto first (faster turnover)
    }

    @Test func imminentEarningsDemotesInTheRank() {
        // Two identical equity buys — only the earnings calendar differs.
        let a = idea("AAPL", conviction: 0.8, stop: 98, target: 110)
        let b = idea("MSFT", conviction: 0.8, stop: 98, target: 110)
        // No earnings data → original order preserved on BOTH boards (byte-stable default).
        #expect(EV.rankByEV([a, b]).map(\.symbol) == ["AAPL", "MSFT"])
        #expect(EV.rankByVelocity([a, b]).map(\.symbol) == ["AAPL", "MSFT"])
        // AAPL reports in 2 days (imminent — a stop may gap through it); MSFT in 30 (clear).
        let earnings: [String: EarningsProximity] = [
            "AAPL": EarningsProximity(daysUntil: 2, severity: .imminent),
            "MSFT": EarningsProximity(daysUntil: 30, severity: .clear),
        ]
        #expect(EV.rankByEV([a, b], earnings: earnings).map(\.symbol) == ["MSFT", "AAPL"])       // imminent sinks
        #expect(EV.rankByVelocity([a, b], earnings: earnings).map(\.symbol) == ["MSFT", "AAPL"])
        // The penalty fires ONLY on a real .imminent date — unknown / .soon / .clear are 0 (only-real-data).
        #expect(EV.earningsRankPenalty(for: a, earnings: earnings) == 2000)
        #expect(EV.earningsRankPenalty(for: b, earnings: earnings) == 0)                          // .clear → 0
        #expect(EV.earningsRankPenalty(for: a, earnings: [:]) == 0)                               // unknown → 0
        #expect(EV.earningsRankPenalty(for: a, earnings: ["AAPL": EarningsProximity(daysUntil: 7, severity: .soon)]) == 0)
        // Band invariant the constant relies on: above conviction(1000)+maxEV, below cost(500k)/regime(1M).
        #expect(1000 + 50.0 < 2000 && 2000 < 500_000 && 500_000 < 1_000_000)
    }

    @Test func earningsRankFlagExplainsTheDemotion() {
        typealias Flag = EV.EarningsRankFlag
        let earnings: [String: EarningsProximity] = [
            "AAPL": EarningsProximity(daysUntil: 2, severity: .imminent),
            "MSFT": EarningsProximity(daysUntil: 7, severity: .soon),
            "NVDA": EarningsProximity(daysUntil: 40, severity: .clear),
        ]
        #expect(EV.earningsRankFlag(for: idea("AAPL", conviction: 0.8, stop: 98, target: 110), earnings: earnings) == .demoted(daysUntil: 2))
        #expect(EV.earningsRankFlag(for: idea("MSFT", conviction: 0.8, stop: 98, target: 110), earnings: earnings) == .approaching(daysUntil: 7))
        #expect(EV.earningsRankFlag(for: idea("NVDA", conviction: 0.8, stop: 98, target: 110), earnings: earnings) == .clear(daysUntil: 40))
        #expect(EV.earningsRankFlag(for: idea("TSLA", conviction: 0.8, stop: 98, target: 110), earnings: earnings) == .unknown)   // no date → unknown
        // isDemoted mirrors earningsRankPenalty > 0 exactly — the badge can never disagree with the rank shift.
        #expect(Flag.demoted(daysUntil: 2).isDemoted)
        #expect(!Flag.approaching(daysUntil: 7).isDemoted && !Flag.clear(daysUntil: 40).isDemoted && !Flag.unknown.isDemoted)
        // Badge surfaces only the actionable cases (imminent/approaching); clear + unknown are quiet.
        #expect(!Flag.demoted(daysUntil: 2).badge.isEmpty && !Flag.approaching(daysUntil: 7).badge.isEmpty)
        #expect(Flag.clear(daysUntil: 40).badge.isEmpty && Flag.unknown.badge.isEmpty)
    }

    @Test func velocityLaneIsBuyOnly() {
        // A SHORT with a valid positive-EV 2:1 setup must NOT enter the velocity / Fast Lane (it
        // cannot compound like a long, and the best-opportunity card already bars it) — even though
        // its evR > 0 would have passed the old gross-EV gate.
        let buy  = idea("BTC-USD", action: .strongBuy, conviction: 0.9, stop: 90, target: 130)
        let sell = idea("ETH-USD", action: .sell, conviction: 0.9, stop: 110, target: 80)
        #expect(EV.ev(for: sell).map { $0.evR > 0 } == true)               // the short IS positive-EV…
        #expect(EV.fastLane([buy, sell]).map(\.symbol) == ["BTC-USD"])      // …yet excluded from the lane
        #expect(EV.rankByVelocity([sell, buy]).first?.symbol == "BTC-USD") // and falls last in velocity rank
    }

    @Test func expectedWeeklyRSumsTopVelocities() {
        let equity = idea("AAPL", conviction: 0.9, stop: 90, target: 130)    // vel 1.228/12
        let crypto = idea("BTC-USD", conviction: 0.9, stop: 90, target: 130) // vel 1.228/3
        let index = idea("^GSPC", conviction: 0.9, stop: 90, target: 130)    // no velocity → excluded
        // fast lane = [crypto, equity]; sum = 1.228/3 + 1.228/12; × 5 trading days.
        let wk = EV.expectedWeeklyR([equity, index, crypto], maxConcurrent: 3, tradingDays: 5)!
        let expected = (1.228 / 3 + 1.228 / 12) * 5
        #expect(abs(wk - expected) < 1e-9)
        #expect(abs(wk - 2.5583333333) < 1e-6)
        #expect(EV.expectedWeeklyR([index]) == nil)                          // empty fast lane → nil
        #expect(EV.expectedWeeklyR([crypto], maxConcurrent: 0) == nil)       // no slots → nil (no crash)
    }

    @Test func expectedWeeklyDollarsScalesWeeklyRByRiskDollar() {
        let equity = idea("AAPL", conviction: 0.9, stop: 90, target: 130)
        let crypto = idea("BTC-USD", conviction: 0.9, stop: 90, target: 130)
        // weekly-R = (1.228/3 + 1.228/12)·5 ; $ per 1R = 10000·0.01 = 100.
        let dollars = EV.expectedWeeklyDollars([equity, crypto], account: 10000, riskFraction: 0.01)!
        let wkR = (1.228 / 3 + 1.228 / 12) * 5
        #expect(abs(dollars - wkR * 100) < 1e-6)
        #expect(abs(dollars - 255.8333333) < 1e-4)
        #expect(EV.expectedWeeklyDollars([equity, crypto], account: 0, riskFraction: 0.01) == nil)  // no account
        #expect(EV.expectedWeeklyDollars([], account: 10000, riskFraction: 0.01) == nil)            // empty fast lane
    }

    @Test func summaryComposesBestFastestAndWeeklyR() {
        let a = idea("A", action: .buy, conviction: 0.2, stop: 90, target: 120)            // EV 0.188
        let b = idea("BTC-USD", action: .strongBuy, conviction: 0.9, stop: 90, target: 130) // EV 1.228, vel 1.228/3
        let s = EV.summary([a, b])
        #expect(s.bestSymbol == "BTC-USD")                       // highest positive-EV buy
        #expect(abs((s.bestEV ?? 0) - 1.228) < 1e-9)
        #expect(s.fastestSymbol == "BTC-USD")                    // highest velocity
        #expect(abs((s.fastestVelocity ?? 0) - 1.228 / 3) < 1e-9)
        #expect(s.weeklyR != nil)
        #expect(s.hasContent)
        #expect(!EV.summary([]).hasContent)                      // empty → nothing to show
    }

    @Test func summaryIncludesWorstRunDrawdownBrake() {
        let b = idea("BTC-USD", action: .strongBuy, conviction: 0.9, stop: 90, target: 130)
        // 3 closed losers in a row → worst run 3; at 1%/trade → 1 − 0.99^3 = 0.029701.
        let losers = (0..<3).map { i in
            TradeRecord(symbol: "X", side: .long, entry: 100, stop: 90, target: nil, shares: 1,
                        openedAt: Date(timeIntervalSince1970: Double(i) * 100),
                        exitPrice: 95, closedAt: Date(timeIntervalSince1970: Double(i) * 100 + 50))
        }
        let s = EV.summary([b], trades: losers)
        #expect(s.worstRunLosses == 3)
        #expect(abs((s.worstRunDrawdownPct ?? 0) - (1 - pow(0.99, 3))) < 1e-9)
        #expect(EV.summary([b]).worstRunDrawdownPct == nil)      // no trades → no brake
    }

    @Test func velocityRespectsTunableHoldDays() {
        let crypto = idea("BTC-USD", conviction: 0.9, stop: 90, target: 130)   // EV 1.228
        let base = EV.velocity(for: crypto)!                                   // default crypto 3 → 1.228/3
        let slower = EV.velocity(for: crypto, holds: VelocityHoldDays(crypto: 6, equity: 12))!  // → 1.228/6
        #expect(abs(base - 1.228 / 3) < 1e-9)
        #expect(abs(slower - 1.228 / 6) < 1e-9)
        #expect(base > slower)                                                 // shorter hold = higher velocity
        #expect(EV.expectedHoldDays(forSymbol: "BTC-USD") == 3)                // default unchanged
        #expect(EV.expectedHoldDays(forSymbol: "BTC-USD", holds: VelocityHoldDays(crypto: 6, equity: 12)) == 6)
    }

    @Test func playbookListsBestFastestWeeklyAndRisk() {
        let s = MoneyVelocitySummary(bestSymbol: "NVDA", bestEV: 0.74, fastestSymbol: "BTC-USD",
                                     fastestVelocity: 0.41, weeklyR: 2.6, worstRunLosses: 6, worstRunDrawdownPct: 0.059)
        let plan = EV.playbook(s)
        #expect(plan.contains("NVDA"))
        #expect(plan.contains("BTC-USD"))
        #expect(plan.contains("+0.74"))
        #expect(plan.contains("week"))
        #expect(plan.contains("stop"))                       // honesty: always a stop
        #expect(plan.lowercased().contains("estimate"))      // honesty: labeled estimate
        #expect(plan.contains("1.") && plan.contains("2."))  // numbered, ordered
        #expect(plan.contains("1%/trade"))                   // default fraction → 1% label
        // The brake LABEL must track the modeled fraction, never drift (honesty floor).
        let at2 = MoneyVelocitySummary(worstRunLosses: 6, worstRunDrawdownPct: 0.118, riskFraction: 0.02)
        #expect(EV.playbook(at2).contains("2%/trade"))
        #expect(!EV.playbook(at2).contains("1%/trade"))
        // Empty summary → just the header + the risk rule, still honest.
        let empty = EV.playbook(MoneyVelocitySummary(bestSymbol: nil, bestEV: nil, fastestSymbol: nil,
                                                     fastestVelocity: nil, weeklyR: nil, worstRunLosses: nil, worstRunDrawdownPct: nil))
        #expect(empty.contains("stop"))
        #expect(empty.contains("1."))
    }

    @Test func tradingDaysForLaneBlendsByCryptoShare() {
        let btc  = idea("BTC-USD", conviction: 0.9, stop: 90, target: 130)
        let eth  = idea("ETH-USD", conviction: 0.9, stop: 90, target: 130)
        let aapl = idea("AAPL", conviction: 0.9, stop: 90, target: 130)
        let msft = idea("MSFT", conviction: 0.9, stop: 90, target: 130)
        #expect(EV.tradingDaysForLane([btc, eth]) == 7)            // all crypto → 7-day week
        #expect(EV.tradingDaysForLane([aapl, msft]) == 5)          // equity only → unchanged 5
        #expect(EV.tradingDaysForLane([btc, aapl, msft]) == 6)     // 1/3 crypto → round(5 + 0.667) = 6
        #expect(EV.tradingDaysForLane([]) == 5)                    // empty lane → 5
    }

    @Test func cryptoRiskScalerOnlyShrinksRisk() {
        #expect(abs(EV.cryptoRiskScaler(annualizedVol: 0.70) - 3.5) < 1e-9)    // 0.70 / 0.20
        #expect(abs(EV.cryptoRiskScaler(annualizedVol: 0.25) - 1.25) < 1e-9)
        #expect(EV.cryptoRiskScaler(annualizedVol: 0.10) == 1.0)               // floored — never inflates risk
        #expect(EV.cryptoRiskScaler(annualizedVol: 0.20) == 1.0)
    }

    @Test func earningsPenaltyStacksBelowACostFailedPeerAndNeverResurrectsANilKey() {
        // BTC: imminent earnings (−2000) AND after-cost negative (−500k); ETH: cost-fail only; AAPL: clean.
        // The bands stack, so BTC sinks BELOW the cost-only-failed ETH, and both below the clean AAPL.
        let thin    = idea("BTC-USD", conviction: 0.5, stop: 98, target: 103)
        let costOnly = idea("ETH-USD", conviction: 0.5, stop: 98, target: 103)
        let clean   = idea("AAPL", conviction: 0.7, stop: 90, target: 130)
        let earnings: [String: EarningsProximity] = ["BTC-USD": EarningsProximity(daysUntil: 2, severity: .imminent)]
        #expect(EV.rankByEV([thin, costOnly, clean], earnings: earnings).map(\.symbol) == ["AAPL", "ETH-USD", "BTC-USD"])
        // The penalty is applied via .map on the rank key, so it can NEVER resurrect a nil (no-EV) key:
        // two stop/target-less buys both rank nil → stable input order, the imminent one does not float up.
        let nilA = idea("NOEVA", conviction: 0.9, stop: nil, target: nil)   // imminent + nil EV key
        let nilB = idea("NOEVB", conviction: 0.9, stop: nil, target: nil)   // clean + nil EV key
        let earn2: [String: EarningsProximity] = ["NOEVA": EarningsProximity(daysUntil: 1, severity: .imminent)]
        #expect(EV.rankByEV([nilB, nilA], earnings: earn2).map(\.symbol) == ["NOEVB", "NOEVA"])
    }

    @Test func afterCostNegativeFlipIsDemotedBelowCleanSetup() {
        // Thin crypto flip: +EV pre-cost (rewardR 1.5) but 50bps crypto cost pushes the after-cost
        // break-even (50%) ABOVE its conviction win-prob (46.5%) → must not out-rank a clean setup.
        let thin  = idea("BTC-USD", conviction: 0.5, stop: 98, target: 103)
        let clean = idea("AAPL",    conviction: 0.7, stop: 90, target: 130)   // 13bps, clears easily
        #expect(EV.rankByEV([thin, clean]).first?.symbol == "AAPL")
        #expect(EV.bestOpportunity([thin, clean])?.idea.symbol == "AAPL")
        // The clean setup alone is still a valid best opportunity (not over-demoted).
        #expect(EV.bestOpportunity([clean])?.idea.symbol == "AAPL")
    }

    @Test func bestOpportunityHonorsTheEarningsGate() {
        // AAPL has the HIGHER base EV (6:1) but reports in 2 days; MSFT is a clean 1.5:1.
        let imminent = idea("AAPL", conviction: 0.9, stop: 95, target: 130)
        let clean = idea("MSFT", conviction: 0.9, stop: 90, target: 115)
        // No earnings → the higher-EV name wins (unchanged behavior, matches the boards).
        #expect(EV.bestOpportunity([imminent, clean])?.idea.symbol == "AAPL")
        // AAPL imminent → demoted below the clean peer, so the card/Today/summary match the EV board.
        let earnings: [String: EarningsProximity] = ["AAPL": EarningsProximity(daysUntil: 2, severity: .imminent)]
        #expect(EV.bestOpportunity([imminent, clean], earnings: earnings)?.idea.symbol == "MSFT")
        // Demotion, not exclusion: if the imminent name is the ONLY positive-EV buy, it still surfaces.
        #expect(EV.bestOpportunity([imminent], earnings: earnings)?.idea.symbol == "AAPL")
    }

    @Test func hairThinStopCannotOverrunTheRegimeBan() {
        // Pre-cap, a regime-banned SELL with a near-zero stop (risk 1e-5) scored ~2,000,000 R and
        // beat the −1,000,000 ban penalty — crowning a short #1 in a BULL tape. rewardR caps at 50.
        let bull = MarketRegime(state: .trendingBull, riskScore: 0.6, signals: [], sizingBias: 1.1, caveat: "x")
        let cleanBuy  = idea("WIN", action: .buy,  conviction: 1.0, stop: 90, target: 120)
        let knifeSell = idea("EXPLOIT", action: .sell, conviction: 1.0, stop: 100.00001, target: 80)
        #expect(EV.rankByEV([cleanBuy, knifeSell], regime: bull).first?.symbol == "WIN")
        // The cap itself: a degenerate hair-thin stop yields rewardR 50, not millions.
        #expect(EV.ev(conviction: 1.0, entry: 100, stop: 100.00001, target: 80)?.rewardR == 50)
        // A normal setup is unaffected (4:1 stays 4:1): reward 40 (140−100) ÷ risk 10 (100−90).
        // (Was target 130 = 30/10 = 3:1, a typo contradicting the "4:1" comment.)
        #expect(EV.ev(conviction: 0.9, entry: 100, stop: 90, target: 140)?.rewardR == 4)
    }

    @Test func regimeGateKeepsBannedSideFromTopRank() {
        let bear   = MarketRegime(state: .trendingBear, riskScore: -0.5, signals: [], sizingBias: 0.5,  caveat: "x")
        let bull   = MarketRegime(state: .trendingBull, riskScore: 0.6,  signals: [], sizingBias: 1.1,  caveat: "x")
        let crisis = MarketRegime(state: .crisis,       riskScore: -0.9, signals: [], sizingBias: 0.25, caveat: "x")
        let rng    = MarketRegime(state: .ranging,      riskScore: 0,    signals: [], sizingBias: 1,    caveat: "x")
        let buy  = idea("WIN", action: .buy,  conviction: 0.9, stop: 90,  target: 130)
        let sell = idea("DN",  action: .sell, conviction: 0.8, stop: 110, target: 80)
        // Backward compat: nil regime is identical to no regime.
        #expect(EV.rankByEV([buy, sell]).map(\.symbol) == EV.rankByEV([buy, sell], regime: nil).map(\.symbol))
        // Risk-off (bear/crisis): no BUY ranks #1, and bestOpportunity (buy-only) returns nil.
        #expect(EV.rankByEV([buy, sell], regime: bear).first?.symbol == "DN")
        #expect(EV.bestOpportunity([buy], regime: bear) == nil)
        #expect(EV.bestOpportunity([buy], regime: crisis) == nil)
        // Bull: no SHORT ranks #1; the buy is the best opportunity.
        #expect(EV.rankByEV([buy, sell], regime: bull).first?.symbol == "WIN")
        #expect(EV.bestOpportunity([buy], regime: bull)?.idea.symbol == "WIN")
        // Ranging gates nothing → identical ordering to no regime.
        #expect(EV.rankByEV([buy, sell], regime: rng).map(\.symbol) == EV.rankByEV([buy, sell]).map(\.symbol))
    }

    @Test func lowConvictionFantasyTargetCannotTopTheBoard() {
        // 18:1 reward:risk but ZERO conviction inflates raw EV to ~5.65R — it must NOT
        // out-rank a real 0.8-conviction 2:1 setup (~0.60R) once quality-adjusted.
        let junk = idea("JUNK", conviction: 0.0, stop: 90, target: 280)
        let real = idea("AAPL", conviction: 0.8, stop: 90, target: 120)
        #expect(EV.rankByEV([junk, real]).first?.symbol == "AAPL")
        #expect(EV.rankByVelocity([junk, real]).first?.symbol == "AAPL")
        #expect(EV.bestOpportunity([junk]) == nil)                      // sub-0.40 conviction → no #1 pick
        #expect(EV.bestOpportunity([junk, real])?.idea.symbol == "AAPL")
    }

    @Test func fastLaneConcentrationFlagsAllSameClass() {
        let c1 = idea("BTC-USD", conviction: 0.9, stop: 90, target: 130)
        let c2 = idea("ETH-USD", conviction: 0.8, stop: 90, target: 130)
        let c3 = idea("SOL-USD", conviction: 0.7, stop: 90, target: 130)
        let conc = EV.fastLaneConcentration([c1, c2, c3])!
        #expect(conc.dominantClass == "Crypto")
        #expect(conc.count == 3 && conc.total == 3)
        #expect(conc.isConcentrated)                     // all 3 fastest are crypto → one bet, not three
        // Mixed: top fast lane = BTC, ETH (crypto), AAPL (equity) → not all one class.
        let eq = idea("AAPL", conviction: 0.95, stop: 90, target: 130)
        let mixed = EV.fastLaneConcentration([c1, eq, c2])!
        #expect(!mixed.isConcentrated)
        #expect(EV.fastLaneConcentration([c1]) == nil)   // <2 fast-lane → nil
    }

    @Test func summaryMatchesStandaloneSurfaces() {
        // The summary card composes the same helpers the standalone surfaces use — pin
        // that they never drift (a future change to summary() that diverges goes red).
        let a = idea("A", action: .buy, conviction: 0.2, stop: 90, target: 120)
        let b = idea("BTC-USD", action: .strongBuy, conviction: 0.9, stop: 90, target: 130)
        let c = idea("AAPL", action: .buy, conviction: 0.6, stop: 90, target: 120)
        let ideas = [a, b, c]
        let s = EV.summary(ideas)
        #expect(s.bestSymbol == EV.bestOpportunity(ideas)?.idea.symbol)
        #expect(s.bestEV == EV.bestOpportunity(ideas)?.ev.evR)
        #expect(s.fastestSymbol == EV.fastLane(ideas).first?.symbol)
        #expect(s.fastestVelocity == EV.fastLane(ideas).first.flatMap { EV.velocity(for: $0) })
        // summary() uses crypto-aware cadence (tradingDaysForLane: ~7d for a crypto lane, 5d
        // equity), so match that here rather than the default 5 — they must agree by construction.
        #expect(s.weeklyR == EV.expectedWeeklyR(ideas, tradingDays: EV.tradingDaysForLane(ideas)))
    }

    @Test func bestOpportunityPicksHighestPositiveEVBuy() {
        let a = idea("A", action: .buy, conviction: 0.2, stop: 90, target: 120)        // EV 0.188
        let b = idea("B", action: .strongBuy, conviction: 0.9, stop: 90, target: 130)  // EV 1.228
        let c = idea("C", action: .sell, conviction: 0.9, stop: 90, target: 130)       // not buy-family
        let d = idea("D", action: .buy, conviction: 0.0, stop: 90, target: 110)        // EV −0.30 (negative)
        let best = EV.bestOpportunity([a, c, d, b])!
        #expect(best.idea.symbol == "B")
        #expect(abs(best.ev.evR - 1.228) < 1e-9)
        // No positive-EV buy idea → nil (don't manufacture one).
        #expect(EV.bestOpportunity([c, d]) == nil)
    }

    @Test func ranksIdeasByEVBestFirstNoEVLast() {
        // A: conv 0.2, 2:1 → EV 0.188 ; B: conv 0.9, 3:1 → EV 1.228 ; C: no stop → no EV.
        let a = idea("A", conviction: 0.2, stop: 90, target: 120)
        let b = idea("B", conviction: 0.9, stop: 90, target: 130)
        let c = idea("C", conviction: 0.9, stop: nil, target: nil)
        let ranked = EV.rankByEV([a, c, b])
        #expect(ranked.map(\.symbol) == ["B", "A", "C"])
    }
}
