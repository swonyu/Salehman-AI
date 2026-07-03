# Research: Same-calendar-month seasonality ablation (Heston & Sadka 2008, JFE) — net-of-cost REAL-DATA

**Date:** 2026-07-03 · **Author:** Opus session (autonomous ablation) · **Status:** NULL (underpowered on available history; not promoted) — a win; indexed.

## Question
Heston & Sadka (2008, JFE): a stock's return in a calendar month has positive autocorrelation with
its OWN past returns in that same calendar month, persisting for years (institutional/fiscal-flow
patterns, not information). This signal has ZERO overlap with any shipped engine term (pure
calendar-time construct) — the cleanest-distinctness candidate researched. Does a long-top-tercile
tilt on trailing same-calendar-month mean return show a net-of-cost edge over equal-weight?
**Power warning up front:** 15y gives only ~1–14 same-month obs/name; the effect's literature spans
decades and hundreds-to-thousands of names. A null here = "underpowered on available history," not
disproof.

## Method
- **Universe:** REUSED `/tmp/multiregime_panel/panel.json` — 25 US large-caps (AAPL MSFT JPM XOM JNJ
  PG KO WMT CAT HD CVX UNH PFE BAC GOOGL IBM GE CSCO INTC MCD DIS MMM HON T VZ), ^GSPC excluded
  (per-symbol signal). Daily bars 2011-07-05→2026-07-02 (3771), one shared calendar verified. No new
  fetch.
- **Ports (self-checked):** `StockSageNetEdge.defaultCosts` US large-cap = 13bps (spread 8 +
  slippage 5); `StockSageDeflatedSharpe` (PSR/DSR, Acklam inverse-normal, moments, expectedMaxSharpe)
  — self-checked (trials=1 ⇒ DSR==PSR; normalCDF(0)=0.5; inverseNormalCDF(0.5)≈0).
- **Signal:** `seasonalScore_i(sym, month m)` = mean of sym's monthly close-to-close return in
  calendar month m across years strictly PRIOR to the entry year (no look-ahead — only years <
  entryYear). LONG top tercile (8 of 25); BASE = equal-weight all 25.
- **No look-ahead:** entry open[i+1], exit open[i+1+H]; non-overlapping blocks stepped by H.
- **Horizons:** 21/42/63d (~1/2/3mo), monthly rebalance. Net 13bps both books.
- **Significance:** block-level paired t of (seasonal_net − EQW_net). DSR selection-deflated across 6
  configs (3 horizons × {absolute, incremental}), varTrialSharpe=0.0261 (realized spread).
- **Power tracking:** recorded same-month prior-year obs count per selected name each block.
- Script: `scratchpad/seasonality_ablation.py` (stdlib).

## Results
| H | n blocks | same-month power (mean/min/max) | SEASONAL abs Sharpe / DSR | INCREMENTAL (seasonal−EQW) t / DSR | PASS |
|---|---|---|---|---|---|
| 21d | 166 | 7.4 / 1 / 14 | 0.212 / 0.510 | t=−0.356 / 0.001 | FAIL |
| 42d | 82  | 7.3 / 1 / 14 | 0.342 / 0.907 | t=+0.392 / 0.067 | FAIL |
| 63d | 54  | 7.3 / 1 / 14 | 0.410 / 0.920 | t=+0.426 / 0.134 | FAIL |

**No config clears DSR>0.95.** The incremental t (the honest test isolating seasonality from beta)
never exceeds |t|=0.43 at any horizon; sign flips (negative 1mo, positive 2-3mo) — noise, not a
sign-stable effect.

**Read-trap flagged:** the ABSOLUTE seasonal-book DSR rises to 0.907–0.920 at 42/63d, superficially
near the bar — but the EQW-all benchmark's own absolute Sharpe (0.450, 0.470) is HIGHER at those
horizons. The tilt is riding 2011-2026 broad-market beta, not beating it. Only the incremental row is
the honest read, and it is flatly null.

## Power verdict
UNDERPOWERED on 15y, as predicted. Per-name trailing same-month sample = 1–14 prior-year obs (mean
7.4). A same-month mean from 1–14 noisy annual points is extremely high-variance; the Heston-Sadka
effect needs decades × a broad cross-section. Read as "no edge at the power this panel provides," NOT
"effect disproven."

## Conclusion
NULL, underpowered — not promoted, not wired. Cleanest-distinctness candidate researched (zero engine
overlap), so a genuine edge would have been notable; the honest verdict is a power-constrained null.
No code change.

## What this round did NOT establish
- Did NOT disprove Heston-Sadka (needs decades × hundreds-to-thousands of names, incl. small/micro
  caps where flow effects concentrate — this 25-mega-cap/15y panel structurally can't see that).
- Did NOT test the broad cross-section the mechanism targets, non-US markets, other asset classes, or
  a longer history.
- Did NOT apply McLean-Pontiff haircut (moot — nothing cleared).
- Did NOT resolve whether a broader/longer panel would find a real effect — documented honest absence.

## Honest limitations
Same-month thinness (1–14 obs, mean 7.4) is the binding constraint; 25 mega-caps ≠ the flow-
constrained segment; survivorship (all 25 survived 2011-2026); single-country/asset-class; correlated
trials make the (already-failing) DSR OPTIMISTIC not conservative (per the ported DSR caveat);
monthly-return convention is one of several (won't flip a null this far from significance).

## Reproduce
`scratchpad/seasonality_ablation.py` (stdlib, reads `/tmp/multiregime_panel/panel.json`). DSR/PSR port
self-checked before use. Expect the underpowered-null to hold.
