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
        // .isFinite matters: a field of "inf"/"infinity" parses to +Infinity, which passes `> 0`
        // and would trap at Int(.infinity) below (a hard crash that persists via UserDefaults).
        guard account > 0, riskFraction > 0, entry > 0, stop > 0,
              account.isFinite, riskFraction.isFinite, entry.isFinite, stop.isFinite else { return nil }
        let riskPerShare = abs(entry - stop)
        guard riskPerShare > 0 else { return nil }
        let riskBudget = account * riskFraction
        // Int(exactly:) is the correct overflow guard: `raw <= Double(Int.max)` PASSES at raw == 2^63
        // (Double(Int.max) rounds UP to 2^63), then Int(2^63) still traps. Int(exactly:) returns nil there.
        let raw = (riskBudget / riskPerShare).rounded(.down)
        guard raw.isFinite, raw >= 0, let shares = Int(exactly: raw) else { return nil }
        let notional = Double(shares) * entry
        return PositionSize(
            shares: shares,
            dollarsAtRisk: Double(shares) * riskPerShare,
            notional: notional,
            pctOfAccount: notional / account * 100,
            riskPerShare: riskPerShare)
    }

    /// One-line "size it now" summary — shares, at-risk amount, % of account — with the
    /// honesty caveat that this sizes the LOSS at the stop, not a profit.
    /// F1/F3 (2026-07-09): whole-share flooring can round a real setup down to 0 shares at a
    /// small account (crypto rows especially — a $50k+ entry floors to 0 at a $10k account) while
    /// the idea still holds a #1 rank slot on the board — that was silent before this. `shares==0`
    /// now says so explicitly, in this SAME string every "Size it now" surface already renders
    /// (idea card, best-opportunity CTA, detail sheet) — no ranking/demotion change, display-only.
    /// Audit 2026-07-12 (ideas-card F1): `dollarsAtRisk` is in the SYMBOL's own currency (SAR for
    /// 2222.SR, pence for .L), so a hardcoded "$" over-/under-stated it ~3.75×/100×. `symbol` is now
    /// threaded so the amount renders in its true currency via the same tested `approxAmount` the
    /// idea-card "At risk" metric uses. `symbol` defaults to "" (→ "$") so any un-updated caller is
    /// byte-identical; every real caller passes it.
    nonisolated static func summaryLine(_ ps: PositionSize, riskPct: Double, symbol: String = "") -> String {
        let atRisk = symbol.isEmpty ? String(format: "≈$%.0f", ps.dollarsAtRisk)
                                    : StockSageCurrency.approxAmount(ps.dollarsAtRisk, symbol: symbol)
        let base = String(format: "%d shares %@ at risk (%.0f%% of acct) at %.1f%%/trade — sizes the LOSS, not a profit promise.",
               ps.shares, atRisk, ps.pctOfAccount, riskPct)
        guard ps.shares == 0 else { return base }
        return base + " Below the 1-share minimum at your account size — not fundable as sized."
    }
}
