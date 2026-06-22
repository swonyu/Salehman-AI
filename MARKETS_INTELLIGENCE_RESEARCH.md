# Markets Intelligence — research & design (what to buy, when, how much, when to sell)

**Owner goal (2026-06-20):** make Salehman AI's Markets tab tell *me* what to buy,
when to buy, when to sell, and how much — every legitimate edge available.
**Single user (owner only).**

**Honest frame first (this is the most important section).** No system predicts
markets reliably. Every rule below is an *edge-shifter*, not a guarantee. The
academic + practitioner consensus is blunt: *"the effectiveness of any strategy
depends on discipline and consistency, not prediction."* So this app's job is to
turn vague hunches into **rules with explicit risk** — a stop you set before you
enter, a size that survives being wrong, and signals with documented (modest)
edge — then get out of the way. Built to help the owner decide, never to promise
profit. The biggest money-maker here is **not losing big**: position sizing and
stops dominate signal quality in every study below.

---

## 1. The decision framework

| Question | Answer the app should give | Backed by |
|---|---|---|
| **What to buy** | Instruments in a confirmed uptrend with positive momentum and a supportive regime | Trend/TSM, momentum factor |
| **When to buy** | On trend confirmation (price>50DMA>200DMA, MACD>signal) in a *trending* regime, or oversold (RSI<30) in a *range* regime | Regime filter |
| **When to sell** | Stop hit (thesis invalidated), target hit (R:R≥2:1), trend break, or trailing-stop ratchet | ATR stops, R:R |
| **How much** | Fixed-fractional risk (≈1% equity/idea) ÷ stop distance, scaled by conviction & inverse volatility, capped | Fixed-fractional, fractional Kelly |

---

## 2. Signals with real, documented edge (keep it to 2–3 complementary ones)

> ⚠️ The *Journal of Banking & Finance* warning: using >4–5 indicators causes
> curve-fitting and poor out-of-sample results. Use a few **complementary** ones.

- **Trend / Time-Series Momentum (TSM)** — *the strongest, most robust edge.*
  Moskowitz, Ooi & Pedersen (2012) documented significant TSM profits across
  asset classes; trend strategies show **Sharpe ≈ 1.2+** and are *counter-cyclical*
  (diversify a portfolio). Implementation: **sign of the trailing 12-month return**
  and/or **price vs the 200-day moving average**; rebalance monthly; **volatility-scale**
  the position.
- **Cross-sectional momentum** — rank a universe by trailing 3–12m return; favor
  top performers ("Value and Momentum Everywhere", Asness/Moskowitz/Pedersen).
- **MACD (12,26,9)** — trend *confirmation*: MACD line vs signal, histogram sign.
  Better for longer trends; tends to over-signal alone.
- **RSI (14)** — *mean-reversion* tool: <30 oversold / >70 overbought. Fewer
  signals than MACD. **Only trust RSI extremes in a range regime** (see §4).

## 3. Position sizing — "how much" (this matters more than the signal)

- **Fixed-fractional** (default): risk a fixed % of equity per idea (commonly
  **1–2%**). Balsara (1992): significantly lower max drawdown + smoother equity
  curve. Position = `riskPct × equity ÷ (entry − stop)`.
- **ATR-based**: size so a `k×ATR` stop equals the risk budget — adapts to
  current volatility automatically.
- **Fractional Kelly**: full Kelly (`f* = W − (1−W)/R`, W=win rate, R=win/loss
  payoff) maximizes long-run growth but Gehm (1983) showed full Kelly → **>50%
  drawdowns**. Pros use **¼–½ Kelly**: cuts volatility more than growth.
- **Volatility targeting**: scale inversely to realized/implied vol; bigger when
  calm, smaller when wild.
- **Hard cap**: never let one idea exceed ~10–20% of the book regardless of math.

## 4. Regime filter — the meta-rule that ties signals together

Markets are **mean-reverting ~60%** of the time and **trending ~40%**. Applying a
trend system in a choppy tape (or RSI-fades in a strong trend) is the classic way
to lose. So **detect the regime first, then pick the signal**:

- **Trending** (use trend/MACD/breakout): `ADX>25`, or price clearly above/below
  the 200DMA, or a high **Kaufman Efficiency Ratio** (|net move| ÷ path length → 1).
- **Range** (use RSI mean-reversion): `ADX<20`, low efficiency ratio.
- **Bias from the index**: above 200DMA → favor longs; below → cut long exposure.
- Use regime as a **filter**, not a direct entry.

## 5. Exits — "when to sell" (define both prices *before* entering)

- **Stop-loss** at the level where the thesis is wrong. **ATR-based** adapts to
  volatility: swing trades **1.5–3.0×ATR**, intraday 0.6–1.0×ATR.
- **Target** ≥ **2× the stop distance** (R:R ≥ 2:1; 3:1 when the chart allows) —
  at 1:3 you only need a ~33% win rate to break even.
- **Trailing stop** (ATR or %) to ride trends — but defined in the plan, *not* an
  emotional reaction when a trade turns green.

## 6. Portfolio construction — diversify by *risk*, not dollars

- A 60/40 portfolio holds ~85–90% of its **risk** in equities. **Risk parity /
  inverse-volatility weighting** equalizes each holding's risk contribution and
  historically improves Sharpe + downside resilience.
- **Rebalance with rules** (calendar or threshold), not feelings.
- Caveat: risk parity suffers in **correlation-regime shocks** (e.g. Q1-2020), so
  keep a cash/hedge sleeve.

## 7. Don't fool yourself — backtesting honesty (or the "edge" is fake)

- **Look-ahead bias** — never use data unavailable at decision time (e.g. same-day
  close to trade the open).
- **Survivorship bias** — include delisted/bankrupt names or results inflate.
- **Overfitting** — few rules, few parameters; test across regimes.
- **Multiple testing** — try enough strategies and one looks great by luck. Adjust.
- **Out-of-sample / walk-forward validation is mandatory** — in-sample numbers are
  "statistically meaningless" otherwise.

---

## 8. How this lands in the app (build roadmap)

1. **`StockSageIndicators`** (DONE) — pure SMA/EMA/RSI/MACD/ATR/efficiency-ratio/
   realized-vol/return. Total + unit-tested.
2. **`StockSageAdvisor`** (DONE) — combines trend + momentum + MACD + RSI under a
   regime filter → a `TradeAdvice`: action, conviction, regime, rationale, **stop**,
   **target**, **suggested position weight**, and a permanent honest caveat.
3. **Historical candles** (NEXT) — extend the quote service to fetch daily OHLC
   history (Yahoo `chart?range=1y&interval=1d`) so indicators have real data.
4. **Advice UI** — per-symbol card: action + conviction meter + stop/target +
   "size N% of book" + the reasons; a ranked "best ideas now" board.
5. **Risk-parity portfolio sizing** across holdings; rebalance suggestions.
6. **Backtester** — walk-forward, OOS, with the bias guards above; show honest
   hit-rate / max-drawdown / Sharpe, never a cherry-picked curve.
7. **Alerts** — notify when a strong setup appears or a stop is breached.

## Sources
- [Time-Series Momentum — historical evidence (Alpha Architect)](https://alphaarchitect.com/time-series-momentum-aka-trend-following-the-historical-evidence/) · [Moskowitz, Ooi, Pedersen, "Time series momentum" (ScienceDirect)](https://www.sciencedirect.com/science/article/pii/S0304405X11002613) · [Value and Momentum Everywhere (NYU Stern PDF)](https://pages.stern.nyu.edu/~lpederse/papers/ValMomEverywhere.pdf)
- [RSI & MACD effectiveness (ResearchGate)](https://www.researchgate.net/publication/392317792_Analysis_of_the_Effectiveness_of_RSI_and_MACD_Indicators_in_Addressing_Stock_Price_Volatility) · [RSI vs MACD (LiteFinance)](https://www.litefinance.org/blog/for-beginners/best-technical-indicators/rsi-vs-macd/)
- [Kelly vs Fixed-Fractional (Medium)](https://medium.com/@tmapendembe_28659/kelly-criterion-vs-fixed-fractional-which-risk-model-maximizes-long-term-growth-972ecb606e6c) · [Position sizing frameworks: fixed-fractional, ATR, Kelly-lite (Medium)](https://medium.com/@ildiveliu/risk-before-returns-position-sizing-frameworks-fixed-fractional-atr-based-kelly-lite-4513f770a82a) · [Kelly position sizing (TradersPost)](https://blog.traderspost.io/article/kelly-criterion-position-sizing-automated-trading)
- [Market regime detection (LuxAlgo)](https://www.luxalgo.com/blog/market-regimes-explained-build-winning-trading-strategies/) · [Identify regimes by trend & volatility (QuantMonitor)](https://quantmonitor.net/how-to-identify-market-regimes-and-filter-strategies-by-trend-and-volatility/)
- [ATR stops & risk management (Superalgos/Medium)](https://medium.com/superalgos/basics-of-risk-management-at-trading-stop-loss-take-profit-and-position-sizing-with-atr-cafe35dec774) · [ATR trailing stops (TrendSpider)](https://trendspider.com/learning-center/atr-trailing-stops-a-guide-to-better-risk-management/)
- [Understanding Risk Parity (AQR PDF)](https://www.aqr.com/-/media/AQR/Documents/Insights/White-Papers/Understanding-Risk-Parity.pdf) · [Risk parity (Wikipedia)](https://en.wikipedia.org/wiki/Risk_parity)
- [Backtesting pitfalls (Starqube)](https://starqube.com/backtesting-investment-strategies/) · [Avoiding bias in backtesting (ForTraders)](https://www.fortraders.com/blog/how-to-avoid-bias-in-backtesting)

*Educational research compiled for the owner's personal use. Not investment advice.*
