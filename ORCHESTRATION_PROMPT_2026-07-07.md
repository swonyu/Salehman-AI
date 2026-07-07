# Multi-Model Orchestration: Ideas Card + Money Math Improvement Wave
## Generated 2026-07-07 · For Claude Code execution

You are Claude Code orchestrating a multi-model workflow. Below is a complete brief:
the current state of the repo, what was already done, what remains, and the exact
model assignments for each subtask.

---

# 1. REPO STATE — What was already done (2026-07-06→07)

The Salehman AI repo (`/Users/saleh/Salehman-AI`, SwiftUI macOS app, main branch)
has had TWO days of intensive autonomous improvement. Below is every shipped change
so you don't redo or collide with them.

## A) Engine / Ranking / Money-math improvements (SHIPPED, do NOT revert)

1. **Continuous net-cost ratio in `evRankKey` and `bestOpportunity` rankVal**
   - File: `StockSageExpectedValue.swift`
   - `evRankKey` now computes `netRatio = netEVR / evR` (clamped 0–1) and scales
     `qualityAdjustedEVR * netRatio` before conviction/cost demotion bands.
   - `bestOpportunity`'s internal `rankVal` applies same `netRatio` to both
     default (qualityAdjustedEVR) and preferVelocity paths.
   - Binary `clearsCostAfterFrictions` −500k penalty preserved; ratio
     differentiates within the "clears" tier.

2. **fastLane earnings/liquidity penalty consistency**
   - Files: `StockSageExpectedValue.swift`, `StockSageTodayPlan.swift`, `MarketsView.swift`
   - Added optional `earnings:`/`liquidity:` params (default empty) to `fastLane`
     and `fastLaneByClass`. Apply `earningsRankPenalty`/`liquidityRankPenalty`
     in sort key. MarketsView passes `store.earnings`/`store.liquidity`.
   - All existing callers byte-identical with default empty params.

3. **rankByVelocityWeighted e/l pass-through**
   - File: `StockSageExpectedValue.swift`
   - Added `earnings:`/`liquidity:` params; passes through to `fastLane` AND
     applies penalties in `weightedVelocity`'s internal key so momentum-hot
     demoted ideas can't be resurrected by quality multiplier.

4. **netExpectedWeeklyR companion function**
   - File: `StockSageExpectedValue.swift`
   - New function summing `netVelocity` instead of gross `velocity(for:)`.
     Same concentration haircut, trading-days cadence. Pure additive — no
     existing display changed (F03/F44 untouched).

5. **cVaR95 (expected shortfall) in PortfolioAnalytics**
   - File: `StockSagePortfolioAnalytics.swift`
   - New field: average loss GIVEN VaR threshold breached. Falls back to VaR
     when zero tail observations.

6. **MonteCarloRuin finite guard**
   - File: `StockSageMonteCarloRuin.swift`
   - `equity < 0 || !equity.isFinite → equity = 0` — extreme f×r overflow
     treated as ruin.

7. **Variance convention documentation**
   - File: `StockSagePortfolioAnalytics.swift`
   - Documented why sample variance (÷n−1) for Sharpe, population (÷n) for
     Sortino — both standard, not a drift.

8. **VolStability harmonized with VolRegime**
   - File: `StockSageVolStability.swift`
   - Changed single invalid rolling-vol window from `return nil` to `continue`
     (skip). Added minimum-series-count guard ≥ max(5, 60% of expected).

9. **ReturnShape dual-threshold**
   - File: `StockSageReturnShape.swift`
   - `isLeftTailed` now requires BOTH `skew < −0.5` AND `downside95 > 0.02`.
     Single-outlier skew no longer triggers false positive. Test updated.

10. **IdeaSort.momentumWeighted + netExpectedWeeklyR display**
    - Files: `MarketsView.swift`
    - New `momentumWeighted` sort case wired via `rankByVelocityWeighted`.
    - Net weeklyR shown under gross in fastLaneStrip: `↳ +X.XR/week net`.

## B) UX/Display improvements (SHIPPED, do NOT touch)

11. **WCAG-AA contrast: `DS.Palette.dangerSoft` token + ~15 danger-text swaps**
    - Files: `DesignSystem.swift`, `MarketsView.swift`, `MarketsTodayActionsCard.swift`
    - All small danger-text sites (earnings warnings, stop prices, gap/leverage
      verdicts, momentum cold, trade gate, alerts, risk chips) now dangerSoft.

12. **Sheet candidate navigation (prev/next)**
    - File: `MarketsView.swift`
    - Chevrons + "N of M" label in detail sheet header. ⌘↑/⌘↓. 300ms debounce.

13. **Unified chip styling**
    - File: `MarketsView.swift`
    - `summaryChip`/`calibrationChip` use `DS.Palette.surface` + `surfaceStroke`.
      Action badges gained surfaceStroke overlay.

14. **DRY-extracted earnings warning HStack**
    - File: `MarketsView.swift`
    - `earningsWarningRow(_:)` helper replaces duplicated buy/sell HStacks.

## C) Audits completed (FINDINGS DOCUMENTED, not fully implemented)

15. **Round 1: 4-agent parallel audit** — 14 engine modules, verdict: no critical bugs.
16. **Round 2: 5-agent parallel audit** — journal, risk, volatility, analytics,
    alerts, monitor, paper-trader, store, pipeline, test coverage.

**Documented but NOT YET implemented:**
- Journal realizedR-nil trades counted in `closed` but excluded from R-stats
  (intentional — needs consumer-facing doc, not code change)
- Monitor alert log cap enforcement site not verified (find where
  `StockSageAlerts.detect` results are appended to `store.alerts` and enforce cap=50)
- WHIPPYX-class weak `#expect(x != nil)` assertions in ~8 test files
- F40 derived-expected fixtures in `PaperTraderTests` and `TodayPlanRankedTests`
- Kelly halfKelly ≤ 0.5 parametric sweep invariant test
- PositionSizer shares→0 dollarsAtRisk consistency invariant test
- Cross-harness cost accounting: backtester (full round-trip per trade) vs
  NetCostSim (per-side turnover) — both documented but not aligned

---

# 2. MODEL ASSIGNMENTS — Who does what

## Fable 5 — Orchestrator & Adjudicator
**Best at:** Planning, decomposition, multi-model coordination, final adjudication,
verification synthesis, catching cross-model inconsistencies.

**Tasks:**
1. Read this entire brief and decompose into an execution plan.
2. Before any code is written, verify each model's output against the repo's
   honesty floor and owner-gate registry (canonical list in
   `gated-scope` skill §1: RANKING #10 `preferVelocity` stays false, F08
   "Conviction"/"Signal strength" term stays unsettled, F03/F44 weekly netting
   stays gross-labeled, cost-table changes stay owner-held).
3. After all models complete: adjudicate disagreements. If two models propose
   different fixes for the same issue, YOU decide based on evidence, not vote.
4. Synthesize all findings into a single, ordered ACTION LIST ranked by
   value-to-effort (highest money-math impact first, then ranking, then test
   hardening).
5. Write the final DEVELOPMENT_LOG entry summarizing what was done.

## Opus 4.8 — Adversarial Math Reviewer & Quality Gate
**Best at:** Deep formula-level verification, adversarial self-review, finding
edge cases in mathematical derivations, cross-module invariant checking.

**Tasks:**
1. HAND-DERIVE every critical formula in the money engine from first principles
   (DO NOT read the code first). Write derivations in a standalone script
   (`/tmp/derive_opus_YYYY-MM-DD.swift`). Then read the implementation and
   compare. Flag ANY divergence between hand-derivation and code.
   Critical formulas to verify:
   - Kelly f* = W − (1−W)/R, half-Kelly, maxFraction cap
   - EV = p·rewardR − (1−p), qualityAdjustedEVR = EV × (0.4 + 0.6·conviction)
   - NetEdge: netReward, netRisk, netRR, breakEven = 1/(1+netRR)
   - DeflatedSharpe: PSR, expectedMaxSharpe, DSR formula
   - PositionSizer: riskFraction → shares → dollarsAtRisk → notional chain
   - CapitalAllocator: halfKelly→regimeBias→volBrake→correlationDeWeight→heatCap
2. Verify cross-module invariants hold:
   - `gross EV ≥ net EV` for any setup with positive costs
   - `suggestedFraction ≤ StockSageKelly.maxFraction` (0.20) always
   - `suggestedWeight ≤ maxWeight` (0.20) always
   - `PositionSizer.shares × riskPerShare ≤ account × riskFraction` (within rounding)
   - `CapitalAllocator.totalHeat ≤ maxHeat` after scaling
   - `cryptoRiskScaler ≥ 1` (never inflates risk)
   - `varianceScalar ≤ 1` (attenuation only)
   - `sizingBias ∈ [0.40, 1.25]` or 0.25 for crisis
3. For each invariant, FIND the test that pins it (or flag it as UNTESTED).
4. Report: verified-correct formulas (with derivation), confirmed invariants
   (with test pointers), and any divergences found.

## DeepSeek V4 Pro — Autonomous Implementation
**Best at:** Long autonomous coding runs, complex algorithm implementation,
agentic engineering, handling multi-file changes.

**Tasks:**
1. Implement the high-priority action items from Opus's findings and the
   documented-but-not-implemented audit findings:
   a) **Fix WHIPPYX weak assertions** — In ~8 test files identified in audit
      round 2, replace plain `#expect(x != nil)` with concrete assertions on
      internal fields. Focus on: `StockSageCapitalAllocatorTests`,
      `StockSageExpectedValueTests`, `StockSagePortfolioAnalyticsTests`,
      `StockSagePaperTraderTests`, `StockSageNetCostSimTests`.
   b) **Fix F40 derived-expected fixtures** — In `StockSagePaperTraderTests`
      and `StockSageTodayPlanRankedTests`, replace `expected = <call to
      function under test>(...)` with independently hand-computed numeric
      constants (use Opus's hand-derivations from task 2).
   c) **Add Kelly halfKelly ≤ 0.5 parametric sweep** — New test in
      `StockSageKellyTests` that sweeps (W,R) pairs and asserts the invariant.
   d) **Add gross ≥ net EV parametric test** — New test in
      `StockSageExpectedValueTests` sweeping cost levels.
   e) **Verify and enforce alert log cap** — Find where `Alerts.detect` results
      are appended to `store.alerts` and ensure cap=50 is enforced.
   f) **Add PositionSizer shares→0 invariant test** — Assert dollarsAtRisk
      stays within budget even when shares floor to 0.
2. All tests MUST pass. Build gate: `xcodebuild build → ** BUILD SUCCEEDED **`.
   Test gate: `xcodebuild test -only-testing:"Salehman AITests" → ** TEST SUCCEEDED **`.
3. Log every change with file:line and rationale.

## DeepSeek V4 Flash — Bulk Sweep & Catalog
**Best at:** High-volume, simple, repetitive tasks — first-pass code, edge-case
enumeration, documentation sweeps.

**Tasks:**
1. **Edge-case catalog** — For every money-math function in these files, enumerate
   ALL edge cases and whether each has a guard:
   - `StockSageExpectedValue.swift` (ev, velocity, netEVR, expectedLogGrowth,
     velocityRankKey, evRankKey, bestOpportunity, fastLane)
   - `StockSageNetEdge.swift` (evaluate, clearsCost, netRR, defaultCosts)
   - `StockSageKelly.swift` (compute, portfolioCap)
   - `StockSagePositionSizer.swift` (size)
   - `StockSageCapitalAllocator.swift` (allocate, suggestAdd, rebalanceToEdge)
   Output as a markdown table: function | edge case | guarded? | guard line.
2. **@AppStorage key conflict scan** — Search all `@AppStorage` keys across the
   StockSage and Markets modules for potential naming conflicts. List every key
   with its file:line and purpose.
3. **Dead code scan** — Search for any exported (non-private) functions in
   StockSage modules that are NEVER called by production code or tests. List
   each with file:line. Do NOT report deliberately-unwired modules (they have
   doc comments saying UNWIRED).
4. **Documentation accuracy sweep** — For every `///` doc comment on a public
   function in StockSage modules, verify the claimed behavior matches the
   implementation. Flag any drift.

## Gemini 3.1 Pro — Independent Math Verification
**Best at:** Math/science/data, formula derivation, structured verification,
second opinion on hard reasoning problems.

**Tasks:**
1. INDEPENDENTLY derive the following from financial first principles
   (do NOT read the Swift code until after deriving):
   a) **Expected value formula**: pWin·rewardR − (1−pWin) — verify the loss
      is correctly modeled as −1R (a full stop-out). Derive the break-even p.
   b) **Kelly criterion**: f* = (p·R − (1−p)) / R = p − (1−p)/R. Derive from
      the log-wealth maximization. Verify half-Kelly = f*/2.
   c) **Net-edge model**: Derive netReward = grossReward − cost (in R units),
      netRisk = grossRisk + cost. Derive netRR = netReward/netRisk.
      Derive break-even p = 1/(1+netRR).
   d) **Velocity = EV / expectedHold**: Show dimensional correctness.
      Derive that EV/day rankings are growth-rate-optimal under re-investment.
   e) **Log-growth**: E[ln(1 + f·outcome)] for binary outcomes (+R, −1).
      Derive the optimal f. Show half-Kelly is 75% of max growth rate.
   f) **Deflated Sharpe**: Derive PSR from Sharpe, skew, kurtosis, and sample
      size. Derive expectedMaxSharpe from Euler-Mascheroni + inverseNormal.
   g) **Position sizing chain**: Show that riskFraction → riskPerShare →
      shares = floor(account × riskFraction / riskPerShare), notional =
      shares × entry, dollarsAtRisk = shares × riskPerShare. Verify
      dollarsAtRisk ≤ account × riskFraction within rounding.
2. Compare your derivations against Opus 4.8's derivations. If they disagree,
   flag for Fable 5 to adjudicate.
3. Report: which formulas match the code, which diverge, and why.

## Gemini 3.5 Flash — Test Fixture Generator & Doc Sweep
**Best at:** Bulk content generation, cheaper alternative for structured output,
documentation writing.

**Tasks:**
1. **Generate test fixtures** for the edge cases Opus and DeepSeek Flash
   identify. For each edge case, produce a Swift `@Test` function body with:
   - A hand-derived expected value (use Gemini 3.1 Pro's derivations)
   - Fixtures that genuinely straddle the boundary
   - Hard `#expect` assertions (never `!= nil` alone)
   Output as complete `@Test func` blocks ready to paste into test files.
2. **Write the `KELLY_INVARIANTS.md` document** — A standalone reference
   documenting every Kelly/sizing invariant in the engine, with:
   - The invariant statement
   - Where it's enforced in code
   - The test that pins it
   - The hand-derivation proving it
3. **Write the `NETEDGE_REFERENCE.md` document** — Standalone reference for
   the net-edge cost model, with all formulas derived, all cost assumptions
   cited, and the research backing each number.

## Sonnet 5 — Careful Implementation
**Best at:** Reading and implementing plans precisely, careful code changes,
strong at following specs without deviation.

**Tasks:**
1. Take the ACTION LIST Fable 5 produces and implement each item in order,
   ONE item at a time. After each item: build + test before proceeding.
2. For any item that requires a numeric assertion, FIRST run the standalone
   derivation script Opus or Gemini 3.1 Pro produced, pasting its output as
   a comment in the test before writing the assertion.
3. STOP on any mismatch between the plan and reality (executing-plans discipline).
4. After ALL items: regenerate SOURCE_BUNDLE, update DEVELOPMENT_LOG, verify
   `git diff --stat` matches what was actually done.

---

# 3. EXECUTION ORDER

1. **Fable 5** reads this brief, produces execution plan → shares with all models
2. **Gemini 3.1 Pro** + **Opus 4.8** work in PARALLEL on independent math verification
3. **DeepSeek V4 Flash** runs bulk catalog in PARALLEL with step 2
4. **Fable 5** adjudicates disagreements between Opus and Gemini 3.1 Pro derivations
5. **DeepSeek V4 Pro** implements fixes from Opus findings + audit-documented items
6. **Gemini 3.5 Flash** generates test fixtures and reference docs
7. **Sonnet 5** implements Fable's final action list, one item at a time
8. **Fable 5** final adjudication + DEVELOPMENT_LOG entry

---

# 4. CONSTRAINTS (HARD — do not violate)

- **NO owner-gated changes**: RANKING #10 `preferVelocity` stays false. F08
  "Conviction" term stays unsettled. F03/F44 weekly netting stays gross-labeled.
  Cost-table stays owner-held.
- **NO UI changes**: Only engine, ranking, money-math, and test files. Do NOT
  edit `MarketsView.swift`, `DesignSystem.swift`, or any View file.
- **NO reverting shipped improvements**: All 16 items under §1 are INTENTIONAL.
  Read them before editing.
- **Honesty floor**: Every numeric assertion must be hand-derived, not read
  from the code. Gross/net must be labeled. Estimates must say "estimated."
- **Build + test GREEN after every change**: `xcodebuild build CODE_SIGNING_ALLOWED=NO`
  and `xcodebuild test -only-testing:"Salehman AITests" CODE_SIGNING_ALLOWED=NO`.
- **executing-plans discipline**: STOP on any plan-reality mismatch. Never adapt
  silently. Paste verification output proving behavior fired.
- **Work directly on `main`**: Pull --ff-only before each commit. Git add BY NAME,
  never `-A`. No new branches.

---

# 5. FILE MAP — What's where

- Engine core: `Salehman AI/StockSage/StockSage{Advisor,Indicators,Regime,Store}.swift`
- Ranking/EV: `Salehman AI/StockSage/StockSageExpectedValue.swift`
- Net-cost: `Salehman AI/StockSage/StockSageNetEdge.swift`
- Sizing: `Salehman AI/StockSage/StockSage{Kelly,CapitalAllocator,PositionSizer}.swift`
- Risk: `Salehman AI/StockSage/StockSage{RiskOfRuin,MonteCarloRuin,GapRisk,LossLimit,Leverage,PortfolioHeat}.swift`
- Analytics: `Salehman AI/StockSage/StockSagePortfolioAnalytics.swift`
- Vol/Shape: `Salehman AI/StockSage/StockSage{VolRegime,VolStability,ReturnShape}.swift`
- Calibration: `Salehman AI/StockSage/StockSageConvictionCalibration.swift`
- Backtest: `Salehman AI/StockSage/StockSage{Backtester,DeflatedSharpe,NetCostSim,StrategyBacktest}.swift`
- Alerts: `Salehman AI/StockSage/StockSage{Monitor,Alerts,AlertDecision,SignalEngine}.swift`
- Paper: `Salehman AI/StockSage/StockSagePaperTrader.swift`
- Journal: `Salehman AI/StockSage/StockSageJournal.swift`
- Tests: `Salehman AITests/StockSage*Tests.swift`
- Design: `Salehman AI/DesignSystem/DesignSystem.swift` (append-only)
- Canonical gate list: `gated-scope` skill §1 (read before starting)
- Campaign map: `money-campaign-map` skill (current phase, validated edges)
