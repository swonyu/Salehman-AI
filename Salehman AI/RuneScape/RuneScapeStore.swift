import Foundation
import Combine

// MARK: - RuneScapeStore
//
// Main-actor store backing the RuneScape tab. Holds the featured watchlist
// (curated GE staples joined with live prices), the cached item mapping (for
// search), and the last-refresh status. Mirrors `StockSageStore`'s shape so the
// view layer reads the same way: `refresh()` pulls live data and is a
// non-destructive no-op when the feed is unreachable or external access is off.
@MainActor
final class RuneScapeStore: ObservableObject {
    static let shared = RuneScapeStore()

    /// Curated featured items joined with live prices (the default board).
    @Published private(set) var featured: [RuneScapeListing] = []
    /// Live name-search results over the full mapping, price-joined.
    @Published private(set) var searchResults: [RuneScapeListing] = []
    @Published private(set) var isLoading = false
    @Published private(set) var lastUpdated: Date?
    /// Human-readable reason the last refresh produced no data (offline, web off,
    /// feed unreachable); nil when healthy.
    @Published private(set) var error: String?

    /// Total tradeable items the mapping knows about — shown in the header once
    /// the mapping has loaded.
    var itemCount: Int { mapping.count }

    private var mapping: [RuneScapeItem] = []
    private var mappingByID: [Int: RuneScapeItem] = [:]
    private var latest: [Int: RuneScapePrice] = [:]

    private init() {}

    /// Pull the live GE snapshot. Caches the (static-ish) mapping on first use,
    /// then refreshes prices each call.
    func refresh() async {
        guard !isLoading else { return }
        if let reason = ToolPolicy.webToolsDisabledReason() {
            error = reason
            return
        }
        isLoading = true
        error = nil

        if mapping.isEmpty {
            let m = await RuneScapeMarketService.fetchMapping()
            if !m.isEmpty {
                mapping = m
                mappingByID = Dictionary(m.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
            }
        }
        let prices = await RuneScapeMarketService.fetchLatest()
        isLoading = false

        guard !prices.isEmpty else {
            error = "Couldn't reach the Grand Exchange feed — showing the last data."
            return
        }
        latest = prices

        featured = RuneScapeMarketService.featuredIDs.compactMap { id in
            // Real data only: drop a featured id whose NAME didn't resolve from the GE
            // mapping rather than showing a fabricated "Item <id>" placeholder beside a real price.
            guard let price = prices[id], let item = mappingByID[id] else { return nil }
            return RuneScapeListing(item: item, price: price)
        }
        lastUpdated = Date()
    }

    /// Filter the cached mapping by name and join live prices. Requires the
    /// mapping + a prior price snapshot (i.e. a successful `refresh()`). Capped at
    /// 50 matches so a 2-letter query can't render thousands of rows.
    func search(_ query: String) {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard q.count >= 2, !mapping.isEmpty else { searchResults = []; return }
        let matches = mapping.lazy
            .filter { $0.name.lowercased().contains(q) }
            .prefix(50)
        searchResults = matches.compactMap { item in
            guard let price = latest[item.id] else { return nil }
            return RuneScapeListing(item: item, price: price)
        }
    }

    /// Clear search state (e.g. when the field empties).
    func clearSearch() { searchResults = [] }
}
