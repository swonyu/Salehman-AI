# Markets-money grand-sweep roadmap (wkigepmwy, 2026-06-22)

⚠ 5 items — DRAFT QUALITY. The workflow's 2-skeptic adversarial verify layer FAILED (parallel() got promises not thunks), so these were NOT double-verified. RE-VERIFY EACH against real source before building. Burn: 44 agents / 2.27M tokens.
Theme: most items CORRECT over-stated edge (selection bias, size-blind cost, edge decay, tail risk) — honesty-positive.

### ⬜ #1 [Validation/Backtest] — Deflated Sharpe + multiple-testing haircut on every backtest
**mechanism:** The watchlist/strategy backtester (StockSageBacktester.swift) reports a raw per-trade Sharpe and a crude trades>=20 significance flag. When the owner scans N symbols and surfaces the best, the winner's Sharpe is selection-biased upward. Add a Probabilistic Sharpe Ratio (PSR) and Deflated Sharpe Ratio (DSR) that haircut the observed Sharpe for (a) sample length, (b) return skew/kurtosis, and (c) the number of trials N that were scanned to find it. Surface DSR>0.95 as the only 'real' bar; show the raw Sharpe struck through next to the deflated one.

**signature:** func deflatedSharpe(observedSharpe: Double, nTrades: Int, skew: Double, kurtosis: Double, trialsTested: Int) -> (psr: Double, dsr: Double, passes: Bool)

**test:** Bailey-Lopez de Prado reference case: observed SR=1.0 (annualized), 24 obs, skew=-3, kurtosis=10, 10 trials tested -> DSR should fall well below PSR and below 0.95 (fails). With trialsTested=1, skew=0, kurtosis=3, 250 obs, same SR -> PSR>0.95 (passes). assert dsr(...,trials=10) < dsr(...,trials=1); assert that as trialsTested rises, dsr monotonically falls.

**caveat:** DSR assumes the trials are roughly independent and the variance of trial Sharpes is estimable; a scan over 14 highly-correlated mega-caps violates independence, so DSR is itself optimistic. It corrects the direction of the bias, not its exact magnitude.

**edgeRationale:** Does NOT double-count the backtester — it corrects the number the backtester already prints. The single highest expected-$ item because every downstream sizing decision (Kelly, EV, velocity) inherits the backtest's win-rate/payoff; if that Sharpe is a multiple-testing artifact, the whole money-velocity stack compounds a phantom edge into real position sizes. Pure, deterministic, ~40 lines, unit-testable against published reference values.

### ⬜ #2 [Execution/Liquidity] — Size-dependent slippage replacing flat-bps cost in NetEdge
**mechanism:** StockSageNetEdge.swift charges a flat round-trip bps estimate regardless of order size; StockSageLiquidity.swift tiers ADV but never feeds it back into cost. Wire them: model slippage as a function of (order notional / ADV) using a square-root market-impact term, impact_bps = k * sqrt(participationRate). Feed the resulting size-aware cost into the existing NetEdge break-even win-rate so the after-cost p* rises for thin names at real size. The plumbing (NetEdge, Liquidity, PositionSizer notional) already exists; this is the missing join.

**signature:** func impactAwareCost(notional: Double, avgDollarVolume: Double, baseSpreadBps: Double, k: Double = 10) -> AllInCost

**test:** Monotonicity + scale: for fixed ADV, impact bps strictly increases in notional and grows ~as sqrt (doubling notional multiplies the impact leg by ~1.41, not 2). assert cost(2*notional).slippageCost / cost(notional).slippageCost is within [1.3,1.5]. A $1k order in a $500M/day name -> impact leg ~0 bps; a $200k order in a $2M/day thin name -> impact leg dominates and pushes NetEdge.breakEvenWinRate materially higher (assert it clears the existing flat-cost p*).

**caveat:** k (the impact coefficient) is a single global constant fit to nothing here — true impact varies by venue, urgency, and time-of-day. It is a labeled estimate, strictly better than the current size-blind flat bps, but still not a fill simulator.

**edgeRationale:** Additive, not duplicative: NetEdge already exists but is size-blind, which systematically flatters exactly the thin, high-turnover 'fast-lane' names the velocity feature ranks highest. This closes the loop between the liquidity tier and the cost model — the place where the current stack most over-states realizable edge. High expected-$ because it directly demotes the crypto/thin-name velocity trades that look best precisely because their costs are mismodeled.

### ⬜ #3 [Validation/Backtest] — Out-of-sample / walk-forward decay metric surfaced to the UI
**mechanism:** The backtester is walk-forward-clean (no look-ahead) but reports ONE pooled stat over the whole history; it never splits in-sample vs out-of-sample to show edge DECAY. Add a chronological split (e.g. first 70% to 'fit/observe', last 30% as held-out OOS) and report the ratio OOS_avgR / IS_avgR. A healthy rule keeps most of its edge OOS; an overfit one collapses. Surface decayRatio with a red flag below ~0.5.

**signature:** func walkForwardDecay(trades: [BacktestTrade], oosFraction: Double = 0.3) -> (isAvgR: Double, oosAvgR: Double, decayRatio: Double, oosSignificant: Bool)

**test:** Synthetic edge that is constant across time -> decayRatio ~1.0. Synthetic series where all winners are in the first half and losers in the second -> isAvgR>0, oosAvgR<0, decayRatio<0. assert a stationary positive-R stream gives decayRatio in [0.8,1.2]; assert a front-loaded-edge stream gives decayRatio<0.5 and oosSignificant flips false when the OOS slice has <20 trades.

**caveat:** A single fixed split is itself a one-shot test — with few trades the OOS slice is tiny and noisy, so a low decayRatio can be sampling noise rather than overfit. It flags suspicion, it does not prove overfitting; combine with rank-1 DSR.

**edgeRationale:** Not a duplicate of the backtester's pooled Sharpe — it's the time-stability dimension the pooled number hides. The existing isSignificant flag answers 'enough trades?'; this answers the orthogonal 'did the edge survive into unseen data?'. Cheap (reuses the existing trade array), high expected-$ because it catches rules that backtest beautifully and then bleed live.

### ⬜ #4 [Risk/Drawdown] — Monte-Carlo ruin & drawdown distribution from journal win/payoff
**mechanism:** The journal computes worst-historical-streak and the summary models a drawdown brake from that ONE realized path (StockSageDrawdown/MoneyVelocitySummary). One path understates the tail. Bootstrap/resample the journal's per-trade R outcomes (or use the estimated W and payoff) for K simulated 100-trade futures at the configured risk-per-trade fraction, and report the distribution: P(drawdown > 20%), P(ruin = account < 50%), median and 95th-percentile max drawdown. This is the forward-looking complement to the existing backward-looking streak.

**signature:** func ruinDistribution(perTradeR: [Double], riskFraction: Double, horizon: Int = 100, sims: Int = 10000, seed: UInt64) -> (pRuin: Double, p20ddProb: Double, medianMaxDD: Double, p95MaxDD: Double)

**test:** Seeded determinism: same seed -> identical outputs (reproducible, unit-testable despite randomness). Sanity bounds: a sample of all +1R trades -> pRuin=0, p95MaxDD small. A 45% win / 1.0 payoff (negative-edge) stream at 2% risk -> pRuin>0 and rising in riskFraction (assert ruin(risk=0.05).pRuin > ruin(risk=0.01).pRuin). Assert p95MaxDD >= medianMaxDD always.

**caveat:** Bootstrapping the journal assumes trades are i.i.d. and that future trades resemble past ones — it ignores serial correlation and regime shifts, so it understates clustered-loss tails. The estimate is only as honest as the journal sample size; with <30 trades the resample is thin.

**edgeRationale:** Distinct from the existing single-path underwater curve and the streak brake: those describe what DID happen; this quantifies the DISTRIBUTION of what could, including ruin probability the current stack never names. High expected-$ via capital preservation — it's the dimension that converts a positive-EV edge into a survivable one, and it directly tightens the riskFraction the Kelly cap already exposes.

### ⬜ #5 [Position Sizing] — Vol-targeted position sizing as an alternative to fixed 1%-risk
**mechanism:** PositionSizer sizes by stop-distance at a fixed risk% per trade; this is correct but leaves total-portfolio volatility drifting as the book's average vol changes. Add a vol-target overlay: scale gross exposure so realized portfolio vol targets a constant (e.g. 12% annualized), using each name's annualized vol (already computed for risk-parity). When vol spikes, the target shrinks size; when it's calm, it permits more. Composes with the existing regime sizing bias rather than replacing it.

**signature:** func volTargetScalar(currentPortfolioVol: Double, targetVol: Double = 0.12, maxLeverage: Double = 1.5) -> Double

**test:** currentVol==targetVol -> scalar 1.0. currentVol=0.24, target=0.12 -> scalar 0.5 (halve exposure). currentVol=0.06 -> scalar capped at maxLeverage (2.0 clamped to 1.5). assert scalar is monotonically decreasing in currentPortfolioVol and never exceeds maxLeverage; assert scalar*currentVol ~= targetVol whenever the cap is not binding.

**caveat:** Vol-targeting uses TRAILING vol, which lags regime turns — it de-risks AFTER volatility has already risen, so it cushions drawdowns but does not pre-empt them, and it can whipsaw size in choppy vol. It overlaps partly with the regime sizingBias; ship it as a SELECTABLE alternative, not stacked on top, or the two corrections compound.

**edgeRationale:** Borderline but kept because it targets a dimension (constant portfolio-level risk) that per-trade fixed-risk sizing does NOT control, and it reuses the annualized-vol inputs risk-parity already produces. The honest caveat flags the partial overlap with regime bias — which is exactly why it ranks last and ships as an alternative rather than an additional multiplier, to avoid double-counting the regime edge.
