# Research: Momentum-crash-state conditioning — net-of-cost real-data ablation

**Date:** 2026-07-03 · **Author:** Opus session (autonomous ablation) · **Status:** INSUFFICIENT SAMPLE — not promoted, not refuted (mechanism finding stands).

## Question
Daniel & Moskowitz (2016, RFS, "Momentum Crashes"): momentum crashes cluster in a specific market
STATE — after a sustained decline, when volatility then falls, past losers (high up-market beta)
rocket on the rebound and crush a momentum long. Candidate overlay: FLATTEN the momentum tilt to
the equal-weight baseline during the crash-state, hold the tilt otherwise. Does this
state-conditional timing overlay improve NET risk-adjusted returns vs always-on momentum,
INCREMENTAL to the engine's existing continuous vol controls (`StockSageRegime`, per-symbol
`StockSageVolRegime` brake, `varianceScalar` targetVol=0.20 attenuation on the trend family)?

## Method
- **BASE_MOM** = always-on: long top-tercile (6 of 18) by TSMOM signal, equal-weighted, rebalanced
  every non-overlapping block. Signal ported EXACTLY from `StockSageIndicators.timeSeriesMomentum
  (lookback:126, skipRecent:21)`: `(closes[i-21]-closes[i-126])/closes[i-126]`, `closes[0...i]` only.
- **OVERLAY** = same, EXCEPT in CRASH-STATE blocks hold equal-weight-ALL-18 instead of the tilt.
- **CRASH-STATE flag** (as-of bar i, no look-ahead): trailing-504-bar (~24mo) market (^GSPC)
  cumulative return `close[i]/close[i-504]-1 < 0` AND trailing-21-bar (~1mo) realized market vol <
  its own trailing-504-bar (~2y) median vol.
- No look-ahead: signal/state from `closes[0...i]`; enter `open[i+1]`; exit `open[i+1+H]`;
  non-overlapping blocks stepped by exactly H. Warmup 523 bars → ~3y testable.
- Net-of-cost: 13bps round-trip (`StockSageNetEdge.defaultCosts` US large-cap), per position per block.
- Horizons 21/42/63/126d. DSR: `StockSageDeflatedSharpe` ported arithmetic-for-arithmetic
  (`passes`=dsr>0.95), `trials=4`, `varTrialSharpe` from the 4 horizon diff-Sharpes. t-machinery
  self-checked (t=2.228/df=10→p=0.050).
- **Panel: REUSED, no new fetch** — `/tmp/lowbeta_ablation/panel.json` (frozen 18 US large-caps +
  ^GSPC, 5y daily, 1254 bars, one shared calendar). Same frozen panel as low-beta/downside-beta.
- Script: `scratchpad/momentum_crash_ablation.py` (stdlib only).

## Results

| Horizon | Blocks | Crash blocks | OVERLAY−BASE_MOM net/blk | paired-t | p | DSR | Passes? |
|---|---|---|---|---|---|---|---|
| 21d | 34 | 4* | +7.24bp | +1.48 | 0.149 | 0.454 | NO |
| 42d | 17 | 1 | −6.43bp | −1.00 | 0.332 | 0.0001 | NO |
| 63d | 11 | 1 | −137.4bp | −1.00 | 0.341 | 0.0008 | NO |
| 126d | 5 | 0 | n/a (zero variance) | — | — | — | untestable |

**The crash-state condition fired exactly ONCE in the entire 5-year panel** — fall 2023
(2023-09→2024-01). The "4 crash blocks" at 21d are 4 OVERLAPPING samples of that single episode
(stepped by 21d through the same ~4-month window), not 4 independent occurrences — the block count
is not the power it appears. At 42d/63d only one non-overlapping block lands inside the episode; at
126d the step skips it entirely (overlay ≡ BASE_MOM → zero diff variance).

Sign is not stable: +61.5bp/blk (favors overlay) at 21d vs −109/−1511bp/blk (overlay HURT) at
42d/63d. The 63d loss traces to a real mechanism, not noise: at 2023-11-02 the top-momentum sextet
(NVDA/AVGO/GOOGL/CAT/MU/WMT) rode into the AI/semis rally (NVDA +58%, AVGO +44%, MU +22% over the
next 63d) while flatten-to-equal-weight diluted the concentration (13.5% vs the tilt's 28.6%). This
crash-state instance was a momentum CONTINUATION, not a crash — the overlay would have cost real
money. Daniel-Moskowitz's own paper flags this: crash risk within the state is probabilistic, not
certain; this one realized draw came up against the overlay.

## OVERLAP verdict (the question the ranker flagged)
**Mechanically NOT redundant with the engine's continuous vol-scaling — but net benefit unproven.**
Measured `varianceScalar` (= `min(1, 0.20/realizedVol)`, attenuation-only) during the crash-state
window = **1.000 (zero attenuation)** — annualized market vol ≈12–15%, under the 20% target — vs
~0.95–0.98 in non-crash blocks. I.e. the continuous vol scalar is *closer to a no-op precisely
during the crash-state* than outside it, exactly as Daniel-Moskowitz predicts (crash risk
concentrates when vol has FALLEN after a decline — the regime a vol-LEVEL scalar ignores). So the
crash-state overlay targets a genuinely different axis (trend direction × vol trajectory) than
`varianceScalar`, `StockSageVolRegime` (vol-level brake), or `StockSageRegime` (fires on ELEVATED
vol — the opposite condition). **The overlap concern is answered: the vol controls do NOT already
capture this state.** But that only shows the overlay addresses an unaddressed axis — it does NOT
establish positive expected value; the single real instance shows it could subtract (42d/63d) as
easily as add (21d).

## What this round did NOT establish
- Did NOT establish that the overlay improves OR harms net momentum returns — exactly one
  crash-state episode; every horizon's crash-block count is 0, 1, or overlapping samples of the
  same episode. A POWER problem, not a measured null.
- Did NOT establish generalization beyond a 2023-AI-rally-flavored instance; the genuine crash-risk
  case (a dead-cat bounce into a second leg down) is untested — this panel didn't contain one.
- Did NOT establish cross-regime robustness — US large-cap only, one 5y window, no pre-2021 history
  (misses 2008, 2020, the 2000–2003 unwind — the canonical Daniel-Moskowitz crash episodes).
- Did NOT clear DSR anywhere (best 0.454 ≪ 0.95); the `trials=4` DSR inputs are themselves fragile
  — disclosed, not smoothed.
- Survivorship: current large-cap survivors only. McLean-Pontiff: moot (nothing cleared to haircut).
- **Load-bearing caveat:** a bull-heavy 5y sample is near the worst possible window to test a
  crash-timing overlay — expected, not a method flaw; a fair test needs a panel spanning ≥1 full
  bear-to-vol-calming cycle (2008/2020, or a window shifted to include 2022).

## Verdict
**INSUFFICIENT CRASH-STATE SAMPLE — refuse to promote, refuse to declare a null.** The mechanism
check (OVERLAP verdict) is genuinely informative and stands regardless of sample size: the overlay
is not redundant with the engine's vol-level controls, and it flags a real UNADDRESSED risk axis
(vol-trajectory after a decline). But the efficacy question needs a panel with multiple independent
crash-state episodes. Do not add this overlay without (a) a longer/multi-regime data source
(pre-2021, ideally 2008/2020) re-run through this exact script, or (b) explicit owner sign-off
accepting the Daniel-Moskowitz literature case without in-house empirical confirmation. RESIDUAL /
OPEN: this is the one candidate of the session's new-edge sweep whose mechanism is non-redundant and
plausibly real but UNTESTABLE on 5y bull data — the natural next step if a multi-regime panel
becomes available.

## Reproduction
```bash
python3 scratchpad/momentum_crash_ablation.py   # reads /tmp/lowbeta_ablation/panel.json; writes momentum_crash_results.json
```
Ported source: `StockSageDeflatedSharpe.swift`, `StockSageNetEdge.swift`, `StockSageIndicators.swift`
(`timeSeriesMomentum`), `StockSageAdvisor.swift` (`varianceScalar`).

## UPDATE 2026-07-03 — multi-regime 15y re-run (the documented next step)
Re-ran the identical overlay/state definitions on a longer, multi-regime panel to resolve the
"insufficient sample" verdict. **Result: upgraded from insufficient-sample to REFUSE / lean-refute
— now measured net-NEGATIVE where the state fires, sign-stable across 2 independent episodes.**

- **Panel:** 25 liquid US large-caps + ^GSPC, 3771 daily bars, 2011-07-05→2026-07-02, one shared
  calendar, zero names dropped; fetched gently (concurrency 1, ~2s), no 429. Names: AAPL MSFT JPM
  XOM JNJ PG KO WMT CAT HD CVX UNH PFE BAC GOOGL IBM GE CSCO INTC MCD DIS MMM HON T VZ. Warmup 524
  bars → testable from 2013-08. Panel at `/tmp/multiregime_panel/panel.json`.
- **Crash-state fired only TWICE, BOTH in 2023** (spring 2023-03-10→05-31; fall 2023-08-15→2024-01-08).
  2020/2022/2018Q4/2025 all FAILED to fire — diagnostic: the state's "trailing-2y-negative AND
  calm-vol" condition structurally excludes fast/high-vol crashes (2020-03-23 vol 83.6%ann ≫ median
  → cond2 fails) and melt-up-preceded declines (2022 trailing-2y still +21% from the 2020-21
  melt-up → cond1 fails). **The binding constraint is the DEFINITION, not data length.**
- **Verdict per horizon (OVERLAY−BASE_MOM, net 13bps, non-overlapping blocks):** 21d −2.22bp/blk
  (DSR 0.0007), 42d −5.54 (~0), 63d −12.41 (~0), 126d 0 (no crash-block, overlay≡base). No horizon
  clears DSR; all fail net-NEGATIVE.
- **Sign STABLE and NEGATIVE across both episodes** (in-state diff: spring/fall −234/−27bp @21d,
  −213 @42d, −241/−391 @63d). Both 2023 episodes were momentum CONTINUATIONS (AI/semis rally) —
  flattening to equal-weight diluted the winning tilt, replicating the 5y fall-2023 result and
  adding a second independent confirmation.
- **OVERLAP mechanism REPLICATED:** avg `varianceScalar`=1.000 in-crash vs 0.959–0.971 non-crash;
  in-state annualized market vol 11.6–14.5% (< 20% target). The vol-level scaling is a no-op
  precisely in the crash-state — the overlay still targets a genuinely unaddressed axis
  (vol-trajectory). Non-redundant, but net-negative where it fires.
- **Caveats:** survivorship WORSE at 15y (today's survivors only — GE/INTC/PFE/T/VZ/IBM survived,
  every delisted 2011-era name excluded, biasing the momentum baseline up); only 2 episodes, same
  2023 macro regime (so "sign stable" = stable *within 2023*, not across bear cycles); 2011/2008 are
  inside/before the warmup; DSR trials=4 fragile.
- **Disposition:** do NOT add the overlay. A genuine efficacy test still needs a panel containing a
  *fired* slow-bleed-into-second-leg crash (2000-03, 2008) — pre-2011 data, owner-scoped. The
  non-redundancy mechanism is the durable finding; the efficacy sign, where testable, is negative.
  Repro: `python3 scratchpad/mrp_ablation.py` (reads `/tmp/multiregime_panel/panel.json`).
