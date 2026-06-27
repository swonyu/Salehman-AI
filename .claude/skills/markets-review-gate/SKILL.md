---
name: markets-review-gate
description: How to act as a review gate on agent/Grok-generated code (especially the Markets UI) in Salehman AI — catch real bugs before they land, tell transient mid-write breaks apart from real regressions, route fixes to the owning session, and build without colliding with concurrent sessions. Use when reviewing another session's or Grok's changes rather than writing them.
---

# Markets review gate

You review code produced by other sessions / Grok agents **without editing their lane**. You FIND + FLAG; the owning session fixes. This is highest-value when several agents edit one big file in parallel.

## Review like the #12 catch — trace, don't trust
1. Read the actual diff: `git diff -- "<file>"`.
2. **Trace it to the call site.** Don't infer data flow from a function's body — find where it's *called* and check the caller's assumptions. (Two real bugs caught this way: a fire-and-forget refactor of an `async` function broke a caller that read the result right after `await`; removing a `defer` reintroduced a stuck loading flag on an early-return path. Both compiled; both were regressions only the call-site trace revealed.)
3. Build-verify with isolated DerivedData (see "concurrent builds").

## Transient mid-write ≠ bug
Four agents editing one 4000-line file leave the tree broken mid-keystroke constantly. Classify:
- **TRANSIENT** (recheck next cycle, NOT a bug): the agent is actively editing (`⏳` in its session log), a new file is empty/half-written, or there's a dangling body mid-extraction.
- **REAL** (flag it): a persisting non-compiling state while the agents are idle, or a wrong edit traced to its call site. A REAL break that survives ≥2 cycles while agents idle is the threshold to escalate.

## Route, don't fix (lane discipline)
You do NOT edit the owning session's lane (e.g. `Views/*`). For a real break, append a ready-to-apply fix-ticket to `GROK_FIXES.md`: `file:line` · the traced mistake · the exact fix · how to verify · the lane. The owning session watches that file and fixes it. To do parallel UI work yourself, add **new component files you own** — never co-edit the contested monolith (last-save-wins clobbers everyone).

## Concurrent builds — never corrupt
`pgrep -f xcodebuild` first. NEVER run two builds on the same DerivedData. Build in an isolated worktree or with `-derivedDataPath /tmp/<name>-dd` so your build can't corrupt theirs (different path → different DerivedData).

## The Grok heuristic (hard-won)
Grok — relayed or as a Safari agent — is genuinely strong at **reasoning and reading real files**, and **fabricates pasteable code**: invented type names (`StockIdea` vs `StockSageIdea`), invented commit SHAs, iOS-only APIs in a macOS app, hollow shells that call no real code, and proposing already-shipped features. **Never paste Grok code.** Verify even its *grounded* answers against the call site — its best, well-cited answer once mischaracterized a wiring that the call site disproved.
