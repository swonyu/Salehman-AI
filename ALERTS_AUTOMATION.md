# Alerts/automation roadmap (w0a4pl180, 2026-06-22)

10 items — act-in-time alerts (position stop/target proximity, regime flip, opt-in OS notifications, no spam). RE-VERIFY vs source; engine-first + python-verified test.

### ⬜ #1 — PositionProximityAlert value type (tradeID-keyed sibling to IdeaAlert)
**mechanism:** New pure value type for proximity/level events on OPEN journal positions, mirroring IdeaAlert (per-event UUID id so the same (symbol,kind) can legitimately re-fire over time; Sendable+Equatable+Identifiable). It carries the TradeRecord.id it refers to (UI can deep-link to the journal row), the symbol, a Kind, a human detail string, the triggering mark price, and the side. Kinds cover proximity + hit for BOTH stop and target, respecting side: a LONG stop is below entry / target above; a SHORT is inverted (TradeRecord.Side already encodes this — verified: long stop=90<entry=100, short stop=110>entry=100). Proximity = price entered the warning band but not yet crossed; Hit = price crossed the level this update (same cross-this-bar semantics StockSageAlertDecision.evaluate uses). isWarning mirrors IdeaAlert: nearStop/stopHit are warnings. NOT a replacement for IdeaAlert or StockSageAlertDecision — a sibling.

**signature:** struct PositionProximityAlert: Sendable, Equatable, Identifiable {
    enum Kind: String, Sendable { case nearStop="Approaching stop"; case stopHit="Stop hit"; case nearTarget="Approaching target"; case targetHit="Target hit" }
    let id: UUID
    let tradeID: UUID          // the open TradeRecord this refers to
    let symbol: String
    let side: TradeRecord.Side
    let kind: Kind
    let detail: String
    let price: Double           // the live mark that triggered the event
    nonisolated init(id: UUID = UUID(), tradeID: UUID, symbol: String, side: TradeRecord.Side, kind: Kind, detail: String, price: Double)
    nonisolated var isWarning: Bool { kind == .nearStop || kind == .stopHit }
}

**test:** Place in NEW file 'Salehman AI/StockSage/StockSagePositionAlerts.swift' (new .swift under 'Salehman AI/' auto-compiles, no pbxproj edit). Verified facts grounding it: IdeaAlert in StockSageAlerts.swift keys by symbol only (per-event UUID id, NO tradeID), TradeRecord.Side {long,short} and TradeRecord.id (UUID, Identifiable) confirmed in StockSageJournal.swift. Tested via the rank-2 detector's test file (pure value type needs no standalone test beyond construction). Keep a static caveat let on the enum, matching every other StockSage type (Caveat-presence sweep, tasks #71/#76). Real-data-only: consumes prices the caller fetched live; no synthetic prices generated here.

**caveat:** Do NOT reuse IdeaAlert: it is keyed by symbol only, but a user can hold TWO open positions in the same symbol (scale-in at different entries/stops), so proximity must be per-TradeRecord. Reusing IdeaAlert would collapse two distinct open positions into one alert. Free/delayed-data honesty: the 'price' field is a delayed free-feed mark, never the user's logged level.

### ⬜ #2 — StockSagePositionAlerts.detect — pure proximity/level detector over open positions
**mechanism:** Pure, nonisolated, deterministic enum function: takes OPEN journal positions plus previous & current price marks per symbol, emits PositionProximityAlert events. Proximity counterpart to StockSageAlerts.detect — same 'only emit on a transition' discipline so a standing condition never re-fires every poll. For each open TradeRecord with a usable stop (and optional target), it computes side-aware distance from the current mark to the level as a fraction of the entry→level risk distance (riskPerShare=abs(entry-stop), already on TradeRecord). nearStop fires when the mark CROSSES INTO the band this update (prev outside, now inside but not through). stopHit fires when the mark crosses THROUGH the stop this update (long: prev>stop now<=stop; short: prev<stop now>=stop) — identical to StockSageAlertDecision.evaluate's stop logic, generalized to side. Target proximity/hit are symmetric toward profit. A position with no previous mark never alerts (same rule as StockSageAlerts). Closed positions skipped (isOpen filter). band defaults 0.25, parameterized for tuning.

**signature:** enum StockSagePositionAlerts {
    nonisolated static func proximityFraction(entry: Double, level: Double, mark: Double) -> Double?  // dist mark→level / risk dist; nil if riskPerShare==0
    nonisolated static func detect(openPositions: [TradeRecord], previousMarks: [String: Double], currentMarks: [String: Double], band: Double = 0.25) -> [PositionProximityAlert]
    nonisolated static let caveat = "Proximity to your own stop/target — the levels YOU logged, not advice. An alert flags that a delayed price reached a line you drew, not that you should act."
}

**test:** Add 'Salehman AITests/StockSagePositionAlertsTests.swift' using Swift Testing (import Testing; @testable import Salehman_AI; struct + @Test + #expect — match StockSageAlertsTests.swift/StockSageJournalTests.swift, NOT XCTest). Local literals only (parallel tests; no shared UserDefaults). Cases: (1) longNearStopFiresOnBandEntry — long entry=100 stop=90, prev=96(dist .6) cur=92(dist .2) => one .nearStop; prev=92→cur=91 => no re-fire. (2) longStopHitOnCrossDown — prev=92 cur=89 => .stopHit, not a duplicate .nearStop. (3) shortStopIsAbove — short entry=100 stop=110, prev=104 cur=108 => .nearStop; prev=108 cur=111 => .stopHit. (4) targetProximityAndHitLong — entry=100 target=120 stop=90; approach 120 from below enters band then crosses => .nearTarget then .targetHit. (5) noPreviousMarkNeverAlerts => []. (6) closedPositionsIgnored => nothing. (7) twoOpenPositionsSameSymbol — two open longs in 'X', different stops, each alerts keyed by tradeID. (8) caveatPresent non-empty. (9) gapThroughStop — prev far above, cur far below (never entered band) => still .stopHit. Verify green via canonical xcodebuild build + test (tee /tmp/salehman_build.log | tail -25). Python-verifiable analog: the side-aware crossing + fraction math can be reproduced in a tiny Python script asserting the same 9 cases.

**caveat:** Math-lie edge cases that MUST be handled: riskPerShare==0 (entry==stop) => proximityFraction returns nil (undefined risk, mirrors TradeRecord.rMultiple returning nil on zero risk — confirmed in StockSageJournal.swift). target==nil => emit no target events (target Optional on TradeRecord; stop non-optional). Guard prices>0. A gap THROUGH the stop without entering the band must still emit .stopHit. Never emit both .nearStop and .stopHit for one level in one call (hit supersedes near). Marks are delayed free-feed closes, never the TradeRecord's own logged levels.

### ⬜ #3 — AppSettings opt-in flag: stockSageNotificationsEnabled (default OFF)
**mechanism:** Single new persisted boolean in AppSettings ('Salehman AI/App/AppSettings.swift') following the existing opt-in privacy-flag pattern (offlineOnly/unrestrictedTools, verified at lines 112/124/188/190/351/353): a @Published var with a didSet writing UserDefaults, a Keys constant, an init read defaulting OFF, and a nonisolated thread-safe reader for off-main callers. This is the ONLY gate that lets any OS-level UserNotification be scheduled for markets. Default OFF = no notification, no permission prompt, until the user explicitly opts in. The existing in-app alertsPanel (store.alertsEnabled, line 62) is unchanged and independent — this flag governs OS delivery only. This is the keystone of the opt-in/anti-spam chain (ranks 4-9).

**signature:** // class body:
@Published var stockSageNotifications: Bool { didSet { UserDefaults.standard.set(stockSageNotifications, forKey: Keys.stockSageNotifications) } }
// Keys enum:
nonisolated static let stockSageNotifications = "set_stockSageNotificationsEnabled"
// private init():
stockSageNotifications = d.bool(forKey: Keys.stockSageNotifications)  // default off (opt-in)
// thread-safe reader (distinct name from instance var to avoid ambiguity):
nonisolated static var stockSageNotificationsEnabled: Bool { UserDefaults.standard.bool(forKey: Keys.stockSageNotifications) }

**test:** In a new test (StockSageNotifierTests or StockSageTests): assert a FRESH UserDefaults suite (no value set) reads false from the nonisolated reader, and that setting the key true reads back true. MUST use a UNIQUE suite name (UserDefaults(suiteName:)), never the standard suite, so parallel tests don't collide on this key (CLAUDE.md rule: never have two tests mutate the same global UserDefaults key). Python-verifiable analog: trivial default-false / set-true read-back assertion.

**caveat:** Name collision avoidance (verified: AppSettings already uses instance 'unrestrictedTools' + static 'unrestrictedToolsEnabled', and instance 'offlineOnly' + static 'isOfflineOnly'). Follow that convention exactly: instance var 'stockSageNotifications' + static 'stockSageNotificationsEnabled'. A static and instance var can technically coexist but the distinct names keep call sites unambiguous. OFF-by-default is load-bearing: a user who never opts in must never see a banner built on delayed data they didn't realize was delayed.

### ⬜ #4 — StockSageNotifier — OS delivery gate + lazy permission only on opt-in
**mechanism:** New @MainActor helper (new file 'Salehman AI/StockSage/StockSageNotifier.swift') owning ALL UNUserNotificationCenter scheduling for high-priority markets alerts. It (a) early-returns when AppSettings.shared.stockSageNotifications is false; (b) requests authorization LAZILY the first time delivery is attempted while enabled (not on launch, not on monitor.start()), so a user who never opts in is never prompted; (c) refuses to schedule on sample/seed data (mirrors the Monitor's existing isSampleData honesty guard, verified StockSageMonitor.swift line 79) and when ToolPolicy reports web tools disabled (no live data => no live alert). No network — only a local UNNotificationRequest(trigger: nil). The unconditional StockSageMonitor.requestNotificationPermission() call in start() (line 43) is REMOVED/moved behind this gate so opt-out users get no permission dialog.

**signature:** @MainActor enum StockSageNotifier {
    nonisolated static func shouldDeliver(enabled: Bool, isSample: Bool, webDisabled: Bool) -> Bool  // pure, testable: enabled && !isSample && !webDisabled
    static func deliver(title: String, body: String, dedupeKey: String) async
    static func ensureAuthorizationIfEnabled() async -> Bool
}
// Monitor.sendAlert(...) and the new regime/idea paths route through await StockSageNotifier.deliver(...) instead of building UNMutableNotificationContent inline.

**test:** Cannot unit-test real UNUserNotificationCenter delivery headlessly (it can crash/no-op in an unbundled test process — NEVER call UNUserNotificationCenter.current() from XCTest). Test the PURE gate: shouldDeliver(enabled:isSample:webDisabled:) returns true ONLY when enabled && !isSample && !webDisabled. Assert the full truth table (8 rows). Keeps the @MainActor side-effecting shell thin over a tested rule — the exact pattern StockSageAlertDecision already follows. Python-verifiable analog: reproduce the 3-input AND truth table.

**caveat:** UNUserNotificationCenter.current() can crash/no-op in an unbundled/test process — never call it from tests. Authorization is async and may be DENIED at the OS level even when the in-app flag is on — deliver() must treat a denied OS permission as a silent no-op, NOT re-prompt every cycle. The opt-in flag is necessary but not sufficient: macOS Notification Center settings are the final authority. No live data (web tools off) => no live alert.

### ⬜ #5 — Anti-spam: priority filter + per-event dedup + coalescing cap
**mechanism:** Only the three highest-priority event classes are ever delivered as OS notifications: (1) stopBreach, (2) targetHit, (3) regime entering .crisis. Signal flips (flipBullish/flipBearish) and new strong-buy/sell stay IN-APP ONLY (already shown in the alertsPanel) — too frequent to push. Dedup reuses the SAME crossing semantics already proven in StockSageAlerts.detect and StockSageMonitor.lastAlerted (verified lines 26/89): a crossing fires once on the transition, never every poll. Regime-crisis dedup is an edge-trigger: notify only on the transition into .crisis from a non-crisis state, store lastNotifiedRegimeState, never re-notify while it stays in crisis. A coalescing cap (N per refresh cycle) collapses >N simultaneous stop/target crossings into ONE summary banner ('M positions hit stops/targets') instead of M banners.

**signature:** nonisolated static func notifiableAlerts(_ alerts: [IdeaAlert]) -> [IdeaAlert]   // keeps only .stopBreach/.targetHit
nonisolated static func regimeCrisisCrossing(previous: MarketRegime.State?, current: MarketRegime.State) -> Bool  // true only on non-crisis -> .crisis
nonisolated static func coalesce(_ alerts: [IdeaAlert], cap: Int) -> [DeliverableNotification]  // collapses to a summary when count > cap

**test:** Pure tests in StockSageTests (Swift Testing): notifiableAlerts drops flips/keeps stop+target; regimeCrisisCrossing(.trendingBull, .crisis)==true, (.crisis,.crisis)==false, (nil,.crisis)==true (first-ever crisis read notifiable once); coalesce of 5 alerts with cap 3 yields exactly 1 summary. All deterministic, no I/O. MarketRegime.State is String-RawRepresentable+Equatable (verified StockSageRegime.swift lines 18-23) so cases are literal. Python-verifiable analog: same filtering + edge-trigger + coalesce-count assertions in pure Python.

**caveat:** 'First read is crisis' is a judgment call: treating nil->crisis as notifiable means a cold launch during a real crisis alerts once (desired), but if the very first regime read is on stale/partial data it could mislead — guard with StockSageStore staleness (a ~6 trading-hour regime-staleness concept already exists) so a stale crisis read does NOT push a banner. Free/delayed data means a 'crossing' computed from a delayed close can fire after price already moved further — that's why flips stay in-app and only stop/target/crisis push.

### ⬜ #6 — Wire position-alert detection into refresh (Store) — real-data-only, no UI invention
**mechanism:** Non-invasive integration mirroring how idea alerts are already wired. Add to StockSageStore: @Published private(set) var positionAlerts: [PositionProximityAlert] = [] and a capped append (reuse maxAlerts=50, verified line 64). Inside refreshIdeas() — at the existing detect site (lines 179-181, under `if alertsEnabled, !ideas.isEmpty`) and BEFORE `ideas` is replaced — build previousMarks from OLD `ideas` (symbol->price) and currentMarks from `ranked` (verified line 177), call StockSagePositionAlerts.detect(openPositions: StockSageJournalStore.shared.open, previousMarks:currentMarks:), prepend results capped at maxAlerts. The previous snapshot already exists (`ideas` is replaced AFTER detect — same ordering the idea-alert call relies on). Both stores are @MainActor singletons so .open is reachable without hops.

**signature:** // StockSageStore additions:
@Published private(set) var positionAlerts: [PositionProximityAlert] = []
func clearPositionAlerts()
// inside refreshIdeas(), within `if alertsEnabled, !ideas.isEmpty {`, AFTER StockSageAlerts.detect and BEFORE `ideas = ranked`, AND gated additionally on !isSampleData:
let prevMarks = Dictionary(ideas.map { ($0.symbol.uppercased(), $0.price) }, uniquingKeysWith: { a,_ in a })
let curMarks  = Dictionary(ranked.map { ($0.symbol.uppercased(), $0.price) }, uniquingKeysWith: { a,_ in a })
let posFired  = StockSagePositionAlerts.detect(openPositions: StockSageJournalStore.shared.open, previousMarks: prevMarks, currentMarks: curMarks)
if !posFired.isEmpty { positionAlerts = Array((posFired + positionAlerts).prefix(Self.maxAlerts)) }

**test:** Detection is covered by the pure StockSagePositionAlertsTests (rank 2); the @MainActor Store wiring is glue, not separately unit-tested — consistent with how the existing idea-alert wiring in refreshIdeas() is exercised only through the pure StockSageAlerts.detect tests. Verify the whole thing compiles and stays green: canonical xcodebuild build (tee /tmp/salehman_build.log | tail -25) then xcodebuild test -only-testing:'Salehman AITests'. Append a dated DEVELOPMENT_LOG.md entry (owner standing directive) and regenerate SOURCE_BUNDLE.md via bash tools/bundle_source.sh.

**caveat:** Honesty floor (load-bearing): proximity alerts must NEVER fire on sample/seed data. isSampleData==true means demo numbers (2222.SR / NVDA are seeded), so the build MUST additionally check !isSampleData — otherwise a user holding a journal position in a seeded symbol gets a fake 'Stop hit' on hardcoded demo prices. Marks come ONLY from ranked/ideas (real fetched closes), NEVER from the TradeRecord's own entry/stop/target (user inputs) — using logged levels as the mark would make every position perpetually 'at its stop'. Verified: isSampleData is @Published at line 35.

### ⬜ #7 — Wire OS delivery into existing detection sites (no new polling, no new data)
**mechanism:** Two existing paths already compute events on REAL data; hook delivery there rather than adding a timer/fetch. (A) refreshIdeas (line 156) already calls StockSageAlerts.detect when alertsEnabled — after appending the in-app `alerts` list (line 181), pass the freshly-fired alerts through StockSageNotifier (filtered to stop/target via notifiableAlerts) so the SAME detected crossing that updates the list also delivers a banner; also route the new positionAlerts stopHit/targetHit. (B) refreshRegime (line 284) already assigns `regime` (line 312) — capture old state BEFORE assess(), compare via regimeCrisisCrossing, deliver a crisis banner once on entry. StockSageMonitor.runCycle already refreshes the store (line 49), so crossings detect during its cycles too. No new network, no fabricated values — delivery is a pure side-channel off data already fetched and already gated through ToolPolicy + isSampleData.

**signature:** // in refreshIdeas, after `alerts = Array((fired + alerts)...)`:
await StockSageNotifier.deliverAlerts(StockSageNotifier.notifiableAlerts(fired))
// in refreshRegime, capture prev BEFORE assess:
let prevState = regime?.state
regime = StockSageRegime.assess(indexCloses: idx.closes, vix: vix, breadthAbove200: breadth)
if !regimeIsStale, StockSageNotifier.regimeCrisisCrossing(previous: prevState, current: regime!.state) {
    await StockSageNotifier.deliver(title: "Markets: risk-off / high volatility", body: regime!.caveat, dedupeKey: "regime-crisis")
}

**test:** Driving refreshIdeas/refreshRegime end-to-end is integration-level (needs the feed) — instead unit-test the wiring helpers (notifiableAlerts, regimeCrisisCrossing, shouldDeliver) and assert: refreshIdeas only routes to the notifier when BOTH alertsEnabled (in-app) AND stockSageNotificationsEnabled (OS) are true; with isSampleData==true (default seeded state) deliverAlerts is a no-op. Verify green via canonical build+test. Python-verifiable analog: the routing predicate (alertsEnabled && osEnabled && !isSample) as a boolean assertion table.

**caveat:** refreshIdeas's alert detection is gated on alertsEnabled (the in-app log toggle), so OS notifications would couple to that toggle unless crossings are detected independently. DECIDE EXPLICITLY: recommend (a) OS notifications require BOTH toggles on — fewest moving parts, least surprising, and the user already opted into seeing alerts at all. The in-app alertsPanel and the OS banner share one detection pass; never add a second poll. Crisis body must be the honest MarketRegime.caveat string (delayed, lagging), never an actionable instruction.

### ⬜ #8 — Honest user-facing caveat in Settings + notification copy
**mechanism:** The opt-in Settings toggle and EVERY delivered notification must state plainly this is delayed/free market data on a polling loop, NOT a live broker feed or trade trigger. The Settings row label/subtitle and the notification body strings carry the disclaimer so the user cannot mistake a 'Stop hit' banner for a real-time execution alert. Matches the repo's standing honesty floor (alerts flag an EVENT, not a profit — see the StockSageAlertDecision header verified at lines 8-9, and the existing alertsPanel copy) and the run-cycle sample-data guard that already refuses to notify on demo prices (Monitor line 79).

**signature:** // SettingsView markets section row:
title: "Market alert notifications"
subtitle: "Off by default. Sends a macOS notification only for a stop hit, target reached, or a shift into high-volatility (risk-off). Polled on delayed, free market data — not a live broker feed; never an instruction to trade."
// notification bodies keep existing StockSageAlertDecision phrasing, e.g.:
stop: "<SYM> hit its stop (<px> <= <stop>) — the setup is invalidated; risk is realized. (Delayed data — verify before acting.)"

**test:** Pure caveat-presence test (mirrors the existing Caveat-presence sweep, tasks #71/#76): assert the regime-crisis body == MarketRegime.caveat-derived string, and that every notification body contains a delayed-data / not-a-broker-feed disclaimer substring. Deterministic string assertions, no I/O. Python-verifiable analog: substring-presence checks over the fixed body templates.

**caveat:** This is the load-bearing honesty constraint, not decoration. Free quote feeds (the Yahoo-style endpoints StockSageQuoteService uses) can be 15+ min delayed, rate-limited, or wrong; a stop/target 'crossing' from a delayed close can fire after the real price already moved further. The notification must never imply real-time actionability, and the feature must stay OFF by default so a user is never surprised by a banner built on data they didn't realize was delayed.

### ⬜ #9 — RegimeFlipAlert — one-time de-risk notice on a risk-on -> risk-off / crisis transition
**mechanism:** New pure file 'Salehman AI/StockSage/StockSageRegimeFlip.swift'. Value type RegimeFlipAlert + enum StockSageRegimeFlip with one pure detector comparing PREVIOUS MarketRegime to CURRENT, emitting an alert ONLY on a deterioration crossing — never on steady state, improvement, or the first-ever reading (no previous => no alert, mirroring StockSageAlerts.detect). Deterioration is a fixed severity ranking of MarketRegime.State: rank(.trendingBull)=3, .ranging=2, .trendingBear=1, .crisis=0. Fires iff rank(current)<rank(previous) AND current is risk-off-or-worse (.trendingBear||.crisis) — any crossing INTO .crisis always fires (lowest rank). detail names the transition (prev.state.rawValue + ' -> ' + cur.state.rawValue), the riskScore swing, and one imperative de-risk line. A severity field (.defensive for the bear crossing, .crisis for any crossing into .crisis) lets the UI pick a color. ONE-TIME is structural: keying off the CHANGE means a regime that STAYS risk-off yields rank(current)==rank(previous) and emits nothing. A thin @MainActor seam in StockSageStore persists the last-ALERTED state so the notice survives polls/relaunches and re-arms only on recovery.

**signature:** nonisolated static func rank(_ s: MarketRegime.State) -> Int
nonisolated static func detect(previous: MarketRegime?, current: MarketRegime) -> RegimeFlipAlert?
nonisolated static let caveat = "...lagging, confirming indicators — this fires AFTER the regime already deteriorated..."
// WIRING SEAM in StockSageStore.refreshRegime() (the only side-effecting code):
@Published private(set) var regimeFlip: RegimeFlipAlert?
private static let lastAlertedRegimeKey = "stocksage.regime.lastAlertedState.v1"
private var lastAlertedRegimeState: MarketRegime.State? { get/set via UserDefaults string + MarketRegime.State(rawValue:) }
private func evaluateRegimeFlip(previous: MarketRegime?, current: MarketRegime)  // re-arm on recovery, suppress re-alert on already-alerted to-state
func dismissRegimeFlip() { regimeFlip = nil }
// capture `let previousRegime = regime` BEFORE assess() at line 312, call evaluateRegimeFlip(previous: previousRegime, current: regime!) after.

**test:** Append StockSageRegimeFlipTests to StockSageTests.swift (Swift Testing). Drive the REAL assess() into each state so tests track real thresholds (verified StockSageRegime.assess at line 68; VIX>=40 forces .crisis at line 91; >=0.40/<=-0.40 thresholds at lines 99-100): bull()=uptrend+VIX14+breadth.85; ranging()=downtrend+VIX14+breadth.50; bear()=downtrend+VIX30+breadth.10; crisis()=VIX55. Cases: firstReadNeverAlerts (nil prev => nil); bullToBearFiresDefensive (severity .defensive, to .trendingBear); anyCrossingIntoCrisisFires (bull/ranging/bear -> crisis => .crisis); improvementNeverAlerts (bear->bull, crisis->ranging => nil); steadyStateIsSilentNoRepeat (bear->bear, crisis->crisis => nil); bullToRangingDoesNotFire (neutral not risk-off => nil); rankOrderingIsMonotonic; carriesHonestLaggingCaveat (caveat contains 'lagging'). The @MainActor seam stays OUT of the pure tests. Python-verifiable analog: the rank-table + (rank<prevRank && current risk-off) predicate plus the re-arm-on-recovery state machine.

**caveat:** HONEST LAGGING NATURE (must ship in the UI, not just code): every input to assess is confirming/backward-looking — price vs 200DMA, index RSI, breadth above 200DMA, VIX level (verified lines 73-94). None lead the turn. This fires AFTER deterioration, often well into a drawdown, and will sometimes whipsaw — a 'reduce exposure now the weather visibly changed' nudge, NOT a top-call. Surface StockSageRegimeFlip.caveat alongside it. Two secondary points: (1) one-time is only structural at the pure layer; the @MainActor seam must persist the last-ALERTED state and suppress until the regime recovers to a higher rank, and that seam stays out of pure tests. (2) the .ranging (bull->neutral) crossing is deliberately silent — a cooldown is not yet risk-off; only bear/crisis crossings warrant a de-risk notice.

### ⬜ #10 — Conviction-flip detection on watched ideas (extend StockSageAlerts, not a rewrite)
**mechanism:** Today StockSageAlerts.detect fires .flipBullish/.flipBearish only when the ACTION crosses INTO the bullish set {strongBuy,buy} or bearish set {sell,reduce} (verified lines 36-37, 50-58). It does NOT fire when an idea STRENGTHENS within the same side (buy->strongBuy) — and the existing bearishFlipFires test asserts buy->strongBuy is NOT a flip. Add an OPT-IN strengthening signal: new IdeaAlert.Kind cases .convictionUp/.convictionDown that fire when the action moves to a STRONGER same-direction rung (buy->strongBuy, reduce->sell). Implement as new enum cases plus a few lines in the existing detect loop, GATED behind a new trailing parameter (default false) so the existing 2-arg call in refreshIdeas() and the 5 existing StockSageAlertsTests stay green unchanged. Rank strongBuy>buy>hold/avoid>reduce>sell via a private strength(_:) helper; emit .convictionUp on a strictly-stronger bullish rung, .convictionDown on the bearish side. Crossing-only discipline preserved (only on a rung change, deduped by the previous snapshot exactly like action flips).

**signature:** // add to IdeaAlert.Kind: case convictionUp="Conviction rising"; case convictionDown="Conviction falling"
nonisolated static func detect(previous: [StockSageIdea], current: [StockSageIdea], includeConvictionShifts: Bool = false) -> [IdeaAlert]
private nonisolated static func strength(_ a: TradeAdvice.Action) -> Int  // strongBuy=2, buy=1, hold/avoid=0, reduce=-1, sell=-2

**test:** Extend StockSageAlertsTests.swift with @Test cases: (1) convictionRiseFiresWhenOptedIn — prev buy, cur strongBuy, includeConvictionShifts:true => one .convictionUp; same inputs with param omitted/false => [] (backward-compat). (2) sideFlipStillBeatsConviction — hold->strongBuy emits .flipBullish (a side entry), not .convictionUp, even when opted in. (3) convictionDownOnBearishStrengthen — reduce->sell with flag on => .convictionDown. Re-run the existing 5 tests unchanged to prove no regression (bearishFlipFires still asserts buy->strongBuy yields [] when the flag is off). Python-verifiable analog: the strength-rung table plus the side-entry-first / same-side-strengthening predicate.

**caveat:** Do NOT change the DEFAULT behavior of detect: refreshIdeas() calls detect(previous:current:) with no extra arg (verified line 180) and bearishFlipFires asserts buy->strongBuy returns []. A new mandatory param or a behavior change on the 2-arg call breaks the build AND the test — the flag MUST default to false. A true side flip (hold->strongBuy crosses INTO the bullish set) must remain .flipBullish, not be relabeled .convictionUp — the side-entry check runs first; conviction shifts apply only when BOTH prev and cur are already on the same side. Lowest rank: a within-side rung change is a softer signal than a side flip, hence in-app-only and never an OS push (anti-spam, rank 5).
