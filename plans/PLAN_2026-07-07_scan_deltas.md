# PLAN — Ideas-tab scan deltas ("New" / action-change chips), 2nd-24h-window item 3

Gap #3 from the owner-asked "what's the idea card missing" assessment: the board is amnesiac
between scans — nothing marks an idea as new or flipped. Design spec'd BEFORE fleeting (repo law).

## What renders (v1 — sort-independent facts only)
- **"New" chip** — the symbol was absent from the previous FULL scan. Neutral chrome.
- **"was <Action>" chip** — the action changed vs the previous full scan (e.g. "was Hold" on a
  now-Buy card). Neutral chrome; shows the PREVIOUS action verbatim (TradeAdvice.Action label).
- **DELIBERATELY EXCLUDED: rank-move chips ("↑3")** — the stored ranking order is NOT what the
  user necessarily sees (IdeaSort has 6 modes); a movement claim that silently references a
  different order than the visible one fails the honesty floor. Recorded here; revisit only with
  an owner-picked semantics (e.g. "moves under the default ranking, labeled as such").
- Both chips join the badge row's existing density protocol: they are LOW-priority — if the row
  already has five chips, delta chips are DROPPED for that card (density cap precedent from the
  journal-history round; a dropped context chip loses nothing money-relevant).

## Persistence (the "previous scan" snapshot)
- New tiny Codable: `{schemaVersion, scanDate, entries: [symbol: actionRawValue]}` in its own
  UserDefaults key `stocksage.prevscan.v1`.
- WRITTEN ONLY at the END of a successful FULL `performRefreshIdeas` commit (after `ideas =`),
  with the PRE-refresh scan's map — i.e. the store keeps the previous map in memory, publishes
  deltas for the new scan, then persists the new scan's map as the next baseline.
- `retryFailedIdeas` (partial merge) NEVER writes the snapshot — a partial scan as baseline would
  fabricate "New" chips for everything it didn't cover. Deltas after a retry are computed against
  the same last-full-scan baseline (consistent).
- `seedQAIdeas` assigns `ideas` directly and must NOT write the snapshot (the write lives in
  performRefreshIdeas only) — QA can never pollute the real baseline.
- Schema-version mismatch or absent key ⇒ NO deltas render (first run is honest: nothing is
  claimed "new" when there is no baseline — absence of data renders nothing, never "everything
  is new").

## Delta computation
Pure static: `deltas(current: [StockSageIdea], previous: [String: String]) -> [String: Delta]`
where Delta ∈ {new, actionChanged(previous: Action)}; case-insensitive symbol match; empty
previous ⇒ empty result (the first-run rule above).

## QA pixel story (zero-pollution, same discipline as the own-it/journal seeds)
- In-memory QA seam: the store's previous-scan map gets a `qaSeed`-style direct assign in the
  --qa path: seed a baseline where BTC-USD is ABSENT (→ its card renders "New") and AAPL's
  previous action was "Hold" (→ AAPL renders "was Hold"; AAPL currently has earnings+extreme+EV =
  4 chips → the delta chip is its 5th, inside the cap; BTC-USD has 24/7+EV ≈ 3).
- The seeded baseline never touches `stocksage.prevscan.v1` (in-memory assign; hash-check the key
  across a capture at the merge gate, the established proof).

## Tests (hand-derived per testing-discipline)
- deltas(): new symbol → .new; changed action → .actionChanged with the right previous; unchanged
  → absent; case-insensitivity; empty previous → empty (first-run rule).
- Store wiring: performRefreshIdeas writes the snapshot / retry does not — via the smallest
  honest seam (if none exists without store surgery, document per WHIPPYX and rely on the pure
  tests + pixel proof).

## Protocol
Fleet: sonnet-xhigh impl in /tmp/deltas-wt branch ideas/scan-deltas → fable-xhigh review (armed:
first-run rule, partial-scan baseline poisoning, density cap, QA pollution, sort-independence of
the claims) → my gate (build+test+grep, capture --adopt, pixel: BTC-USD "New" + AAPL "was Hold"
at both widths, hash-check prevscan key) → ship.
