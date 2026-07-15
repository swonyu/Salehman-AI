import Foundation

// MARK: - Tadawul tick sizes (first-real-trade review, 2026-07-16)
//
// The engine's ATR-derived stop/target prices are arbitrary-decimal; Tadawul rejects orders
// that aren't on the tick grid, so the app's copy-plan could hand the owner an UNPLACEABLE
// price for a `.SR` order (e.g. "Stop: 28.63" in the 0.02-tick band). This helper computes the
// placeable equivalent and a DISPLAY-ONLY advisory line — the engine's stopPrice/targetPrice
// (which feed EV/R:R) are never changed; the note is the honest bridge to the broker ticket.
//
// TICK TABLE — Saudi Exchange amended regime, effective 2025-06-29 (sourced 2026-07-16 from
// two agreeing secondary sources of the exchange announcement: Argaam #1823880 + Sahm Capital
// support), Main Market + Nomu, excluding debt instruments:
//   < 25.00 → 0.01 · 25.00–49.98 → 0.02 · 50.00–99.95 → 0.05 · 100.00–249.90 → 0.10 ·
//   250.00–499.80 → 0.20 · ≥ 500.00 → 0.50
// US/NASDAQ needs no equivalent (US equities tick at $0.01 above $1 — any 2-dp price places).

enum StockSageTickSize {

    /// The Tadawul tick for a given SAR price (the 2025-06-29 band table).
    nonisolated static func tadawulTick(forPrice p: Double) -> Double {
        switch p {
        case ..<25:    return 0.01
        case ..<50:    return 0.02
        case ..<100:   return 0.05
        case ..<250:   return 0.10
        case ..<500:   return 0.20
        default:       return 0.50
        }
    }

    /// Nearest tick-grid price for a Tadawul order at this level.
    nonisolated static func tadawulRounded(_ p: Double) -> Double {
        let tick = tadawulTick(forPrice: p)
        return (p / tick).rounded() * tick
    }

    /// True when the price already sits on the tick grid (within float noise).
    nonisolated static func tadawulAligned(_ p: Double) -> Bool {
        abs(p - tadawulRounded(p)) < 1e-9
    }

    /// DISPLAY-ONLY placeability advisory for a `.SR` order plan. nil for non-Tadawul symbols,
    /// nil when every provided leg already sits on the grid. Rounds to the NEAREST tick (≤ half
    /// a tick of drift, ≤ ~7bps at typical .SR prices — disclosed, never applied to the engine's
    /// own numbers).
    nonisolated static func placeabilityNote(symbol: String, entry: Double?, stop: Double?,
                                             target: Double?) -> String? {
        guard symbol.uppercased().hasSuffix(".SR") else { return nil }
        var parts: [String] = []
        for (label, value) in [("entry", entry), ("stop", stop), ("target", target)] {
            guard let v = value, v > 0, !tadawulAligned(v) else { continue }
            parts.append(String(format: "%@ %.2f → place as %.2f", label, v, tadawulRounded(v)))
        }
        guard !parts.isEmpty else { return nil }
        let tick = tadawulTick(forPrice: stop ?? entry ?? target ?? 0)
        return String(format: "Tadawul tick %.2f SAR — engine levels off the grid: %@ (nearest tick; ≤½-tick drift, engine math unchanged).",
                      tick, parts.joined(separator: "; "))
    }
}
