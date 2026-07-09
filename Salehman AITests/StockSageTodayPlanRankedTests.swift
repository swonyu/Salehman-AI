import Testing
import Foundation
@testable import Salehman_AI

// MARK: - Today's ranked action list (FASTMONEY_BACKLOG #4)

struct StockSageTodayPlanRankedTests {

    private func idea(_ symbol: String, action: TradeAdvice.Action = .strongBuy, conviction: Double,
                      price: Double = 100, stop: Double?, target: Double?) -> StockSageIdea {
        StockSageIdea(symbol: symbol, market: "M", price: price,
                      advice: TradeAdvice(action: action, conviction: conviction, regime: .bullTrend, rationale: [],
                                          stopPrice: stop, targetPrice: target, suggestedWeight: 0.05, caveat: "x"),
                      spark: [])
    }

    // A comfortably-clear setup: normal stop distance ⇒ costs barely register ⇒ net R:R ≥ 2.
    private func clearIdea(_ symbol: String, conviction: Double = 0.95, price: Double = 100,
                           riskAbs: Double = 5, rewardAbs: Double = 20) -> StockSageIdea {
        idea(symbol, conviction: conviction, price: price, stop: price - riskAbs, target: price + rewardAbs)
    }

    @Test func orderMatchesFastLaneCappedAtThree() {
        let ideas = [clearIdea("A", conviction: 0.6, riskAbs: 5, rewardAbs: 11),
                     clearIdea("B", conviction: 0.95, riskAbs: 2, rewardAbs: 12),
                     clearIdea("C", conviction: 0.8, riskAbs: 4, rewardAbs: 16),
                     clearIdea("D", conviction: 0.7, riskAbs: 6, rewardAbs: 13)]
        let lane = StockSageExpectedValue.fastLane(ideas)
        let plans = StockSageTodayPlan.rankedActions(ideas, account: nil, riskFraction: nil)
        #expect(plans.count == Swift.min(3, lane.count))
        #expect(plans.map(\.symbol) == Array(lane.prefix(3)).map(\.symbol))
    }

    @Test func liquidityPassThroughDemotesThinNamesInRankedActions() throws {
        let ideas = [clearIdea("A", conviction: 0.6, riskAbs: 5, rewardAbs: 11),
                     clearIdea("B", conviction: 0.95, riskAbs: 2, rewardAbs: 12),
                     clearIdea("C", conviction: 0.8, riskAbs: 4, rewardAbs: 16)]
        let first = try #require(StockSageExpectedValue.fastLane(ideas).first).symbol
        let thin = [first: LiquidityProfile(avgDollarVolume: 50_000, tier: .thin)]
        let laneThin = StockSageExpectedValue.fastLane(ideas, liquidity: thin)
        // Engine sanity: the −3000 thin sentinel (band-pinned in
        // liquidityRankPenaltyFiresOnlyForTheThinTier) demotes the former #1 —
        // conviction gaps here are ≤ 350 (1000 × Δconviction), far under 3000.
        #expect(laneThin.first?.symbol != first)
        // The contract this test pins: rankedActions MIRRORS fastLane's demoted order
        // under identical inputs (before 2026-07-07 the liquidity param didn't exist,
        // so the Today card's order silently diverged from the strip's).
        let plans = StockSageTodayPlan.rankedActions(ideas, account: nil, riskFraction: nil, liquidity: thin)
        #expect(plans.map(\.symbol) == Array(laneThin.prefix(3)).map(\.symbol))
        // Demotion, not exclusion: the thin name still appears in the 3-slot plan.
        #expect(plans.map(\.symbol).contains(first))
    }

    @Test func sharesXorNilAccount() {
        let ideas = [clearIdea("A"), clearIdea("B", conviction: 0.9, riskAbs: 3, rewardAbs: 15)]
        let noAccount = StockSageTodayPlan.rankedActions(ideas, account: nil, riskFraction: nil)
        #expect(!noAccount.isEmpty)
        for p in noAccount { #expect(p.shares == nil && p.dollarsAtRisk == nil) }

        let withAccount = StockSageTodayPlan.rankedActions(ideas, account: 10_000, riskFraction: 0.01)
        #expect(!withAccount.isEmpty)
        for p in withAccount { #expect(p.shares != nil && p.dollarsAtRisk != nil) }
    }

    @Test func everyPlanCarriesADefinedStopAndTarget() {
        let ideas = [clearIdea("A"), clearIdea("B", conviction: 0.9, riskAbs: 3, rewardAbs: 15)]
        let plans = StockSageTodayPlan.rankedActions(ideas, account: nil, riskFraction: nil)
        for p in plans { #expect(p.stop > 0 && p.target > 0 && p.entry > 0) }
    }

    // wave-11/F09: rankedActions now passes rrIsNet:true when StockSageNetEdge.netRR resolves non-nil
    // (i.e. for all clearIdea fixtures with valid entry/stop/target). The expected gate must match.
    // Hand-derived via derive_wave11f.swift: US large-cap costs=13bps; clearIdea A (riskAbs=5,
    // rewardAbs=20) netRR≈3.87; clearIdea B (riskAbs=3, rewardAbs=15) netRR≈4.75 — both non-nil.
    @Test func gateVerdictMatchesTradeGateEvaluateOnTheSameInputs() {
        let ideas = [clearIdea("A"), clearIdea("B", conviction: 0.9, riskAbs: 3, rewardAbs: 15)]
        let plans = StockSageTodayPlan.rankedActions(ideas, account: nil, riskFraction: 0.01)
        #expect(plans.count == 2)   // hard count FIRST — a `for p in plans` over an empty list would pass vacuously (WHIPPYX)
        for p in plans {
            let resolvedNetRR = StockSageNetEdge.netRR(symbol: p.symbol, entry: p.entry, stop: p.stop, target: p.target)
            let rr = resolvedNetRR ?? abs(p.target - p.entry) / abs(p.entry - p.stop)
            // rrIsNet:true iff netRR resolved (non-nil) — mirrors rankedActions' own logic post-wave-11
            let expected = StockSageTradeGate.evaluate(hasStop: true, rewardToRisk: rr, riskFraction: 0.01,
                                                       rrIsNet: resolvedNetRR != nil)
            #expect(p.gate == expected)   // riskFraction: 0.01 supplied ⇒ gate is non-nil
            // Value pin (not just the plumbing mirror): the decision itself is hand-derived .clear.
            // A netRR 3.873294, B netRR 4.750799 (both ≥2 → positive-skew PASS; derive_gate_decision.swift);
            // riskFraction 0.01 ≤ 0.02 cap PASS; hasStop PASS; corr/earnings nil (no check) ⇒ no warn/fail ⇒ .clear.
            // Catches the failure a pure mirror can't: if rankedActions AND this call shared the same wrong rr,
            // `p.gate == expected` would still pass while the decision was wrong.
            #expect(p.gate?.decision == .clear)
        }
    }

    // An oversized risk% (5%, above the gate's 2% cap) deterministically blocks every plan,
    // regardless of the setup's own R:R — the cleanest way to force a known-blocked row.
    @Test func overRiskCapBlocksEveryPlanAndTheRowIsFlagged() {
        let ideas = [clearIdea("A"), clearIdea("B", conviction: 0.9, riskAbs: 3, rewardAbs: 15),
                     clearIdea("C", conviction: 0.85, riskAbs: 4, rewardAbs: 18)]
        let plans = StockSageTodayPlan.rankedActions(ideas, account: 10_000, riskFraction: 0.05)
        #expect(!plans.isEmpty)
        for p in plans { #expect(p.gate?.decision == .blocked) }   // riskFraction: 0.05 supplied ⇒ gate is non-nil
        let text = StockSageTodayPlan.copyAllText(plans)
        #expect(text.contains("DO NOT TRADE"))
        for p in plans { #expect(text.contains(p.symbol)) }
    }

    @Test func copyTextParsesWithSymbolVelocityAndStop() {
        let ideas = [clearIdea("A"), clearIdea("B", conviction: 0.9, riskAbs: 3, rewardAbs: 15)]
        let plans = StockSageTodayPlan.rankedActions(ideas, account: 10_000, riskFraction: 0.01)
        let text = StockSageTodayPlan.copyAllText(plans)
        let lines = text.split(separator: "\n")
        #expect(lines.count >= plans.count)
        for p in plans {
            #expect(text.contains(p.symbol))
            // wave-12 fix #7: copyAllText emits "%+.3fR/day gross" (F29/F30 tag); pin the
            // full substring so a tag-stripping regression is caught immediately.
            #expect(text.contains("R/day gross"))
            // Adaptive price: ≥$1 → %.2f, sub-dollar → %.4f, sub-cent → %.6f.
            // These plans use price=100/stop≥95, so %.2f applies (but use the same
            // adaptive logic rather than hard-coding %.2f so the test stays honest).
            let expectedStop: String = {
                let a = abs(p.stop)
                if a >= 1 || a == 0 { return String(format: "%.2f", p.stop) }
                if a >= 0.01 { return String(format: "%.4f", p.stop) }
                return String(format: "%.6f", p.stop)
            }()
            #expect(text.contains(expectedStop))
        }
    }

    // Regression: sub-dollar crypto prices (DOGE-class, ~$0.10) must NOT collapse to identical
    // "0.10" strings for entry and stop. fmt must use %.4f so e.g. entry 0.1040 ≠ stop 0.0990.
    @Test func subDollarPricesUseFourDecimalPlacesInCopyText() {
        // entry ~$0.104, stop ~$0.099 → 5% risk, 4:1 R:R target
        let doge = idea("DOGE-USD", conviction: 0.85, price: 0.104, stop: 0.099, target: 0.124)
        let plans = StockSageTodayPlan.rankedActions([doge], account: nil, riskFraction: nil, max: 1)
        guard !plans.isEmpty else {
            // If fastLane filters it (unlikely with 4:1 R:R) the fixture is moot — skip gracefully.
            return
        }
        let text = StockSageTodayPlan.copyAllText(plans)
        // Both must appear as 4-decimal strings, not 2-decimal collapsed identical values.
        #expect(text.contains("0.1040"))
        #expect(text.contains("0.0990"))
        #expect(text.contains("0.1240"))
        // The 2-decimal collapsed representations must NOT appear (the old bug).
        #expect(!text.contains("entry 0.10 stop 0.10"))
    }

    // Regression: sub-cent prices (e.g. SHIB-USD at $0.000025) must use %.6f precision.
    @Test func subCentPricesUseSixDecimalPlacesInCopyText() {
        let shib = idea("SHIB-USD", conviction: 0.85, price: 0.000025, stop: 0.000022, target: 0.000037)
        let plans = StockSageTodayPlan.rankedActions([shib], account: nil, riskFraction: nil, max: 1)
        guard !plans.isEmpty else { return }
        let text = StockSageTodayPlan.copyAllText(plans)
        #expect(text.contains("0.000025"))
        #expect(text.contains("0.000022"))
        #expect(text.contains("0.000037"))
    }

    // Week-horizon research (RESEARCH_2026-07-02_week_horizon_velocity.md, roadmap #2): a short
    // idea's gate/net-R:R must reflect overnight financing, matching StockSageExpectedValue's own
    // netEVR/netVelocity — the plan can't disagree with the ranking that put it here. Hand-verified
    // via a standalone Swift snippet before writing this fixture (entry=100, stop=105, target=85 —
    // a genuine short per StockSageAdvisor.stopTarget's convention: stop above, target below):
    //   netRR without financing ≈ 2.8986 ; netRR WITH financing (3%/yr × 12d) ≈ 2.8251 (strictly less)
    @Test func financingInputsAreNonZeroForAShortIdeaWithAHoldEstimate() {
        let short = idea("SHORT", action: .sell, conviction: 0.9, price: 100, stop: 105, target: 85)
        let (finRate, finDays) = StockSageExpectedValue.financingCostInputs(for: short)
        #expect(finRate > 0 && finDays > 0)
    }

    @Test func rankedActionsCarryExecutionMetadataForRecommendationUI() {
        let earningsDate = Calendar.current.date(byAdding: .day, value: 2, to: Date()) ?? Date()
        let earnings = ["A": StockSageEarnings.proximity(now: Date(), earnings: earningsDate)]
        let plans = StockSageTodayPlan.rankedActions([clearIdea("A", conviction: 0.9)],
                                                     account: nil,
                                                     riskFraction: 0.01,
                                                     earnings: earnings,
                                                     max: 1)
        guard let first = plans.first else {
            Issue.record("expected at least one plan")
            return
        }
        #expect(first.action == .strongBuy)
        #expect(first.regime == .bullTrend)
        #expect(first.daysToEarnings == earnings["A"]?.daysUntil)
    }

    @Test func equityExecutableFirstPrefersClearTradableRowsOverBlockedTopVelocity() {
        let ideas = [
            // BLOCK: net R:R < 1 (0.99), but still positive EV at very high conviction.
            clearIdea("BLOCK", conviction: 0.99, riskAbs: 10, rewardAbs: 9),
            // CLEAR: valid positive-skew setup at low conviction; lower velocity than BLOCK.
            clearIdea("CLEAR", conviction: 0.0, riskAbs: 5, rewardAbs: 10)
        ]
        let defaultOrder = StockSageTodayPlan.rankedActions(
            ideas,
            account: nil,
            riskFraction: 0.01,
            max: 2
        )
        #expect(defaultOrder.first?.symbol == "BLOCK")

        let executableFirst = StockSageTodayPlan.rankedActions(
            ideas,
            account: nil,
            riskFraction: 0.01,
            mode: .equityExecutableFirst,
            max: 2
        )
        #expect(executableFirst.first?.symbol == "CLEAR")
        #expect(executableFirst.first?.gate?.decision != .blocked)
    }

    @Test func defaultRankedModeRemainsFastLaneOrdered() {
        let ideas = [
            clearIdea("A", conviction: 0.65, riskAbs: 4, rewardAbs: 12),
            clearIdea("B", conviction: 0.92, riskAbs: 2, rewardAbs: 10),
            clearIdea("C", conviction: 0.80, riskAbs: 3, rewardAbs: 12)
        ]
        let lane = StockSageExpectedValue.fastLane(ideas)
        let plans = StockSageTodayPlan.rankedActions(ideas, account: nil, riskFraction: 0.01)
        #expect(plans.map(\.symbol) == Array(lane.prefix(3)).map(\.symbol))
    }

    @Test func copyAllTextIncludesBlockedWarningWhenBlockedRowsPresent() {
        let ideas = [
            clearIdea("BLOCK", conviction: 0.99, riskAbs: 10, rewardAbs: 9),
            clearIdea("CLEAR", conviction: 0.0, riskAbs: 5, rewardAbs: 10)
        ]
        let plans = StockSageTodayPlan.rankedActions(ideas, account: nil, riskFraction: 0.01, max: 2)
        #expect(plans.contains { $0.gate?.decision == .blocked })
        let text = StockSageTodayPlan.copyAllText(plans)
        #expect(text.contains("DO NOT TRADE"))
    }

    @Test func executableOnlyFilterWouldDropBlockedRowsForCopyPathParity() {
        let ideas = [
            clearIdea("BLOCK", conviction: 0.99, riskAbs: 10, rewardAbs: 9),
            clearIdea("CLEAR", conviction: 0.0, riskAbs: 5, rewardAbs: 10)
        ]
        let plans = StockSageTodayPlan.rankedActions(ideas, account: nil, riskFraction: 0.01, max: 2)
        let filtered = plans.filter { plan in
            guard let decision = plan.gate?.decision else { return false }
            return decision != .blocked
        }
        #expect(filtered.count == 1)
        #expect(filtered.first?.symbol == "CLEAR")
        let text = StockSageTodayPlan.copyAllText(filtered)
        #expect(!text.contains("DO NOT TRADE"))
    }

    @Test func netRRWithFinancingMatchesHandVerifiedValueAndIsBelowNoFinancing() {
        let netRRWithFinancing = StockSageNetEdge.netRR(symbol: "SHORT", entry: 100, stop: 105, target: 85,
                                                         annualFinancingRate: 0.03, holdDays: 12)
        #expect(netRRWithFinancing != nil)
        if let nr = netRRWithFinancing {
            #expect(abs(nr - 2.8250936623961853) < 1e-9)
        }
        let netRRNoFinancing = StockSageNetEdge.netRR(symbol: "SHORT", entry: 100, stop: 105, target: 85)
        #expect(netRRNoFinancing != nil)
        if let nr = netRRNoFinancing {
            #expect(abs(nr - 2.898635477582846) < 1e-9)
        }
        if let w = netRRWithFinancing, let n = netRRNoFinancing { #expect(w < n) }
    }

    // `rankedActions` is buy-family only BY DESIGN — `fastLane()`'s `velocityRankKey` explicitly
    // guards `case .buyFamily = side(idea)` ("a short does not compound the same way... Fixes a
    // short topping the Fast Lane while it is correctly barred from the best-opportunity card").
    // A short idea's financing cost is therefore never reachable through this composer — pinned
    // here explicitly so a future change doesn't silently start showing shorts without financing.
    @Test func rankedActionsNeverIncludesAShortIdeaSoFinancingIsStructurallyUnreachableHere() {
        let short = idea("SHORT", action: .sell, conviction: 0.9, price: 100, stop: 105, target: 85)
        let plans = StockSageTodayPlan.rankedActions([short], account: nil, riskFraction: nil, max: 1)
        #expect(plans.isEmpty)
    }

    @Test func caveatSweepContainsEstimateAndPerTradeRiskCap() {
        let ideas = [clearIdea("A"), clearIdea("B", conviction: 0.9, riskAbs: 3, rewardAbs: 15)]
        let plans = StockSageTodayPlan.rankedActions(ideas, account: nil, riskFraction: nil)
        let text = StockSageTodayPlan.copyAllText(plans).lowercased()
        #expect(text.contains("estimate"))
        #expect(text.contains("per-trade risk cap") || text.contains("per trade"))
    }

    @Test func cryptoSuffixShownUpfront() {
        let ideas = [idea("BTC-USD", conviction: 0.9, price: 100, stop: 95, target: 120),
                     clearIdea("AAPL", conviction: 0.85, riskAbs: 3, rewardAbs: 15)]
        let plans = StockSageTodayPlan.rankedActions(ideas, account: nil, riskFraction: nil)
        #expect(plans.contains { $0.symbol == "BTC-USD" && $0.isCrypto })
        #expect(plans.contains { $0.symbol == "AAPL" && !$0.isCrypto })
        let text = StockSageTodayPlan.copyAllText(plans)
        #expect(text.contains("BTC-USD (24/7 crypto)"))
        #expect(!text.contains("AAPL (24/7 crypto)"))
    }

    // Thin-but-gross-positive setup (conviction exactly AT minConvictionToRank, so isLowConviction
    // is false and this isolates the floor flag): p=0.442, R:R=1.4 → grossEvR≈0.061 (clears
    // fastLane's evR>0 filter) but netExpectancyR≈0.035 ÷ 12-day equity hold ≈0.0029R/day, under
    // the 0.005 floor. Hand-verified via a standalone Swift snippet mirroring ev()/netEVR()/
    // netVelocity() exactly before writing this fixture.
    @Test func rankedActionPlanSurfacesTheNetCostFloorFlagWhenBelowIt() {
        let thin = idea("A", conviction: 0.40, price: 100, stop: 95, target: 107)
        let comfortable = clearIdea("B", conviction: 0.9, riskAbs: 3, rewardAbs: 15)
        let plans = StockSageTodayPlan.rankedActions([thin, comfortable], account: nil, riskFraction: nil, max: 2)
        guard let thinPlan = plans.first(where: { $0.symbol == "A" }) else {
            Issue.record("expected A's positive-but-thin gross EV to clear fastLane's filter")
            return
        }
        #expect(thinPlan.netCostFloorFlag.isDeranked)
        #expect(!thinPlan.isLowConviction)   // isolates: this row is flagged for cost, not conviction
        guard let comfortablePlan = plans.first(where: { $0.symbol == "B" }) else {
            Issue.record("expected B in the plan list")
            return
        }
        #expect(!comfortablePlan.netCostFloorFlag.isDeranked)
        let text = StockSageTodayPlan.copyAllText(plans)
        #expect(text.contains("below net-cost floor"))
    }

    // Low-conviction (0.20 < 0.40 minConvictionToRank) but comfortable 3:1 R:R keeps net EV/day
    // well above the floor — isolates the conviction flag from the cost flag. Hand-verified:
    // netExpectancyR≈0.558, netVelocity≈0.0465R/day (well above 0.005).
    @Test func rankedActionPlanSurfacesLowConvictionWhenBelowTheRankingFloor() {
        let lowConv = idea("A", conviction: 0.20, price: 100, stop: 95, target: 115)
        let comfortable = clearIdea("B", conviction: 0.9, riskAbs: 3, rewardAbs: 15)
        let plans = StockSageTodayPlan.rankedActions([lowConv, comfortable], account: nil, riskFraction: nil, max: 2)
        guard let lowConvPlan = plans.first(where: { $0.symbol == "A" }) else {
            Issue.record("expected A's positive gross EV to clear fastLane's filter")
            return
        }
        #expect(lowConvPlan.isLowConviction)
        #expect(!lowConvPlan.netCostFloorFlag.isDeranked)   // isolates: flagged for conviction, not cost
        guard let comfortablePlan = plans.first(where: { $0.symbol == "B" }) else {
            Issue.record("expected B in the plan list")
            return
        }
        #expect(!comfortablePlan.isLowConviction)
        let text = StockSageTodayPlan.copyAllText(plans)
        #expect(text.contains("low conviction"))
    }

    @Test func neitherFlagFiresForACleanHighConvictionSetup() {
        let clean = clearIdea("A", conviction: 0.95, riskAbs: 5, rewardAbs: 20)
        let plans = StockSageTodayPlan.rankedActions([clean], account: nil, riskFraction: nil, max: 1)
        #expect(plans.count == 1)
        #expect(!plans[0].netCostFloorFlag.isDeranked)
        #expect(!plans[0].isLowConviction)
    }

    @Test func maxCapsBelowThree() {
        let ideas = [clearIdea("A"), clearIdea("B", conviction: 0.9, riskAbs: 3, rewardAbs: 15),
                     clearIdea("C", conviction: 0.85, riskAbs: 4, rewardAbs: 18)]
        let plans = StockSageTodayPlan.rankedActions(ideas, account: nil, riskFraction: nil, max: 1)
        #expect(plans.count == 1)
    }

    @Test func emptyIdeasProducesEmptyPlanList() {
        #expect(StockSageTodayPlan.rankedActions([], account: nil, riskFraction: nil).isEmpty)
    }

    // MARK: - TODAY-PARITY: held/journal display context (defaulted nil, populated = dict value)

    @Test func heldSharesAndClosedTradeCountDefaultToNilWithoutPositionsOrJournal() {
        let ideas = [clearIdea("A"), clearIdea("B", conviction: 0.9, riskAbs: 3, rewardAbs: 15)]
        let plans = StockSageTodayPlan.rankedActions(ideas, account: nil, riskFraction: nil)
        #expect(!plans.isEmpty)
        for p in plans { #expect(p.heldShares == nil && p.closedTradeCount == nil) }
    }

    @Test func heldSharesAndClosedTradeCountPopulateFromTheSameBatchHelpersTheBoardUses() {
        let ideas = [clearIdea("A"), clearIdea("B", conviction: 0.9, riskAbs: 3, rewardAbs: 15)]
        let positions = [PortfolioPosition(symbol: "A", shares: 30, costBasis: 90)]
        let closedTrade = TradeRecord(symbol: "A", side: .long, entry: 100, stop: 95, target: 120,
                                      shares: 10, openedAt: Date(timeIntervalSince1970: 0),
                                      exitPrice: 110, closedAt: Date(timeIntervalSince1970: 100))
        let plans = StockSageTodayPlan.rankedActions(ideas, account: nil, riskFraction: nil,
                                                      positions: positions, journalTrades: [closedTrade])
        let a = plans.first { $0.symbol == "A" }
        let b = plans.first { $0.symbol == "B" }
        // Pinned against the SAME source-of-truth dicts the ideas board builds — not a
        // re-derivation, so this can't silently diverge from StockSagePortfolio.holdingBySymbol /
        // StockSageJournal.historyBySymbol.
        let expectedHeld = StockSagePortfolio.holdingBySymbol(in: positions)["A"]?.shares
        let expectedClosed = StockSageJournal.historyBySymbol(in: [closedTrade])["A"]?.count
        #expect(a?.heldShares == expectedHeld)
        #expect(a?.closedTradeCount == expectedClosed)
        // B has neither a position nor a closed trade — must stay nil, not zero (no fabricated 0).
        #expect(b?.heldShares == nil)
        #expect(b?.closedTradeCount == nil)
    }

    // F04-parity (2nd-read hunt, 2026-07-08): nil riskFraction must NOT fabricate a gate verdict
    // (the old `?? 0.01` default inside StockSageDecisionSnapshotBuilder always produced one) —
    // the plan's gate is honestly nil, the row badge/copy text must say so, never CLEAR/CAUTION/
    // BLOCKED conjured from an unrequested 1% risk.
    @Test func rankedActionGateIsNilWhenRiskFractionNotSuppliedAndCopyTextSaysNotEvaluated() {
        let ideas = [clearIdea("A"), clearIdea("B", conviction: 0.9, riskAbs: 3, rewardAbs: 15)]
        let plans = StockSageTodayPlan.rankedActions(ideas, account: nil, riskFraction: nil)
        #expect(!plans.isEmpty)
        for p in plans { #expect(p.gate == nil) }
        let text = StockSageTodayPlan.copyAllText(plans)
        // Verbatim wording match with the sheet's copy-plan (MarketsView.swift ~5064-5065) — all
        // surfaces must agree on the exact same honest phrasing.
        #expect(text.contains("Pre-trade gate: not evaluated — enter risk % to see the verdict."))
        #expect(!text.contains("Clear to trade"))
        #expect(!text.contains("Proceed with caution"))
        #expect(!text.contains("Don't take this trade"))
    }

    @Test func copyAllTextAppendsHoldsSuffixOnlyWhenHeldSharesResolves() {
        let ideas = [clearIdea("A"), clearIdea("B", conviction: 0.9, riskAbs: 3, rewardAbs: 15)]
        let positions = [PortfolioPosition(symbol: "A", shares: 30, costBasis: 90)]
        let plans = StockSageTodayPlan.rankedActions(ideas, account: nil, riskFraction: nil, positions: positions)
        let text = StockSageTodayPlan.copyAllText(plans)
        #expect(text.contains("holds 30 sh"))
        // B is not held — its line must not claim a holding.
        let bLine = text.split(separator: "\n").first { $0.contains(". B") }
        #expect(bLine.map { !$0.contains("holds") } ?? false)
    }
}
