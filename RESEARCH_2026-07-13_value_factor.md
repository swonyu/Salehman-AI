# VALUE factor (book-to-market / earnings-yield) long tilt on the survivorship-free panel — net-of-cost REAL-DATA ablation

**Date:** 2026-07-13 · **Disposition: NULL — 0/12 arms pass; run VALID; 2-lens verified. The value leg of the
Fama-French factor space is now MEASURED null on the 2010-2026 XBRL-era survivorship-free population, not assumed.**
The FIRST price/fundamentals-ratio ablation in project history; surfaced by the 2026-07-13 completeness-critic as the
single largest genuinely-unclosed hole in the campaign's "edge-search exhausted" claim (value had ZERO corpus
adjudication — it was assumed priced-in as the "incremental-to price/size/value/momentum" baseline, never measured).

**Pre-registration:** [`tools/eodhd_panel/PREREG_2026-07-13_value_factor.md`](tools/eodhd_panel/PREREG_2026-07-13_value_factor.md),
committed at `fee97f2` BEFORE any statistic; 3-lens Opus design review (`wf_00ad60b4-3ab`) → COMMIT-WITH-FIXES, all 6
fixes A–F applied pre-commit. **Runner:** `tools/eodhd_panel/value_factor.py` (signal-swap on the twice-verified
`gpa_quality.py`/`smallcap_maxbabivol.py` machinery). **Data pull:** `tools/eodhd_panel/edgar_pull_value.py`.

## Why value is DISTINCT from the GP/A profitability null (not a re-derivation)
The corpus measured PROFITABILITY (GP/A, Novy-Marx quality) → NULL at DSR 0.326. Value loads OPPOSITE in FF5 (HML vs
RMW; a cheap stock is often a low-profitability one), and — decisively — its denominator is PRICE (market cap), not a
balance-sheet item. That makes value's economically-tradable weight the LONG leg (cheap stocks are retail-occupiable),
dodging the short-leg wall every prior refusal leaned on. Testing it was warranted, not refusable-by-analogy.

## Result — VALID NULL, 0/12 arms
2 signals (B/M, E/P) × 2 scopes (FULL, LOWLIQ) × 3 horizons (63/126/252) on the frozen 34,701-series panel
(`5ce314475941a0cd`), 5,135 clean names, master window 2010-01-04→2026-07-09 (4,153 bars). SEC EDGAR companyfacts
(free, delisted filers persist; 3,807 value-fact extracts). Net 13/60bps by scope, block significance, DSR-gated,
selection-deflated (trials=12, varTrialSharpe floored 0.0343 BINDING).

| arm | nblk | diff_mean | t | DSR12 | S2a | S2b | S1lag |
|---|---|---|---|---|---|---|---|
| BM/FULL/H63 | 64 | +0.00091 | 0.24 | 0.027 | 0.006 | 0.006 | Y |
| BM/FULL/H126 | 31 | −0.00138 | −0.14 | 0.053 | 0.022 | 0.022 | N |
| BM/FULL/H252 | 15 | −0.01488 | −0.75 | 0.044 | 0.039 | 0.039 | Y |
| BM/LOWLIQ/H63 | 64 | +0.00070 | 0.17 | 0.023 | 0.006 | 0.006 | Y |
| BM/LOWLIQ/H126 | 31 | −0.00206 | −0.18 | 0.046 | 0.036 | 0.036 | N |
| BM/LOWLIQ/H252 | 15 | −0.01896 | −0.60 | 0.032 | 0.040 | 0.040 | Y |
| EP/FULL/H63 | 64 | −0.00664 | −1.87 | 0.000 | 0.001 | 0.001 | Y |
| EP/FULL/H126 | 31 | −0.01097 | −1.33 | 0.001 | 0.069 | 0.069 | Y |
| EP/FULL/H252 | 15 | −0.03025 | −1.32 | 0.003 | 0.145 | 0.145 | Y |
| EP/LOWLIQ/H63 | 64 | −0.01582 | −2.86 | 0.000 | 0.000 | 0.000 | Y |
| EP/LOWLIQ/H126 | 31 | −0.02571 | −2.23 | 0.000 | 0.072 | 0.072 | Y |
| EP/LOWLIQ/H252 | 15 | −0.06212 | −1.46 | 0.000 | 0.131 | 0.131 | Y |

- **B/M:** diffs near zero (+0.0009 to −0.019/block), no significance (|t| ≤ 0.75), best DSR 0.053 ≪ 0.95.
- **E/P:** diffs consistently NEGATIVE (−0.007 to −0.062/block), some block-significant (LOWLIQ/H63 t=−2.86,
  LOWLIQ/H126 t=−2.23) — high-earnings-yield ("cheap on earnings") small/illiquid names UNDERperformed in the 2010s
  (the value-trap / drought signature). The symmetric-negative pre-commitment correctly did NOT fire (negDSR ≤ 0.816
  < 0.95) — no tradable long premium AND no shortable anti-premium survives deflation.
- Both cohort AND EQW GROSS books are positive (cohG_t / eqwG_t ≈ 2.2–3.4) — shared 2010–26 bull BETA; the paired
  diff isolates the value tilt and finds nothing. The corpus's "tilt adds nothing over EQW" signature again.

## Run VALIDITY (the placebo veto — and a methodological finding)
Both corrected placebos max DSR < 0.58 (S1″ ratio-shuffle 0.537; S1‴ returns-shuffle 0.579) → **run VALID**, no leak.
**METHODOLOGICAL FINDING (recorded, not hidden):** the FIRST placebo construction shuffled only the (numerator,
shares) scalar and RE-DERIVED the ratio with each name's REAL price in the denominator — so the real 1/price factor
SURVIVED the shuffle, low-price names still clustered in the "random" top tercile, and the placebo cohort−EQW diff was
spuriously positive, maxing DSR 1.000 → the first run was flagged INVALID. This is EXACTLY the price-residual the
design review's Lens-2 predicted a scalar-shuffle could not break. CORRECTED to two true nulls for a price-based
ratio: **S1″ permutes the fully-computed ratio (price included) across names**; **S1‴ keeps real cohorts but permutes
the forward block RETURNS**. Both then landed diff≈0 (max DSR < 0.58). Caught by the placebo FIRING, before any VALID
decision statistic (the invalid run's ledger entries were removed). The base-arm diffs were identical across both runs
(only the validity gate changed) — the code audit confirmed the placebo touches only `run_valid`, a gate that can only
BLOCK a pass, so the correction moved the run from "null-by-invalidity" to "null-by-merit" and could not manufacture
the null.

## Two defects caught PRE-decision-statistic (the prereg discipline working)
1. **FIX-B dei-window bug:** dei cover-page shares are dated to the filing's "as of" date, days-to-weeks AFTER the
   FY-end (AAPL dei end 2013-10-18 vs FY-end 2013-09-28), so exact-end matching missed dei and fell through to the
   corrupt us-gaap MAX (AAPL 2013: the 6,294,494,000 restated comparative, ~7× the true 899,738,000). Caught by the
   MANDATED AAPL-2013 ground-truth reproduction. Fixed: dei matched within [end, end+45d]; same-end us-gaap disagreeing
   >2× dropped as ambiguous (never MAX-picked). Verified AAPL 2013 → 899.738M dei total, not 6.29B.
2. **Placebo price-leak** (above).
Both fixed before any valid statistic; both disclosed in the prereg; neither touches the decision rule, threshold, or
base-arm computation.

## 2-lens verification
- **Lens 1 (independent re-implementation):** an AAPL B/M reproduction written from scratch (imports nothing from the
  runner) from raw EDGAR JSON + raw price bars: equity $123.549B, dei shares 899.738M, split factor 28 (7:1 + 4:1,
  both after FY-end), sharesAdj 25.193B, MarketCap @ 2014-01-02 = adjClose $19.75 × 25.193B = **$497.7B ≡ rawClose
  $553.13 × rawShares 899.7M = $497.7B** (split-consistency identity holds), B/M = **0.2483** (LOW/growth → not cheap
  tercile). The runner's `build_value_events` produced the IDENTICAL 0.2483 — bit-exact match.
- **Lens 2 (code audit vs prereg, Opus red-team):** all 6 conjuncts CONFIRMED bit-exact (FIX A algebra, top-tercile-LONG
  direction, placebo validity, as-of/no-lookahead, freshness/eligibility/blocks, DSR gate); block counts reconcile
  (N=4153 → 65/32/16 max − 1 early-ramp skip = 64/31/15); DSR port responsive (Sharpe-0.5 → DSR 0.957, so a real edge
  would clear); best arm 0.053 decisive not borderline. VERDICT: REAL, TRUSTWORTHY NULL — no defect.

## What this did NOT establish
- **Not a refutation of the academic value premium.** 2010-2026 is value's DOCUMENTED DROUGHT decade (HML ~flat-to-
  negative), and this is the XBRL window the free EDGAR feed covers. A null here is the MODAL outcome even if value
  works in general — it measures value on THIS era/population, per the prereg's honest prior.
- **d = cohort − EQW is a LOWER BOUND** on the value-premium long leg (EQW already contains ~1/3 cohort names;
  conservative, toward null).
- 2010-2026 / US-filers / price-return-basis / single-source (EDGAR) — same scope caveats as the GP/A sibling.

## Disposition
Keep the engine as shipped — do NOT add a value selection tilt. The value leg of the FF factor space is closed:
MEASURED null, not assumed. The completeness-critic's largest gap is answered. Ledger family `value-factor` (+12 arms).
Nothing wired; fences stand; milestone (net-of-cost DSR>0.95) UNMET and unchanged.
