# OSRS profit build-specs (osrs-profit-research w7063r3f9, 2026-06-22)

8 agents → 12 ranked Swift engine specs. Build top items engine-first + test + commit.

## Top 3
- Freshness-decay multiplier in gp/hour ranking (realizedGpPerHour) — adds fillConfidence(highTime:lowTime:now:) and sorts flips/budget by realizedGpPerHour. Highest realized-gp impact because stale quotes are the #1 cause of a high theoretical gp/hour never materializing, and the highTime/lowTime data ALREADY exists on RuneScapePrice (lines 34/36) and is already decoded from the OSRS-Wiki /latest feed — zero new data, small effort, directly improves what the user buys.
- Net-of-tax margin everywhere (netMarginPercent) + tax-correctness audit — closes the gross-vs-net gap at RuneScapeModels.swift:45 so every ranking/tooltip honors the app's 2% tax honesty guarantee. Pure correctness, no modeling assumptions, tiny effort, prevents a silent honesty regression.
- Alchemy comparative analyzer (realizedAlchGpPerHour) — surfaces 'alch instead' when nature-cost + cast speed beats the best flip. For mid/small bankrolls high-alch (e.g. Rune platebody ~3.4M gp/hr) routinely outruns buy-limit-capped flips, so this opens a genuinely higher realized-gp path; works from live listings[561] nature price, small effort.

## Specs
### ⬜ #1 — Freshness-decay multiplier in gp/hour ranking (realizedGpPerHour)  [small]
**Signature:** `nonisolated static func fillConfidence(highTime: Date?, lowTime: Date?, now: Date = Date()) -> Double { /* 1.0 for <90s; linear decay to a 0.25 floor by ~3h; nil times => 1.0 */ }  // then add `var realizedGpPerHour: Double` to GEFlip (gpPerHour × confidence) and sort flips()/bestFlipsForBudget() by it; thread `now: Date = Date()` through both.`
**Test:** highTime=lowTime=now -> ~1.0; both = now-1h -> ~0.75; both = now-3h -> ~0.25 floor; both nil -> 1.0. flips() and bestFlipsForBudget() now rank a fresh 65K flip above a 70K flip whose prices are 3h old; verify a stale item loses budget allocation to a fresher one.
**Honesty:** Time-decay is a PROXY for staleness, not a volume measurement. A 3h-old Bonds quote may still fill instantly; a 5-min niche quote may sit. The OSRS-Wiki /latest feed gives highTime/lowTime but no trade volume, so this conservatively discounts age and cannot guarantee fills. Surface it as 'realized velocity', not a promise.

### ⬜ #2 — Net-of-tax margin everywhere (netMarginPercent) + tax-correctness audit of sort keys  [small]
**Signature:** `extension RuneScapePrice { func netMarginPercent(rate: Double = StockSageGEFlip.defaultRate) -> Double? { guard let high, let low, high > 0 else { return nil }; let tax = StockSageGEFlip.sellTax(high, rate: rate); return Double(high - low - tax) / Double(high) * 100 } }  // deprecate/comment the existing gross marginPercent (RuneScapeModels.swift:45) so no UI/sort path uses gross.`
**Test:** 1000->1100 flip (high=1100, tax=22) => netMarginPercent ≈ (78/1100)*100 ≈ 7.09%, NOT the gross 10%. Assert it equals profitPerItem/buyPrice*100 to within rounding. Tax-exempt edge (sell<50) => margin computed with 0 tax. Grep test/CI assert that gross marginPercent has no UI or ranking callers.
**Honesty:** Pure correctness fix, no modeling assumptions. It closes a real gap: marginPercent (line 45) is GROSS and one stray sort/tooltip using it would silently violate the app's 'all numbers net of 2% tax' guarantee. Net is the only honest edge a flipper keeps.

### ⬜ #3 — Alchemy comparative analyzer: realizedAlchGpPerHour() + 'alch instead' rank  [small]
**Signature:** `nonisolated static func realizedAlchGpPerHour(itemAlchValue: Int, natureRunePrice: Int, castsPerMinute: Double = 90, essenceCostPerCast: Int = 0) -> Double? { guard itemAlchValue > 0, natureRunePrice > 0, castsPerMinute > 0 else { return nil }; let net = itemAlchValue - natureRunePrice - essenceCostPerCast; guard net > 0 else { return nil }; return Double(net) * castsPerMinute / 60.0 * 60.0 }  // gp/hour = net/cast × casts/min × 60; pair with a helper that flags `alchGpPerHour > flip.realizedGpPerHour`.`
**Test:** nature=60, Rune platebody alch=38000, 90 casts/min => (38000-60)*90 = 3,414,600 gp/hr; beats most ≤500K/hr flips. Low-alch leather body (alch 12000) vs a flip at 7500 gp/hr => high-alch still wins. Negative net (alch<nature) and natureRunePrice=0 => nil. Nature price pulled from live listings[561].
**Honesty:** Assumes you sustain the cast rate (lag/AFK/fatigue cut real throughput) and nature runes fill instantly at the quoted price (thinly-traded natures spike). Alch is UNCAPPED by GE buy limits but CAPPED by player attention. Game economy, not financial advice — 'realized gp/hour depends on your setup'.

### ⬜ #4 — Capital-efficiency ROI knapsack allocator (roiOptimizedAllocation) + compoundCycles  [medium]
**Signature:** `nonisolated static func roiOptimizedAllocation(_ flips: [GEFlip], budget: Int, roiThreshold: Double = 0.0) -> BudgetPlan  // greedily allocate budget to flips sorted by roiPct desc (skip < roiThreshold), respecting buyLimit & remaining gp — mirrors bestFlipsForBudget but ROI-ranked; optionally extend BudgetPlan with `totalRoiPct` and `cyclesTo(target:from:)`.`
**Test:** budget=500K; cheap 50K@12% ROI vs mid 100K@8% vs expensive 400K@3% vs fat 1M@1%. ROI-ranked picks cheap+mid first; gp/hr lower short-term but higher totalRoiPct than greedy-by-gp/hr. roiThreshold=8% drops expensive+fat. cyclesTo(1M, from:100K) returns the integer 4h-cycle count to compound there.
**Honesty:** ROI compounding assumes liquidity holds across cycles — if bankroll demand for a cheap item exceeds its volume, fills collapse and ROI evaporates. Sound for small accounts (<10M) on liquid items; harsh slippage for big bankrolls on niche flips. Caveat: 'assumes cycle-N volume ≥ cycle-1'.

### ⬜ #5 — Per-item allocation cap with diversification + concentrationRisk on BudgetPlan  [small]
**Signature:** `nonisolated static func bestFlipsForBudgetDiversified(_ flips: [GEFlip], budget: Int, maxAllocationPct: Double = 0.25) -> BudgetPlan  // skip/partial-fill any flip whose capital would exceed maxAllocationPct×budget, spilling to the next flip; add `let concentrationRisk: Double` (Herfindahl Σ(capital/total)²) to BudgetPlan.`
**Test:** budget=100M, 3 flips each able to absorb >25M. At 25% cap expect ~25M, 25M, 50M split. Single flip > budget => partial fill at the cap. concentrationRisk: one-flip plan ≈1.0; four equal flips ≈0.25; assert >0.40 sets a UI warning flag.
**Honesty:** Diversifying costs ~5-8% theoretical gp/hour (spreads into slower flips) but cuts single-item crash/fill-stall exposure from ~70% to ~25% of bankroll. In OSRS fills aren't guaranteed (depend on open GE orders) — concentration is fill-risk, not free gp/hour.

### ⬜ #6 — Bankroll-compounding projection (compoundingProjection) — labeled HYPOTHETICAL  [small]
**Signature:** `nonisolated static func compoundingProjection(plan: BudgetPlan, cycles: Int, initialBankroll: Int) -> [ProjectionCycle]  // struct ProjectionCycle { let cycleNum: Int; let projectedBankroll: Int; let realizedProfit: Int; let roiPct: Double } — reinvest tax-net profit-per-cycle (gpPerHour×4h) forward N cycles.`
**Test:** 5M start, +50K/4h (~1% ROI), 10 cycles => ≈5M×1.01^10 ≈ 5.52M; assert against a hand-computed forward fold. 0 cycles => [initial]; 0 initial => empty/guarded. Multi-flip plan pools profit across the portfolio.
**Honesty:** HYPOTHETICAL & VOLUME-GATED: assumes you re-fill the same flips every cycle, margins/limits stay stable, and you actually fill what you buy. A static-condition CEILING, not a forecast — the GE economy shifts. UI must label it educational.

### ⬜ #7 — Volume-margin decay correction (gpPerHourVolumeCorrected)  [medium]
**Signature:** `nonisolated static func gpPerHourVolumeCorrected(buy: Int, sell: Int, buyLimit: Int, marginalDecay: Double = 0.3, rate: Double = defaultRate) -> Double?  // average realized margin = profit × (1 - marginalDecay/2) as you climb the buy limit; marginalDecay=0 recovers gpPerHour.`
**Test:** marginalDecay=0 => equals gpPerHour exactly. marginalDecay=0.3 => result ~15% lower (avg over the fill). High buyLimit decays more in absolute gp than a 1-unit limit. Compare corrected vs raw ranking on a snapshot: thin expensive items drop in rank more than cheap high-volume ones.
**Honesty:** HYPOTHETICAL: marginalDecay is a tuned parameter, NOT game-truth — real fills follow each item's live supply/demand curve, time of day, and luck. Use to surface 'realized vs theoretical', explicitly volume-gated.

### ⬜ #8 — Price-pair staleness filter for the fastest-flips UI strip (isMarginFresh)  [small]
**Signature:** `nonisolated static func isMarginFresh(highTime: Date?, lowTime: Date?, now: Date = Date(), maxAge: TimeInterval = 240) -> Bool { guard let h = highTime, let l = lowTime else { return false }; return max(now.timeIntervalSince(h), now.timeIntervalSince(l)) <= maxAge }  // filter fastestFlipsStrip to flips whose BOTH prices are < 4 min old.`
**Test:** both=now => true; one=now-5min => false; both nil => false; high=30s/low=200s => true; high=50s/low=300s => false. UI: render one fresh + one half-stale flip, assert only fresh shows and the explanatory note renders.
**Honesty:** Conservative: requires both sides fresh; a 4-min sell quote may already have moved. The 240s window is semi-arbitrary (should be a tunable setting). Falls back to 'no flips -> refresh', which is honest UX. Largely subsumed by rank-1's confidence model; ship as the UI filter atop it.

### ⬜ #9 — Volume-gate predicate + 'thesis-only' badge (volumeGate) — BLOCKED on missing data  [medium]
**Signature:** `nonisolated static func volumeGate(buyLimit: Int, margin: Int, estimatedDaily: Int) -> Bool { guard buyLimit > 0 else { return false }; return estimatedDaily >= buyLimit * 3 && margin > 0 }  // badge flips failing the gate as thesis-only instead of hiding them.`
**Test:** rune ore (limit 10k, ~50k daily) => true; 1-limit item, 0 daily => false; zero/negative inputs => false. Wire to UI: low-volume flip keeps its gp/hour but gets a 🔬 badge.
**Honesty:** DEPENDS ON DATA WE DON'T HAVE: the OSRS-Wiki /latest endpoint exposes high/low/highTime/lowTime/buyLimit but NO volume. estimatedDaily would need the separate /1h or /24h volume series (a new fetch) or a hardcoded guess. Until that feed is added this can't run on real data — defer, or first add the volume endpoint. Rank-1's time-decay is the available proxy.

### ⬜ #10 — Age-aware budget allocator with confidence bands (ConfidentBudgetPlan)  [medium]
**Signature:** `nonisolated static func confidentBudgetPlan(_ flips: [GEFlip], budget: Int, now: Date = Date()) -> ConfidentBudgetPlan  // struct adds confidenceWeightedGpPerHour, worstCaseGpPerHour, and per-flip expectedFillMinutes (derived from price age + buyLimit).`
**Test:** 300K across Bonds (5-min prices) vs a niche plugin (2h prices): bonds expectedFillMinutes ≤15 & higher confidence; plugin ≥40 & lower; worstCaseGpPerHour ≈60% of theoretical. Run 10× with randomized buy-prices in-margin; realized clusters in the band, not the peak.
**Honesty:** expectedFillMinutes is invented from age+buyLimit, NOT market depth (the API exposes neither order book nor volume). A heavier, mostly-cosmetic wrapper over rank-1's confidence — most of its value is already delivered by realizedGpPerHour. Lower priority for the effort.

### ⬜ #11 — Alchemy-aware hybrid budget allocator (mixedAlchAndFlipPlan)  [medium]
**Signature:** `nonisolated static func mixedAlchAndFlipPlan(flips: [GEFlip], alchs: [AlchItem], naturePrice: Int, budget: Int) -> MixedBudgetPlan  // struct BudgetedAlch { itemId, name, alchedPerHour, gpPerHour, costPerCast }; greedily fill by max(flip.realizedGpPerHour, alch.gpPerHour) across both pools.`
**Test:** 10M budget, nature 60. Flips A(5k/hr), B(2.5k/hr); alchs C(Rune plate, 56k/hr), D(Addy, 17.8k/hr). Plan ranks alch C first (uncapped by GE limit). 500K budget => alch dominates since flip units are buy-limit/capital starved.
**Honesty:** Mixes two different throughput models: flips are timer-gated/AFK-ish; alch is attention-gated and fatigue-degrades. Plan is best when the player rotates between them. Builds on rank-3; needs an AlchItem source (alch values are static per-item data, easy to bundle). Game economy, not advice.

### ⬜ #12 — Multi-cycle rotation scheduler (multiCycleRotation) across buy-limit resets  [large]
**Signature:** `nonisolated static func multiCycleRotation(flips: [GEFlip], sessionHours: Int, bankroll: Int, volumeMultiplier: Double = 1.0) -> FlipSession?  // FlipSession = [CycleAllocation { cycleStart: Int, items: [RotatedFlip], projectedGp: Double, utilizationPct: Double }]; nil if sessionHours < 4.`
**Test:** 8h, 100M, flips A/B/C. Cycle 1 (0-4h) buy A+B to limit; cycle 2 (4-8h) limits reset, rebuy A+B; idle capital backfills C. Expect ~2× single-cycle projected gp. volumeMultiplier=0.8 => realized < projected. sessionHours=3 => nil.
**Honesty:** Assumes volume multipliers and margins hold across the whole session (they don't — markets drift). A CEILING under static assumptions, not a floor; illiquid flips may realize 30-60% of projection. Largest build for the most assumptions — last to ship; lean on liquid items only.

## Notes
Verified against the real code: /Users/saleh/Desktop/Salehman AI/Salehman AI/StockSage/StockSageGEFlip.swift (GEFlip+roiPct, BudgetedFlip, BudgetPlan, sellTax 2%/cap5M/exempt<50, gpPerHour, flips, bestFlipsByROI, bestFlipsForBudget) and /Users/saleh/Desktop/Salehman AI/Salehman AI/Views/RuneScapeMarketView.swift (fastestFlipsStrip already consumes flips, ROI, and the budget plan; net-margin chip already applies sellTax).

KEY DATA FINDING — drives the ranking: the recency/freshness ideas were the strongest cluster AND the cheapest because RuneScapePrice already carries highTime/lowTime (Date?) at /Users/saleh/Desktop/Salehman AI/Salehman AI/RuneScape/RuneScapeModels.swift:34 and :36, decoded from the OSRS-Wiki /latest endpoint in /Users/saleh/Desktop/Salehman AI/Salehman AI/RuneScape/RuneScapeMarketService.swift:74-76. The engine simply doesn't thread them in yet. So rank-1 is high-value/low-effort: best realized-gp lift per line of code, no new data source. Prefer this single confidence multiplier over the heavier ConfidentBudgetPlan (rank 10) which mostly re-wraps the same signal.

DEDUP: the 12 ideas collapse to 5 themes — (a) recency/freshness [4 ideas -> rank 1 confidence multiplier + rank 8 UI filter; rank 10 is a heavier duplicate]; (b) tax honesty audit [rank 2]; (c) alchemy [rank 3 analyzer + rank 11 hybrid allocator]; (d) capital efficiency / risk [rank 4 ROI knapsack, rank 5 diversification, rank 6 compounding projection]; (e) volume realism [rank 7 decay correction, rank 9 volume-gate, rank 12 multi-cycle].

ONE BLOCKED IDEA: volumeGate (rank 9) needs trade-volume data the /latest feed does NOT provide — it would require adding the OSRS-Wiki /1h or /24h volume series as a new fetch, or hardcoded guesses. Per the 'prefer ideas that work with existing high/low/times/buyLimit data' rule it's deprioritized; the rank-1 time-decay confidence is the available stand-in for the same 'can I actually fill this?' question.

HONESTY THROUGHLINE preserved on every spec: gp/hour stays a volume-gated CEILING, fills aren't guaranteed, OSRS is a game economy (not financial advice). The confidence/decay/projection models are explicitly proxies or HYPOTHETICAL, never promises.

Suggested build order for the top 3: do rank 2 first (pure correctness, unblocks honest ranking), then rank 1 (the realized-gp lift — sort by realizedGpPerHour), then rank 3 (alch alternative path). All three are 'small' effort and need no new data source. Add XCTests per the testIdea for each in Salehman AITests/StockSageTests.swift, and remember the owner's standing directive to append a dated DEVELOPMENT_LOG.md entry after implementing.