import Foundation

// MARK: - Grand Exchange flip velocity (gp / hour)
//
// The OSRS mirror of the stock side's EV/day "velocity": rank GE flips by gp PER
// HOUR, not just margin, so a high-buy-limit item that fills fast beats a fat-margin
// item you can only buy 8 of every 4 hours. A flip buys at the instant-sell price
// (`low`) and sells at the instant-buy price (`high`); the SELL pays GE tax.
//
// Honesty: the buy-limit window and tax rate model OSRS rules, but the GE tax RATE
// and CAP have changed over the game's history — `rate` is a parameter (default 2%, live since 2025-05-29,
// matching the rest of this codebase) and the live RuneLite Java side, which talks to
// the real game, is the source of truth. gp/hour assumes you actually FILL the buy
// limit each window — real fills depend on volume. Pure + deterministic.

struct GEFlip: Sendable, Equatable, Identifiable {
    let itemId: Int
    let name: String
    let buyPrice: Int        // you buy at the instant-sell price (`low`)
    let sellPrice: Int       // you sell at the instant-buy price (`high`)
    let buyLimit: Int        // units per 4-hour GE window
    let taxPerItem: Int      // GE tax paid on each sale
    let profitPerItem: Int   // sell − buy − tax
    let gpPerHour: Double     // profitPerItem × buyLimit ÷ 4h window
    var id: Int { itemId }
}

/// One flip in a budget plan: how many units the gp budget funds and the realized
/// gp/hour for that (possibly limit-or-budget-capped) quantity.
struct BudgetedFlip: Sendable, Equatable, Identifiable {
    let itemId: Int
    let name: String
    let units: Int          // funded units (≤ buy limit, ≤ what the budget can buy)
    let capital: Int        // units × buyPrice — gp tied up in this flip
    let gpPerHour: Double   // profitPerItem × units ÷ 4h (scales down when budget-capped)
    var id: Int { itemId }
}

/// A budget allocation across the fastest flips.
struct BudgetPlan: Sendable, Equatable {
    let flips: [BudgetedFlip]
    let totalCapital: Int
    let totalGpPerHour: Double
}

enum StockSageGEFlip {
    nonisolated static let windowHours = 4.0      // GE buy limits reset every 4 hours
    nonisolated static let taxCap = 5_000_000     // GE tax is capped per item
    nonisolated static let taxExemptBelow = 50    // sales under this are tax-free
    nonisolated static let defaultRate = 0.02     // 2% (live OSRS since 2025-05-29) — a parameter; verify vs current rules

    /// GE sell tax per item: `rate` of the sell price, floored, capped at 5M/item,
    /// exempt below the threshold.
    nonisolated static func sellTax(_ sellPrice: Int, rate: Double = defaultRate) -> Int {
        guard sellPrice >= taxExemptBelow else { return 0 }
        return Swift.min(Int((Double(sellPrice) * rate).rounded(.down)), taxCap)
    }

    /// gp/hour for flipping one item: (sell − buy − tax) × buyLimit ÷ 4h window.
    /// nil if prices/limit are non-positive or there's no profit after tax.
    nonisolated static func gpPerHour(buy: Int, sell: Int, buyLimit: Int, rate: Double = defaultRate) -> Double? {
        guard buy > 0, sell > 0, buyLimit > 0 else { return nil }
        let profit = sell - buy - sellTax(sell, rate: rate)
        guard profit > 0 else { return nil }
        return Double(profit) * Double(buyLimit) / windowHours
    }

    /// Build and rank flips (gp/hour desc) from priced listings. Listings without a
    /// buy limit, missing prices, or no profit after tax are dropped.
    nonisolated static func flips(_ listings: [RuneScapeListing], rate: Double = defaultRate) -> [GEFlip] {
        listings.compactMap { l -> GEFlip? in
            guard let buy = l.price.low, let sell = l.price.high, let limit = l.item.buyLimit,
                  let gph = gpPerHour(buy: buy, sell: sell, buyLimit: limit, rate: rate) else { return nil }
            let tax = sellTax(sell, rate: rate)
            return GEFlip(itemId: l.item.id, name: l.item.name, buyPrice: buy, sellPrice: sell,
                          buyLimit: limit, taxPerItem: tax, profitPerItem: sell - buy - tax, gpPerHour: gph)
        }
        .sorted { $0.gpPerHour > $1.gpPerHour }
    }

    /// "With N gp, flip these": greedily allocate the budget to the fastest flips
    /// (gp/hour desc), buying up to each flip's 4h buy limit or whatever the remaining
    /// gp affords — whichever is smaller. An ESTIMATE that assumes you fill what you buy;
    /// real fills depend on volume, and it doesn't reserve gp for slippage.
    nonisolated static func bestFlipsForBudget(_ flips: [GEFlip], budget: Int) -> BudgetPlan {
        var remaining = Swift.max(0, budget)
        var chosen: [BudgetedFlip] = []
        for f in flips.sorted(by: { $0.gpPerHour > $1.gpPerHour }) {
            guard remaining > 0, f.buyPrice > 0, f.buyLimit > 0, f.profitPerItem > 0 else { continue }
            let units = Swift.min(f.buyLimit, remaining / f.buyPrice)   // integer units the gp can buy
            guard units > 0 else { continue }
            let capital = units * f.buyPrice
            chosen.append(BudgetedFlip(itemId: f.itemId, name: f.name, units: units, capital: capital,
                                       gpPerHour: Double(f.profitPerItem) * Double(units) / windowHours))
            remaining -= capital
        }
        return BudgetPlan(flips: chosen,
                          totalCapital: chosen.reduce(0) { $0 + $1.capital },
                          totalGpPerHour: chosen.reduce(0.0) { $0 + $1.gpPerHour })
    }
}
