# Design — Offline-capable ideas board from the history cache (v2 of `StockSageHistoryCache`)

**Date:** 2026-07-03 · **Author:** Claude #4 (Opus 4.8), autonomous window · **Status:** DESIGN ONLY — implementation is OWNER-GATED (product + honesty call) and VISUAL-QA-GATED (UI-visible). Do not implement without the owner.
**Basis:** extends the shipped `StockSageHistoryCache` (`2026-07-03-history-cache-design.md`, commit fce9414). That v1 persists full-OHLCV histories and consumes them for the sim ONLY. This spec designs the deferred **decision #5 / Option B**: rendering the ideas board from cached candles on launch, honestly labeled, before the first network round-trip.

## Why (value)
Today the board shows real ideas only AFTER `fetchHistories` returns; offline / on a throttled feed it shows the cached-QUOTE board (last price, no fresh signals). Because v1 now persists full histories, the board *could* compute real advisor/EV/ranking output from cached candles at launch — a faster, offline-resilient first paint — **as long as it never masquerades as live.** This matters directly while the Yahoo v8 endpoint is throttle-sensitive (the same condition that motivated v1).

## Why this is GATED (do not ship autonomously)
1. **Honesty floor — the hard part.** A board built from cached candles is a *stale-signal* surface. Every number (EV, win-band, velocity, R:R, gate verdict) would be derived from candles as-of `savedAt`, not now. Mislabeling any of them as current is the exact failure the whole app exists to avoid. This needs the owner's explicit sign-off on the labeling contract, not an agent's judgment.
2. **Visual-QA gate.** It adds a launch-state banner + per-idea staleness treatment to `MarketsView` — UI-visible, layout-touching. The `visual-qa` skill makes this before-merge-blocking, and no native-screenshot MCP is available in the autonomous window.
3. **Product call.** "Show stale ideas at launch" vs "show nothing until live" is a UX decision (decision #5 in the O8 proposal), the owner's to make.

## Proposed design (for owner review)
### Load path (mirrors the quote-cache seed)
On `StockSageStore` init, alongside `loadCachedQuotes()`, add `loadCachedHistories()`:
`StockSageHistoryCache.load()?.priceHistories()` → run the SAME pure `buildIdeas(defs:histories:…)` used by the live refresh → seed `ideas` with a `provenance: .cached(savedAt:)` marker. A live `refreshIdeas` overwrites it (last-good wins), identical lifecycle to the quote cache.

### Honesty contract (NON-NEGOTIABLE, owner-ratified before build)
- **Board-level banner:** amber, always visible while the board is cache-seeded — e.g. *"Ideas computed from cached candles as of {savedAt} — NOT live. Tap Find ideas for current."* (reuse the existing cached-quote banner treatment; extend its copy, don't invent a second style).
- **Per-idea staleness:** any idea whose newest cached bar `isStale(symbol:asOf:.now)` (the shipped v1 gate, default 7 days ≈ 5 trading days) is either (a) suppressed from the cache-seeded board, or (b) shown with an explicit ⚠ "stale — {n}d old" tag. **Recommend (a) suppress** — a stale-signal idea presented as a current opportunity is the most dangerous mislabel; a backtest may use it, a "fresh idea" must not (v1's `isStale` doc says exactly this).
- **No sizing/EV number is ever unlabeled.** The `(gross)` / `win% assumed` / `estimate, not a forecast` labels already present carry over unchanged; the banner adds the *as-of* qualifier on top.
- **nil stays nil:** a symbol with no/short cached history contributes no idea — never a guessed one (frozen nil-contract).

### What must NOT change (held gates)
- No EV / ranking / calibration / sizing math change — the cache-seeded board runs the SAME `buildIdeas`, byte-identical logic, only the *input source* (cached vs live histories) and the *provenance label* differ.
- Calibration stays as-shipped (F01/F02 untouched); netting stays gross-labeled (F03).

## Test plan (when built)
1. Cache-seed determinism: `buildIdeas` on `load()?.priceHistories()` == `buildIdeas` on the same histories fetched live (same output, provenance aside) — proves no logic divergence.
2. Staleness suppression (HARD assert): a symbol whose newest bar is `isStale` produces NO cache-seeded idea (or the ⚠ tag), per the ratified choice.
3. Banner presence: cache-seeded board state → banner shown; post-live-refresh → banner cleared (assert the state, not the pixels — pixels are the visual-QA pass).
4. Overwrite: a live refresh replaces the cache-seeded ideas (last-good wins).

## Recommendation
Build only after the owner ratifies (a) the suppress-vs-tag choice for stale ideas and (b) the banner copy, and only with a visual-QA pass at default + 440pt. Until then, v1 (sim-only) stands and nothing user-visible changes. This spec is the review artifact.

---
### Topic-2 note (universe 210→1,024) — no new design needed
The universe-expansion design is already complete and committed (`plans/PLAN_2026-07-03_universe_1024.md`). Its only blocker is external: Yahoo v8 verification of the 1,024-name manifest (HTTP-429 throttle). No design work remains — execution resumes when the throttle clears (O4 poller owns the cadence) or via the EODHD plugin as an independent verification source. The shipped `StockSageHistoryCache` does not change this (it caches whatever universe is fetched; verifying 814 *new* symbols still needs live fetches). So "topic 2" = designed-and-blocked, not designed-anew.
