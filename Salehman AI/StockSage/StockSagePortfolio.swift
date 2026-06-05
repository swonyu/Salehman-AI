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

    private init() { load() }

    /// Add a position. No-ops on a blank symbol or non-positive share count, so a
    /// fat-fingered form submit can't store garbage.
    func add(symbol: String, shares: Double, costBasis: Double) {
        let s = symbol.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !s.isEmpty, shares > 0, costBasis >= 0 else { return }
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
            UserDefaults.standard.set(data, forKey: Self.key)
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: Self.key),
              let decoded = try? JSONDecoder().decode([PortfolioPosition].self, from: data) else { return }
        positions = decoded
    }
}
