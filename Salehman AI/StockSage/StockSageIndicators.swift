import Foundation

// MARK: - StockSageIndicators
//
// Pure, dependency-free technical indicators over a price / OHLC series. Every
// function is TOTAL (insufficient data → nil, never a crash or NaN) and
// deterministic, so they're unit-tested directly and can drive both the live
// advisor and the (future) backtester. Evidence + rationale for each:
// MARKETS_INTELLIGENCE_RESEARCH.md. All series are newest-LAST.
enum StockSageIndicators {

    /// Simple moving average of the last `period` values.
    nonisolated static func sma(_ values: [Double], period: Int) -> Double? {
        guard period > 0, values.count >= period else { return nil }
        return values.suffix(period).reduce(0, +) / Double(period)
    }

    /// Final exponential moving average (seeded with the SMA of the first window).
    nonisolated static func ema(_ values: [Double], period: Int) -> Double? {
        emaSeries(values, period: period).last
    }

    /// Full EMA series — newest last, length `values.count - period + 1`.
    /// Empty when there isn't enough data. Used by MACD.
    nonisolated static func emaSeries(_ values: [Double], period: Int) -> [Double] {
        guard period > 0, values.count >= period else { return [] }
        let k = 2.0 / (Double(period) + 1.0)
        var e = values.prefix(period).reduce(0, +) / Double(period)
        var out = [e]
        for v in values.dropFirst(period) {
            e = v * k + e * (1 - k)
            out.append(e)
        }
        return out
    }

    /// Wilder's RSI over `period` (default 14). 0–100. A series with no down-moves
    /// returns 100; no up-moves returns 0.
    nonisolated static func rsi(_ closes: [Double], period: Int = 14) -> Double? {
        guard period > 0, closes.count > period else { return nil }
        var gains = 0.0, losses = 0.0
        for i in 1...period {
            let change = closes[i] - closes[i - 1]
            if change >= 0 { gains += change } else { losses -= change }
        }
        var avgGain = gains / Double(period)
        var avgLoss = losses / Double(period)
        if closes.count > period + 1 {
            for i in (period + 1)..<closes.count {
                let change = closes[i] - closes[i - 1]
                let g = change > 0 ? change : 0
                let l = change < 0 ? -change : 0
                avgGain = (avgGain * Double(period - 1) + g) / Double(period)
                avgLoss = (avgLoss * Double(period - 1) + l) / Double(period)
            }
        }
        guard avgLoss != 0 else { return avgGain == 0 ? 50 : 100 }
        let rs = avgGain / avgLoss
        return 100 - 100 / (1 + rs)
    }

    struct MACDValue: Sendable, Equatable {
        let macd: Double
        let signal: Double
        let histogram: Double
    }

    /// MACD(12,26,9): macd = EMA(fast) − EMA(slow); signal = EMA(signalPeriod) of
    /// the macd line; histogram = macd − signal.
    nonisolated static func macd(_ closes: [Double], fast: Int = 12, slow: Int = 26, signalPeriod: Int = 9) -> MACDValue? {
        guard fast < slow, closes.count >= slow + signalPeriod else { return nil }
        let fastSeries = emaSeries(closes, period: fast)
        let slowSeries = emaSeries(closes, period: slow)
        guard !fastSeries.isEmpty, !slowSeries.isEmpty else { return nil }
        // The slow EMA series is shorter; align on its tail length.
        let count = min(fastSeries.count, slowSeries.count)
        let macdLine = zip(fastSeries.suffix(count), slowSeries.suffix(count)).map { $0 - $1 }
        guard let signal = ema(macdLine, period: signalPeriod), let last = macdLine.last else { return nil }
        return MACDValue(macd: last, signal: signal, histogram: last - signal)
    }

    /// Wilder's Average True Range over `period` (default 14). Highs/lows/closes
    /// must be equal length and newest-last.
    nonisolated static func atr(highs: [Double], lows: [Double], closes: [Double], period: Int = 14) -> Double? {
        let n = closes.count
        guard period > 0, n > period, highs.count == n, lows.count == n else { return nil }
        var trs: [Double] = []
        trs.reserveCapacity(n - 1)
        for i in 1..<n {
            let tr = Swift.max(highs[i] - lows[i],
                               abs(highs[i] - closes[i - 1]),
                               abs(lows[i] - closes[i - 1]))
            trs.append(tr)
        }
        guard trs.count >= period else { return nil }
        var atr = trs.prefix(period).reduce(0, +) / Double(period)
        for tr in trs.dropFirst(period) {
            atr = (atr * Double(period - 1) + tr) / Double(period)
        }
        return atr
    }

    /// Kaufman Efficiency Ratio over `period`: |net change| ÷ Σ|step changes|.
    /// 0 = pure chop (mean-reverting), 1 = clean trend. A simple, robust regime
    /// discriminator (substitutes for ADX without its complexity).
    nonisolated static func efficiencyRatio(_ closes: [Double], period: Int = 20) -> Double? {
        guard period > 0, closes.count > period else { return nil }
        let window = Array(closes.suffix(period + 1))
        guard let first = window.first, let last = window.last else { return nil }
        let net = abs(last - first)
        var noise = 0.0
        for i in 1..<window.count { noise += abs(window[i] - window[i - 1]) }
        guard noise != 0 else { return 0 }
        return net / noise
    }

    /// Annualized realized volatility from closes: stdev of log returns × √periodsPerYear.
    nonisolated static func annualizedVolatility(_ closes: [Double], periodsPerYear: Double = 252) -> Double? {
        guard closes.count >= 3 else { return nil }
        var rets: [Double] = []
        for i in 1..<closes.count where closes[i - 1] > 0 {
            rets.append(log(closes[i] / closes[i - 1]))
        }
        guard rets.count >= 2 else { return nil }
        let mean = rets.reduce(0, +) / Double(rets.count)
        let variance = rets.reduce(0) { $0 + ($1 - mean) * ($1 - mean) } / Double(rets.count - 1)
        return variance.squareRoot() * periodsPerYear.squareRoot()
    }

    /// Percent return over the last `period` steps (e.g. 126 ≈ 6 trading months).
    nonisolated static func returnOverPeriod(_ closes: [Double], period: Int) -> Double? {
        guard period > 0, closes.count > period else { return nil }
        let past = closes[closes.count - 1 - period]
        guard past != 0, let last = closes.last else { return nil }
        return (last - past) / past * 100
    }

    /// Is the latest move backed by REAL volume? Compares the last `recentBars` of the
    /// (real, fetched) volume series against the `lookback` bars before them. ratio = recent
    /// avg ÷ prior avg; confirmed when ratio ≥ 1 (above-average participation). Returns nil
    /// when volumes are absent/all-zero (FX & indices have none) — never invents a number.
    nonisolated static func volumeConfirmation(closes: [Double], volumes: [Double],
                                               lookback: Int = 20, recentBars: Int = 3)
        -> (confirmed: Bool, ratio: Double)? {
        guard volumes.count == closes.count, lookback > 0, recentBars > 0,
              volumes.count >= lookback + recentBars else { return nil }
        let recent = volumes.suffix(recentBars)
        let prior  = volumes.dropLast(recentBars).suffix(lookback)
        let recentAvg = recent.reduce(0, +) / Double(recent.count)
        let priorAvg  = prior.reduce(0, +) / Double(prior.count)
        guard priorAvg > 0 else { return nil }   // no real volume to compare against
        let ratio = recentAvg / priorAvg
        return (confirmed: ratio >= 1.0, ratio: ratio)
    }
}
