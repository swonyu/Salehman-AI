# Changelog — Salehman GE Flips

## 2026-06-25 — major feature + hardening pass

A large expansion of the flip finder, each feature build-verified and put through
multiple rounds of adversarial review (38 confirmed findings fixed).

### Ranking
- **Realized gp/hour** sort (now the default): theoretical gp/hour × a freshness-confidence
  multiplier (1.0 when quotes are fresh → 0.25 floor by ~3h) so stale spreads that won't
  fill are down-ranked. Deterministic id tie-break on every sort.

### Panel
- Item **icons**, a colored **profit/ROI hero line**, RS-style compact numbers, a per-row
  **freshness dot**, and a live **"Updated Ns ago"** clock.
- In-panel **sort dropdown**, live **name search**, and **favourites** (★, persisted,
  pinned to top, "favourites only" filter).
- **Click a row** to expand a recent **price sparkline**; **right-click** for wiki links
  and to copy the name / buy price / sell price.
- **"Thin volume"** badge when daily volume is low relative to the buy limit.

### Money tools
- **Budget allocator** — enter your gp (e.g. `100m`) and it plans what to buy, up to each
  item's 4h buy limit, with total profit, realized gp/hour and a best-case "+X/day"
  extrapolation. Optional **diversification cap** (max % per item) with a concentration
  readout.
- **"Alch instead"** cue — flags when High Alchemy (highalch − nature − item cost, at an
  acquisition-gated cast rate) beats a flip's realized gp/hour.

### Live / passive
- Optional **auto-refresh** on an interval and **notifications** when a flip crosses a
  gp/hour threshold (primed baseline, deduped, capped).
- Opt-in draggable **in-game overlay** (top-flips HUD).

### Correctness / robustness
- GE tax via exact integer floor; tax-exempt items (Old School Bond) not taxed.
- Per-call HTTP timeouts; mapping cache TTL that serves the stale cache on failure
  instead of erroring; single-flight refresh with mid-flight coalescing.
- Config-panel edits re-rank immediately; thorough EDT/threading and lifecycle hygiene.
- Pure logic (FlipFinder, BudgetPlanner, Sparkline.mids, notification gating) is unit-tested.

> All velocity/projection/alch figures are volume-/attention-gated **estimates**, not
> guarantees — see the in-panel disclaimer.
