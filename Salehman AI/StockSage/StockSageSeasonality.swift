import Foundation

// MARK: - Monthly seasonality
//
// Some names have a mild calendar tendency (the "sell in May" folklore, tax-loss
// bounces, etc.). This measures it honestly: month-over-month returns grouped by
// calendar month, averaged, WITH the sample count — because a "+3% average June"
// over 2 years is noise, not a pattern. Pure + tested. Always framed as a weak,
// backward-looking tendency, never a forecast.

struct MonthlySeasonality: Sendable, Equatable {
    struct MonthStat: Sendable, Equatable, Identifiable {
        let month: Int          // 1…12
        let avgReturn: Double   // average month-over-month return (fraction)
        let samples: Int        // how many years contributed this month
        var id: Int { month }
        /// A month needs ≥3 yearly samples before it's worth reading at all.
        nonisolated var isReliable: Bool { samples >= 3 }

        nonisolated func note(monthName: String) -> String {
            let pct = String(format: "%+.1f%%", avgReturn * 100)
            let tail = isReliable ? "" : " — thin sample, treat as noise"
            return "\(monthName): historically \(pct) average over \(samples) year\(samples == 1 ? "" : "s")\(tail). A weak, backward-looking tendency — not a forecast."
        }
    }
    let months: [MonthStat]     // exactly 12 entries (month 1…12)
    let years: Double

    nonisolated static let empty = MonthlySeasonality(
        months: (1...12).map { MonthStat(month: $0, avgReturn: 0, samples: 0) }, years: 0)
}

enum StockSageSeasonality {
    private nonisolated static var utcCalendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }

    /// Group month-over-month returns by calendar month. Accepts daily OR monthly
    /// bars — within each calendar month the LAST close is taken as the month-end,
    /// then returns are computed between consecutive month-ends.
    nonisolated static func compute(dates: [Date], closes: [Double]) -> MonthlySeasonality {
        guard dates.count == closes.count, dates.count >= 2 else { return .empty }
        let cal = utcCalendar

        // Collapse to one (key, month, month-end-close) point per calendar month.
        // `key` = year*12+month lets us require ADJACENT months below.
        var order: [(key: Int, month: Int, close: Double)] = []
        var lastKey = Int.min
        for (d, c) in zip(dates, closes) where c > 0 {
            let comps = cal.dateComponents([.year, .month], from: d)
            guard let y = comps.year, let m = comps.month else { continue }
            let key = y * 12 + m
            if key == lastKey {
                order[order.count - 1].close = c   // keep the last close seen this month
            } else {
                order.append((key: key, month: m, close: c))
                lastKey = key
            }
        }
        guard order.count >= 2 else { return .empty }

        var byMonth: [Int: [Double]] = [:]
        for i in 1..<order.count {
            // Only credit a return when the two points are CONSECUTIVE calendar
            // months — a gap (e.g. a dropped null bar) would otherwise mislabel a
            // multi-month return as the later month's single-month seasonality.
            guard order[i - 1].close > 0, order[i].key == order[i - 1].key + 1 else { continue }
            byMonth[order[i].month, default: []].append(order[i].close / order[i - 1].close - 1)
        }
        let months = (1...12).map { m -> MonthlySeasonality.MonthStat in
            let rs = byMonth[m] ?? []
            let avg = rs.isEmpty ? 0 : rs.reduce(0, +) / Double(rs.count)
            return MonthlySeasonality.MonthStat(month: m, avgReturn: avg, samples: rs.count)
        }
        let years = dates.last!.timeIntervalSince(dates.first!) / (365.25 * 86_400)
        return MonthlySeasonality(months: months, years: years)
    }

    nonisolated static func stat(_ s: MonthlySeasonality, month: Int) -> MonthlySeasonality.MonthStat? {
        s.months.first { $0.month == month }
    }
}
