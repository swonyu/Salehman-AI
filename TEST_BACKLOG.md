# Test-coverage backlog (test-coverage-sweep wmvxdkm71, 2026-06-22)

10 agents -> 43 source-verified test specs. RE-VERIFY each expected value before adding.

### ✅ DONE StockSageBacktester.summarize — Adverse gap fills BELOW the stop (entry 100, stop 97, gap-open 96)
**Expected:** avgR = -4/3 ≈ -1.333 (filled at the gap-open, not the stop)
```swift
@Test func summarizeAdverseGapFillsAtWorseThanStopPrice() {
    // r read from the trade: (96-100)/(100-97) = -4/3. summarize() just averages .r.
    let trade = BacktestTrade(entryIndex: 0, exitIndex: 1, entry: 100, exit: 96, r: -4.0/3.0, outcome: .stop)
    let result = StockSageBacktester.summarize([trade])
    #expect(result.trades == 1)
    #expect(abs(result.avgR - (-4.0/3.0)) < 1e-9)
}
```

### ✅ DONE StockSageBacktester.summarize — Breakeven trade (r==0) counted in trades but excluded from win/loss split [+1, 0, -1]
**Expected:** trades=3, wins=1, winRate=1/3, totalR=0, avgWinR=1, avgLossR=1, maxDrawdownR=1
```swift
@Test func summarizerBreakevenTradeExcludedFromWinLossSplit() {
    let trades = [
        BacktestTrade(entryIndex: 0, exitIndex: 1, entry: 100, exit: 101, r: 1, outcome: .target),
        BacktestTrade(entryIndex: 1, exitIndex: 2, entry: 101, exit: 101, r: 0, outcome: .openAtEnd),
        BacktestTrade(entryIndex: 2, exitIndex: 3, entry: 101, exit: 100, r: -1, outcome: .stop)
    ]
    let result = StockSageBacktester.summarize(trades)
    #expect(result.trades == 3)
    #expect(result.wins == 1)
    #expect(abs(result.winRate - 1.0/3.0) < 1e-9)
    #expect(abs(result.totalR) < 1e-9)
    #expect(abs(result.avgWinR - 1) < 1e-9)
    #expect(abs(result.avgLossR - 1) < 1e-9)
    #expect(abs(result.maxDrawdownR - 1) < 1e-9)
}
```

### ✅ DONE StockSageBacktester.summarize — Max drawdown peak-to-trough across cumulative R [+5,-2,-2,-2]
**Expected:** cum=[5,3,1,-1], peak=5 throughout → maxDrawdownR=6
```swift
@Test func summarizeMaxDrawdownTracksPeakToTrough() {
    let trades = [
        BacktestTrade(entryIndex: 0, exitIndex: 1, entry: 100, exit: 105, r: 5, outcome: .target),
        BacktestTrade(entryIndex: 1, exitIndex: 2, entry: 105, exit: 103, r: -2, outcome: .stop),
        BacktestTrade(entryIndex: 2, exitIndex: 3, entry: 103, exit: 101, r: -2, outcome: .stop),
        BacktestTrade(entryIndex: 3, exitIndex: 4, entry: 101, exit: 99, r: -2, outcome: .stop)
    ]
    let result = StockSageBacktester.summarize(trades)
    #expect(abs(result.maxDrawdownR - 6) < 1e-9)  // peak 5 → trough -1
}
```

### ✅ DONE StockSageBacktester.summarize — Average hold bars = mean(exitIndex - entryIndex) for variable holds
**Expected:** avgHoldBars = (1 + 10) / 2 = 5.5
```swift
@Test func summarizeComputesAverageHoldBarsCorrectly() {
    let trades = [
        BacktestTrade(entryIndex: 5, exitIndex: 6, entry: 100, exit: 101, r: 1, outcome: .target),   // hold 1
        BacktestTrade(entryIndex: 10, exitIndex: 20, entry: 100, exit: 110, r: 2, outcome: .target)  // hold 10
    ]
    let result = StockSageBacktester.summarize(trades)
    #expect(abs(result.avgHoldBars - 5.5) < 1e-9)
}
```

### ✅ DONE StockSageIndicators.returnOverPeriod — past price is zero (closes[0]=0) → division guard
**Expected:** nil
```swift
@Test func returnOverPeriodRejectsZeroPastPrice() {
    #expect(StockSageIndicators.returnOverPeriod([0, 100, 110], period: 2) == nil)  // past = closes[0] = 0
}
```

### ✅ DONE StockSageIndicators.macd — fast >= slow (inverted / equal) is rejected
**Expected:** nil
```swift
@Test func macdRejectsFastNotLessThanSlow() {
    let closes = (0..<60).map { 100.0 + Double($0) }   // plenty of data; only the fast<slow guard should reject
    #expect(StockSageIndicators.macd(closes, fast: 26, slow: 12) == nil)
    #expect(StockSageIndicators.macd(closes, fast: 12, slow: 12) == nil)
}
```

### ✅ DONE StockSageIndicators.efficiencyRatio — all prices identical → noise==0 guard
**Expected:** 0.0
```swift
@Test func efficiencyRatioFlatPriceReturnsZero() {
    #expect(StockSageIndicators.efficiencyRatio([5.0, 5.0, 5.0, 5.0, 5.0], period: 3)! == 0.0)
}
```

### ✅ DONE StockSageIndicators.emaSeries — period == 0 → guard period > 0 (prevents k = 2/(0+1) blowups)
**Expected:** []
```swift
@Test func emaSeriesRejectsPeriodZero() {
    #expect(StockSageIndicators.emaSeries([1, 2, 3], period: 0) == [])
}
```

### ✅ DONE StockSageIndicators.rsi — period == 0 → guard prevents /period division
**Expected:** nil
```swift
@Test func rsiRejectsPeriodZero() {
    #expect(StockSageIndicators.rsi([1, 2, 3], period: 0) == nil)
}
```

### ✅ DONE StockSageIndicators.atr — period == 0 → guard
**Expected:** nil
```swift
@Test func atrRejectsPeriodZero() {
    #expect(StockSageIndicators.atr(highs: [10, 12, 11], lows: [8, 9, 9], closes: [9, 11, 10], period: 0) == nil)
}
```

### ✅ DONE StockSageIndicators.efficiencyRatio — period == 0 → guard (suffix(period+1) safety)
**Expected:** nil
```swift
@Test func efficiencyRatioRejectsPeriodZero() {
    #expect(StockSageIndicators.efficiencyRatio([1, 2, 3], period: 0) == nil)
}
```

### ✅ DONE StockSageIndicators.returnOverPeriod — period == 0 → guard (index underflow)
**Expected:** nil
```swift
@Test func returnOverPeriodRejectsPeriodZero() {
    #expect(StockSageIndicators.returnOverPeriod([100, 110], period: 0) == nil)
}
```

### ✅ DONE StockSageStrategyBacktest.aggregate — zero-return symbol (totalR==0) is NOT counted profitable (> not >=)
**Expected:** symbolsProfitable = 0
```swift
@Test func aggregateSymbolWithZeroReturnIsNotProfitable() {
    let symbols = [
        BacktestResult(trades: 10, wins: 5, winRate: 0.5, avgR: 0, totalR: 0, maxDrawdownR: 2, sharpe: 0, avgHoldBars: 5),
        BacktestResult(trades: 5, wins: 2, winRate: 0.4, avgR: -0.2, totalR: -1, maxDrawdownR: 3, sharpe: -0.5, avgHoldBars: 4)
    ]
    let s = StockSageStrategyBacktest.aggregate(symbols)
    #expect(s.symbolsTested == 2)
    #expect(s.symbolsWithTrades == 2)
    #expect(s.symbolsProfitable == 0)
    #expect(abs(s.totalR - (-1)) < 1e-9)
}
```

### ✅ DONE StockSagePortfolioHeat.compute (.level) — heatPct exactly 0.10 is .hot (warm uses < 0.10)
**Expected:** .hot (1000 risk on 10k = 10%)
```swift
@Test func heatAtExact10PercentBoundaryIsHot() {
    // 100 shares · |100-90| = 1000 on a 10k account = exactly 10%.
    let h = StockSagePortfolioHeat.compute(openTrades: [(100, 100, 90)], accountSize: 10_000)!
    #expect(abs(h.heatPct - 0.10) < 1e-9)
    #expect(h.level == .hot)
    #expect(h.verdict.lowercased().contains("heavy"))
}
```

### ✅ DONE StockSagePortfolioHeat.compute (.level) — heatPct exactly 0.05 is .warm (cool uses < 0.05)
**Expected:** .warm (500 risk on 10k = 5%)
```swift
@Test func heatAtExact5PercentBoundaryIsWarm() {
    // 100 shares · |100-95| = 500 on a 10k account = exactly 5%. (NOTE: the candidate's
    // (10,100,95)=50→0.5% was wrong; use 100 shares to actually land on 5%.)
    let h = StockSagePortfolioHeat.compute(openTrades: [(100, 100, 95)], accountSize: 10_000)!
    #expect(abs(h.heatPct - 0.05) < 1e-9)
    #expect(h.level == .warm)
    #expect(h.verdict.contains("getting full"))
}
```

### ✅ DONE StockSageNetEdge.evaluate — netExpectancyR at winProb 0 and 1 (entry100 stop90 target130, no costs)
**Expected:** winProb 0 → -1.0; winProb 1 → 3.0
```swift
@Test func netExpectancyRAtExtremeWinProbs() {
    let e0 = StockSageNetEdge.evaluate(entry: 100, stop: 90, target: 130, winProb: 0)!
    let e1 = StockSageNetEdge.evaluate(entry: 100, stop: 90, target: 130, winProb: 1)!
    #expect(abs(e0.netExpectancyR! - (-1.0)) < 1e-9)
    #expect(abs(e1.netExpectancyR! - 3.0) < 1e-9)
}
```

### ✅ DONE StockSageExpectedValue.ev(conviction:entry:stop:target:) — SHORT trade entry>stop, target<entry (entry100 stop110 target80 conv0.9) — abs() parity
**Expected:** rewardR=2.0, winProbEstimate≈0.557, evR≈0.671, isPositive
```swift
@Test func evShortTradeParity() {
    let short = StockSageExpectedValue.ev(conviction: 0.9, entry: 100, stop: 110, target: 80)!
    #expect(abs(short.rewardR - 2.0) < 1e-9)
    let p = 0.35 + 0.9 * 0.23
    #expect(abs(short.winProbEstimate - p) < 1e-9)
    #expect(abs(short.evR - (p * 2.0 - (1 - p))) < 1e-9)
    #expect(short.isPositive)
}
```

### ✅ DONE StockSageExpectedValue.winProbEstimate(conviction:) — midpoint conviction 0.5 pins the 0.35 + 0.23·c formula
**Expected:** 0.465
```swift
@Test func winProbEstimateMidpoint() {
    #expect(abs(StockSageExpectedValue.winProbEstimate(conviction: 0.5) - 0.465) < 1e-9)
}
```

### ⬜ (OUT OF SCOPE — OSRS/GEFlip, owner-directed markets-tab-only scope) StockSageGEFlip.sellTax — sellPrice exactly at taxExemptBelow (50) is NOT exempt (>= guard)
**Expected:** 1 (floor(50·0.02))
```swift
@Test func sellTaxAtBoundary50NotExempt() {
    #expect(StockSageGEFlip.sellTax(50) == 1)
}
```

### ⬜ (OUT OF SCOPE — OSRS/GEFlip, owner-directed markets-tab-only scope) StockSageGEFlip.sellTax — tax-cap inflection at 250M (floor(250M·0.02)=5M exactly)
**Expected:** 249,999,999→4,999,999; 250,000,000→5,000,000; 251,000,000→5,000,000
```swift
@Test func sellTaxAtCapInflection() {
    #expect(StockSageGEFlip.sellTax(249_999_999) == 4_999_999)
    #expect(StockSageGEFlip.sellTax(250_000_000) == 5_000_000)
    #expect(StockSageGEFlip.sellTax(251_000_000) == 5_000_000)
}
```

### ⬜ (OUT OF SCOPE — OSRS/GEFlip, owner-directed markets-tab-only scope) StockSageGEFlip.flips — negative profit after tax (buy 1000, sell 1010, tax 20 → -10) is silently dropped
**Expected:** empty result
```swift
@Test func flipsFiltersNegativeProfitAfterTax() {
    let badListing = RuneScapeListing(
        item: RuneScapeItem(id: 99, name: "Loser", examine: "", members: false, buyLimit: 100),
        price: RuneScapePrice(high: 1010, highTime: nil, low: 1000, lowTime: nil)
    )
    #expect(StockSageGEFlip.flips([badListing]).isEmpty)
}
```

### ⬜ (OUT OF SCOPE — OSRS/GEFlip, owner-directed markets-tab-only scope) StockSageGEFlip.bestFlipsForBudget — greedy remainder below next item's buyPrice is not allocated
**Expected:** only A bought: units=2, totalCapital=2000 (remainder 500 < B's 2000)
```swift
@Test func bestFlipsForBudgetPartialRemainder() {
    let a = GEFlip(itemId: 1, name: "A", buyPrice: 1000, sellPrice: 1150, buyLimit: 10,
                    taxPerItem: 30, profitPerItem: 120, gpPerHour: 300)
    let b = GEFlip(itemId: 2, name: "B", buyPrice: 2000, sellPrice: 2400, buyLimit: 5,
                    taxPerItem: 48, profitPerItem: 352, gpPerHour: 440)
    let plan = StockSageGEFlip.bestFlipsForBudget([a, b], budget: 2500)
    #expect(plan.flips.map(\.itemId) == [1])
    #expect(plan.flips[0].units == 2)
    #expect(plan.totalCapital == 2000)
}
```

### ⬜ (OUT OF SCOPE — OSRS/GEFlip, owner-directed markets-tab-only scope) StockSageGEFlip.gpPerHour — minimum viable profit (profit=1 survives > 0 guard): buy100 sell103 limit100
**Expected:** 25.0 (profit 1 · 100 ÷ 4h)
```swift
@Test func gpPerHourMinimumViableProfit() {
    let gph = StockSageGEFlip.gpPerHour(buy: 100, sell: 103, buyLimit: 100)!  // tax floor(103·0.02)=2 → profit 1
    #expect(abs(gph - 25.0) < 1e-9)
}
```

### ⬜ (OUT OF SCOPE — OSRS/GEFlip, owner-directed markets-tab-only scope) StockSageGEFlip.GEFlip.roiPct — minimal non-zero buyPrice (=1) division boundary
**Expected:** 10000.0 (profit 100 ÷ 1 · 100)
```swift
@Test func roiPctWithMinimalBuyPrice() {
    let flip = GEFlip(itemId: 1, name: "Test", buyPrice: 1, sellPrice: 101, buyLimit: 100,
                      taxPerItem: 2, profitPerItem: 100, gpPerHour: 0)
    #expect(abs(flip.roiPct - 10000.0) < 1e-9)
}
```

### ✅ DONE StockSageRiskParity.targets(_:) — negative currentValue (short) is silently filtered (>= 0 guard)
**Expected:** only LONG survives: count 1
```swift
@Test func negativeCurrentValueSilentlyDropped() {
    let t = StockSageRiskParity.targets([
        RiskParityHolding(symbol: "SHORT", currentValue: -100, volatility: 0.20),
        RiskParityHolding(symbol: "LONG", currentValue: 100, volatility: 0.20),
    ])
    #expect(t.count == 1)
    #expect(t[0].symbol == "LONG")
}
```

### ✅ DONE StockSageRiskParity.targets(_:) — all currentValue == 0 → validTotal 0 → currentWeight falls back to target (delta 0)
**Expected:** A target 2/3, B target 1/3, both deltaWeight 0
```swift
@Test func allZeroCurrentValueUsesTargetAsCurrentWeight() {
    let t = StockSageRiskParity.targets([
        RiskParityHolding(symbol: "A", currentValue: 0, volatility: 0.10),
        RiskParityHolding(symbol: "B", currentValue: 0, volatility: 0.20),
    ])
    let a = t.first { $0.symbol == "A" }!
    let b = t.first { $0.symbol == "B" }!
    #expect(abs(a.targetWeight - 2.0/3.0) < 1e-9)
    #expect(abs(b.targetWeight - 1.0/3.0) < 1e-9)
    #expect(abs(a.deltaWeight) < 1e-9)
    #expect(abs(b.deltaWeight) < 1e-9)
}
```

### ✅ DONE StockSageAllocation.breakdown(_:) — mixed long/short — negative-value short dropped from slices (where value > 0) but clamped to 0 in total
**Expected:** totalValue=175, byClass count 1 (Equity), topClassConcentration=1.0
```swift
@Test func mixedSignHoldingsShortsDroppedFromConcentration() {
    let b = StockSageAllocation.breakdown([("AAPL", 100), ("SHY", -50), ("MSFT", 75)])
    #expect(b.totalValue == 175)
    #expect(b.byClass.count == 1)
    #expect(abs(b.topClassConcentration - 1.0) < 1e-9)
}
```

### ✅ DONE StockSageKelly.compute(winRate:payoffRatio:accountSize:) — zero accountSize → dollarsToRisk 0 (max(0,account) guard)
**Expected:** suggestedFraction 0.20, dollarsToRisk 0.0
```swift
@Test func zeroAccountSizeYieldsZeroDollars() {
    let k = StockSageKelly.compute(winRate: 0.60, payoffRatio: 2.0, accountSize: 0)
    #expect(abs(k.suggestedFraction - 0.20) < 1e-9)
    #expect(k.dollarsToRisk == 0.0)
}
```

### ✅ DONE StockSageRegime.adjustedWeight(base:bias:cap:) — zero bias zeroes the position (base>0 passes, then ·0)
**Expected:** 0.0
```swift
@Test func zeroBiasSilentlyZerosPosition() {
    #expect(StockSageRegime.adjustedWeight(base: 0.10, bias: 0.0, cap: 0.20) == 0.0)
}
```

### ✅ DONE StockSageAdvisor.stopTarget(action:price:atr:) — buy with atr == 0 hits the $0>0?…:8% false branch (distinct from atr: nil)
**Expected:** stop = 92, target = 116
```swift
@Test func stopTargetWithZeroATRUses8PercentFallback() {
    let st = StockSageAdvisor.stopTarget(action: .buy, price: 100, atr: 0)
    #expect(st.stop == 92)            // 100 - 100·0.08
    #expect(st.target == 116)         // 100 + 2·(100-92)
}
```

### ✅ DONE StockSageCurrency.breakdown — non-base weight just under 0.25 is NOT flagged (> threshold, strict)
**Expected:** concentration == nil, hasFXRisk == false (EUR ≈ 24.9998%)
```swift
@Test func concentrationJustUnder25PercentNotFlagged() {
    // USD 1000 + EUR 333.33 (rate 1) → EUR weight 333.33/1333.33 ≈ 0.249998 < 0.25.
    let b = StockSageCurrency.breakdown(
        holdings: [(1000, "USD"), (333.33, "EUR")],
        ratesToBase: ["EUR": 1.0], base: "USD", concentrationThreshold: 0.25)!
    #expect(b.concentration == nil)
    #expect(!b.hasFXRisk)
}
```

### ✅ DONE StockSageAlertDecision.evaluate — target crossed EXACTLY on the level (price == target) still fires (>= guard)
**Expected:** .targetHit
```swift
@Test func targetCrossedExactlyOnTheLevel() {
    let a = StockSageAlertDecision.evaluate(symbol: "X", recommendation: .buy, price: 120, priorPrice: 115,
                                            stop: 90, target: 120, lastAlertedRecommendation: nil)
    #expect(a?.kind == .targetHit)
}
```

### ✅ DONE StockSageAlertDecision.evaluate — stop crossed EXACTLY on the level (price == stop) still fires (<= guard)
**Expected:** .stopBreach
```swift
@Test func stopCrossedExactlyOnTheLevel() {
    let a = StockSageAlertDecision.evaluate(symbol: "X", recommendation: .buy, price: 90, priorPrice: 95,
                                            stop: 90, target: 120, lastAlertedRecommendation: nil)
    #expect(a?.kind == .stopBreach)
}
```

### ✅ DONE StockSageRebalance.plan — drift exactly at band (2%) is suppressed; 2.1% > band trades (> band, strict)
**Expected:** at band → trades empty; above band → trades non-empty
```swift
@Test func driftExactlyAtBandEdge() {
    let atBand = StockSageRebalance.plan(holdings: [("A", 5200), ("B", 4800)],
                                         targets: ["A": 0.5, "B": 0.5], band: 0.02)!
    #expect(atBand.trades.isEmpty)  // |0.52-0.50| = 0.02, not > 0.02
    let aboveBand = StockSageRebalance.plan(holdings: [("A", 5210), ("B", 4790)],
                                            targets: ["A": 0.5, "B": 0.5], band: 0.02)!
    #expect(!aboveBand.trades.isEmpty)
}
```

### ✅ DONE StockSagePartialLadder.levels — single-rung (rungs=1) degenerate: whole position exits at the target
**Expected:** 1 rung at 130, rMultiple 3.0, fraction 1.0, blendedExitR 3.0
```swift
@Test func singleRungLadderExitsAtTarget() {
    let l = StockSagePartialLadder.levels(entry: 100, stop: 90, target: 130, rungs: 1)!
    #expect(l.rungs.count == 1)
    #expect(abs(l.rungs[0].price - 130) < 1e-9)
    #expect(abs(l.rungs[0].rMultiple - 3.0) < 1e-9)
    #expect(abs(l.rungs[0].fraction - 1.0) < 1e-9)
    #expect(abs(l.blendedExitR - 3.0) < 1e-9)
}
```

### ✅ DONE StockSagePartialLadder.levels — large rungs (10) blended average scaling
**Expected:** 10 rungs each fraction 0.1, blendedExitR = 2.75 (target 150 → 5R; (1+2+…+10)/10·(5/10)=2.75)
```swift
@Test func largeRungsCountBlendingIsCorrect() {
    // entry 100, stop 90 (risk 10), target 150 (5R), 10 rungs. r_i = 5·i/10, each fraction 0.1.
    // blended = Σ 0.1·(5·i/10) for i=1…10 = 0.5·(55/10) = 2.75.
    let l = StockSagePartialLadder.levels(entry: 100, stop: 90, target: 150, rungs: 10)!
    #expect(l.rungs.count == 10)
    #expect(l.rungs.allSatisfy { abs($0.fraction - 0.1) < 1e-9 })
    #expect(abs(l.blendedExitR - 2.75) < 1e-9)
}
```

### ✅ DONE StockSageIndicators.annualizedVolatility — a zero/corrupt price mid-series drops a return; survivors decide nil
**Expected:** [100,0,110] → nil (only 1 valid return); [100,100,110] → non-nil
```swift
@Test func annualizedVolatilitySkipsZeroPrice() {
    #expect(StockSageIndicators.annualizedVolatility([100.0, 0, 110.0]) == nil)   // closes[1]=0 drops one ret → count 1
    #expect(StockSageIndicators.annualizedVolatility([100.0, 100.0, 110.0]) != nil)
}
```

### ✅ DONE StockSageJournal.streak — single closed trade with R != 0 → streak of 1
**Expected:** streakCount 1, streakIsWin true, bestR 2.0
```swift
@Test func streakSingleWinTradeIsStreakOfOne() {
    let single = [TradeRecord(symbol: "AAPL", side: .long, entry: 100, stop: 90, target: nil, shares: 1,
                             openedAt: Date(timeIntervalSince1970: 0),
                             exitPrice: 120, closedAt: Date(timeIntervalSince1970: 100))]
    let s = StockSageJournal.streak(single)!
    #expect(s.streakCount == 1)
    #expect(s.streakIsWin == true)
    #expect(abs(s.bestR - 2.0) < 1e-9 && s.bestSymbol == "AAPL")
}
```

### ✅ DONE StockSageJournal.streak — all decisive trades breakeven (R==0) → no streak
**Expected:** streakCount 0 (not crash/undefined)
```swift
@Test func streakNoStreakWhenAllBreakeven() {
    let breakeven = (0..<3).map { i in
        TradeRecord(symbol: "X", side: .long, entry: 100, stop: 90, target: nil, shares: 1,
                    openedAt: Date(timeIntervalSince1970: Double(i) * 100),
                    exitPrice: 100, closedAt: Date(timeIntervalSince1970: Double(i) * 100 + 50))
    }
    let s = StockSageJournal.streak(breakeven)!
    #expect(s.streakCount == 0)
}
```

### ✅ DONE StockSageJournal.equityRisk — all winners → zero losing run, zero drawdown
**Expected:** maxConsecutiveLosses 0, maxDrawdownR 0.0
```swift
@Test func equityRiskAllWinnersZeroDrawdown() {
    let winners = [1.5, 2.0, 1.0].enumerated().map { i, r in
        TradeRecord(symbol: "X", side: .long, entry: 100, stop: 90, target: nil, shares: 1,
                    openedAt: Date(timeIntervalSince1970: Double(i) * 100),
                    exitPrice: 100 + r * 10, closedAt: Date(timeIntervalSince1970: Double(i) * 100 + 50))
    }
    let risk = StockSageJournal.equityRisk(winners)!
    #expect(risk.maxConsecutiveLosses == 0)
    #expect(abs(risk.maxDrawdownR) < 1e-9)
}
```

### ✅ DONE StockSageJournal.expectancyTrend — delta exactly == band → .flat (delta > band is strict)
**Expected:** .flat (early mean 0, recent mean 0.1, band 0.1)
```swift
@Test func expectancyTrendDeltaAtBandExactlyIsFlat() {
    let flat = (0..<6).map { i -> TradeRecord in
        let r = i < 3 ? 0.0 : 0.1
        return TradeRecord(symbol: "X", side: .long, entry: 100, stop: 90, target: nil, shares: 1,
                          openedAt: Date(timeIntervalSince1970: Double(i) * 100),
                          exitPrice: 100 + r * 10, closedAt: Date(timeIntervalSince1970: Double(i) * 100 + 50))
    }
    let t = StockSageJournal.expectancyTrend(flat, band: 0.1)!
    #expect(t.direction == .flat)
}
```

### ✅ DONE StockSageJournal.classifyHealth — profitFactor exactly 1.5 is .strong (>= 1.5); 1.49 is .developing
**Expected:** 1.5 → .strong; 1.49 → .developing
```swift
@Test func classifyHealthPFBoundaryIsInclusive() {
    let atBound = StockSageJournal.classifyHealth(profitFactor: 1.5, expectancyR: 0.5, significant: true,
                                                  n: 30, maxDrawdownR: 3.0, minTrades: 20, deepDrawdownR: 8.0)
    #expect(atBound.verdict == .strong)
    let justBelow = StockSageJournal.classifyHealth(profitFactor: 1.49, expectancyR: 0.5, significant: true,
                                                    n: 30, maxDrawdownR: 3.0, minTrades: 20, deepDrawdownR: 8.0)
    #expect(justBelow.verdict == .developing)
}
```

### ✅ DONE StockSageAdvisor.advise(closes:highs:lows:) — 50–200 bars uses the lighter 0.20 trend term (buy, not strongBuy) vs full 0.40 at 250 bars
**Expected:** 70-bar uptrend → .buy; 250-bar uptrend → .strongBuy; short conviction < long conviction
```swift
@Test func fiftyBarHistoryUsesLighterTrendScore() {
    let aShort = StockSageAdvisor.advise(closes: (1...70).map(Double.init))
    let aLong  = StockSageAdvisor.advise(closes: (1...250).map(Double.init))
    #expect(aShort.action == .buy)
    #expect(aLong.action == .strongBuy)
    #expect(aShort.conviction < aLong.conviction)
}
```

**2026-06-28 implementation:** All 37 in-scope specs (6 GEFlip/OSRS items excluded per owner's markets-tab-only directive) verified via a 16-agent parallel re-audit against current source (function signatures, independently re-derived expected values, duplicate-coverage checks) before adding — 35/37 confirmed exactly as drafted, 2 needed fixes (a stale raw-integer-ramp fixture replaced with the file's own `TrendFixtures.up()` helper; a floating-point boundary case that didn't land bit-exact in binary64, corrected to values that do). A 38th case (`driftExactlyAtBandEdge`, not part of the 37 above — a StockSageRebalance boundary test) surfaced the SAME floating-point-boundary class of bug during the actual build+test run despite passing the 16-agent audit, and was fixed the same way (0.02/5200/4800 replaced with the bit-exact 0.25/2500/7500 pair). All 37 + the 2 alert-boundary tests (redirected from the wrong target file `StockSageAlertsTests.swift` to the correct `StockSageAlertDecisionTests.swift` — the audit caught that `StockSageAlertDecision` is a distinct enum from `StockSageAlerts`) now pass. Full suite green.
