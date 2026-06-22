import Foundation

// MARK: - TradeAdvice
//
// A concrete, actionable recommendation derived from a price history — the
// "what / when / how much / when-to-sell" the owner asked for. Honest by
// construction: every field is a RULES-BASED suggestion with a conviction and a
// permanent caveat, never a guarantee. Evidence behind each rule:
// MARKETS_INTELLIGENCE_RESEARCH.md.
struct TradeAdvice: Sendable, Equatable {
    enum Action: String, Sendable {
        case strongBuy = "Strong Buy"
        case buy       = "Buy"
        case hold      = "Hold"
        case avoid     = "Avoid"   // choppy / no edge — stand aside
        case reduce    = "Reduce"
        case sell      = "Sell"
    }
    enum Regime: String, Sendable {
        case bullTrend = "Bullish trend"
        case bearTrend = "Bearish trend"
        case range     = "Range-bound"
    }

    let action: Action
    /// 0–1 rules-based conviction — the strength of the signal confluence, NOT a
    /// probability of profit.
    let conviction: Double
    let regime: Regime
    /// The indicators that fired, in plain language.
    let rationale: [String]
    /// Protective stop price (ATR-based when highs/lows are available), if long-biased.
    let stopPrice: Double?
    /// Profit target at ≥2:1 reward:risk vs the stop, if long-biased.
    let targetPrice: Double?
    /// Suggested fraction of the book to size into this idea (0–1): fixed-fractional
    /// risk ÷ stop distance, scaled by conviction, hard-capped.
    let suggestedWeight: Double
    /// Always present — the honest reminder.
    let caveat: String
}

// MARK: - StockSageAdvisor
//
// Combines a few complementary, evidence-backed signals (trend, momentum, MACD,
// RSI) UNDER a regime filter (efficiency ratio) into a single `TradeAdvice`. The
// regime decides whether RSI extremes are reversal signals (range) or noise
// (trend) — the meta-rule that stops us fighting the tape. Pure + deterministic.
enum StockSageAdvisor {
    /// Risk budgeted per idea (fraction of equity lost if the stop is hit).
    /// 1% — evidence: smoother equity curve, materially lower max drawdown.
    nonisolated static let riskPerTrade = 0.01
    /// No single idea may be sized above this share of the book, whatever the math says.
    nonisolated static let maxWeight = 0.20

    nonisolated static let caveat = "Rules-based & educational — not a guarantee or financial advice. Markets are uncertain; size small and honor your stop."

    /// Advice straight from a fetched candle history — wires the live OHLC feed
    /// (`StockSageQuoteService.fetchHistory`) to the rules below, ATR stops included.
    nonisolated static func advise(history: StockSagePriceHistory) -> TradeAdvice {
        advise(closes: history.closes, highs: history.highs, lows: history.lows)
    }

    /// Advice from a daily close history (+ optional highs/lows for ATR stops).
    /// Series are newest-last. Conservative "Hold" when history is too short.
    nonisolated static func advise(closes: [Double], highs: [Double]? = nil, lows: [Double]? = nil) -> TradeAdvice {
        guard closes.count >= 30, let price = closes.last, price > 0 else {
            return TradeAdvice(action: .hold, conviction: 0, regime: .range,
                               rationale: ["Not enough price history to judge."],
                               stopPrice: nil, targetPrice: nil, suggestedWeight: 0, caveat: caveat)
        }

        // Real periods only — never substitute a shorter window for the 200DMA
        // (with <200 bars `min(200,count)` made the 50DMA and 200DMA identical and
        // silently disabled the heaviest trend signal).
        let sma50  = closes.count >= 50  ? StockSageIndicators.sma(closes, period: 50)  : nil
        let sma200 = closes.count >= 200 ? StockSageIndicators.sma(closes, period: 200) : nil
        let rsi    = StockSageIndicators.rsi(closes) ?? 50
        let macd   = StockSageIndicators.macd(closes)
        let er     = StockSageIndicators.efficiencyRatio(closes) ?? 0
        let mom    = StockSageIndicators.returnOverPeriod(closes, period: min(closes.count - 1, 126)) ?? 0
        var atr: Double? = nil
        if let highs, let lows { atr = StockSageIndicators.atr(highs: highs, lows: lows, closes: closes) }

        var rationale: [String] = []
        var score = 0.0   // directional, roughly -1 … +1

        // Trend (heaviest weight — the most robust documented edge).
        if let s50 = sma50, let s200 = sma200 {
            if price > s50, s50 > s200 { score += 0.40; rationale.append("Uptrend — price > 50DMA > 200DMA") }
            else if price < s50, s50 < s200 { score -= 0.40; rationale.append("Downtrend — price < 50DMA < 200DMA") }
            else if price > s200 { score += 0.15; rationale.append("Above the 200DMA (long-term bullish)") }
            else { score -= 0.15; rationale.append("Below the 200DMA (long-term bearish)") }
        } else if let s50 = sma50 {
            // 50–200 bars: a real 50DMA but no true 200DMA — a lighter, honest read.
            if price > s50 { score += 0.20; rationale.append("Above the 50DMA (uptrend, <200 bars history)") }
            else { score -= 0.20; rationale.append("Below the 50DMA (downtrend, <200 bars history)") }
        }
        // Momentum (~6-month).
        if mom > 0 { score += 0.15; rationale.append(String(format: "+%.0f%% 6-month momentum", mom)) }
        else if mom < 0 { score -= 0.15; rationale.append(String(format: "%.0f%% 6-month momentum", mom)) }
        // MACD trend confirmation — weighted LIGHTER than independent momentum
        // (±0.10 vs ±0.15): the research calls it a confirmation signal that
        // "over-signals alone" and it's the most redundant with the 0.40 trend term,
        // so it shouldn't stack at equal weight (independent calibration review).
        if let m = macd {
            if m.histogram > 0 { score += 0.10; rationale.append("MACD above signal (bullish)") }
            else if m.histogram < 0 { score -= 0.10; rationale.append("MACD below signal (bearish)") }
        }

        // Regime: trending vs choppy decides how to read RSI.
        let trending = er >= 0.30
        if !trending {
            if rsi < 30 { score += 0.25; rationale.append(String(format: "RSI %.0f oversold in a range — bounce setup", rsi)) }
            else if rsi > 70 { score -= 0.25; rationale.append(String(format: "RSI %.0f overbought in a range — fade setup", rsi)) }
        } else {
            if rsi > 80 { score -= 0.10; rationale.append("RSI > 80 — extended; trail stops") }
            else if rsi < 20 { score += 0.10; rationale.append("RSI < 20 — washed out") }
        }

        let regime: TradeAdvice.Regime = trending ? (score >= 0 ? .bullTrend : .bearTrend) : .range

        // Score → action. In a choppy regime with no edge, prefer "Avoid" (stand
        // aside) over "Hold" — the research is clear that forcing trades in chop loses.
        let action: TradeAdvice.Action
        switch score {
        case 0.5...:        action = .strongBuy
        case 0.2..<0.5:     action = .buy
        case -0.2..<0.2:    action = trending ? .hold : .avoid
        case -0.5 ..< -0.2: action = .reduce
        default:            action = .sell
        }
        let conviction = Swift.min(abs(score), 1.0)
        // Only a buy-family verdict gets an actionable trade plan. Gating on the
        // ACTION (not raw score>0) stops a "Hold"/"Avoid" card from also showing a
        // stop, target, and position size — which contradicted the recommendation.
        let isBuy = action == .buy || action == .strongBuy

        // Stop & target (long-biased framing; a short mirrors it).
        var stop: Double? = nil
        var target: Double? = nil
        if isBuy {
            if let atr, atr > 0 {
                let s = price - 2 * atr                  // 2-ATR swing stop
                stop = s
                target = price + 2 * (price - s)         // 2:1 reward:risk
            } else {
                let s = price * 0.92                      // fallback 8% stop (no OHLC)
                stop = s
                target = price + 2 * (price - s)
            }
        }

        // Position size: risk budget ÷ stop distance %, scaled by conviction, capped.
        var weight = 0.0
        if isBuy, let stop, stop < price {
            let stopDistPct = (price - stop) / price
            if stopDistPct > 0 {
                weight = (riskPerTrade / stopDistPct) * (0.4 + 0.6 * conviction)
                weight = Swift.min(weight, maxWeight)
            }
        }

        return TradeAdvice(action: action, conviction: conviction, regime: regime,
                           rationale: rationale, stopPrice: stop, targetPrice: target,
                           suggestedWeight: weight, caveat: caveat)
    }
}
