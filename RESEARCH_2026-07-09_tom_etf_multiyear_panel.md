# RESEARCH 2026-07-09 — Turn-of-month ETF effect: the MULTI-YEAR POWERED PANEL (the run every 1y cache note named as blocking)

**Verdict: NULL — powered and decisive. Locked config (-1,+3) @ 8bps: +0.222%/mo net, t=1.178, sign-flip p=0.242, bootstrap CI crosses zero; shipped-engine DSR = 0.831 (best config 0.868), ALL fail the 0.95 bar. The effect is +0.44%/mo in 2016–21 and +0.0001%/mo (t=0.000) in 2021–26 — dead in the recent half-decade. TOM beats own buy-and-hold monthly Sharpe in 1/10 symbols. The 1y cache chain's "directional positive" was noise inside a flat 5-year stretch. The TOM research lane's multi-year exit clause is ANSWERED; no promotion case exists.**

## Why this run (and what it closes)
The entire 2026-07-09 1y chain (probe → sweep → max-t → holdout → LOOMO → nonparam → exact
sign-flip → cost-stress → LOSO, all indexed) ended every note with the same disposition:
"candidate remains OPEN pending a multi-year split-adjusted ETF panel with walk-forward
significance + DSR gating." Same-day, the multi-year equity-baseline run (origin 96daf89,
[RESEARCH_2026-07-09_yahoo5y_multiyear.md](RESEARCH_2026-07-09_yahoo5y_multiyear.md)) proved
the Yahoo v8 multi-year path works (paced sequential, minimal `Mozilla/5.0` UA). This run
executes that exact blocking clause at 10× the 1y power.

## Panel (source + as-of)
- **10 liquid US ETFs** (the 1y chain's exact panel): SPY VOO QQQ DIA IWM VTI XLF XLK XLE XLI.
- **Yahoo v8 `range=10y` daily ADJUSTED closes** (total-return consistent; the 1y cache chain
  used raw cache closes — adjclose is the stricter total-return choice), fetched 2026-07-09,
  all 10 HTTP 200, paced ~1 req/2s. Span **2016-07-11 → 2026-07-08, 2,512 bars/symbol**,
  → **n=120 pooled month windows (2016-08..2026-07)** vs the 1y chain's n=12.
- Regimes spanned: 2016-18 bull, 2018Q4 selloff, 2020 COVID crash, 2021 melt-up, 2022
  rate-hike bear, 2023-26 AI bull — the multi-regime depth every 1y note lacked.

## Protocol (pre-registered — locked BEFORE seeing this data)
- **PRIMARY: locked config (-1,+3)** carried unchanged from the 1y train-lock
  ([RESEARCH_2026-07-09_tom_etf_cache_holdout.md](RESEARCH_2026-07-09_tom_etf_cache_holdout.md)):
  enter close of LAST trading day of month M, exit close of 3rd trading day of M+1,
  **net of 8bps round-trip** (1y-chain ETF cost assumption). Pooled = equal-weight/month.
- SECONDARY: the same 4-config sweep {-2,-1}×{+3,+4} under **joint family-wise max-|mean|
  sign-flip control** (flips applied to all configs simultaneously — preserves cross-config
  correlation); cost stress {0,8,16,24}bps; first/second-half split; LOSO.
- **DSR/PSR from the SHIPPED `StockSageDeflatedSharpe` compiled verbatim** by swiftc from
  `Salehman AI/StockSage/StockSageDeflatedSharpe.swift` (zero port risk, the indexed-ablation
  standard); trials=4 (the sweep), varTrialSharpe measured across the 4 configs (0.000260).
- Permutations/bootstrap seeded (20260709); 200k sign-flip draws primary, 100k family-wise,
  10k bootstrap.

## Results (pasted from the run)
**PRIMARY — locked (-1,+3) @ 8bps, n=120:**
```
mean +0.2223%/mo  sd +2.0663%  monthlySharpe 0.108  t=1.178
sign-flip perm p (200k, two-sided) = 0.2423
exact sign test p = 0.0824  (pos months: 70/120)
bootstrap 95% CI mean/mo: [-0.1412%, +0.5860%]
```
**Comparator:** pooled EQW buy-and-hold monthly mean +1.3224%/mo, Sharpe 0.275 — B&H Sharpe
is 2.5× the TOM strategy's. Per-symbol: TOM net Sharpe beats own B&H monthly Sharpe in
**1/10 symbols** (XLE 0.138 vs 0.131; every index/sector ETF fails by a wide margin).

**SECONDARY — 4-config sweep @ 8bps (family-wise p = 0.2619):**
```
(-2,+3): +0.1747%/mo t=0.951   (-2,+4): +0.2462%/mo t=1.215
(-1,+3): +0.2223%/mo t=1.178   (-1,+4): +0.2961%/mo t=1.380
```
**Shipped-engine DSR (trials=4, varTrialSharpe=0.000260):**
```
cfg_-2_3: sharpe=0.0868 skew=-0.717 kurt=4.644 PSR=0.8202 DSR=0.7694 passes=false
cfg_-2_4: sharpe=0.1109 skew=-1.017 kurt=6.353 PSR=0.8726 DSR=0.8326 passes=false
cfg_-1_3: sharpe=0.1076 skew=-0.476 kurt=5.231 PSR=0.8724 DSR=0.8311 passes=false
cfg_-1_4: sharpe=0.1260 skew=-0.890 kurt=6.797 PSR=0.9014 DSR=0.8678 passes=false
```
Note the moments: NEGATIVE skew (−0.48..−1.02) + fat tails (kurt 4.6–6.8) — the TOM window
carries left-tail crash exposure, and the PSR/DSR machinery correctly haircuts for it.

**Cost stress (locked):** 0bps t=1.602 p=0.113 → 8bps t=1.178 → 16bps t=0.754 → 24bps
t=0.330 p=0.745. Not significant even at ZERO cost.

**Split halves (locked @ 8bps) — the decisive decomposition:**
```
H1 2016-08..2021-07: mean +0.4444%/mo  Sharpe 0.215  t=1.663  n=60
H2 2021-08..2026-07: mean +0.0001%/mo  Sharpe 0.000  t=0.000  n=60
```
The entire decade point-estimate lives in the FIRST half; the effect is **identically zero in
the most recent 5 years** — the exact window the 1y cache chain sampled (its +0.31%/mo was
month-luck: 12 draws from a zero-mean stretch). This is the "recent-decade persistence is a
documented absence" caveat from [RESEARCH_2026-07-03_candidate_edges.md](RESEARCH_2026-07-03_candidate_edges.md),
now MEASURED on our own panel instead of cited.

**LOSO (locked):** mean range +0.1941% (drop XLE) .. +0.2327% (drop IWM), t 1.03–1.26 — no
single-symbol dependence; the null is broad.

## Disposition
1. **The TOM research lane's multi-year exit clause is DONE — verdict NULL/non-promotional.**
   No walk-forward configuration clears significance (raw, trial-accounted, or exact), no
   config clears DSR>0.95 on the shipped engine, the strategy's Sharpe efficiency claim fails
   9/10 symbols, and the effect is zero in the live-relevant recent regime. The 1y chain's
   INTERIM/underpowered verdict upgrades to **POWERED NULL**.
2. **The owner-activated `turnOfMonthEnabled` tilt (2026-07-09 "WIRE ACTIVATE") is untouched**
   — activation was an owner call, explicitly not an evidence promotion, and deactivation is
   equally owner-gated. This run REMOVES the "pending more data" ambiguity: the evidence now
   AFFIRMATIVELY shows no net TOM edge on this panel at this power. **OWNER DECISION now
   sharper: keep the tilt as a deliberate preference (it stays capped ±0.03,
   reliability-gated, disclosed in the UI) or order deactivation.** Note the wired tilt is
   per-symbol same-calendar-month seasonality (Heston-Sadka family — itself NULL'd underpowered
   2026-07-03) rather than the pooled index-ETF TOM window tested here; both family members
   are now null-to-underpowered on every measurement we have.
3. Nothing else wired/changed by this research (docs-only).

## Honesty caveats
Survivorship-free by construction (broad index/sector ETFs, all alive all decade). Single
vendor (Yahoo adjclose; window slides daily — exact decimals drift, the NULL verdict is the
stable claim). 8bps RT is the 1y-chain assumption (current-era research says index-ETF ~0.5bps
— but the ZERO-cost row is also non-significant, so the cost assumption is not load-bearing).
The pooled test is month-level (no overlapping windows); trials=4 understates the full
campaign's search breadth (probe/sweep/max-t/holdout across the 1y chain) — a HIGHER honest
trial count only pushes DSR further below the bar, so the null is conservative. Scripts:
session-scratchpad one-shots (fetch/analysis/DSR runner); this doc carries the full protocol
+ pasted outputs for reproduction.

## UPDATE 2026-07-09 (owner ruling, same day)
With this powered NULL in hand, the owner ruled **KEEP (option "a")** for the already-activated
`turnOfMonthEnabled` tilt — a deliberate, disclosed preference, explicitly **not an evidence
promotion**. The flag stays `true`; harm is bounded by construction (capped ±0.03, reliability-
weighted, |t|<1-gated, direction-aware, UI-disclosed). Per `research/INDEX.md`'s TOM status-lock
line, **the TOM research lane is now CLOSED** — do not re-open without new data-class evidence
(e.g. a delisting-inclusive multi-decade panel) or new owner words.
