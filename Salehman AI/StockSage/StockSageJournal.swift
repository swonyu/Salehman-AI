import Foundation
import Combine

// MARK: - Trade journal (records the OWNER's decisions; not advice)
//
// The backtester answers "would the rules have worked?"; the journal answers
// "what did I actually do, and how is it going?" Each record is a trade the owner
// chose to take — entry, protective stop, optional target, size — with an optional
// close. P&L and R-multiple are computed PURELY off those numbers so the math is
// testable and honest: R = profit ÷ the risk you defined at entry (entry→stop).

struct TradeRecord: Codable, Sendable, Equatable, Identifiable {
    enum Side: String, Codable, Sendable, CaseIterable {
        case long = "Long"
        case short = "Short"
    }
    let id: UUID
    let symbol: String
    let side: Side
    let entry: Double
    let stop: Double
    let target: Double?
    let shares: Double
    let openedAt: Date
    var exitPrice: Double?
    var closedAt: Date?
    /// Optional free-text note. Optional + defaulted so older persisted records
    /// (encoded before this field existed) still decode cleanly.
    var note: String?

    init(id: UUID = UUID(), symbol: String, side: Side, entry: Double, stop: Double,
         target: Double?, shares: Double, openedAt: Date,
         exitPrice: Double? = nil, closedAt: Date? = nil, note: String? = nil) {
        self.id = id; self.symbol = symbol; self.side = side
        self.entry = entry; self.stop = stop; self.target = target
        self.shares = shares; self.openedAt = openedAt
        self.exitPrice = exitPrice; self.closedAt = closedAt; self.note = note
    }

    nonisolated var isOpen: Bool { closedAt == nil }

    /// Risk per share defined at entry (entry→stop distance).
    nonisolated var riskPerShare: Double { abs(entry - stop) }

    /// P&L at a given mark price (sign respects side).
    nonisolated func profit(at price: Double) -> Double {
        side == .long ? (price - entry) * shares : (entry - price) * shares
    }

    /// R-multiple at a mark price = profit-per-share ÷ risk-per-share. nil if the
    /// stop equals entry (no defined risk → R is undefined, not infinite).
    nonisolated func rMultiple(at price: Double) -> Double? {
        let risk = riskPerShare
        guard risk > 0 else { return nil }
        let perShare = side == .long ? (price - entry) : (entry - price)
        return perShare / risk
    }

    nonisolated var realizedProfit: Double? { exitPrice.map { profit(at: $0) } }
    nonisolated var realizedR: Double? { exitPrice.flatMap { rMultiple(at: $0) } }
}

/// Aggregate stats over the CLOSED trades — the owner's realized track record.
struct JournalStats: Sendable, Equatable {
    let closed: Int
    let wins: Int
    let winRate: Double
    let totalR: Double
    let totalProfit: Double
    let avgR: Double
}

/// The EDGE decomposition over closed trades — why the expectancy is what it is.
struct JournalEdge: Sendable, Equatable {
    let avgWinR: Double        // average R of winning trades (R > 0)
    let avgLossR: Double       // average R of losing trades, as a POSITIVE magnitude
    let payoffRatio: Double    // avgWinR ÷ avgLossR (0 if no losses yet)
    let expectancyR: Double    // R you make per trade on average (= mean realized R)
    let closedWithR: Int       // closed trades with a defined R
    let profitFactor: Double?  // Σ winning R ÷ Σ |losing R|; nil with no losses yet
}

/// The shape of realized R outcomes across ordered bins.
struct RDistribution: Sendable, Equatable {
    struct Bin: Sendable, Equatable, Identifiable {
        let label: String
        let count: Int
        var id: String { label }
    }
    let bins: [Bin]    // ordered: ≤−1, −1..0, 0..1, 1..2, >2
    let total: Int
}

/// Realized performance split by trade side (long vs short).
struct SidePnL: Sendable, Equatable, Identifiable {
    let side: TradeRecord.Side
    let trades: Int
    let wins: Int
    let totalR: Double
    let avgR: Double
    let winRate: Double
    var id: String { side.rawValue }
}

/// Realized R for one calendar month (closed trades).
struct MonthlyPnL: Sendable, Equatable, Identifiable {
    let month: String   // "YYYY-MM" (UTC)
    let trades: Int
    let totalR: Double
    var id: String { month }
}

/// Realized performance for one calendar year (closed trades) — for record-keeping.
struct YearlyPnL: Sendable, Equatable, Identifiable {
    let year: String            // "YYYY" (UTC)
    let trades: Int
    let wins: Int
    let winRate: Double         // 0–1
    let realizedDollars: Double // sum of realized P&L (account currency)
    let totalR: Double
    var id: String { year }
}

/// Realized performance for one sector (closed trades).
struct SectorPnL: Sendable, Equatable, Identifiable {
    let sector: String
    let trades: Int
    let wins: Int
    let totalR: Double
    let winRate: Double
    var id: String { sector }
}

/// Best/worst closed trade + the current consecutive win-or-loss streak.
struct JournalStreak: Sendable, Equatable {
    let bestR: Double
    let bestSymbol: String
    let worstR: Double
    let worstSymbol: String
    let streakCount: Int     // consecutive most-recent same-result trades (0 if none decisive)
    let streakIsWin: Bool    // true = winning streak
}

/// The expectancy with its sampling error — so a thin record reads as noise.
struct ExpectancyCI: Sendable, Equatable {
    let expectancyR: Double   // mean realized R
    let stdErrR: Double       // sample stdev ÷ √n
    let n: Int
    /// Distinguishable from zero only when the mean is ≥1 standard error away.
    nonisolated var isSignificant: Bool { abs(expectancyR) >= stdErrR }

    nonisolated var note: String {
        let tail = isSignificant ? "" : " — not yet distinguishable from zero (thin/noisy sample)"
        return String(format: "Expectancy %+.2fR ± %.2fR (n=%d)%@", expectancyR, stdErrR, n, tail)
    }
}

/// Average days held for winners vs losers — the "cut winners early / ride losers" check.
struct HoldingPeriod: Sendable, Equatable {
    let avgWinDays: Double
    let avgLossDays: Double
    let winCount: Int
    let lossCount: Int

    /// The classic discipline leak: holding winners SHORTER than losers.
    nonisolated var ridingLosers: Bool { winCount > 0 && lossCount > 0 && avgWinDays < avgLossDays }

    nonisolated var note: String {
        let base = String(format: "Avg hold: winners %.0fd vs losers %.0fd", avgWinDays, avgLossDays)
        guard winCount > 0, lossCount > 0 else { return base + "." }
        if avgWinDays < avgLossDays { return base + " — you cut winners early / ride losers." }
        if avgWinDays > avgLossDays { return base + " — you give winners room and cut losers fast." }
        return base + "."
    }
}

/// The owner's realized equity-curve risk: worst losing run + deepest drawdown.
struct JournalRisk: Sendable, Equatable {
    let maxConsecutiveLosses: Int
    let maxDrawdownR: Double   // worst peak→trough of cumulative R (positive magnitude)
}

/// An honest one-glance verdict on the journal's realized track record.
struct SystemHealth: Sendable, Equatable {
    enum Verdict: String, Sendable {
        case negative = "Negative"      // losing
        case unproven = "Unproven"      // too few / not significant
        case developing = "Developing"  // real but not yet robust
        case strong = "Strong"          // significant + healthy PF + contained DD
    }
    let verdict: Verdict
    let reason: String
}

/// Is the edge improving or fading? Recent-half mean R vs first-half mean R.
struct ExpectancyTrend: Sendable, Equatable {
    enum Direction: String, Sendable {
        case improving = "improving"
        case fading = "fading"
        case flat = "flat"
    }
    let earlyR: Double      // mean R of the FIRST half (by close time)
    let recentR: Double     // mean R of the most-recent half
    let direction: Direction
    nonisolated var delta: Double { recentR - earlyR }
}

/// A HYPOTHETICAL forward projection of account growth from the measured edge.
struct GrowthProjection: Sendable, Equatable {
    let expectancyR: Double   // measured mean R per closed trade
    let fraction: Double      // risk per trade
    let trades: Int           // future trades modeled
    let multiple: Double      // ×(1 + fraction·expectancyR)^trades
}

/// The account-growth multiple your logged R produced, compounded at a fixed risk %.
struct CompoundingCurve: Sendable, Equatable {
    let multiples: [Double]   // running growth multiple after each closed trade
    let fraction: Double      // risk per trade (e.g. 0.01 = 1%)
    nonisolated var finalMultiple: Double { multiples.last ?? 1 }
}

enum StockSageJournal {
    /// Compounding curve: starting at ×1, each closed trade (by close time) multiplies
    /// the account by (1 + fraction·R). Clamped at 0 (ruin is absorbing). Pure — this
    /// is the PAST path of the owner's OWN trades at a fixed risk %, NOT a projection.
    nonisolated static func compoundingCurve(_ trades: [TradeRecord], fraction: Double = 0.01) -> CompoundingCurve? {
        let rs = trades.filter { !$0.isOpen }
            .sorted { ($0.closedAt ?? .distantPast) < ($1.closedAt ?? .distantPast) }
            .compactMap { $0.realizedR }
        guard !rs.isEmpty else { return nil }
        var mult = 1.0
        var out: [Double] = []
        out.reserveCapacity(rs.count)
        for r in rs {
            mult = Swift.max(0, mult * (1 + fraction * r))
            out.append(mult)
        }
        return CompoundingCurve(multiples: out, fraction: fraction)
    }

    /// Realized P&L rolled up by calendar year (UTC) — $ + R + win-rate + count, newest
    /// first. Closed trades only. For the owner's own record-keeping; NOT tax advice.
    nonisolated static func yearlyPnL(_ trades: [TradeRecord]) -> [YearlyPnL] {
        var cal = Calendar(identifier: .gregorian); cal.timeZone = TimeZone(identifier: "UTC")!
        var byYear: [String: [TradeRecord]] = [:]
        for t in trades where !t.isOpen {
            guard let c = t.closedAt else { continue }
            byYear[String(cal.component(.year, from: c)), default: []].append(t)
        }
        return byYear.map { year, ts in
            let wins = ts.filter { ($0.realizedProfit ?? 0) > 0 }.count
            return YearlyPnL(year: year, trades: ts.count, wins: wins,
                             winRate: ts.isEmpty ? 0 : Double(wins) / Double(ts.count),
                             realizedDollars: ts.compactMap(\.realizedProfit).reduce(0, +),
                             totalR: ts.compactMap(\.realizedR).reduce(0, +))
        }.sorted { $0.year > $1.year }
    }

    /// A HYPOTHETICAL forward account multiple: compound the measured expectancy (R/trade)
    /// over `trades` future trades at risk `fraction` — ×(1 + fraction·expectancyR)^trades.
    /// nil for non-positive trades/fraction or a wipeout step (1 + f·e ≤ 0). This is NOT a
    /// prediction — it assumes the past edge persists and ignores variance (which lowers it).
    nonisolated static func projectGrowth(expectancyR: Double, trades: Int, fraction: Double = 0.01) -> GrowthProjection? {
        let step = 1 + fraction * expectancyR
        guard trades > 0, fraction > 0, step > 0 else { return nil }
        return GrowthProjection(expectancyR: expectancyR, fraction: fraction, trades: trades,
                                multiple: pow(step, Double(trades)))
    }

    /// Expectancy trend: mean R of the first half vs the most-recent half of closed
    /// trades (by close time). `band` = the flat zone. nil under 6 closed-with-R.
    nonisolated static func expectancyTrend(_ trades: [TradeRecord], band: Double = 0.10) -> ExpectancyTrend? {
        let rs = trades.filter { !$0.isOpen }
            .sorted { ($0.closedAt ?? .distantPast) < ($1.closedAt ?? .distantPast) }
            .compactMap { $0.realizedR }
        guard rs.count >= 6 else { return nil }
        let half = rs.count / 2
        let early = Array(rs.prefix(half))
        let recent = Array(rs.suffix(rs.count - half))
        let earlyR = early.reduce(0, +) / Double(early.count)
        let recentR = recent.reduce(0, +) / Double(recent.count)
        let delta = recentR - earlyR
        let dir: ExpectancyTrend.Direction = delta > band ? .improving : (delta < -band ? .fading : .flat)
        return ExpectancyTrend(earlyR: earlyR, recentR: recentR, direction: dir)
    }

    /// Classify track-record health from the already-computed stats. Pure decision
    /// table so the thresholds are unit-tested in isolation. `deepDrawdownR` = the
    /// peak→trough R that downgrades an otherwise-strong system.
    nonisolated static func classifyHealth(profitFactor: Double?, expectancyR: Double, significant: Bool,
                                           n: Int, maxDrawdownR: Double,
                                           minTrades: Int = 20, deepDrawdownR: Double = 8) -> SystemHealth {
        let pfStr = profitFactor.map { String(format: "%.2f", $0) } ?? "∞"
        let ddStr = String(format: "%.1f", maxDrawdownR)
        let expStr = String(format: "%+.2f", expectancyR)

        if expectancyR < 0 || (profitFactor.map { $0 < 1 } ?? false) {
            return SystemHealth(verdict: .negative,
                                reason: "Losing so far (PF \(pfStr), expectancy \(expStr)R). Cut size or stand down.")
        }
        if n < minTrades || !significant {
            return SystemHealth(verdict: .unproven,
                                reason: "Too little to trust (n=\(n)\(significant ? "" : ", not significant")). Keep logging before sizing up.")
        }
        let pfStrong = profitFactor.map { $0 >= 1.5 } ?? true   // no losses ⇒ effectively ∞
        if pfStrong && maxDrawdownR < deepDrawdownR {
            return SystemHealth(verdict: .strong,
                                reason: "Significant edge — PF \(pfStr), expectancy \(expStr)R over \(n), worst DD −\(ddStr)R.")
        }
        return SystemHealth(verdict: .developing,
                            reason: maxDrawdownR >= deepDrawdownR
                                ? "Real edge but a deep −\(ddStr)R drawdown (PF \(pfStr), n=\(n)) — robust? not proven."
                                : "Real but thin edge (PF \(pfStr), significant, n=\(n)) — promising, keep building.")
    }

    /// System health over the journal's closed trades. nil with no closed-with-R.
    nonisolated static func systemHealth(_ trades: [TradeRecord], minTrades: Int = 20) -> SystemHealth? {
        let rs = trades.filter { !$0.isOpen }.compactMap { $0.realizedR }
        guard !rs.isEmpty else { return nil }
        let e = edge(trades)
        return classifyHealth(profitFactor: e.profitFactor, expectancyR: e.expectancyR,
                              significant: expectancyConfidence(trades)?.isSignificant ?? false,
                              n: rs.count, maxDrawdownR: equityRisk(trades)?.maxDrawdownR ?? 0,
                              minTrades: minTrades)
    }

    /// Kelly inputs (win-rate, payoff) from the OWNER's own closed trades. Requires
    /// a meaningful sample (≥`minTrades`) AND at least one win and one loss to form
    /// an honest payoff. nil otherwise — never size off 3 lucky trades.
    nonisolated static func kellyInputs(_ trades: [TradeRecord], minTrades: Int = 10)
        -> (winRate: Double, payoffRatio: Double, n: Int)? {
        let rs = trades.filter { !$0.isOpen }.compactMap { $0.realizedR }
        guard rs.count >= minTrades else { return nil }
        let wins = rs.filter { $0 > 0 }
        let losses = rs.filter { $0 < 0 }
        guard !wins.isEmpty, !losses.isEmpty else { return nil }
        let winRate = Double(wins.count) / Double(rs.count)
        let avgWin = wins.reduce(0, +) / Double(wins.count)
        let avgLossMag = -losses.reduce(0, +) / Double(losses.count)
        guard let inp = StockSageKelly.inputs(winRate: winRate, avgWinR: avgWin, avgLossR: avgLossMag) else { return nil }
        return (inp.winRate, inp.payoffRatio, rs.count)
    }

    /// Worst consecutive losing run and max drawdown (in R) over CLOSED trades
    /// ordered by close time — the same drawdown math the backtester uses, applied
    /// to the OWNER's own record. nil with no closed-with-R trades.
    nonisolated static func equityRisk(_ trades: [TradeRecord]) -> JournalRisk? {
        let ordered = trades.filter { !$0.isOpen }
            .sorted { ($0.closedAt ?? .distantPast) < ($1.closedAt ?? .distantPast) }
        let rs = ordered.compactMap { $0.realizedR }
        guard !rs.isEmpty else { return nil }

        var maxRun = 0, run = 0
        for r in rs {
            if r < 0 { run += 1; maxRun = Swift.max(maxRun, run) } else { run = 0 }
        }
        var cum = 0.0, peak = 0.0, maxDD = 0.0
        for r in rs { cum += r; peak = Swift.max(peak, cum); maxDD = Swift.max(maxDD, peak - cum) }
        return JournalRisk(maxConsecutiveLosses: maxRun, maxDrawdownR: maxDD)
    }

    /// Average holding period (days) for winning vs losing closed trades. nil with
    /// no closed trades that carry both open/close timestamps.
    nonisolated static func holdingPeriod(_ trades: [TradeRecord]) -> HoldingPeriod? {
        func days(_ t: TradeRecord) -> Double? {
            t.closedAt.map { $0.timeIntervalSince(t.openedAt) / 86_400 }
        }
        let closed = trades.filter { !$0.isOpen }
        let wins = closed.filter { ($0.realizedProfit ?? 0) > 0 }.compactMap(days)
        let losses = closed.filter { ($0.realizedProfit ?? 0) < 0 }.compactMap(days)
        guard !wins.isEmpty || !losses.isEmpty else { return nil }
        return HoldingPeriod(
            avgWinDays: wins.isEmpty ? 0 : wins.reduce(0, +) / Double(wins.count),
            avgLossDays: losses.isEmpty ? 0 : losses.reduce(0, +) / Double(losses.count),
            winCount: wins.count, lossCount: losses.count)
    }

    /// Realized-R outcomes bucketed into 5 ordered bins so the SHAPE of results is
    /// visible, not just the average. Boundaries (each trade in exactly one bin):
    /// (−∞,−1] · (−1,0] · (0,1] · (1,2] · (2,∞) — lower-exclusive, upper-inclusive.
    nonisolated static func rDistribution(_ trades: [TradeRecord]) -> RDistribution? {
        let rs = trades.filter { !$0.isOpen }.compactMap { $0.realizedR }
        guard !rs.isEmpty else { return nil }
        var counts = [0, 0, 0, 0, 0]
        for r in rs {
            if r <= -1 { counts[0] += 1 }
            else if r <= 0 { counts[1] += 1 }
            else if r <= 1 { counts[2] += 1 }
            else if r <= 2 { counts[3] += 1 }
            else { counts[4] += 1 }
        }
        let labels = ["≤−1R", "−1..0R", "0..1R", "1..2R", ">2R"]
        return RDistribution(bins: zip(labels, counts).map { RDistribution.Bin(label: $0, count: $1) },
                             total: rs.count)
    }

    /// How many TOTAL and how many MORE trades to reach |mean R| ≥ z·stderr (z=2 ≈
    /// 95%): N ≥ (z·s/|mean|)². nil when the mean is ~0 (a zero edge never confirms)
    /// or <2 trades. A sample-size estimate, not a promise the edge survives.
    nonisolated static func tradesToSignificance(_ trades: [TradeRecord], z: Double = 2) -> (needed: Int, more: Int)? {
        let rs = trades.filter { !$0.isOpen }.compactMap { $0.realizedR }
        guard rs.count >= 2 else { return nil }
        let n = rs.count
        let mean = rs.reduce(0, +) / Double(n)
        guard abs(mean) > 1e-9 else { return nil }
        let variance = rs.reduce(0) { $0 + ($1 - mean) * ($1 - mean) } / Double(n - 1)
        let s = variance.squareRoot()
        guard s > 0 else { return (needed: n, more: 0) }   // no spread → already certain
        let ratio = z * s / abs(mean)
        let needed = Int((ratio * ratio).rounded(.up))
        return (needed: needed, more: Swift.max(0, needed - n))
    }

    /// Mean realized R with its standard error (sampleStdev/√n). nil for <2 trades
    /// with a defined R (no spread to estimate).
    nonisolated static func expectancyConfidence(_ trades: [TradeRecord]) -> ExpectancyCI? {
        let rs = trades.filter { !$0.isOpen }.compactMap { $0.realizedR }
        guard rs.count >= 2 else { return nil }
        let n = rs.count
        let mean = rs.reduce(0, +) / Double(n)
        let variance = rs.reduce(0) { $0 + ($1 - mean) * ($1 - mean) } / Double(n - 1)   // sample variance
        let stdErr = variance.squareRoot() / Double(n).squareRoot()
        return ExpectancyCI(expectancyR: mean, stdErrR: stdErr, n: n)
    }

    /// Best/worst realized trade and the current streak (by close time). Breakeven
    /// (R == 0) trades don't count toward the streak. nil with no closed-with-R trades.
    nonisolated static func streak(_ trades: [TradeRecord]) -> JournalStreak? {
        let closed = trades.filter { !$0.isOpen }.compactMap { t in t.realizedR.map { (t, $0) } }
        guard !closed.isEmpty else { return nil }
        let best = closed.max { $0.1 < $1.1 }!
        let worst = closed.min { $0.1 < $1.1 }!

        let ordered = closed.sorted { ($0.0.closedAt ?? .distantPast) < ($1.0.closedAt ?? .distantPast) }
        let decisive = ordered.filter { $0.1 != 0 }
        var count = 0
        var isWin = false
        if let last = decisive.last {
            isWin = last.1 > 0
            for (_, r) in decisive.reversed() {
                if (r > 0) != isWin { break }
                count += 1
            }
        }
        return JournalStreak(bestR: best.1, bestSymbol: best.0.symbol,
                             worstR: worst.1, worstSymbol: worst.0.symbol,
                             streakCount: count, streakIsWin: isWin)
    }

    nonisolated static func stats(_ trades: [TradeRecord]) -> JournalStats {
        let closed = trades.filter { !$0.isOpen }
        let rs = closed.compactMap { $0.realizedR }
        let profits = closed.compactMap { $0.realizedProfit }
        let wins = profits.filter { $0 > 0 }.count
        let totalR = rs.reduce(0, +)
        return JournalStats(
            closed: closed.count,
            wins: wins,
            winRate: closed.isEmpty ? 0 : Double(wins) / Double(closed.count),
            totalR: totalR,
            totalProfit: profits.reduce(0, +),
            avgR: rs.isEmpty ? 0 : totalR / Double(rs.count))
    }

    /// Edge decomposition: average win R, average loss R, payoff ratio, and the
    /// per-trade expectancy (winRate·avgWin − lossRate·avgLoss == mean realized R).
    nonisolated static func edge(_ trades: [TradeRecord]) -> JournalEdge {
        let rs = trades.filter { !$0.isOpen }.compactMap { $0.realizedR }
        let wins = rs.filter { $0 > 0 }
        let losses = rs.filter { $0 < 0 }
        let avgWin = wins.isEmpty ? 0 : wins.reduce(0, +) / Double(wins.count)
        let avgLossMag = losses.isEmpty ? 0 : -losses.reduce(0, +) / Double(losses.count)
        let grossWin = wins.reduce(0, +)
        let grossLoss = -losses.reduce(0, +)   // positive magnitude
        return JournalEdge(
            avgWinR: avgWin,
            avgLossR: avgLossMag,
            payoffRatio: avgLossMag > 0 ? avgWin / avgLossMag : 0,
            expectancyR: rs.isEmpty ? 0 : rs.reduce(0, +) / Double(rs.count),
            closedWithR: rs.count,
            profitFactor: grossLoss > 0 ? grossWin / grossLoss : nil)
    }

    /// Realized performance split LONG vs SHORT — are you actually good at shorting,
    /// or only making money long? Closed trades only; sides with no trades omitted.
    nonisolated static func bySide(_ trades: [TradeRecord]) -> [SidePnL] {
        let closed = trades.filter { !$0.isOpen }
        return TradeRecord.Side.allCases.compactMap { side in
            let ts = closed.filter { $0.side == side }
            guard !ts.isEmpty else { return nil }
            let rs = ts.compactMap { $0.realizedR }
            let wins = ts.filter { ($0.realizedProfit ?? 0) > 0 }.count
            return SidePnL(side: side, trades: ts.count, wins: wins,
                           totalR: rs.reduce(0, +),
                           avgR: rs.isEmpty ? 0 : rs.reduce(0, +) / Double(rs.count),
                           winRate: Double(wins) / Double(ts.count))
        }
    }

    /// Realized R grouped by close MONTH (UTC), most-recent first.
    nonisolated static func monthlyPnL(_ trades: [TradeRecord]) -> [MonthlyPnL] {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        var groups: [String: (count: Int, r: Double)] = [:]
        for t in trades where !t.isOpen {
            guard let closed = t.closedAt, let r = t.realizedR else { continue }
            let c = cal.dateComponents([.year, .month], from: closed)
            guard let y = c.year, let m = c.month else { continue }
            let key = String(format: "%04d-%02d", y, m)
            var g = groups[key] ?? (0, 0)
            g.count += 1; g.r += r
            groups[key] = g
        }
        return groups.map { MonthlyPnL(month: $0.key, trades: $0.value.count, totalR: $0.value.r) }
            .sorted { $0.month > $1.month }   // YYYY-MM string sort = chronological, newest first
    }

    /// Realized P&L grouped by the symbol's sector — which industries you actually
    /// make money in. Closed trades only, sorted by total R (best first).
    nonisolated static func bySector(_ trades: [TradeRecord]) -> [SectorPnL] {
        let closed = trades.filter { !$0.isOpen }
        var groups: [String: [TradeRecord]] = [:]
        for t in closed { groups[StockSageSector.sector(t.symbol), default: []].append(t) }
        return groups.map { sector, ts in
            let wins = ts.filter { ($0.realizedProfit ?? 0) > 0 }.count
            let totalR = ts.compactMap { $0.realizedR }.reduce(0, +)
            return SectorPnL(sector: sector, trades: ts.count, wins: wins, totalR: totalR,
                             winRate: ts.isEmpty ? 0 : Double(wins) / Double(ts.count))
        }
        .sorted { $0.totalR > $1.totalR }
    }

    nonisolated static let caveat =
        "Your own trade record — not advice. P&L/R are computed from the prices you entered; a journal documents decisions, it doesn't validate them."
}

// MARK: - Persisted journal store

@MainActor
final class StockSageJournalStore: ObservableObject {
    static let shared = StockSageJournalStore()

    @Published private(set) var trades: [TradeRecord] = []
    private let key = "stocksage.journal.v1"

    private init() { load() }

    var open: [TradeRecord] { trades.filter { $0.isOpen } }
    var closed: [TradeRecord] { trades.filter { !$0.isOpen } }
    var stats: JournalStats { StockSageJournal.stats(trades) }
    var edgeStats: JournalEdge { StockSageJournal.edge(trades) }
    var sectorPnL: [SectorPnL] { StockSageJournal.bySector(trades) }
    var monthlyPnL: [MonthlyPnL] { StockSageJournal.monthlyPnL(trades) }
    var yearlyPnL: [YearlyPnL] { StockSageJournal.yearlyPnL(trades) }
    var sideStats: [SidePnL] { StockSageJournal.bySide(trades) }
    var streakSummary: JournalStreak? { StockSageJournal.streak(trades) }
    var expectancyCI: ExpectancyCI? { StockSageJournal.expectancyConfidence(trades) }
    var holdingPeriod: HoldingPeriod? { StockSageJournal.holdingPeriod(trades) }
    var tradesToSignificance: (needed: Int, more: Int)? { StockSageJournal.tradesToSignificance(trades) }
    var rDistribution: RDistribution? { StockSageJournal.rDistribution(trades) }
    var equityRisk: JournalRisk? { StockSageJournal.equityRisk(trades) }
    var kellyInputs: (winRate: Double, payoffRatio: Double, n: Int)? { StockSageJournal.kellyInputs(trades) }
    var systemHealth: SystemHealth? { StockSageJournal.systemHealth(trades) }
    var expectancyTrend: ExpectancyTrend? { StockSageJournal.expectancyTrend(trades) }
    var compounding: CompoundingCurve? { StockSageJournal.compoundingCurve(trades) }

    func add(_ t: TradeRecord) {
        trades.insert(t, at: 0)
        save()
    }

    func close(_ id: UUID, exitPrice: Double, at date: Date = Date()) {
        guard exitPrice > 0, let i = trades.firstIndex(where: { $0.id == id }) else { return }
        trades[i].exitPrice = exitPrice
        trades[i].closedAt = date
        save()
    }

    func remove(_ id: UUID) {
        trades.removeAll { $0.id == id }
        save()
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([TradeRecord].self, from: data) else { return }
        trades = decoded
    }

    private func save() {
        if let data = try? JSONEncoder().encode(trades) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}
