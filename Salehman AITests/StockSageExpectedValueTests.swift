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
        #expect(s.weeklyR == EV.expectedWeeklyR(ideas))
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
