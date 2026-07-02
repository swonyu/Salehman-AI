import Foundation

// MARK: - Trade-plan export
//
// Writing the plan down BEFORE the trade is the single cheapest discipline there
// is — it turns a vibe into entry / stop / target / size you can be held to. This
// renders an idea into a clean, copyable text plan (broker note, journal, message).
// Pure + tested. It restates the app's numbers and its caveat; it promises nothing.

enum StockSageTradePlan {
    // aa#4: ladder and chandelierLevel added so Copy Plan exports the scale-out rungs
    // and chandelier exit level that the sheet displays — the pasted broker note now
    // matches what the trader read on screen. Both parameters are optional; nil callers
    // (e.g. card-level copyIdeaPlan) skip those lines. Wave 9 also switched all price
    // lines to adaptivePrice and relabeled the Action line, so the nil path is NOT
    // byte-identical to pre-wave-8 output for sub-$1 prices / the conviction wording.

    // Replicates MarketsView.adaptivePrice exactly: ≥$1 or zero → 2dp; ≥$0.01 → 4dp;
    // sub-cent → 6dp. Keeps the pasted broker note consistent with what the sheet shows.
    // nonisolated so it can be called from the nonisolated text() function.
    nonisolated private static func adaptivePrice(_ v: Double) -> String {
        let a = abs(v)
        if a >= 1 || a == 0 { return String(format: "%.2f", v) }
        if a >= 0.01 { return String(format: "%.4f", v) }
        return String(format: "%.6f", v)
    }

    nonisolated static func text(symbol: String, market: String, price: Double,
                                 advice: TradeAdvice, rewardRisk: RewardRisk?,
                                 size: PositionSize?, flags: [RiskFlag],
                                 ladder: PartialLadder? = nil,
                                 chandelierLevel: Double? = nil) -> String {
        var lines: [String] = []
        lines.append("TRADE PLAN — \(symbol) (\(market))")
        // Wave-8 relabeled: "signal strength X/100" replaces "conviction X%".
        // The old label said "conviction" which contradicts the sheet's honesty relabel
        // (conviction != win probability); the new label matches the sheet and adds the
        // explicit disclaimer so the pasted plan is self-contained.
        lines.append("Action: \(advice.action.rawValue) · signal strength \(Int(advice.conviction * 100))/100 · \(advice.regime.rawValue) — rules-based score, not a win probability")
        lines.append("Entry: \(adaptivePrice(price))")
        if let s = advice.stopPrice { lines.append("Stop: \(adaptivePrice(s))") }
        if let t = advice.targetPrice { lines.append("Target: \(adaptivePrice(t))") }
        if let rr = rewardRisk {
            lines.append(String(format: "R:R: %.1f (%@) — needs a >%.1f%% win-rate to break even",
                                rr.ratio, rr.quality.rawValue, rr.breakevenWinRate * 100))
        }
        // aa#4: scale-out ladder rungs — prices use adaptivePrice so sub-dollar names
        // never show "0.00" in the pasted plan, matching what the sheet displays.
        if let ld = ladder, !ld.rungs.isEmpty {
            let rungText = ld.rungs.map { "\(adaptivePrice($0.price)) (+\(String(format: "%.1f", $0.rMultiple))R)" }.joined(separator: " / ")
            lines.append(String(format: "Scale-out (⅓ each): %@ — blended exit +%.1fR. Assumes each level fills.", rungText, ld.blendedExitR))
        }
        // aa#4: chandelier exit level — adaptivePrice ensures sub-dollar levels show
        // real magnitude (e.g. "0.006200" not "0.00") matching the sheet's display.
        if let cl = chandelierLevel {
            lines.append("Chandelier exit: ~\(adaptivePrice(cl)) — a STARTING trailing level; move it up as new highs print, never down. An exit rule, not a target.")
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
