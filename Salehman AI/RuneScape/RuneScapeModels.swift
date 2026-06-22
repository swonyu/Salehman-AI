import Foundation

// MARK: - RuneScape Grand Exchange models
//
// Value types for the live Old School RuneScape (OSRS) Grand Exchange market.
// Data comes from the community-run real-time prices API at
// `prices.runescape.wiki` (keyless). Plain Sendable structs so they cross the
// nonisolated fetch → main-actor store boundary cleanly.

/// One tradeable OSRS item, from the GE item mapping.
struct RuneScapeItem: Sendable, Equatable, Identifiable {
    /// The Grand Exchange item id (stable across updates).
    let id: Int
    let name: String
    /// The in-game "examine" flavor text.
    let examine: String
    /// Members-only item (vs free-to-play).
    let members: Bool
    /// 4-hour GE buy limit, when the mapping knows it.
    let buyLimit: Int?

    /// Official OSRS item sprite — a reliable per-id thumbnail.
    var iconURL: URL? {
        URL(string: "https://secure.runescape.com/m=itemdb_oldschool/obj_sprite.gif?id=\(id)")
    }
}

/// Latest instant-buy / instant-sell quote for an item (from `/latest`).
/// `high` is the instant-BUY price (what you pay to buy now); `low` is the
/// instant-SELL price (what you receive selling now). Either can be missing for
/// a thinly-traded item.
struct RuneScapePrice: Sendable, Equatable {
    let high: Int?
    let highTime: Date?
    let low: Int?
    let lowTime: Date?

    /// GE flip margin: buy-now minus sell-now (gross, before the 2% GE sell tax).
    var margin: Int? {
        guard let high, let low else { return nil }
        return high - low
    }

    /// Age of the OLDER traded leg (high/low) — the limiting freshness of the displayed spread. A
    /// thin item's "sell" leg can be days stale while shown green, so the UI must qualify it. nil if
    /// neither leg carries a feed timestamp.
    nonisolated func oldestLegAge(asOf now: Date) -> TimeInterval? {
        // If both legs are priced, both must carry a trade time to age the spread honestly. A priced
        // leg with a missing time can't be aged, so don't report the OTHER leg's (misleadingly fresh)
        // age — return nil and let isStale treat the half-timestamped spread as unverifiable.
        if high != nil, low != nil, (highTime == nil) != (lowTime == nil) { return nil }
        let ts = [highTime, lowTime].compactMap { $0 }
        guard let oldest = ts.min() else { return nil }
        return Swift.max(0, now.timeIntervalSince(oldest))
    }

    /// The spread is stale when its older leg hasn't traded within `maxAge` (default 60 min, matching
    /// the plugin's maxStaleMinutes) — the margin may no longer be fillable.
    nonisolated func isStale(maxAge: TimeInterval = 3600, asOf now: Date) -> Bool {
        // Both legs priced but EXACTLY ONE has a trade time → the feed gives times yet one leg is
        // unverifiable → treat as stale. (Neither leg timestamped = feed provides none → can't judge.)
        if high != nil, low != nil, (highTime == nil) != (lowTime == nil) { return true }
        guard let age = oldestLegAge(asOf: now) else { return false }
        return age > maxAge
    }

    /// Margin as a percentage of the sell price — the "return" on a flip.
    var marginPercent: Double? {
        guard let high, let low, low > 0 else { return nil }
        return Double(high - low) / Double(low) * 100
    }

    /// Best single price to show when only one side is wanted (buy, else sell).
    var displayPrice: Int? { high ?? low }
}

/// An item joined with its current price — the row the UI renders.
struct RuneScapeListing: Sendable, Equatable, Identifiable {
    let item: RuneScapeItem
    let price: RuneScapePrice
    var id: Int { item.id }
}
