# Test-hardening sweep (wmagiftnw, 2026-06-23)

13 CONFIRMED untested critical branches in the money engines (deterministic, regression-catching). Each has an exact Swift-Testing sketch. Add 1-2/tick.

### ⬜ #1 [critical] — runCycle returns strong signals even when sample/cache gate suppresses notifications
**file:** /Users/saleh/Desktop/Salehman AI/Salehman AITests/StockSageMonitorTests.swift
```swift
@MainActor @Test func runCycleReturnsStrongSignalsEvenOnSampleDataWithoutNotifying() async {
  let store = StockSageStore.shared
  let original = store.fetchAllSymbols(); let wasSample = store.isSampleData
  defer { store.replaceAll(original, isSample: wasSample) }
  let mover = StockSageSymbol(symbol: "UP", market: "NYSE", quotes: [
    StockSageQuote(price: 100, previousPrice: 100),
    StockSageQuote(price: 110, previousPrice: 100)]) // +10% -> strongBuy
  store.replaceAll([mover], isSample: true)
  #expect(store.isSampleData) // gate closed
  let signals = await StockSageMonitor.shared.runCycle(notify: true)
  #expect(signals.contains { $0.symbol == "UP" && $0.recommendation == .strongBuy })
}
```

### ⬜ #2 [critical] — summarize() decay-population gate (>=8 trades) populates BacktestResult.decay
**file:** /Users/saleh/Desktop/Salehman AI/Salehman AITests/StockSageBacktesterTests.swift
```swift
@Test func decayPopulatesOnlyAtEightTrades() {
  let seven = StockSageBacktester.summarize((0..<7).map { trade($0 < 5 ? 1 : -1) })
  #expect(seven.decay == nil)
  let eight = StockSageBacktester.summarize((0..<8).map { trade($0 < 6 ? 1 : -1) })
  #expect(eight.decay != nil)
  #expect(eight.decay?.oosTrades == 2) // 30% slice = max(1, Int((8*0.30).rounded())) = 2
}
```

### ⬜ #3 [high] — SHORT in-profit and near-stop verdicts (side-aware rNow path)
**file:** /Users/saleh/Desktop/Salehman AI/Salehman AITests/StockSageJournalTests.swift
```swift
@Test func openActionsShortSideInProfitAndNearStop() {
  let short = TradeRecord(symbol: "S", side: .short, entry: 100, stop: 110, target: 80, shares: 10, openedAt: Date(timeIntervalSince1970: 0))
  let win = StockSageJournal.openActions([short], mark: { _ in 90 }).first  // -10 = +1R short
  #expect(win?.kind == .inProfit)
  #expect((win?.rNow ?? 0) > 0)
  let near = StockSageJournal.openActions([short], mark: { _ in 107.5 }).first // +7.5 = -0.75R
  #expect(near?.kind == .nearStop)
  #expect(abs((near?.rNow ?? 0) - (-0.75)) < 1e-9)
}
```

### ⬜ #4 [high] — Earnings (-2000) stacked with cost-fail (-500k) sorts below cost-only-failed peer
**file:** /Users/saleh/Desktop/Salehman AI/Salehman AITests/StockSageExpectedValueTests.swift
```swift
@Test func earningsStacksBelowCostFailedPeer() {
  let thin = idea("BTC-USD", conviction: 0.5, stop: 98, target: 103)   // imminent earnings + after-cost negative
  let costOnly = idea("ETH-USD", conviction: 0.5, stop: 98, target: 103) // clean earnings, after-cost negative
  let clean = idea("AAPL", conviction: 0.7, stop: 90, target: 130)      // passes both
  let earnings = ["BTC-USD": EarningsProximity(daysUntil: 2, severity: .imminent)]
  let order = EV.rankByEV([thin, costOnly, clean], earnings: earnings).map(\.symbol)
  #expect(order == ["AAPL", "ETH-USD", "BTC-USD"])
}
```

### ⬜ #5 [high] — -2000 earnings vs -1000 conviction-band cross-ordering on real ideas
**file:** /Users/saleh/Desktop/Salehman AI/Salehman AITests/StockSageExpectedValueTests.swift
```swift
@Test func imminentSinksBelowLowConvictionCleanPeer() {
  let imminentHi = idea("AAPL", conviction: 0.9, stop: 90, target: 130)   // strong but reports in 2d
  let lowConvClean = idea("MSFT", conviction: 0.39, stop: 90, target: 130) // sub-floor, clean calendar
  let earnings = ["AAPL": EarningsProximity(daysUntil: 2, severity: .imminent)]
  #expect(EV.rankByEV([imminentHi, lowConvClean], earnings: earnings).first?.symbol == "MSFT")
}
```

### ⬜ #6 [medium] — WalkForwardDecay.oosSignificant TRUE side and exactly-20-OOS boundary
**file:** /Users/saleh/Desktop/Salehman AI/Salehman AITests/StockSageBacktesterTests.swift
```swift
@Test func oosSignificantFlipsAtTwentyOOS() {
  let below = StockSageBacktester.walkForwardDecay((0..<63).map { trade(1) }) // oosCount 19
  #expect(!below.oosSignificant)
  let at = StockSageBacktester.walkForwardDecay((0..<67).map { trade(1) })    // oosCount 20
  #expect(at.oosTrades == 20)
  #expect(at.oosSignificant)
}
```

### ⬜ #7 [medium] — isUrgent targetHit half + targetHit sorts ahead of higher-|R| non-urgent row
**file:** /Users/saleh/Desktop/Salehman AI/Salehman AITests/StockSageJournalTests.swift
```swift
@Test func targetHitOutranksHigherRNonUrgent() {
  let a = TradeRecord(symbol: "A", side: .long, entry: 100, stop: 90, target: 110, shares: 10, openedAt: Date(timeIntervalSince1970: 0))
  let b = TradeRecord(symbol: "B", side: .long, entry: 100, stop: 90, target: 999, shares: 10, openedAt: Date(timeIntervalSince1970: 0))
  let marks: [String: Double] = ["A": 110, "B": 130] // A targetHit +1R, B inProfit +3R
  let actions = StockSageJournal.openActions([a, b], mark: { marks[$0.symbol] ?? 0 })
  #expect(actions.first?.kind == .targetHit) // urgent beats larger |R|
  #expect(OpenAction(kind: .targetHit, symbol: "X", detail: "", rNow: 0).isUrgent == true)
  #expect(OpenAction(kind: .holding, symbol: "X", detail: "", rNow: 0).isUrgent == false)
}
```

### ⬜ #8 [medium] — equityRisk maxConsecutiveLosses: trailing run + breakeven-resets-streak
**file:** /Users/saleh/Desktop/Salehman AI/Salehman AITests/StockSageJournalTests.swift
```swift
@Test func maxConsecutiveLossesTrailingRunAndBreakevenSplit() {
  #expect(StockSageJournal.equityRisk(seq([1, -1, -1, -1]))?.maxConsecutiveLosses == 3) // trailing run
  #expect(StockSageJournal.equityRisk(seq([-1, -1, 0, -1]))?.maxConsecutiveLosses == 2) // R==0 scratch splits
}
```

### ⬜ #9 [medium] — nil-key fall-through: imminent-earnings idea with nil base key stays nil (not -2000)
**file:** /Users/saleh/Desktop/Salehman AI/Salehman AITests/StockSageExpectedValueTests.swift
```swift
@Test func earningsPenaltyNeverResurrectsANilKey() {
  let nilA = idea("NOEVA", action: .buy, conviction: 0.9, stop: nil, target: nil) // imminent + nil EV key
  let nilB = idea("NOEVB", action: .buy, conviction: 0.9, stop: nil, target: nil) // clean + nil EV key
  let earnings = ["NOEVA": EarningsProximity(daysUntil: 1, severity: .imminent)]
  // both keys nil -> sort is stable on input order; the imminent one must NOT float above via a resurrected -2000
  #expect(EV.rankByEV([nilB, nilA], earnings: earnings).map(\.symbol) == ["NOEVB", "NOEVA"])
}
```

### ⬜ #10 [medium] — openActions .holding catch-all verdict (flat long and flat short)
**file:** /Users/saleh/Desktop/Salehman AI/Salehman AITests/StockSageJournalTests.swift
```swift
@Test func openActionsHoldingCatchAll() {
  let long = TradeRecord(symbol: "L", side: .long, entry: 100, stop: 90, target: 130, shares: 10, openedAt: Date(timeIntervalSince1970: 0))
  let l = StockSageJournal.openActions([long], mark: { _ in 95 }).first // rNow -0.5R: above nearStop, below inProfit
  #expect(l?.kind == .holding)
  #expect(l?.detail.contains("no level crossed") == true)
  let short = TradeRecord(symbol: "S", side: .short, entry: 100, stop: 110, target: 80, shares: 10, openedAt: Date(timeIntervalSince1970: 0))
  #expect(StockSageJournal.openActions([short], mark: { _ in 105 }).first?.kind == .holding) // rNow -0.5R
}
```

### ⬜ #11 [medium] — sellTax at exact 50-gp exempt boundary (first taxed sale)
**file:** /Users/saleh/Desktop/Salehman AI/Salehman AITests/StockSageGEFlipTests.swift
```swift
@Test func sellTaxTaxesExactlyAtExemptBoundary() {
  #expect(StockSageGEFlip.sellTax(50) == 1)  // floor(50*0.02)=1, first taxed price
  #expect(StockSageGEFlip.sellTax(49) == 0)  // still exempt one below
  #expect(StockSageGEFlip.sellTax(StockSageGEFlip.taxExemptBelow) == Int((Double(StockSageGEFlip.taxExemptBelow) * StockSageGEFlip.defaultRate).rounded(.down)))
}
```

### ⬜ #12 [medium] — portfolioCap clamps negative per-position fraction to 0 (max(0,$0) clamp)
**file:** /Users/saleh/Desktop/Salehman AI/Salehman AITests/StockSageKellyTests.swift
```swift
@Test func portfolioCapClampsNegativeFractions() {
  let pc = StockSageKelly.portfolioCap([-0.10, 0.05, 0.05], maxPortfolioHeat: 0.30)
  #expect(abs(pc.bookRequestedHeat - 0.10) < 1e-9) // negatives floored before summing
  #expect(pc.scaleApplied == 1)
  #expect(abs(pc.bookHeat - 0.10) < 1e-9)
  #expect((pc.scaledFractions.first ?? -1) == 0)
  #expect(pc.scaledFractions.allSatisfy { $0 >= 0 })
}
```

### ⬜ #13 [medium] — portfolioCap clamps maxPortfolioHeat > 1 to 1 (min(1,...) ceiling)
**file:** /Users/saleh/Desktop/Salehman AI/Salehman AITests/StockSageKellyTests.swift
```swift
@Test func portfolioCapClampsCapAboveOneToOne() {
  let pc = StockSageKelly.portfolioCap([0.6, 0.6], maxPortfolioHeat: 5.0) // cap clamped to 1.0; requested 1.2 > 1.0
  #expect(abs(pc.maxPortfolioHeat - 1.0) < 1e-9)
  #expect(abs(pc.scaleApplied - (1.0 / 1.2)) < 1e-9)
  #expect(abs(pc.bookHeat - 1.0) < 1e-9)
}
```
