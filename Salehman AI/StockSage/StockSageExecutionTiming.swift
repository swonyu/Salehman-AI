import Foundation

// MARK: - Execution-timing advisory (week-horizon velocity research, item #2)
//
// Evidence: Lou, Polk & Skouras, "A Tug of War: Overnight vs Intraday Expected Returns"
// (JFE; verified 3-0 ×3 in RESEARCH_2026-07-02_week_horizon_velocity.md). Across 14 US
// strategies (1993-2013, non-microcap), all five PAST-RETURN strategies — 12-1 price
// momentum, industry momentum, earnings momentum, time-series momentum, and short-term
// reversal — earn their premia ENTIRELY OVERNIGHT (12-1 momentum: overnight CAPM alpha
// 0.98%/month t=3.84 vs intraday −0.02% t=−0.06; overnight Sharpe 0.77 vs 0.31 close-to-
// close), while nine OTHER anomaly types earn entirely intraday. This is a ZERO-added-
// turnover lever: it changes WHEN an already-planned entry executes, not whether to trade.
//
// StockSage's OWN trend-family signal (12-1 TSMOM + SMA/MACD trend, capped together —
// StockSageAdvisor.trendFamilyCap) is exactly a past-return / momentum-family construction,
// so this applies directly to any idea whose regime reads `.bullTrend`/`.bearTrend` (a
// score-positive/negative TRENDING read, not the `.range` mean-reversion/RSI-bounce case,
// which is a structurally different signal type this specific finding doesn't cover).
//
// Advisory ONLY: appended to `rationale`, exactly like ReturnShape/VolStability/VolRegime/
// SectorRotation before it. Never touches score/conviction/stopPrice/targetPrice/
// suggestedWeight — the ranking/sizing math is completely untouched.

enum StockSageExecutionTiming {
    nonisolated static let caveat =
        "A documented pattern (Lou-Polk-Skouras), not a promise for any single trade — timing an " +
        "entry doesn't change WHICH setups to take, only when to place an already-decided order."

    /// Advisory note for a trend-driven buy/sell idea: momentum/trend premia are documented to
    /// accrue almost entirely in the OVERNIGHT session, so entering near the close (to hold the
    /// position overnight) captures more of the historical edge than a mid-session entry. nil for
    /// non-trending (`.range`) or non-actionable (`.hold`/`.avoid`) advice — this is specifically
    /// the momentum-family finding, not a generic timing tip.
    nonisolated static func sessionNote(action: TradeAdvice.Action, regime: TradeAdvice.Regime) -> String? {
        guard action == .strongBuy || action == .buy || action == .sell || action == .reduce else { return nil }
        switch regime {
        case .bullTrend, .bearTrend:
            return "Trend/momentum premia are documented to accrue almost entirely OVERNIGHT — " +
                   "entering near the close (to hold the position overnight) has historically captured " +
                   "more of this edge than a mid-session entry."
        case .range:
            return nil
        }
    }
}
