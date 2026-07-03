# Research: Residual (factor-neutralized) momentum — net-of-cost REAL-DATA ablation

**Date:** 2026-07-03 · **Author:** Opus session (autonomous ablation) · **Status:** NULL (net incremental edge not demonstrated) — a win; indexed.

## Question
Blitz, Huij & Martens (2011, "Residual Momentum"): standard 12-1 momentum carries market/beta
exposure that adds volatility and drives crashes/reversals. Residual momentum instead ranks
names on the momentum of their MARKET-RESIDUAL returns (regress daily returns on the market,
cumulate the residual over the formation window, standardize by residual vol). Claim: same
momentum premium, ~half the volatility, lower crash risk, and (hypothesis, not the paper's
own claim) lower whipsaw/turnover → plausibly better NET-of-cost. HONESTY QUESTION: is the
residual-momentum LONG cohort's net-of-cost edge over unconditional momentum real and
DSR-clearing, or does it wash out after costs like every other momentum refinement tried this
session (frog-in-the-pan, IRRX reversal)?

## Method
- **Panel reuse (no new fetch):** the cached low-beta ablation panel,
  `/tmp/lowbeta_ablation/panel.json` — 18 US large-caps {NVDA,AVGO,MU,AAPL,MSFT,GOOGL,JPM,BAC,
  XOM,CVX,PG,KO,WMT,JNJ,UNH,PFE,HD,CAT} + `^GSPC` market proxy, 5y daily Yahoo v8 chart data,
  1254 shared bars, one calendar verified across all 19 series. Frozen BEFORE this run (chosen
  for the low-beta ablation, reused verbatim per the ablation-harness "spare the shared
  endpoint" instruction). Same universe as the low-beta/frog-in-the-pan precedents —
  comparable, not cherry-picked.
- **Signal (residual momentum):** at each as-of bar `i`, fit a market-model regression
  (alpha, beta) per stock on trailing 252 daily close-to-close returns (`i-251..i`, the
  "trailing market-regression window"). Compute the residual series over that same window,
  take the 126-bar sub-window ending 21 bars before `i` (bars `i-146..i-21` — 12-1-style
  skip-recent, but 126 not 252 bars, per the assigned params), compound the residuals into a
  formation-window residual return, and standardize by the residual return's std dev over the
  full 252-bar window (`resid_cum / (resid_vol * sqrt(126))`). Cross-sectional rank, LONG top
  tercile (6 of 18).
- **Baseline (BASE):** unconditional 12-1-style momentum — raw price return over the identical
  formation window (`(close[i-21]-close[i-146])/close[i-146]`), same skip-21, same 126-bar
  formation, same tercile size (6 of 18). Only the signal differs; the window and cohort size
  are held fixed so the comparison isolates the residualization step.
- **No look-ahead:** signal built from bars `<= i` only (regression + formation both end at or
  before `i-21`); enter `open[i+1]`; exit `open[i+1+H]`. As-of index stepped by exactly `H`
  (non-overlapping blocks, genuinely independent).
- **Net-of-cost (mandatory):** `StockSageNetEdge.defaultCosts(forSymbol:)` ported exactly —
  US large-cap round-trip = spread 8bps + slippage 5bps = **13bps**, charged once per
  name per rebalance in both cohorts (same convention as the low-beta/frog precedents: a full
  round-trip charge per held name per block, NOT scaled by whether that name is a turnover
  event — see Limitations, this matters for the turnover claim below).
- **Block-level significance:** one net mean per non-overlapping block (RESID cohort mean,
  BASE cohort mean), incremental = RESID−BASE per block, paired t-test across blocks
  (t-CDF from scratch, self-checked t=2.228/df=10→p=0.0500, same anchor as prior ablations).
- **DSR gate:** `StockSageDeflatedSharpe` (normalCDF via erf, Acklam inverse-normal-CDF,
  skew/non-excess-kurtosis moments, PSR, expected-max-Sharpe, `deflated()`) ported verbatim
  from `Salehman AI/StockSage/StockSageDeflatedSharpe.swift`, self-checked against
  `inverseNormalCDF(0.975)≈1.959964`. `passes` = DSR>0.95. Selection-deflated over
  **trials=8** (RESID-absolute × 4 horizons + INCREMENTAL × 4 horizons — BASE excluded from
  the trial count as the fixed benchmark, not a promotion candidate); `varTrialSharpe` measured
  across those 8 per-block Sharpes (0.253).
- **Horizon sweep:** 21 / 42 / 63 / 126 trading days.
- **Turnover:** fraction of the 6-name cohort that changed between consecutive rebalances,
  tracked separately for RESID and BASE.
- **Crash/drawdown:** max drawdown of each arm's compounded per-block net series.

## Results
Net-of-cost per-block means (bp) and DSR (trials=8):

| H | blocks | RESID net | RESID mdd | BASE net | BASE mdd | INC (RESID−BASE) | INC t / p | RESID DSR | INC DSR | RESID turnover | BASE turnover |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 21  | 47 | +274.7bp | −10.6% | +311.3bp | −17.6% | −36.6bp  | t=−0.63 / p=0.530 | 0.191 | 0.000 | 46.0% | 23.6% |
| 42  | 23 | +614.8bp | −5.3%  | +677.8bp | −15.3% | −63.0bp  | t=−0.44 / p=0.666 | 0.666 | 0.000 | 54.5% | 34.8% |
| 63  | 15 | +812.4bp | −5.9%  | +947.2bp | −13.4% | −134.9bp | t=−0.63 / p=0.538 | 0.694 | 0.000 | 57.1% | 42.9% |
| 126 | 7  | +1309.2bp| −5.9%  | +1889.6bp| −0.1%  | −580.4bp | t=−0.85 / p=0.428 | 0.526 | 0.000 | 88.9% | 66.7% |

**1. VERDICT — every config fails DSR>0.95, absolute AND incremental.**
- RESID absolute: best DSR 0.694 (H=63) — closer than the frog-in-the-pan or IRRX
  precedents got, but still ≪0.95. This is bull-beta showing through (5y window is a large-cap
  tech-momentum bull run), not evidence of the residualization step adding value.
- INCREMENTAL (the clean, market-neutral test the task asked for): DSR **0.000 at every
  horizon** — the incremental Sharpe is negative at all four horizons, so the DSR floor bottoms
  out immediately. The point estimate is NEGATIVE, not merely insignificant: residual momentum
  underperformed plain 12-1 momentum net-of-cost by 37–580bp/block, worsening with horizon.
  None of the four incremental t-stats clear even the loosest textbook bar (all |t|<1, all
  p>0.4) — this is noise-consistent with zero, tilted negative.

**2. Turnover + crash comparison (the mechanism).**
- **Turnover: the hypothesis is FALSIFIED, not just unconfirmed.** Residual momentum's cohort
  turned over roughly TWICE as fast as plain momentum's at every horizon (46% vs 24% @21d,
  55% vs 35% @42d, 57% vs 43% @63d, 89% vs 67% @126d). Standardizing by residual (idiosyncratic)
  vol makes the ranking MORE sensitive to daily-scale noise in the residual series, not less —
  the opposite of the "steadier signal → lower whipsaw" intuition this ablation set out to test.
- **Crash/drawdown: partially supports the claim, but not cleanly.** RESID's max drawdown was
  smaller than BASE's at 3 of 4 horizons (10.6% vs 17.6% @21d; 5.3% vs 15.3% @42d; 5.9% vs 13.4%
  @63d) — consistent with the "lower crash risk" mechanism. It REVERSED at H=126 (RESID −5.9% vs
  BASE −0.1%), but that horizon has only 7 non-overlapping blocks — too few for the sign to mean
  much either way.
- **Does the mechanism translate to NET improvement? No.** Even where drawdown favored RESID,
  the net incremental return was negative at every horizon. And because the cost model here
  charges every held name the same round-trip fee per rebalance regardless of whether it's a
  new position (the same convention the low-beta/frog precedents use), it does not reward lower
  turnover — so RESID's higher (not lower) turnover isn't even fully penalized in this backtest;
  a turnover-sensitive cost model would very likely make the incremental verdict WORSE for
  RESID, not better. The lower-volatility property may still be real (smaller sd/blk at 3 of 4
  horizons: 457.7 vs 593.1bp @21d, 769.8 vs 934.9bp @42d, 974.4 vs 1140.3bp @63d), but a smoother
  ride at a lower net return is not automatically a better net Sharpe once the mean also drops.

## Conclusion
**NULL — the residual-momentum LONG cohort's net-of-cost edge over unconditional 12-1
momentum is NOT established; the point estimate is negative and the turnover-reduction
mechanism is empirically falsified on this panel.** No config (absolute or incremental) clears
DSR>0.95. This extends the standing session pattern (frog-in-the-pan, IRRX reversal): momentum
refinements that look plausible in theory keep washing out — or in this case, going slightly
negative — once measured net-of-cost with an honest selection-deflated bar. Do not promote;
keep the engine's plain 12-1/TSMOM momentum treatment exactly as shipped.

## What this round did NOT establish
- **Not** a disproof of Blitz-Huij-Martens' volatility-reduction claim in general — the paper's
  headline is about VOLATILITY/crash risk, and this panel's drawdown numbers are directionally
  consistent with it at 3 of 4 horizons. What's falsified here is the NARROWER hypothesis this
  ablation was designed to test: that the lower vol/turnover translates into a better NET return
  after costs on THIS panel. It does not, and the turnover-reduction premise it would need is
  actively wrong here (turnover is higher, not lower).
- **Not** tested with a wider or non-tech-heavy universe — the 18-name panel is
  mega-cap-tech-heavy (NVDA/AVGO/MU dominate the momentum tercile in a 2021–2026 AI/semis rally),
  a single strong bull regime. Residual momentum's beta-stripping mechanically forfeits some of
  that regime's tailwind; a sideways or bear-market panel could flip the absolute comparison
  (residual momentum is designed to shine exactly there) — this run cannot speak to that.
- **Not** run with the paper's original 36-month regression window / 12-month formation (this
  used the task-assigned 252d regression / 126d formation, a shorter-window variant) — a
  longer-window replica is a residual if anyone wants the closer-to-original-paper test.
- **Not** benchmark/beta-subtracted beyond the incremental spread itself — RESID and BASE both
  still carry some correlated exposure to the panel's tech-heavy composition; the incremental
  series is the market-neutral-ish test asked for, but it is not a clean single-factor-neutral
  return in the strict Fama-French sense.
- **Not** adjusted for the McLean-Pontiff publication-decay haircut before judging — moot here
  since the result is null/negative already; the haircut would only make a positive finding
  look worse, and there is no positive finding to haircut.
- Single-regime, survivorship-clean-by-construction panel (current 18 large-caps, no
  delisted/failed names) — both are CEILINGS on any measured edge, not floors; a real edge
  would need to survive a delisting-inclusive, multi-regime panel too, which this run does not
  test.

## Reproduce
`/tmp/residual_momentum_ablation/residual_momentum.py` (stdlib-only Python; reads the cached
`/tmp/lowbeta_ablation/panel.json`, writes `results.json`). Self-checks: t-distribution
(t=2.228,df=10→p=0.0500) and inverse-normal-CDF (`Φ⁻¹(0.975)≈1.959964`) both pass before any
result is trusted. Expect the NULL conclusion (DSR≪0.95 at every config, incremental point
estimate ≤0) to hold on a rerun against the same cached panel; a fresh Yahoo pull (sliding 5y
window) will shift exact decimals but is not expected to flip the conclusion given how far every
DSR sits below the 0.95 bar and how consistently the incremental sign is negative.
