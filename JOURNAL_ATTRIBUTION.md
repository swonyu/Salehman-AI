# Journal signal-attribution roadmap (wrk0orqi1, 2026-06-22)

5 items — the learn-what-works loop. Tag trades w/ entry signal (optional defaulted fields, old records decode), measure realized expectancy per signal. RE-VERIFY vs source.

### ⬜ #1 — Add optional, defaulted signal-attribution fields to TradeRecord (old records stay decodable)
**mechanism:** In /Users/saleh/Desktop/Salehman AI/Salehman AI/StockSage/StockSageJournal.swift, add NEW stored properties to `struct TradeRecord` (lines 12-66), modeled exactly on `var note: String?` (line 29) — the same optional-defaulted idiom already shipped in persisted data under the `stocksage.journal.v1` UserDefaults key (StockSageJournalStore.load/save:593-603). VERIFIED: `note` is a `var String?` with synthesized Codable and no custom CodingKeys/init(from:), so Swift's synthesized decoder maps a missing key to nil — that IS the backward-compat mechanism and it's load-bearing (load() at line 595 uses `try?`, so any decode throw silently wipes the whole journal). Store the signal as PRIMITIVES, NOT the `TradeAdvice` type: VERIFIED `TradeAdvice` (StockSageAdvisor.swift:10-47) is `Sendable, Equatable` but NOT Codable and lives outside the journal module — embedding it would force a Codable conformance and couple the pure model to the advisor. Add after line 29:
    var signalAction: String?     // TradeAdvice.Action.rawValue, e.g. "Strong Buy"
    var signalConviction: Double? // 0...1 raw advisor conviction
    var signalRegime: String?     // TradeAdvice.Regime.rawValue, e.g. "Bullish trend"
Extend the memberwise init (lines 31-38) with three TRAILING defaulted params `signalAction: String? = nil, signalConviction: Double? = nil, signalRegime: String? = nil` and assign them. Appending at the END keeps EVERY existing call site source-compatible (the test helper `tSym`/`t` at StockSageJournalTests.swift:14-19, `StockSageJournalStore.add`, and `saveDraftTrade` at MarketsView.swift:1285). Add `nonisolated var isFromSignal: Bool { signalAction != nil }`. Do NOT add a custom init(from:)/CodingKeys — synthesis already defaults missing keys for Optionals; a hand-written one risks breaking decode of the other fields.

**signature:** struct TradeRecord: Codable, Sendable, Equatable, Identifiable {
  // existing fields … var note: String?
  var signalAction: String?
  var signalConviction: Double?
  var signalRegime: String?
  init(id: UUID = UUID(), symbol: String, side: Side, entry: Double, stop: Double,
       target: Double?, shares: Double, openedAt: Date,
       exitPrice: Double? = nil, closedAt: Date? = nil, note: String? = nil,
       signalAction: String? = nil, signalConviction: Double? = nil, signalRegime: String? = nil)
  nonisolated var isFromSignal: Bool { signalAction != nil }
}

**test:** In StockSageJournalTests.swift (Swift Testing — `import Testing`, `@testable import Salehman_AI`). VERIFIED Side raw values are "Long"/"Short" (lines 13-16), so the legacy JSON below is valid.

@Test func oldRecordWithoutSignalFieldsStillDecodes() throws {
  let legacy = "[{\"id\":\"00000000-0000-0000-0000-000000000001\",\"symbol\":\"AAPL\",\"side\":\"Long\",\"entry\":100,\"stop\":90,\"shares\":10,\"openedAt\":0}]"
  let recs = try JSONDecoder().decode([TradeRecord].self, from: Data(legacy.utf8))
  #expect(recs.count == 1)
  #expect(recs[0].signalAction == nil)
  #expect(recs[0].signalConviction == nil)
  #expect(recs[0].signalRegime == nil)
  #expect(recs[0].isFromSignal == false)
  #expect(recs[0].symbol == "AAPL")
}
@Test func signalFieldsRoundTrip() throws {
  let t = TradeRecord(symbol: "NVDA", side: .long, entry: 100, stop: 90, target: 120,
                      shares: 5, openedAt: Date(timeIntervalSince1970: 0),
                      signalAction: "Strong Buy", signalConviction: 0.82, signalRegime: "Bullish trend")
  let back = try JSONDecoder().decode(TradeRecord.self, from: JSONEncoder().encode(t))
  #expect(back.signalAction == "Strong Buy")
  #expect(back.signalConviction == 0.82)
  #expect(back.isFromSignal == true)
  #expect(back == t)   // Equatable now includes the new fields
}
Verify: `xcodebuild test -scheme "Salehman AI" -destination 'platform=macOS' -configuration Debug CODE_SIGNING_ALLOWED=NO -only-testing:"Salehman AITests"` 2>&1 | tee /tmp/salehman_build.log | tail -25 — confirm the BUILD + all-tests-passed tail line.

**caveat:** Equatable synthesis now compares the three fields: any pre-existing test that builds two 'equal' records where one was constructed with a tag and the other without will newly differ — intended. The fields are only populated on the prefill-from-idea path (rank 2); manually-typed trades leave them nil, so ALL attribution analytics MUST filter on `isFromSignal`/non-nil and report coverage (e.g. "42 of 60 closed trades carry a signal"), never assume universal attributability. Storing the raw STRING (not the enum) means a future rename of a `TradeAdvice.Action` raw value won't retro-rewrite history (correct — history is immutable) but grouping code must compare against current raw values and tolerate unknown legacy strings. Do NOT touch StockSageJournalCSV in this step (rank 5).

### ⬜ #2 — Populate the signal fields on prefill-from-idea, carried through the draft to the saved record
**mechanism:** VERIFIED the record is built in `saveDraftTrade()` (MarketsView.swift:1282-1293) from @State draft fields, NOT in `prefillTradeFromIdea` (1307-1321) which only fills text fields — so the signal must be carried through draft state. The idea's signal is reached via `idea.advice.action.rawValue` / `idea.advice.conviction` / `idea.advice.regime.rawValue` (StockSageStore.swift:10 → StockSageAdvisor.swift:25-29). NOTE: the source-of-truth here is `TradeAdvice`, NOT `StockSageRecommendation` (StockSageSignalEngine.swift:11-17) — the two enums share the 'Strong Buy'/'Buy'/'Sell' raw strings but `prefillTradeFromIdea` only has a `TradeAdvice`, so standardize on `TradeAdvice.Action.rawValue`. Steps: (1) Add `@State private var draftSignal: (action: String, conviction: Double, regime: String)? = nil` next to `draftNote` (line 62). (2) In `prefillTradeFromIdea`, after the existing assignments (the human-readable `draftNote = "From idea: …"` at line 1316 STAYS — it's user prose; this is the machine-readable tag), set `draftSignal = (idea.advice.action.rawValue, idea.advice.conviction, idea.advice.regime.rawValue)`. (3) In `saveDraftTrade()` pass them into the `TradeRecord(...)` call (lines 1285-1288): `signalAction: draftSignal?.action, signalConviction: draftSignal?.conviction, signalRegime: draftSignal?.regime`. (4) Add `draftSignal = nil` to the existing reset block (line 1290) AND clear it whenever a FRESH manual add opens, so a stale idea-signal can't attach to a hand-typed trade. The existing `isLoggableIdea` gate (1300-1305) already restricts prefill to Buy/Strong Buy/Sell/Reduce — Hold/Avoid never prefill, so they never tag. Use `idea.advice.conviction` (raw 0–1 signal strength), NOT any EV-mapped win-prob.

**signature:** // MarketsView.swift
@State private var draftSignal: (action: String, conviction: Double, regime: String)? = nil

private func prefillTradeFromIdea(_ idea: StockSageIdea) {
  // …existing field fills (draftSymbol/draftEntry/draftStop/draftTarget/draftNote/draftSide)…
  draftSignal = (idea.advice.action.rawValue, idea.advice.conviction, idea.advice.regime.rawValue)
}
private func saveDraftTrade() {
  // …existing guards…
  let trade = TradeRecord(symbol: …, side: draftSide, entry: e, stop: st,
                          target: Double(draftTarget), shares: sh, openedAt: Date(),
                          note: trimmedNote.isEmpty ? nil : trimmedNote,
                          signalAction: draftSignal?.action,
                          signalConviction: draftSignal?.conviction,
                          signalRegime: draftSignal?.regime)
  journal.add(trade)
  // …existing resets at line 1290… ; draftSignal = nil
}

**test:** `saveDraftTrade`/`prefillTradeFromIdea` are private SwiftUI view methods (not headlessly unit-testable), so assert the DATA CONTRACT at the TradeRecord layer with a hand-mirrored mapping. In StockSageJournalTests.swift:

@Test func recordBuiltFromIdeaSignalCarriesAttribution() {
  let t = TradeRecord(symbol: "AAPL", side: .long, entry: 100, stop: 92, target: 120,
                      shares: 10, openedAt: Date(timeIntervalSince1970: 0),
                      note: "From idea: Strong Buy, 82% conviction",
                      signalAction: TradeAdvice.Action.strongBuy.rawValue,
                      signalConviction: 0.82,
                      signalRegime: TradeAdvice.Regime.bullTrend.rawValue)
  #expect(t.signalAction == "Strong Buy")
  #expect(t.signalRegime == "Bullish trend")
  #expect(t.isFromSignal)
}
@Test func manuallyLoggedTradeHasNoSignal() {
  let t = TradeRecord(symbol: "X", side: .long, entry: 10, stop: 9, target: nil,
                      shares: 1, openedAt: Date(timeIntervalSince1970: 0))
  #expect(t.isFromSignal == false)
}
Verify with the canonical `xcodebuild test … -only-testing:"Salehman AITests"` and confirm the BUILD SUCCEEDED / all-passed tail line.

**caveat:** The owner can edit prefilled entry/stop/side before saving — so a saved record's `signalAction` reflects the SIGNAL that triggered the log, not necessarily the hand-tuned numbers (correct for attribution: we credit the signal, not the levels), meaning downstream analytics must not assume `entry`/`stop` equal the idea's original price/stop. A per-tuple `@State` is not Equatable/animatable; if it must drive view diffing later, model it as a small Equatable struct. MarketsView is Chat A's Markets lane — claim it in COORDINATION.md before editing. This prefill path is the ONLY producer wired here; any future entry point won't tag unless it passes the same three args.

### ⬜ #3 — Pure StockSageJournal.bySignalAction(_:) + SignalPnL — realized R grouped by signal, coverage-honest
**mechanism:** Add a pure `nonisolated static` analyzer to `enum StockSageJournal` (StockSageJournal.swift), cloning the proven `bySector(_:)` (lines 529-540) and `SectorPnL` (lines 130-137) shape byte-for-byte — VERIFIED both already filter `!isOpen`, count wins via `realizedProfit > 0`, sum `realizedR`, compute winRate, and sort by totalR descending; reuse those exact idioms so the math stays identical to every other aggregate. Two structural differences from `bySector`: (1) the grouping key is `t.signalAction` instead of `StockSageSector.sector(t.symbol)`; (2) trades with NO signal are EXCLUDED, not bucketed: `for t in closed { guard let a = t.signalAction, !a.isEmpty else { continue }; groups[a, default: []].append(t) }` — keeping a legacy untagged trade out so it can't masquerade as a strategy. Sort best-first by `totalR` (ties by `trades` desc for determinism). ALSO add `signalCoverage(_:)` returning `(attributed: Int, unattributed: Int)` over CLOSED trades so coverage is reported, not assumed. Expose both on `StockSageJournalStore` as computed passthroughs next to `sectorPnL` (line 561): `var signalPnL: [SignalPnL] { StockSageJournal.bySignalAction(trades) }`. Add a `caveat` string constant alongside the existing `StockSageJournal.caveat` (line 542-543) — the journal-wide caveat sweep (tasks #71/#76, both VERIFIED completed) enforces caveat presence on journal analytics.

**signature:** struct SignalPnL: Sendable, Equatable, Identifiable {
  let action: String        // signalAction raw value
  let trades: Int
  let wins: Int
  let totalR: Double
  let avgR: Double
  let winRate: Double        // 0–1
  var id: String { action }
}
extension StockSageJournal {
  nonisolated static func bySignalAction(_ trades: [TradeRecord]) -> [SignalPnL]
  nonisolated static func signalCoverage(_ trades: [TradeRecord]) -> (attributed: Int, unattributed: Int)
}
// StockSageJournalStore:
var signalPnL: [SignalPnL] { StockSageJournal.bySignalAction(trades) }

**test:** In StockSageJournalTests.swift, modeled on the existing `bySectorGroupsAndSortsByTotalR` style:

@Test func bySignalActionGroupsRealizedRAndExcludesUntaggedAndOpen() {
  func rec(_ action: String?, exit: Double?, closed: Bool = true) -> TradeRecord {
    TradeRecord(symbol: "X", side: .long, entry: 100, stop: 90, target: nil, shares: 1,
                openedAt: Date(timeIntervalSince1970: 0), exitPrice: exit,
                closedAt: closed ? Date(timeIntervalSince1970: 100) : nil, signalAction: action)
  }
  let trades = [
    rec("Strong Buy", exit: 120),               // +2R
    rec("Strong Buy", exit: 90),                // −1R
    rec("Buy",        exit: 130),               // +3R
    rec("Buy",        exit: 110, closed: false),// OPEN → excluded
    rec(nil,          exit: 130),               // manual → excluded from grouping, counted unattributed
  ]
  let g = StockSageJournal.bySignalAction(trades)
  #expect(g.count == 2)
  #expect(g.first?.action == "Buy" && g.first?.totalR == 3)   // best-first by totalR
  let sb = g.first { $0.action == "Strong Buy" }!
  #expect(sb.trades == 2 && sb.wins == 1)
  #expect(abs(sb.totalR - 1.0) < 1e-9)
  #expect(abs(sb.avgR - 0.5) < 1e-9)
  #expect(abs(sb.winRate - 0.5) < 1e-9)
  let cov = StockSageJournal.signalCoverage(trades)
  #expect(cov.attributed == 3)   // 3 closed tagged
  #expect(cov.unattributed == 1) // 1 closed manual
  #expect(StockSageJournal.bySignalAction([]).isEmpty)
}
Verify with the canonical `xcodebuild test …` command; confirm BUILD + all-tests-passed tail.

**caveat:** Because untagged trades are dropped, `bySignalAction(trades).map(\.trades).reduce(0,+)` need NOT equal `stats(trades).closed` — intentional, not a bug; assert it so a future 'fix' doesn't re-bucket untagged into a fake group. This measures ASSOCIATION (self-reported labels), not causation — garbage tagging in = garbage attribution out; state that in the `caveat` constant. Win count uses `realizedProfit > 0` (strict), so breakeven is a non-win, matching `bySector`/`bySide`. Per-action samples for a real owner are tiny — any UI MUST show n and lean on the existing significance machinery (ExpectancyCI.isSignificant, tradesToSignificance) before drawing conclusions; never present a 2-trade 'Strong Buy edge' as real. Keep the function PURE/nonisolated and pass `trades` in (like `bySector`/`edge`) so it's deterministic under parallel tests.

### ⬜ #4 — StockSageJournal.whatWorked(_:) — copyable 'what actually worked' summary with the load-bearing caveat
**mechanism:** Build a pure `nonisolated static func whatWorked(_ trades:) -> String?` on `enum StockSageJournal` from `bySignalAction(trades)` (rank 3), following the 'namespaced static returns text' pattern the journal/velocity copy buttons already paste. Return `nil` when `bySignalAction` is empty (no tagged closed trades) so the UI can HIDE the button — VERIFIED that mirrors how `compoundingCurve`/`expectancyConfidence`/`streak` (lines 232/425/437) all return optionals on a thin record. When non-nil: `let best = list.first!; let worst = list.last!`; render best and worst by realized R (totalR plus avgR/winRate/trades for context), formatting signed R as `%+.2fR` exactly like the existing journal copy. If best == worst (single signal), say so honestly rather than printing identical rows. ALWAYS append a closing caveat line stating this is the owner's OWN small-sample history, descriptive not predictive — reuse the tone of `StockSageJournal.caveat` (lines 542-543) and `ExpectancyCI.note` (lines 157-160). Expose on the store: `var whatWorkedSummary: String? { StockSageJournal.whatWorked(trades) }` next to line 561-574.

**signature:** extension StockSageJournal {
  /// Copyable best/worst-by-realized-R summary from signal attribution, with an
  /// explicit 'your own small-sample history, not predictive' caveat. nil when no
  /// signal-tagged closed trades exist.
  nonisolated static func whatWorked(_ trades: [TradeRecord]) -> String?
}
// StockSageJournalStore:
var whatWorkedSummary: String? { StockSageJournal.whatWorked(trades) }

**test:** In StockSageJournalTests.swift, feeding the same tagged set as the rank-3 test:

@Test func whatWorkedNamesBestAndWorstByRealizedRAndCarriesCaveat() {
  let trades = [ /* Strong Buy +2R, Strong Buy −1R (totalR +1), Buy +3R */ ]
  let text = StockSageJournal.whatWorked(trades)!
  #expect(text.contains("Buy"))                    // best, +3R
  #expect(text.contains("Strong Buy"))             // worst, +1R
  #expect(text.range(of: "Buy")!.lowerBound < text.range(of: "Strong Buy")!.lowerBound)
  // caveat presence (matches sweep tests #71/#76):
  #expect(text.lowercased().contains("your") || text.lowercased().contains("own"))
  #expect(text.lowercased().contains("sample") || text.lowercased().contains("not predict"))
}
@Test func whatWorkedNilWhenNoTaggedClosedTrades() {
  #expect(StockSageJournal.whatWorked([]) == nil)
  let untagged = TradeRecord(symbol: "X", side: .long, entry: 10, stop: 9, target: nil, shares: 1,
                             openedAt: Date(timeIntervalSince1970: 0), exitPrice: 11,
                             closedAt: Date(timeIntervalSince1970: 100))
  #expect(StockSageJournal.whatWorked([untagged]) == nil)
}
Verify with the canonical `xcodebuild test …`; confirm BUILD + all-passed tail.

**caveat:** The caveat line is load-bearing and tested — never let a refactor drop it; it's the honesty floor the journal-wide caveat sweep enforces. Keep the function PURE (no store access, no Date.now) so it's deterministic under parallel tests. Do NOT claim statistical significance in the copy — `bySignalAction` rows can be n=1; the text DESCRIBES, it does not validate (same stance as `StockSageJournal.caveat`). The Copy-button wiring (reuse the verbatim NSPasteboard idiom at MarketsView.swift:952-953 / 2234-2235, gate on `if let text = store.whatWorkedSummary`) is Chat A's Markets lane — claim MarketsView in COORDINATION.md first.

### ⬜ #5 — (Optional) Export the signal tag in CSV — only if you bump header + row + test together
**mechanism:** VERIFIED `StockSageJournalCSV` (StockSageJournalCSV.swift) has a FIXED header string at line 11 (`"symbol,side,entry,stop,target,shares,openedAt,exitPrice,closedAt,realizedR,note"`) and writes the row fields in StockSageJournalCSV.csv (lines 16-29), with `note` appended last at line 28. VERIFIED the CSV test (StockSageJournalCSVTests.swift:16) asserts `lines[0] == StockSageJournalCSV.header` BYTE-FOR-BYTE — so the column contract is enforced and any addition MUST update header + row builder + test in the SAME change or the suite breaks. If (and only if) the owner wants tags to survive export, append `signalAction` AFTER `note`: header becomes `…,note,signal`, and add `f.append(t.signalAction ?? "")` after line 28 (escaped via the existing `escape`). This is STRICTLY optional and additive — the attribution report (ranks 3-4) works purely off in-app records and does NOT require CSV. Leave CSV untouched otherwise.

**signature:** // StockSageJournalCSV.swift
static let header = "symbol,side,entry,stop,target,shares,openedAt,exitPrice,closedAt,realizedR,note,signal"
// in csv(_:), after `f.append(t.note ?? "")`:
f.append(t.signalAction ?? "")

**test:** In StockSageJournalCSVTests.swift, update the existing header assertion AND add a round-trip:

@Test func headerIncludesSignalColumn() {
  #expect(StockSageJournalCSV.header.hasSuffix(",signal"))
  #expect(StockSageJournalCSV.header.split(separator: ",").count == 12)
}
@Test func taggedTradeEmitsSignalInLastColumn() {
  let t = TradeRecord(symbol: "NVDA", side: .long, entry: 100, stop: 90, target: nil, shares: 1,
                      openedAt: Date(timeIntervalSince1970: 0), signalAction: "Strong Buy")
  let row = StockSageJournalCSV.csv([t]).split(separator: "\n").map(String.init)[1]
  #expect(row.hasSuffix(",Strong Buy"))
}
@Test func untaggedTradeEmitsEmptyTrailingSignalCell() {
  let t = TradeRecord(symbol: "X", side: .long, entry: 10, stop: 9, target: nil, shares: 1,
                      openedAt: Date(timeIntervalSince1970: 0))
  let row = StockSageJournalCSV.csv([t]).split(separator: "\n").map(String.init)[1]
  #expect(row.hasSuffix(","))   // empty signal cell, no trailing data
}
IMPORTANT: also fix any EXISTING CSV test that hard-codes the old 11-column header or row length, or it will fail. Verify with the canonical `xcodebuild test …`; confirm BUILD + all-passed tail.

**caveat:** Do this ONLY as one atomic change (header + row + every affected test) — a partial edit breaks the byte-exact header assertion at StockSageJournalCSVTests.swift:16 and any column-count test. A comma inside an action string is impossible today (the five `TradeAdvice.Action` raw values are comma-free) but the existing `escape` (lines 36-40) already handles it for safety, so route the value through it. This step is genuinely optional: skip it unless the owner asks for tags in exports — the learn-what-works loop (ranks 1→4) is complete without CSV. After ANY of these changes: run the canonical build+test piped to /tmp/salehman_build.log | tail -25, regenerate SOURCE_BUNDLE.md via `bash tools/bundle_source.sh` (never Read it), update PROJECT_CONTEXT.md (new TradeRecord fields + attribution analytics), and append a dated DEVELOPMENT_LOG.md entry — all standing owner directives.
