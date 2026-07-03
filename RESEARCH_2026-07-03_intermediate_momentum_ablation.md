# Research: Intermediate-horizon ("gap") momentum — incremental ablation vs the engine's recent-momentum term

**Date:** 2026-07-03 · **Author:** Opus session (autonomous ablation) · **Status:** NULL (incremental net edge not demonstrated) — a win; indexed.

## Question
Does Novy-Marx's (2012, JFE, "Is momentum really momentum?") intermediate-horizon momentum window
— the return from t-252 to t-126, i.e. skipping the most recent ~6 months entirely — add
net-of-cost edge INCREMENTAL to the engine's existing 126-bar recent-momentum term
(`stocksage-mental-model` §7.1, weight ±0.15, part of the correlated trend family summed then
re-capped), or is it the same factor re-surfaced at an older lag?

## Method (ablation-harness, standalone script)
- **Panel**: REUSED verbatim from `/tmp/lowbeta_ablation/panel.json` — 18 US large-caps (NVDA, AVGO,
  MU, AAPL, MSFT, GOOGL, JPM, BAC, XOM, CVX, PG, KO, WMT, JNJ, UNH, PFE, HD, CAT) + ^GSPC, 5y daily
  (1254 bars, 2021-07 → 2026-07, Yahoo chart endpoint), frozen universe unchanged from the
  lowbeta/frog precedents (no new fetch — zero endpoint load, full comparability).
- **Signals** (ported shapes):
  - `RECENT` (baseline) = engine's `timeSeriesMomentum` (lookback=126, skipRecent=21):
    `(close[i-21] - close[i-126]) / close[i-126]`.
  - `INTERMEDIATE` (candidate) = Novy-Marx: `(close[i-126] - close[i-252]) / close[i-252]`.
  - `BASE` = equal-weight all 18 (passive baseline).
- **No look-ahead**: signal from `closes[0..i]`; enter `open[i+1]`; exit `open[i+1+H]`. Top-tercile
  (6 of 18) long each signal per non-overlapping block. Horizons 21/42/63/126d.
- **Secondary**: overlapping 5-day-step cross-check at H=21/63 — sign/magnitude only (autocorrelated,
  not used for significance).
- **Net-of-cost**: `StockSageNetEdge.defaultCosts` US large-cap round trip = 13bps, ported verbatim;
  1×13bps per arm per block. Incremental spreads = difference of two already-net series (honest
  2-round-trip cost for a long/short overlay, not double-counted).
- **Significance**: block-level paired t (stdlib Student-t CDF, asserted t=2.228/df=10→p=0.050).
- **DSR**: `StockSageDeflatedSharpe` formulas ported line-for-line; `trials=20` (5 arms × 4 horizons),
  `varTrialSharpe`=0.806. `passes = dsr > 0.95`.
- Script: `/tmp/intermediate_momentum_ablation/run.py` (stdlib only).

## Results

| Horizon | RECENT net Sharpe | INTERMEDIATE net Sharpe | BASE net Sharpe | INTERM−RECENT | INTERM−BASE |
|---|---|---|---|---|---|
| 21d (n=47) | 1.484 | 1.715 | 1.816 | −0.02%/blk, p=0.98, DSR 0.000 | +0.78%/blk, p=0.18, DSR 0.000 |
| 42d (n=23) | 1.660 | 1.254 | 2.202 | −0.98%/blk, p=0.55, DSR 0.000 | +0.93%/blk, p=0.50, DSR 0.000 |
| 63d (n=15) | 1.673 | 0.962 | 1.725 | −3.41%/blk, p=0.16, DSR 0.000 | −0.57%/blk, p=0.77, DSR 0.000 |
| 126d (n=7) | 1.198 | 0.828 | 1.807 | −3.21%/blk, p=0.48, DSR 0.000 | +1.03%/blk, p=0.89, DSR 0.000 |

No arm/horizon clears DSR>0.95. Best absolute DSR is BASE@42d (0.932) — the passive baseline in a
bull-heavy window, not either momentum candidate. Secondary overlapping-weekly cross-check:
`INTERM−RECENT` gross = −0.42% (H=21, n=196), −3.11% (H=63, n=188) — same negative sign as the
primary blocks at both horizons.

## Verdict
**NULL. Intermediate-horizon momentum does not add incremental value over the engine's existing
recent-momentum term, net of cost, at any tested horizon.** The market-neutral `INTERM − RECENT`
spread is negative at every horizon, never distinguishable from zero (all p ≥ 0.16), never clears
DSR. Same momentum factor at an older lag on this panel/window — not a distinct signal — and here
the older lag is if anything slightly worse. Closes the intermediate-momentum candidate — do NOT
add a Novy-Marx gap-momentum leg.

## What this round did NOT establish
- Not tested on a broader/point-in-time (non-survivorship-biased) universe — the 18-name panel is
  a ceiling, not a floor.
- Not tested outside the 2021-07→2026-07 bull-heavy window — a single regime.
- No McLean-Pontiff haircut applied — moot, the incremental spread is negative before any haircut.
- Not tested against the engine's FULL correlated trend family (MACD histogram, vol-adjusted
  momentum) — only the single 126-bar recent-momentum term per the "avoid re-deriving the existing
  term" framing. A test vs the summed/re-capped trend-family score is a narrower follow-up.
- The 126d row (n=7 blocks) is underpowered; its p=0.48 should not be over-read either way.
- No engine/ranking code touched — research-only, never a fixture.

## Reproduce
`/tmp/intermediate_momentum_ablation/run.py` (`python3 run.py`, stdlib only; reads the cached
`/tmp/lowbeta_ablation/panel.json`). Self-checks: Student-t (t=2.228/df=10→p=0.050) asserted before
results. Expect the NULL (negative incremental spread, DSR≪0.95) to hold on rerun.
