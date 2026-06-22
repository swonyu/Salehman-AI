# Integration audit — orphaned engines (weacf9n9o, 2026-06-22)

6 built-but-disconnected engines. #2 (trendOK veto into advise) WIRED. Rest: wire into the live path.

### ✅ DONE #1 — StockSageLossLimit circuit breaker is orphaned — no post-loss-streak halt anywhere in the app
**builtEngine:** Salehman AI/StockSage/StockSageLossLimit.swift — StockSageLossLimit.evaluate(closedTrades:policy:now:calendar:) (signature confirmed at line 52) -> LossLimitState (status ok/warn/halted, dailyRealized, weeklyRealized, lossRun, haltReason, caveat); LossLimitPolicy(maxDailyLoss/maxWeeklyLoss/maxDailyLossR/maxWeeklyLossR/standDownLossRun/warnFraction) at line 13, init at line 21.

**wiredInto:** NOTHING. Natural home: the journal panel in Salehman AI/Views/MarketsView.swift (~line 1040), where journal.streakSummary is already rendered and journal.trades is already in scope.

**fix:** In journalPanel (after the streakSummary block ~line 1043) render a status chip from `StockSageLossLimit.evaluate(closedTrades: journal.trades, policy: LossLimitPolicy(standDownLossRun: 3))` — show state.status (ok/warn/halted) + state.haltReason + state.caveat (default policy needs no AppSettings work).

**value:** Highest. Post-loss-streak revenge/over-sizing is the #1 way retail accounts blow up, and this is the cheapest wire: its exact input ([TradeRecord] closed trades) is already aggregated in the journal panel where JournalStreak's win/loss run is already displayed, and the journal's own System-health verdict already literally says 'stand down' (StockSageJournal.swift:305) with nothing enforcing it. Confirmed zero app-target callers: only StockSageLossLimitTests.swift references it.

### ✅ DONE #2 — timeSeriesMomentum / trendOK own-trend crash-filter veto is built + unit-tested but never reaches advise() or the rank
**builtEngine:** Salehman AI/StockSage/StockSageIndicators.swift:189 timeSeriesMomentum + :201 trendOK (binary risk-on/off wrapper, $0>0). Passing tests at StockSageIndicatorsTests.swift:111-122.

**wiredInto:** Nothing in the live path. confirmed NOT present in StockSageAdvisor.advise (grep returns no trendOK in StockSageAdvisor.swift), buildIdeas, rankScore, or StockSageBacktester.

**fix:** In StockSageAdvisor.advise, right after the relativeStrength block (after line 171, before `let regime` at line 173; `closes` already in scope): `if score > 0, StockSageIndicators.trendOK(closes) == false { score -= 0.20; rationale.append("Against the name's own 12-1 downtrend — momentum veto") }`

**value:** High. It is the one new signal the research notes frame as a crash filter / veto, and the ONLY one of the four (vs volumeConfirmation/volAdjustedMomentum/relativeStrength, all confirmed to mutate `score`) that does not influence advise() and therefore never moves an idea's conviction/action or its rankScore. rankScore (StockSageAdvisor.swift) is a pure function of action+conviction, both sourced solely from `score`, so a signal counts iff it mutates `score` — and trendOK never does. Confirmed: only call sites repo-wide are the doc-comment and StockSageIndicatorsTests.swift.

### ✅ DONE #3 — StockSageGapRisk — forward 'a stop is not a guaranteed fill' quantifier is orphaned
**builtEngine:** Salehman AI/StockSage/StockSageGapRisk.swift — worstCase(side:entry:stop:shares:…) at line 62 and fromPosition(_:side:stop:entry:accountEquity:gapPct:) at line 70 -> [GapRiskScenario]; each scenario has .verdict (line 24), .exceedsAccount (line 22), .rMultiple, .accountLossPct.

**wiredInto:** NOTHING. Natural home: positionSizerPanel(_:) in Salehman AI/Views/MarketsView.swift (line 2644), which already computes the PositionSize and shows a weaker static gap string (~line 2671).

**fix:** In positionSizerPanel(_:), replace the static gap warning (~line 2671) with `StockSageGapRisk.fromPosition(ps, side: (idea.advice.action == .sell || idea.advice.action == .reduce) ? .short : .long, stop: stop, entry: idea.price, accountEquity: Double(sizerAccount) ?? 0)` and render each scenario's .verdict (red if .exceedsAccount).

**value:** Medium-high. Real, distinct honesty gap: no surface quantifies gap-through-stop forward (the backtester only models gaps backward in simulateExit), and the sizer panel hand-rolls a weaker static gap warning at MarketsView.swift:2671. Near drop-in — entry/stop/shares/account/side are all already in scope in positionSizerPanel, and a fromPosition(PositionSize,…) bridge exists purpose-built. Lower than LossLimit because it informs rather than halts. Confirmed zero app-target callers.

### ✅ DONE #4 — StockSageLeverage — margin/liquidation honesty (100/L wipeout, liq price, drawdown multiplier) is orphaned
**builtEngine:** Salehman AI/StockSage/StockSageLeverage.swift — assess(account:notional:entry:) at line 47 (and assess(leverage:entry:) at line 34) -> LeverageRisk? (liquidationMovePct=100/L, liquidationPrice, drawdownMultiplier, canLoseMoreThanAccount, .verdict at line 19, .caveat).

**wiredInto:** NOTHING. Natural home: the `if leveraged` branch (line 2671) of positionSizerPanel(_:) in Salehman AI/Views/MarketsView.swift (leveraged computed at line 2659), which already knows the position is leveraged and shows a generic string.

**fix:** Inside the `if leveraged` branch (~line 2671), render `StockSageLeverage.assess(account: Double(sizerAccount) ?? 0, notional: ps.notional, entry: idea.price)?.verdict` in place of the generic static warning string.

**value:** Medium. Genuine gap and a clean wire (the book-based overload assess(account:notional:entry:) takes exactly the values already in scope, and L = notional/account is the same ratio pctOfAccount already uses), but partially redundant with the existing `leveraged` detection warning at MarketsView.swift:2659/2671 — it upgrades an existing warning rather than filling a blind spot, so it is the lowest-priority orphan to surface. Confirmed zero app-target callers.

### ⬜ #5 — Quote disk cache has no max-age bound and the cached-as-of label uses an HH:mm-only formatter (a previous-day cache reads as today)
**builtEngine:** StockSageQuoteCache (persisted last-good quotes with savedAt; load() enforces no upper age bound — confirmed no max-age/expire in StockSageQuoteCache.swift) + loadedFromCache/cacheSavedAt store flags set in StockSageStore.loadCachedQuotes() (~line 83).

**wiredInto:** Header subtitle shows a cached label (MarketsView.swift ~line 312) but with the HH:mm-only formatter and no max-age bound; cached prices feed Portfolio/Allocation/Currency value math unlabeled at the row level.

**fix:** In MarketsView.headerSubtitle, when loadedFromCache and cacheSavedAt is not from today, format with a date (relative/date+time) instead of the bare HH:mm formatter — and optionally drop or '⚠︎ stale cache'-flag a cache older than ~N days.

**value:** Medium. Highest-value of the remaining freshness gaps because cached prices silently feed Portfolio value, FX exposure, and what-if math at the row level via currentPrice(). NOT a fabricated-number violation — the data is real last-good live quotes, honestly labeled as cached — but 'how stale' is under-communicated: the date is dropped from the label (HH:mm-only, MarketsView.swift Self.timeFormatter) and there is no age ceiling, so a weeks-old snapshot can read as today's.

### ⬜ #6 — TodayView 'Best bet' tile shows EV from store.ideas with no staleness label while the Markets card warns the same scan is stale
**builtEngine:** StockSageExpectedValue.bestOpportunity (positive-EV-gated; now regime-gated via stockSage.regime at TodayView.swift:260) + StockSageStore.ideasUpdated timestamp (@Published).

**wiredInto:** Markets ideas header is staleness-labeled (MarketsView.swift, 4h threshold via store.ideasUpdated), but the Today tile (TodayView.swift:260) has NO equivalent check — confirmed no ideasUpdated/stale reference in TodayView.swift.

**fix:** In TodayView, gate or annotate the best-bet tile on freshness — only show it (or append a '· stale' qualifier) when stockSage.ideasUpdated is within the same 4h bound MarketsView uses; hide when ideasUpdated is nil or older.

**value:** Low. Freshness-labeling polish, not an ONLY-REAL-DATA violation: store.ideas is never persisted (empty on every fresh launch, only populated by an in-session 'Find ideas' scan), bestOpportunity returns nil unless a genuine positive-EV buy exists, and the shown value is an R-multiple EV estimate with caveat copy — not a stale price. The inconsistency: in a long session the Today tab keeps surfacing a best bet computed on hours-old ideas while Markets flags the same scan stale (>4h).
