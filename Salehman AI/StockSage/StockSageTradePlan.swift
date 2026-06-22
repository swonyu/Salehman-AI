import Foundation

// MARK: - Trade-plan export
//
// Writing the plan down BEFORE the trade is the single cheapest discipline there
// is — it turns a vibe into entry / stop / target / size you can be held to. This
// renders an idea into a clean, copyable text plan (broker note, journal, message).
// Pure + tested. It restates the app's numbers and its caveat; it promises nothing.

enum StockSageTradePlan {
    nonisolated static func text(symbol: String, market: String, price: Double,
                                 advice: TradeAdvice, rewardRisk: RewardRisk?,
                                 size: PositionSize?, flags: [RiskFlag]) -> String {
        var lines: [String] = []
        lines.append("TRADE PLAN — \(symbol) (\(market))")
        lines.append("Action: \(advice.action.rawValue) · conviction \(Int(advice.conviction * 100))% · \(advice.regime.rawValue)")
        lines.append(String(format: "Entry: %.2f", price))
        if let s = advice.stopPrice { lines.append(String(format: "Stop: %.2f", s)) }
        if let t = advice.targetPrice { lines.append(String(format: "Target: %.2f", t)) }
        if let rr = rewardRisk {
            lines.append(String(format: "R:R: %.1f (%@) — needs a >%.1f%% win-rate to break even",
                                rr.ratio, rr.quality.rawValue, rr.breakevenWinRate * 100))
        }
        if let ps = size {
            lines.append(String(format: "Size: %d shares · $%.0f at risk · %.0f%% of account",
                                ps.shares, ps.dollarsAtRisk, ps.pctOfAccount))
            // Mirror the on-screen leverage warning so the pasted plan can't understate risk.
            if ps.pctOfAccount > 100 {
                lines.append(String(format: "⚠ Notional exceeds the account — needs margin/leverage; a gap THROUGH the stop can lose well more than the $%.0f stated risk.",
                                    ps.dollarsAtRisk))
            }
        }
        if !flags.isEmpty {
            lines.append("Risk flags: " + flags.map(\.label).joined(separator: ", "))
        }
        if !advice.rationale.isEmpty {
            lines.append("")
            lines.append("Why: " + advice.rationale.joined(separator: "; "))
        }
        lines.append("")
        lines.append(advice.caveat)
        return lines.joined(separator: "\n")
    }
}
