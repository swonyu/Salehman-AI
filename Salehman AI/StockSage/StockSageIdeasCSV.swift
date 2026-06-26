import Foundation

// MARK: - Ideas board CSV export
//
// Renders the ranked Trade-Ideas board as RFC-4180 CSV so the board isn't trapped
// in the app — take it into Excel / Sheets / Python. Pure + tested. `rank` reflects
// the on-screen order of the list passed in (already sorted by the chosen metric).
// Rationale bullets are joined with "; " and the whole field is CSV-escaped, so a
// comma or quote inside a reason can't corrupt the file.
enum StockSageIdeasCSV {
    nonisolated static let header =
        "rank,symbol,market,price,action,conviction,stop,target,weightPct,regime,rationale"

    nonisolated static func csv(_ ideas: [StockSageIdea]) -> String {
        var rows = [header]
        for (i, idea) in ideas.enumerated() {
            let a = idea.advice
            var f: [String] = []
            f.append(String(i + 1))
            f.append(idea.symbol)
            f.append(idea.market)
            f.append(String(idea.price))
            f.append(a.action.rawValue)
            // conviction/weight formatted to avoid float noise (0.12×100 = 12.000000002);
            // prices (price/stop/target) kept exact — don't round money.
            f.append(String(format: "%.2f", a.conviction))
            f.append(a.stopPrice.map { String($0) } ?? "")
            f.append(a.targetPrice.map { String($0) } ?? "")
            f.append(String(format: "%.1f", a.suggestedWeight * 100))
            f.append(a.regime.rawValue)
            f.append(a.rationale.joined(separator: "; "))
            rows.append(f.map(escape).joined(separator: ","))
        }
        return rows.joined(separator: "\n")
    }

    /// RFC-4180: a field containing a comma, quote, CR or LF is wrapped in double
    /// quotes, with any internal double-quote doubled.
    nonisolated static func escape(_ field: String) -> String {
        guard field.contains(",") || field.contains("\"") || field.contains("\n") || field.contains("\r")
        else { return field }
        return "\"" + field.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }
}
