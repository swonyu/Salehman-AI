# Data-integrity / only-real-data audit (wqelv0xwp, 2026-06-22)

12 CONFIRMED findings (22 agents, verify layer ran). #2 (.L pence 100x across all value sites) DONE. The rest are the highest-priority backlog — SACRED only-real-data rule. RE-VERIFY each vs source.

### ⬜ #1 [high] — Headline portfolio Value/P&L sums across currencies at 1:1 with no FX conversion
**file:** Salehman AI/Views/MarketsView.swift:515-521, 565-583
**fix:** In portfolioTotals (519) convert each holding to a single base (USD) before summing. Reuse the fxRates dict already built at 810-817 (direct CCYUSD=X else 1/USDCCY=X); multiply each position's majorUnitValue by its rate, USD positions x1. Drop/flag positions whose currency has no tracked rate rather than counting 1:1. Label the figure 'Value (USD)'. Minimum acceptable: restrict the headline total to USD-quoted holdings and label any excluded foreign holdings.

### ✅ DONE #2 [high] — London .L pence (divide by 100) not applied to headline Value/P&L or any holding-value site except the currency-exposure widget
**file:** Salehman AI/Views/MarketsView.swift:515-521, 636, 722-723, 782, 3034-3035
**fix:** Add one view helper holdingValue(_ p) that applies StockSageCurrency.majorUnitValue(symbol:rawValue:) once, and route EVERY raw (currentPrice(p.symbol) ?? p.costBasis) * p.shares site through it: portfolioTotals (519), positionRow (636), rebalHoldings (722-723), allocation holdings (782), whatIfHoldings (3034-3035). A 400p (£4) SHEL.L/AZN.L/BP.L share is currently valued at 400 (~100x). majorUnitValue (StockSageCurrency.swift:59-61) already exists; only line 807 uses it today.

### ⬜ #3 [high] — Stale disk-cache prices render under the green 'Live worldwide quotes ... delayed ~15 min' banner
**file:** Salehman AI/Views/MarketsView.swift:156-176 (feedBanner/liveBanner); StockSageStore.swift:83-91 (loadCachedQuotes)
**fix:** feedBanner branches binary on store.isSampleData only (line 157), but loadCachedQuotes sets isSampleData=false + loadedFromCache=true with no age gate, so a possibly-days-old cache shows the green Live banner while headerSubtitle (317-319) correctly says 'Last-good (cached)'. Add a third branch: if store.isSampleData { sampleBanner } else if store.loadedFromCache { cachedBanner } else { liveBanner }, where cachedBanner surfaces store.cacheSavedAt (reuse the 317-319 string). Optionally age-gate loadCachedQuotes so a very old snapshot isn't silently trusted as Live.

### ⬜ #4 [high] — Per-holding position-row value & unrealized P&L computed on unlabeled SAMPLE prices
**file:** Salehman AI/Views/MarketsView.swift:634-657 (currentPrice 511-513; seedSampleData StockSageStore.swift:674-683)
**fix:** While store.isSampleData, make currentPrice return nil so positionRow falls into its existing honest '— no price' path (648) and hides the colored P&L (652) — or stamp the value/P&L with a SAMPLE marker (reuse the StockSageTodayPlan.swift:33 warning). Seeded AAPL=227.1/NVDA=126.5/2222.SR/1120.SR/7010.SR currently present as confident live-looking marks for a held seeded symbol with no per-row label. This is the shared root fix for the SAMPLE-leak findings below.

### ⬜ #5 [medium] — Portfolio summary Value/P&L computed on unlabeled SAMPLE prices
**file:** Salehman AI/Views/MarketsView.swift:515-522, 563-597
**fix:** Covered by the rank-4 root fix: gating currentPrice to nil under store.isSampleData makes portfolioTotals fall back to cost basis honestly. If kept, stamp the summary card with the SAMPLE warning while isSampleData. The only existing indicator is the generic page-top sampleBanner; the card itself carries no SAMPLE label.

### ⬜ #6 [high] — What-if portfolio-impact concentration % uses a SAMPLE-priced book, and the detail sheet shows NO banner at all
**file:** Salehman AI/Views/MarketsView.swift:3034-3068 (ideaDetailSheet, presented via .sheet at 150)
**fix:** ideaDetailSheet is a separate modal that never renders feedBanner/sampleBanner (those live only once in body at 103), so inside the sheet there is zero sample/stale indicator. Thread store.isSampleData into the sheet and suppress or SAMPLE-label the what-if concentration note (mirror isSample: store.isSampleData already passed to StockSageTodayPlan.build at 2300), or apply the rank-4 currentPrice nil-out so the book falls back to cost basis. The >60% CONCENTRATED warning can fire/false-negative on demo prices with no caveat.

### ⬜ #7 [medium] — Journal open-trade unrealized P&L / R-multiple marked against unlabeled SAMPLE price
**file:** Salehman AI/Views/MarketsView.swift:1385-1402
**fix:** journalOpenRow's mark = currentPrice(trade.symbol) (1386) is non-nil for seeded symbols in sample mode, so the honest 'no live px' branch (1401) never fires and a concrete dollar P&L (1397) and R (1399) render off a demo quote. Covered by the rank-4 root fix (currentPrice nil under isSampleData) so the row shows 'no live px'; otherwise label the figure SAMPLE.

### ⬜ #8 [medium] — Watchlist prices and %-change render with no staleness cue when the board is cache-seeded
**file:** Salehman AI/Views/MarketsView.swift:1806-1836 (signalCard), 1721
**fix:** Primarily resolved by rank-3 (cache state banner-flagged). As defense in depth, when store.loadedFromCache is true, add a one-line 'showing last-good prices — tap refresh for live' header above the rows so cached prices (and the Strong Buy/Sell signal chips computed off them) aren't presented with live authority.

### ⬜ #9 [medium] — Portfolio Value/P&L show stale/cached marks with no per-section freshness/asOf indicator
**file:** Salehman AI/Views/MarketsView.swift:563-597 (portfolioSummary), 634-658 (positionRow), 511-513
**fix:** The portfolio section has no asOf line of its own; the only freshness surface is the scroll-header banner. Add a small 'Marked at <store.lastUpdated>' / 'Last-good (cached) as of <store.cacheSavedAt>' line to portfolioSummary and a warning when store.feedError != nil (a failed background refresh, StockSageStore.swift:628-639, leaves stale numbers indefinitely). Secondary to rank-3.

### ⬜ #10 [low] — Allocation $ baseValue and currency-exposure values use SAMPLE prices, unlabeled
**file:** Salehman AI/Views/MarketsView.swift:780-841
**fix:** Covered by the rank-4 root fix (currentPrice nil under isSampleData degrades the panel to cost-basis values honestly). Independently lower-impact than the headline total since baseValue sits inside a percentage split; the genuinely misleading number is the top-line value already addressed at ranks 1/4/5.

### ⬜ #11 [low] — Risk-parity rebalance '$ trades' computed on a SAMPLE-priced book, unlabeled
**file:** Salehman AI/Views/MarketsView.swift:722-742
**fix:** Gate the concrete $-trade block on !store.isSampleData (or label SAMPLE), or rely on the rank-4 currentPrice nil-out so rebalHoldings uses cost basis. Narrow multi-condition repro (real-vol parity present while store.symbols still sample-priced) and the figure is already heavily caveated ('ignores costs/taxes'), hence low.

### ⬜ #12 [medium] — Per-row gp/hour flip estimate in the RuneScape watchlist has no visible caveat
**file:** Salehman AI/Views/RuneScapeMarketView.swift:299 (figure), 340-343 (a11y label)
**fix:** gp/hour is a fill-assuming ceiling (StockSageGEFlip multiplies by the FULL buy limit; glossary calls it 'A CEILING ... VOLUME-GATED'), caveated in 3 nearby places but not on the row. Add .help(StockSageGlossary.explain(.gpPerHour)) to the Text at line 299 (matching line 228) and append a hedge to the accessibility label (340-343), e.g. '... about X per hour, an estimate that assumes you fill the buy limit'. Not covered by existing honesty/glossary tests.
