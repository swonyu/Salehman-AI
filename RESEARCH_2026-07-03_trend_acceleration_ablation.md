# Trend Acceleration (Momentum-of-Momentum) Ablation — 2026-07-03

**Date:** 2026-07-03 · **Author:** Opus session (autonomous ablation) · **Status:** NULL (net incremental edge not demonstrated) — a win; indexed.

## Question
Does accelerating momentum (rising 63-day momentum, i.e. the SECOND derivative of price) predict
continuation beyond what the shipped 126-bar momentum LEVEL term (±0.15) and MACD histogram term
(±0.10, `stocksage-mental-model` §7.1) already capture? Framed as an INCREMENTAL test per the
ranker's flag: MACD histogram is itself a crude acceleration proxy, so the honest bar is "beats
momentum level AND is not a repackaged MACD term."

## Method
Standalone Python script (`ablation-harness`, Path B), stdlib only, no engine-source edits. Panel:
REUSED `/tmp/lowbeta_ablation/panel.json` — 18 US large-caps (NVDA, AVGO, MU, AAPL, MSFT, GOOGL, JPM,
BAC, XOM, CVX, PG, KO, WMT, JNJ, UNH, PFE, HD, CAT) + ^GSPC (ignored), 1254 aligned daily bars,
calendar equality verified. Frozen (inherited from the low-beta ablation, not re-selected).

Signals (from `closes[0..i]` only — no look-ahead):
- `accel_i = MOM_63(i) − MOM_63(i−63)`, `MOM_63(i)=(close[i]−close[i−63])/close[i−63]` (ported from
  `StockSageIndicators.returnOverPeriod`).
- `BASE_LEVEL` = MOM_126 skip-21 (`(close[i−21]−close[i−126])/close[i−126]`, ported).
- `MACD_PROXY` = MACD(12,26,9) histogram, ported verbatim from `StockSageIndicators.macd` (EMA
  seeded with SMA, as the Swift `emaSeries`).
- `EQW_BASE` = equal-weight ALL symbols (passive benchmark).

Entry `open[i+1]`, exit `open[i+1+H]`, net = raw − 13bps (`StockSageNetEdge.defaultCosts` US
large-cap: spread 8 + slippage 5). Top-tercile cohort (6 of 18), equal-weighted. Horizons
21/42/63/126d, non-overlapping blocks (block-level significance, paired t vs 0, vs EQW_BASE, and the
incrementals). Secondary 5-day-step overlapping cross-check at H=21 (sign/magnitude only). DSR/PSR
ported verbatim from `StockSageDeflatedSharpe.swift`; `passes := dsr>0.95`; trials=12 (3 arms × 4
horizons), varTrialSharpe=0.0280.

## Results

| H | n_blocks | MOM_LEVEL mean/DSR | MACD_PROXY mean/DSR | ACCEL mean/DSR |
|---|---|---|---|---|
| 21d | 53 | +2.134% / 0.611 | +1.654% / 0.588 | +1.287% / 0.397 |
| 42d | 26 | +4.586% / 0.808 | +3.409% / 0.730 | +2.223% / 0.525 |
| 63d | 17 | +6.808% / 0.883 | +1.013% / 0.273 | +2.996% / 0.483 |
| 126d | 8  | +11.929% / 0.715 | +0.691% / 0.282 | +13.309% / 0.802 |

No arm clears DSR>0.95 at any horizon. EQW_BASE (no selection) mean/block: 21d=1.474%, 42d=3.123%,
63d=4.514%, 126d=9.721%.

Incrementals (block-paired t):
- ACCEL−MOM_LEVEL: 21d −0.847%(t=−1.02), 42d −2.363%(t=−1.18), 63d −3.812%(t=−1.64), 126d
  +1.380%(t=0.23, n=8).
- ACCEL−MACD_PROXY: 21d −0.367%(t=−0.52), 42d −1.185%(t=−0.79), 63d +1.983%(t=0.95), 126d
  +12.617%(t=2.77, n=8 — noise-prone thin row, not a finding).

Secondary overlapping cross-check (5-day step, H=21, n=222): ACCEL−MOM_LEVEL=−1.00%,
ACCEL−MACD_PROXY=+0.05% — same sign/magnitude as primary.

**Accel vs MACD-histogram-proxy correlation: pooled Pearson r = 0.089** (n=954, descriptive) —
near-zero, the two signals are statistically distinct, NOT a repackaging.

## Verdict
NULL. Acceleration underperforms plain momentum LEVEL at every horizon except the thin H=126 row (8
blocks — underpowered), and is statistically indistinguishable from the MACD proxy everywhere except
that same thin row. No config clears DSR>0.95. Acceleration is empirically DISTINCT from MACD
(r≈0.09) but adds no net-of-cost incremental value over either the momentum-level term or the MACD
term already scored. Do NOT add an acceleration term.

## What this round did NOT establish
- Whether acceleration works on a broader/different panel (small/mid-cap, international, longer
  history) — this 18-name tech/semis-tilted panel is low-power and non-representative for a general
  claim.
- Whether a different lookback pairing (21/21, 252/252) behaves differently — only 63/63 tested.
- Whether acceleration adds value as a TIE-BREAK/CONFIRMATION filter (the way MACD is used, ±0.10)
  rather than a standalone top-tercile selector — a different, untested construction.
- A per-trade-level DSR (this used block-level cohort returns, n=8–53).
- McLean-Pontiff haircut — moot, nothing cleared DSR.

## Reproduce
`/tmp/trend_accel_ablation/run_ablation.py` (stdlib, `python3 run_ablation.py`; reads
`/tmp/lowbeta_ablation/panel.json`). Formulas hand-verified against `StockSageIndicators.swift`
(returnOverPeriod, emaSeries, macd, timeSeriesMomentum) + `StockSageDeflatedSharpe.swift`.
