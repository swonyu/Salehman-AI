import Foundation

// MARK: - Glossary & asset-class risk notes
//
// Every number in the Markets tab is backward-looking and rules-based, not a
// forecast. These plain-language explainers (shown as ⓘ tooltips on each card)
// say what each stat means AND that it describes the past. The asset-class notes
// surface the structural risks of FX / crypto / index instruments that a single
// price line hides.

enum StockSageGlossary {

    // Per-card help — concise, honest, hover-reveal.
    nonisolated static let analyticsHelp = """
    Sharpe: annualized return per unit of TOTAL volatility — higher = smoother. \
    Sortino: like Sharpe but penalizes only DOWNSIDE volatility (upside swings don't count against you). \
    Calmar: annual return ÷ worst drawdown. VaR95: a daily loss the book exceeds ~1 day in 20 — a routine bad day, NOT a worst case. \
    Diversification (0–100): 100 = effectively independent holdings, 0 = one concentrated bet (blends average pairwise correlation with how many names you hold). All backward-looking: past behavior, not a prediction.
    """

    nonisolated static let regimeHelp = """
    A risk-on/off gauge from the S&P 500 vs its 200-day average, its momentum, the VIX, and breadth \
    (how many large-caps are above their own 200-day line). It sets a sizing BIAS — smaller risk-off, larger risk-on — \
    not a buy/sell call. A gauge of conditions, not a forecast; re-gauge it intraday as things move.
    """

    nonisolated static let kellyHelp = """
    Kelly = the bet fraction that maximizes long-run growth GIVEN your edge (win-rate W and payoff ratio R): f* = W − (1−W)/R. \
    Full Kelly is famously too aggressive — one bad streak ruins it — so this shows HALF and QUARTER Kelly and caps the suggestion at 20%. \
    Garbage in, garbage out: if your W and R estimates are optimistic, so is the size.
    """

    nonisolated static let heatmapHelp = """
    Pairwise correlation of daily returns. Green (≤0) = the two move independently or opposite — real diversification. \
    Red (>0, deeper = closer to +1) = they move together, so they're closer to one position than two. \
    Correlations rise in crashes exactly when you need diversification most — treat low correlation as fragile.
    """

    nonisolated static let strategyHelp = """
    The advisor's fixed rules run across a sample of names over ~5 years and pooled: total trades, blended win-rate, \
    expectancy (avg R), total R, worst single-name drawdown, % of names profitable. Backward-looking, small-sample, \
    survivorship-biased, and the rules are FIXED not optimized — an illustration of behavior, not a promise.
    """

    nonisolated static let journalHelp = """
    Your own record of trades taken. R-multiple = profit ÷ the risk you defined at entry (entry→stop), so +2R means you made \
    twice what you risked. Stats cover CLOSED trades only. A journal documents your decisions — it doesn't validate them.
    """

    nonisolated static let betaHelp = """
    Beta vs the S&P 500: how much your book moves WITH the market. β=1 tracks it; β>1 AMPLIFIES both gains and losses \
    (β1.5 ≈ 50% bigger swings than the index); β<1 damps it; β<0 moves opposite (a hedge). Backward-looking over ~1 year \
    of daily returns — it drifts as holdings and correlations change.
    """

    /// Structural risk note for FX / crypto / index symbols; nil for a plain equity.
    nonisolated static func assetClassRiskNote(for symbol: String) -> String? {
        switch StockSageAllocation.assetClass(symbol) {
        case "Crypto":
            return "Crypto trades 24/7 with no circuit breakers and weekend gaps, and has historically run 2–4× equity volatility — size smaller and expect deeper swings than the indicators imply."
        case "Forex":
            return "FX trades ~24/5 and is driven by rates, macro and central-bank policy, with weekend gaps. Leverage is implicit — treat the full notional as your risk, not the margin."
        case "Index":
            return "This is an index LEVEL, not directly tradable — use it as a regime/context gauge; get exposure via an ETF or future, whose costs and tracking differ."
        default:
            return nil
        }
    }
}
