---
name: salehman-activate
description: Use at the start of, on resuming, or after a context-compaction in ANY Salehman AI ideas-card / StockSage / Markets task — when you need to know which of the project skills to load for the work at hand (editing the engine, deciding what to build, ablating, testing, shipping, reviewing, debugging, owner-gated calls).
---

# salehman-activate — the workstream skill router

One entry point for the Salehman ideas-card / StockSage workstream. It does NOT replace the
skills below — it tells you WHICH to invoke for the task at hand, so none is missed. **Invoke the
mapped skills; don't just read this.** For the deep operating protocol invoke `opus-operating`;
for how skills work at all, `superpowers:using-superpowers`.

## Task → skills to invoke first

| What you're doing | Invoke |
|---|---|
| Session start / after a compaction | `opus-operating` → `stocksage-mental-model` → `gated-scope` |
| Editing `StockSage/*` or a Markets view | `stocksage-mental-model` + `gated-scope` + `stocksage-flags-and-config` |
| Deciding what to build for the money engine / "make money faster" | `money-campaign-map` + `research-memory` |
| Running or writing up an ablation / backtest | `ablation-harness` + `research-memory` + `spec-fidelity` |
| Writing / fixing / reviewing a test | `testing-discipline` + `spec-fidelity` |
| Reporting a result, citing a number, logging, declaring "done" | `fact-discipline` |
| Reviewing another session's or Grok's code | `markets-review-gate` + `incident-ledger` |
| Shipping ANY change (code, docs, tests) | `shipping-changes` |
| A build/test failed or the app misbehaves | `debugging-guide` + `diagnostics-toolkit` |
| A UI-visible change (ideas board / detail sheet) | `visual-qa` (pixels, after merge) + `run-salehman-ai` |
| Running an improvement wave on a shipped surface | `wave-cycle` |
| Build / run / screenshot / type-check the app | `run-salehman-ai` |
| "Has this failure happened before?" | `incident-ledger` |
| ANY owner-gated decision (RANKING #10, F01/F02, F03/F44, F08, F10) | `gated-scope` §1 → **REFUSE, surface options, do not proceed** |

## Non-negotiables (they bind every task above)

- **Honesty floor:** nil = unknown (never fabricated); estimates labeled; gross vs net always
  labeled; "measured" only from real outcomes; a negative result is a deliverable.
- **Gates are walls:** the parked owner decisions in `gated-scope` §1 are refused, not flagged-and-done.
- **Evidence over claims:** "done" = pasted verdict-line / `git diff` / hand-derivation, never "it passes".
- **Never lose work / no collisions:** worktrees + WIP commits; single writer per file; add-by-name;
  cherry-pick onto latest origin; never `reset --hard`; leave other sessions' dirty files.
- **The engine has NO proven edge** (DSR ≈ 0) — its value is risk-discipline; don't imply alpha.

## When NOT to use
Non-Salehman work; or when you already have the right skill loaded for the task. This is a router,
not a substitute for the mapped skill's own content.
