# Design — Disk history cache for StockSage (`StockSageHistoryCache`)

**Date:** 2026-07-03 · **Author:** Claude #4 (Opus 4.8), autonomous 12h window · **Status:** design → implementation (owner pre-approved "do what you think is best / all 3").
**Basis:** extends `PROPOSAL_2026-07-03_history_cache.md` (O8) — this resolves its 5 open owner-decisions with conservative, goal-focused defaults and narrows scope to what is safe to land with the owner away (no UI change → no visual-QA gate; held engine gates untouched).

## Problem (measured, from O6 / `research/NETCOST_SIM_REAL_PANELS_2026-07-03.md`)
The app persists last-good **quotes** (`StockSageQuoteCache`, 1 return/symbol) but **never persists price histories** — `StockSageQuoteService.fetchHistories` is network-only and its result is discarded after `buildIdeas`. So `StockSageNetCostSim` (and any offline backtest/edge-validation) has **0 usable panels offline**. The campaign goal — a *measured* net-of-cost edge (DSR > 0.95) — is therefore hostage to the Yahoo v8 throttle. A disk history cache breaks that dependency at **zero extra network** (it persists bytes the app already downloads).

## Decisions taken (documented for owner review — each a 1-line flip if you disagree)
| # (O8) | Decision | Choice | Why |
|---|---|---|---|
| 1 Scope | closes-only vs full OHLCV | **Full OHLCV** (mirror `StockSagePriceHistory` verbatim) | Simpler (no projection ⇒ fewer mistakes), future-proofs an offline board, still only ~19 MB at 1,024 syms. |
| — Consumption | sim-only vs offline board | **Sim/validation only; board stays live-only** | Rendering ideas from cached history is a UI-visible behavior change ⇒ visual-QA gate I cannot run while owner away. Storing the data ≠ wiring the board. |
| 2 Medium | JSON vs SQLite | **JSON** | Mirrors the proven, tested `StockSageQuoteCache` exactly; ~19 MB doesn't justify a new dependency/schema. |
| 3 Freshness *T* | trading days before "too stale" for a live-presented idea | **5** (helper only; no UI consumer in v1) | Matches O8 recommendation; present for correctness + future board wiring. |
| 4 Window | 1y vs 2y+ | **1y (252 bars)** | Matches the existing `fetchHistories` default range — no change to the network path. |
| 5 Offline board | render from cache on launch | **No (v1)** | Owner-reviewable product/honesty call; deferred to keep v1 non-UI and safe. |

## Architecture (one new file + one save call + tests)
### `Salehman AI/StockSage/StockSageHistoryCache.swift` (new, pure + thin I/O — mirrors `StockSageQuoteCache`)
```
nonisolated struct StockSageHistoryCache: Codable, Sendable, Equatable {
    static let currentSchemaVersion = 1
    nonisolated struct Entry: Codable, Sendable, Equatable {   // Codable mirror of StockSagePriceHistory
        let symbol: String
        let dates: [Date]
        let opens, highs, lows, closes, volumes: [Double]
    }
    var schemaVersion: Int      // decode of an older/newer file → guarded → nil (isNewListing precedent)
    var entries: [Entry]
    var savedAt: Date

    // build from a completed fetch: trim to last `maxBars` (252) per symbol, drop symbols
    // not in `universe` (uppercased) so a rotating/shrinking universe can't leak storage.
    static func from(histories: [String: StockSagePriceHistory], universe: Set<String>,
                     savedAt: Date, maxBars: Int = 252) -> StockSageHistoryCache

    func priceHistories() -> [String: StockSagePriceHistory]   // reconstruct for consumers/sim

    // honesty: a symbol whose newest bar is > maxAgeTradingDays old is STALE (usable for a
    // backtest, NOT for a "fresh idea"). Pure calendar-agnostic bar-count/date check.
    func isStale(symbol: String, asOf: Date, maxAgeTradingDays: Int = 5) -> Bool

    static func diskURL() -> URL?   // Application Support / "salehman_history_cache.json"
    static func load() -> StockSageHistoryCache?   // try?-guarded; schemaVersion != current ⇒ nil
    func save()                     // JSONEncoder + write(.atomic); try?-guarded, best-effort
}
```
Invariants (frozen nil-contracts / honesty floor): parallel arrays stay equal-length; a missing/short/too-stale/corrupt/schema-mismatched history stays **nil** — never a guessed or zero-filled series; cached data is labeled "as of `savedAt`, not live" wherever surfaced.

### Write path — piggyback, ZERO new network (`StockSageStore.swift`, after the fetch at ~:318)
After the existing `let histories = await StockSageQuoteService.fetchHistories(...)` (the full-universe 1y fetch), fire a **detached, best-effort** save so it never blocks `buildIdeas` (the 19 MB encode is off the refresh path):
```
let uni = Set(universe.map { $0.symbol.uppercased() })
Task.detached { StockSageHistoryCache.from(histories: histories, universe: uni, savedAt: Date()).save() }
```
No new endpoint pressure — it persists bytes already downloaded and currently discarded. The `fetchHistories` throttle behavior is unchanged.

### Consumption (v1: validation only)
`StockSageHistoryCache.load()?.priceHistories()` → build a `StockSageNetCostSim.Panel` (returns = Δcloses per symbol; industry index per symbol) → `simulate(...)`. This is the offline net-cost edge-validation path (research/test-facing), **not** a shipped UI button in v1.

## Test plan (Swift Testing; every literal hand-derived per `testing-discipline`)
1. **Codec round-trip** — encode→decode preserves entries + parallel-array equal-length equality (mirror `StockSageQuoteCacheTests`). Hard `#expect` on a reconstructed field, not just non-nil.
2. **Trim** — a 400-bar history → `from(maxBars:252)` keeps exactly the last 252 bars (newest preserved, oldest dropped); assert `closes.first`/`.last` values (hand-derived from a deterministic series).
3. **Universe eviction** — a symbol not in `universe` is dropped; one in it survives; hard count.
4. **Schema-version fallback** — a cache serialized with `schemaVersion` ≠ current → `load()`/decode path returns nil (no partial/guessed decode) — the `isNewListing` precedent.
5. **Staleness** — `isStale` true when newest bar is `T`+1 trading days old, false at the boundary (F05 straddle: pin the `> maxAgeTradingDays` guard at both sides).
6. **Offline-sim enablement (the O6 unblock, the point of the feature)** — build a cache from ≥ (lookback+hold+few) bars of a deterministic real-shaped panel, `load`→`priceHistories`→Panel→`simulate` returns a **non-nil** verdict (≥ min rebalances). Hard assert non-nil (WHIPPYX: never a soft guard).

## Out of scope (v1) — explicitly not touched
- No offline **board** rendering (owner-gated product/honesty call; visual-QA-gated).
- No change to `StockSageQuoteService` / `fetchHistories` / the network/throttle path.
- No engine-math / EV / ranking / calibration change — held gates (F01/F02, F03, RANKING #10, cost-table) untouched.
- No UI-visible change ⇒ no visual-QA gate blocks the ship.

## Why safe to land with owner away
Pure new file + one detached best-effort save + hand-derived tests. No UI (no visual QA), no engine gate, no network change. Reversible (delete the file + the one save call). Worst case a cache file that fails to decode → `load()` returns nil → the app behaves exactly as today (one clean re-fetch).
