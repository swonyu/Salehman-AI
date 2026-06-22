# Ranking-quality specs (wny86u8yc, 2026-06-22)

5 vetted items (survived rate-limiting). RE-VERIFY each claim vs REAL source; engine-first + python-verified test.

### ⬜ #1 — Regime-gate the EV ranking: no BUY ranks #1 in crisis/bear, no SHORT-side in a bull
**signature:** Add ONE trailing, defaulted-nil parameter to the two public ranking entry points in Salehman AI/StockSage/StockSageExpectedValue.swift. Both keep byte-for-byte current behavior when regime is nil, so every existing caller and test compiles and passes unchanged:

  nonisolated static func rankByEV(_ ideas: [StockSageIdea], regime: MarketRegime? = nil) -> [StockSageIdea]
  nonisolated static func bestOpportunity(_ ideas: [StockSageIdea], regime: MarketRegime? = nil) -> (idea: StockSageIdea, ev: ExpectedValue)?

VERIFIED against source (read in full):
- MarketRegime (StockSageRegime.swift:17) is `struct MarketRegime: Sendable, Equatable` with `let state: State`; State cases are exactly `.trendingBull / .trendingBear / .ranging / .crisis`. Only `.state` is needed for the gate. Literal init for tests: `MarketRegime(state:riskScore:signals:sizingBias:caveat:)` (memberwise, all fields settable).
- TradeAdvice.Action (StockSageAdvisor.swift:11) cases are EXACTLY `.strongBuy, .buy, .hold, .avoid, .reduce, .sell`. There is NO `.short` and NO `.strongSell` on TradeAdvice — `.sell`/`.reduce` are the ONLY short-side actions in this engine. Do NOT invent a `.short` case.
- StockSageIdea (StockSageStore.swift:6): `let advice: TradeAdvice`, `let price: Double`, `let symbol: String`.
- bestOpportunity (line 152) already filters to `.buy || .strongBuy` only, so the crisis/bear BUY ban is enforced by returning nil.
- Existing private helpers/consts in scope: evRankKey(for:) (110), qualityAdjustedEVR(for:) (107), minConvictionToRank=0.40 (102), ev(for:) (132), and the established `-1000` sub-conviction demotion convention.
Call sites (MarketsView.swift:1962 rankByEV, :2186/:2253 + TodayView.swift:260 bestOpportunity) MAY later pass `regime:` once a regime value is available; out of scope here.

**mechanics:** Pure, deterministic suppression layer that runs ONLY when regime != nil; touches ranking KEYS and #1 eligibility only, never displayed EV (mirrors the file's existing "DISPLAYED EV stays raw" contract).

1) Side classifier (private, pure):
   enum RankSide { case buyFamily, sellFamily, neutral }
   nonisolated private static func side(_ idea: StockSageIdea) -> RankSide
     .buyFamily  ← .buy, .strongBuy ; .sellFamily ← .sell, .reduce ; .neutral ← .hold, .avoid

2) Regime ban predicate (private, pure) — is this side banned from rank #1 under this regime?
   nonisolated private static func bannedFromTopRank(_ s: RankSide, regime: MarketRegime.State) -> Bool {
       switch regime {
       case .crisis, .trendingBear: return s == .buyFamily    // no BUY ranks #1 in crisis/bear
       case .trendingBull:          return s == .sellFamily    // no SHORT (sell-family) ranks #1 in a bull
       case .ranging:               return false               // neutral regime gates nothing
       }
   }

3) rankByEV sorts on a regime-adjusted key that ADDITIVELY demotes a banned side by 1_000_000 — an order of magnitude past the existing -1000 conviction band — so a banned high-conviction idea always ranks below EVERY non-banned idea (incl. non-banned low-conviction ones), guaranteeing the #1 slot is never a banned side:
   nonisolated private static func regimeAdjustedEVRankKey(for idea: StockSageIdea, regime: MarketRegime?) -> Double? {
       guard let base = evRankKey(for: idea) else { return nil }   // nil-EV ideas still fall last, unchanged
       guard let r = regime else { return base }                   // nil regime → IDENTICAL to today
       return bannedFromTopRank(side(idea), regime: r.state) ? base - 1_000_000 : base
   }
   rankByEV's enumerated().sorted body is unchanged except it calls regimeAdjustedEVRankKey(for:regime:) instead of evRankKey(for:). The (x?,y?)/(_?,nil)/(nil,_?)/(nil,nil) switch arms and the .offset stable tiebreak are untouched, so nil-key ideas keep falling last in original order.

4) bestOpportunity gains ONE guard at the TOP, before the existing compactMap/max body:
   if let r = regime, bannedFromTopRank(.buyFamily, regime: r.state) { return nil }
   In bull/ranging buyFamily is not banned → identical to today. In crisis/bear it returns nil rather than crowning a buy as the single best bet.

INVARIANTS: regime==nil ⇒ regimeAdjustedEVRankKey returns exactly evRankKey and bestOpportunity hits no new guard ⇒ byte-identical output. Penalty is additive on the ranking key only; ev(for:)/qualityAdjustedEVR/displayed numbers never change. All new helpers are `nonisolated private static`, matching file convention — public surface unchanged. After implementing: regenerate SOURCE_BUNDLE.md via `bash tools/bundle_source.sh` and append a dated DEVELOPMENT_LOG.md entry (date · what · files · why · result), per CLAUDE.md.

**test:** Add to Salehman AITests/StockSageExpectedValueTests.swift (reuse `EV` typealias at line 9 and the private idea(_:action:conviction:stop:target:) factory at line 36, which already supports `action:`). Build regimes as literals:
  let bear   = MarketRegime(state: .trendingBear, riskScore: -0.5, signals: [], sizingBias: 0.5,  caveat: "x")
  let crisis = MarketRegime(state: .crisis,       riskScore: -0.9, signals: [], sizingBias: 0.25, caveat: "x")
  let bull   = MarketRegime(state: .trendingBull, riskScore: 0.6,  signals: [], sizingBias: 1.1,  caveat: "x")

@Test backwardCompatNilRegimeUnchanged: build several ideas; #expect EV.rankByEV(ideas).map(\.symbol) == EV.rankByEV(ideas, regime: nil).map(\.symbol); #expect EV.bestOpportunity(ideas)?.idea.symbol == EV.bestOpportunity(ideas, regime: nil)?.idea.symbol.
@Test noBuyRanksFirstInBear: let buy = idea("WIN", action: .buy, conviction: 0.9, stop: 90, target: 130); let sell = idea("DN", action: .sell, conviction: 0.8, stop: 110, target: 80). #expect EV.rankByEV([buy, sell], regime: bear).first?.symbol != "WIN". #expect EV.bestOpportunity([buy], regime: bear) == nil. #expect EV.bestOpportunity([buy], regime: crisis) == nil.
@Test noShortRanksFirstInBull: same two; #expect EV.rankByEV([buy, sell], regime: bull).first?.symbol == "WIN"; #expect EV.bestOpportunity([buy], regime: bull)?.idea.symbol == "WIN".
@Test rangingGatesNothing: mixed buy+sell set; #expect EV.rankByEV(set, regime: ranging).map(\.symbol) == EV.rankByEV(set).map(\.symbol).
@Test bannedHighConvictionRanksBelowNonBannedLowConviction: a banned-side high-conviction idea and a non-banned above-floor low-conviction idea; #expect the non-banned ranks first under the gating regime (proves 1_000_000 > 1000).

Run & leave green:
  xcodebuild test -scheme "Salehman AI" -destination 'platform=macOS' -configuration Debug CODE_SIGNING_ALLOWED=NO -only-testing:"Salehman AITests" 2>&1 | tee /tmp/salehman_build.log | tail -25
Verdict line must read ** TEST SUCCEEDED **; all 19 pre-existing EV tests must stay green unmodified.

### ⬜ #2 — Liquidity-gate the EV ranking: a thin name can't rank #1 or lead the fast lane
**signature:** Thread ONE optional, defaulted liquidity lookup through Salehman AI/StockSage/StockSageExpectedValue.swift. The default makes every existing call byte-identical.

At the top of `enum StockSageExpectedValue`:
  typealias LiquidityLookup = @Sendable (String) -> LiquidityProfile.Tier?
  nonisolated static let noLiquidity: LiquidityLookup = { _ in nil }

Append `liquidity: LiquidityLookup = noLiquidity` as the LAST parameter to exactly these five members (defaulted → no caller changes):
- rankByEV(_:liquidity:)
- rankByVelocity(_:holds:liquidity:)
- bestOpportunity(_:liquidity:)
- fastLane(_:holds:liquidity:)
- private evRankKey(for:liquidity:) and private velocityRankKey(for:holds:liquidity:)

VERIFIED: LiquidityProfile (StockSageLiquidity.swift:11) is `struct ... Sendable, Equatable`; enum Tier cases are exactly `thin/moderate/deep` (lines 13-15). Store holds `@Published private(set) var liquidity: [String: LiquidityProfile]` keyed UPPERCASE (StockSageStore.swift:521). qualityAdjustedEVR(for:) (line 107) is PUBLIC and read by summary()/bestOpportunity's .max and the parity test — its signature/body MUST stay unchanged; layer the discount in a NEW private helper instead:
  private nonisolated static func liquidityDiscount(_ t: LiquidityProfile.Tier?) -> Double {
      switch t { case .thin: return 0.5; case .moderate: return 0.9; case .deep, nil: return 1.0 } }
  private nonisolated static func rankEdge(for idea: StockSageIdea, liquidity: LiquidityLookup) -> Double? {
      qualityAdjustedEVR(for: idea).map { $0 * liquidityDiscount(liquidity(idea.symbol)) } }

**mechanics:** Three behaviors, all no-ops under the default lookup (returns nil → discount 1.0, `!= .thin` always true):

1) DISCOUNT before sorting. Rewrite the two private rank-key helpers to call rankEdge instead of qualityAdjustedEVR, keeping the existing sub-floor `- 1000`:
   evRankKey(for:liquidity:) = rankEdge(for:liquidity:).map { conviction >= minConvictionToRank ? $0 : $0 - 1000 }
   velocityRankKey(for:holds:liquidity:): guard let q = rankEdge(...), let hold = expectedHoldDays(...), hold>0; v = q/hold; return conviction>=floor ? v : v-1000.
   rankByEV/rankByVelocity/fastLane forward their `liquidity` arg into these keys; their .sorted bodies are otherwise unchanged. liquidityDiscount(nil)==1.0 ⇒ default path multiplies by 1 ⇒ identical keys ⇒ identical order ⇒ all existing tests pass byte-for-byte.

2) BAR thin from #1. In bestOpportunity's compactMap add `liquidity(idea.symbol) != .thin` alongside the conviction floor, and forward liquidity into the .max key (rankEdge for both operands). Default lookup returns nil (never == .thin) ⇒ guard always passes ⇒ unchanged.

3) THIN CAN'T LEAD THE FAST LANE — hard guarantee, not just a discount a 10:1 thin flyer could overcome. In fastLane's compactMap compute `let isThin = liquidity(idea.symbol) == .thin` and use key `isThin ? v - 1000 : v` (mirrors the conviction demotion). Keep this demotion LOCAL to fastLane (don't also put it in velocityRankKey) to avoid double-penalizing the board sort. Thin names stay VISIBLE in the lane but never first.

WHY discount AND hard-gate: the ×0.5/×0.9 discount handles the general "thin = worse fill = lower realistic edge" across the whole board ordering; the hard `!= .thin` (best bet) and `-1000` (fast-lane head) gates enforce the owner's invariant that the single #1 pick and the lane head are never names you structurally can't fill, no matter how juicy the raw EV. Discount alone could let a fantasy thin flyer still top #1.

CALLER WIRING (separate, optional follow-up — spec builds green without it): at MarketsView.swift:1962, :2186, :2253, :2356 and TodayView.swift:260 pass `liquidity: { store.liquidity[$0.uppercased()]?.tier }`. Until then the UI is unchanged. After implementing: regenerate SOURCE_BUNDLE.md and append a DEVELOPMENT_LOG.md entry per CLAUDE.md.

**test:** Existing 19 EV tests MUST stay green untouched (every call omits liquidity → noLiquidity default → byte-identical). Add a `thinLiquidityCannotRankFirstOrLeadFastLane` block to StockSageExpectedValueTests.swift using the idea(...) helper (line 36) and an inline lookup. PENNY is thin, others deep/crypto-deep:
  let look: EV.LiquidityLookup = { $0 == "PENNY" ? .thin : .deep }
  // 1. Thin name with HUGE raw EV (fantasy 9:1) barred from #1.
  let flyer = idea("PENNY", action: .strongBuy, conviction: 0.9, stop: 90, target: 190)
  let solid = idea("AAPL",  action: .buy,       conviction: 0.7, stop: 90, target: 120)
  #expect(EV.bestOpportunity([flyer, solid], liquidity: look)?.idea.symbol == "AAPL")  // thin barred
  #expect(EV.bestOpportunity([flyer, solid])?.idea.symbol == "PENNY")                  // default no-op
  // 2. Thin can't lead the fast lane (both crypto so both HAVE velocity).
  let thinC = idea("PENNY", conviction: 0.9, stop: 90, target: 190)
  let deepC = idea("BTC-USD", conviction: 0.9, stop: 90, target: 130)
  let lane = EV.fastLane([thinC, deepC], liquidity: { $0 == "PENNY" ? .thin : .deep })
  #expect(lane.first?.symbol == "BTC-USD")
  #expect(lane.contains { $0.symbol == "PENNY" })   // still shown, just not first
  // 3. Board discount sinks a thin name below an equal-edge deep one.
  let r = EV.rankByEV([thinC, deepC], liquidity: { $0 == "PENNY" ? .thin : .deep })
  #expect(r.map(\.symbol) == ["BTC-USD", "PENNY"])

Run: xcodebuild test -scheme "Salehman AI" -destination 'platform=macOS' -configuration Debug CODE_SIGNING_ALLOWED=NO -only-testing:"Salehman AITests" 2>&1 | tee /tmp/salehman_build.log | tail -25 → ** TEST SUCCEEDED **.

### ⬜ #3 — Three-tier EV/velocity partitioning: winners → no-EV → losers LAST (a confirmed loser never outranks a no-EV idea)
**signature:** No public signature changes. Both entry points keep their exact current signatures, plus an additive, defaulted-on knob (mirrors the holds: VelocityHoldDays pattern already in this file):
  nonisolated static func rankByEV(_ ideas: [StockSageIdea], losersLast: Bool = true) -> [StockSageIdea]
  nonisolated static func rankByVelocity(_ ideas: [StockSageIdea], holds: VelocityHoldDays = .defaults, losersLast: Bool = true) -> [StockSageIdea]
Default true makes losers-last the standing behavior; losersLast: false recovers the legacy two-way order. The only caller (MarketsView.swift:1962-1963) uses the two-/holds-arg forms and is unchanged.

VERIFIED: ExpectedValue.isPositive { evR > 0 } (line 16). ev(for:) (132) returns nil iff no stop/target. Current rankByEV (139) / rankByVelocity (120) sort a single Optional key where the comparator puts EVERY non-nil before EVERY nil (`case (_?, nil): return true`) — so a negative-EV idea (key ≈ -0.30, non-nil) ranks ABOVE a no-EV idea (nil → bottom). That is the bug: confirmed losers interleave ahead of no-EV names. StockSageIdea/TradeAdvice fields and existing private keys (evRankKey, velocityRankKey, qualityAdjustedEVR, minConvictionToRank=0.40) all confirmed present.

**mechanics:** Add a 3-state tier ordinal derived from RAW ev sign (not quality-adjusted), so the partition is honest about real edge while WITHIN-tier order stays on the existing keys (winner order byte-identical):
  private enum EVTier: Int { case positive = 0, none = 1, negative = 2 }
  private nonisolated static func evTier(for idea: StockSageIdea) -> EVTier {
      guard let e = ev(for: idea) else { return .none }      // nil iff no stop/target
      return e.isPositive ? .positive : .negative }           // evR == 0 → negative tier

Velocity must keep no-velocity (index/FX, no hold) DEAD LAST (the velocity tests pin that), so it gets a 4-way partition:
  private nonisolated static func velocityTier(for idea: StockSageIdea, holds: VelocityHoldDays) -> Int {
      guard velocityRankKey(for: idea, holds: holds) != nil else { return 3 }  // no velocity → last of all
      switch evTier(for: idea) { case .positive: return 0; case .none: return 1; case .negative: return 2 } }

Replace the two sort bodies: PRIMARY by tier ascending, then fall back to the EXISTING inner comparator so winner order is bit-identical. rankByEV body:
  ideas.enumerated().sorted { a, b in
      let ta = losersLast ? evTier(for: a.element).rawValue : 0
      let tb = losersLast ? evTier(for: b.element).rawValue : 0
      if ta != tb { return ta < tb }
      switch (evRankKey(for: a.element), evRankKey(for: b.element)) {   // UNCHANGED inner order + .offset stable tiebreak
      case let (x?, y?): return x == y ? a.offset < b.offset : x > y
      case (_?, nil): return true; case (nil, _?): return false; case (nil, nil): return a.offset < b.offset } }.map(\.element)
rankByVelocity is identical shape with evTier→velocityTier(for:holds:) and evRankKey→velocityRankKey(for:holds:). losersLast == false forces ta=tb=0 ⇒ degrades to exactly today's single-key sort.

WHY correct & stable: within the positive tier the secondary key is the existing quality-adjusted evRankKey (preserves the conviction-floor -1000 demotion and qualityWeight down-weighting bit-for-bit); the .offset tiebreak keeps the sort STABLE; tier is from RAW ev sign so a high-conviction loser and a junk loser both land in the negative tier and neither can sneak above a winner via the -1000 trick (which only moves things WITHIN the inner key). Update the two doc-comments to state the three-tier order. After implementing: regenerate SOURCE_BUNDLE.md and append a DEVELOPMENT_LOG.md entry per CLAUDE.md.

**test:** Add to StockSageExpectedValueTests.swift. The idea(...) helper already builds a negative-EV idea via conviction 0 / stop 90 / target 110 (evR -0.30), so no new fixtures needed.
@Test rankByEVPutsLosersLastAfterNoEV:
  let win  = idea("WIN",  conviction: 0.9, stop: 90, target: 130)   // EV 1.228 → positive
  let none = idea("NONE", conviction: 0.9, stop: nil, target: nil)  // no R:R → no-EV (middle)
  let lose = idea("LOSE", conviction: 0.0, stop: 90, target: 110)   // EV -0.30 → negative (LAST)
  let r = EV.rankByEV([lose, none, win]).map(\.symbol)
  #expect(r == ["WIN", "NONE", "LOSE"]); #expect(r.last == "LOSE")
@Test rankByVelocityKeepsLosersBeforeNoVelocity:
  let win = idea("BTC-USD", conviction:0.9, stop:90, target:130); let lose = idea("ETH-USD", conviction:0.0, stop:90, target:110); let idx = idea("^GSPC", conviction:0.9, stop:90, target:130)
  #expect(EV.rankByVelocity([idx, lose, win]).map(\.symbol) == ["BTC-USD", "ETH-USD", "^GSPC"])
@Test losersLastFalseRecoversLegacyOrder:
  let lose = idea("LOSE", conviction:0.0, stop:90, target:110); let none = idea("NONE", conviction:0.9, stop:nil, target:nil)
  #expect(EV.rankByEV([none, lose], losersLast: false).map(\.symbol) == ["LOSE", "NONE"])
  #expect(EV.rankByEV([none, lose]).map(\.symbol) == ["NONE", "LOSE"])
@Test winnersNeverInterleaveWithLosers (regression pin): build 2 winners, 1 no-EV, 2 losers in scrambled input; assert max(winner index) < noEV index < min(loser index).
Pre-existing tests re-derive identically: ranksIdeasByEVBestFirstNoEVLast (["B","A","C"]) and lowConvictionFantasyTargetCannotTopTheBoard (.first == "AAPL") both unchanged — grep-confirmed NO existing test asserts a negative-EV idea's rank relative to a no-EV idea. Run the canonical test command → ** TEST SUCCEEDED **.

### ⬜ #4 — Demote earnings-imminent ideas in bestOpportunity and the shared EV ranking key (a stop won't hold an overnight gap)
**signature:** Thread an OPTIONAL earnings map through the shared ranking key and the public ranking surfaces in Salehman AI/StockSage/StockSageExpectedValue.swift. All new params are trailing and default nil/off → every current caller/test byte-identical.

VERIFIED: EarningsProximity (StockSageEarnings.swift:11) is `struct ... Sendable, Equatable` with `let severity: Severity`; Severity.imminent = "≤3 days" (line 13). Its .note literally warns "a protective stop may NOT hold through it." Memberwise init is `EarningsProximity(daysUntil:severity:)`. Store holds `@Published private(set) var earnings: [String: EarningsProximity]` keyed UPPERCASE (StockSageStore.swift:497). qualityAdjustedEVR(for:) (107) is the SINGLE ranking key shared by bestOpportunity's .max (159), rankByEV (via evRankKey), and velocity/fastLane (via velocityRankKey).

New/changed:
  nonisolated static let imminentEarningsEVMultiplier = 0.8
  private nonisolated static func earningsRankMultiplier(for idea: StockSageIdea, earnings: [String: EarningsProximity]?) -> Double {
      guard let e = earnings?[idea.symbol.uppercased()], e.severity == .imminent else { return 1.0 }; return imminentEarningsEVMultiplier }
  qualityAdjustedEVR(for idea:, earnings: [String: EarningsProximity]? = nil) -> Double?  // *= earningsRankMultiplier
  evRankKey(for:earnings:) / velocityRankKey(for:holds:earnings:) — thread earnings, default nil
  bestOpportunity(_:earnings: ... = nil, excludeImminentEarnings: Bool = false), rankByEV(_:earnings:), rankByVelocity(_:holds:earnings:), fastLane(_:holds:earnings:), summary(_:trades:fraction:holds:earnings:) — all trailing-defaulted.

**mechanics:** WHY demote: a stop is an INTRADAY promise; an overnight earnings gap can open straight through it, so the risk sized at entry isn't the risk actually held. The engine already KNOWS this (EarningsProximity.note + StockSageRiskFlags raises a high "Earnings ≤3d" flag), but bestOpportunity can still crown such an idea #1 because EV ignores the gap. This threads the existing knowledge into ranking.

WHERE: multiply the ×0.8 discount once inside qualityAdjustedEVR(for:earnings:), the single shared key, so all four surfaces demote consistently — no second path to drift. It stacks multiplicatively on the existing qualityWeight, so it only ever SHRINKS the ranking edge. Thread earnings into evRankKey/velocityRankKey (pass to qualityAdjustedEVR) and into the public surfaces; in bestOpportunity pass earnings into BOTH operands of the .max closure.

EXCLUDE switch: bestOpportunity gains `excludeImminentEarnings: Bool = false`; when true AND earnings?[sym.uppercased()]?.severity == .imminent, drop that idea in the compactMap (the strict "#1 pick must have clean runway" mode). Default false → ×0.8 discount only.

WHY 0.8 not 0: a positive-EV setup near earnings is still a real edge if you size for the gap or wait — matching the file's non-blocking philosophy. 0.8 flips the #1 pick to a comparable clean-runway idea without erasing the opportunity. WHY only .imminent (≤3d): .soon/.clear don't threaten an overnight gap inside a typical intraday-stopped hold; reuse the existing ≤3-day cutoff, don't reinvent it. DISPLAY EV stays RAW (ev(for:) untouched) — same contract the file already keeps; the shown EV is true while ORDERING accounts for event risk, explained by the already-rendered "Earnings ≤3d" flag.

BYTE-COMPAT: every new param trailing-defaulted; earningsRankMultiplier returns 1.0 for nil-or-not-imminent, so qualityAdjustedEVR(for:) computes the EXACT same Double as today. After implementing: regenerate SOURCE_BUNDLE.md and append a DEVELOPMENT_LOG.md entry per CLAUDE.md. Optional caller wiring (pass store.earnings at MarketsView:2186/:2253, TodayView:260) is a separate non-blocking follow-up.

**test:** Add to StockSageExpectedValueTests.swift (uses idea(...) helper + EV typealias). Map keyed UPPERCASE, matching store.earnings:
@Test imminentEarningsDemotesBestOpportunity:
  let aapl = idea("AAPL", action: .strongBuy, conviction: 0.9, stop: 90, target: 130)  // raw EV 1.228R
  let msft = idea("MSFT", action: .buy,       conviction: 0.9, stop: 90, target: 130)  // EQUAL raw EV 1.228R
  let imminent = EarningsProximity(daysUntil: 2, severity: .imminent)
  let clear    = EarningsProximity(daysUntil: 30, severity: .clear)
  #expect(EV.bestOpportunity([aapl, msft])?.idea.symbol == "AAPL")   // baseline: tie broken by order, AAPL first
  let map: [String: EarningsProximity] = ["AAPL": imminent, "MSFT": clear]
  let best = EV.bestOpportunity([aapl, msft], earnings: map)
  #expect(best?.idea.symbol == "MSFT")                              // AAPL key 1.228·0.8=0.982 < MSFT 1.228 → flips
  #expect(best?.ev.evR == EV.ev(for: msft)?.evR)                    // DISPLAYED EV is the RAW estimate
  #expect(EV.bestOpportunity([aapl], earnings: ["AAPL": imminent], excludeImminentEarnings: true) == nil)
  #expect(EV.qualityAdjustedEVR(for: aapl) == EV.qualityAdjustedEVR(for: aapl, earnings: nil))  // byte-compat
  let base = EV.qualityAdjustedEVR(for: aapl)!
  #expect(abs(EV.qualityAdjustedEVR(for: aapl, earnings: map)! - base * EV.imminentEarningsEVMultiplier) < 1e-9)
Note: MSFT target MUST be 130 (equal raw EV) so the ×0.8 flip is unambiguous (0.982 < 1.228). Run: xcodebuild test -scheme "Salehman AI" -destination 'platform=macOS' -configuration Debug CODE_SIGNING_ALLOWED=NO -only-testing:"Salehman AITests/StockSageExpectedValueTests" 2>&1 | tee /tmp/salehman_build.log | tail -25 → ** TEST SUCCEEDED **; all 19 pre-existing EV tests stay green (none pass earnings).

### ⬜ #5 — Conviction-calibrated win probability + TradeRecord.convictionAtEntry (replace the guessed 35–58% band with THIS owner's realized hit-rate once there's signal)
**signature:** Additive only — no existing function changes signature.
VERIFIED: TradeRecord (StockSageJournal.swift:12-66) is Codable/Sendable/Equatable/Identifiable; init ends with `note: String? = nil` (line 33); has .isOpen and .realizedR (Double?, nil unless closed + defined risk via exitPrice.flatMap{rMultiple}). ExpectedValue {winProbEstimate, rewardR, evR} (line 12). winProbEstimate(conviction:) (63-65) = 0.35 + clamp(conviction)·0.23 — DO NOT MODIFY (pinned by tests). ev(conviction:entry:stop:target:) (69) and ev(for:) (132) confirmed.

1) TradeRecord gains a stored field (LAST init param, defaulted):
   var convictionAtEntry: Double?
   init(..., note: String? = nil, convictionAtEntry: Double? = nil)  // assign in body
2) struct CalibratedWinProb: Sendable, Equatable { let p: Double; let isCalibrated: Bool; let n: Int }
3) nonisolated static func calibratedWinProb(conviction: Double, trades: [TradeRecord], minPerBin: Int = 5) -> CalibratedWinProb
4) OPTIONAL additive overload (defaulted off): nonisolated static func ev(conviction:entry:stop:target:, calibrationTrades: [TradeRecord] = []) -> ExpectedValue?  — empty (every current caller) → behaves exactly as today via winProbEstimate; non-empty → uses calibratedWinProb(...).p only if .isCalibrated, else falls back to winProbEstimate. The existing 4-arg ev(...) signature is KEPT.

**mechanics:** BINNING + FIT (calibratedWinProb), pure/nonisolated, no global state:
- edges [0,0.2,0.4,0.6,0.8,1.0]; binIndex(c) = clamp(Int(clamp(c,0,1)/0.2), 0...4).
- eligible = trades.filter{ !$0.isOpen } each with non-nil convictionAtEntry AND non-nil realizedR (a defined-risk closed outcome). A win = realizedR > 0 (breakeven R==0 is NOT a win).
- closedInBin = eligible.filter{ binIndex($0.convictionAtEntry!) == binIndex(conviction) }.
- If closedInBin.count >= minPerBin (default 5): smooth toward the band with a beta(1,1) prior so a thin 0%/100% bin can't claim certainty: p = (wins + 1)/(count + 2); clamp p to [0.05, 0.95]. Return CalibratedWinProb(p, isCalibrated: true, n: count).
- Else (incl. zero eligible): p = winProbEstimate(conviction:) (the conservative 35–58% band). Return CalibratedWinProb(p, isCalibrated: false, n: closedInBin.count).

WHY: conviction is NOT a probability (the file's own caveat). The current 35–58% band is a deliberately conservative GUESS. Calibration replaces it with THIS owner's realized per-bin hit-rate once there's enough signal (>=5/bin), stays honestly labeled "uncalibrated" (falling back to the band) until then, and never fabricates confidence from 1–4 lucky trades. Smoothing + [0.05,0.95] keep evR finite and stop a 5/5 bin from claiming p=1.0.

POPULATE ON PREFILL (MarketsView.swift): add @State private var draftConviction: Double? = nil near the draft fields; in prefillTradeFromIdea(_:) set draftConviction = idea.advice.conviction; in saveDraftTrade() pass convictionAtEntry: draftConviction into the TradeRecord(...) init; reset to nil in the clear block. Manual (non-prefill) adds leave it nil — correct, no advisor conviction for a hand-typed trade. After implementing: regenerate SOURCE_BUNDLE.md and append a DEVELOPMENT_LOG.md entry per CLAUDE.md.

**test:** Add to a new StockSageCalibrationTests.swift (or the EV test file): import Testing + @testable import Salehman_AI. Helper builds a closed long with known R and conviction (entry 100, stop 90 → risk 10; exit = 100 + r·10 ⇒ realizedR == r):
  func t(conv: Double, r: Double) -> TradeRecord {
      TradeRecord(symbol:"X", side:.long, entry:100, stop:90, target:nil, shares:1,
                  openedAt: Date(timeIntervalSince1970:0), exitPrice: 100 + r*10,
                  closedAt: Date(timeIntervalSince1970:86_400), convictionAtEntry: conv) }
@Test fallsBackToBandWhenThin: res = EV.calibratedWinProb(conviction:0.9, trades:[]); #expect(!res.isCalibrated); #expect(res.n==0); #expect(abs(res.p - EV.winProbEstimate(conviction:0.9)) < 1e-9). 4 same-bin trades still under floor → !isCalibrated.
@Test fitsWhenBinHasEnough: 5 trades in the 0.8–1.0 bin, 3 wins/2 losses; res = EV.calibratedWinProb(conviction:0.92, trades: s); #expect(res.isCalibrated); #expect(res.n==5); #expect(abs(res.p - 4.0/7.0) < 1e-9).
@Test clampsAndSmoothsExtremeBins: 5 winners in bin 0.2–0.4 → (5+1)/(5+2); #expect(res.p < 0.95); #expect(abs(res.p - 6.0/7.0) < 1e-9).
@Test binIsolation: 8 trades in bin 0 don't calibrate conviction 0.9 (bin 4) → !isCalibrated, n==0.
@Test openAndUndefinedRTradesIgnored: an open trade (no exitPrice) carries no realizedR → excluded; plus5 + [open] yields n==5.
@Test decodeOldRecordHasNilConviction: decode JSON `[{"id":"00000000-0000-0000-0000-000000000001","symbol":"X","side":"Long","entry":100,"stop":90,"shares":1,"openedAt":0}]` (no convictionAtEntry key) → .first?.convictionAtEntry == nil (proves backward-compatible Codable decode of records persisted before this field). Round-trip of a populated value survives encode→decode.
@Test evOverloadFallsBackUntilCalibrated: EV.ev(conviction:1, entry:100, stop:90, target:120, calibrationTrades: [])!.evR == 0.74 (identical to the pinned 4-arg ev).
Run the canonical test command → ** TEST SUCCEEDED **, and every pre-existing EV/journal/CSV test still green (winProbEstimate band 0.35/0.58, EV values 0.74/1.228/0.188, CSV columns, decode round-trips).
