import Foundation

// MARK: - Crypto perp funding drag (CRYPTO_RISK #4)
//
// The entire cost stack (NetEdge, Backtester) models ONE-TIME entry/exit frictions. A
// perpetual-futures position — how most LEVERED crypto is actually traded — pays a RECURRING
// funding rate for the whole hold, invisible to a price-only backtest: a 20-day hold at 5×
// positive funding can eat multiple R. This overlay charges an owner-tunable, LABELED
// annualized-funding ESTIMATE BAND against the spot net expectancy. It NEVER fabricates a live
// rate; funding is regime-dependent and can go NEGATIVE (longs get PAID) — the note must say
// so. A pure spot (non-perp) position has no funding leg and simply never calls this. Pure math.

struct CryptoFundingDrag: Sendable, Equatable {
    let leverage: Double
    let holdDays: Double
    let annualFundingBpsLow: Double
    let annualFundingBpsHigh: Double
    let fundingDragRMid: Double        // R eaten at the band midpoint (can be negative — paid)
    let fundingDragRHigh: Double       // R eaten at the band's costly end
    let netEdgeRAfterFunding: Double   // spotNetExpectancyR − fundingDragRMid
    let stillPositiveMid: Bool
    let note: String
    let caveat: String
}

enum StockSageCryptoFunding {
    /// ESTIMATE band ≈ 3%–30% APR — regime-dependent, can be NEGATIVE; owner-tunable, never a
    /// quote. No live/paid funding feed exists in this app; if real rates ever arrive they must
    /// be labeled live-vs-estimate, never hardcoded here.
    nonisolated static let defaultAnnualFundingBps = (low: 300.0, high: 3000.0)

    nonisolated static let caveat = "Funding is the most regime-dependent cost in crypto and the hardest to estimate honestly — this is an owner-tunable ESTIMATE band, not a forecast and never a quote. It can flip sign (a negative-funding regime pays the long side to hold). Applies to perp/levered positions only. The stop is still the floor."

    /// Funding drag in R for a perp position: dailyFunding = annualBps/10 000/365; drag as a
    /// fraction of 1R = leverage · dailyFunding · holdDays ÷ riskFractionOfNotional. nil on
    /// degenerate inputs (leverage ≤ 0, holdDays < 0, riskFraction ≤ 0, or an inverted band).
    nonisolated static func drag(spotNetExpectancyR: Double, riskFractionOfNotional: Double,
                                 leverage: Double, holdDays: Double,
                                 annualFundingBps: (low: Double, high: Double) = defaultAnnualFundingBps)
        -> CryptoFundingDrag? {
        guard leverage > 0, holdDays >= 0, riskFractionOfNotional > 0,
              annualFundingBps.low <= annualFundingBps.high else { return nil }
        func dragR(_ annualBps: Double) -> Double {
            leverage * (annualBps / 10_000 / 365) * holdDays / riskFractionOfNotional
        }
        let mid = dragR((annualFundingBps.low + annualFundingBps.high) / 2)
        let high = dragR(annualFundingBps.high)
        let after = spotNetExpectancyR - mid
        let note = String(format: "Est. funding drag over %.0f day(s) at %.1f×: −%.2fR mid (−%.2fR at the high band) off a %+.2fR spot net edge → %+.2fR left (mid). Funding can flip sign — a negative-funding regime PAYS longs to hold. Estimate, not a forecast; the stop is still your floor.",
                          holdDays, leverage, mid, high, spotNetExpectancyR, after)
        return CryptoFundingDrag(leverage: leverage, holdDays: holdDays,
                                 annualFundingBpsLow: annualFundingBps.low,
                                 annualFundingBpsHigh: annualFundingBps.high,
                                 fundingDragRMid: mid, fundingDragRHigh: high,
                                 netEdgeRAfterFunding: after, stillPositiveMid: after > 0,
                                 note: note, caveat: caveat)
    }
}
