# Risk-engine UI wiring plan (w4laq3ie0, 2026-06-22)

4 concrete placements to surface GapRisk/LossLimit/Leverage (+ caveats) in MarketsView. RE-VERIFY symbols+line numbers vs source; typecheck only (UNVERIFIED render); one MarketsView edit at a time to avoid collisions.

### ⬜ #1 — Loss-limit circuit breaker banner (STOP TRADING / approaching-limit) atop the Trade journal card
**surface:** /Users/saleh/Desktop/Salehman AI/Salehman AI/Views/MarketsView.swift

**placement:** Add a `lossLimitPolicy` computed property and a `lossLimitBanner` @ViewBuilder to the MarketsView struct. Put `lossLimitBanner` immediately AFTER tradeJournalPanel's closing brace, just before `private var addTradeForm` (line 1238). CALL SITE: inside tradeJournalPanel (the VStack starting line 944), insert `lossLimitBanner` on a NEW line between the header HStack's closing `}` (line 973) and the `if let health = journal.systemHealth {` block (line 975). This renders the breaker ABOVE the system-health verdict and ABOVE `if showAddTrade { addTradeForm }` (line 983). VERIFIED: it MUST stay OUTSIDE the `if s.closed > 0` realized-stats block (line 987) so a multi-day loss streak still shows on a zero-closed-today period. All symbols confirmed in-scope: `journal` is @ObservedObject StockSageJournalStore.shared at line 40 exposing `journal.trades: [TradeRecord]`; `sizerAccount`("10000")/`sizerRiskPct`("1") are @AppStorage at lines 68-69; `StockSageInput.positiveAmount` exists; engine `StockSageLossLimit.evaluate(closedTrades:policy:now:)`, `LossLimitPolicy`, `LossLimitState.{status,haltReason,caveat,dailyRealized,weeklyRealized,lossRun}` all in-target; DS.Palette.danger/.warningSoft, DS.Space.md/.sm, DS.Radius.card, mvFont8/9 all exist.

**code:** // Add to MarketsView. Account/risk default to 10_000 / 1% when fields blank.
private var lossLimitPolicy: LossLimitPolicy {
    let acct = StockSageInput.positiveAmount(sizerAccount) ?? 10_000
    let riskPct = (Double(sizerRiskPct).flatMap { $0 > 0 ? $0 : nil }) ?? 1.0
    let oneR = acct * (riskPct / 100)
    return LossLimitPolicy(
        maxDailyLoss:  oneR * 3,
        maxWeeklyLoss: oneR * 6,
        maxDailyLossR: 3,
        maxWeeklyLossR: 6,
        standDownLossRun: 3,
        warnFraction: 0.70)
}

@ViewBuilder private var lossLimitBanner: some View {
    let state = StockSageLossLimit.evaluate(
        closedTrades: journal.trades,   // engine filters to closedAt != nil internally
        policy: lossLimitPolicy,
        now: Date())
    switch state.status {
    case .ok:
        EmptyView()
    case .halted:
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: "hand.raised.fill")
                    .font(.system(size: 15, weight: .bold)).foregroundStyle(.white)
                Text("STOP TRADING").font(.system(size: 13, weight: .heavy))
                    .foregroundStyle(.white).tracking(0.5)
                Spacer()
            }
            if let reason = state.haltReason {
                Text(reason).font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white).fixedSize(horizontal: false, vertical: true)
            }
            Text(String(format: "Today %+.0f \u{00B7} this week %+.0f realized \u{00B7} %d-loss run.",
                        state.dailyRealized, state.weeklyRealized, state.lossRun))
                .font(.system(size: mvFont9, weight: .medium))
                .foregroundStyle(.white.opacity(0.9))
            Text(state.caveat).font(.system(size: mvFont8))
                .foregroundStyle(.white.opacity(0.78)).fixedSize(horizontal: false, vertical: true)
        }
        .padding(DS.Space.md).frame(maxWidth: .infinity, alignment: .leading)
        .background(DS.Palette.danger.opacity(0.85),
                    in: RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                    .stroke(DS.Palette.danger, lineWidth: 1.5))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Stop trading. \(state.haltReason ?? ""). \(state.caveat)")
    case .warn:
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 11)).foregroundStyle(DS.Palette.warningSoft)
            VStack(alignment: .leading, spacing: 2) {
                Text("Approaching your loss limit").font(.system(size: 11, weight: .bold))
                    .foregroundStyle(DS.Palette.warningSoft)
                Text(String(format: "Today %+.0f \u{00B7} week %+.0f \u{00B7} %d-loss run \u{2014} ease off and size down.",
                            state.dailyRealized, state.weeklyRealized, state.lossRun))
                    .font(.caption2).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(DS.Space.sm).frame(maxWidth: .infinity, alignment: .leading)
        .background(DS.Palette.warningSoft.opacity(0.10),
                    in: RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous))
        .accessibilityLabel("Approaching loss limit. Loss run \(state.lossRun). Ease off and size down.")
    }
}

// CALL SITE inside tradeJournalPanel, after the header HStack's closing `}` (line 973),
// before `if let health = journal.systemHealth {` (line 975):
//
//            }   // end header HStack (line 973)
//
//            lossLimitBanner   // STOP-TRADING / approaching-limit circuit breaker
//
//            if let health = journal.systemHealth {   // existing line 975

**verify:** (1) Build green: xcodebuild -scheme "Salehman AI" -destination 'platform=macOS' -configuration Debug CODE_SIGNING_ALLOWED=NO build 2>&1 | tee /tmp/salehman_build.log | tail -25 expects ** BUILD SUCCEEDED **. No project.pbxproj edit (LossLimitPolicy/LossLimitState/StockSageLossLimit and journal.trades are all in-target). (2) Tests stay green: xcodebuild test ... -only-testing:"Salehman AITests" (StockSageTests already covers engine correctness). (3) run-salehman-ai QA capture of Markets > Portfolio: a journal with 3 consecutive recent closed losers (closedAt within today UTC) -> red STOP TRADING banner at the TOP of the Trade journal card above system-health, showing haltReason + caveat; 2 losers (>= 70% of standDownLossRun=3) -> amber 'Approaching your loss limit'; winning/flat record -> no banner (EmptyView). Confirm a streak spanning multiple days still renders on a zero-closed-today period (proves placement is outside the `if s.closed > 0` block). (4) Append a dated DEVELOPMENT_LOG.md entry.

### ⬜ #2 — Replace the ad-hoc 'Notional exceeds account' string with a real StockSageLeverage verdict (liq move% + liq price + loss multiplier)
**surface:** /Users/saleh/Desktop/Salehman AI/Salehman AI/Views/MarketsView.swift

**placement:** Inside positionSizerPanel(_ idea:) (lines 2586-2624), in the success branch `if let acct = Double(sizerAccount), let rp = Double(sizerRiskPct), let ps = StockSagePositionSizer.size(...)` (opens lines 2599-2600). EDIT 1 at line 2601: replace `let leveraged = ps.pctOfAccount > 100` with the engine call so `lev` is available to both the `% acct` metric color (line 2606-2607, unchanged because `leveraged` stays a Bool) and the warning row. EDIT 2: replace the `if leveraged { Text("\u{26A0} Notional exceeds ...") }` block at lines 2613-2616 with the verdict-driven block. VERIFIED in-scope: `acct`, `entry` (line 2588), `ps.notional`, `ps.pctOfAccount`, helper `ideaMetric(_:_:color:)` (line 3032), mvFont9, DS.Palette.danger/.warningSoft. Engine `StockSageLeverage.assess(account:notional:entry:)` returns optional `LeverageRisk` exposing `.liquidationMovePct/.liquidationPrice/.drawdownMultiplier/.canLoseMoreThanAccount/.verdict` and static `.caveat` — all confirmed.

**code:** // EDIT 1 — line 2601, replace the boolean with the engine assessment:
let lev = StockSageLeverage.assess(account: acct, notional: ps.notional, entry: entry)
let leveraged = (lev?.canLoseMoreThanAccount ?? false) || ps.pctOfAccount > 100
// `leveraged` still drives the `% acct` metric color at line 2606-2607 — that call site is unchanged.
// lev is nil only if account/notional <= 0, impossible past the `if let acct ...` guard + a real position;
// the `?? false` keeps it total and preserves parity with the old > 100% gate.

// EDIT 2 — replace the warning block at lines 2613-2616 with:
if let lev, leveraged {
    HStack(spacing: 16) {
        ideaMetric("Liq. move", String(format: "%.1f%%", lev.liquidationMovePct), color: DS.Palette.danger)
        if lev.liquidationPrice > 0 {
            ideaMetric("Liq. price", String(format: "$%.2f", lev.liquidationPrice), color: DS.Palette.danger)
        }
        ideaMetric("Loss \u{00D7}", String(format: "%.1f\u{00D7}", lev.drawdownMultiplier))
        Spacer(minLength: 0)
    }
    Text("\u{26A0}\u{FE0E} " + lev.verdict)
        .font(.system(size: mvFont9)).foregroundStyle(DS.Palette.warningSoft).fixedSize(horizontal: false, vertical: true)
    Text(StockSageLeverage.caveat)
        .font(.system(size: mvFont9)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
}

**verify:** (1) Build green: xcodebuild ... build 2>&1 | tee /tmp/salehman_build.log | tail -25 expects ** BUILD SUCCEEDED **. Uses only in-scope values (acct, ps.notional, entry) + existing helpers — no new imports/state. (2) Engine math sanity (one-off or unit test against StockSageLeverage, no UI): notional = 2*account (200%, leverage 2.0) -> liquidationMovePct 50.0, liquidationPrice entry*0.5, drawdownMultiplier 2.0, canLoseMoreThanAccount true; notional == account (100%, ps.pctOfAccount == 100, old > 100 gate OFF) -> leverage 1.0, canLoseMoreThanAccount false, `leveraged` stays false (block hides at exactly 100%, parity with old threshold). liquidationPrice > 0 guard only hides 'Liq. price' when leverage <= 1 (price 0), which can't co-occur with leveraged==true, so all three metrics render for any real margin case. (3) Append a dated DEVELOPMENT_LOG.md entry and regenerate SOURCE_BUNDLE.md via `bash tools/bundle_source.sh`.

### ⬜ #3 — Render the 'a stop is not a fill' gap-risk table on the sized-trade surface
**surface:** /Users/saleh/Desktop/Salehman AI/Salehman AI/Views/MarketsView.swift

**placement:** Add a `gapRiskTable(side:entry:stop:shares:account:)` @ViewBuilder as a new private helper on MarketsView, e.g. directly ABOVE positionSizerPanel (before line 2586). CALL SITE: inside positionSizerPanel, in the `if let acct ... let rp ... let ps = StockSagePositionSizer.size(...)` block, immediately AFTER the leverage warning block's closing brace and BEFORE the `} else {` at line 2617 — i.e. between line 2616 and line 2617 — so it shares the panel card background (.padding(10).background at lines 2621-2622). Do NOT put it in ideaDetailSheet directly and do NOT put it after the positionSizerPanel(idea) call site at line 2956 (sized shares are private to the sizer block). VERIFIED in-scope at call site: `idea` (panel arg), `entry`(line 2588), `stop`(line 2587), `acct`, `ps.shares`(Int — convert with Double(ps.shares)). CORRECTION (load-bearing): TradeAdvice.Action has NO `.strongSell` case — it is only {strongBuy, buy, hold, avoid, reduce, sell}. The spec's `idea.advice.action == .strongSell` would NOT COMPILE. Side must derive from `.sell || .reduce` ONLY (mirroring the verified bearish test at line 1313: `idea.advice.action == .sell || idea.advice.action == .reduce`). Engine `StockSageGapRisk.worstCase(side:entry:stop:shares:accountEquity:)` returns `[GapRiskScenario]` (4 default gaps), each with `.verdict`, `.exceedsAccount`, `.caveat == StockSageGapRisk.caveat`; the caveat is identical across rows so render it ONCE.

**code:** // New @ViewBuilder helper on MarketsView (place above positionSizerPanel, before line 2586):
@ViewBuilder private func gapRiskTable(side: TradeSide, entry: Double, stop: Double,
                                       shares: Int, account: Double) -> some View {
    let scenarios = StockSageGapRisk.worstCase(side: side, entry: entry, stop: stop,
                                               shares: Double(shares), accountEquity: account)
    if !scenarios.isEmpty {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: "arrow.down.forward.and.arrow.up.backward.circle")
                    .font(.system(size: 11)).foregroundStyle(DS.Palette.warningSoft)
                Text("A stop is not a fill")
                    .font(.system(size: 11, weight: .semibold)).foregroundStyle(.white)
                Spacer()
            }
            ForEach(scenarios.indices, id: \.self) { i in
                let s = scenarios[i]
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: s.exceedsAccount ? "exclamationmark.octagon.fill"
                                                       : "exclamationmark.triangle")
                        .font(.system(size: mvFont9))
                        .foregroundStyle(s.exceedsAccount ? DS.Palette.danger : DS.Palette.warningSoft)
                        .frame(width: 11)
                    Text(s.verdict)
                        .font(.system(size: mvFont9))
                        .foregroundStyle(s.exceedsAccount ? DS.Palette.danger : DS.Palette.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            // The engine caveat is identical across rows — print it ONCE.
            Text(StockSageGapRisk.caveat)
                .font(.system(size: mvFont9)).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Gap risk: a stop is a trigger, not a guaranteed fill. "
            + scenarios.map { $0.verdict }.joined(separator: " "))
    }
}

// CALL SITE inside positionSizerPanel, between line 2616 and the `} else {` at line 2617.
// CORRECTED side derivation — .strongSell does NOT exist; use .sell || .reduce only:
let gapSide: TradeSide = (idea.advice.action == .sell
                          || idea.advice.action == .reduce) ? .short : .long
gapRiskTable(side: gapSide, entry: entry, stop: stop, shares: ps.shares, account: acct)

**verify:** (1) Build green: xcodebuild ... build 2>&1 | tee /tmp/salehman_build.log | tail -25 expects ** BUILD SUCCEEDED **. (2) Engine contract: StockSageGapRisk.worstCase returns 4 GapRiskScenario (gaps 0.05/0.08/0.20/0.35), each exposing .verdict (String) and .exceedsAccount (Bool); view renders one row per scenario.verdict plus the engine caveat exactly once. ps.shares is Int — converted via Double(ps.shares). (3) Visual via run-salehman-ai: open the idea detail sheet for a buy idea with a stop set, enter Acct $ and Risk %, confirm the 4-row table appears under the position-size numbers with the worst row (35% gap / exceedsAccount) flagged in danger color. (4) Append a dated DEVELOPMENT_LOG.md entry.

### ⬜ #4 — Caveat-reachability test: pin Leverage/GapRisk/LossLimit caveats to a pure helper the position-sizer panel renders
**surface:** /Users/saleh/Desktop/Salehman AI/Salehman AITests/StockSageRiskPanelCaveatTests.swift (new test) + /Users/saleh/Desktop/Salehman AI/Salehman AI/StockSage/StockSageRiskPanel.swift (new pure extraction, does not exist yet) wired into /Users/saleh/Desktop/Salehman AI/Salehman AI/Views/MarketsView.swift

**placement:** This is a follow-up to ranks 1-3 and should land AFTER them: it makes the three caveats reachable from a rendered Markets view through a pure function and pins them with a test. Add enum StockSageRiskPanel with `nonisolated static func lines(leveraged: Bool) -> [String]` to a new StockSage/StockSageRiskPanel.swift (auto-compiles, same flavor as StockSageTradePlan). In positionSizerPanel(_:), render those lines via a ForEach (the leverage caveat already shows from rank 2; this helper additionally surfaces StockSageGapRisk.caveat and StockSageLossLimit.caveat as a single source of truth so the panel can't drift from the engines). Test lands in Salehman AITests/ next to StockSageHonestyGuardTests.swift. VERIFIED markers (each appears exactly once in its engine): leverageMark = "multiply your loss and your risk of ruin" (StockSageLeverage.caveat), gapMark = "A stop is a trigger, not a guaranteed fill" (StockSageGapRisk.caveat), lossLimitMark = "behavioral brake, not a probability edge" (StockSageLossLimit.caveat). NOTE: if rank 3 already renders StockSageGapRisk.caveat in gapRiskTable and rank 1 renders StockSageLossLimit.caveat in lossLimitBanner, those caveats are already reachable on screen; this extraction still adds value as a regression anchor and is the codebase-idiomatic 'pin the pure text the view renders' shape (precedent: StockSageTradePlan.text + StockSageTradePlanTests).

**code:** // ----- (A) NEW Salehman AI/StockSage/StockSageRiskPanel.swift
import Foundation

enum StockSageRiskPanel {
    /// Honesty lines for the position-sizer panel. `leveraged` mirrors the flag
    /// MarketsView computes at line 2601. Leverage + gap caveats are always present
    /// (a stop is never a guaranteed fill); the loss-limit brake caveat too.
    nonisolated static func lines(leveraged: Bool) -> [String] {
        var out: [String] = []
        if leveraged { out.append(StockSageLeverage.caveat) }
        out.append(StockSageGapRisk.caveat)
        out.append(StockSageLossLimit.caveat)
        return out
    }
}

// ----- wire into Views/MarketsView.swift positionSizerPanel(_:): render the helper
// (place after the leverage verdict block from rank 2, still inside the success branch):
//     ForEach(StockSageRiskPanel.lines(leveraged: leveraged), id: \.self) { line in
//         Text(line)
//             .font(.system(size: mvFont9))
//             .foregroundStyle(leveraged ? DS.Palette.warningSoft : .secondary)
//             .fixedSize(horizontal: false, vertical: true)
//     }

// ----- (B) NEW Salehman AITests/StockSageRiskPanelCaveatTests.swift
import Testing
import Foundation
@testable import Salehman_AI

struct StockSageRiskPanelCaveatTests {
    private let leverageMark  = "multiply your loss and your risk of ruin"
    private let gapMark       = "A stop is a trigger, not a guaranteed fill"
    private let lossLimitMark = "behavioral brake, not a probability edge"

    @Test func leveragedPanelSurfacesAllThreeCaveats() {
        let lines = StockSageRiskPanel.lines(leveraged: true)
        let joined = lines.joined(separator: "\n")
        #expect(joined.contains(leverageMark))
        #expect(joined.contains(gapMark))
        #expect(joined.contains(lossLimitMark))
        #expect(lines.contains(StockSageLeverage.caveat))
        #expect(lines.contains(StockSageGapRisk.caveat))
        #expect(lines.contains(StockSageLossLimit.caveat))
    }

    @Test func cashPanelStillKeepsGapAndLossLimitHonesty() {
        let lines = StockSageRiskPanel.lines(leveraged: false)
        let joined = lines.joined(separator: "\n")
        #expect(joined.contains(gapMark))
        #expect(joined.contains(lossLimitMark))
        #expect(!joined.contains(leverageMark))
    }

    @Test func markersStayAnchoredToTheEngineCaveats() {
        #expect(StockSageLeverage.caveat.contains(leverageMark))
        #expect(StockSageGapRisk.caveat.contains(gapMark))
        #expect(StockSageLossLimit.caveat.contains(lossLimitMark))
    }
}

**verify:** xcodebuild test -scheme "Salehman AI" -destination 'platform=macOS' -configuration Debug CODE_SIGNING_ALLOWED=NO -only-testing:"Salehman AITests/StockSageRiskPanelCaveatTests" 2>&1 | tee /tmp/salehman_build.log | tail -25 expects ** TEST SUCCEEDED **. To prove the test bites, delete one .caveat append from StockSageRiskPanel.lines and confirm the matching #expect fails. New .swift files under the app/test dirs auto-compile (no project.pbxproj edit). Then run the full -only-testing:"Salehman AITests" suite to leave green, and append a dated DEVELOPMENT_LOG.md entry.
