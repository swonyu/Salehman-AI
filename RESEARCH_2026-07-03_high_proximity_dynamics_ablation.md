# Research: 52-week-high TEMPORAL DYNAMICS (streak / delta-proximity) — net-of-cost REAL-DATA ablation, incremental over the shipped static proximity term

**Date:** 2026-07-03 · **Author:** Opus session (autonomous ablation) · **Status:** NULL (incremental edge not demonstrated) — a win; indexed.

## Question
The engine already scores a point-in-time 52-week-high PROXIMITY term (George & Hwang 2004 /
Byun & Jeon 2023 lineage): `StockSageAdvisor.highProximityWeight` 0.10 × (pth − `highProximityNeutralAnchor`
0.90), pth clamped ≤1, long-side-only, zeroed in `bearTrend` (§7.1, `stocksage-mental-model`).
HYPOTHESIS: the TEMPORAL DYNAMICS of nearness-to-high — how long a name has stayed near its high,
and whether that nearness is rising or falling — carry information the static snapshot misses.
Two candidate signals: (a) `daysNearHigh` = fraction of trailing 63 bars with close ≥ 0.95 ×
rolling-252-day max (a "streak" read); (b) `deltaProximity(21)` = pth(t) − pth(t−21) (proximity
MOMENTUM). The HONEST test is INCREMENTAL over the shipped static term, not standalone — a
standalone test would just re-confirm the already-shipped proximity effect.

## Method
- **Harness fidelity:** `StockSageDeflatedSharpe` (Acklam inverse-normal, PSR/expected-max-Sharpe)
  compiled FROM THE REAL SOURCE into a standalone Swift runner — zero port risk on the DSR math.
  `StockSageNetEdge.defaultCosts` US large-cap rate (13bp = 8 spread + 5 slippage) ported exactly
  by value.
- **Panel (REUSED, no new fetch):** the frozen `/tmp/lowbeta_ablation/panel.json` — 18 US
  large-caps {NVDA,AVGO,MU,AAPL,MSFT,GOOGL,JPM,BAC,XOM,CVX,PG,KO,WMT,JNJ,UNH,PFE,HD,CAT} + ^GSPC,
  5y daily Yahoo, 1254 bars, calendars verified identical across all 19 series. ^GSPC ignored (a
  per-symbol signal). Copied verbatim into `/tmp/high_proximity_dynamics_ablation/panel.json`.
- **BASE cohort (the shipped term's proxy):** static `pth(t) = min(close(t) / rolling252max(t), 1.0)`
  — the same clamp-to-1 the shipped code applies — top tercile (top 6 of 18) cross-sectionally at
  each rebalance.
- **Candidate signals (exact, as specified):**
  - `daysNearHigh(i)` = (# of the trailing 63 closes ≥ 0.95 × rolling252max(i)) / 63. Uses a FIXED
    reference (today's rolling-252 max) against each of the 63 trailing closes, not a re-computed
    max at each of those 63 days — both readings use only data ≤ i (no look-ahead either way); the
    fixed-reference version is the simpler, more common "how many of the last N days closed near
    today's high-water mark" reading. Disclosed simplification, not a re-derivation from memory.
  - `deltaProximity(i)` = pth(i) − pth(i−21), the literal proximity-momentum spec.
  - Both ranked top tercile (top 6 of 18) cross-sectionally at each rebalance, same mechanics as BASE.
- **DISCLOSED SIMPLIFICATION shared by BASE and both candidates:** the shipped `highProximity()`
  consumes a real intraday-high series; this panel (like its low-beta/downside-beta siblings) has
  close+open only, so pth uses close/rolling-252-max — the same close-only proxy risk the shipped
  code's own comment warns about. This affects BASE and both dynamic arms identically, so the
  incremental (dynamic − BASE) comparison stays apples-to-apples even though the absolute pth level
  may run hotter than a true-high pth would.
- **No look-ahead:** signal from closes[0..i] only; enter open[i+1], exit open[i+1+H]; as-of index
  stepped by exactly H (non-overlapping, independent blocks).
- **Warmup:** 274 bars (rolling-252 max needs 252, plus the 21-bar delta lookback needs its own
  full 252-bar max window, +1 buffer).
- **Net-of-cost (mandatory):** net = gross forward return − 13bp round-trip (`defaultCosts`,
  US large-cap: spread 8 + slippage 5).
- **Block-level significance:** one net number per non-overlapping block (cross-sectional mean of
  the top-tercile cohort), paired t-test across blocks on (dynamic − BASE) (t-CDF implemented from
  scratch, self-checked t=2.228/df=10→p=0.0500 before trusting any p).
- **DSR gate:** real `StockSageDeflatedSharpe.deflated` on each per-block net series; Sharpe=mean/sd,
  nTrades=block count; selection-deflated trials=20 (4 horizons × 5 arms: BASE, DAYS_NEAR_HIGH,
  DELTA_PROXIMITY, DNH−BASE, DPX−BASE), varTrialSharpe=0.0992 (measured across the 20 configs).
- **Horizon sweep:** 21 / 42 / 63 / 126 trading days.

## Results
Per-block NET means (bp) and DSR (real `StockSageDeflatedSharpe`, trials=20):

| H | nBlk | BASE net / DSR | DAYS_NEAR_HIGH net / DSR | DELTA_PROXIMITY net / DSR | DNH−BASE net / t / p / DSR | DPX−BASE net / t / p / DSR |
|---|---|---|---|---|---|---|
| 21  | 46 | +180.8 / 0.024 | +107.6 / 0.030 | +164.8 / 0.061 | −73.2 / −1.12 / 0.270 / 0.000 | −16.1 / −0.24 / 0.809 / 0.000 |
| 42  | 23 | +346.4 / 0.124 | +288.1 / 0.264 | +371.0 / 0.391 | −58.3 / −0.40 / 0.691 / 0.000 | +24.6 / +0.17 / 0.865 / 0.005 |
| 63  | 15 | +525.8 / 0.458 | +507.9 / 0.699 | +689.2 / 0.591 | −18.0 / −0.10 / 0.920 / 0.009 | +163.4 / +1.05 / 0.310 / 0.088 |
| 126 | 7  | +1335.7 / 0.827 | +1402.3 / **0.990 (passes)** | +1593.6 / 0.655 | +66.6 / +0.28 / 0.792 / 0.106 | +257.9 / +0.54 / 0.607 / 0.166 |

- **No incremental config clears DSR>0.95 at any horizon.** Best incremental DSR = 0.166
  (DPX−BASE, H=126, n=7 blocks). All incremental block-level paired-t p-values are far above 0.05
  (0.270–0.920) — never significant, sign is unstable across horizons (DNH−BASE is negative at
  21/42/63d, flips barely positive at 126d on 7 blocks; DPX−BASE is negative at 21d, positive but
  non-significant at 42/63/126d).
- **The one absolute DSR "pass" is a thin-sample artifact, not a dynamics finding.**
  DAYS_NEAR_HIGH at H=126 shows DSR=0.990 in ABSOLUTE terms, but on only 7 non-overlapping blocks
  (2021–2026 bull market, essentially unpowered) and its own BASE comparator is already at 0.827
  absolute DSR at that horizon — both arms are picking up the same shared bull-trend/momentum beta
  that the shipped static term already captures. The INCREMENTAL DSR for that exact cell
  (DNH−BASE, H=126) is only 0.106, and the paired-t p is 0.792 — not remotely significant. An
  absolute pass with a null incremental result is exactly the "smoothed restatement of the same
  factor" pattern the hypothesis needed to rule out, and it did not survive that test.
- **Direction:** DAYS_NEAR_HIGH (the streak read) net returns are LOWER than BASE at every horizon
  except 126d (46/23/15/7 blocks) — sustained nearness does not obviously add continuation beyond
  what the static term already prices in, and may modestly select more "already extended" names
  that give some of it back. DELTA_PROXIMITY (rising proximity) shows a mildly positive point
  estimate at 42/63/126d but never clears significance or DSR.

## Conclusion
**NULL — the temporal dynamics of 52-week-high proximity (streak or delta) do not clear the
net-of-cost DSR>0.95 gate incrementally over the shipped static proximity term, and neither
incremental series is block-significant at any horizon.** This is the honest answer to the actual
question asked ("do the dynamics beat the static snapshot"), not to the easier standalone question
("is proximity informative at all" — already answered yes by the shipped term). The static
point-in-time proximity term already captures essentially all of the exploitable signal available
in this construction; the temporal-dynamics variants tested here are, at best, statistically
indistinguishable restatements of it, and at worst (daysNearHigh, most horizons) modestly worse.
**Keep the engine exactly as shipped — no promotion, no new signal.**

## What this round did NOT establish
- **Not** a disproof that ANY temporal-dynamics formulation of 52-week-high nearness could ever
  add value — only these two specific, literally-specified constructions (daysNearHigh/63,
  Δproximity(21)) on this panel, this cost model, these four horizons.
- **Not** tested with a true intraday-high series — pth here is close/rolling-252-max (clamped ≤1),
  the same close-only proxy the shipped code's own comment flags as a risk; a highs-aware panel
  could shift absolute levels (though BASE and both candidates share the bias identically, so the
  incremental conclusion is more robust to this than the absolute numbers are).
- **Not** powered at H=126 (n=7 blocks) — the single absolute-DSR "pass" there is exactly the kind
  of thin-sample artifact the pre-registered recipe warns about; do not cite it as a finding.
- **Not** a full replication of George & Hwang (2004) or Byun & Jeon (2023) at academic scale
  (18-name US large-cap panel, single 2021–2026 bull regime, no international/small-cap spread) —
  see caveats below.
- **Not** benchmark-subtracted on the absolute BASE/DNH/DPX arms (they carry bull beta); the
  incremental (dynamic − BASE) arms ARE the market-neutral clean test, and those are the ones that
  fail.

## Honest caveats
- **Panel breadth:** 18 large-cap US names, one sector-diversified but narrow universe — no
  small-cap, no international, no crypto. 52-week-high effects in the literature are documented as
  partly small-cap-concentrated (per the shipped code's own comment on the static term); this panel
  cannot speak to that segment.
- **Survivorship:** all 18 are current large, liquid, currently-listed names over a 5y window that
  ends in a bull market — survivorship and single-regime bias both push toward overstating any
  momentum-adjacent effect (including the BASE arm's own +180 to +1336bp gross-ish absolute
  numbers, which are NOT a claim of achievable live returns).
- **McLean-Pontiff:** even a published, peer-reviewed anomaly should be haircut ~26% OOS and ~58%
  post-publication (McLean & Pontiff, JF 2016) before it's treated as live-achievable; this result
  is a NULL before any such haircut is even needed.
- **Single bull regime:** 2021-07 → 2026-07 is overwhelmingly a bull tape; a bear/range regime
  could show a different incremental pattern (though the shipped static term is itself zeroed in
  bearTrend, so the live-relevant window for either signal is bull/range only, partially mitigating
  this).
- **Block thinness at long H:** H=126 has only 7 independent blocks — any p-value or DSR at that
  horizon is a directional read, not a reliable statistical verdict; it is reported for
  completeness, not cited as evidence either way.
- **Cross-sectional top-tercile construction:** a purely per-symbol (non-cross-sectional) time-
  series version of these signals was not tested; the cross-sectional tercile framing matches the
  sibling low-beta/downside-beta/frog-in-the-pan precedents for methodological consistency but is a
  scope choice, not the only valid design.

## Reproduce
`/tmp/high_proximity_dynamics_ablation/`: `panel.json` (copied verbatim from
`/tmp/lowbeta_ablation/panel.json` — no new fetch), `high_proximity_dynamics.py` (stdlib, signals +
blocks + paired-t) → `series.json`/`table.json`; `main.swift` compiled with the real source:
`swiftc -O main.swift StockSageDeflatedSharpe.swift -o runner && ./runner`. Expect the null
conclusion to hold (no incremental DSR clears 0.95); exact decimals will drift if Yahoo's sliding
5y window is re-fetched — only the CONCLUSION (temporal dynamics ≈ static term, no incremental
edge) is the stable claim.
