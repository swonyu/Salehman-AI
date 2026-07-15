# Investment/issuance FF factor legs (asset-growth CMA + net-share-issuance) LONG tilt — net-of-cost REAL-DATA ablation

**Date:** 2026-07-15 · **Disposition: NULL — 0/12 arms pass; run VALID; 2-lens verified. The LONG leg of the
investment/issuance Fama-French factors is now MEASURED null on the 2010-2026 XBRL-era survivorship-free population,
not assumed.** The THIRD fundamentals-side ablation (after GP/A quality NULL and value B/M+E/P NULL); closes the
2026-07-13 completeness-critic's rank-2 gap (the investment factor / CMA / asset growth and net-share-issuance had
ZERO corpus adjudication — grep-verified — never surveyed OR ablated).

**Pre-registration:** [`tools/eodhd_panel/PREREG_2026-07-15_investment_issuance.md`](tools/eodhd_panel/PREREG_2026-07-15_investment_issuance.md),
committed at `03f36ed` BEFORE any statistic; focused Opus design review (`a2796f0610`) → COMMIT-WITH-FIXES, both fixes
applied pre-commit. **Runner:** `tools/eodhd_panel/investment_issuance.py` (Δ-of-consecutive-FYs signal swap on the
twice-verified `value_factor.py`/`gpa_quality.py` machinery). Data ALREADY on disk (Assets from the GP/A pull, shares
from the value pull — no new EDGAR fetch).

## Why distinct from the value/quality nulls (not a re-derivation)
The investment factor (FF5 CMA / Cooper-Gulen-Schill 2008 asset growth) and net-share-issuance (Pontiff-Woodgate 2008
/ Daniel-Titman 2006) load on NEITHER HML nor RMW — a genuinely different fundamental axis. And the LONG direction is
the LOW end (low asset growth = conservative; low issuance = buyback), OPPOSITE to value/quality's top-tercile-long.
Tested LONG-leg only (matching the retail-occupiable constraint) — the prereg's honest prior stated up front that the
tradable alpha of both factors is SHORT-concentrated (overpriced high-growth/high-issuance firms), so the long leg is
thin and a NULL is the modal outcome even if the factor works.

## Result — VALID NULL, 0/12 arms
2 signals (AG, ISS) × 2 scopes (FULL, LOWLIQ) × 3 horizons (63/126/252) on the frozen 34,701-series panel
(`5ce314475941a0cd`); 4,629 clean names; usable AG 3,590 / ISS 2,984 (delisted 1,232 / active 2,560 — genuinely
survivorship-free, ~33% delisted); master window 2010-01-04→2026-07-09 (4,153 bars). SEC EDGAR companyfacts (free).
Net 13/60bps by scope, block significance, DSR-gated, selection-deflated (trials=12, varTrialSharpe 0.052 > the 0.0343
floor so the floor was not binding, bench12 0.381).

| arm | nblk | diff_mean | t | DSR12 | S2a | S2b | S1lag |
|---|---|---|---|---|---|---|---|
| AG/FULL/H63 | 64 | +0.00379 | 1.51 | 0.051 | 0.002 | 0.000 | Y |
| AG/FULL/H126 | 31 | +0.00604 | 1.14 | 0.169 | 0.001 | 0.000 | Y |
| AG/FULL/H252 | 15 | +0.01869 | 0.96 | 0.287 | 0.026 | 0.010 | Y |
| AG/LOWLIQ/H63 | 64 | +0.00753 | 1.59 | 0.037 | 0.001 | 0.000 | Y |
| AG/LOWLIQ/H126 | 31 | +0.01397 | 1.22 | 0.103 | 0.000 | 0.000 | Y |
| AG/LOWLIQ/H252 | 15 | +0.05445 | 1.02 | 0.238 | 0.004 | 0.000 | Y |
| ISS/FULL/H63 | 64 | −0.00090 | −0.28 | 0.000 | 0.016 | 0.016 | N |
| ISS/FULL/H126 | 31 | −0.00406 | −0.49 | 0.002 | 0.336 | 0.336 | Y |
| ISS/FULL/H252 | 15 | −0.01994 | −0.66 | 0.003 | 0.771 | 0.771 | Y |
| ISS/LOWLIQ/H63 | 64 | −0.01117 | −2.30 | 0.000 | 0.000 | 0.000 | Y |
| ISS/LOWLIQ/H126 | 31 | −0.02913 | −1.44 | 0.000 | 0.008 | 0.008 | Y |
| ISS/LOWLIQ/H252 | 15 | −0.08326 | −1.03 | 0.000 | 0.092 | 0.092 | Y |

- **AG (asset-growth low-investment long leg):** diffs POSITIVE (the published CMA-long direction) but tiny (+0.004 to
  +0.055/block), |t| ≤ 1.59, best DSR 0.287 ≪ 0.95. The low-asset-growth cohort mildly outperformed EQW but nowhere
  near significance after multiple-testing deflation. S1′ sign-agreement holds on all 6 AG arms (a genuine, if weak,
  directional signal — not noise around zero, but not tradable).
- **ISS (net-issuance low-issuance long leg):** diffs NEGATIVE (−0.001 to −0.083/block), some block-significant at
  LOWLIQ (H63 t=−2.30) — low-issuance small/illiquid names UNDERperformed in the 2010s. Symmetric-negative
  pre-commitment correctly did NOT fire (negDSR ≤ 0.246) — no tradable long premium AND no shortable anti-premium
  survives deflation.
- Both cohort AND EQW GROSS books positive (cohG_t / eqwG_t ≈ 2.2–3.7) — shared bull BETA; the paired diff isolates
  the tilt and finds nothing tradable.

## The SMOKE→full collapse (why full-universe + DSR is the honest test)
A 600-name SMOKE test showed AG/FULL/H63 at t=2.24 / DSR 0.696 — the most-alive fundamental signal the campaign had
produced, and it survived the FIX-1 interval guard (t 2.33→2.24). On the FULL ~3,590-name universe it **COLLAPSED to
t=1.51 / DSR 0.051.** The mechanism, confirmed by the code audit: on 600 names the low-asset-growth cohort caught a
handful of idiosyncratic winners that inflated the mean; on the full universe that luck averaged out (diff dropped
~5×), AND the DSR benchmark ROSE (varTrialSharpe 0.023→0.052 — the 12 arms' Sharpes are more dispersed on full data →
higher expected-max-of-12), so even the surviving positive tilt deflates to nothing. This is exactly what
pre-registration + DSR exist to catch: a naive read of the SMOKE t=2.24 would have claimed "asset growth works"; the
full-universe, trials-deflated, DSR-gated discipline correctly says NULL.

## Run VALIDITY + the price-exogenous placebo
Both placebos max DSR < 0.35 (signal-shuffle 0.348; returns-shuffle 0.307) → run VALID, no leak. Unlike the value run
(whose price-in-denominator ratio required the placebo-correction saga), the invest signal is PRICE-EXOGENOUS
(Assets/shares only), so the price-leak the value placebo exposed structurally cannot arise — the dedicated
`_invest_run_leg` reads the precomputed signal scalar directly (no `num/(px·sh)` division), verified by a
price-invariance selfcheck.

## Two defects caught PRE-decision-statistic (design review + the prereg discipline)
1. **FIX 1 — pair-interval guard:** the initial builders paired any consecutive FY-ends; a skipped year (2013→2016 =
   a 2-year growth) or a fiscal-year-change stub (Dec→Jun = 6 months) would mislabel a multi/partial-period change as
   annual, scattering names to the tercile extremes on a wrong basis → dilute toward null. Fixed: a Δ is annual ONLY
   if `end_t − end_{t-1} ∈ [340,380] days`; selfcheck asserts a 2-year-gap and a 6-month-stub pair produce NO event.
   The AG signal barely changed under the guard (t 2.33→2.24 on SMOKE) — so it was NOT a pairing artifact, which is
   itself informative (the low-AG tilt is real, just not tradable).
2. **The split-neutrality trap (solved by construction + selfcheck-locked):** raw EDGAR shares are un-split-adjusted,
   so a 7:1 split would fake a +600% "issuance." `sharesAdj(FY) = rawShares × split_factor_after(FY-end)` puts both
   years on today's basis so the ratio cancels the split; the selfcheck verifies a 7:1 split with constant real shares
   reads ISS=0 (not +600%). Without this, every splitting company would be jammed into the high-issuance short leg and
   OUT of the low-issuance cohort — a null-manufacturing bias.

## 2-lens verification
- **Lens 1 (independent re-implementation):** an AAPL AG + ISS reproduction written from scratch (imports nothing from
  the runner's event builders for the arithmetic): AG 2024→2025 Assets $365.0B→$359.2B = **−1.57%** (asset shrinkage =
  conservative), runner stored **+0.0157** (= −AG, correct negation for bottom-tercile-long) — bit-exact; interval
  364 days (annual, passes FIX 1). ISS 2024→2025 sharesAdj 15.116B→14.776B = **−2.25%** (buyback = negative issuance),
  runner stored +0.0225. Both match the runner exactly.
- **Lens 2 (code audit vs prereg, Opus red-team):** CONFIRMED — REAL, TRUSTWORTHY NULL. Independently recomputed the
  decision rule on all 12 arms (disagreed with the runner on NONE); reproduced AAPL AG from raw facts bit-exact
  (FY2024 Assets 364,980M → FY2025 359,241M → −1.572% stored +0.01572); all 5 audit items pass. Δ-signal + negation
  direction correct (a sign error would have inverted to the aggressive-grower cohort — it did not); FIX-1 guard
  boundary-tested (365d ok, 730d/181d dropped, only 4 single-FY names stranded); price-exogenous path grep-proven
  leak-free (the only `sig[code]` assignment is the precomputed scalar — no `px`/`mcap`/`num/(px·sh)` anywhere);
  DSR gate bit-exact (best arm 0.287 decisive, nearest-to-pass min-conjunct DSR 0.010). **The SMOKE→full collapse
  is LEGITIMATE averaging-out, NOT a suppression bug:** the full AG cohort still selects low-asset-growth names, its
  gross book is pure beta (cohort gross-t ≈ EQW gross-t), and the paired-diff Sharpe (0.19) fell BELOW the
  multiple-testing bench (0.38) → "a lucky arm in a noisy 600-name sample regressing toward its true ~0 mean at full
  breadth." Two minor non-blocking notes: `census_single_fy=4` under-counts (narrow definition, result-irrelevant);
  prereg committed 03f36ed before any statistic (ordering confirmed).

## What this did NOT establish
- **Not a refutation of the academic investment/issuance factors.** LONG-leg only — the tradable alpha of both is
  SHORT-concentrated (overpriced aggressive-investment / high-issuance firms), and the long leg is thin by
  construction; a null is the modal outcome even if the factor works. And 2010-2026 is a specific regime (the
  investment premium is strongest around the dot-com/2000s aggressive-investment episodes largely outside this window).
- **d = cohort − EQW is a LOWER BOUND** on the long-leg premium (EQW contains ~1/3 cohort; conservative, toward null).
- The 2-FY Δ requirement shrinks the eligible universe vs the single-FY GP/A/value runs (only 4 single-FY names
  dropped — the panel is deep enough that the Δ requirement costs almost nothing).

## Disposition
Keep the engine as shipped — do NOT add a low-investment or low-issuance selection tilt. The LONG leg of the
investment/issuance FF factors is closed: MEASURED null, not assumed. The completeness-critic's rank-2 gap is answered.
Ledger family `investment-issuance` (+12 arms). Nothing wired; fences stand; milestone (net-of-cost DSR>0.95) UNMET
and unchanged.
