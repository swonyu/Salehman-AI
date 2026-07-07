import Foundation
import Combine

/// One holding: a symbol, how many shares, and the per-share cost basis.
struct PortfolioPosition: Codable, Identifiable, Equatable, Sendable {
    var id = UUID()
    let symbol: String
    var shares: Double
    var costBasis: Double   // per-share purchase price

    /// Cost of the whole position.
    var totalCost: Double { shares * costBasis }
}

/// Tiny persisted portfolio for the Markets tab. UserDefaults-backed (JSON) —
/// holdings are small + local, so no SwiftData/Core Data needed. Current value /
/// P&L is computed against `StockSageStore`'s latest prices by the view, so this
/// store stays a pure holdings record with no price coupling.
@MainActor
final class StockSagePortfolio: ObservableObject {
    static let shared = StockSagePortfolio()

    @Published private(set) var positions: [PortfolioPosition] = []

    private static let key = "stocksage_portfolio_v1"
    private let defaults: UserDefaults

    private init() {
        self.defaults = .standard
        load()
    }

    init(userDefaults: UserDefaults) {
        self.defaults = userDefaults
        load()
    }

    /// Add a position. No-ops on a blank symbol or non-positive share count, so a
    /// fat-fingered form submit can't store garbage.
    func add(symbol: String, shares: Double, costBasis: Double) {
        let s = symbol.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !s.isEmpty, shares > 0, shares.isFinite, costBasis >= 0, costBasis.isFinite else { return }
        positions.append(PortfolioPosition(symbol: s, shares: shares, costBasis: costBasis))
        save()
    }

    func remove(_ id: UUID) {
        positions.removeAll { $0.id == id }
        save()
    }

    func clear() {
        positions.removeAll()
        save()
    }

    private func save() {
        if let data = try? JSONEncoder().encode(positions) {
            defaults.set(data, forKey: Self.key)
        }
    }

    private func load() {
        guard let data = defaults.data(forKey: Self.key),
              let decoded = try? JSONDecoder().decode([PortfolioPosition].self, from: data) else { return }
        positions = decoded
    }

    /// QA-only in-memory seed: assigns `positions` directly, bypassing `save()` so nothing
    /// touches UserDefaults. Multiple lots of the same symbol are legal (see Gotchas in the
    /// map entry) — this is a raw assign, not a merge; callers wanting the "own it" aggregate
    /// view use `StockSagePortfolio.holding(for:in:)` below on whatever `positions` holds.
    func qaSeed(_ seeded: [PortfolioPosition]) {
        positions = seeded
    }
}

/// One symbol's aggregated holding across every lot: total shares + weighted-average cost
/// basis. Multiple `PortfolioPosition` rows can share a symbol (multi-lot books — see
/// StockSagePortfolio's Gotchas); "own it" surfaces (ideas card/sheet) show ONE number per
/// symbol, so lots must be summed/weighted here rather than each caller re-deriving it.
struct AggregatedHolding: Equatable {
    let symbol: String
    let shares: Double
    /// Weighted-average cost basis across lots: Σ(shares·costBasis) / Σ(shares).
    let costBasis: Double

    /// Unrealized % vs `price`, signed raw math: (price/costBasis − 1) × 100, one decimal.
    /// nil when either side is non-positive (a nil/zero cost or price must not render a
    /// fabricated percent — honesty floor, same convention as the rest of StockSage's
    /// nil-on-insufficient-data functions).
    func unrealizedPct(vs price: Double) -> Double? {
        guard costBasis > 0, price > 0 else { return nil }
        return ((price / costBasis - 1) * 100 * 10).rounded() / 10
    }
}

extension StockSagePortfolio {
    /// Aggregates every lot matching `symbol` (case-insensitive — positions are stored
    /// uppercased by `add()`, but this defends a caller that isn't). Returns nil when the
    /// symbol isn't held or every matching lot has zero/invalid shares (avoids a
    /// divide-by-zero weighted average).
    static func holding(for symbol: String, in positions: [PortfolioPosition]) -> AggregatedHolding? {
        let target = symbol.uppercased()
        let lots = positions.filter { $0.symbol.uppercased() == target && $0.shares > 0 }
        guard !lots.isEmpty else { return nil }
        let totalShares = lots.reduce(0) { $0 + $1.shares }
        guard totalShares > 0 else { return nil }
        let weightedCost = lots.reduce(0) { $0 + $1.shares * $1.costBasis } / totalShares
        return AggregatedHolding(symbol: target, shares: totalShares, costBasis: weightedCost)
    }
}
