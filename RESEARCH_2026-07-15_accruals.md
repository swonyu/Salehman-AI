# ACCRUALS (Sloan 1996) LONG tilt on the survivorship-free panel — net-of-cost REAL-DATA ablation

**Date:** 2026-07-15 · **Disposition: NULL — 0/6 arms pass; run VALID; 2-lens verified. The LONG leg of the accruals
anomaly is now MEASURED null on the 2010-2026 XBRL-era (post-decay) survivorship-free population — the corpus's
ARGUED accruals-refuse is converted into a MEASUREMENT, completing the canonical fundamental-anomaly axis (value,
quality, investment/issuance, accruals: ALL measured).** The FOURTH fundamentals-side ablation. The 2026-07-09
non-price survey had REFUSED accruals "as a decision, not an oversight" (short-leg-concentrated + long-dead
post-2003); the investment/issuance precedent (also refused-by-analogy, then measured) justified the run.

**Pre-registration:** [`tools/eodhd_panel/PREREG_2026-07-15_accruals.md`](tools/eodhd_panel/PREREG_2026-07-15_accruals.md),
committed at `fd5f3c3` BEFORE any statistic; focused Opus design review → **COMMIT, no defects** (the Sloan formula
verified numerically twice AND against real-panel economics: 11,395 events from 1,111 names center at median −0.033,
exactly the small-negative Sloan predicts — a reversed Δ would center positive). **Runner:**
`tools/eodhd_panel/accruals.py` (the Sloan signal on the twice-verified `investment_issuance.py` machinery).
**Data:** `edgar_pull_accruals.py` — the working-capital tags the GP/A+value pulls didn't save; 3,807 files, 0 errors.

## Signal
Sloan (1996) balance-sheet accruals = **[(ΔCA − ΔCash) − (ΔCL − ΔSTD − ΔTP) − Dep(t)] / avg(Assets_t, Assets_{t-1})**,
Δ over consecutive FYs ([340,380]d interval guard), required roles assets/ca/cash/cl at BOTH FYs + Dep at FY_t
(std/tp optional, default 0 per Sloan). Cohort = **BOTTOM tercile accruals long** (low accruals = high earnings
quality = Sloan's long leg), stored negated for the inherited top-tercile sort. Price-exogenous (balance-sheet only)
→ the dedicated `_invest_run_leg` scalar path; joint availability = max(filed) over ALL ingredient records both FYs.

## Result — VALID NULL, 0/6 arms; the campaign's MOST NUANCED null
2,820 usable names (937 delisted / 1,883 active — survivorship-free; 964 with facts but no usable event = the
multi-role + interval coverage cost); trials=6, varTrialSharpe 0.0076 → **floored 0.0343 (BINDING**, bench 0.114→0.241).

| arm | nblk | diff_mean | t | DSR6 | DSRflr | S2a | S1lag | lag_mean |
|---|---|---|---|---|---|---|---|---|
| FULL/H63 | 64 | +0.00263 | 1.13 | 0.595 | 0.206 | 0.203 | Y | +0.00182 |
| FULL/H126 | 31 | +0.00794 | 1.38 | 0.820 | 0.530 | 0.076 | Y | +0.00062 |
| FULL/H252 | 15 | +0.02646 | 1.26 | **0.921** | 0.730 | 0.050 | **N** | −0.00255 |
| LOWLIQ/H63 | 64 | +0.00426 | 0.99 | 0.537 | 0.161 | 0.046 | Y | +0.00219 |
| LOWLIQ/H126 | 31 | +0.02137 | 1.43 | 0.902 | 0.571 | 0.054 | Y | +0.00036 |
| LOWLIQ/H252 | 15 | +0.06863 | 1.17 | **0.927** | 0.701 | 0.022 | **N** | −0.01032 |

**ALL 6 diffs POSITIVE** (t 0.99–1.43) — directionally consistent with Sloan — and raw DSR reached **0.921/0.927**
on the H252 arms, the campaign's closest-ever approach to the bar. The decision rule refuses on THREE independent
conjuncts, each interrogating a different failure mode:
1. **The variance floor BINDS** (0.0076 → 0.0343): six tightly-correlated arms understate selection risk; floored
   DSR ≤ 0.730 — exactly what the floor exists for.
2. **Winsorization COLLAPSES the diff** (S2a/S2b ≤ 0.203, mostly ≤ 0.076): the premium is TAIL-DRIVEN — a handful of
   extreme names carry it; cap block returns at ±100% and it evaporates. Not a robust cross-sectional premium.
3. **S1′ lag sign-agreement FAILS on both H252 arms**, and the lag decay is dramatic everywhere (FULL/H126 +0.0079 →
   +0.0006 under a 6-month delay; LOWLIQ/H126 +0.0214 → +0.0004): the tilt is QUICKLY-PRICED — whatever echo of the
   accrual premium exists is consumed within months of the filing, unreachable at a lagged rebalance.
Together: a thin, tail-concentrated, fast-decaying echo of the pre-decay accrual premium — real enough to point the
right way, nowhere near a tradable edge at the honest bar.

## Run validity — the near-bar placebo, honestly characterized (Lens-2-corrected)
Signal-shuffle placebo max DSR 0.826; returns-shuffle **0.941** — VALID per the pre-committed ≤0.95 rule. Lens 2
reproduced the 0.941 bit-exact and CORRECTED the initial small-sample guess: it comes from **seed3 LOWLIQ/H63, n=64 —
a WELL-POWERED arm**, and the same arm reads 0.149/0.020/0.941 across the three seeds → a returns-permutation lottery,
not structure. The decisive reframe: **the placebo (pure noise) reaching DSR 0.94 means the real arms' raw 0.92 sits
INSIDE the noise envelope — the near-bar placebo CORROBORATES the null rather than threatening it.** The pre-registered
rule (max over 3 seeds × 6 arms ≤ 0.95) was applied exactly as committed; a 4th seed would be OUTSIDE the prereg and
was correctly not run to adjudicate.

## 2-lens verification
- **Lens 1 (independent re-implementation):** AAPL 2024→2025 Sloan accruals reproduced from raw EDGAR facts with
  hand-written arithmetic (no runner imports): ΔCA −5.0B, ΔCash +6.0B, ΔCL −10.8B, ΔSTD +1.4B, ΔTP −13.6B, Dep 11.7B,
  avgAssets 362B → accruals = **−0.066568** (strongly negative = high earnings quality, sensible for cash-rich AAPL);
  runner stored +0.066568 (correct negation) — **bit-exact match**.
- **Lens 2 (code audit vs prereg, Opus red-team):** CONFIRMED — REAL, TRUSTWORTHY NULL, no defects. All three failing
  conjuncts recomputed BIT-EXACT from recorded moments: `expected_max_sharpe(6, 0.0343) = 0.240789` matches the JSON;
  floored DSR FULL/H252 = 0.7296 and LOWLIQ/H252 = 0.7006 recompute exactly; the S2a collapse is internally consistent
  with the tail-driven construction (every arm carries positive skew 0.84–3.33, kurtosis 5.3–16.4; the symmetric ±100%
  clip can only strip a tail-driven positive, never manufacture one; S2a==S2b exact equality EXPLAINED — zero
  integrity-screened names carry an accruals signal, so the clean and clean+screened panels are identical here);
  both H252 lag-sign fails verified (diff>0, lag<0). The placebo max 0.9410599741 reproduced bit-identical and
  RE-CHARACTERIZED (see Run validity above — the audit corrected the initial n=15 guess to n=64 well-powered, and
  reframed it as corroborating). `diff_mean == coh_gross_mean − eqw_gross_mean` bit-exact for all 6 arms (the
  positive-everywhere pattern is genuine weak cohort outperformance, not an artifact; both books draw from the
  identical per-rebalance eligible universe). Census reconciled exactly (2,820 + 964 = 3,784 = facts total). Ledger:
  exactly 6 arms, family `accruals`, run `fd5f3c3`, all null, bit-exact. The DSR port matches
  `StockSageDeflatedSharpe.swift` line-for-line. Minor verdict-inert note: `REGISTRY_ARMS=807` over-counts vs the
  795-line committed base — the conservative over-deflation direction.

## What this did NOT establish
- **Not a refutation of the (pre-decay) academic accrual anomaly.** 2010-2026 is ENTIRELY post-decay (the premium
  ~vanished after 2003, Green-Hand-Soliman 2011) — the prereg named this the strongest a-priori-null of all four
  fundamental runs, and the measured thin-echo pattern is exactly what post-decay looks like.
- LONG-leg only (the tradable alpha is short-concentrated) — the short leg (high-accruals overpriced firms) was NOT
  tested (retail cannot cheaply short small-caps; the corpus's standing short-leg wall).
- d = cohort − EQW is a LOWER BOUND (EQW contains ~1/3 cohort; conservative, toward null).
- Optional-role (std/tp) one-sided defaults introduce a bounded, disclosed convention per Sloan's method.

## Disposition
Keep the engine as shipped — do NOT add a low-accruals selection tilt. The accruals long leg is closed: MEASURED
null (a directionally-consistent but tail-driven, fast-decaying, floor-failing echo), not an argued refuse. **The
canonical fundamental-anomaly axis is now COMPLETE: value, quality (GP/A), investment/issuance, and accruals — all
measured nulls on the survivorship-free panel.** Ledger family `accruals` (+6 arms). Nothing wired; fences stand;
milestone (net-of-cost DSR>0.95) UNMET and unchanged.
