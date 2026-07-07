# Cap-vs-continuous allocation ablation — net-of-cost REAL-DATA (OPEN FRONTIER "Weekly top-3 concentration", 2nd exit clause)

**Date:** 2026-07-07 · **Author:** Opus 4.8 orchestrator + 4-agent workflow (Fable plan / Sonnet build+run / Opus+Sonnet verify, all xhigh) · **Run:** wf_b63c1ee6-86c
**Verdict:** **POSITIVE but heavily caveated — does NOT support a hard cap, does NOT overturn the literature null, does NOT clear the bar to change anything. Owner-gated regardless. Reinforces continuous edge-concentration (shipped).**

## Question

`research/INDEX.md` OPEN FRONTIER "Weekly top-3 concentration mechanics" had two exit clauses. The
literature half closed NULL 2026-07-03 (validates the shipped allocator + the hard-top-3-cap FENCE;
Jagannathan-Ma 2003, DeMiguel et al. 2009). The **second, empirical clause** stayed open:

> does a **hard integer count-cap (top-N)** beat the shipped **continuous risk-budget allocator**
> (maxHeat + half-Kelly + correlation-cluster de-weight) on REAL data, net-of-cost, walk-forward, DSR-gated?

This run answers it — data-unblocked because the Yahoo throttle lifted for US names (HTTP 200 + adjclose, re-measured 2026-07-07).

## Method (reduced-scope, production-faithful where it counts)

- **Universe (FROZEN before analysis):** 20 liquid US large-caps, sector-spread — AAPL MSFT GOOGL AMZN NVDA JPM JNJ PG XOM HD KO WMT CAT DIS V MA UNH CVX PEP ADBE. Yahoo v8 `adjclose`, 5y daily, single shared intersected calendar (**1254 bars**), all 20 passed a |daily return|<0.35 split-leak gate (Python + a redundant Swift re-check; no name dropped).
- **Signal proxy (IDENTICAL across arms):** TSMOM 12-1 skip-21 = `adjclose[i-21]/adjclose[i-252]-1`; fundable iff >0 (buy-family). **Equal-risk base w0=0.02/name** — deliberately replaces production's half-Kelly/EV/net-edge/regime/vol sizing stack to isolate the ONE variable under test (the cap).
- **Arms:** CONTINUOUS (all fundable) vs CAP-N (top-N by score), N∈{1,2,3,5}. Each arm then runs, in order: **(a) `StockSageCorrelationCluster.correlationAdjustedWeights` — the SHIPPED function, compiled verbatim** (zero port risk); **(b) heat-scale ported byte-faithful from `StockSageCapitalAllocator.allocate` lines 114-115** (`scale = requested>0.08 ? 0.08/requested : 1`).
- **Accounting:** 200 non-overlapping weekly rebalances (decide close i, earn `adjclose[i+5]/adjclose[i]-1`, next decision i+5; no look-ahead). Net-of-cost: turnover `Σ|Δw|` charged **6.5 bps/unit one-way** (= 13 bps round-trip per the shipped `StockSageNetCostSim` convention — the plan lens caught a 2× double-charge in the first draft).
- **Stats:** per-arm net Sharpe → **`StockSageDeflatedSharpe.deflated`, compiled verbatim** (weekly-unit Sharpe, trials=5, DSR>0.95 bar). Increment `d_t = net(CAP-N)−net(CONTINUOUS)` → 50 non-overlapping 4-week blocks → paired t (Fama-MacBeth). Both a **raw (as-deployed)** and an **exposure-matched (renormalized to 8% heat)** increment computed — the plan lens pre-registered the exposure-match to prevent a mechanically-manufactured result.
- **Verification:** both verify lenses recompiled `main.swift` verbatim (bit-for-bit stdout match) AND ran independent clean-room reimplementations; all load-bearing numbers reproduced. `lookahead_clean / port_faithful / stats_valid / conclusion_supported = true` on both.

## Results (net-of-cost, real data)

Per-arm — every arm individually clears DSR>0.95 (a bull-beta artifact; the benchmark itself is Sharpe-rich):

| Arm | weekly Sharpe | ann Sharpe (display) | DSR |
|---|---|---|---|
| CONTINUOUS | 0.174 | 1.25 | 0.977 |
| CAP-1 | 0.229 | 1.65 | 0.999 |
| CAP-2 | 0.193 | 1.39 | 0.992 |
| CAP-3 | 0.206 | 1.49 | 0.994 |
| CAP-5 | 0.200 | 1.45 | 0.992 |

Increment CAP-N − CONTINUOUS (bps/wk, block-t, block-p, 50 blocks):

| N | RAW (as-deployed) | EXPOSURE-MATCHED |
|---|---|---|
| 1 | +0.04, t=0.04, p=0.965 (null — exposure-diluted) | +8.29, t=3.10, p=0.003 |
| 2 | +0.58, t=0.78, p=0.437 (null) | +3.86, t=2.53, p=0.015 |
| 3 | +1.62, t=2.07, **p=0.044** (raw-sig; FAILS Bonferroni ×4=0.176) | +3.07, t=2.70, p=0.009 |
| 5 | +1.66, t=2.65, **p=0.011** (survives Bonferroni ×4=0.043) | +1.63, t=2.61, p=0.012 |

**Interpretive key (the diagnostic):** gross-return-per-unit-exposure is monotone —
CAP-1 0.0139 > CAP-2 0.0084 > CAP-3 0.0074 > CAP-5 0.0057 > CONTINUOUS 0.0035. The top-TSMOM
names simply earned more per dollar of risk in this tape; concentration harvests the signal's
monotone payoff. This is a statement about the **signal × regime**, not about the allocator.

## Disposition — why this changes nothing (and is NOT oversold)

1. **It does not argue for a hard cap.** CONTINUOUS here is flat-equal-weight; CAP-N concentrates by signal. So the result = *concentration-toward-signal beats flat-equal*. Production's allocator **already concentrates continuously** via half-Kelly (∝ edge). The equal-risk proxy stripped that out, then rediscovered concentration helps — which the shipped continuous allocator already delivers **without** a hard integer cap. Consistent with the fence ("a cap helps only as a continuous regularizer shrinking toward equal-risk").
2. **Single regime.** 2021-2026 is one narrow-leadership mega-cap momentum bull — exactly where concentration wins. Not OOS, not multi-regime; does **not** overturn the indexed Jagannathan-Ma/DeMiguel OOS null.
3. **Survivorship-inflated.** 20 currently-listed names → measured Sharpes are a CEILING; the 2021-26 losers/delistings are absent, biasing the momentum-concentration effect up.
4. **Proxy, not production.** Equal-risk base + TSMOM proxy ≠ the shipped half-Kelly/EV/regime/vol sizing (which often re-pins the top few at the 0.08 cap on its own).
5. **Multiplicity.** Only CAP-5 survives Bonferroni raw; CAP-3 is fragile.

**Bar not cleared.** No allocator change is warranted, and any such change is **owner-gated (RANKING #10 family)** regardless. Nothing wired; no engine file touched.

## What this did NOT establish

- That a hard top-N cap improves the **production** (half-Kelly) allocator — untested; the proxy removed production sizing.
- Anything OOS or multi-regime — single 5y bull only.
- That concentration survives a delisting-inclusive (CRSP-grade) panel — survivor-only here.

## Genuinely-open follow-up (owner-scoped, not decided here)

Does production's half-Kelly concentrate *enough*, or would a **continuous** stronger edge-tilt (NOT a hard cap) help — and does any of it survive a second regime + a delisting-inclusive panel? A half-Kelly-weighted rerun on the same harness is the cheap next step (the runner is reusable at `tools/cap_ablation/`).

## Artifacts

`tools/cap_ablation/{main.swift, fetch_panel.py, panel.json}` (compiles the 3 shipped closure files verbatim; reusable). Run: wf_b63c1ee6-86c, 4 agents, 494k tokens, 0 errors.
