# Tax / all-in real-cost roadmap (ww4x2gfcz, 2026-06-22)

7 items — what the owner actually KEEPS (itemized friction + financing + crypto taker + optional after-tax). evaluate() stays byte-for-byte; all additive. RE-VERIFY vs source.

### ⬜ #1 — AllInCost — itemized per-share round-trip friction (spread + slippage + commission + financing + taker)
**mechanism:** New pure struct in the EXISTING Salehman AI/StockSage/StockSageNetEdge.swift, added alongside CostAssumption (lines 35-40) WITHOUT touching evaluate() (lines 56-88) or its 9 green tests (StockSageNetEdgeTests.swift lines 10-77). Today evaluate collapses everything into one scalar `cost = max(0,spreadBps+slippageBps)/1e4*entry + max(0,commissionPerShare)` (line 64) — no financing, no crypto-taker, and the caller can't see which leg dominates. AllInCost itemizes the round trip in PRICE units/share. Spread/slippage bps stay round-trip by convention (crossed twice, already baked into the bps label). Financing = `entry * max(0,annualFinancingRate) * max(0,holdDays)/365`, ZERO for a same-day long (holdDays 0); it is the shorts/overnight leg, fed from holdDays or TradeRecord.daysHeld(asOf:) (Journal lines 63-65). Taker fee is the GE-2% analog (mirrors StockSageGEFlip.sellTax, GEFlip lines 58-61): equities/FX/index charge NO notional tax (`takerFeeCost==0`), crypto venues charge ~10-30bps/side on BOTH fills → `entry*(takerFeeBps+takerFeeBps)/1e4`. allInCost is a NEW nonisolated static helper; dominantLeg names the largest leg for the UI 'what's eating the edge' line. This is the foundation every other money-honesty spec composes through, so it ships first.

**signature:** struct AllInCost: Sendable, Equatable {
  let spreadCost: Double      // price/share, round-trip
  let slippageCost: Double    // price/share, round-trip
  let commissionCost: Double  // price/share, round-trip (commissionPerShare is already round-trip)
  let financingCost: Double   // shorts/overnight only; 0 for same-day long
  let takerFeeCost: Double    // crypto taker, both fills (GE-2% analog); 0 for stocks/FX/index
  nonisolated var total: Double { spreadCost + slippageCost + commissionCost + financingCost + takerFeeCost }
  nonisolated var dominantLeg: String  // name of the largest leg
}
extension StockSageNetEdge {
  nonisolated static func allInCost(entry: Double, spreadBps: Double = 0, slippageBps: Double = 0,
                                    commissionPerShare: Double = 0, takerFeeBps: Double = 0,
                                    annualFinancingRate: Double = 0, holdDays: Double = 0,
                                    isShort: Bool = false) -> AllInCost
}

**test:** In StockSageNetEdgeTests.swift add (python-equivalent arithmetic, deterministic, 1e-9 tol): (1) allInCostSumsEveryLeg — entry 100, spread 8bps, slip 5bps, comm $0.04, taker/financing 0 → spreadCost 0.08, slippageCost 0.05, commissionCost 0.04, total 0.17, dominantLeg=='spread'. (2) financingOnlyChargesShortsAndHolds — same-day long (holdDays 0) → financingCost==0; 10-day short, 6% annual, entry 100 → financingCost == 100*0.06*10/365 ≈ 0.16438, total strictly > the same long. (3) cryptoTakerFeeIsTheGEAnalog — entry 50000, takerFeeBps 15 both fills → takerFeeCost == 50000*30/1e4 == 150; an equity with takerFeeBps 0 → takerFeeCost==0. (4) dominantLegNamesTheBiggestFriction — thin crypto scalp where takerFeeCost>spreadCost → dominantLeg=='takerFee'. All numbers reproduce in plain Python.

**caveat:** Keep evaluate(...) byte-for-byte so the 9 existing NetEdge tests plus MarketsView/Backtester/ExpectedValue callers stay green — allInCost is purely additive. Every leg is a LABELED ESTIMATE, never a broker/exchange quote: financingRate and takerFeeBps are caller-supplied or asset-class estimates, NOT scraped numbers. A CASH long pays no financing — default annualFinancingRate 0 so nothing changes unless the caller opts in. Not advice; not tax/financial advice.

### ⬜ #2 — NetEdge surfaces net-of-EVERYTHING: per-share dollar EV + the displayed edge that survives all frictions
**mechanism:** Additive in StockSageNetEdge.swift. NetEdge (lines 11-30) already nets spread/slip/commission into netRR / netExpectancyR / breakEvenWinRate — but only in R units and only the partial scalar. Add an evaluateAllIn(entry:stop:target:cost:winProb:) that threads AllInCost.total (rank 1) as the `cost` into the SAME formulas (netReward = grossReward − cost (line 65); netRisk = grossRisk + cost (line 66); netRR = netReward/netRisk (line 68); p* = 1/(1+netRR) (line 83)), so financing/taker automatically RAISE the break-even bar — the single falsifiable bar the doc-comment on lines 17-21 already promises. Expose dollars: netDollarRewardPerShare = grossReward − allIn.total; netDollarEVPerShare(estWinProb) = pWin*netDollarReward − (1−pWin)*netDollarRisk; survivesAllCosts = netRR>0. A thin crypto scalp whose taker fee exceeds its target then reads as a NEGATIVE dollar EV even when the gross R:R looked fine. The optional `allIn: AllInCost?` is nil on the legacy path → identical to today.

**signature:** extension NetEdge {
  var allIn: AllInCost? { get }   // populated only by evaluateAllIn; nil ⇒ legacy path
  nonisolated var netDollarRewardPerShare: Double
  nonisolated func netDollarEVPerShare(estWinProb: Double) -> Double?
  nonisolated var survivesAllCosts: Bool { netRR > 0 }
}
extension StockSageNetEdge {
  nonisolated static func evaluateAllIn(entry: Double, stop: Double, target: Double,
                                        cost: AllInCost, winProb: Double? = nil) -> NetEdge?
}

**test:** StockSageNetEdgeTests.swift: (1) evaluateAllInMatchesScalarWhenNoFinancingOrTaker — feed an AllInCost built only from the wideSetupBarelyDentedByCosts spread/slip/comm (lines 24-35); assert netRR, costPerShare, netExpectancyR equal legacy evaluate() to 1e-9 (all-in is a strict superset). (2) financingFlipsAThinHoldNegative — a 1:1 setup net-positive same-day goes netRR<=0 once a 30-day short financing leg is added; netDollarEVPerShare(0.6) crosses from positive to <0. (3) displayedEdgeIsWhatSurvives — crypto scalp with taker>target → survivesAllCosts==false and netDollarRewardPerShare<0. (4) breakEvenRisesWithFinancing — adding financing strictly raises breakEvenWinRate.

**caveat:** Original evaluate() and its 9 tests stay untouched — evaluateAllIn is additive. Honesty in STRINGS not just math: netDollarEVPerShare is a per-share ESTIMATE that says nothing about taxes; verdict/help text must repeat 'estimate, not advice; not tax/financial advice' (mirror StockSageExpectedValue.caveat line 325 and StockSageJournal.caveat line 542) and never imply guaranteed/tax-free profit. Real-data-only: entry/stop/target come from live quotes; cost legs are labeled estimates.

### ⬜ #3 — CostAssumption gains financing + taker-fee defaults — labeled estimate ranges, never fabricated broker numbers
**mechanism:** Extend CostAssumption (StockSageNetEdge.swift lines 35-40) and defaultCosts(forSymbol:) (lines 44-51) with an estimated annualFinancingRate and crypto takerFeeBps plus a labeled estimateRange string, keeping roundTripBps UNCHANGED. Use publicly-typical ESTIMATE midpoints: US large-cap 13bps spread+slip / financing 0 default (margin ~6-9%/yr) / taker 0; intl 30bps / ~8-12% / taker 0; crypto 50bps spread+slip PLUS taker ~10-30bps/side (the real all-in driver) / funding ~5-30%/yr; FX 7bps / swap-carry (can be +/-) / taker 0; index 8bps / taker 0. This is the literal answer to 'do stocks have a GE-2% tax?': geAnalog is 0 for equities/FX/index, >0 for crypto via the taker fee. Add roundTripBpsAllIn = spreadBps+slippageBps+2*takerFeeBps so the crypto widening is visible.

**signature:** extension StockSageNetEdge {
  struct CostAssumption: Sendable, Equatable {
    let spreadBps: Double
    let slippageBps: Double
    let takerFeeBps: Double          // >0 only for crypto (GE-2% analog)
    let annualFinancingRate: Double  // est borrow/funding %/yr; can be 0
    let assetClass: String
    let estimateRange: String        // labeled estimate, e.g. 'crypto: 30-70bps spread+slip, 10-30bps taker/side, ~5-30%/yr funding — ESTIMATES'
    nonisolated var roundTripBps: Double { spreadBps + slippageBps }        // UNCHANGED
    nonisolated var roundTripBpsAllIn: Double { spreadBps + slippageBps + 2*takerFeeBps }
  }
  nonisolated static func defaultCosts(forSymbol: String) -> CostAssumption   // same signature
}

**test:** Extend defaultCostsScaleByAssetClass (StockSageNetEdgeTests.swift lines 54-69): BTC-USD has takerFeeBps>0 AND annualFinancingRate>0 AND roundTripBpsAllIn>roundTripBps; AAPL / EURUSD=X / ^GSPC have takerFeeBps==0 AND roundTripBpsAllIn==roundTripBps (the stocks-have-no-GE-tax assertion); every estimateRange is non-empty and lowercased-contains 'estimate' (honesty-floor, mirrors StockSageHonestyGuardTests). Existing numerics (crypto 50, FX 7, index 8, intl 30, US 13) at lines 56-63 and HonestyGuard lines 32-33 stay green.

**caveat:** Adding stored fields breaks the memberwise init — StockSageBacktesterTests.swift line 91 builds CostAssumption(spreadBps:slippageBps:assetClass:) directly, so add DEFAULTED params (takerFeeBps: Double = 0, annualFinancingRate: Double = 0, estimateRange: String = "") to keep that call site (and lines 185/192 if present) compiling unchanged. Ranges are estimates labeled as such — NOT quotes from any specific broker/exchange, and the string must say so.

### ⬜ #4 — AfterTaxEstimate value type + StockSageAfterTax.estimate(...) pure engine (labeled estimate, NOT tax advice)
**mechanism:** New file Salehman AI/StockSage/StockSageAfterTax.swift (auto-compiles, no pbxproj edit) — a pure, deterministic, nonisolated enum mirroring StockSageJournal/StockSageNetEdge style (no I/O, no actor, no Date.now in the math). Computes a LABELED after-tax realized-P&L ESTIMATE over CLOSED trades only (realizedProfit non-nil, Journal line 59), never opening positions. Classification: SHORT-TERM if held <= boundaryDays (default 365, a parameter so leap-year/statutory nuance is owner-tunable and testable), LONG-TERM if strictly more, measured openedAt→closedAt; compute via the floored whole-day rule consistent with TradeRecord.daysHeld (Journal lines 63-65) so a 365*86400-apart pair floors to 365 == short-term (inclusive). Netting: each closed trade contributes realizedProfit (sign-correct for long/short); net WITHIN each character bucket first, then a net loss in one bucket spills to reduce the other (mirrors real netting), all pure arithmetic. Tax applies ONLY to a positive net: estShortTermTax = max(0,netST)*ordinaryRate, estLongTermTax = max(0,netLT)*longTermRate; afterTaxRealized = grossRealized − estTotalTax where grossRealized = Σ realizedProfit. ordinaryRate REQUIRED; longTermRate defaults to ordinaryRate (HONEST — no silent preferential discount). Rates clamped to [0,1]. Returns nil with no closed-with-realized-profit trades (parity with every Journal fn returning nil on empty → UI shows nothing, not a fake $0). Does NOT recompute expectancy — R-multiples are pre-tax by definition and stay untouched.

**signature:** struct AfterTaxEstimate: Sendable, Equatable {
  let grossRealized: Double; let shortTermGross: Double; let longTermGross: Double
  let netShortTermTaxable: Double; let netLongTermTaxable: Double
  let ordinaryRate: Double; let longTermRate: Double
  let estimatedShortTermTax: Double; let estimatedLongTermTax: Double; let estimatedTotalTax: Double
  let afterTaxRealized: Double; let effectiveRate: Double?  // estTotalTax/grossRealized when grossRealized>0 else nil
  let closedCount: Int
  nonisolated var disclaimer: String { "Estimate only — NOT tax or financial advice. ...labeled estimate, not a guaranteed or tax-free result." }
}
enum StockSageAfterTax {
  nonisolated static func estimate(_ trades: [TradeRecord], ordinaryRate: Double,
                                   longTermRate: Double? = nil, boundaryDays: Int = 365) -> AfterTaxEstimate?
  nonisolated static let caveat: String  // contains 'NOT tax'
}

**test:** New Salehman AITests/StockSageAfterTaxTests.swift (Swift Testing, @testable import Salehman_AI, same seq/closedR/held helpers as StockSageJournalTests; build holding-period-sensitive records with explicit openedAt/closedAt boundaryDays*86_400 apart like the existing held() helper, lines 74-78). Cases: emptyReturnsNil (empty + only-open → nil); shortTermGainTaxedAsIncome (30d +$1000, rate 0.30 → tax 300, afterTax 700, effectiveRate≈0.30, netST 1000, netLT 0); longTermUsesSeparateRate (400d +$1000, 0.30/0.15 → tax 150, afterTax 850; nil LT rate falls back to 300 — proves no silent discount); lossesOffsetGains (+$1000 & −$400 ST at 0.25 → netST 600, tax 150, afterTax 450); netLossPaysNoTax (gross −$500 → tax 0, afterTax −500, effectiveRate nil); crossBucketSpill (ST −$200 spills onto LT +$500 → LT taxable 300, ST tax 0); ratesClamped (1.5→1.0, −0.2→0.0); boundaryIsInclusiveOfShortTerm (365d short, 366d long); disclaimerAlwaysPresent (.disclaimer contains 'NOT tax' & 'Estimate only', caveat contains 'NOT tax'); composesWithExpectancyUntouched (StockSageJournal.edge(trades).expectancyR unchanged). All dollar arithmetic reproduces in plain Python.

**caveat:** LABELED ESTIMATE, NOT tax/financial advice, NOT a guarantee of any profit tax-free or otherwise. Deliberately models only the simplest honest case and does NOT model: wash sales, the $3000/yr loss-vs-ordinary cap, carryforwards, specific-lot/FIFO, state/local/NIIT, foreign jurisdictions, or the exact statutory >1yr boundary (tunable day count). longTermRate==ordinaryRate default is intentional so the app never promises a preferential rate. Real-data-only: taxes nothing but the owner's own logged closed-trade dollars; returns nil rather than fabricating $0. Add its caveat to the StockSageHonestyGuardTests hedged-caveat sweep.

### ⬜ #5 — Owner-controlled enable/disable toggle + read-only store accessor (OPTIONAL, default OFF)
**mechanism:** Make the after-tax estimate opt-in and owner-disableable. In Salehman AI/App/AppSettings.swift add three persisted @Published fields following the exact `didSet { UserDefaults.standard.set(... forKey: Keys.x) }` pattern (lines 97-114) with matching Keys entries (the `nonisolated static let key = "set_..."` block at lines 184+) and load() defaults: afterTaxEstimateEnabled: Bool (DEFAULT false), afterTaxMarginalRate: Double (default 0.0 — a half-configured feature estimates ZERO tax, never invents one), afterTaxLongTermRate: Double (default -1 sentinel ⇒ use ordinary). Add nonisolated static mirrors that read UserDefaults directly (precedent: salehmanRefineEnabled line 289, isOfflineOnly line 300): afterTaxEnabled, afterTaxRate, afterTaxLongTermRate (-1 → nil). Expose a read-only computed accessor on @MainActor StockSageJournalStore parallel to its existing var yearlyPnL/var systemHealth (Journal lines 559-574) that returns nil when the toggle is OFF, so disabling makes the feature vanish everywhere with one switch, passing AppSettings.afterTaxRate (and LT rate / -1→nil) straight into StockSageAfterTax.estimate. No routing, no network, no cost — local arithmetic over already-stored trades.

**signature:** // AppSettings.swift (mirrors existing fields):
@Published var afterTaxEstimateEnabled: Bool { didSet { UserDefaults.standard.set(afterTaxEstimateEnabled, forKey: Keys.afterTaxEnabled) } }   // DEFAULT false
@Published var afterTaxMarginalRate: Double  { didSet { UserDefaults.standard.set(afterTaxMarginalRate, forKey: Keys.afterTaxRate) } }       // default 0.0
@Published var afterTaxLongTermRate: Double  { didSet { UserDefaults.standard.set(afterTaxLongTermRate, forKey: Keys.afterTaxLongRate) } }   // -1 ⇒ use ordinary
nonisolated static var afterTaxEnabled: Bool { UserDefaults.standard.bool(forKey: Keys.afterTaxEnabled) }
nonisolated static var afterTaxRate: Double { UserDefaults.standard.double(forKey: Keys.afterTaxRate) }
nonisolated static var afterTaxLongTermRate: Double? { let v = UserDefaults.standard.double(forKey: Keys.afterTaxLongRate); return v >= 0 ? v : nil }
// StockSageJournalStore (parity with var yearlyPnL):
var afterTaxEstimate: AfterTaxEstimate? { guard AppSettings.afterTaxEnabled else { return nil }; return StockSageAfterTax.estimate(trades, ordinaryRate: AppSettings.afterTaxRate, longTermRate: AppSettings.afterTaxLongTermRate) }

**test:** In StockSageAfterTaxTests.swift add store/settings cases that NEVER collide with other tests' UserDefaults keys (CLAUDE.md parallel-test rule): set/reset the afterTax keys explicitly and restore in defer. Cases: disabledReturnsNil (enabled key false → store.afterTaxEstimate nil even with closed trades); enabledRoundTrips (key true + 0.30 rate, one +$1000 30-day trade → afterTaxRealized 700); defaultRateIsZeroNotInvented (enabled true, rate unset 0.0 → estimatedTotalTax 0, afterTaxRealized==grossRealized); longTermSentinel (afterTaxLongTermRate -1 ⇒ engine receives nil ⇒ LT falls back to ordinary). Restore every touched key in defer.

**caveat:** Default OFF and default rate 0.0 are deliberate honesty guards: the view only appears and only subtracts tax once the owner explicitly opts in AND enters their own marginal rate — it never self-enables or guesses a rate, preserving the no-silent-behavior / local-first / real-data-only posture (zero network/paid calls). The SettingsView toggle+rate field and the labeled journal card are out of scope of this pure-logic spec, but the card MUST render the per-result disclaimer and caveat verbatim so the 'estimate only / NOT tax advice' floor is visible wherever a number shows. StockSageJournalStore is @MainActor — the store-accessor tests run on the main actor or via the nonisolated static mirrors.

### ⬜ #6 — Journal records realized all-in cost so net-of-everything EV is reconcilable against the owner's REAL fills
**mechanism:** Additive in StockSageJournal.swift. TradeRecord (lines 12-66) computes profit/R purely off entry/exit/shares, so realizedR (line 60) is GROSS — it silently overstates the edge vs the net-of-everything NetEdge the Markets tab shows (an honesty gap). Add optional `var realizedCost: Double?` (total $ frictions actually paid on the round trip) DEFAULTED nil so older persisted records still decode — same pattern as the `note` field (lines 27-38, with a defaulted init param and decode-safe optionality). Add netProfit(at:), netRealizedProfit, netRealizedR that subtract it, KEEPING the gross fields so the journal can show gross-vs-net side by side. Add StockSageJournal.netEdge(_:) parallel to edge() (lines 476-491) computed off netRealizedR. This closes the loop: Markets estimates net-of-everything forward (ranks 1-3), the journal measures it backward.

**signature:** // TradeRecord (additive + defaulted, Codable-safe for old data):
var realizedCost: Double?  // total round-trip $ frictions paid; nil = unknown/gross-only
nonisolated func netProfit(at price: Double) -> Double?
nonisolated var netRealizedProfit: Double? { get }
nonisolated var netRealizedR: Double? { get }  // (realizedProfit − realizedCost)/(riskPerShare·shares)
// enum StockSageJournal:
nonisolated static func netEdge(_ trades: [TradeRecord]) -> JournalEdge  // computed off netRealizedR

**test:** In StockSageJournalTests.swift (reuse closedR/held/seq helpers): (1) realizedCostDefaultsNilAndDecodesOldData — encode a TradeRecord WITHOUT realizedCost, decode succeeds, netRealizedR == realizedR (nil cost ⇒ net==gross). (2) netRealizedRSubtractsCosts — closed +2R winner, 100 shares, risk $1/sh, realizedCost $40 → realizedR 2.0 but netRealizedR == (200−40)/100 == 1.6. (3) netEdgeIsStrictlyBelowGrossWhenCostsPresent — winners with positive realizedCost → StockSageJournal.netEdge(trades).expectancyR < StockSageJournal.edge(trades).expectancyR. (4) StockSageJournalStore round-trips realizedCost through save/load (use a defer-restored key). Arithmetic reproduces in Python.

**caveat:** Gross realizedR MUST stay so the existing JournalTests / JournalCSVTests and every Journal rollup (stats, edge, bySide, monthlyPnL, yearlyPnL, systemHealth, kellyInputs — lines 249-540) keep their current numbers; netEdge/netRealizedR are additive views. Do NOT auto-fabricate realizedCost from estimates and present it as actually-paid cost — if the owner didn't enter real fills, any estimate-derived cost must be labeled an estimate. Record-keeping, NOT tax advice (reinforce StockSageJournal.caveat line 542).

### ⬜ #7 — StockSageHurdle — the active-trading hurdle engine (how often must this work to beat buy-and-hold)
**mechanism:** New file Salehman AI/StockSage/StockSageHurdle.swift (auto-compiles) — a pure, deterministic, nonisolated enum answering the owner's literal question: given all-in per-round-trip costs (+ optional taxes), the WIN RATE and TRADES-PER-YEAR a strategy needs JUST to match a broad-index buy-and-hold. It does NOT fetch data; indexAnnualReturn comes from the real ^GSPC history StockSageStore already fetches, and the active edge from a cost-aware NetEdge (ranks 1-2) or the journal's real realized R via StockSageJournal.edge / kellyInputs (lines 336-348). Identity, per-trade in R-units where one unit of risk = riskFraction of equity: netEdgeR = winRate·netRR − (1−winRate)·1 (uses NetEdge.netRR which already subtracts round-trip cost); perTradeReturn = riskFraction·netEdgeR; afterTaxPerTrade applies taxRate to POSITIVE expectancy only with a capped lossOffset (default = taxRate, never greater); requiredTradesPerYear = ln(1+indexAnnualReturn)/ln(1+afterTaxPerTrade) when afterTaxPerTrade>0 else nil with verdict .cannotBeatAtAnyFrequency (a losing after-cost-and-tax edge beats buy-and-hold at NO frequency). Composes breakEvenWinRate directly: requiredWinRate(toBeatIndexAt:) returns max(index-hurdle win rate, NetEdge.breakEvenWinRate (line 83)) so you must clear BOTH the cost floor and the index bar; the struct carries costBreakEvenWinRate and indexHurdleWinRate side by side. realityCheck compares the owner's OWN journal trades/yr + win rate against the requirement; Verdict ∈ {.beatsIndex,.belowIndexHurdle,.belowCostFloor,.cannotBeatAtAnyFrequency,.insufficientData}. The 'most active retail trading underperforms a low-cost index after costs and taxes' line is stated as a general base-rate finding, never a numeric prediction about this user.

**signature:** struct TradingHurdle: Sendable, Equatable {
  let indexAnnualReturn: Double; let riskFraction: Double
  let costBreakEvenWinRate: Double?; let netEdgeRPerTrade: Double; let afterTaxReturnPerTrade: Double
  let requiredTradesPerYear: Double?; let indexHurdleWinRate: Double?
  let verdict: Verdict; let realityCheck: String; let caveat: String
  enum Verdict: String, Sendable { case beatsIndex, belowIndexHurdle, belowCostFloor, cannotBeatAtAnyFrequency, insufficientData }
}
enum StockSageHurdle {
  nonisolated static let caveat: String  // contains 'estimate' and 'NOT tax'/'financial advice'
  nonisolated static func evaluate(netEdge: NetEdge, estWinProb: Double, indexAnnualReturn: Double,
                                   riskFraction: Double = 0.01, taxRate: Double = 0, lossOffset: Double? = nil,
                                   actualTradesPerYear: Double? = nil, actualWinRate: Double? = nil) -> TradingHurdle?
  nonisolated static func requiredWinRate(netRR: Double, indexAnnualReturn: Double, tradesPerYear: Double,
                                          riskFraction: Double = 0.01, taxRate: Double = 0,
                                          costBreakEvenWinRate: Double?) -> Double?
  nonisolated static func fromJournal(_ trades: [TradeRecord], netEdge: NetEdge, indexAnnualReturn: Double,
                                      riskFraction: Double = 0.01, taxRate: Double = 0) -> TradingHurdle?
}

**test:** New Salehman AITests/StockSageHurdleTests.swift (Swift Testing, matches StockSageNetEdgeTests style): (1) composesBreakEvenWinRate — NetEdge for entry100/stop90/target130 (netRR 3, breakEvenWinRate 0.25) → costBreakEvenWinRate==0.25±1e-9 and indexHurdleWinRate>=0.25. (2) losingAfterCostsBeatsNothing — after-cost expectancy <=0 → requiredTradesPerYear nil AND verdict .cannotBeatAtAnyFrequency. (3) higherIndexReturnRaisesTheBar — index 0.04 vs 0.12 → requiredTradesPerYear strictly larger for 0.12. (4) taxesRaiseTheHurdle — taxRate 0.0 vs 0.35 on the same positive edge → afterTaxReturnPerTrade strictly lower, requiredTradesPerYear strictly higher. (5) realityCheckIsHonestAndHedged — caveat lowercased contains 'estimate' AND ('not tax' OR 'financial advice'); realityCheck mentions costs/taxes; asserts NONE of {guarantee, guaranteed, risk-free, tax-free, sure}. (6) requiredWinRateClampsToCostFloor — at a tiny tradesPerYear the index bar alone implies a win rate below break-even → returns the cost-floor breakEvenWinRate. (7) degenerateNetEdgeIsNil / insufficientJournalIsNil — nil NetEdge → evaluate nil; fromJournal under StockSageJournal.kellyInputs minTrades (line 336) → nil / .insufficientData. Append StockSageHurdle.evaluate(...).caveat to the StockSageHonestyGuardTests sweep. All identities reproduce in Python (ln-based).

**caveat:** HONESTY FLOOR (test-enforced): (1) caveat/realityCheck contain none of {guarantee,guaranteed,risk-free,tax-free,sure thing} and a test asserts their absence. (2) Every number is a LABELED estimate — indexAnnualReturn/costs/taxRate/win rate are inputs the user/app supplies, never hardcoded fact. (3) NOT tax or financial advice, verbatim in caveat (mirrors StockSageJournal.caveat line 542). (4) Real-data-only — indexAnnualReturn from the real ^GSPC history StockSageStore fetches; active edge from the journal's REAL realizedR or a NetEdge from real entry/stop/target; never synthesizes a return series. (5) The 'most active trading underperforms' line is a general well-established base-rate finding, not a numeric claim or a prediction about this user. (6) Tax modeling is deliberately crude (single short-term rate, capped loss offset) and labeled as such. (7) Pure/deterministic and nonisolated so it unit-tests in the parallel suite without touching global UserDefaults. Append the dated entry to DEVELOPMENT_LOG.md after implementing (owner standing directive).
