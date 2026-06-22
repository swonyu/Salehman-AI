import Testing
import Foundation
@testable import Salehman_AI

// MARK: - Trade journal P&L / R math (pure)

struct StockSageJournalTests {

    private func t(_ side: TradeRecord.Side, entry: Double, stop: Double, shares: Double,
                   exit: Double? = nil) -> TradeRecord {
        tSym("X", side, entry: entry, stop: stop, shares: shares, exit: exit)
    }

    private func tSym(_ symbol: String, _ side: TradeRecord.Side, entry: Double, stop: Double,
                      shares: Double, exit: Double? = nil) -> TradeRecord {
        TradeRecord(symbol: symbol, side: side, entry: entry, stop: stop, target: nil,
                    shares: shares, openedAt: Date(timeIntervalSince1970: 0),
                    exitPrice: exit, closedAt: exit == nil ? nil : Date(timeIntervalSince1970: 100))
    }

    @Test func longProfitAndRMultiple() {
        let trade = t(.long, entry: 100, stop: 90, shares: 10)   // risk/share = 10
        #expect(trade.profit(at: 120) == 200)                    // (120−100)*10
        #expect(trade.rMultiple(at: 120) == 2.0)                 // +20 / 10 risk
        #expect(trade.rMultiple(at: 90) == -1.0)                 // hit the stop = −1R
    }

    @Test func shortProfitAndRMultiple() {
        let trade = t(.short, entry: 100, stop: 110, shares: 5)  // risk/share = 10
        #expect(trade.profit(at: 80) == 100)                     // (100−80)*5
        #expect(trade.rMultiple(at: 80) == 2.0)                  // +20 / 10
        #expect(trade.rMultiple(at: 110) == -1.0)                // stop hit = −1R
    }

    @Test func zeroRiskRIsUndefinedNotInfinite() {
        #expect(t(.long, entry: 100, stop: 100, shares: 1).rMultiple(at: 120) == nil)
    }

    @Test func realizedUsesExitPrice() {
        let win = t(.long, entry: 50, stop: 45, shares: 4, exit: 60)
        #expect(win.realizedProfit == 40)        // (60−50)*4
        #expect(win.realizedR == 2.0)            // +10 / 5
        #expect(win.isOpen == false)
        #expect(t(.long, entry: 50, stop: 45, shares: 4).realizedProfit == nil)   // still open
    }

    @Test func edgeDecomposesWinsAndLosses() {
        let trades = [
            t(.long, entry: 100, stop: 90, shares: 1, exit: 120),   // +2R win
            t(.long, entry: 100, stop: 90, shares: 1, exit: 110),   // +1R win
            t(.long, entry: 100, stop: 90, shares: 1, exit: 90),    // −1R loss
            t(.long, entry: 100, stop: 90, shares: 1),              // open → excluded
        ]
        let e = StockSageJournal.edge(trades)
        #expect(e.closedWithR == 3)
        #expect(abs(e.avgWinR - 1.5) < 1e-9)        // (2+1)/2
        #expect(abs(e.avgLossR - 1.0) < 1e-9)       // |−1|
        #expect(abs(e.payoffRatio - 1.5) < 1e-9)    // 1.5 / 1.0
        #expect(abs(e.expectancyR - (2.0 + 1.0 - 1.0) / 3) < 1e-9)   // mean realized R = (+2 +1 −1)/3
        // Expectancy equals JournalStats.avgR (consistency).
        #expect(abs(e.expectancyR - StockSageJournal.stats(trades).avgR) < 1e-9)
    }

    private func closedAt(_ symbol: String, exit: Double, at time: Double) -> TradeRecord {
        TradeRecord(symbol: symbol, side: .long, entry: 100, stop: 90, target: nil, shares: 1,
                    openedAt: Date(timeIntervalSince1970: time - 50),
                    exitPrice: exit, closedAt: Date(timeIntervalSince1970: time))
    }

    private func closedR(_ r: Double) -> TradeRecord {
        tSym("X", .long, entry: 100, stop: 90, shares: 1, exit: 100 + r * 10)   // R = (exit−100)/10
    }

    private func held(_ exit: Double, days: Double) -> TradeRecord {
        TradeRecord(symbol: "X", side: .long, entry: 100, stop: 90, target: nil, shares: 1,
                    openedAt: Date(timeIntervalSince1970: 0),
                    exitPrice: exit, closedAt: Date(timeIntervalSince1970: days * 86_400))
    }

    @Test func holdingPeriodFlagsRidingLosers() {
        // winners held 10d & 14d (avg 12), loser held 31d → riding losers.
        let h = StockSageJournal.holdingPeriod([held(120, days: 10), held(120, days: 14), held(90, days: 31)])!
        #expect(abs(h.avgWinDays - 12) < 1e-9)
        #expect(abs(h.avgLossDays - 31) < 1e-9)
        #expect(h.winCount == 2 && h.lossCount == 1)
        #expect(h.ridingLosers)
        #expect(h.note.contains("ride losers"))
    }

    @Test func holdingPeriodGoodDisciplineAndEmpty() {
        // winners held long (20d), losers cut fast (3d) → not riding losers.
        let h = StockSageJournal.holdingPeriod([held(120, days: 20), held(90, days: 3)])!
        #expect(!h.ridingLosers)
        #expect(h.note.contains("cut losers fast"))
        #expect(StockSageJournal.holdingPeriod([]) == nil)
    }

    @Test func expectancyConfidenceBand() {
        // rs = [3, 1]: mean 2; sample var = ((1)+(1))/(2−1) = 2; stdev √2; stderr √2/√2 = 1.0.
        let c = StockSageJournal.expectancyConfidence([closedR(3), closedR(1)])!
        #expect(abs(c.expectancyR - 2.0) < 1e-9)
        #expect(abs(c.stdErrR - 1.0) < 1e-9)
        #expect(c.n == 2)
        #expect(c.isSignificant)        // |2.0| ≥ 1.0
    }

    private func seq(_ rs: [Double]) -> [TradeRecord] {
        rs.enumerated().map { i, r in
            TradeRecord(symbol: "X", side: .long, entry: 100, stop: 90, target: nil, shares: 1,
                        openedAt: Date(timeIntervalSince1970: Double(i) * 100),
                        exitPrice: 100 + r * 10, closedAt: Date(timeIntervalSince1970: Double(i) * 100 + 50))
        }
    }

    @Test func projectGrowthCompoundsExpectancyForward() {
        // expectancy +1R at 10%/trade, 2 trades → (1.1)^2 = 1.21; 3 trades → 1.331.
        #expect(abs(StockSageJournal.projectGrowth(expectancyR: 1.0, trades: 2, fraction: 0.10)!.multiple - 1.21) < 1e-9)
        #expect(abs(StockSageJournal.projectGrowth(expectancyR: 1.0, trades: 3, fraction: 0.10)!.multiple - 1.331) < 1e-9)
        // Negative expectancy shrinks the account: −1R at 10%, 2 trades → 0.9^2 = 0.81.
        #expect(abs(StockSageJournal.projectGrowth(expectancyR: -1.0, trades: 2, fraction: 0.10)!.multiple - 0.81) < 1e-9)
        // Guards: no trades, and a wipeout step (1 + 0.01·−200 = −1 ≤ 0) → nil.
        #expect(StockSageJournal.projectGrowth(expectancyR: 1, trades: 0) == nil)
        #expect(StockSageJournal.projectGrowth(expectancyR: -200, trades: 2, fraction: 0.01) == nil)
    }

    @Test func projectGrowthNearWipeoutStaysFiniteAndGuardsZeroStep() {
        // step = 1 + 0.01·(−99) = 0.01 → ×0.01² = 0.0001 (survives, tiny).
        #expect(abs(StockSageJournal.projectGrowth(expectancyR: -99, trades: 2, fraction: 0.01)!.multiple - 0.0001) < 1e-12)
        // step = 1 + 0.01·(−100) = 0 → wipeout guard → nil (no 0^n weirdness).
        #expect(StockSageJournal.projectGrowth(expectancyR: -100, trades: 2, fraction: 0.01) == nil)
    }

    @Test func compoundingCurveSingleTrade() {
        let c = StockSageJournal.compoundingCurve(seq([2]), fraction: 0.01)!
        #expect(c.multiples.count == 1)
        #expect(abs(c.finalMultiple - 1.02) < 1e-9)
    }

    @Test func compoundingCurveCompoundsLoggedR() {
        // R = [+2, −1, +1] at 1%/trade → ×1.02, then ×1.02·0.99 = ×1.0098,
        // then ×1.0098·1.01 = ×1.019898.
        let c = StockSageJournal.compoundingCurve(seq([2, -1, 1]), fraction: 0.01)!
        #expect(c.multiples.count == 3)
        #expect(abs(c.multiples[0] - 1.02) < 1e-9)
        #expect(abs(c.multiples[1] - 1.0098) < 1e-9)
        #expect(abs(c.finalMultiple - 1.019898) < 1e-9)
        #expect(StockSageJournal.compoundingCurve([]) == nil)
    }

    @Test func yearlyPnLRollsUpDollarsAndR() {
        var cal = Calendar(identifier: .gregorian); cal.timeZone = TimeZone(identifier: "UTC")!
        func tr(_ entry: Double, _ exit: Double, _ shares: Double, year: Int) -> TradeRecord {
            let d = cal.date(from: DateComponents(year: year, month: 6, day: 15))!
            return TradeRecord(symbol: "X", side: .long, entry: entry, stop: 90, target: nil, shares: shares,
                               openedAt: d.addingTimeInterval(-86_400), exitPrice: exit, closedAt: d)
        }
        // 2025: +100 (entry100→110×10, R+1) and −50 (→95×10, R−0.5). 2026: +100 (→120×5, R+2).
        let y = StockSageJournal.yearlyPnL([tr(100, 110, 10, year: 2025),
                                            tr(100, 95, 10, year: 2025),
                                            tr(100, 120, 5, year: 2026)])
        #expect(y.map(\.year) == ["2026", "2025"])             // newest first
        let y25 = y.first { $0.year == "2025" }!
        #expect(y25.trades == 2 && y25.wins == 1)
        #expect(abs(y25.realizedDollars - 50) < 1e-9)          // 100 − 50
        #expect(abs(y25.totalR - 0.5) < 1e-9)                  // 1 − 0.5
        #expect(abs(y25.winRate - 0.5) < 1e-9)
        let y26 = y.first { $0.year == "2026" }!
        #expect(abs(y26.realizedDollars - 100) < 1e-9)
        #expect(abs(y26.totalR - 2) < 1e-9)
        #expect(y26.winRate == 1.0)
        #expect(StockSageJournal.yearlyPnL([]).isEmpty)
    }

    private func closedInMonth(_ y: Int, _ m: Int, exit: Double) -> TradeRecord {
        var cal = Calendar(identifier: .gregorian); cal.timeZone = TimeZone(identifier: "UTC")!
        let d = cal.date(from: DateComponents(year: y, month: m, day: 15))!
        return TradeRecord(symbol: "X", side: .long, entry: 100, stop: 90, target: nil, shares: 1,
                           openedAt: d.addingTimeInterval(-86_400), exitPrice: exit, closedAt: d)
    }

    @Test func systemHealthDecisionTable() {
        typealias H = StockSageJournal
        // Negative: PF<1 or expectancy<0 (regardless of n).
        #expect(H.classifyHealth(profitFactor: 0.8, expectancyR: -0.2, significant: true, n: 50, maxDrawdownR: 3).verdict == .negative)
        #expect(H.classifyHealth(profitFactor: 1.2, expectancyR: -0.1, significant: true, n: 50, maxDrawdownR: 3).verdict == .negative)
        // Unproven: profitable but too few or not significant.
        #expect(H.classifyHealth(profitFactor: 2, expectancyR: 0.5, significant: false, n: 50, maxDrawdownR: 2).verdict == .unproven)
        #expect(H.classifyHealth(profitFactor: 2, expectancyR: 0.5, significant: true, n: 10, maxDrawdownR: 2).verdict == .unproven)
        // Strong: significant, PF≥1.5, contained DD (and no-losses ⇒ ∞ PF strong).
        #expect(H.classifyHealth(profitFactor: 1.8, expectancyR: 0.4, significant: true, n: 50, maxDrawdownR: 3).verdict == .strong)
        #expect(H.classifyHealth(profitFactor: nil, expectancyR: 1.0, significant: true, n: 30, maxDrawdownR: 0).verdict == .strong)
        // Developing: significant + profitable but thin PF, or a deep drawdown.
        #expect(H.classifyHealth(profitFactor: 1.2, expectancyR: 0.2, significant: true, n: 50, maxDrawdownR: 3).verdict == .developing)
        #expect(H.classifyHealth(profitFactor: 2.0, expectancyR: 0.5, significant: true, n: 50, maxDrawdownR: 12).verdict == .developing)
    }

    @Test func systemHealthWiringAndEmpty() {
        // 20 flat +1R wins → significant (0 variance), no losses (∞ PF), DD 0 → Strong.
        let strong = StockSageJournal.systemHealth(Array(repeating: closedR(1), count: 20))!
        #expect(strong.verdict == .strong)
        #expect(StockSageJournal.systemHealth([]) == nil)
    }

    @Test func bySideSplitsLongAndShort() {
        let trades = [
            tSym("A", .long, entry: 100, stop: 90, shares: 1, exit: 120),    // long +2R win
            tSym("B", .long, entry: 100, stop: 90, shares: 1, exit: 90),     // long −1R loss
            tSym("C", .short, entry: 100, stop: 110, shares: 1, exit: 70),   // short +3R win
        ]
        let s = StockSageJournal.bySide(trades)
        #expect(s.count == 2)
        let long = s.first { $0.side == .long }!
        #expect(long.trades == 2 && long.wins == 1)
        #expect(abs(long.totalR - 1.0) < 1e-9 && abs(long.avgR - 0.5) < 1e-9 && abs(long.winRate - 0.5) < 1e-9)
        let short = s.first { $0.side == .short }!
        #expect(short.trades == 1 && short.wins == 1)
        #expect(abs(short.totalR - 3.0) < 1e-9 && short.winRate == 1.0)
        #expect(StockSageJournal.bySide([]).isEmpty)
    }

    @Test func monthlyPnLGroupsByCloseMonthNewestFirst() {
        // June: +2R & −1R (2 trades, +1R); May: +3R (1 trade).
        let trades = [closedInMonth(2026, 6, exit: 120), closedInMonth(2026, 6, exit: 90),
                      closedInMonth(2026, 5, exit: 130)]
        let m = StockSageJournal.monthlyPnL(trades)
        #expect(m.count == 2)
        #expect(m[0].month == "2026-06" && m[0].trades == 2 && abs(m[0].totalR - 1.0) < 1e-9)
        #expect(m[1].month == "2026-05" && m[1].trades == 1 && abs(m[1].totalR - 3.0) < 1e-9)
        #expect(StockSageJournal.monthlyPnL([]).isEmpty)
    }

    @Test func kellyInputsFromJournalNeedSampleAndBothSides() {
        // 6 wins of +2R, 4 losses of −1R → W 0.6, payoff 2/1 = 2.0, n 10.
        let trades = Array(repeating: closedR(2), count: 6) + Array(repeating: closedR(-1), count: 4)
        let k = StockSageJournal.kellyInputs(trades)!
        #expect(abs(k.winRate - 0.6) < 1e-9)
        #expect(abs(k.payoffRatio - 2.0) < 1e-9)
        #expect(k.n == 10)
        // Under 10 closed → nil.
        #expect(StockSageJournal.kellyInputs(Array(repeating: closedR(2), count: 5) + Array(repeating: closedR(-1), count: 3)) == nil)
        // No losses → nil (can't form a payoff).
        #expect(StockSageJournal.kellyInputs(Array(repeating: closedR(2), count: 12)) == nil)
    }

    @Test func expectancyTrendDirection() {
        // ordered early [0,0,0] mean 0, recent [1,1,1] mean 1 → delta +1 > band → improving.
        let up = StockSageJournal.expectancyTrend(seq([0, 0, 0, 1, 1, 1]))!
        #expect(up.direction == .improving)
        #expect(abs(up.earlyR) < 1e-9 && abs(up.recentR - 1) < 1e-9 && abs(up.delta - 1) < 1e-9)
        #expect(StockSageJournal.expectancyTrend(seq([2, 2, 2, 0, 0, 0]))!.direction == .fading)
        #expect(StockSageJournal.expectancyTrend(seq([1, 1, 1, 1, 1, 1]))!.direction == .flat)
        #expect(StockSageJournal.expectancyTrend(seq([1, 1, 1, 1, 1])) == nil)   // <6 closed
    }

    @Test func equityRiskRunAndDrawdown() {
        // ordered R: +3,−1,−1,−1,+1 → worst run 3 losses; cumR 3,2,1,0,1 → max DD 3R.
        let r = StockSageJournal.equityRisk(seq([3, -1, -1, -1, 1]))!
        #expect(r.maxConsecutiveLosses == 3)
        #expect(abs(r.maxDrawdownR - 3.0) < 1e-9)
        #expect(StockSageJournal.equityRisk([]) == nil)
    }

    @Test func rDistributionPartitionsEachTradeOnce() {
        // bins (−∞,−1]·(−1,0]·(0,1]·(1,2]·(2,∞): −2,−1→b0; −0.5,0→b1; 0.5,1→b2; 1.5,2→b3; 3→b4.
        let trades = [-2.0, -1, -0.5, 0, 0.5, 1, 1.5, 2, 3].map { closedR($0) }
        let d = StockSageJournal.rDistribution(trades)!
        #expect(d.total == 9)
        #expect(d.bins.map(\.count) == [2, 2, 2, 2, 1])
        #expect(d.bins.map(\.count).reduce(0, +) == d.total)   // exactly one bin per trade
        #expect(d.bins.map(\.label) == ["≤−1R", "−1..0R", "0..1R", "1..2R", ">2R"])
        #expect(StockSageJournal.rDistribution([]) == nil)
    }

    @Test func tradesToSignificanceEstimate() {
        // rs = [4,−2,4,−2]: mean 1; sample var = 4·9/3 = 12; s = √12; needed = (2√12/1)² = 48.
        let r = StockSageJournal.tradesToSignificance([closedR(4), closedR(-2), closedR(4), closedR(-2)])!
        #expect(r.needed == 48)
        #expect(r.more == 44)        // 48 − 4 current
        // A zero-edge sample never confirms → nil.
        #expect(StockSageJournal.tradesToSignificance([closedR(1), closedR(-1)]) == nil)
        // <2 trades → nil.
        #expect(StockSageJournal.tradesToSignificance([closedR(2)]) == nil)
    }

    @Test func noisyZeroMeanSampleIsNotSignificant() {
        // rs = [1,1,−1,−1]: mean 0; var = 4/3; stdev 1.1547; stderr /√4 = 0.5774 > |mean|.
        let c = StockSageJournal.expectancyConfidence([closedR(1), closedR(1), closedR(-1), closedR(-1)])!
        #expect(abs(c.expectancyR) < 1e-9)
        #expect(abs(c.stdErrR - (4.0 / 3).squareRoot() / 2) < 1e-9)
        #expect(!c.isSignificant)
        #expect(StockSageJournal.expectancyConfidence([closedR(1)]) == nil)   // n < 2
    }

    @Test func streakFindsBestWorstAndCurrentRun() {
        // By close time: AAPL +2R, MSFT +1R, JPM −1R, XOM −0.5R → 2-loss streak.
        let trades = [
            closedAt("AAPL", exit: 120, at: 100),   // +2R
            closedAt("MSFT", exit: 110, at: 200),   // +1R
            closedAt("JPM", exit: 90, at: 300),     // −1R
            closedAt("XOM", exit: 95, at: 400),     // −0.5R
        ]
        let s = StockSageJournal.streak(trades)!
        #expect(abs(s.bestR - 2.0) < 1e-9 && s.bestSymbol == "AAPL")
        #expect(abs(s.worstR - (-1.0)) < 1e-9 && s.worstSymbol == "JPM")
        #expect(s.streakCount == 2 && s.streakIsWin == false)   // XOM, JPM are the trailing losses
    }

    @Test func streakCountsAWinningRun() {
        let trades = [closedAt("A", exit: 90, at: 100),    // −1R
                      closedAt("B", exit: 120, at: 200),   // +2R
                      closedAt("C", exit: 110, at: 300)]   // +1R
        let s = StockSageJournal.streak(trades)!
        #expect(s.streakCount == 2 && s.streakIsWin == true)   // B, C trailing wins
        #expect(StockSageJournal.streak([]) == nil)
    }

    @Test func bySectorGroupsAndSortsByTotalR() {
        let trades = [
            tSym("AAPL", .long, entry: 100, stop: 90, shares: 1, exit: 120),  // Tech +2R win
            tSym("AAPL", .long, entry: 100, stop: 90, shares: 1, exit: 90),   // Tech −1R loss
            tSym("JPM", .long, entry: 100, stop: 90, shares: 1, exit: 130),   // Financials +3R win
            tSym("MSFT", .long, entry: 100, stop: 90, shares: 1),             // Tech, open → excluded
        ]
        let s = StockSageJournal.bySector(trades)
        #expect(s.count == 2)
        #expect(s.first?.sector == "Financials")        // totalR 3 > 1 → first
        #expect(s.first?.totalR == 3 && s.first?.trades == 1 && s.first?.wins == 1)
        let tech = s.first { $0.sector == "Technology" }!
        #expect(tech.trades == 2 && tech.wins == 1)
        #expect(abs(tech.totalR - 1.0) < 1e-9)          // +2 −1
        #expect(abs(tech.winRate - 0.5) < 1e-9)
        #expect(StockSageJournal.bySector([]).isEmpty)
    }

    @Test func profitFactorIsGrossWinOverGrossLoss() {
        let trades = [
            t(.long, entry: 100, stop: 90, shares: 1, exit: 120),   // +2R
            t(.long, entry: 100, stop: 90, shares: 1, exit: 110),   // +1R
            t(.long, entry: 100, stop: 90, shares: 1, exit: 90),    // −1R
        ]
        #expect(abs(StockSageJournal.edge(trades).profitFactor! - 3.0) < 1e-9)   // (2+1)/1
        // No losses yet → nil (not Inf).
        #expect(StockSageJournal.edge([t(.long, entry: 100, stop: 90, shares: 1, exit: 120)]).profitFactor == nil)
    }

    @Test func edgeWithNoLossesHasZeroPayoffNotInfinity() {
        let onlyWins = [t(.long, entry: 100, stop: 90, shares: 1, exit: 120)]
        let e = StockSageJournal.edge(onlyWins)
        #expect(e.payoffRatio == 0)        // guarded, not inf/NaN
        #expect(StockSageJournal.edge([]).closedWithR == 0)
    }

    @Test func statsOverClosedTradesOnly() {
        let trades = [
            t(.long, entry: 100, stop: 90, shares: 1, exit: 120),   // +2R win
            t(.long, entry: 100, stop: 90, shares: 1, exit: 90),    // −1R loss
            t(.long, entry: 100, stop: 90, shares: 1),              // open → excluded
        ]
        let s = StockSageJournal.stats(trades)
        #expect(s.closed == 2)
        #expect(s.wins == 1)
        #expect(s.winRate == 0.5)
        #expect(s.totalR == 1.0)        // +2 −1
        #expect(s.avgR == 0.5)
        #expect(StockSageJournal.stats([]).closed == 0)
    }
}
