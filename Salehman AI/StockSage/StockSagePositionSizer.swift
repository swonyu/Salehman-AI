import Foundation

// MARK: - Position-size calculator
//
// The one habit that separates survivors: size by the LOSS, not the hope. Decide
// how much of the account you'll lose if the stop is hit (e.g. 1%), and the share
// count falls out of the stop distance. This makes risk the input and size the
// output — never the reverse. Pure + tested. It sizes the loss; it promises nothing
// about the gain.

struct PositionSize: Sendable, Equatable {
    let shares: Int            // whole shares (rounded DOWN — never over-risk)
    let dollarsAtRisk: Double  // actual $ lost on a stop-out (floored shares × risk/share)
    let notional: Double       // shares × entry
    let pctOfAccount: Double    // notional ÷ account, %
    let riskPerShare: Double
}

enum StockSagePositionSizer {
    /// Size so a stop-out loses ≈ `riskFraction` of `account`. nil for invalid
    /// inputs (non-positive) or entry == stop (undefined risk → not infinite size).
    nonisolated static func size(account: Double, riskFraction: Double,
                                 entry: Double, stop: Double) -> PositionSize? {
        guard account > 0, riskFraction > 0, entry > 0, stop > 0 else { return nil }
        let riskPerShare = abs(entry - stop)
        guard riskPerShare > 0 else { return nil }
        let riskBudget = account * riskFraction
        let shares = Int((riskBudget / riskPerShare).rounded(.down))
        let notional = Double(shares) * entry
        return PositionSize(
            shares: shares,
            dollarsAtRisk: Double(shares) * riskPerShare,
            notional: notional,
            pctOfAccount: notional / account * 100,
            riskPerShare: riskPerShare)
    }
}
