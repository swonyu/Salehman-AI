# PLAN — StockSagePaperTrader (forward paper-trading harness) — 2026-07-03

**Owner request:** "build it" (a fake-money forward test of the engine's ideas) + "never make mistakes."
**Author:** Opus 4.8 successor. **Branch:** `ideas-card/paper-trader` (isolated worktree).

## Goal
Auto-paper-trade every long-actionable idea the engine generates, mark each to a **net-of-cost** fill,
close it when a bar crosses stop/target/time-stop, and accumulate the realized outcomes into a
**separate** store whose forward win-rate / R / DSR is the honest out-of-sample test the campaign's
"proven edge" milestone needs. Zero capital, zero manual effort.

## Fences (NON-NEGOTIABLE)
1. **F01/F02 (calibration semantics) is a WALL.** Paper outcomes MUST NOT feed the production
   `StockSageStore.convictionCalibration` / `fit(fromJournal:)`. The real calibration stays real-journal-only.
   Paper trades live in a SEPARATE store (distinct UserDefaults key), never conflated with the real journal.
2. **Honesty floor.** (a) Net-of-cost fills, never mid — a naive paper fill overstates and lies (the whole
   point of the app's cost research). (b) Paper vs real never conflated — separate store, "PAPER" labels.
   (c) nil = unknown: a trade with no bars after `openedAt` stays open, never a fabricated close.
3. **No `MarketsView.swift` edit this build.** It carries the uncommitted F08 edit (can't commit around it)
   and a UI panel needs visual-QA (headless-blocked). v1 = engine + persistence + wiring + tests. The
   display panel is a separate, QA-gated follow-up. The store EXPOSES the paper stats so the panel is trivial later.
4. **Derive, never copy; backtest parity.** Reuse `StockSageBacktester.simulateExit` for the bar-walk-to-exit
   and match its net-R convention exactly — the paper-trader's realized R must equal the backtester's for the
   same trade, so the two paths can't diverge.

## Design

### New file: `Salehman AI/StockSage/StockSagePaperTrader.swift`
Pure engine (enum, `nonisolated static`), reusing `TradeRecord` (from `StockSageJournal.swift`) as the record.

- `func open(from idea: StockSageIdea, at openDate: Date, costs: StockSageNetEdge.CostAssumption) -> TradeRecord?`
  - Long-only: returns nil unless `advice.action ∈ {strongBuy, buy}` AND `stopPrice` AND `targetPrice` are
    non-nil AND `entry(=idea.price) > stopPrice` (defined risk). No fabrication on missing data.
  - `entry = idea.price` (GROSS — matches backtester, which keeps entry gross and nets in the cost at exit),
    `stop = advice.stopPrice!`, `target = advice.targetPrice!`, `conviction = advice.conviction`,
    `openedAt = openDate`, `side = .long`.
  - `shares` = nominal fixed-risk sizing so the reused $ analytics are sensible: `max(1, round(nominalRisk /
    riskPerShare))`, `nominalRisk` param default $100. R is scale-free (the honest metric); $ is nominal — documented.
- `func markToMarket(_ open: [TradeRecord], history: StockSagePriceHistory, asOf: Date, costs:, maxHoldingBars: Int = 63) -> [TradeRecord]`
  - For each OPEN long trade whose symbol == history.symbol: find `startIdx` = first index with `dates[i] > openedAt`.
    If none → unchanged (stays open, honesty: no new data).
  - Reuse `StockSageBacktester.simulateExit(entryIdx: startIdx, stop:, target:, opens/highs/lows/closes:, n:, mode: .timeStop(maxHoldingBars))`.
  - Outcome `.openAtEnd` → stays open (unchanged). Otherwise close:
    `costPerShare = max(0, costs.roundTripBps)/10_000 * entry`; `netExit = grossExit - costPerShare`;
    set `exitPrice = netExit`, `closedAt = dates[exitIdx]`. Then `TradeRecord.realizedR == backtester net R`
    ((netExit − entry)/(entry − stop)). Only closes trades whose symbol matches this history (per-symbol call).
  - PURE + deterministic (no `Date.now`); `asOf` passed for any future use; dates come from the bars.

### New store: `StockSagePaperTradeStore` (in the same file or `StockSagePaperTrader.swift`)
Mirror `StockSageJournalStore` EXACTLY (proven pattern): `@MainActor final class`, `@Published private(set)
var trades: [TradeRecord]`, UserDefaults key `"stocksage.papertrades.v1"` (DISTINCT from the journal's
`stocksage.journal.v1`), `load()/save()` `try?`-guarded (nil on any decode failure — the frozen contract).
Exposes the reused analytics over ITS trades: `stats`, `edgeStats`, `systemHealth`, `rDistribution`,
`expectancyCI` (all via `StockSageJournal.*`) — labeled PAPER at the eventual UI. Plus `open`/`closed` counts.

### Wiring: `StockSageStore.performRefreshIdeas()` (after `ideas = ranked`, ~line 344)
New MainActor method `updatePaperTrades(ideas:histories:asOf:)`, called after ideas are set:
1. Mark-to-market existing open paper trades: for each symbol with an open paper trade, if `histories[symbol]`
   exists, call `markToMarket([thatTrade], history:, asOf: now, costs: defaultCosts(forSymbol:))`; persist closes.
2. Open new: for each ranked idea, if `open(from:at:costs:)` returns a trade AND no open paper trade exists for
   that symbol → add it (dedup: one open paper trade per symbol).
3. All via `StockSagePaperTradeStore.shared`. Cheap, synchronous, best-effort (never throws/blocks the refresh).
- Guarded by a flag `paperTradingEnabled` (default TRUE — the owner asked for it) so it's a clean seam; off
  ⇒ the store is never mutated (byte-identical refresh). Flag lives in the store, documented.

### OUT of scope (documented, not done)
- No UI panel (F08/MarketsView + visual-QA fence) — follow-up.
- Paper outcomes do NOT feed `convictionCalibration` (F01/F02 wall) — a separate owner-gated decision.
- No short paper trades (app is long-biased; stops are long-only).

## Tests (RED first, hand-derived fixtures — `testing-discipline`)
New `StockSagePaperTraderTests.swift`. Every fixture derived by hand in the test body (no harness output as fixture):
1. **open() gating:** buy/strongBuy with stop+target+risk>0 → non-nil with correct entry/stop/target/conviction/side;
   hold/avoid/reduce/sell → nil; missing stop or target → nil; entry ≤ stop → nil.
2. **markToMarket target hit (net R):** a hand-built 4-bar history where bar 2 high ≥ target. Expected
   `exitPrice = target − costPerShare`, `closedAt = dates[2]`, `realizedR` = hand-computed net value. Assert to 1e-9.
3. **markToMarket stop hit (gap-honest + net):** bar low ≤ stop (and a gap-down open below stop) → fills at
   `min(stop, open) − costPerShare`; realizedR < −1 (friction makes a stop-out worse than −1R). Hand-derived.
4. **stop-wins-ties:** a single bar where low ≤ stop AND high ≥ target → resolves to STOP (pessimistic). Assert outcome/price.
5. **time-stop:** neither level hit within maxHoldingBars → closes at that bar's close − cost, `realizedR` hand-derived.
6. **no bars after openedAt → stays open** (unchanged, isOpen == true). And openAtEnd (fewer than maxBars, no hit) → stays open.
7. **BACKTEST PARITY:** for one trade, `markToMarket`'s realized R == `simulateExit` + the backtester's
   `(exitPrice − entry − costPerShare)/risk` computed independently in the test → equal to 1e-9.
8. **store separation:** a paper trade added to `StockSagePaperTradeStore.shared` does NOT appear in
   `StockSageJournalStore.shared.trades` (distinct keys) — and vice-versa. (Isolate UserDefaults keys per testing-discipline.)
9. **Falsifiability probe:** break one assert, watch it fail by name, restore (guard against a vacuous filter).

## Exit checklist (`stocksage-mental-model` §8 + `shipping-changes`)
1. FULL suite green in the worktree (isolated `-derivedDataPath`); accept ONLY `** TEST SUCCEEDED **`.
2. `bash tools/bundle_source.sh` (never Read SOURCE_BUNDLE).
3. Dated `DEVELOPMENT_LOG.md` entry above the Standing-notes anchor.
4. `MARKETS_TAB_MAP.md` entry for the new file + note the `StockSageStore` wiring.
5. `PROJECT_CONTEXT.md` — add the paper-trader to the module catalog.
6. add-by-name (NEVER `-A`; MarketsView F08 edit stays untouched), branch CI green by verdict line, ff-only merge.
7. Adversarial review (workflow, diverse lenses: honesty-floor / gate-compliance / fill-math parity / test-vacuity) BEFORE merge.
