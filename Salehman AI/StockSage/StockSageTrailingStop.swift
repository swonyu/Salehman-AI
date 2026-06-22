import Foundation

// MARK: - ATR trailing-stop suggestion
//
// A fixed stop is set once and forgotten; a TRAILING stop follows the trade up.
// This is a true Chandelier exit: the HIGHEST HIGH over the lookback minus a
// multiple of ATR (average true range). Anchoring to the highest high (not the
// latest close) is what makes it trail — the anchor can't fall while that high
// stands, so the level rises with new highs and doesn't drop on a down day. The
// ATR term scales the room to the name's real volatility, not a guessed percent.
// It's a STARTING level computed once — the owner moves it up as new highs print.
// Pure + tested. An exit rule, not a profit forecast.

struct TrailingStop: Sendable, Equatable {
    let level: Double         // suggested stop price (for a long): highestHigh − k·ATR
    let atr: Double           // current ATR
    let multiple: Double      // k (ATRs of room)
    let distancePct: Double   // how far below the last close, %
}

enum StockSageTrailingStop {
    /// Chandelier exit for a LONG: highestHigh(period) − k·ATR. nil if ATR can't be
    /// computed, the level is non-positive, or it isn't below the last close (a stop
    /// at/above price means it would already be hit — not a usable trailing level).
    nonisolated static func suggest(highs: [Double], lows: [Double], closes: [Double],
                                    multiple: Double = 3, period: Int = 14) -> TrailingStop? {
        guard multiple > 0, let last = closes.last, last > 0,
              let anchorHigh = highs.suffix(period).max(),
              let atr = StockSageIndicators.atr(highs: highs, lows: lows, closes: closes, period: period),
              atr > 0 else { return nil }
        let level = anchorHigh - multiple * atr
        guard level > 0, level < last else { return nil }
        return TrailingStop(level: level, atr: atr, multiple: multiple,
                            distancePct: (last - level) / last * 100)
    }
}
