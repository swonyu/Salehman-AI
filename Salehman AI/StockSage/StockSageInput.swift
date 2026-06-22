import Foundation

// MARK: - Numeric input validation
//
// The UI parses free-text numeric fields (account size, risk %, journal prices, GE
// budget) with `Double(text) ?? 0` — so "abc", "1.2.3", a negative, or an out-of-range
// percent silently become 0/default and quietly produce a wrong $-estimate or P&L.
// These pure validators return nil on bad input so callers can show an honest hint
// instead of computing on a fabricated zero. Tolerant of thousands separators + spaces.

enum StockSageInput {
    private nonisolated static func clean(_ s: String) -> String {
        s.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: "")
    }

    /// A finite amount > 0 (money / budget / price). nil otherwise.
    nonisolated static func positiveAmount(_ s: String) -> Double? {
        guard let v = Double(clean(s)), v.isFinite, v > 0 else { return nil }
        return v
    }

    /// A percent in (0, max]. nil otherwise (default cap 100). For Kelly / risk %.
    nonisolated static func percent(_ s: String, max: Double = 100) -> Double? {
        guard let v = Double(clean(s)), v.isFinite, v > 0, v <= max else { return nil }
        return v
    }

    /// A whole count > 0 (GE budget gp, share count). Rejects decimals + non-numbers.
    nonisolated static func positiveInt(_ s: String) -> Int? {
        guard let v = Int(clean(s)), v > 0 else { return nil }
        return v
    }
}
