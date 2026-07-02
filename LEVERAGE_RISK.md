# Leverage/gap honest-risk roadmap (wx04p42yj, 2026-06-22)

5 HONESTY engines — never understate loss (stop is a trigger not a fill; leverage loss-more-than-account). RE-VERIFY vs source.

### ⬜ #1 — StockSageGapRisk — the beyond-stop loss engine (a stop is a trigger, not a fill)
**mechanism:** New pure/deterministic `enum StockSageGapRisk` in Salehman AI/StockSage/StockSageGapRisk.swift. It generalizes FORWARD the only place in the codebase that already models adverse gap fills: StockSageBacktester.simulateExit line 169 `Swift.min(effStop, opens[j])` (backward-looking only). Given a real position (entry, stop, shares, side) and a gap-through percent, it computes the actual FILL price and how far the realized loss exceeds the planned 1R. LONG: an open gaps BELOW the stop to gapFill = stop·(1−gapPct); lossPerShare = entry−gapFill = riskPerShare + stop·gapPct where riskPerShare = |entry−stop| (identical to StockSagePositionSizer.riskPerShare). rMultiple = lossPerShare/riskPerShare = 1 + (stop·gapPct)/riskPerShare, ALWAYS >1R when gapPct>0 — that is the whole point. dollarsLost = shares·lossPerShare; beyondPlanDollars = dollarsLost − plannedRiskDollars. SHORT mirrors it (gaps UP: gapFill = stop·(1+gapPct)). Account math: accountLossPct = dollarsLost/accountEquity; with leverage L the position is larger but the per-share loss is unchanged — leverage enters via the equity it can wipe, so when accountLossPct>1 the surface sets exceedsAccount=true and NEVER clamps to 100%. A worstCase(...) helper sweeps canonical events (weekend 5%, earnings 8%, crypto-flash 20%, halt-reopen 35%) into an ascending-loss ladder — the UI's 'a stop is not a fill' honesty table. Ranked FIRST because it is the single largest honesty gap: every other engine (PositionSizer, PortfolioHeat, RiskOfRuin) explicitly assumes the stop fills AT its level, and this is the only forward-looking quantifier of what happens when it does not — pure survival-first truth, no new data feed.

**signature:** struct GapRiskScenario: Sendable, Equatable {
  let side: TradeSide
  let gapPct: Double
  let entry, stop, gapFillPrice, riskPerShare, lossPerShare, shares: Double
  let plannedRiskDollars, dollarsLost, beyondPlanDollars, rMultiple: Double
  let leverage, accountEquity, accountLossPct: Double
  nonisolated var blowsThroughStop: Bool { gapPct > 0 }
  nonisolated var exceedsAccount: Bool { accountLossPct > 1.0 }   // NEVER clamped
  nonisolated var verdict: String
  nonisolated var caveat: String
}
enum TradeSide: Sendable, Equatable { case long, short }
enum StockSageGapRisk {
  nonisolated static func scenario(side: TradeSide, entry: Double, stop: Double, shares: Double, gapPct: Double, accountEquity: Double, leverage: Double = 1.0) -> GapRiskScenario?
  nonisolated static func worstCase(side: TradeSide, entry: Double, stop: Double, shares: Double, accountEquity: Double, leverage: Double = 1.0, gaps: [Double] = [0.05, 0.08, 0.20, 0.35]) -> [GapRiskScenario]
  // Bridge from a real sized position. side is PASSED EXPLICITLY (PositionSize carries no side); long-only callers pass .long.
  nonisolated static func fromPosition(_ ps: PositionSize, side: TradeSide, stop: Double, entry: Double, accountEquity: Double, leverage: Double = 1.0, gapPct: Double) -> GapRiskScenario?
}

**test:** New StockSageGapRiskTests.swift (Swift Testing: `import Testing`/`import Foundation`/`@testable import Salehman_AI`, `@Test func`, `#expect`, matching StockSagePortfolioHeatTests). Python-verifiable arithmetic: (1) baseline gapPct=0 → gapFill==stop, rMultiple==1.0, beyondPlanDollars==0, blowsThroughStop==false (reduces to every other engine's optimistic assumption). (2) long: entry 100, stop 95, shares 100, gap 0.10 → gapFill=95·0.9=85.5, lossPerShare=14.5, rMultiple=14.5/5=2.9, dollarsLost=1450, planned=500, beyondPlanDollars=950 — each to 1e-9. (3) short mirror: entry 100, stop 105, gap 0.10 → gapFill=105·1.1=115.5, lossPerShare=15.5, rMultiple=15.5/5=3.1. (4) SACRED FLOOR: equity 1000, 5× leverage, gap 0.35 sized so accountLossPct>1 → exceedsAccount==true, accountLossPct NOT clamped at 1.0, verdict+caveat contain 'more than'. (5) worstCase: count==gaps.count, ascending by dollarsLost, last (0.35) costliest. (6) guards: entry==stop, shares<=0, equity<=0, gapPct<0, leverage<=0 all → nil (no divide-by-zero, no infinite size). (7) caveat non-empty and contains 'gap' so it folds into StockSageHonestyGuardTests' existing lowercased-substring sweep (its hedge list already includes "gap").

**caveat:** PERMANENT, embedded verbatim in GapRiskScenario.caveat and rendered as-is: 'A stop is a trigger, not a guaranteed fill. Overnight, weekend, earnings and 24/7-crypto gaps can open far THROUGH your stop — you exit at the gap price, not the stop, so the loss exceeds the planned 1R. With leverage or options the loss can be MORE than your entire account (you can owe the broker). This models ONE clean gap fill; a thin or halted book or a cascading liquidation can be worse still. Never a maximum, never a probability, never advice.' accountLossPct MUST NEVER be clamped at 100%. This engine is real-data-only: gapPct is a what-if the user/UI supplies, not a forecast; the canonical-event percentages are illustrative magnitudes, not predicted probabilities.

### ✅ DONE #2 — StockSageLeverage — the honest leverage/margin engine (liquidation distance + loss-more-than-account floor)
**mechanism:** New pure `enum StockSageLeverage` in Salehman AI/StockSage/StockSageLeverage.swift. It derives the three numbers leverage actually changes — none of which is upside — for a LONG: (1) liquidationMovePct = 100/L, the gross adverse % move that wipes the posted equity at L× (before fees/funding/maintenance, which only move it CLOSER); (2) liquidationPrice = entry·(1−1/L); (3) drawdownMultiplier = L, every unleveraged loss scaled by L. L is computed from real data as notional÷account — the SAME quantity StockSagePositionSizer.pctOfAccount/100 already produces and MarketsView line 2601 already flags as `ps.pctOfAccount > 100`. The result struct LeverageRisk is Sendable+Equatable with NON-OPTIONAL `caveat` and `canLoseMoreThanAccount: Bool` (true whenever L>1 OR the instrument is options/futures/fx/short) so no caller can render leverage without the loss-more-than-account truth attached. It composes with rank 1: feeding fraction·L into StockSageRiskOfRuin.scenario gives the honest leveraged ruin input. A `lossProfile(Instrument)` helper routes cashEquity/marginEquity/fxLeveraged/futures/longOption/shortOption through the SAME caveat machinery off the asset-class label the universe already carries — no new feed. Ranked second: it quantifies and names the 'can lose more than the account' floor that rank 1 relies on, and replaces the existing ad-hoc >100% string with tested math.

**signature:** struct LeverageRisk: Sendable, Equatable {
  let leverage, entry, liquidationMovePct, liquidationPrice, drawdownMultiplier: Double
  let canLoseMoreThanAccount: Bool
  let caveat: String
  nonisolated var verdict: String   // "3× — a 33.3% drop wipes you; losses hit 3× as hard. Can lose MORE than the account."
}
enum StockSageLeverage {
  nonisolated static let caveat = "Leverage and options are NOT free upside: they multiply your loss and your risk of ruin by the same factor they multiply gains. At L× a 100/L% adverse move wipes the position, and a gap/funding/slippage THROUGH that level — or any options/futures position — can lose MORE than the entire account, leaving you owing money. Fees, funding and maintenance margin only move liquidation CLOSER."
  nonisolated static func assess(account: Double, notional: Double, entry: Double, instrumentCanLoseMoreThanAccount: Bool = false) -> LeverageRisk?
  nonisolated static func assess(leverage L: Double, entry: Double, instrumentCanLoseMoreThanAccount: Bool = false) -> LeverageRisk?
  nonisolated static func from(_ ps: PositionSize, account: Double, entry: Double) -> LeverageRisk?
  enum Instrument: Sendable { case cashEquity, marginEquity, fxLeveraged, futures, longOption, shortOption }
  nonisolated static func lossProfile(_ i: Instrument) -> (canLoseMoreThanAccount: Bool, note: String)
}

**test:** New StockSageLeverageTests.swift (house idiom). Python-verifiable: (1) liquidationExactInverse: assess(leverage:3, entry:100) → liquidationMovePct==100.0/3 within 1e-9, liquidationPrice≈66.6666… within 1e-9, drawdownMultiplier==3. (2) tenXWipesAtTenPercent: assess(leverage:10, entry:50) → liquidationMovePct==10.0, liquidationPrice==45. (3) composesWithRiskOfRuin: StockSageRiskOfRuin.scenario(losses:3, fraction:0.05).survivalMultiple == pow(0.95,3) within 1e-12, proving 0.01·5 leveraged fraction is the honest ruin input. (4) honestyFloorPresent: every LeverageRisk has non-empty caveat AND canLoseMoreThanAccount==true whenever leverage>1; assert caveat contains 'more than'. (5) guardsBadInputs: nil for account<=0, notional<=0, entry<=0, and leverage<1 (no leverage to model). (6) chainsOffRealSizer: ps=StockSagePositionSizer.size(...); from(ps,account,entry).leverage == ps.pctOfAccount/100 within 1e-9. (7) lossProfileHonesty: cashEquity→false; marginEquity/fxLeveraged/futures/shortOption→true; longOption→false BUT its note says premium can go to ZERO; every note non-empty; can-lose-more notes contain 'more than the account'.

**caveat:** HARD HONESTY FLOOR, non-negotiable: leverage and options can lose MORE than the account — canLoseMoreThanAccount and caveat are non-optional fields so no UI path can drop them. liquidationMovePct=100/L is GROSS/best-case (before fees, funding, gaps, maintenance margin — all move liquidation CLOSER). LONG ONLY: shorts have unbounded loss and must NOT reuse 100/L. longOption is bounded at premium and must NEVER be lumped with shortOption (unbounded); conflating them either overstates the long-option or, far worse, understates the naked-short and breaches the floor. cashEquity is the only genuinely can't-owe-money case. Real-data-only: L from a real notional÷account or a real PositionSize, never a hypothetical 10× upside teaser.

### ⬜ #3 — Wire LeverageRisk + GapRisk into the position-size card, replacing the hand-written >100% string
2026-07-03: worstCase ladder added to the gap row's tooltip (single 20% headline row unchanged).
**mechanism:** In MarketsView.swift the position-size card (lines 2599–2619) already computes `let ps = StockSagePositionSizer.size(...)` and `let leveraged = ps.pctOfAccount > 100`, then renders a hand-written warning at line 2614. Replace that literal with `StockSageLeverage.from(ps, account: acct, entry: entry)` so the SAME card surfaces the quantified liquidation distance (100/L %), the drawdown multiplier (L×), and the engine-owned honesty caveat — measured, not narrated — making the warning a property of a tested engine that cannot drift from the math. When a real advisor stop is present, also render the gap ladder via StockSageGapRisk.worstCase(side:.long, …) so the user sees 'if it gaps X%, you lose $Y (Z·R)'. Net behavior change: instead of 'needs margin', the user now sees the exact adverse % move that wipes them AND the beyond-stop loss ladder. Ranked third: it is the consumer that turns ranks 1–2 into something the owner actually sees; gated behind those engines existing and green.

**signature:** // Replace the `if leveraged { Text("⚠︎ Notional exceeds…") }` branch (MarketsView ~2613):
if let lev = StockSageLeverage.from(ps, account: acct, entry: entry) {
    Text(lev.verdict).font(.system(size: mvFont9)).foregroundStyle(DS.Palette.danger)
    Text(lev.caveat).font(.system(size: mvFont9)).foregroundStyle(DS.Palette.warningSoft)
        .fixedSize(horizontal: false, vertical: true)
}
// plus, when a real stop exists, a compact gap ladder:
ForEach(StockSageGapRisk.worstCase(side: .long, entry: entry, stop: stop, shares: Double(ps.shares), accountEquity: acct), id: \.gapPct) { g in
    Text(g.verdict).font(.system(size: mvFont9)).foregroundStyle(DS.Palette.warningSoft)
}

**test:** Behavior is covered by ranks 1–2 engine tests (verdict/caveat strings are engine-owned and asserted there). Add ONE UI-adjacent assertion to the existing caveat-presence sweep (the test family behind tasks #71/#76, e.g. StockSageHonestyGuardTests): the leverage caveat string contains 'more than' AND ('wipes' OR 'liquidat'), and the gap caveat contains 'gap' AND ('not guaranteed' OR 'not a … fill'), so a future edit cannot strip the loss-more-than-account / stop-is-not-a-fill language from the rendered card.

**caveat:** Do NOT remove the existing tight-stop note ('Tight stops inflate share count; widen the stop or cut risk %') — it explains WHY notional exceeded the account and is complementary to the liquidation figure. Keep the danger color; leverage is a warning state, not informational. The card models a LONG only — pass side:.long explicitly; if a short path is ever added it must NOT reuse the 100/L or long gap formula. Per CLAUDE.md this UI change requires a dated DEVELOPMENT_LOG.md entry and a SOURCE_BUNDLE.md regen via tools/bundle_source.sh.

### ⬜ #4 — StockSageOptionsRisk — PROPOSED new engine: long single-leg, defined-risk-only, real-data-only (NOT YET BUILT)
**mechanism:** VERIFIED SCOPE FACT FIRST: I read the four named engines and ran `git grep -nE 'theta|strike|expir|premium|covered call|cash-secured|black.?scholes|greeks|delta hedg|naked|sell.?to.?open'` over Salehman AI/StockSage/ (excluding SOURCE_BUNDLE.md / *_ARCHIVE.md per CLAUDE.md) — it returns ZERO matches. There is NO options modeling anywhere: PositionSizer/PortfolioHeat/RiskOfRuin(=StockSageRiskOfRuin in StockSageDrawdownScenario.swift)/Backtester are equity/spot-only and size by the STOP. I therefore fabricate no existing options behavior. PROPOSAL (new file, not written this session): `enum StockSageOptionsRisk` matching the house pattern — Sendable+Equatable result, nonisolated static funcs, nil on any invalid input, hard non-optional caveat. It models ONLY the one honest case retail ignores: BUYING a single call/put held to expiry, sized by the premium actually paid. Encoded facts: (1) MAX LOSS = 100% of premium (premium·100·contracts + fees) and the buyer USUALLY loses because theta bleeds extrinsic value to zero; (2) defined-risk ONLY if you never roll/average-down/sell-to-open, so the API exposes NO such helper at all; (3) breakeven INCLUDES premium + commission (call: strike+premium+fee/share, NOT the strike). Real-data-only arithmetic facts (max loss, breakeven, intrinsic-at-expiry) — invents NO implied volatility, NO Black-Scholes fair value, NO probability-of-profit. Ranked fourth: it is net-new (no existing surface to make honest) and gated behind owner review/build/test; ranks 1–3 harden code that already ships.

**signature:** struct OptionsRiskEstimate: Sendable, Equatable {
  enum Kind: String, Sendable { case call, put }
  let kind: Kind
  let contracts: Int
  let strike, premiumPerShare, underlyingPrice, feePerContract: Double
  let maxLossDollars: Double          // (premiumPerShare*100 + feePerContract)*contracts — the WHOLE bet
  let breakevenPrice: Double          // call: strike+premium+fee/sh; put: strike−premium−fee/sh
  let intrinsicAtExpiryPerShare: Double // max(0, ±(underlying−strike))
  nonisolated var isWorthlessAtExpiryNow: Bool { intrinsicAtExpiryPerShare <= 0 }
  nonisolated var pctOfPremiumKeptIfExpiredNow: Double
}
enum StockSageOptionsRisk {
  nonisolated static func estimate(kind: OptionsRiskEstimate.Kind, contracts: Int, strike: Double, premiumPerShare: Double, underlyingPrice: Double, feePerContract: Double = 0) -> OptionsRiskEstimate?
  nonisolated static func summaryLine(_ e: OptionsRiskEstimate) -> String
  nonisolated static let caveat = "Buying an option: your MAX loss is 100% of the premium (+ fees) and the buyer USUALLY loses — theta bleeds extrinsic value to zero by expiry, so you need the move big enough AND fast enough. Breakeven is strike ± premium ± fees, not the strike. Defined-risk ONLY if you never roll, average-down, or sell to open — selling/uncovered legs can lose FAR MORE than the premium, even more than your whole account. Real numbers in = real arithmetic out; NOT a fair-value model and NEVER implies the trade is cheap, likely, or easy money."
}

**test:** New OptionsRiskTests.swift (house idiom). Python-verifiable: (1) maxLossIsWholePremiumPlusFees: estimate(.call, contracts:2, strike:100, premiumPerShare:3.50, underlyingPrice:98, feePerContract:0.65) → maxLossDollars == (3.50*100+0.65)*2 == 701.30 within 1e-6. (2) callBreakevenIncludesPremiumAndFees: strike 100 + 3.50 + 0.0065/sh → 103.5065, asserted in (103.5,103.52), NOT 100. (3) otmWorthZeroAtExpiry: call strike 100 underlying 98 → intrinsicAtExpiryPerShare==0, isWorthlessAtExpiryNow==true, pctOfPremiumKeptIfExpiredNow==0. (4) invalidInputsReturnNil: contracts 0, strike −5, premium 0, fee −1 each → nil (no fake 0). (5) summaryNeverImpliesEasyMoney: lowercased summary contains none of ['easy','guaranteed','income',"can't lose",'sure thing','free money'] AND contains 'max loss'+'breakeven'+'theta'. (6) caveatStatesCanLoseMore: caveat (lowercased) contains 'max loss','theta','roll','sell' and ('far more' OR 'more than'). Folds into the app-wide caveat sweep.

**caveat:** HONESTY FLOOR PRESERVED: models ONLY long, defined-risk, held-to-expiry single legs; the caveat EXPLICITLY states selling/rolling/averaging-down can lose FAR MORE than the premium — even more than the whole account. It deliberately has NO API for sell-to-open, naked legs, spreads, or rolling, so it can never imply those are safe or bounded. longOption is bounded at premium and must NEVER be conflated with the unbounded naked short. Real-data-only: arithmetic on prices the user/chain supplies, inventing NO IV, NO Black-Scholes fair value, NO probability-of-profit (doing so would imply we can predict the move). This is a PROPOSAL — it does not exist yet and must be reviewed/built/tested; building it requires a dated DEVELOPMENT_LOG.md entry and a SOURCE_BUNDLE.md regen per CLAUDE.md.

### ⬜ #5 — PROPOSED options honesty copy bank + extend the caveat sweep — ONLY if rank 4 is built
**mechanism:** To match how every StockSage surface ships honesty (StockSageGlossary.swift's MoneyVelocityTerm + MoneyVelocityCopy, whose every UI string a test asserts is hedged), an options card adds a parallel OptionsRiskTerm enum and an OptionsRiskCopy bank whose every string is provably caveated. The existing caveat-presence sweep (tasks #71/#76) is EXTENDED to include the options bank, so CI fails if anyone ships an un-hedged options string. No paid API and no auto-mode spend: option quotes, if ever fetched, come from the same real quote feed as equities; until then the user types the premium they actually paid. Ranked last because it is pure presentation contingent on rank 4 existing — lowest survival value, highest dependency.

**signature:** enum OptionsRiskTerm: String, CaseIterable, Sendable { case maxLoss = "Max loss", breakeven = "Breakeven", theta = "Theta decay", definedRisk = "Defined risk" }
enum OptionsRiskCopy {
  nonisolated static let maxLoss = "100% of the premium you paid (+ fees). That is the whole bet."
  nonisolated static let breakeven = "Strike ± premium ± fees — you need the move PAST this just to break even."
  nonisolated static let theta = "Every day, extrinsic value bleeds toward $0 at expiry. Time is against the buyer."
  nonisolated static let definedRisk = "Defined only if you NEVER roll, average-down, or sell to open. Selling can lose far more than the premium."
  nonisolated static let all: [String] = [maxLoss, breakeven, theta, definedRisk]
}

**test:** In the extended sweep: everyOptionsCopyStringIsHedged: for each s in OptionsRiskCopy.all, lowercased contains none of ['guaranteed','easy','income','sure',"can't lose",'will profit']; AND OptionsRiskCopy.all contains at least one string with 'far more' OR 'never roll' (the dangerous-path warning must be present somewhere in the bank). Mirrors the existing MoneyVelocityCopy sweep exactly so the structural guard generalizes.

**caveat:** PROPOSAL contingent on rank 4 being built; does not exist yet. Included only to show the surface inherits the same enforced-honesty pattern (every string provably hedged, dangerous paths named) the rest of StockSage uses. Per CLAUDE.md, building it requires a dated DEVELOPMENT_LOG.md entry and a SOURCE_BUNDLE.md regen via tools/bundle_source.sh — neither done because nothing was built this session. Must never soften 'selling can lose far more than the premium' into upside-only language.
