# PROPOSAL — Disk history cache for StockSage (design, docs-only) — 2026-07-03

**Author:** Opus 4.8 lane, task O8 (issued by Fable 5). **Status:** design proposal, NO code.
**Origin:** O6 (`research/NETCOST_SIM_REAL_PANELS_2026-07-03.md`) found the app persists last-good *quotes*
(`StockSageQuoteCache`, 1 return/symbol) but **never persists price histories**, so `StockSageNetCostSim`
(and any backtest/indicator) cannot run offline on real data. This formalizes O6's constructive note into a
design + an owner decision-list. Nothing here is implemented; Fable converts it to a house plan if approved.

## 1. The gap (measured, from O6)

- Persisted today: `~/Library/Application Support/salehman_quote_cache.json` — `StockSageQuoteCache`, 209
  symbols × 1 quote each (`price`, `previousClose`, `time`, `isNewListing`). **No time series.**
- Histories ARE fetched, in bulk, every analysis: `StockSageQuoteService.fetchHistories(for:range:"1y",
  interval:"1d",concurrency:6)` (`StockSageQuoteService.swift:168`), consumed at `StockSageStore.swift:318`
  (`let histories = await …fetchHistories(...)`) to `buildIdeas`, then **discarded** (held only for the
  refresh's lifetime). The data the sim needs is fetched and thrown away.
- Shape available to persist: `StockSagePriceHistory` (`:250-261`) = `symbol` + parallel equal-length arrays
  `dates:[Date]`, `opens/highs/lows/closes/volumes:[Double]`, newest LAST.

## 2. Design

### 2.1 What to store — two options (OWNER DECISION #1)
- **Option A — closes + dates only (minimal).** Serves `StockSageNetCostSim` (returns = Δcloses) and every
  returns-based signal. Does NOT reconstruct ATR/gap/OHLC-dependent reads.
- **Option B — full OHLCV (`StockSagePriceHistory` verbatim).** Serves the ENTIRE ideas board offline
  (advisor, indicators, sim) — the board could render real ideas on launch with no network, labeled stale.
  ~4× the storage of A.
- Recommendation: **B if the goal is an offline-capable board; A if the goal is only to unblock the sim.**
  Both are small (§2.4).

### 2.2 Storage medium — JSON vs SQLite (OWNER DECISION #2)
- **JSON (recommended).** Mirrors the existing `StockSageQuoteCache` pattern exactly (a `Codable` struct +
  `diskURL()` in Application Support + atomic `write(options:.atomic)`), so it inherits a proven, tested
  shape and the same honest-staleness discipline. Whole-file load on launch; at the sizes in §2.4 this is a
  sub-second, off-main decode (the app already off-mains the 79 KB `knowledge.json` and larger work).
- **SQLite.** Enables per-symbol incremental upsert + load-on-demand + query, at the cost of a new dependency,
  a schema/migration story, and complexity that ~10–20 MB does not justify. Revisit only if the window grows
  to many years or intraday bars (100s of MB).
- Recommendation: **JSON now**; SQLite is a later scale decision, not a launch decision.

### 2.3 Write path — piggyback, ZERO new network
- After the existing bulk fetch succeeds (`StockSageStore.swift:318`), hand the already-in-memory
  `[String: StockSagePriceHistory]` to a new `StockSageHistoryCache.save(histories, savedAt:)`. No new fetch,
  no extra endpoint pressure — it persists bytes the app already downloaded and currently discards.
- On launch, `StockSageHistoryCache.load()` seeds the board (Option B) and/or the sim (Option A/B). A live
  refresh then overwrites it (last-good wins). Same lifecycle as `StockSageQuoteCache`.

### 2.4 Size & eviction math (shown)
1 year daily ≈ **252** trading bars/symbol; target universe **1,024** symbols.

| Layout | Per symbol | ×1,024 | JSON on disk (≈) |
|---|---|---|---|
| **A: closes + dates** (2 arrays × 252) | 252×2 = 504 values | 516,096 values | **≈6.5–7 MB** (≈26 chars/bar: close ~12 + epoch date ~12 + delimiters) |
| **B: full OHLCV** (6 arrays × 252) | 1,512 values | 1,548,288 values | **≈18–19 MB** (≈72 chars/bar) |

Binary lower bounds (8 B/Double): A = 1,024×252×2×8 ≈ **4.1 MB**; B = 1,024×252×6×8 ≈ **12.4 MB**. Either way
this is **trivial** for Application Support (the quote cache is already 21 KB; `knowledge.json` 79 KB).
**Growth is bounded**: a fixed 252-bar window × the universe cap — it does not grow without limit.
- **Eviction / trim:** on each `save`, (a) keep only the last 252 bars per symbol (trim older), and (b) drop
  symbols no longer in the current universe (so a shrinking/rotating universe cannot leak storage). Optional
  small LRU for recently-removed symbols; not required given the hard universe cap.
- **Date compaction (optional, Option A):** dates are ~identical across symbols (shared trading calendar), so
  a future optimization could store one calendar axis + per-symbol closes — cuts A roughly in half. NOT
  recommended for v1 (per-symbol dates are simpler and correctly handle holidays/late listings/half-days).

### 2.5 Staleness & the honesty floor (NON-NEGOTIABLE)
Cached history must NEVER silently masquerade as live. Mechanisms:
- **`savedAt`** on the cache (as `StockSageQuoteCache.savedAt` already does); every cached-history-derived
  surface is labeled "as of `savedAt`, not live" — reuse the existing staleness-labeling the quote cache
  already applies ("rebuilt rows are last-good as of `savedAt`, not live — the UI labels them so",
  `StockSageQuoteCache.swift:9`).
- **Per-symbol freshness gate (OWNER DECISION #3):** if a symbol's newest cached bar is older than *T*
  trading days, that symbol's history is STALE — usable for a backtest/sim (inherently historical) but NOT
  for computing a "fresh" idea/signal presented as current. Recommend **T ≈ 5** trading days.
- **Sim vs live distinction:** a `NetCostSim`/backtest verdict from cached history is labeled "on cached
  candles as of `savedAt`" — never conflated with a live result. (O6's whole point: enable the honest offline
  run, still honestly labeled.)
- **Never fabricate:** a missing/short/too-stale history stays `nil` (the frozen nil-contract), never a
  guessed or zero-filled series.

### 2.6 Invalidation & schema versioning
- **Overwrite on success:** a completed live `fetchHistories` replaces the cache (last-good).
- **Schema-version fallback:** add an explicit `schemaVersion` (or rely on Codable's all-or-nothing decode,
  the precedent `StockSageQuoteCache` set when it added `isNewListing`: "a cache file written before this
  field existed simply won't decode … `load()` returns nil rather than guess"). A schema change ⇒ old cache
  fails to decode ⇒ `load()` returns nil ⇒ one clean re-fetch. **No silent misdecode.**
- **Corruption:** `try?`-guarded read (as `StockSageQuoteCache.load()`), nil on any decode failure.

### 2.7 Test strategy (described; hand-derived fixtures per `testing-discipline`)
1. **Codec round-trip:** encode→decode a `StockSageHistoryCache` preserves parallel-array equality (mirror
   `StockSageQuoteCacheTests`); parallel arrays stay equal-length.
2. **Trim/eviction:** saving a 400-bar history keeps exactly the last 252; saving a symbol not in the universe
   is dropped on the next save; total stays under the §2.4 budget for 1,024 symbols.
3. **Staleness labeling (honesty-floor, HARD assert):** a cache with `savedAt` = *T*+1 trading days ago →
   the derived read is labeled stale / not-live and a "fresh idea" is suppressed for that symbol
   (`#expect` the label + the suppression, not "it looks right").
4. **Schema-version fallback:** a cache serialized without a newly-added field → `load()` returns `nil`
   (no partial/guessed decode) — the `isNewListing` precedent.
5. **Offline-sim enablement (the O6 unblock):** `StockSageNetCostSim.simulate` on a panel built from a loaded
   real cache returns a **non-nil** verdict (≥4 rebalances now available) — the concrete proof this proposal
   fixes O6's coverage gap.

## 3. Decision-needed list (for the owner)
1. **Scope:** closes+dates (unblock the sim) vs full OHLCV (offline-capable board). §2.1.
2. **Medium:** JSON (recommended) vs SQLite. §2.2.
3. **Freshness threshold *T*** (trading days before cached history is "too stale" for a live-presented idea).
   Recommend 5. §2.5.
4. **Window length:** 1 year (252 bars, matches `fetchHistories` default) vs 2y+ (better DSR/backtest
   samples, ~2× storage). §2.4.
5. **Offline board:** should the board *render* ideas from cached history on launch (honestly labeled), or
   should the cache only seed the sim? A product/honesty call. §2.1/§2.5.

## 4. Why this is worth doing
- **Unblocks O6:** a real-data net-cost verdict for the IRRX overlay (and any future signal) becomes possible
  offline, at zero extra endpoint pressure — directly relevant while O4 shows the live endpoint is
  throttle-sensitive.
- **Faster, offline-resilient launch** (Option B): the board can show real, honestly-stale ideas before the
  first network round-trip, instead of waiting on `fetchHistories`.
- **Cheap & bounded:** ≤~19 MB, fixed-window, mirrors an existing tested pattern.

**Out of scope / not touched here:** no Swift written; no edit to `StockSageQuoteService`/`StockSageStore`;
this is a proposal for Fable to convert to a plan. The `fetchHistories` network path and its throttle
behavior are unchanged — the cache only persists what that path already returns.
