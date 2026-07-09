# TRIAGE — critique rotation-3 (degraded-states / first-run / terminology), 2026-07-10

**Source:** wf_f3708a47-ec1, 3 read-only Fable-xhigh lenses, 15 findings (2 HIGH / 7 MED / 6 LOW), extensive clean-checks recorded in the journal. ALL findings are display/disclosure/copy class — no cost value, gate math, sizing math, or rank-order changes. All 15 ACCEPTED for one wave.

## Wave B items (single writer, worktree)

**D-lens (degraded-state honesty):**
1. **HIGH** `MarketsTodayActionsCard.row(_:_:)` ~L296 — visible+spoken "⚠︎ price as of <date> — not live; re-price before ordering" when `plan.priceAsOf` is prior-UTC-day (same `utcDayKey` check `copyAllText` already uses; nil renders nothing). Kills the "export more honest than pixels" violation.
2. **MED** Deploy-capital copy path (~L4229-4240) — prepend "⚠ SAMPLE DATA" when `store.isSampleData`; per-line "| ⚠ PRICE NOT LIVE — as of …" via each position's idea.priceAsOf (mirror `copyAllText` verbatim); visible one-line stale note on the card when any allocated position is prior-day.
3. **MED** `bestOpportunityCard` (~L3994) + `bestOpportunityCTA` (~L4588) — upgrade `staleAsOfPrice` to the two-axis `cardIsStale` (price OR analysis>4h); analysis-stale-only wording "analysis over 4h old — re-scan for a current read"; fold into a11y.
4. **LOW** TodayView "Best bet" tile (~L260-272) — append `sourceTagLabel` output to `.help`; "⚠︎ stale — " prefix on detail when `cardIsStale`.
5. **LOW** `sampleBanner` ~L643 — show BOTH truths (sample sentence + feedError appended), not `feedError ?? sample`.

**F-lens (first-run):**
6. **HIGH** `@AppStorage("marketsSizerAccount")="10000"` / risk `"1"` defaults (L171-172) → `""` (unset). Every downstream nil path ships + is QA-exercised (nilrisk fixture). NOTE: behavior shift on FRESH INSTALLS ONLY (owner's AppStorage already holds real values); enforcement of "never fabricate" on the money-prescribing surfaces. Tests: pin that empty AppStorage → sizer nil-path branch renders SET-RISK affordance not sized orders.
7. **MED** first-scan-in-progress caption on `bestOpportunityCard` + `moneyVelocityCard` when `store.isLoadingIdeas && store.ideasUpdated == nil`: "First scan in progress — N of M names analyzed; best-so-far, order may change" via existing `ideasProgress`.
8. **LOW** auto-gauge regime once in the same first-run `.task` that auto-scans: `if store.regime == nil { await store.refreshRegime() }` (button stays for re-gauge).
9. **LOW** summary strip "avg conv" chip → "avg signal" + optional `.help` on non-interactive chips ("rules-based score, not a probability").

**T-lens (terminology drift):**
10. **MED** moneyVelocityCard "Best now" sub-label L4402 + a11y L4522 → "Est. EV %+.2fR (gross)" / "estimated EV … gross" (the only unlabeled EV left).
11. **MED** `prefillTradeFromIdea` L2239 journal note → "signal strength N/100" (F08 vocabulary; percent form removed per wave-8).
12. **MED** ideaCard EV-chip `.help` L3612 "round-trip frictions" → "est. round-trip costs" (993bdce straggler).
13. **MED** detail-sheet sizer 0-share message L5355 → lead with the Wave-A ratified "Below the 1-share minimum at your account size…" phrase, keep remedy + honesty tail.
14. **LOW** ideaCard Vel. `.help` L3691 → align ordering-key naming with the fastLane hover ("per-day log-growth at ½-Kelly, cost-haircut").
15. **LOW** `StockSageTodayPlan.build` L112 "≈ 150 at risk" → "≈ $150 at risk" (match L280 + on-screen rows).

## Fences (unchanged from Wave A)
No cost VALUE, gate MATH, sizing MATH, rank-order, or flag changes. Item 6 changes DEFAULTS of two @AppStorage strings from fabricated values to unset — the honesty floor's own rule; sizing math untouched. Item 8 adds one existing-API call on first run only.

## Pipeline
Single Sonnet writer (worktree, WIP commits) → Fable adversarial review (fence sweep + full diff) → fix pass → my independent gate on merged main → ship (dev-log, bundle, MAP, add-by-name, push, CI by log) → pixel QA (today/markets fixtures + the nilrisk fixture for item 6).
