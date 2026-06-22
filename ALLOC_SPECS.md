# Capital allocator specs (wc6fxpt1i, 2026-06-22)

3 vetted items (survived rate-limiting). RE-VERIFY each claim vs REAL source; engine-first + python-verified test.

### ⬜ #1 — StockSageCapitalAllocator — half-Kelly, edge-weighted, heat-capped allocation across a board of ideas
**signature:** NEW FILE: `/Users/saleh/Desktop/Salehman AI/Salehman AI/StockSage/StockSageCapitalAllocator.swift` (auto-compiles under Salehman AI/StockSage/ — no project.pbxproj edit; verified no existing file with this name). Pure, deterministic, `nonisolated`, Chat A (Markets/StockSage) lane.

```swift
import Foundation

struct AllocatedPosition: Sendable, Equatable, Identifiable {
    let symbol: String
    let riskFraction: Double   // per-trade account fraction at risk after scaling (0…1)
    let shares: Int            // whole shares (floored — never over-risk)
    let dollarsAtRisk: Double  // shares × |entry−stop|
    let notional: Double       // shares × entry
    let halfKelly: Double      // raw half-Kelly fraction pre-scale (transparency)
    let evR: Double            // expected value in R that earned the weight
    var id: String { symbol }
}

struct CapitalAllocation: Sendable, Equatable {
    let positions: [AllocatedPosition]   // desc by riskFraction, tie-break asc symbol
    let totalHeat: Double                // Σ dollarsAtRisk ÷ account (0…1) — ≤ maxHeat
    let requestedHeat: Double            // Σ raw half-Kelly of fundable ideas (pre-scale)
    let scaleApplied: Double             // ≤1 when the cap bound; 1 otherwise
    let account: Double
    let maxHeat: Double
    let caveat: String
}

enum StockSageCapitalAllocator {
    nonisolated static let caveat = "Allocations are HALF-Kelly off ESTIMATED edges (conviction is not a probability); total open heat is hard-capped. Whole shares floor each position, so realized heat is ≤ the cap. Sizes the loss at each stop — a correlated gap can lose more."
    nonisolated static func allocate(ideas: [StockSageIdea], account: Double, maxHeat: Double = 0.08) -> CapitalAllocation
}
```

**mechanics:** PURPOSE: turn a board of ranked ideas into a concrete, heat-bounded 'how much in each' plan by COMPOSING three pre-existing tested engines — zero new financial math.

GUARDS: `guard account > 0, maxHeat > 0` else empty plan (positions [], totalHeat 0, requestedHeat 0, scaleApplied 1, echo account/maxHeat, caveat). Empty ideas → same empty plan. `let cap = min(max(0, maxHeat), 1)`.

STEP 1 (fundability + raw weight, one pass): fund an idea only if ALL hold — action ∈ {.strongBuy,.buy}; stop=advice.stopPrice and target=advice.targetPrice non-nil and idea.price>0; `StockSageExpectedValue.ev(conviction: advice.conviction, entry: idea.price, stop: stop, target: target)` non-nil AND evR>0. Compute payoff=|target−price|/|price−stop| (==evResult.rewardR), winProb=evResult.winProbEstimate, `k=StockSageKelly.compute(winRate: winProb, payoffRatio: payoff, accountSize: account)`, rawFraction=k.halfKelly. CRITICAL (verified StockSageKelly.swift:46-47): k.halfKelly is ALREADY an account fraction in [0,0.5] (fStar/2) — DO NOT divide by account; do NOT use k.dollarsToRisk. Skip if rawFraction<=0.

STEP 2 (edge weighting): the per-idea target IS rawFraction — half-Kelly already encodes the edge (bigger W·R ⇒ bigger fStar ⇒ bigger half), so no separate EV multiplier (avoids double-counting EV). State this in a comment.

STEP 3 (heat scaling): requestedHeat=Σ rawFraction; scaleApplied = requestedHeat>cap ? cap/requestedHeat : 1; scaledFraction = rawFraction*scaleApplied. Uniform proportional scaling preserves the edge ranking and pins Σ pre-floor heat to min(requestedHeat, cap).

STEP 4 (whole-share floor via Sizer — only place dollars/shares are produced): `guard let ps = StockSagePositionSizer.size(account: account, riskFraction: scaledFraction, entry: price, stop: stop), ps.shares > 0 else { drop }`. Sizer floors with .rounded(.down) (verified StockSagePositionSizer.swift:28) ⇒ realized dollarsAtRisk ≤ scaledFraction·account, so floored total heat ≤ scaled (capped) heat. Build AllocatedPosition(halfKelly: rawFraction, riskFraction: scaledFraction, …).

STEP 5 (assemble): totalHeat = Σ position.dollarsAtRisk / account. Sort desc by riskFraction, tie-break asc symbol (deterministic). Return with maxHeat: cap.

INVARIANTS the tests pin: (a) totalHeat ≤ maxHeat+1e-9 ALWAYS; (b) requestedHeat≤cap ⇒ scaleApplied==1 and riskFraction==halfKelly; (c) no funded position has evR≤0, non-buy action, or missing stop/target; (d) all shares whole and >0; (e) ordering edge-respecting.

DEDUP NOTE: this is the merged survivor of the two board-level allocator specs (the EV-weighted-correlation variant collided on filename and produced only dollar weights with no share sizing/heat-cap; correlation-merge is intentionally left out of the buildable core to keep allocation deterministic and the heat invariant exact).

**mechanics_composes:** StockSageExpectedValue.ev(conviction:entry:stop:target:)->ExpectedValue? (StockSageExpectedValue.swift:69-75; evR=p·rewardR−(1−p), winProbEstimate band 0.35–0.58 verified line 63-64, rewardR=reward/risk line 72) gates fundability + feeds Kelly inputs. StockSageKelly.compute(winRate:payoffRatio:accountSize:)->KellyResult (StockSageKelly.swift:41-64; .halfKelly=fStar/2∈[0,0.5], fStar clamped [0,1] line 46) supplies the per-idea target FRACTION. StockSagePositionSizer.size(account:riskFraction:entry:stop:)->PositionSize? (StockSagePositionSizer.swift:22-36; floors shares line 28, nil on entry==stop/non-positive line 24-26) converts each scaled fraction to whole shares+$. Heat semantics mirror StockSagePortfolioHeat.compute (StockSagePortfolioHeat.swift:37-42: Σ shares·|entry−stop|÷account). Model: StockSageIdea (StockSageStore.swift:6-14: .symbol/.price/.advice), TradeAdvice (StockSageAdvisor.swift:10-47: .action/.conviction/.stopPrice?/.targetPrice?). All composed engines are pure nonisolated enums, individually unit-tested.

**test:** NEW FILE: `/Users/saleh/Desktop/Salehman AI/Salehman AITests/StockSageCapitalAllocatorTests.swift`. swift-testing (import Testing/Foundation/@testable import Salehman_AI), `struct …Tests`, `@Test`, `#expect`, tolerance 1e-9/1e-6. No shared global state. Helper (verified against the real TradeAdvice init at StockSageExpectedValueTests.swift:39): `func idea(_ s:String, price:Double, stop:Double, target:Double, conviction:Double, action:TradeAdvice.Action = .buy)->StockSageIdea { StockSageIdea(symbol:s, market:"TEST", price:price, advice:TradeAdvice(action:action, conviction:conviction, regime:.bullTrend, rationale:[], stopPrice:stop, targetPrice:target, suggestedWeight:0, caveat:"x"), spark:[]) }`.

PYTHON-VERIFIED PINS (winProb(0.5)=0.465; halfKelly=0.1433333333; 143 shares; $1430 at risk — all reproduced in python this session):
1. capBindsTotalHeatNeverExceedsMax(): three conviction-0.9 buys (AAA 100/90/160, BBB 50/45/80, CCC 200/180/320 — each halfKelly≈0.2416, Σ≈0.7247>0.08), account 100_000, maxHeat 0.08 → #expect(a.totalHeat<=0.08+1e-9); #expect(a.scaleApplied<1.0); #expect(a.positions.allSatisfy{$0.shares>0}); #expect(abs(a.maxHeat-0.08)<1e-9).
2. halfKellyIsFractionNotDividedByAccount() [critical regression]: single buy conviction 0.5, 100/90/130 (payoff 3, p 0.465), account 10_000, maxHeat 0.50. #expect(a.positions.count==1); #expect(abs(a.positions[0].halfKelly-0.1433333333)<1e-6); #expect(abs(a.positions[0].riskFraction-0.1433333333)<1e-6); #expect(abs(a.scaleApplied-1.0)<1e-9); #expect(a.positions[0].shares==143); #expect(abs(a.positions[0].dollarsAtRisk-1430)<1e-9).
3. wholeShareFloorKeepsRealizedHeatUnderScaledTarget(): reuse case-2 → #expect(a.positions[0].dollarsAtRisk <= a.positions[0].riskFraction*10_000+1e-9); #expect(a.totalHeat<=0.1433333333+1e-9).
4. unscaledWhenRequestedHeatBelowCap(): single weak-edge buy with halfKelly<0.08, maxHeat 0.08 → #expect(abs(a.scaleApplied-1.0)<1e-9); #expect(abs(a.positions[0].riskFraction-a.positions[0].halfKelly)<1e-9).
5. excludesNonBuyAndNonPositiveEV(): mix .sell, .hold, a buy with target below entry (ev nil/≤0), one VALID buy → #expect(a.positions.map(\.symbol)==["VALID"]); #expect(a.positions.allSatisfy{$0.evR>0}).
6. emptyAndDegenerateInputsYieldEmptyPlan(): #expect(CA.allocate(ideas:[],account:10_000).positions.isEmpty); #expect(CA.allocate(ideas:[idea("A",price:100,stop:90,target:130,conviction:0.5)],account:0).positions.isEmpty); let z=CA.allocate(ideas:[…],account:10_000,maxHeat:0); #expect(z.positions.isEmpty); #expect(z.totalHeat==0).
7. positionsSortedByRiskFractionDescThenSymbol(): two buys, loose cap → #expect(a.positions.first!.riskFraction>=a.positions.last!.riskFraction).
8. carriesHonestyCaveat(): #expect(a.caveat.lowercased().contains("kelly")); #expect(a.caveat.lowercased().contains("heat")||a.caveat.lowercased().contains("cap")).

BUILD/TEST (canonical, token-disciplined): `xcodebuild -scheme "Salehman AI" -destination 'platform=macOS' -configuration Debug CODE_SIGNING_ALLOWED=NO build 2>&1 | tee /tmp/salehman_build.log | tail -25` then `xcodebuild test … -only-testing:"Salehman AITests" 2>&1 | tee /tmp/salehman_test.log | tail -25`. Leave green, append a dated DEVELOPMENT_LOG.md entry, regenerate SOURCE_BUNDLE.md via `bash tools/bundle_source.sh`.

### ⬜ #2 — StockSageMarginalAllocator — should I add THIS idea to the live book? (correlation gate → heat-headroom cap → size)
**signature:** NEW FILE: `/Users/saleh/Desktop/Salehman AI/Salehman AI/StockSage/StockSageMarginalAllocator.swift` (renamed from the spec's StockSageCapitalAllocator to avoid colliding with rank-1; auto-compiles, no pbxproj edit). Pure, deterministic, `nonisolated`, Chat A lane. Mirrors the StockSageTradeGate/PortfolioHeat/ClusterCheck primitive-enum style.

```swift
import Foundation

struct CapitalIdea: Sendable, Equatable {
    let symbol: String
    let entry: Double
    let stop: Double
    let candidateRiskFraction: Double   // desired per-trade risk, e.g. 0.01
}
struct MarginalAllocation: Sendable, Equatable {
    enum Decision: String, Sendable { case add="Add at full size"; case sizeDown="Add, but smaller — heat-capped"; case block="Don't add" }
    let decision: Decision
    let approvedRiskFraction: Double   // 0…candidateRiskFraction
    let suggestedShares: Int           // floored by the Sizer; 0 when blocked
    let dollarsAtRisk: Double          // approvedRiskFraction × account
    let currentHeatPct: Double         // book heat BEFORE the add
    let projectedHeatPct: Double       // book heat AFTER the add
    let headroomFraction: Double       // max(0, maxHeat − currentHeatPct)
    let cluster: ClusterCheck?         // passthrough; nil when not computable
    let heat: PortfolioHeat?           // passthrough; nil when account≤0
    let reason: String
    let caveat: String
}
enum StockSageMarginalAllocator {
    nonisolated static func suggestAdd(idea: CapitalIdea, openTrades: [(shares: Double, entry: Double, stop: Double)], holdings: [(symbol: String, returns: [Double])], candidateReturns: [Double], account: Double, maxHeat: Double = 0.10, corrThreshold: Double = 0.80) -> MarginalAllocation?
}
```
Returns nil ONLY when account<=0 (mirrors PortfolioHeat.compute returning nil there).

**mechanics:** PURE, deterministic, no money-spending defaults. Orthogonal to rank-1: that one allocates a FRESH account across a board; THIS one sizes ONE marginal add against an already-OPEN book.

1. GUARD: `guard account > 0 else { return nil }`. Treat candidateRiskFraction<=0 / entry<=0 / stop<=0 / entry==stop as a hard BLOCK (approvedRiskFraction 0, shares 0, reason 'Undefined risk (no usable stop) — can't size.') — NOT nil.
2. CURRENT HEAT: `let heat = StockSagePortfolioHeat.compute(openTrades:, accountSize: account)` (non-nil after guard); currentHeatPct = heat.heatPct (empty book → 0).
3. CORRELATION GATE: `let cluster = StockSageClusterCheck.check(candidate: idea.symbol, candidateReturns:, holdings:, threshold: corrThreshold)`. If cluster?.isConcentrating==true → DECISION .block, approved 0, shares 0, $0, projectedHeatPct=currentHeatPct; reason names cluster.highlyCorrelated.first (symbol+corr). cluster==nil (thin data) is NOT a block — gate passes, continue.
4. HEAT-HEADROOM CAP (only if not corr-blocked): headroomFraction=max(0, maxHeat−currentHeatPct); approvedRiskFraction=min(candidateRiskFraction, headroomFraction). headroom<=0 → .block (book at ceiling). approved<candidate → .sizeDown. else → .add (append diversifying cluster note when cluster!=nil && !isConcentrating).
5. SIZE: `let ps = StockSagePositionSizer.size(account: account, riskFraction: approvedRiskFraction, entry: idea.entry, stop: idea.stop)`; suggestedShares = ps?.shares ?? 0 (skip when approved 0).
6. DOLLARS/PROJECTED: dollarsAtRisk = approvedRiskFraction*account; projectedHeatPct = currentHeatPct + approvedRiskFraction (both fractions of the SAME account ⇒ additive). INVARIANT (pinned): non-block ⇒ projectedHeatPct ≤ maxHeat+1e-9.
7. CAVEAT (always): 'Heat assumes each stop fills AT its level — a correlated gap can lose more; correlation is backward-looking and rises toward 1 in crashes. Sizes the LOSS, not a profit.'

PRECEDENCE: correlation gate is checked BEFORE the heat cap and dominates — a concentrating add is blocked even with heat headroom. Percentages in strings via Int((x*100).rounded()).

**mechanics_composes:** StockSagePortfolioHeat.compute(openTrades:accountSize:)->PortfolioHeat? (StockSagePortfolioHeat.swift:37-42; nil only when accountSize≤0, empty→0%, .heatPct=dollarsAtRisk/accountSize line 15, .level cool<0.05/warm<0.10/hot≥0.10 line 19) for current book heat. StockSageClusterCheck.check(candidate:candidateReturns:holdings:threshold:)->ClusterCheck? (StockSageClusterCheck.swift:39-53; nil when candidateReturns.count<2 OR no comparable holdings — same symbol skipped case-insensitively line 43; .isConcentrating=!highlyCorrelated.isEmpty line 23) for the correlation gate; transitively uses StockSagePortfolioAnalytics.correlation (Pearson, common-tail aligned via suffix, clamped −1…1, line 136-148). StockSagePositionSizer.size (StockSagePositionSizer.swift:22-36, floors shares) converts the approved fraction to whole shares. All four are pure nonisolated enums — verified read this session.

**test:** NEW FILE: `/Users/saleh/Desktop/Salehman AI/Salehman AITests/StockSageMarginalAllocatorTests.swift`. swift-testing. Fixtures: `let cand=[0.01,-0.02,0.03,-0.01]; identical=cand; negated=cand.map{-$0}; func idea(_ rf:Double=0.01)->A.CapitalIdea{.init(symbol:"NEW",entry:100,stop:95,candidateRiskFraction:rf)}` (typealias A=StockSageMarginalAllocator).

PYTHON-VERIFIED PINS (book [(70,100,90)] → 700/10000=7% heat, headroom to 10%=3%; 10000·0.01/|100−95|=20 shares — reproduced this session):
1. blockedByCorrelation: holdings [("AAA",identical),("BBB",negated)], empty book, account 10_000 → r.decision==.block; approvedRiskFraction==0 && suggestedShares==0 && dollarsAtRisk==0; cluster?.isConcentrating==true; reason.contains("AAA"); projectedHeatPct==currentHeatPct.
2. headroomCapBindsSizeDown: idea(0.05), openTrades [(70,100,90)], holdings [], candidateReturns [], account 10_000 → abs(currentHeatPct-0.07)<1e-9; abs(headroomFraction-0.03)<1e-9; decision==.sizeDown; abs(approvedRiskFraction-0.03)<1e-9; abs(projectedHeatPct-0.10)<1e-9; projectedHeatPct<=0.10+1e-9; suggestedShares>0.
3. fullSizeWhenRoomAndUncorrelated: idea(0.01), empty book, holdings [("BBB",negated)], account 10_000 → decision==.add; abs(approvedRiskFraction-0.01)<1e-9; cluster?.isConcentrating==false; abs(projectedHeatPct-0.01)<1e-9; suggestedShares==20.
4. blockedWhenBookAtCeiling: openTrades [(120,100,90)] → 1200/10000=12% → idea(0.01) → decision==.block; headroomFraction==0; approvedRiskFraction==0 && suggestedShares==0; reason.lowercased() contains "ceiling"||"heat".
5. correlationDominatesEvenWithHeadroom: empty book (full 10% headroom) + holdings [("AAA",identical)] → decision==.block; headroomFraction==0.10; approvedRiskFraction==0 (corr beats headroom).
6. nilOnlyWithoutAccount: A.suggestAdd(idea:idea(),openTrades:[],holdings:[],candidateReturns:cand,account:0)==nil.
7. undefinedRiskBlocksNotNil: CapitalIdea(symbol:"X",entry:100,stop:100,candidateRiskFraction:0.01) → decision==.block && suggestedShares==0 (NOT nil).
8. caveatAlwaysPresent: case-3 result → !caveat.isEmpty; caveat.lowercased().contains("gap"); caveat.lowercased().contains("backward-looking").

BUILD/TEST: canonical `xcodebuild … build` then `xcodebuild test … -only-testing:"Salehman AITests"`, both `2>&1 | tee /tmp/salehman_build.log | tail -25`. Leave green; append DEVELOPMENT_LOG.md entry; regenerate SOURCE_BUNDLE.md.

### ⬜ #3 — StockSageRiskParity.rebalanceByRiskParity — reweight the whole book toward inverse-vol equal-risk targets with a no-trade band (risk-neutral, net-zero)
**signature:** EXTEND existing file `/Users/saleh/Desktop/Salehman AI/Salehman AI/StockSage/StockSageRiskParity.swift` (add a static func to the existing enum — no new file, no new types; reuses RiskParityHolding + RebalancePlan). Chat A lane; this is the same-file extension so claim it in COORDINATION.md if the other session is touching StockSageRiskParity.

```swift
extension StockSageRiskParity {
    /// Reweight the WHOLE book toward inverse-volatility equal-risk targets with a no-trade
    /// band. Pure reweight of EXISTING invested dollars — adds NO net risk (no new cash, no
    /// leverage; target weights sum to 1 over the valid set, so buy/sell deltas net to ~0).
    /// nil when nothing is sizeable (no holding with positive value AND positive vol).
    nonisolated static func rebalanceByRiskParity(_ holdings: [RiskParityHolding], band: Double = 0.03) -> RebalancePlan?
}
```
Band default 0.03 here is intentionally decoupled from StockSageRebalance.plan's own 0.02 default (passed through explicitly).

**mechanics:** Three deterministic steps, each delegating to verified already-tested code — no new math.

1. TARGETS: `let tgts = targets(holdings)` (existing StockSageRiskParity.targets) — drops vol≤0 / value<0, computes inverse-vol weights wᵢ=(1/volᵢ)/Σ(1/vol) over the valid set (Σ targetWeight=1; weightᵢ·volᵢ equal across holdings = equal risk contribution), currentWeight over the SAME valid dollars so deltas are comparable. `guard !tgts.isEmpty else { return nil }`.
2. MAP to plan's input shape over the SAME valid set (load-bearing for net-zero): `let valid = holdings.filter { $0.volatility>0 && $0.currentValue>=0 }`; `let holdingTuples = valid.map { (symbol:$0.symbol, value:$0.currentValue) }`; `let targetDict = Dictionary(uniqueKeysWithValues: tgts.map { ($0.symbol, $0.targetWeight) })`. Mismatching the two sets would break net-to-zero.
3. PLAN: `return StockSageRebalance.plan(holdings: holdingTuples, targets: targetDict, band: band)` — normalizes targets (already sum 1 ⇒ no-op), emits a RebalanceTrade only where |drift|>band, deltaValue=drift·total, biggest-first.

WHY NET-ZERO (the tested invariant): target and current weights are normalized over the SAME valid dollar base ⇒ Σ drift = Σ(tw−cw) = 1−1 = 0 ⇒ Σ deltaValue = 0: every dollar bought is funded by a dollar sold; no new cash, no leverage, gross exposure unchanged — only risk is redistributed. The band can only SUPPRESS trades, never add exposure (so band-suppression net-zero is asserted only on the full reweight, band 0).

EDGE CASES (handled by composed engines): empty/all-invalid → targets() empty → nil. Single valid holding → 100%→100% → empty trades → isBalanced==true (NOT nil; the book exists). vol≤0/negative value silently dropped. band≥1 → always balanced.

HONESTY: inherits the composed engines' limits — ignores costs/taxes/min-lot, vol is a point estimate, and equal-MEASURED risk ≠ equal-REALIZED risk in a correlation shock. Doc comment carries the cash-sleeve caveat (hold cash OUTSIDE the book; this only reweights risk assets) — backed by StockSageRiskParity.swift header lines 8-10 and MARKETS_INTELLIGENCE_RESEARCH.md §6.

**mechanics_composes:** StockSageRiskParity.targets(_:) (StockSageRiskParity.swift:67-80) — inverse-vol target weights normalized to 1 over the positive-vol valid set, currentWeight over the same dollar base so deltas net to ~0. + StockSageRebalance.plan(holdings:targets:band:) (StockSageRebalance.swift:31-55) — normalizes targets, applies the no-trade band, emits per-symbol buy/sell trades sized in account currency biggest-first, nil if total≤0 or targets sum≤0. Types: RiskParityHolding/RiskParityTarget (StockSageRiskParity.swift:13/21), RebalancePlan/RebalanceTrade (StockSageRebalance.swift:12/21). Cash-sleeve caveat backed by StockSageCorrelationCluster.largest over CorrelationMatrix (StockSageCorrelationCluster.swift:27, threshold 0.70) which detects the ≥0.70-correlated cliques where naive risk parity is fragile. All verified read this session and already unit-tested (StockSageRiskParityTests.swift / StockSageRebalanceTests.swift).

**test:** ADD to `/Users/saleh/Desktop/Salehman AI/Salehman AITests/StockSageRiskParityTests.swift` (or a new StockSageRebalanceByRiskParityTests.swift; same @testable import, swift-testing @Test/#expect). PYTHON-VERIFIED: CALM vol0.10 / WILD vol0.40 → inverse-vol targets 0.80 / 0.20; current 0.5 each → CALM delta +0.30 → +$3000 (reproduced this session).
1. rebalanceByRiskParityAddsNoNetRisk (band 0): holdings [CALM 5000 vol0.10, WILD 5000 vol0.40] → plan!; abs(plan.totalValue-10_000)<1e-9; let net=plan.trades.reduce(0){$0+$1.deltaValue}; abs(net)<1e-6; let calm=plan.trades.first{$0.symbol=="CALM"}!; let wild=plan.trades.first{$0.symbol=="WILD"}!; abs(calm.targetWeight-0.8)<1e-9; abs(wild.targetWeight-0.2)<1e-9; calm.deltaValue>0 && calm.action=="Buy"; wild.deltaValue<0 && wild.action=="Sell"; abs(calm.deltaValue-3000)<1e-9.
2. noTradeBandSuppressesTinyDrift (band 0.03): [A 5100 vol0.20, B 4900 vol0.20] → target 50/50, current 51/49, drift 0.01<0.03 → plan!; plan.trades.isEmpty; plan.isBalanced.
3. emptyIsNilSingleIsBalanced: rebalanceByRiskParity([])==nil; rebalanceByRiskParity([RiskParityHolding(symbol:"BAD",currentValue:1000,volatility:0)])==nil; let solo=rebalanceByRiskParity([RiskParityHolding(symbol:"ONLY",currentValue:1000,volatility:0.25)])!; solo.isBalanced.
4. highCorrelationRegimeIsDetectableForCashSleeve: CorrelationMatrix(symbols:["A","B","C"], matrix:[[1,0.85,0.80],[0.85,1,0.82],[0.80,0.82,1]]); let cluster=StockSageCorrelationCluster.largest(m)!; cluster.symbols.count==3; cluster.minPairwise>=0.70; then rebalanceByRiskParity([A 3000,B 3000,C 4000, all vol0.20], band:0)! → net Σ deltaValue, abs(net)<1e-6 (still risk-neutral; cash sleeve lives outside this book).

RUN: `xcodebuild test -scheme "Salehman AI" -destination 'platform=macOS' -configuration Debug CODE_SIGNING_ALLOWED=NO -only-testing:"Salehman AITests" 2>&1 | tee /tmp/salehman_test.log | tail -25` → expect ** TEST SUCCEEDED **. Append DEVELOPMENT_LOG.md entry; regenerate SOURCE_BUNDLE.md.
