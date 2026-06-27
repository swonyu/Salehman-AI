# Markets tab — deep-research backlog (workflow wiuoch73w, 2026-06-22)

A 9-agent markets-deep-research Workflow mapped 8 Markets surfaces and synthesized a value-ranked, deduplicated backlog. Ranks 1,2,4,6,7,8,9,24,28 shipped in 809dece. The rest are queued for the autonomous loop, highest value/effort first.

## Universe scaling recommendation (verified: the two-tier core/catalog design already exists)
The two-tier design the prompt is asking for ALREADY EXISTS in the uncommitted StockSageQuoteService.swift and just needs to be finished and surfaced — don't rebuild it. Verified structure (StockSageUniverse, lines 219-339):

1. `groups` = the ANALYZED CORE (~250 liquid, recognizable symbols across 35 region/asset groups). This is the only set that gets bulk live-quoted AND 1-year-history-fetched for the board, ideas ranking, heatmap, and allocation. Keep it bounded (a few hundred) so a manual refresh and refreshIdeas stay sane on bandwidth/rate-limits.

2. `catalogExtra` = the DISCOVERY LONG-TAIL (the '+' groups): real, liquid Yahoo tickers that are searchable and one-tap-addable but NEVER bulk-fetched — adding one fetches just that single quote.

3. `catalog` = groups + catalogExtra, deduped (core label wins), with a pure, bounded `search(query, limit)` already wired into the add-ticker autocomplete (MarketsView:1630-1639).

What's missing to effectively 'list all stocks' without overloading the per-symbol history feed:

- BROWSE SURFACE (rank 10): expose `catalog` as a paginated/sectioned, filterable 'Browse markets' sheet (by asset class/region), with last-quote preview and one-tap add. The add path lazily fetches a single quote — so the directory can grow to thousands of tickers with O(1) feed cost per add, never O(n) history fetches.

- LAZY ANALYSIS: keep ideas/backtests/indicators operating ONLY on the analyzed core plus whatever the user has explicitly added to their watchlist. A catalog symbol gets its expensive 1-year history fetched only when the user opens its detail / adds it / requests a backtest — never in the bulk sweep. This is the key invariant that lets the catalog scale independently of the history feed.

- CACHING (rank 11) is the enabler: a disk cache for quotes + recent histories + a TTL idea-advice cache (keyed by symbol+price-hash) means re-opening the app, scrolling the catalog, and re-analyzing don't re-hammer Yahoo's keyless endpoint, which has no SLA and 429s under load (rank 5).

- To approach 'all stocks' literally, replace the hand-curated catalogExtra with a bundled static symbol directory (e.g. a JSON of exchange-listed tickers shipped in the app) loaded lazily for search/browse only. Same invariant: directory entries cost nothing until added; bulk feed work stays pinned to the ~250-symbol core + the user's watchlist.

- HONESTY: fix the marketCount label (rank 24) — it counts groups (now 35), not exchanges, and once the catalog grows the banner must not imply every catalog symbol is live-analyzed. Make the board explicit that ranking/ideas cover the analyzed core + your watchlist, and the rest of the catalog is searchable-but-not-scanned until added.

## Backlog
### ✅ DONE (809dece) #1 — Guard the alert Monitor against sample data (stops fake 'Strong Buy' on launch)  [high/small, Data/Monitor/bug]
**What:** VERIFIED: runCycle() iterates fetchAllSymbols() with no isSampleData guard. seedSampleData() seeds two strongBuy movers (2222.SR +6.7%, NVDA +7.2%). On first launch, start() calls refresh() (Monitor:49); if that fails (offline, web tools off, or coverage), isSampleData stays true and runCycle fires real UNUserNotifications 'Strong Buy: 2222.SR' on fabricated prices.
**Why:** Directly violates the honesty floor — the app would push a buy alert built on hardcoded demo numbers. Highest value-to-effort: one guard line. Add `guard !StockSageStore.shared.isSampleData else { return [] }` at the top of runCycle().
**Files:** Salehman AI/StockSage/StockSageMonitor.swift:73-89; Salehman AI/StockSage/StockSageStore.swift:604-613

### ✅ DONE (809dece) #2 — Persist position-sizer account & risk%; surface them as one shared assumption  [high/small, Money-velocity/UX/ux]
**What:** sizerAccount ('10000') and sizerRiskPct ('1') are @State, not @AppStorage, so they silently reset on every app restart — and they feed THREE separate $-estimates (Size-it-now ~2060, Est./week ~2122, fast-lane weekly $ ~2228). cryptoHoldDays/equityHoldDays already use @AppStorage, so the pattern exists.
**Why:** A trader who sets $50k sees it revert to $10k after closing the app, making every $/week figure quietly wrong. Fix: migrate both to @AppStorage and add a single header line 'Using: $X account, Y% risk/trade' above the cards so the user sees one edit cascades to three places. Honesty + tiny diff.
**Files:** Salehman AI/Views/MarketsView.swift:59-60; Salehman AI/Views/MarketsView.swift:2060-2125

### ✅ DONE (next) #3 — Partial-success Ideas: render what loaded + name what's missing  [high/medium, Data/Ideas/honesty]
**What:** refreshIdeas() abandons the whole board if histories.isEmpty and the compactMap silently drops symbols that failed mid-fetch. EV/velocity ranking (MarketsView ~1833) is then computed on the partial set, so a missing NVDA biases the entire 'highest EV' ordering with no user signal.
**Why:** Honesty + money-edge: ranking on an incomplete universe can mislead which bet is 'best'. Compute `failed = universe.count - histories.count`, succeed with partial results, show 'Analyzed N of M (AAPL, NVDA missing)' + a 'Retry failed' button that re-fetches only the misses. Keeps the good 90% on screen honestly.
**Files:** Salehman AI/StockSage/StockSageStore.swift:135-174; Salehman AI/Views/MarketsView.swift:1832-1887

### ✅ DONE (809dece) #4 — Stale-ideas warning banner (>4h since last analysis)  [high/small, Honesty/Ideas/honesty]
**What:** ideasHeader shows 'Analyzed HH:mm' but never warns when the scan is hours/days old. The Regime card already flags staleness ('Gauged … — stale, re-gauge', ~207-211) — ideas has no equivalent.
**Why:** A trader can act on a week-old scan thinking it's fresh. Reuse the regimeIsStale pattern: orange banner when now - ideasUpdated > 4h, with a threshold constant. Small, high-value honesty win that mirrors existing code.
**Files:** Salehman AI/Views/MarketsView.swift:1839-1887; Salehman AI/Views/MarketsView.swift:207-211

### ✅ DONE (core; UI-label deferred) #5 — Distinguish 429/503 rate-limit from feed failure; back off + label cached prices  [high/medium, Data/Feed resilience/perf]
**What:** fetchOne() treats any non-200 as nil — no distinction between 404 (dead symbol) and 429/503 (rate-limited by Yahoo's keyless endpoint). Back-to-back refresh + refreshIdeas + Monitor can trip a 429; the board silently shows partial data with a generic 'couldn't reach feed'.
**Why:** As the universe grows this becomes the dominant failure mode. Return a Result/FetchError enum, retry once on 429 after ~2s, and surface 'Temporarily rate-limited (showing cached/partial)' instead of a generic error so the trader knows it's transient, not broken.
**Files:** Salehman AI/StockSage/StockSageQuoteService.swift:68-108; Salehman AI/StockSage/StockSageStore.swift:561-572

### ✅ DONE (809dece) #6 — Defensive bounds in SignalEngine (currentPrice<=0, gap caveat)  [high/small, Signals/bug]
**What:** changePercent guards previousPrice==0 but not currentPrice<=0 or previousPrice<0, so corrupt data produces a misleading confidence. Separately, an overnight earnings gap (prev close from yesterday) reads as 'very strong momentum' though the move is already executed at the open.
**Why:** Keeps the function TOTAL and honest about timing. Add `guard currentPrice > 0 else { return .hold('Invalid price') }`, and when previousPrice's timestamp is >16h old append '[overnight gap — may already be priced in]'. Prevents a trader chasing an already-locked move.
**Files:** Salehman AI/StockSage/StockSageSignalEngine.swift:34-58

### ✅ DONE (809dece) #7 — Fix WCAG contrast on Buy/Hold recommendation badges + saturated heatmap text  [high/small, Visual/a11y/a11y]
**What:** recTextColor() returns Color(white:0.12) dark ink for .buy/.hold/.strongBuy on bright successSoft/warningSoft pastels (~1.9:1, QA-flagged). Logic duplicated at 2881-2885. Correlation heatmap values are white on saturated red/green (~1.8:1).
**Why:** Badges and the heatmap are the fastest visual scan in the tab; low contrast slows decisions and fails AA. Darken ink to Color(white:0.05-0.08) for pastels, apply the same dark-ink logic to heatmap cells when abs(corr)>0.7. Affects every signal row.
**Files:** Salehman AI/Views/MarketsView.swift:1719-1736; Salehman AI/Views/MarketsView.swift:876-916; Salehman AI/Views/MarketsView.swift:2881-2885

### ✅ DONE (809dece) #8 — Persist watchlist & ideas sort preference  [high/small, UX/ux]
**What:** watchlist `sort` and `ideaSort` are @State, not @AppStorage — both revert to Default on tab re-entry. 'Strongest signal' is a core daily workflow that has to be re-selected every time.
**Why:** Pure friction tax on the owner's main workflow. Migrate both to @AppStorage. Trivial diff, repeated-daily value.
**Files:** Salehman AI/Views/MarketsView.swift:12; Salehman AI/Views/MarketsView.swift:15

### ✅ DONE (809dece) #9 — Show diversification affirmation (not just concentration warning) in idea sheet  [high/small, Risk/ux]
**What:** ClusterCheck is computed but only rendered when cc.isConcentrating==true (`if let cc = … cc.isConcentrating`). When an idea genuinely DIVERSIFIES (low correlation to holdings), that positive signal is calculated then thrown away.
**Why:** The owner wants to grow an edge — knowing an idea reduces book risk is as actionable as a concentration warning. Change the guard to render cc.note unconditionally: 'adds diversification' below 0.8, 'concentration in disguise' at/above. One-line condition change, already-computed data.
**Files:** Salehman AI/Views/MarketsView.swift:2577-2583; Salehman AI/StockSage/StockSageClusterCheck.swift:42

### ✅ DONE (31ed234+) #10 — Add a 'Browse all markets' directory backed by the existing catalog  [high/medium, Universe/Discovery/feature]
**What:** VERIFIED: StockSageUniverse already has the two-tier split — `groups` (analyzed core, bulk-fetched) and `catalogExtra` (discovery long-tail, single-fetch on add) merged into `catalog` with a pure `search()`. The add box wires search() as autocomplete (MarketsView ~1630-1639), but `catalog` is never exposed as a browsable, filterable directory and the .all section just mirrors the watchlist.
**Why:** This is the lazy-analysis backbone for 'list all stocks' that already exists in code but has no surface. Add a 'Browse markets' sheet: paginated/sectioned list over catalog, filter by asset class/region, preview last quote, one-tap add (which lazily fetches just that quote). No change to the per-symbol history feed cost — see universeRecommendation.
**Files:** Salehman AI/StockSage/StockSageQuoteService.swift:276-339; Salehman AI/Views/MarketsView.swift:1602-1660

### ✅ DONE #11 — Disk cache for quotes + recent histories (offline/last-good + faster re-open)  [high/medium, Data/Persistence/perf]
**What:** Quotes and histories live only in memory. Cold launch with no/slow network shows sample data; refreshIdeas re-downloads ~250-symbol 1-year history (O(n) bandwidth) every time with no resume. No idea-advice cache keyed by symbol+price-hash.
**Why:** Caching unlocks: offline 'Last updated HH:mm' instead of demo data, resume after a dropped fetch, instant re-open, and graceful partial degradation — and it's the prerequisite for lazy catalog analysis. Persist last-good quotes + top-N histories via JSONEncoder/FileManager; add a 4h TTL idea cache with 'Quick' (cached) vs 'Full' (cache-bust) modes.
**Files:** Salehman AI/StockSage/StockSageStore.swift:135-174; Salehman AI/StockSage/StockSageStore.swift:538-582

### ✅ DONE #12 — Progress + cancel + outer timeout on refreshIdeas()  [high/medium, Data/Ideas/perf]
**What:** refreshIdeas() has a re-entry guard but no Task handle, no progress, and no outer timeout — individual fetches time out at 15s but if the detached advisor compute hangs, isLoadingIdeas stays true forever and the spinner never stops. Briefing generation (MarketsView ~1790) similarly can't be cancelled.
**Why:** A hung 'Loading ideas…' with no cancel is a dead-end the user can't escape without relaunching. Store the Task, expose cancelIdeasRefresh(), publish ideasProgress (current/total) for 'Loading 45/250…', and wrap in a ~120s watchdog that flips the flag with a clear error.
**Files:** Salehman AI/StockSage/StockSageStore.swift:135-174; Salehman AI/Views/MarketsView.swift:1790

### ✅ DONE #13 — Ideas board: sector / Strong-Buy-Sell quick filter  [high/medium, UX/feature]
**What:** The EV-ranked ideas board (250+ symbols once the core grows) has no local filter — to see only Strong Buys or only Tech, the user scrolls the whole list or re-runs 'Find ideas' on a narrowed universe.
**Why:** Filtering is the fastest path from a big board to an actionable shortlist — directly serves 'make money fast'. Add a SegmentPicker below ideaSort: All / Strong Buy only / Strong Sell only / [sector]; filter store.ideas locally before displayedIdeas. No extra network.
**Files:** Salehman AI/Views/MarketsView.swift:1815; Salehman AI/Views/MarketsView.swift:1832-1836

### ✅ DONE #14 — Quick-remove on watchlist rows (hover trash, matching portfolio rows)  [medium/small, UX/ux]
**What:** Watchlist symbol removal is buried in a .contextMenu (~1708). Portfolio positionRow already surfaces a hover-reveal trash icon (~639); the watchlist doesn't, so curating a long list is slow.
**Why:** Cheap consistency win on a daily action. Reuse the positionRow hover-trash pattern on signalCard.
**Files:** Salehman AI/Views/MarketsView.swift:1641-1717; Salehman AI/Views/MarketsView.swift:613-654

### ✅ DONE #15 — Confirm dialog before closing a journal trade (prevent wrong-exit P&L)  [medium/small, Journal/ux]
**What:** Closing an open trade prompts for exit price then immediately calls journal.close() with no confirmation/undo. A fat-fingered 100.5 vs 105.0 writes a wrong R/P&L; correcting it requires a lossy delete.
**Why:** The journal is the system-health source of truth — a wrong close corrupts expectancy/edge stats. Add a confirm sheet showing computed P&L and R-multiple before committing, or a brief undo toast.
**Files:** Salehman AI/Views/MarketsView.swift:1310-1321

### ✅ DONE #16 — Validate numeric inputs (Kelly %, journal prices, GE budget)  [medium/small, Inputs/bug]
**What:** kellyField and journalField are plain TextFields with no validation — '-50' for win% or a negative price silently clamps to 0/garbage. RuneScape budget parses Int(text) ?? 0 so 'abc' becomes 0 and the user just sees 'budget too small'.
**Why:** Garbage-in produces silently-wrong sizing and a confusing dead UI. Add decimalPad + range filtering (0-100 for %, 0+ for price/account/budget) and an inline red 'positive numbers only' state.
**Files:** Salehman AI/Views/MarketsView.swift:1421-1432; Salehman AI/Views/MarketsView.swift:1224-1230; Salehman AI/Views/RuneScapeMarketView.swift:236

### ✅ DONE #17 — Asset-class-aware cost assumptions in NetEdge  [medium/small, Risk/Cost/honesty]
**What:** NetEdge is always called with spreadBps=10, slippageBps=5 (15bps round-trip) for every symbol — reasonable for US equities but wrong for crypto and FX. The math is honest but the input isn't asset-class-aware.
**Why:** Net-edge directly gates whether a trade clears costs; a flat assumption mis-rates crypto/FX edges. Branch on StockSageAllocation.assetClass(symbol) for per-class bps and state the assumption in the NetEdge caveat.
**Files:** Salehman AI/Views/MarketsView.swift:2612; Salehman AI/StockSage/StockSageAllocation.swift

### ✅ DONE #18 — Surface dropped/unassessable symbols in risk engines (risk-parity, cluster)  [medium/small, Risk/feature]
**What:** Risk-parity silently filters holdings with vol<=0 (RiskParity:68) and ClusterCheck returns nil when either side has <2 return points — both with no UI signal, so a concentrated idea can look 'safe' only because data was too sparse to assess.
**Why:** Silent omission in a risk gate is the dangerous kind. Add a dropped:[String] field to risk-parity output ('excluded X — no vol data') and a faint 'Cluster check unavailable (insufficient history)' note when check() is nil.
**Files:** Salehman AI/StockSage/StockSageRiskParity.swift:68; Salehman AI/Views/MarketsView.swift:2577-2583

### ✅ DONE #19 — Symmetric stop/target for short (Sell/Reduce) recommendations  [medium/medium, Advisor/feature]
**What:** Only .buy/.strongBuy populate stopPrice/targetPrice; .sell/.reduce return nil for both ('long-biased framing'). A trader acting on a Sell idea gets no protective stop or target and must eyeball it.
**Why:** Asymmetry leads to over-risky or undersized shorts on exactly the signals the engine generated. Mirror the logic: stop = price + 2*atr, target = price - 2*risk, same risk budget; add a `side` field to TradeAdvice. Needs tests.
**Files:** Salehman AI/StockSage/StockSageAdvisor.swift:137-162

### ✅ DONE #20 — Replicate fast-lane concentration warning onto the money-velocity summary card  [medium/small, Money-velocity/ux]
**What:** The 'top N fastest are all crypto — one bet in disguise' warning only renders inside fastLaneStrip (≥2 setups). The summary card shows the fastest symbol + weekly-R but never checks concentration, so a glance at the summary can read '3 diversified setups' when it's 3 BTC trades.
**Why:** Velocity-chasing hides correlation risk — the owner's fastest-money instinct is exactly where this bites. Run the same isConcentrated check inside moneyVelocityCard and render a one-line yellow alert.
**Files:** Salehman AI/Views/MarketsView.swift:2096-2186; Salehman AI/Views/MarketsView.swift:2235-2238

### ✅ DONE #21 — Accessibility labels on journal trade rows + delete/close buttons + P&L sign  [medium/medium, a11y/Journal/a11y]
**What:** journalOpenRow/journalClosedRow have no accessibilityElement(.combine)/label — VoiceOver reads disjoint fragments. Win/loss is encoded by color only (1294-1296, 1332-1335), and the trash/Close buttons have no labels (a user can't tell a delete from context).
**Why:** Color-only P&L and unlabeled destructive buttons are real a11y failures on the owner's own audit trail. Combine each row into one labeled element ('AAPL Long @150, +1.5R, closed'), prefix signs/words for gain/loss, label the trash/Close buttons with the symbol.
**Files:** Salehman AI/Views/MarketsView.swift:1282-1339

### ✅ DONE #22 — Earnings fetch: add concurrency cap, timeout, and per-symbol cache  [medium/medium, Data/perf]
**What:** refreshEarnings(symbol:) fetches per-symbol on demand with no concurrency cap, timeout, or cache; a user opening 50 symbol details can launch 50 serial fetches, each silently failing on a hang.
**Why:** Earnings proximity is a trade-timing input — a silently-stale fetch means trading into earnings blind. Add ~4-parallel + 8s timeout + a symbol-keyed cache (like multiTimeframe), and show 'Earnings data stale' on timeout.
**Files:** Salehman AI/StockSage/StockSageStore.swift:434-440

### ✅ DONE #23 — FX exposure breakdown: parse the non-USD leg instead of bucketing all pairs as Global  [medium/medium, Allocation/Currency/feature]
**What:** currencyForSymbol() maps every '=X' FX pair to USD/Global, so 70% EURUSD + 30% GBPUSD both show as Global, hiding that the book is 70% EUR-exposed. Allocation panel also assumes FX rates are fresh with only a soft 'Rates are snapshots' note.
**Why:** Currency concentration is hidden risk for a multi-currency book. Extract the non-quote leg (EURUSD=X → EUR) for the breakdown, and stamp the FX rates with a REFRESHED/STALE-as-of-time label so allocation isn't mistaken for hedge sizing.
**Files:** Salehman AI/StockSage/StockSageCurrency.swift:58; Salehman AI/Views/MarketsView.swift:759-828

### ✅ DONE (809dece) #24 — Correct the '28/35 markets' label to 'market groups' and re-clarify banner  [medium/small, Honesty/Copy/honesty]
**What:** VERIFIED: marketCount = groups.count (now 35 after the universe expansion). The banner says 'Live worldwide quotes across N markets' and 'N world markets', but groups bundle multiple venues (World indices, Forex, Crypto, ETFs are not exchanges) so the count overstates distinct exchanges.
**Why:** Small but real honesty gap the owner cares about. Relabel to 'N market groups' (or count distinct exchanges programmatically). Note the stale '~99-symbol analysis' / '28 markets' code comments are now wrong too — make the count dynamic.
**Files:** Salehman AI/Views/MarketsView.swift:150; Salehman AI/Views/MarketsView.swift:301; Salehman AI/StockSage/StockSageQuoteService.swift:307

### ✅ DONE #25 — Watchlist-scoped Monitor + refresh (stop pulling 250+ symbols to watch 5)  [medium/medium, Monitor/Perf/perf]
**What:** Monitor.start() calls full refresh() every 45s and runCycle scans every tracked symbol. A user watching 5 picks still pulls the whole analyzed core each cycle and scans all of it — ~10-50x waste, and it grows with the universe.
**Why:** Bandwidth + rate-limit pressure scale with universe size; the owner mostly watches a few names. Add an optional pinned-watchlist filter to refresh()/runCycle (fallback to full when nil) so alerts on a small set don't pull the world.
**Files:** Salehman AI/StockSage/StockSageMonitor.swift:40-59; Salehman AI/StockSage/StockSageStore.swift:538-548

### ✅ DONE #26 — Backtest input validation + show open-at-end trade count  [medium/small, Backtester/bug]
**What:** run() accepts a history with no checks for low<=high, OHLC>0, or monotonic dates — a corrupt feed yields a plausible-looking but wrong backtest. Also, BacktestTrade.Outcome.openAtEnd exists but the UI shows only aggregate metrics, so a user can't tell 15-of-20 trades are still open (skewing avgR/EV).
**Why:** A wrong backtest is worse than none for a money decision. Add validateHistory() guard returning .empty on bad data, and surface openAtEnd count in the idea detail ('15 closed · 5 open at end').
**Files:** Salehman AI/StockSage/StockSageBacktester.swift:25-73

### ✅ DONE #27 — Cap idea-detail / backtest sheet width; lock sheet scroll on small windows  [medium/small, Visual/Layout/ux]
**What:** ideaDetailSheet uses .frame(minWidth:440,minHeight:480) with NO maxWidth, so on a 2560px display text lines exceed 140 chars; the main column already caps at maxWidth:780. On small macOS windows the sheet's ScrollView can scroll away behind the parent.
**Why:** Readability + a layout trap on the most important decision surface (the full trade plan). Add .frame(maxWidth:680) and make the sheet lock the underlying scroll / set a sane default size.
**Files:** Salehman AI/Views/MarketsView.swift:2513-2837

### ✅ DONE (809dece) #28 — GE-flip: fix stale 1% tax tooltip, label margin as pre-tax, flag missing-volume risk  [medium/small, RuneScape/honesty]
**What:** Tooltip says 'before the 1% GE tax' but the implemented rate is 2% (StockSageGEFlip.defaultRate=0.02 since 2025-05-29). The green margin chip shows GROSS (high-low) margin while the strip's per-item profit nets tax — inconsistent mental model. gp/hour assumes full buy-limit fill with no liquidity gauge.
**Why:** A trading tool that contradicts its own tax rate and shows pre-tax margin as if net erodes trust. Fix the tooltip to 2%, relabel the chip 'margin (pre-tax)', and add a 'volume/liquidity unknown — may not fill' caveat to the optimizer.
**Files:** Salehman AI/Views/RuneScapeMarketView.swift:301-309; Salehman AI/StockSage/StockSageGEFlip.swift:50-79

### ✅ DONE #29 — Stagger launch fetches; opt-in 'refresh ideas on open' to avoid request spike  [medium/small, Perf/perf]
**What:** onAppear fires refresh() un-awaited while the Monitor also calls refresh() on its first cycle; if ideas auto-refresh is ever enabled, hundreds of parallel fetches can launch in the first seconds, risking a 429 and a CPU/memory spike on launch.
**Why:** Compounds the rate-limit risk exactly when the user is watching the app start. Gate Monitor's first refresh behind a short delay (or share the onAppear snapshot) and keep ideas-on-open opt-in + staggered after quotes land.
**Files:** Salehman AI/Views/MarketsView.swift:124-129; Salehman AI/StockSage/StockSageMonitor.swift:45-50

### ✅ DONE (sparkline part) #30 — Money-velocity card header sizing + neutral sparkline color for flat moves  [low/small, Visual/visual]
**What:** moneyVelocityCard header is 11pt bold while peer card titles (regime, journal) are 14pt semibold, so it reads as a sub-section. sparkColor() returns success for last>=first, so a ranging/flat idea shows green arbitrarily (≥ favors green).
**Why:** Hierarchy clarity + honest visual encoding. Bump the header to 13-14pt; return a neutral color when |last-first|/first < ~2% so flat ideas don't look like uptrends.
**Files:** Salehman AI/Views/MarketsView.swift:2106; Salehman AI/Views/MarketsView.swift:2889-2892

### ✅ DONE #31 — Promote/justify hardcoded engine thresholds (er>=0.30, significance>=20, div-score weights, breadth sample)  [low/small, Honesty/Calibration/honesty]
**What:** Several money-affecting magic numbers are inline and unjustified: trending threshold er>=0.30, isSignificant trades>=20, diversificationScore 0.7/0.3 weights + cap 8, and the regime breadth sample skewed to 10 US large-caps. No named constants, boundary tests, or cited rationale.
**Why:** For a money system, every threshold should be auditable. Promote to named constants with a one-line rationale, add boundary tests (er 0.299 vs 0.301), expose a diversificationCaveat, and note the breadth sample is US-tech-biased.
**Files:** Salehman AI/StockSage/StockSageAdvisor.swift:112; Salehman AI/StockSage/StockSageBacktester.swift:59; Salehman AI/StockSage/StockSagePortfolioAnalytics.swift:94; Salehman AI/StockSage/StockSageRegime.swift:48-56

### ✅ DONE #32 — Move the gpPerHour RuneScape term out of MoneyVelocityTerm (orphaned in equities glossary)  [low/small, Glossary/visual]
**What:** MoneyVelocityTerm.gpPerHour is a RuneScape GE flip metric living in the equities/crypto money-velocity glossary; grep shows it's used only by the RuneLite plugin, not MarketsView — semantically orphaned.
**Why:** Cheap clarity. Move it to a RunesVelocityTerm enum (or delete if unused), or add a context comment so the financial glossary stays coherent.
**Files:** Salehman AI/StockSage/StockSageGlossary.swift:21

## Notes
Synthesis of 8 surface maps, deduplicated to 32 ranked items. Verified against live source (not just the maps): (a) the sample-data alert bug is REAL — StockSageMonitor.runCycle (Monitor.swift:73-89) has no isSampleData guard and seedSampleData (Store.swift:604-613) seeds two strongBuy movers, so a failed first-launch refresh fires fake notifications [rank 1]; (b) the catalog/analyzed-core split the prompt asked me to design ALREADY EXISTS in the uncommitted StockSageQuoteService.swift:219-339 with a pure search() wired into the add box (MarketsView:1630-1639) — my universe recommendation finishes and surfaces it rather than reinventing it; (c) marketCount=groups.count is now 35, so '28 markets' copy in some maps is itself stale, and the label conflates groups with exchanges [rank 24].

Dedup notes: the sizerAccount/sizerRiskPct issue appeared as 4 separate findings across 3 maps (stale default, not persisted, cascades to 3 estimates, no parity label) — merged into rank 2. The 'partial Ideas loss' issue appeared 4× (silent truncation, no missing-symbol visibility, biased EV ranking, no retry) — merged into rank 3. WCAG badge/heatmap contrast appeared in 3 maps — merged into rank 7. Journal a11y (no row labels, color-only P&L, unlabeled delete/close) merged into rank 21.

Ranking method: value-to-effort, with the owner's honesty floor and risk-control priority weighting 'value' up for anything that prevents a misleading money/edge number (sample-data alert, partial-ideas ranking bias, stale-ideas banner, asset-class costs). Quick wins (ranks 1-9, 14-16) are mostly small diffs reusing patterns already in the codebase. Larger feature work (browse surface, disk cache, short-side advisor, FX-leg parsing) is ranked by how much it compounds — caching (rank 11) is flagged as the prerequisite for both offline UX and the scalable catalog.

Not yet verified by running build/tests — these are static-analysis findings against current source; recommend the owner run the canonical xcodebuild build+test after the rank 1-2 quick fixes land, since Monitor and Store are both in the modified-but-uncommitted set per git status.