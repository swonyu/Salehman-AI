import Testing
import Foundation
@testable import Salehman_AI

// MARK: - Loss-limit circuit breaker (pure) — the halt-after-a-bad-run guardrail.
// Deterministic via injected `now`; entry 100 / stop 90 so exit = 100 + r·10 gives R == r.

struct StockSageLossLimitTests {
    typealias LL = StockSageLossLimit

    private let cal = Calendar.current
    private var dayStart: Date { cal.startOfDay(for: Date(timeIntervalSince1970: 1_700_000_000)) }
    private var now: Date { cal.date(byAdding: .hour, value: 12, to: dayStart)! }   // midday
    private func todayAt(_ hoursBeforeNow: Int) -> Date { cal.date(byAdding: .hour, value: -hoursBeforeNow, to: now)! }
    private var yesterday: Date { cal.date(byAdding: .hour, value: -2, to: dayStart)! }  // before midnight

    /// A CLOSED long with realized R == r (profit = r·10·shares), or OPEN when closedAt is nil.
    private func t(_ r: Double, shares: Double = 10, closedAt: Date?) -> TradeRecord {
        TradeRecord(symbol: "X", side: .long, entry: 100, stop: 90, target: 130, shares: shares,
                    openedAt: Date(timeIntervalSince1970: 0),
                    exitPrice: closedAt == nil ? nil : 100 + r * 10, closedAt: closedAt)
    }

    @Test func profitableDayIsOk() {
        let s = LL.evaluate(closedTrades: [t(2, closedAt: now)],
                            policy: LossLimitPolicy(maxDailyLoss: 150), now: now)
        #expect(s.status == .ok && abs(s.dailyRealized - 200) < 1e-9)
    }

    @Test func dailyDollarLossHalts() {
        let s = LL.evaluate(closedTrades: [t(-1, closedAt: now), t(-1, closedAt: todayAt(1))],
                            policy: LossLimitPolicy(maxDailyLoss: 150, standDownLossRun: 0), now: now)
        #expect(s.status == .halted && abs(s.dailyRealized + 200) < 1e-9)
        #expect(s.haltReason?.lowercased().contains("daily") == true)
    }

    @Test func warnBandAtSeventyPercent() {
        // −$100 vs a $130 limit → 77% of the limit → warn (not yet halted).
        let s = LL.evaluate(closedTrades: [t(-1, closedAt: now)],
                            policy: LossLimitPolicy(maxDailyLoss: 130, standDownLossRun: 0), now: now)
        #expect(s.status == .warn)
    }

    @Test func threeLossStreakStandsDown() {
        let s = LL.evaluate(closedTrades: [t(-1, closedAt: now), t(-1, closedAt: todayAt(1)), t(-1, closedAt: todayAt(2))],
                            policy: LossLimitPolicy(standDownLossRun: 3), now: now)
        #expect(s.lossRun == 3 && s.status == .halted)
        #expect(s.haltReason?.lowercased().contains("streak") == true)
    }

    @Test func breakevenScratchBreaksTheRun() {
        // recency: loss, then breakeven (R==0) → run stops at 1.
        let s = LL.evaluate(closedTrades: [t(-1, closedAt: now), t(0, closedAt: todayAt(1)), t(-1, closedAt: todayAt(2))],
                            policy: LossLimitPolicy(standDownLossRun: 3), now: now)
        #expect(s.lossRun == 1 && s.status == .ok)
    }

    @Test func yesterdaysLossExcludedFromTodayTally() {
        let s = LL.evaluate(closedTrades: [t(-5, closedAt: yesterday)],
                            policy: LossLimitPolicy(maxDailyLoss: 100, standDownLossRun: 0), now: now)
        #expect(abs(s.dailyRealized) < 1e-9 && s.status == .ok)   // not counted today
    }

    @Test func openTradesContributeNothing() {
        let s = LL.evaluate(closedTrades: [t(-1, closedAt: nil)],
                            policy: LossLimitPolicy(maxDailyLoss: 100), now: now)
        #expect(abs(s.dailyRealized) < 1e-9 && s.lossRun == 0 && s.status == .ok)
    }
}
