# Net-cost sim on REAL cached panels — coverage result (2026-07-03)

**Task:** O6 (Opus lane, Round 2) — run `StockSageNetCostSim.simulate` (the IRRX net-of-cost gate) on
REAL market data, WITHOUT any network, using the app's persisted quote cache; report the honest Deflated-Sharpe
verdict + coverage caveats.

## Verdict (honest, negative)

**NOT RUNNABLE from the persisted cache without network.** The app persists no multi-day price histories to
disk — only a single last-good quote per symbol — so no walk-forward return panel can be reconstructed, and
`StockSageNetCostSim.simulate` returns `nil` on the available data by its own minimum-length guard. This is a
**coverage result, not a harness failure**: the synthetic-fixture result from O3 stands unchanged (the IRRX
overlay does **not** clear net-of-cost; `clearsNetOfCost=false`). No real-data DSR could be computed.

## Method

1. Located the only on-disk market-data cache from source: `StockSageQuoteCache.diskURL()` →
   `~/Library/Application Support/salehman_quote_cache.json` (`StockSageQuoteCache.swift:62-66`).
2. Inspected its actual contents (read-only, no network) to measure coverage.
3. Checked whether any *history* (multi-day close series) is persisted anywhere — required because
   `simulate` needs a per-symbol return time series (a `lookback` window + ≥1 forward hold, and ≥4
   non-overlapping rebalances for a `verdict`).

## Evidence (measured, as-of 2026-07-03T00:32:56Z)

- **Cache file:** `salehman_quote_cache.json`, 21,238 bytes, mtime 2026-07-03 03:32 local.
- **`savedAt`:** 804731576.892 (Core Data epoch) = **2026-07-03T00:32:56Z**.
- **Entries:** **209** symbols (the analyzed-core set — 2222.SR, 1120.SR, 7010.SR, …).
- **Per-entry shape (all 209 identical keys):** `{ symbol, price, previousClose, time, isNewListing }` —
  i.e. **one quote per symbol** (`price` + `previousClose`), which is **exactly one return** per symbol and
  **no time axis** (each entry is a single snapshot; there is no array of closes). Confirmed by
  `jq '[.entries[]|keys]|unique'` → a single key-set with no history/close array.
- **History persistence:** none. `StockSageQuoteService.fetchHistory` (`:153`) is **network-only** (fetches
  `range=1y` from Yahoo v8 on demand); the resulting `StockSagePriceHistory` is held transiently in
  `StockSageStore` for the session and is **never written to disk**. A full-tree scan of Application Support
  found only `salehman_quote_cache.json`, `SalehmanAI/{chats, knowledge.json, prompts.json}` — no history cache.

## Why the harness cannot run on this

`StockSageNetCostSim.rebalanceSeries` guards `T >= lookback + hold` (default `lookback=2, hold=1` ⇒ needs
`T >= 3` periods per symbol); `simulate` further requires `rebs.count >= 4` non-overlapping rebalances to
produce a Deflated-Sharpe `verdict`. The cache offers **T = 1 return per symbol** ⇒ `rebalanceSeries` returns
`[]` ⇒ `simulate` returns `nil`. A cross-section of 209 single-returns has no time dimension for a
walk-forward reversal, so it cannot substitute for a per-symbol panel.

## Coverage caveat (stated plainly)

- Symbols with usable panels: **0 / 209** (each has 1 return; the harness needs ≥3 periods, ≥4 rebalances).
- Real-data DSR verdict for the IRRX overlay: **not computable offline** from the current persisted cache.

## Constructive note (for Fable — out of the Opus lane, NOT implemented here)

A no-network real-data run would become possible if the app persisted `fetchHistory` results to a disk
history cache (e.g. a `salehman_price_history.json` of `[symbol: [close]]`, last-good, `savedAt`-labeled,
same honest-staleness labeling as the quote cache). That is a code change in `StockSageQuoteService` /
`StockSageStore` (a new persistence layer), outside this read-only measurement task. Until then, a real-panel
net-cost validation requires a (throttle-gentle) live history fetch — the same endpoint O4 is verifying —
which is explicitly out of scope for O6's no-network constraint.

## Bottom line

The persisted cache is **quote-only** (209 × 1 return), so the net-cost gate cannot be exercised on real data
offline. The honest result is the coverage gap itself; O3's synthetic-fixture finding (IRRX does not clear
net-of-cost) is neither confirmed nor refuted on real data by this attempt.
