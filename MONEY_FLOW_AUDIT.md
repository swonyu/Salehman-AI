# Money-flow integration + completeness audit (wdzfepgrt, 2026-06-22)

13 CONFIRMED items (bugs + gaps). #1 (short prefill drops stop/target) DONE. RE-VERIFY each vs source. STRONG money-flow bugs: #2 indices/FX as buyable ideas, #3 shorts top fast-lane, #4 regime dropped in velocity, #5 cost-gate dropped in velocity, #6 RS on FX/indices, #8 cache drops user tickers. Gaps: #9 live per-position 'act now', #10 walkForwardDecay unwired, #11 PSR not displayed.

### ✅ DONE #1 [high/bug] — Prefill-from-idea silently discards the advisor's computed stop & target for SHORT (Sell/Reduce) ideas
**file:** /Users/saleh/Desktop/Salehman AI/Salehman AI/Views/MarketsView.swift:1474-1480
**fix:** The advisor DOES fill stop/target for sell/reduce (StockSageAdvisor.swift:279-282: short stop = price+dist, target = price-2*(s-price)). Prefill from the idea regardless of side: `draftStop = idea.advice.stopPrice.map { String(format: "%.2f", $0) } ?? ""` and same for draftTarget; delete the false comment at lines 1477-1478. The existing .map/?? nil-fallback already covers the genuine degenerate-ATR (nil) case.

### ⬜ #2 [high/bug] — Indices (and FX pairs) advised as long-only equities — buy/stop/target/weight emitted for un-buyable index LEVELS like ^VIX/^GSPC
**file:** /Users/saleh/Desktop/Salehman AI/Salehman AI/StockSage/StockSageStore.swift:223-231 (buildIdeas)
**fix:** Gate buildIdeas by asset class using the existing StockSageAllocation.assetClass(_:): `guard StockSageAllocation.assetClass(sym.symbol) != "Index" else { continue }` so index levels never surface as buyable ideas. For Forex/Crypto, route through a path that suppresses the equity ATR stop/target/weight fields. Also exclude indices from the downstream EV/velocity/allocator math since those helpers all read store.ideas.

### ⬜ #3 [high/bug] — SELL/REDUCE ideas sized as buy-style opportunities in the entire velocity/fast-lane stage
**file:** /Users/saleh/Desktop/Salehman AI/Salehman AI/StockSage/StockSageExpectedValue.swift:216-223 (fastLane), 158-163 (velocityRankKey)
**fix:** The velocity lane gates only on `e.evR > 0`; a short gets a valid 2:1 stop/target so its EV is positive, letting it top the Fast Lane / 'Fastest compounding' card while bestOpportunity (202) and CapitalAllocator require buy/strongBuy. Add the buy-family gate to fastLane (218) and velocityRankKey (158): `guard idea.advice.action == .buy || idea.advice.action == .strongBuy else { return nil }` (reuse the existing side(idea)==.buyFamily helper).

### ⬜ #4 [medium/bug] — Market regime dropped between EV stage and velocity stage — a buy crowned 'fastest' in a bear/crisis tape the EV gate forbids
**file:** /Users/saleh/Desktop/Salehman AI/Salehman AI/StockSage/StockSageExpectedValue.swift:158-174, 216-223, 271-291 (summary)
**fix:** velocityRankKey/rankByVelocity/fastLane/expectedWeeklyR take no regime: param and never call bannedFromTopRank; summary() (276) regime-gates `best` but forwards regime nowhere into fastLane (277) or expectedWeeklyR (287). Plumb `regime: MarketRegime? = nil` through those four functions, apply the same bannedFromTopRank demotion used in regimeAdjustedEVRankKey (153-157), and forward regime from summary() (and MarketsView call sites) into fastLane/expectedWeeklyR.

### ⬜ #5 [medium/bug] — After-cost-frictions demotion dropped in the velocity ranking key (cost gate enforced in EV rank, lost in velocity rank)
**file:** /Users/saleh/Desktop/Salehman AI/Salehman AI/StockSage/StockSageExpectedValue.swift:158-163 (velocityRankKey) vs 125-131 (evRankKey)
**fix:** evRankKey demotes net-negative-after-cost setups (`if !clearsCostAfterFrictions(idea) { key -= 500_000 }`, line 129); velocityRankKey applies only the conviction floor (162) and fastLane gates on GROSS evR>0, so a thin high-cost crypto flip can top the velocity board. Mirror the cost screen in velocityRankKey: after computing `v`, `if !clearsCostAfterFrictions(idea) { return v - 500_000 }` (clearsCostAfterFrictions is already file-private/reusable).

### ⬜ #6 [medium/bug] — Relative-strength-vs-S&P term applied to FX pairs and indices, where it is meaningless and the rationale label is false
**file:** /Users/saleh/Desktop/Salehman AI/Salehman AI/Salehman AI/StockSage/StockSageStore.swift:226 → StockSageAdvisor.swift:178-182
**fix:** buildIdeas passes the ^GSPC benchmark to advise() for every non-^GSPC symbol; advise adds ±0.08 and a 'Leading/Lagging the S&P' rationale for FX/index/crypto, which is economically meaningless (and wrong-signed for ^VIX). Only pass a benchmark for equities: `let bench = StockSageAllocation.assetClass(sym.symbol) == "Equity" ? benchmark : nil` (still nil for ^GSPC). advise already no-ops on a nil benchmark.

### ⬜ #7 [medium/bug] — retryFailedIdeas drops the benchmark, so retried symbols are scored on a different (RS-less) regime than the main scan they're re-ranked against
**file:** /Users/saleh/Desktop/Salehman AI/Salehman AI/StockSage/StockSageStore.swift:206 vs 176
**fix:** refreshIdeas passes the ^GSPC benchmark into buildIdeas (176); retryFailedIdeas calls buildIdeas without it (206, defaults nil), so the ±0.08 RS term flows into conviction/rankScore for main-scan ideas but not retried ones, then both are co-sorted. Cache the last refresh's ^GSPC 1y history on the store and pass it into the retry's buildIdeas so retried ideas are scored identically to the board they're ranked against.

### ⬜ #8 [medium/bug] — refresh() persists only `live` to the disk cache, silently dropping preserved user-added tickers from the last-good board
**file:** /Users/saleh/Desktop/Salehman AI/Salehman AI/StockSage/StockSageStore.swift:651
**fix:** replaceAll commits `live + preservedUserRows` (647) but the cache is built from `live` only (651), so a user-added ticker the feed missed this cycle is on screen yet absent from the saved cache and vanishes from the offline/last-good board on next launch. Persist exactly what was committed: `let committed = live + preservedUserRows; replaceAll(committed, isSample: false); ...; StockSageQuoteCache.from(symbols: committed, savedAt: lastUpdated ?? Date()).save()`.

### ⬜ #9 [high/gap] — No live per-position management layer — the journal tracks open trades but never says what to DO with them right now
**file:** /Users/saleh/Desktop/Salehman AI/Salehman AI/StockSage/StockSageJournal.swift:469 (insertion) / MarketsView.swift:1489 journalOpenRow
**fix:** Held positions get post-mortem analytics but no live 'act now' verdict; the only stop-aware logic (StockSageAlertDecision via StockSageMonitor) runs over the watchlist, never journal.open, so a real position crossing its real stop fires nothing. Smallest first step (no schema change): add a pure static `openActions(_ open:[TradeRecord], mark:(String)->Double?) -> [OpenAction]` in enum StockSageJournal that emits a ranked stopHit/targetHit/nearStop/trailUp/hold verdict per open trade (reusing rMultiple/riskPerShare), fed by currentPrice(_:); render the top action on journalOpenRow (1489) and/or a banner above the Open section. Partial-exit logging + a persisted currentStop are larger follow-ups.

### ⬜ #10 [high/gap] — WalkForwardDecay (in-sample vs out-of-sample edge-decay overfit red-flag) is built + tested but never called outside tests
**file:** /Users/saleh/Desktop/Salehman AI/Salehman AI/StockSage/StockSageBacktester.swift:74-101
**fix:** decayRatio (oosAvgR/isAvgR) + isRedFlag (decayRatio<0.5) — the single most decision-relevant overfit guard — is never invoked by the store (StockSageStore.swift:578/365 call only run()) or any View. run() builds per-trade `trades` internally but returns summarize(trades), discarding detail. Cheapest path: have run() also compute WalkForwardDecay from its internal trades and expose it (new field on BacktestResult or sibling published value), then render decayRatio + the red-flag warning in the backtest panel next to the 'too small a sample' warning at MarketsView.swift:2738.

### ⬜ #11 [medium/gap] — BacktestResult.probabilisticSharpe (PSR confidence haircut) is computed, populated, and tested — but never displayed
**file:** /Users/saleh/Desktop/Salehman AI/Salehman AI/Views/MarketsView.swift:2735 (display site); StockSageBacktester.swift:348-358
**fix:** The backtest panel shows the raw, upward-biased Sharpe but not the PSR haircut built to temper it (zero hits for PSR in Views). Value is already live on store.backtest — one guarded line after 2735: `if let psr = bt.probabilisticSharpe { ideaMetric("PSR", String(format: "%.0f%%", psr * 100), color: psr >= 0.95 ? DS.Palette.successSoft : (psr >= 0.5 ? .white : DS.Palette.danger)) }` plus a .help() explaining P(true Sharpe > 0). No store/plumbing change.

### ⬜ #12 [medium/gap] — TrailingStop.recompute (ratcheting since-entry Chandelier) is built + tested but the app surfaces only the non-ratcheting .suggest
**file:** /Users/saleh/Desktop/Salehman AI/Salehman AI/StockSage/StockSageTrailingStop.swift:44-64
**fix:** .suggest (one-shot, no ratchet) is the only wired entry point (StockSageStore.swift:544 → MarketsView.swift:3130); .recompute (anchors highest-high since entry, ratchets up-only) has no production callers. Map a journaled open trade's openedAt to a candle index for entryIndex and call StockSageTrailingStop.recompute in a store method paralleling refreshTrailingStop; display the ratcheted level on the open-position/journal row (the math is done; only the openedAt→index mapping is new).

### ⬜ #13 [medium/gap] — Non-default ExitMode cases (chandelierTrail / scaleOutLadder / timeStop) are simulated and tested but the app only ever runs .allAtTarget
**file:** /Users/saleh/Desktop/Salehman AI/Salehman AI/StockSage/StockSageBacktester.swift:108-113 (enum), run() default at 127
**fix:** Both app-side backtest calls (StockSageStore.swift:365, 578) pass the default exitMode, so the owner never sees how a trailing or scale-out exit would score head-to-head. Cheapest surfacing: in the runner, additionally run() the same history under .chandelierTrail and/or .scaleOutLadder and show a Total R / Sharpe comparison as extra rows in the backtest panel near MarketsView.swift:2737. No new financial math — the modes already simulate; this is UI exposure of an existing seam.
