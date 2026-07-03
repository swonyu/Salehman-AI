# MAX / Lottery-Demand Ablation — 2026-07-03

**Date:** 2026-07-03 · **Author:** Opus session (autonomous ablation) · **Status:** NULL (net edge not demonstrated; empirically re-derives the low-vol/IVOL null) — a win; indexed.

## Question
Does a LONG tilt toward the bottom-tercile-MAX cohort (avoiding high-MAX "lottery" names, Bali,
Cakici & Whitelaw 2011, JFE) earn a net-of-cost edge over unconditional long — and, since the
ranker flagged MAX as a behavioral cousin of the already-run low-beta/low-IVOL ablation (2026-07-03,
same panel), does MAX behave *differently* from IVOL or does it just re-derive the same low-vol null?

## Method
Standalone script, no engine-source edits, nothing committed. Reused the cached 5y daily panel
`/tmp/lowbeta_ablation/panel.json` (18 US large-caps + `^GSPC`, 1254 bars, 2021-07→2026-07) — no new
fetch. Ported verbatim from `Salehman AI/StockSage/`: `StockSageNetEdge.defaultCosts` (US large-cap =
13bps round-trip, spread 8 + slippage 5) and `StockSageDeflatedSharpe` (`Result.passes` = `dsr>0.95`,
compiled from the real Swift source, zero port risk).

- `MAX_i` = mean of the top-5 daily returns of stock `i` over the trailing 21 trading days.
- `IVOL_i` = residual vol vs `^GSPC` over trailing 252d (identical formula to the sibling
  low-beta/IVOL ablation's `beta.py`, cross-checked: `ivol_21_LOW` Sharpe +0.204 in both runs — port
  verified).
- Cohorts: LOW_MAX / HIGH_MAX = bottom/top tercile (6 of 18) by MAX score; LOW_IVOL = bottom tercile
  by IVOL; BASE = equal-weight all 18.
- No look-ahead: signal from closes ≤ i; enter `open[i+1]`; exit `open[i+1+H]`; as-of stepped by
  exactly H (non-overlapping, independent blocks). Horizons 21/42/63/126d. Net 13bps per long
  round-trip.
- Significance: block-level paired t-test (one number per non-overlapping block), t-dist self-checked
  (t=2.228/df=10→p=0.050). DSR: trials=16 (this study's 4 horizons × 4 arms), `varTrialSharpe` =
  variance of the 16 trial Sharpes, `expectedMaxSharpe`=0.890 from the real compiled routine.
- Distinctness: LOW_MAX and LOW_IVOL cohorts on the SAME rebalance dates/panel; tested
  LOW_MAX−LOW_IVOL series with identical block-t machinery + per-block cohort-membership overlap.
- Script: `/tmp/max_ablation/max_ablation.py` (stdlib) + `/tmp/max_ablation/main.swift` (compiled
  against a copy of the real `StockSageDeflatedSharpe.swift`).

## Verdicts

### Absolute and incremental (net-of-cost, per horizon)
| H | blocks | LOW_MAX abs mean/blk (Sharpe, DSR) | LOW_MAX−BASE (t, p, DSR) | LOW_MAX−HIGH_MAX (t, p, DSR) |
|---|---|---|---|---|
| 21  | 47 | +67.1bp (+0.204, DSR 0.000)  | −132.9bp/blk, t=−2.80, p=0.007, DSR 0.000 | −335.9bp/blk, t=−3.06, p=0.004, DSR 0.000 |
| 42  | 23 | +13.4bp (+0.041, DSR 0.000)  | −406.9bp/blk, t=−3.56, p=0.002, DSR 0.000 | −876.6bp/blk, t=−3.46, p=0.002, DSR 0.000 |
| 63  | 15 | +201.7bp (+0.396, DSR 0.024) | −408.5bp/blk, t=−2.59, p=0.022, DSR 0.000 | −966.7bp/blk, t=−2.74, p=0.016, DSR 0.000 |
| 126 | 7  | +462.9bp (+1.031, DSR 0.605) | −846.5bp/blk, t=−2.11, p=0.079, DSR 0.000 | −1872.4bp/blk, t=−1.95, p=0.100, DSR 0.000 |

No configuration clears DSR>0.95 at any horizon (best 0.605 @126, n=7). The low-MAX−BASE incremental
is NEGATIVE and block-significant (p<0.05) at 21/42/63d — the low-MAX cohort net-underperformed the
unconditional base, the OPPOSITE sign of the hypothesis. HIGH_MAX outperformed both at every horizon —
a bull-regime/high-beta-wins effect (see Limitations), not evidence for the lottery-demand short leg.

### Distinctness — the load-bearing test
| H | LOW_MAX−LOW_IVOL mean/blk | t | p | DSR | avg membership overlap (of 6) |
|---|---|---|---|---|---|
| 21  | −2.1bp   | −0.06 | 0.956 | 0.000 | 3.62 |
| 42  | −137.9bp | −1.48 | 0.153 | 0.000 | 3.65 |
| 63  | −45.0bp  | −0.30 | 0.772 | 0.000 | 3.60 |
| 126 | −120.2bp | −0.27 | 0.799 | 0.006 | 3.57 |

**MAX behaves statistically indistinguishably from IVOL on this panel — it re-derives the low-vol
null.** No horizon shows a significant LOW_MAX vs LOW_IVOL return difference despite only ~60%
cohort-membership overlap (meaningfully different stock sets, but indistinguishable forward net
returns). The ranker's cousin flag is empirically confirmed. Cross-check: `ivol_21_LOW` Sharpe +0.204
matches the sibling low-beta/IVOL run exactly; every sibling config also fails DSR with the same
negative, block-significant LOW−BASE sign — consistent, reproducible null across both signals.

## Conclusion / disposition
NULL, not promoted. MAX/lottery-demand joins the low-beta/IVOL result as a confirmed non-distinct null
on this panel/window. Do not re-run this exact construction on this panel without new evidence
(a broader/small-cap-inclusive universe, or a different regime).

## What this round did NOT establish
- Whether the TRUE published MAX effect (full-CRSP, small/micro-cap-heavy, retail-options-driven)
  holds — this 18-mega-cap panel structurally EXCLUDES the segment where lottery demand concentrates.
  A conservative/underpowered test of Bali-Cakici-Whitelaw, NOT a literature refutation.
- Performance across a full cycle including a drawdown — 2021-07→2026-07 is one bull run; low-vol/
  low-MAX cohorts mechanically lag a one-way-up tape.
- A cross-study multiple-comparisons count — DSR trials=16 covers only this study's grid; folding in
  the sibling low-beta/IVOL study's 24 trials (~40 joint) would only push every DSR further below 0.95.
- Any funded short-leg (high-MAX avoid) return net of borrow — tested LOW_MAX absolute and the
  LOW_MAX−HIGH_MAX spread, not a funded short.
- Survivorship-bias-free universe — today's large-caps applied retroactively, not point-in-time
  constituents.

## Reproduce
`/tmp/max_ablation/`: `max_ablation.py` (stdlib), `main.swift` + `StockSageDeflatedSharpe.swift` copy,
`panel.json` (reused from `/tmp/lowbeta_ablation/`), `series.json`, `table.json`, `runner`. Expect the
null (no DSR clears 0.95; low-MAX−IVOL insignificant) to hold; decimals drift with Yahoo's sliding
window, the conclusion (MAX ≈ IVOL, no incremental edge) is stable.
