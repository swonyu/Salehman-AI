import SwiftUI
import Combine

// MARK: - Markets placeholder store
//
// A minimal `MarketStore` so `TabSwitcherBar`'s live status dot has something to
// read during Phase 1. Phase 2 replaces this with the real polling store
// (Markets/MarketStore.swift) and deletes this file.

/// Snapshot of the market's current open/closed state. The real implementation
/// derives this from exchange hours + a network probe.
struct MarketSession {
    var isOpen: Bool
    var shortLabel: String
}

/// In-progress placeholder for the Saudi/TASI market data store. Publishes a
/// stable "Closed" session until the real data layer ships.
@MainActor
final class MarketStore: ObservableObject {
    static let shared = MarketStore()

    @Published var session = MarketSession(isOpen: false, shortLabel: "Closed")

    private init() {}
}
