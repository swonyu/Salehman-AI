# Research: Downside-beta / semi-beta asymmetry long-selection ablation — net-of-cost REAL-DATA

**Date:** 2026-07-03 · **Author:** Opus session (autonomous ablation) · **Status:** NULL (net edge not demonstrated) — a win; indexed.

## Question
Ang, Chen & Xing (2006, "Downside Risk", RFS) find investors demand a premium for stocks whose
returns covary with the market specifically in DOWN markets — downside beta
β⁻ = cov(r_i, r_mkt | r_mkt<threshold)/var(r_mkt | r_mkt<threshold). The PRICING signal is the
ASYMMETRY relative to upside beta β⁺ (or β⁻ vs plain symmetric beta), not symmetric beta itself —
the 2026-07-03 low-beta/BAB ablation already tested symmetric beta and found it NULL (and, on this
bull-market panel, significantly net-negative vs unconditional long). HONESTY QUESTION: is a
downside-risk-aware long selection (avoid high-β⁻ names, or prefer favorable β⁻−β⁺ asymmetry) a
DISTINCT net-of-cost edge over unconditional long AND over the already-failed symmetric low-beta
tilt — or does it collapse to the same null?

## Method
- **Harness fidelity:** `StockSageDeflatedSharpe.swift` COMPILED FROM THE REAL SOURCE (copied
  verbatim into the standalone runner, zero port risk on the DSR/PSR math) — same recipe as the
  sibling low-beta and frog-in-the-pan ablations. `defaultCosts` for US large-cap ported exactly:
  spread 8bp + slippage 5bp = 13bp round-trip.
- **Panel (REUSED, no new fetch):** copied verbatim from `/tmp/lowbeta_ablation/panel.json` — 18 US
  large-caps {NVDA,AVGO,MU,AAPL,MSFT,GOOGL,JPM,BAC,XOM,CVX,PG,KO,WMT,JNJ,UNH,PFE,HD,CAT} + ^GSPC
  market proxy, 5y daily via the Yahoo v8 chart endpoint (`StockSageQuoteService`'s source), one
  shared calendar verified (1254 bars). Frozen by the sibling session before any result was seen;
  this session added no symbols and performed no new fetch.
- **Signals (candidate spec, exact):**
  - Trailing 252-day daily returns as-of index i.
  - `beta_full` (symmetric OLS beta, full 252d sample) — recomputed here identically to the sibling
    low-beta script and cross-checked bit-for-bit (H=21 LOW mean 21.8bp here vs 21.77bp there;
    H=42: 78.2bp both) — confirms the port is faithful, not just similar.
  - `β⁻` = cov(r_i,r_mkt | r_mkt<0)/var(r_mkt | r_mkt<0); `β⁺` analogous on r_mkt≥0. **Disclosed
    simplification:** Ang-Chen-Xing's original threshold conditions on r_mkt < mean(r_mkt), not 0;
    this run uses the simpler/common Bawa-Lindenberg 0-threshold. Over a 252d window the daily
    market mean is close to 0 so the two nearly coincide, but this is a real scope-narrowing, not
    a re-derivation of the paper. Minimum usable subsample floor: 20 days (never binding — observed
    down-day counts ranged 102–144 of 252).
  - `asymmetry` = β⁻ − β⁺ (low/negative = favorable: less downside co-movement than upside
    participation).
- **No look-ahead:** signal from closes[0..i]; enter open[i+1], exit open[i+1+H]; as-of index
  stepped by exactly H (non-overlapping, independent blocks) — identical mechanics to both
  precedent scripts.
- **Four arms per horizon:** BASE = equal-weight long all 18; LOW_DB = bottom-tercile β⁻ (6 of 18);
  LOW_ASYM = bottom-tercile (β⁻−β⁺); LOW_BETA_ref = bottom-tercile symmetric beta (recomputed here
  for a same-script, same-panel, same-block distinctness comparison — not just cited from the
  sibling file).
- **Net-of-cost (mandatory):** net = gross forward return − 13bp (one round trip per long
  entry/exit), real `StockSageNetEdge.defaultCosts(forSymbol:)` US large-cap tier.
- **Block-level significance:** one net number per non-overlapping block (equal-weight mean across
  cohort members), then paired t-test across blocks on four difference series: LOW_DB−BASE,
  LOW_DB−LOW_BETA_ref, LOW_ASYM−BASE, LOW_ASYM−LOW_BETA_ref (t-CDF implemented from scratch,
  self-checked t=2.228/df=10→p=0.0500 before trusting any p).
- **Horizon sweep:** 21/42/63/126 trading days, matching the sibling low-beta script for direct
  comparability.
- **DSR:** all 28 scanned configs fed to the compiled `StockSageDeflatedSharpe.deflated(...)`,
  `trials=28`, `varTrialSharpe`=0.174, `expMaxSharpe`=0.853. Pass bar: `dsr > 0.95`.
- **Script:** `/tmp/downside_beta_ablation/downside_beta.py` (stdlib only) +
  `/tmp/downside_beta_ablation/main.swift` (DSR runner). Raw outputs: `table.json`, `series.json`,
  `dsr_output.txt`.

## Results

### Absolute, net-of-cost, per horizon

| H | Arm | mean (bp/blk) | Sharpe | DSR | Pass |
|---|---|---:|---:|---:|---|
| 21 | LOW_DB | 13.3 | 0.040 | 0.000 | no |
| 21 | LOW_ASYM | 179.0 | 0.299 | 0.000 | no |
| 21 | LOW_BETA_ref | 21.8 | 0.066 | 0.000 | no |
| 42 | LOW_DB | 53.8 | 0.128 | 0.001 | no |
| 42 | LOW_ASYM | 407.9 | 0.499 | 0.055 | no |
| 42 | LOW_BETA_ref | 78.2 | 0.161 | 0.001 | no |
| 63 | LOW_DB | 70.4 | 0.135 | 0.004 | no |
| 63 | LOW_ASYM | 643.0 | 0.595 | 0.174 | no |
| 63 | LOW_BETA_ref | 92.9 | 0.156 | 0.004 | no |
| 126 | LOW_DB | 117.9 | 0.212 | 0.065 | no |
| 126 | LOW_ASYM | 1643.3 | 0.868 | 0.517 | no |
| 126 | LOW_BETA_ref | 153.1 | 0.293 | 0.104 | no |

Incremental significance (block-level paired t):

| H | LOW_DB − BASE | LOW_DB − LOW_BETA_ref | LOW_ASYM − BASE | LOW_ASYM − LOW_BETA_ref |
|---|---|---|---|---|
| 21 | −186.7bp, t=−2.93, p=0.005 | −8.4bp, t=−0.44, p=0.659 | −21.1bp, t=−0.36, p=0.717 | +157.2bp, t=+1.61, p=0.114 |
| 42 | −366.6bp, t=−2.98, p=0.007 | −24.5bp, t=−0.62, p=0.543 | −12.5bp, t=−0.11, p=0.915 | +329.6bp, t=+1.45, p=0.160 |
| 63 | −539.8bp, t=−2.48, p=0.026 | −22.4bp, t=−0.37, p=0.720 | +32.8bp, t=+0.16, p=0.873 | +550.2bp, t=+1.61, p=0.129 |
| 126 | −1191.4bp, t=−3.21, p=0.018 | −35.2bp, t=−0.36, p=0.734 | +333.9bp, t=+0.61, p=0.563 | +1490.1bp, t=+1.80, p=0.122 |

**No config clears DSR>0.95 anywhere.** Best absolute: LOW_ASYM H=126, DSR=0.517. Best incremental:
LOW_ASYM−LOW_BETA_ref H=126, DSR=0.303.

### Distinctness
- **LOW_DB vs LOW_BETA_ref:** never significant (p=0.54–0.73) — downside-beta selection is
  statistically indistinguishable from symmetric low-beta selection on this panel, and shares its
  block-significant net-negative alpha vs BASE (p=0.005–0.026 every horizon, a bull-market
  artifact). It re-derives the low-beta null rather than escaping it.
- **LOW_ASYM vs LOW_BETA_ref:** large point-estimate gaps (+157 to +1490bp/block, growing with
  horizon) but never significant (p=0.11–0.16, underpowered at n=7–47 blocks); LOW_ASYM tracks BASE
  (p=0.56–0.92) rather than lagging. Suggestive, not established.

## Overlap with existing engine modules
- **`StockSageReturnShape`** (skewness/downside95): per-symbol univariate read on a NAME's OWN
  return distribution — no market conditioning, no covariance.
- **`StockSageVolRegime`** (sizing multiplier): per-symbol univariate realized-vol percentile brake
  — no market conditioning, no covariance.
- Downside-beta is a cross-sectional, MARKET-CONDITIONED co-movement measure — mechanically
  distinct from both even though thematically adjacent ("downside-risk awareness"). No
  double-counting risk if ever wired; moot here since NULL.

## Did NOT establish
- Did NOT establish a DSR-passing net-of-cost edge for either LOW_DB or LOW_ASYM at any horizon.
- Did NOT establish that downside-beta is a statistically distinct signal from symmetric beta on
  this panel — LOW_DB vs LOW_BETA_ref is never significant.
- Did NOT establish that the LOW_ASYM distinctness is real vs sampling noise — large effect size
  but underpowered (max n=47 blocks, min n=7).
- Did NOT test the regime this literature is about — a genuine bear/drawdown market. The 5y window
  is one sustained bull run; downside-beta's premium is a down-market phenomenon and this sample
  has no sustained down market.
- Did NOT test outside 18 US large-caps + ^GSPC; no sector-neutral control; survivorship not
  addressed (current constituents only = ceiling).
- Did NOT apply McLean-Pontiff haircut (moot — nothing cleared DSR).

## Honest limitations
- Down-day subsample (~118–120 of 252 avg) ≈ half the symmetric-beta sample → inherently noisier.
- Threshold simplification (r_mkt≷0 vs mean-threshold) disclosed above.
- Small-block horizons (H=126, n=7) make several "not significant" results genuinely underpowered
  rather than confidently null — read LOW_ASYM as "inconclusive," not "disproven."
- 28-config trial count for DSR = this study's own scan (documented lower bound, same convention as
  the sibling runs).

## Conclusion / disposition
NULL. Neither cohort promoted. The low-beta null is NOT escaped by conditioning on market-down-days
alone (LOW_DB collapses into it). The favorable-asymmetry construction (β⁻−β⁺) is the more faithful
implementation of the Ang-Chen-Xing signal and shows a qualitatively different (less
bull-market-punished) return profile than plain low-beta, but the sample cannot confirm that
difference is real rather than noise, and it fails DSR regardless. A re-run across a window
containing a genuine drawdown regime is the natural next step if ever revisited, but is NOT required
— this is a valid, indexed NULL.

## Reproduction
```bash
cd /tmp/downside_beta_ablation
python3 downside_beta.py
swiftc -O -o runner main.swift StockSageDeflatedSharpe.swift
./runner
```
Panel: `/tmp/downside_beta_ablation/panel.json` (byte-copy of `/tmp/lowbeta_ablation/panel.json`,
no new fetch).
