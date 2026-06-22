import Foundation

// MARK: - Multi-currency exposure
//
// Convert a book of holdings (each in its own currency) into one base currency and show
// how the money is split ACROSS currencies — because a "diversified" book that's 70% in
// one foreign currency carries an FX risk the per-symbol view hides. Pure + deterministic.
// Honest: the rates are a snapshot; real FX moves are an un-modeled risk, and any holding
// whose currency has no rate is EXCLUDED (and named) rather than silently valued at zero.

struct CurrencyExposure: Sendable, Equatable, Identifiable {
    let currency: String
    let baseValue: Double   // converted into the base currency
    let weight: Double      // 0–1 of the (convertible) book
    var id: String { currency }
}

struct CurrencyBreakdown: Sendable, Equatable {
    let base: String
    let totalBase: Double
    let exposures: [CurrencyExposure]      // largest first
    let concentration: CurrencyExposure?   // largest NON-base exposure over the threshold, else nil
    let unpriced: [String]                 // currencies dropped for lack of a rate
    nonisolated var hasFXRisk: Bool { concentration != nil }
}

enum StockSageCurrency {
    /// Roll holdings up by currency, converted to `base` via `ratesToBase` (units of base per
    /// 1 unit of the currency; base itself is implicitly 1). Flags the largest non-base
    /// currency when it exceeds `concentrationThreshold` of the book. nil if nothing convertible.
    nonisolated static func breakdown(holdings: [(value: Double, currency: String)],
                                      ratesToBase: [String: Double], base: String,
                                      concentrationThreshold: Double = 0.25) -> CurrencyBreakdown? {
        var byCcy: [String: Double] = [:]
        var unpriced: Set<String> = []
        for h in holdings {
            let v = Swift.max(0, h.value)
            let rate: Double? = (h.currency == base) ? 1.0 : ratesToBase[h.currency]
            guard let r = rate, r > 0 else { unpriced.insert(h.currency); continue }
            byCcy[h.currency, default: 0] += v * r
        }
        let total = byCcy.values.reduce(0, +)
        guard total > 0 else { return nil }

        let exposures = byCcy
            .map { CurrencyExposure(currency: $0.key, baseValue: $0.value, weight: $0.value / total) }
            .sorted { $0.baseValue > $1.baseValue }
        let concentration = exposures.first { $0.currency != base && $0.weight > concentrationThreshold }
        return CurrencyBreakdown(base: base, totalBase: total, exposures: exposures,
                                 concentration: concentration, unpriced: unpriced.sorted())
    }

    /// Best-effort trading currency for a symbol from its market suffix. Crypto (`-USD`),
    /// FX pairs (`=X`), and indices (`^`) map to `base`; an UNKNOWN suffix maps to the suffix
    /// itself, so it surfaces as "unpriced" rather than being silently mislabeled the base.
    nonisolated static func currencyForSymbol(_ symbol: String, base: String = "USD") -> String {
        let s = symbol.uppercased()
        if s.hasPrefix("^") || s.hasSuffix("-USD") { return base }   // index level / crypto priced in USD
        // FX pair "BASEQUOTE=X": holding it is exposure to its NON-base leg (long base vs
        // quote). EURUSD=X → EUR; USDJPY=X → JPY; a cross (EURGBP=X) → its base.
        if s.hasSuffix("=X") {
            let pair = String(s.dropLast(2))
            guard pair.count == 6 else { return base }
            let lead = String(pair.prefix(3)), trail = String(pair.suffix(3))
            if lead == base { return trail }
            if trail == base { return lead }
            return lead
        }
        guard let dot = s.lastIndex(of: "."), s.index(after: dot) < s.endIndex else { return base }
        let suffix = String(s[s.index(after: dot)...])
        return currencyForSuffix[suffix] ?? suffix
    }

    private nonisolated static let currencyForSuffix: [String: String] = [
        "SR": "SAR", "L": "GBP", "DE": "EUR", "PA": "EUR", "T": "JPY", "HK": "HKD",
        "SS": "CNY", "KS": "KRW", "NS": "INR", "AX": "AUD", "SA": "BRL", "TO": "CAD",
        "SW": "CHF", "AS": "EUR", "MC": "EUR", "MI": "EUR", "ST": "SEK", "AD": "AED",
        "DU": "AED", "QA": "QAR", "CA": "EGP", "JO": "ZAR", "TW": "TWD", "SI": "SGD", "MX": "MXN",
    ]
}
