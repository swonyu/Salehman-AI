# PLAN — StockSage audit → review → improve wave (owner-directed, 2026-07-07)

Owner (verbatim): "audit and review the code then improve stocksage" — issued during the 24h
autonomous window with the 8th-revision fleet split (Fable 5 / Opus 4.8 / Sonnet 5, all xhigh).
This is the wave-cycle critique→triage→spec→implement→verify→gate→ship artifact.

## Scope — what gets audited (and what deliberately does NOT)

**EXCLUDED (already verified this cycle — re-auditing is churn):** the money-math core
(ExpectedValue/Kelly/NetEdge/PositionSizer/CapitalAllocator/DeflatedSharpe/Regime formulas) —
3-way blind-derivation verified 2026-07-07 (zero real bugs; commit 3caec00 log entry); the
2026-07-07 red-team (b31cd88, its one survivor F04 since fixed by the ux-wave-3 merge); the
five §1.A test pins (ac47361…c16b49f).

**IN SCOPE — six lenses:**
- **L1 (Opus xhigh) — recent-diff correctness:** everything landed in the last ~24h at HEAD:
  ux-wave-2 (a45ebac, MarketsView +345), earnings/liquidity wiring wave (71929c3), universe
  expansion (0520de7), ordinal blocks (6d49aeb), F04 closure merge. Diff-driven review.
- **L2 (Opus xhigh) — honesty-floor surfaces:** every displayed number's label duty (gross/net,
  assumed/measured, nil→nothing) on the ideas card / detail sheet / Today card / fast lane vs
  the stocksage-mental-model §4 table; a11y labels vs displayed values.
- **L3 (Fable xhigh) — Store, concurrency, data flow:** StockSageStore (MainActor seams, refresh
  watchdog, alert cap path, paper-trader wiring, reconcile-vs-tracked), QuoteService/QuoteCache/
  HistoryCache (cache honesty, eviction, schema), sample-data flag discipline.
- **L4 (Fable xhigh) — non-money engine seams:** Journal, PaperTrader (store separation, F01/F02
  wall), Monitor/Alerts/AlertDecision, RefuseList, ExecutionTiming, and the earnings/liquidity
  params threading END-TO-END (a surface that misses the new params ranks stale — the wiring
  wave's contract).
- **L5 (Sonnet xhigh) — test-gap sweep on recent code:** what landed in the last 24h without a
  value test; duplicate/dead code introduced by the recent waves.
- **L6 (Sonnet xhigh) — UI robustness:** 440pt-narrow wrap paths, .help text truth vs engine
  constants, keyboard-nav/debounce edge cases in the new sheet navigation.

## Verification protocol (repo standard)
Every MED+ finding is adversarially verified by TWO refute-by-default agents (one Opus, one
Fable, both xhigh) with pasted evidence (file:line + a concrete failure input); survives only
if not refuted. LOW/cosmetic findings pass through as unverified notes. The orchestrator (me,
Fable xhigh) adjudicates splits — evidence, not votes.

## Triage rules (post-audit)
- **Real bug (verified)** → fix in the improvement wave.
- **Improvement, non-gated** → rank by value-to-effort; implement.
- **Owner-gated** (RANKING #10, F03/F44, cost-table, term choices, anything ranking-default or
  cost-table shaped) → PARK with a note; never flag-and-proceed.
- **Reject** → record why (so it isn't re-filed).

## Improvement wave protocol (after triage)
Per item: Sonnet-xhigh implements in a worktree with WIP commits → Opus-xhigh adversarial diff
review → fix round if needed → I run the independent full build+test gate → UI-visible items get
pixel QA via the QA snapshot harness (markets_ideas / markets_ideas_narrow, in flight on branch
qa/ideas-capture) → ship per shipping-changes (dev-log, bundle, map, add-by-name, CI-green).
Engine/calc changes: tests hand-derived per testing-discipline (never from the code under test).

## Success criteria
Audit findings ledger (verified/parked/rejected) recorded in the dev-log; every shipped
improvement CI-green with its verification pasted; zero owner gates crossed; honest nulls
(clean lenses) recorded as nulls.
