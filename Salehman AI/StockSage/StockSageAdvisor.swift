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
    /// The ATR multiple used for the stop: 2.0 by default, widened to 2.5 for high-volatility
    /// names (so normal noise doesn't whipsaw the trade out) and tightened to 1.5 for calm ones.
    var stopMultiplier: Double = 2.0
    /// Plain-language reason for the stop width (e.g. "2.5×ATR — sized for 72% volatility"),
    /// surfaced in the idea detail. nil when volatility wasn't available.
    var stopReason: String? = nil
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
    nonisolated static func advise(history: StockSagePriceHistory,
                                   benchmark: StockSagePriceHistory? = nil) -> TradeAdvice {
        advise(closes: history.closes, highs: history.highs, lows: history.lows,
               volumes: history.volumes, benchmarkCloses: benchmark?.closes)
    }

    /// Advice from a daily close history (+ optional highs/lows for ATR stops, optional REAL
    /// volumes for participation confirmation, and optional benchmark closes for relative
    /// strength). Series are newest-last. Conservative "Hold" when history is too short.
    /// HONESTY NOTE: the `volumes` and `benchmarkCloses` terms are gated on those inputs (nil ⇒
    /// not applied). But passing `highs`/`lows` ALSO enables the ATR stop and the volatility-
    /// adjusted-momentum nudge, and the stop width always scales with realized volatility derived
    /// from `closes` — so a close-only call and a highs/lows call are NOT identical, and any
    /// caller that supplies highs/lows (including the backtester) gets the fuller signal. (Only
    /// `stopTarget` with `realizedVol: nil` is byte-identical to the legacy 2-ATR stop.)
    nonisolated static func advise(closes: [Double], highs: [Double]? = nil, lows: [Double]? = nil,
                                   volumes: [Double]? = nil, benchmarkCloses: [Double]? = nil) -> TradeAdvice {
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

        // Volume confirmation (real volumes only): a directional move carried by
        // above-average participation is more trustworthy; one on thin volume is suspect.
        // Nudges the MAGNITUDE of the existing signal (±0.05), never flips its direction,
        // and does nothing when volumes are absent/zero (FX, indices) — so the
        // close-only callers (e.g. the backtester) are unchanged.
        if let volumes, abs(score) > 0,
           let vc = StockSageIndicators.volumeConfirmation(closes: closes, volumes: volumes) {
            let dir = score >= 0 ? 1.0 : -1.0
            score += dir * (vc.confirmed ? 0.05 : -0.05)
            rationale.append(vc.confirmed
                ? String(format: "Volume-confirmed (recent ×%.1f the prior average)", vc.ratio)
                : String(format: "Thin volume (recent ×%.1f the prior average) — weak participation", vc.ratio))
        }

        // Volatility-adjusted momentum quality (needs highs/lows for ATR): a move that's
        // large relative to the asset's OWN noise is a clean, risk-efficient trend; a same-%
        // move that's small next to violent swings is a whipsaw trap. Nudges ±0.05 in the
        // momentum's own direction (never flips it); skipped when |vam| is middling or no ATR.
        if let highs, let lows, mom != 0,
           let vam = StockSageIndicators.volAdjustedMomentum(closes: closes, highs: highs, lows: lows) {
            if abs(vam) >= 5 {
                score += vam > 0 ? 0.05 : -0.05
                rationale.append(String(format: "Volatility-efficient trend (momentum ÷ ATR%% ≈ %.0f)", abs(vam)))
            }
        }

        // Relative strength vs the benchmark (real index closes only): the documented
        // momentum edge is OUT-performance, not absolute drift. A name leading the S&P gets
        // a small confirmation; one merely rising with (or lagging) the market is demoted.
        // ±0.08, additive, and skipped entirely when no benchmark is supplied.
        if let benchmarkCloses,
           let rs = StockSageIndicators.relativeStrength(symbolCloses: closes, benchmarkCloses: benchmarkCloses) {
            if rs > 0 { score += 0.08; rationale.append(String(format: "Leading the S&P (relative strength +%.0f%%)", rs)) }
            else if rs < 0 { score -= 0.08; rationale.append(String(format: "Lagging the S&P (relative strength %.0f%%)", rs)) }
        }

        // Time-series (12-1) own-trend crash filter: veto a long-side score when the name is in
        // its OWN downtrend (the documented TSMOM crash-protection). −0.20 — strong enough to flip
        // a marginal buy to a hold/avoid. nil (insufficient bars) ⇒ no veto, unchanged.
        if score > 0, StockSageIndicators.trendOK(closes) == false {
            score -= 0.20
            rationale.append("Against the name's own 12-1 downtrend — momentum veto")
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

        let isSell = action == .sell || action == .reduce

        // Stop & target — symmetric: a long stops BELOW / targets ABOVE; a short mirrors it.
        // The ATR multiple now scales with the name's realized volatility (wider for crypto,
        // tighter for calm equities) so the stop fits the asset, not a one-size guess.
        let realizedVol = StockSageIndicators.annualizedVolatility(closes)
        let (stop, target) = Self.stopTarget(action: action, price: price, atr: atr, realizedVol: realizedVol)
        let stopMult = Self.stopMultiple(forVol: realizedVol)
        let stopReason = realizedVol.map { String(format: "%.1f×ATR stop — sized for %.0f%% annualized volatility", stopMult, $0 * 100) }

        // Position size: risk budget ÷ stop distance %, scaled by conviction, capped.
        // Distance is absolute so a short (stop > price) sizes the same as a long.
        var weight = 0.0
        if (isBuy || isSell), let stop {
            let stopDistPct = abs(price - stop) / price
            if stopDistPct > 0 {
                weight = (riskPerTrade / stopDistPct) * (0.4 + 0.6 * conviction)
                weight = Swift.min(weight, maxWeight)
            }
        }

        return TradeAdvice(action: action, conviction: conviction, regime: regime,
                           rationale: rationale, stopPrice: stop, targetPrice: target,
                           suggestedWeight: weight, caveat: caveat,
                           stopMultiplier: stopMult, stopReason: stopReason)
    }

    /// Symmetric 2-ATR swing stop + 2:1 target for an actionable buy/sell. Long: stop
    /// below, target above. Short (sell/reduce): stop ABOVE entry, target BELOW. 8% stop
    /// fallback when no ATR. (nil, nil) for hold/avoid or a non-positive price. Pure.
    /// ATR multiple for the stop, by realized volatility: a 70%-vol crypto needs a WIDER stop
    /// (2.5×) so ordinary daily noise doesn't whipsaw it out; a calm name can run a tighter
    /// 1.5×. nil vol → the documented 2.0× default (so existing callers are unchanged).
    nonisolated static func stopMultiple(forVol realizedVol: Double?) -> Double {
        guard let v = realizedVol else { return 2.0 }
        if v >= 0.70 { return 2.5 } else if v >= 0.40 { return 2.0 } else { return 1.5 }
    }

    nonisolated static func stopTarget(action: TradeAdvice.Action, price: Double, atr: Double?,
                                       realizedVol: Double? = nil)
        -> (stop: Double?, target: Double?) {
        let isBuy = action == .buy || action == .strongBuy
        let isSell = action == .sell || action == .reduce
        guard (isBuy || isSell), price > 0 else { return (nil, nil) }
        // realizedVol nil → 2×ATR / 8% fallback, BYTE-IDENTICAL to before. When supplied, the
        // ATR multiple scales with vol, and the no-ATR fallback widens for volatile names
        // (≈12% at 75% vol vs 8% baseline) — never tighter than 8%.
        let mult = stopMultiple(forVol: realizedVol)
        let fallbackPct = realizedVol.map { 0.08 * Swift.max(1.0, $0 / 0.50) } ?? 0.08
        let dist = (atr.map { $0 > 0 ? mult * $0 : price * fallbackPct }) ?? price * fallbackPct
        if isBuy {
            let s = price - dist
            guard s > 0 else { return (nil, nil) }   // ATR ≥ price ⇒ no sane long stop — untradeable
            return (s, price + 2 * (price - s))
        } else {
            let s = price + dist
            let t = price - 2 * (s - price)
            return (s, t > 0 ? t : nil)        // a degenerate (huge-ATR) negative target is dropped
        }
    }
}
