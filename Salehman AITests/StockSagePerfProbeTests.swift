import Testing
import Foundation
@testable import Salehman_AI

// MARK: - PLAN_2026-07-08_equity2000 Stage 3 — perf probe at n≈2,400
//
// Builds a deterministic ~2,400-idea synthetic set (SageFix.idea, no RNG) and MEASURES
// wall time of the displayedIdeas-equivalent work: rankByVelocity (the default sort's
// decorate-sort path), ×3 to simulate a hover-render worst case (three re-sorts of the
// same board — e.g. body re-evaluated on hover state changes). This is a MEASUREMENT,
// not a spec fixture — the assertion is a generous regression-catcher bound, not a
// timing pin (ponytail: no memoization added unless the number crosses ~30ms/sort —
// our dropped-frame operationalization of the plan's "if a keystroke-lag shows"
// criterion, not a number the plan itself names; see DEVELOPMENT_LOG for the branch taken).
struct StockSagePerfProbeTests {

    /// ~2,400 synthetic ideas: conviction/stop/target/class (via symbol pattern) vary
    /// across the set via a deterministic loop (no RNG — reproducible byte-for-byte).
    private func syntheticIdeas(count: Int = 2_400) -> [StockSageIdea] {
        let actions: [TradeAdvice.Action] = [.strongBuy, .buy, .hold, .reduce, .sell]
        let regimes: [TradeAdvice.Regime] = [.bullTrend, .bearTrend, .range]
        // Symbol suffix rotates through equity/Saudi/crypto-shaped tickers so the set
        // isn't monotonically one asset class (mirrors the mixed worldwide universe).
        let suffixes = ["", ".SR", "-USD"]
        return (0..<count).map { i in
            let conviction = Double(i % 100) / 100.0                         // 0.00...0.99 cycling
            let action = actions[i % actions.count]
            let regime = regimes[i % regimes.count]
            let price = 10.0 + Double(i % 500)                               // varied price levels
            let riskDistance = 1.0 + Double(i % 20) * 0.5                    // varied stop distance
            let suffix = suffixes[i % suffixes.count]
            return SageFix.idea("SYM\(i)\(suffix)", conviction: conviction, action: action,
                                regime: regime, rr: 1.5 + Double(i % 5) * 0.5,
                                price: price, riskDistance: riskDistance)
        }
    }

    @Test func rankByVelocityAt2400ScaleIsWithinSanityBound() {
        let ideas = syntheticIdeas()
        #expect(ideas.count == 2_400)

        let clock = ContinuousClock()
        // ×3 to simulate a hover-render worst case (displayedIdeas re-evaluated
        // multiple times per interaction burst).
        let elapsed = clock.measure {
            for _ in 0..<3 {
                _ = StockSageExpectedValue.rankByVelocity(ideas)
            }
        }
        let totalMs = Double(elapsed.components.seconds) * 1_000
            + Double(elapsed.components.attoseconds) / 1e15
        let perSortMs = totalMs / 3

        print("[PERF] rankByVelocity ×3 at n=\(ideas.count): total \(totalMs)ms, per-sort \(perSortMs)ms")

        // Generous sanity bound — a regression catcher (e.g. an accidental O(n²) path),
        // NOT a flaky timing pin. See DEVELOPMENT_LOG for the measured number and the
        // memoization decision it drove.
        //
        // MEASURED (Debug build, .dd-isolated, 5 runs): per-sort ≈16.7–18.3ms at n=2,400 —
        // under the ~30ms/sort line (our dropped-frame operationalization of the plan's
        // keystroke-lag criterion). Adversarial worst case (independent review measurement,
        // all-buy-family mix so every idea pays the NetEdge evals): ≈24.8–26.1ms/sort —
        // still under, but the margin to re-check if the universe grows again.
        // DECISION: memoization NOT justified — the honest null. displayedIdeas is left
        // unmemoized; ship the probe only (PLAN_2026-07-08_equity2000 Stage 3).
        #expect(totalMs < 5_000)
    }

    // MARK: - Whole-render-equivalent probe (post-ship critique verification)
    //
    // A post-ship critique argued the single-sort probe above understates the real cost:
    // ONE MarketsView body invalidation (a keystroke in the Ideas-tab search field, a hover,
    // a chunk-publish) does NOT call rankByVelocity once — it evaluates several `@ViewBuilder`
    // properties in the SAME body pass, several of which independently call the SAME
    // StockSageExpectedValue.fastLane/bestOpportunity/summary family with byte-identical
    // arguments. VERIFIED render-graph enumeration (grepped against the real tree at this
    // commit, MarketsView.swift):
    //
    //   ALWAYS-RENDERED (every body eval, any section tab — both live in `normalBody`):
    //     moneyVelocityCard  → summary(...)                         [internally: bestOpportunity
    //                                                                 ×1, rankByVelocity ×1,
    //                                                                 expectedWeeklyR → fastLane×1
    //                                                                 + fastLaneConcentration→
    //                                                                 fastLane×1, tradingDaysForLane
    //                                                                 → fastLane×1  = 5 passes]
    //                        → fastLaneConcentration(...)             [own fastLane×1]
    //                        → .help(weeklyGrossHelp(...))            [tradingDaysForLane→fastLane×1
    //                                                                  — SwiftUI's non-closure
    //                                                                  .help(String) overload is
    //                                                                  evaluated eagerly at body-
    //                                                                  build time, not lazily on
    //                                                                  hover]
    //     bestOpportunityCTA → bestOpportunity(...)                   [1 pass]
    //   Subtotal always-rendered: 5 + 1 + 1 + 1 = 8 fastLane-family passes.
    //
    //   IDEAS-TAB-ONLY (section == .ideas; still runs on a search keystroke since the search
    //   field lives inside the Ideas tab's own board and `ideaSearch` is @State on this view —
    //   confirmed: MarketsView.swift:44 `@State private var ideaSearch`, invalidates the WHOLE
    //   `normalBody`, not a scoped subview):
    //     displayedIdeas      → rankByVelocity (default sort)          [1 pass]
    //     bestOpportunityCard → bestOpportunity(...)                    [1 pass]
    //     capitalAllocationCard → allocate(...)                         [own O(n) pass, NOT
    //                                                                    fastLane-family —
    //                                                                    counted separately below]
    //     fastLaneStrip       → fastLane(...) bound to `lane`           [1 pass]
    //                         → tradingDaysForLane(...)                 [→fastLane×1]
    //                         → expectedWeeklyR(...)                    [→fastLane×1 +
    //                                                                    fastLaneConcentration→
    //                                                                    fastLane×1 = 2]
    //                         → netExpectedWeeklyR(...)                 [→fastLane×1 +
    //                                                                    fastLaneConcentration→
    //                                                                    fastLane×1 = 2]
    //                         → fastLaneConcentration(...)               [1 pass]
    //                         → .help(weeklyGrossHelp(...))              [tradingDaysForLane→
    //                                                                     fastLane×1]
    //     todaysActionsCard   → rankedActions(...)                       [→fastLane×1]
    //   Subtotal Ideas-tab-only: 1+1+1+1+2+2+1+1+1 = 11 fastLane-family passes + 1 allocate pass.
    //
    //   GRAND TOTAL (Ideas tab open, any invalidation incl. a search keystroke): 8 + 11 = 19
    //   fastLane-family passes + 1 allocate pass ≈ 20 total engine passes per body evaluation.
    //   (NOT the ~12-15 the critique estimated, nor the stage-3 null's implicit 1 — the true
    //   number sits between them; a prior same-day dedup round, commits 915086a/c4dccd4, already
    //   cut fastLaneStrip 12→7 and moneyVelocityCard's duplicate concentration/dollars calls, so
    //   this 19-20 count is POST-dedup, not the pre-dedup 22 the DEVELOPMENT_LOG's "22→~13"
    //   entry describes — that entry's "13" underestimates the CURRENT total because it counted
    //   fastLaneStrip + moneyVelocityCard in isolation and did not net out each function's OWN
    //   internal re-derivation of fastLane, e.g. expectedWeeklyR calling fastLane again after the
    //   caller already bound `lane`.)
    //
    //   Two variants below: COLD-START (empty trades, nil calibration, nil regime, empty
    //   earnings/liquidity — MIRRORS the app's actual first-launch defaults: journal.trades == [],
    //   store.convictionCalibration == nil until a backtest runs, store.regime == nil until a
    //   regime fetch completes, store.earnings/store.liquidity == [:] until those scans populate)
    //   and WARM (non-empty earnings + liquidity dicts, since fastLane/bestOpportunity/summary all
    //   branch on them via earningsRankPenalty/liquidityRankPenalty — StockSageExpectedValue.swift
    //   lines 321/334 — an all-empty fixture would silently skip that branch's cost).
    private func auxEarnings(for ideas: [StockSageIdea]) -> [String: EarningsProximity] {
        // Every 7th idea gets a "soon" earnings flag — enough density to exercise the
        // earningsRankPenalty branch on a meaningful fraction of the set without making
        // every idea imminent (which would degenerate the ranking to ties).
        Dictionary(uniqueKeysWithValues: ideas.enumerated().compactMap { i, idea -> (String, EarningsProximity)? in
            guard i % 7 == 0 else { return nil }
            return (idea.symbol.uppercased(), EarningsProximity(daysUntil: 5, severity: .soon))
        })
    }

    private func auxLiquidity(for ideas: [StockSageIdea]) -> [String: LiquidityProfile] {
        // Every 11th idea gets a "thin" liquidity flag — same rationale as earnings above.
        Dictionary(uniqueKeysWithValues: ideas.enumerated().compactMap { i, idea -> (String, LiquidityProfile)? in
            guard i % 11 == 0 else { return nil }
            return (idea.symbol.uppercased(), LiquidityProfile(avgDollarVolume: 500_000, tier: .thin))
        })
    }

    /// Runs the exact fastLane-family call set the verified render-graph enumeration above
    /// lists, with the SAME argument shapes MarketsView passes (ideas, holds, calibration,
    /// regime, earnings, liquidity, trades, account/riskFraction, maxConcurrent/tradingDays
    /// defaults) — one call per render-graph line item, not a synthetic proxy for it.
    private func oneWholeRenderPass(ideas: [StockSageIdea],
                                    trades: [TradeRecord],
                                    earnings: [String: EarningsProximity],
                                    liquidity: [String: LiquidityProfile],
                                    calibration: StockSageConvictionCalibration?) {
        let holds = VelocityHoldDays.defaults
        let account = 10_000.0, riskFraction = 0.01   // sizerAccount/sizerRiskPct's real @AppStorage defaults ("10000"/"1")

        // moneyVelocityCard
        _ = StockSageExpectedValue.summary(ideas, trades: trades, fraction: riskFraction, holds: holds,
                                           regime: nil, earnings: earnings, liquidity: liquidity, calibration: calibration)
        _ = StockSageExpectedValue.fastLaneConcentration(ideas, holds: holds, calibration: calibration,
                                                          earnings: earnings, liquidity: liquidity)
        _ = StockSageExpectedValue.tradingDaysForLane(ideas, holds: holds, calibration: calibration)   // weeklyGrossHelp's inner call

        // bestOpportunityCTA
        _ = StockSageExpectedValue.bestOpportunity(ideas, regime: nil, earnings: earnings, liquidity: liquidity, calibration: calibration)

        // displayedIdeas (default .velocity sort)
        _ = StockSageExpectedValue.rankByVelocity(ideas, holds: holds, earnings: earnings, liquidity: liquidity, calibration: calibration)

        // bestOpportunityCard
        _ = StockSageExpectedValue.bestOpportunity(ideas, regime: nil, earnings: earnings, liquidity: liquidity, calibration: calibration)

        // capitalAllocationCard
        _ = StockSageCapitalAllocator.allocate(ideas: ideas, account: account, calibration: calibration, regime: nil)

        // fastLaneStrip
        let lane = StockSageExpectedValue.fastLane(ideas, holds: holds, calibration: calibration, earnings: earnings, liquidity: liquidity)
        let tradingDays = StockSageExpectedValue.tradingDaysForLane(ideas, holds: holds, calibration: calibration)
        _ = StockSageExpectedValue.expectedWeeklyR(ideas, tradingDays: tradingDays, holds: holds, calibration: calibration)
        _ = StockSageExpectedValue.netExpectedWeeklyR(ideas, tradingDays: tradingDays, holds: holds, calibration: calibration,
                                                       earnings: earnings, liquidity: liquidity)
        _ = StockSageExpectedValue.fastLaneConcentration(ideas, holds: holds, calibration: calibration,
                                                          earnings: earnings, liquidity: liquidity)
        _ = StockSageExpectedValue.tradingDaysForLane(ideas, holds: holds, calibration: calibration)   // weeklyGrossHelp's inner call

        // todaysActionsCard
        _ = StockSageTodayPlan.rankedActions(ideas, account: account, riskFraction: riskFraction, holds: holds,
                                             calibration: calibration, earnings: earnings, liquidity: liquidity)
        _ = lane   // silence unused-if-nothing-below-reads-it warnings in a future edit
    }

    /// AFTER: the SAME render-graph line items as `oneWholeRenderPass` above, but calling the
    /// BIND-ONCE `lane:`-taking overloads MarketsView now uses at each site that can safely share
    /// an already-computed `fastLane(...)` (fastLaneStrip's own 4 internal recomputes collapsed to
    /// 1 shared `lane`). Deliberately DOES NOT touch: `summary()`'s internal fastLane/bestOpportunity/
    /// rankByVelocity re-derivations (its 3 internal calls use 3 DIFFERENT arg shapes — e.g. its
    /// weeklyR path's `expectedWeeklyR` call omits earnings/liquidity while `bestOpportunity`/
    /// `rankByVelocity` include them — collapsing them to one shared lane would silently change
    /// which idea set backs which field); `bestOpportunityCard`/`bestOpportunityCTA`'s independent
    /// `bestOpportunity` calls (separate @ViewBuilder properties with no shared scope without a
    /// larger normalBody restructure — correctly out of scope for a bind-once dedupe, not a missed
    /// spot); `weeklyTurnoverNote`'s internal `assumedWeeklyRoundTrips` fastLane pass (order-
    /// sensitive `.prefix` over a NON-earnings/liquidity-aware lane — provably NOT the same lane as
    /// fastLaneStrip's, so deduping it would risk a silently wrong turnover count).
    private func oneWholeRenderPassDeduped(ideas: [StockSageIdea],
                                           trades: [TradeRecord],
                                           earnings: [String: EarningsProximity],
                                           liquidity: [String: LiquidityProfile],
                                           calibration: StockSageConvictionCalibration?) {
        let holds = VelocityHoldDays.defaults
        let account = 10_000.0, riskFraction = 0.01

        // moneyVelocityCard — summary()'s own internals unchanged (see doc above); its separate
        // fastLaneConcentration call also unchanged (moneyVelocityCard has no shared lane scope
        // with fastLaneStrip without a normalBody-level lift).
        _ = StockSageExpectedValue.summary(ideas, trades: trades, fraction: riskFraction, holds: holds,
                                           regime: nil, earnings: earnings, liquidity: liquidity, calibration: calibration)
        _ = StockSageExpectedValue.fastLaneConcentration(ideas, holds: holds, calibration: calibration,
                                                          earnings: earnings, liquidity: liquidity)
        _ = StockSageExpectedValue.tradingDaysForLane(ideas, holds: holds, calibration: calibration)

        // bestOpportunityCTA
        _ = StockSageExpectedValue.bestOpportunity(ideas, regime: nil, earnings: earnings, liquidity: liquidity, calibration: calibration)

        // displayedIdeas (default .velocity sort) — unchanged, no shared-arg duplicate elsewhere.
        _ = StockSageExpectedValue.rankByVelocity(ideas, holds: holds, earnings: earnings, liquidity: liquidity, calibration: calibration)

        // bestOpportunityCard
        _ = StockSageExpectedValue.bestOpportunity(ideas, regime: nil, earnings: earnings, liquidity: liquidity, calibration: calibration)

        // capitalAllocationCard
        _ = StockSageCapitalAllocator.allocate(ideas: ideas, account: account, calibration: calibration, regime: nil)

        // fastLaneStrip — BIND-ONCE: `lane` computed once, `tradingDays` computed once via the
        // lane: overload, then expectedWeeklyR/netExpectedWeeklyR/fastLaneConcentration all reuse
        // `lane` instead of re-deriving fastLane. 6 internal fastLane passes → 1.
        let lane = StockSageExpectedValue.fastLane(ideas, holds: holds, calibration: calibration, earnings: earnings, liquidity: liquidity)
        let tradingDays = StockSageExpectedValue.tradingDaysForLane(lane: lane)
        _ = StockSageExpectedValue.expectedWeeklyR(lane: lane, ideas: ideas, tradingDays: tradingDays, holds: holds, calibration: calibration)
        _ = StockSageExpectedValue.netExpectedWeeklyR(lane: lane, ideas: ideas, tradingDays: tradingDays, holds: holds, calibration: calibration,
                                                       earnings: earnings, liquidity: liquidity)
        _ = StockSageExpectedValue.fastLaneConcentration(lane: lane)
        // weeklyGrossHelp's inner tradingDaysForLane call is now the ALREADY-BOUND `tradingDays`
        // above (view code passes tradingDays: to weeklyGrossHelp) — zero additional calls here.

        // todaysActionsCard — rankedActions is an ENGINE function (StockSageTodayPlan.swift) with
        // its own internal fastLane pass; NOT given a lane: overload (its only view call site is
        // this one, and threading a lane: param through the engine layer for a single caller is a
        // larger, riskier diff than the measured gain justifies — left as its own pass).
        _ = StockSageTodayPlan.rankedActions(ideas, account: account, riskFraction: riskFraction, holds: holds,
                                             calibration: calibration, earnings: earnings, liquidity: liquidity)
    }

    @Test func wholeRenderEquivalentAt2400ScaleColdStart() {
        let ideas = syntheticIdeas()
        #expect(ideas.count == 2_400)
        let clock = ContinuousClock()
        // Cold-start defaults: empty trades, nil calibration — mirrors journal.trades == []
        // and store.convictionCalibration == nil before any backtest has run.
        let beforeElapsed = clock.measure {
            for _ in 0..<3 {
                oneWholeRenderPass(ideas: ideas, trades: [], earnings: [:], liquidity: [:], calibration: nil)
            }
        }
        let afterElapsed = clock.measure {
            for _ in 0..<3 {
                oneWholeRenderPassDeduped(ideas: ideas, trades: [], earnings: [:], liquidity: [:], calibration: nil)
            }
        }
        let beforeMs = Double(beforeElapsed.components.seconds) * 1_000 + Double(beforeElapsed.components.attoseconds) / 1e15
        let afterMs = Double(afterElapsed.components.seconds) * 1_000 + Double(afterElapsed.components.attoseconds) / 1e15
        print("[PERF] whole-render-equivalent BEFORE dedupe (cold-start) ×3 at n=\(ideas.count): total \(beforeMs)ms, per-invalidation \(beforeMs / 3)ms")
        print("[PERF] whole-render-equivalent AFTER dedupe (cold-start) ×3 at n=\(ideas.count): total \(afterMs)ms, per-invalidation \(afterMs / 3)ms")
        // Generous sanity bound (brief: <20s), not a timing pin.
        #expect(beforeMs < 20_000)
        #expect(afterMs < 20_000)
    }

    @Test func wholeRenderEquivalentAt2400ScaleWithEarningsAndLiquidity() {
        let ideas = syntheticIdeas()
        #expect(ideas.count == 2_400)
        let earnings = auxEarnings(for: ideas)
        let liquidity = auxLiquidity(for: ideas)
        #expect(!earnings.isEmpty && !liquidity.isEmpty)   // hard count first — never a silently-empty aux fixture
        let clock = ContinuousClock()
        let beforeElapsed = clock.measure {
            for _ in 0..<3 {
                oneWholeRenderPass(ideas: ideas, trades: [], earnings: earnings, liquidity: liquidity, calibration: nil)
            }
        }
        let afterElapsed = clock.measure {
            for _ in 0..<3 {
                oneWholeRenderPassDeduped(ideas: ideas, trades: [], earnings: earnings, liquidity: liquidity, calibration: nil)
            }
        }
        let beforeMs = Double(beforeElapsed.components.seconds) * 1_000 + Double(beforeElapsed.components.attoseconds) / 1e15
        let afterMs = Double(afterElapsed.components.seconds) * 1_000 + Double(afterElapsed.components.attoseconds) / 1e15
        print("[PERF] whole-render-equivalent BEFORE dedupe (earnings+liquidity-aware) ×3 at n=\(ideas.count): total \(beforeMs)ms, per-invalidation \(beforeMs / 3)ms")
        print("[PERF] whole-render-equivalent AFTER dedupe (earnings+liquidity-aware) ×3 at n=\(ideas.count): total \(afterMs)ms, per-invalidation \(afterMs / 3)ms")
        #expect(beforeMs < 20_000)
        #expect(afterMs < 20_000)
    }

    // MARK: - Equivalence proof: deduped lane:-overload outputs == direct-call outputs
    //
    // Semantics-preservation gate for the BIND-ONCE dedupe: every `lane:`-taking overload added to
    // StockSageExpectedValue must return BYTE-IDENTICAL output to its `ideas:`-only sibling when
    // `lane` is exactly what that sibling would have derived internally. Uses a smaller n (200,
    // not 2,400) — this is a correctness proof, not a perf measurement, and Equatable/exact
    // comparison of every element is O(n) here regardless.
    @Test func dedupedFastLaneFamilyMatchesDirectCallsAt2400Scale() {
        let ideas = syntheticIdeas()
        let holds = VelocityHoldDays.defaults
        for (label, earnings, liquidity) in [("cold-start", [String: EarningsProximity](), [String: LiquidityProfile]()),
                                              ("earnings+liquidity", auxEarnings(for: ideas), auxLiquidity(for: ideas))] {
            let lane = StockSageExpectedValue.fastLane(ideas, holds: holds, calibration: nil, earnings: earnings, liquidity: liquidity)
            #expect(!lane.isEmpty, "fixture must produce a non-empty fast lane for \(label) — else this proves nothing")

            // tradingDaysForLane(lane:) == tradingDaysForLane(ideas:) when lane matches what the
            // ideas:-overload would derive WITHOUT earnings/liquidity — the ideas:-only overload's
            // OWN internal fastLane call never passes them, so the true equivalence check must use
            // that same non-earnings/liquidity-aware lane, not the earnings/liquidity-aware one above.
            let plainLane = StockSageExpectedValue.fastLane(ideas, holds: holds, calibration: nil)
            let directDays = StockSageExpectedValue.tradingDaysForLane(ideas, holds: holds, calibration: nil)
            let dedupedDays = StockSageExpectedValue.tradingDaysForLane(lane: plainLane)
            #expect(directDays == dedupedDays, "tradingDaysForLane mismatch for \(label)")

            // expectedWeeklyR(lane:ideas:) == expectedWeeklyR(ideas:) when lane == fastLane(ideas, holds, calibration)
            // (the ideas:-only overload's own internal derivation — no earnings/liquidity, matching plainLane above).
            let directWk = StockSageExpectedValue.expectedWeeklyR(ideas, tradingDays: directDays, holds: holds, calibration: nil)
            let dedupedWk = StockSageExpectedValue.expectedWeeklyR(lane: plainLane, ideas: ideas, tradingDays: directDays, holds: holds, calibration: nil)
            #expect(directWk == dedupedWk, "expectedWeeklyR mismatch for \(label)")

            // netExpectedWeeklyR(lane:ideas:) == netExpectedWeeklyR(ideas:) — THIS overload's own
            // internal fastLane call DOES pass earnings/liquidity, so the earnings/liquidity-aware
            // `lane` computed above is the correct comparison lane here.
            let directNetWk = StockSageExpectedValue.netExpectedWeeklyR(ideas, tradingDays: directDays, holds: holds, calibration: nil, earnings: earnings, liquidity: liquidity)
            let dedupedNetWk = StockSageExpectedValue.netExpectedWeeklyR(lane: lane, ideas: ideas, tradingDays: directDays, holds: holds, calibration: nil, earnings: earnings, liquidity: liquidity)
            #expect(directNetWk == dedupedNetWk, "netExpectedWeeklyR mismatch for \(label)")

            // fastLaneConcentration(lane:) == fastLaneConcentration(ideas:) when lane is the SAME
            // earnings/liquidity-aware derivation the ideas:-only overload makes internally.
            let directConc = StockSageExpectedValue.fastLaneConcentration(ideas, holds: holds, calibration: nil, earnings: earnings, liquidity: liquidity)
            let dedupedConc = StockSageExpectedValue.fastLaneConcentration(lane: lane)
            #expect(directConc == dedupedConc, "fastLaneConcentration mismatch for \(label)")
        }
    }
}
