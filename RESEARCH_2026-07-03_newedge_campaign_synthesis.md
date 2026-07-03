# New-edge campaign synthesis — 2026-07-03 autonomous single-signal ablation sweep

**Date:** 2026-07-03 · **Author:** Opus session (autonomous) · **Status:** capstone summary of an 11-candidate net-of-cost DSR sweep. Every candidate NULL or REFUSED. No code change. Engine value remains risk-discipline, not alpha — now empirically reinforced across 11 independent signal families.

## What this is
A single autonomous session ran a vetted queue of price-only, un-tried, non-fenced candidate edges through the `ablation-harness` net-of-cost DSR gate (`StockSageDeflatedSharpe.passes` = DSR > 0.95), each recorded as its own indexed detail file. This document ties them together and states the measured campaign conclusion. It is a synthesis, not a new experiment — the individual detail files carry the numbers and method.

## Method integrity (common to every candidate)
- **Real DSR:** every run COMPILED `StockSageDeflatedSharpe` from source (zero port risk on the verdict math); `StockSageNetEdge.defaultCosts` ported exactly (13bps US round-trip).
- **No look-ahead:** signal from bars ≤ i, enter open[i+1], exit open[i+1+H].
- **Block-level significance:** one net number per non-overlapping block, paired t across blocks — never pooled symbol×date points.
- **Net-of-cost + selection-deflated:** costs charged per position per block; DSR deflated across each study's own horizon×arm grid.
- **McLean-Pontiff:** the ~26%/58% OOS/post-publication haircut noted before judging (moot on every candidate — none cleared even pre-haircut).
- **Honesty floor:** every detail file has a "did NOT establish" section; underpowered results are labeled "insufficient/underpowered," never dressed as clean nulls.
- **Data discipline:** the 18-name/5y and 25-name/15y panels were fetched GENTLY (concurrency 1, ~2s) and REUSED across candidates — near-zero load on the shared Yahoo endpoint other sessions need.

## The 11 candidates and their verdicts

| # | Candidate | Citation | Verdict | Key number |
|---|---|---|---|---|
| 1 | Frog-in-the-pan info-discreteness momentum filter | Da-Gurun-Warachka 2014 | NULL | best DSR 0.684 (bull beta); incremental ≤0.094; turnover doesn't bite at 1–6mo |
| 2 | Low-beta / low-IVOL long tilt (BAB) | Frazzini-Pedersen 2014 | NULL (& negative) | incremental LOW−BASE significantly NEGATIVE at 7/8 horizons |
| 3 | Residual (market-neutral) momentum | Blitz-Huij-Martens 2011 | NULL | incremental negative all horizons; turnover hypothesis FALSIFIED (~2× faster) |
| 4 | Downside-beta / semi-beta asymmetry | Ang-Chen-Xing 2006 | NULL | LOW_DB collapses into the symmetric low-beta null; LOW_ASYM underpowered, fails DSR |
| 5 | Intermediate ("gap") momentum | Novy-Marx 2012 | NULL | INTERM−RECENT negative every horizon, all p≥0.16 |
| 6 | Momentum-crash-state conditioning | Daniel-Moskowitz 2016 | **REFUSE** (5y insufficient → 15y net-negative) | state fires only in 2023 even in 15y; net-negative & sign-stable where it fires |
| 7 | 52-week-high temporal dynamics (streak/Δ) | George-Hwang lineage | NULL | no incremental config clears DSR (best 0.166); dynamics ≈ shipped static term |
| 8 | MAX / lottery-demand | Bali-Cakici-Whitelaw 2011 | NULL | empirically re-derives the low-vol/IVOL null (LOW_MAX−LOW_IVOL insignificant everywhere) |
| 9 | Trend acceleration / momentum-of-momentum | (practitioner) | NULL | distinct from MACD (r=0.09) but not additive; underperforms momentum level |
| 10 | Volatility-managed momentum | Barroso-Santa-Clara 2015 | CLOSED BY ANALYSIS | = the shipped `varianceScalar` (targetVol 0.20); nothing new to ablate |
| 11 | Industry/sector momentum | Moskowitz-Grinblatt 1999 | NULL (& worse) | sector tilt WORSE than single-name momentum (SEC−STOCK −132bp @63d, p=0.012) |

## The measured conclusion
**No price-only single signal in this sweep clears the DSR > 0.95 net-of-cost bar on real retail-scale data.** This is a *measured* result across 11 independent families, not an assertion — and it reinforces the corpus's standing prior (the engine has no proven edge; its value is risk-discipline). The recurring pattern:
1. **Absolute Sharpes ride bull-market beta** (2011–2026 / 2021–2026 are bull-heavy) and look superficially strong — several absolute DSRs reach 0.6–0.92. The equal-weight benchmark's own Sharpe is usually as high or higher. The absolute column is a trap; only the market-neutral **incremental** test is honest.
2. **The incremental tests are null or negative** everywhere. Where a candidate is a refinement of an existing engine term (frog/residual/gap/52wh/accel = momentum family; MAX/downside-beta = low-vol family), it fails to beat the term it refines, and often underperforms it.
3. **Cost + the DSR selection haircut finish the job.** Even the few candidates with a positive point estimate never approach the t>3 / DSR>0.95 bar once costs and multiple-testing are charged.

## The one thing that isn't fully closed
**Momentum-crash-state conditioning (#6)** is the only candidate that surfaced a genuinely *non-redundant* mechanism: the engine's vol controls (`varianceScalar`, `StockSageVolRegime`) are vol-LEVEL brakes and measured a **no-op (scalar=1.0) precisely in the crash-state** (vol had fallen after a decline). So the overlay targets an unaddressed axis — vol-*trajectory*, not vol-level. BUT: the state's "2y-trailing-negative AND calm-vol" definition structurally fires only in slow-bleed-then-quiet regimes; even 15 years (2011–2026) contained only one such episode (2023), where the overlay measured **net-negative and sign-stable** (both 2023 sub-episodes were momentum continuations that flattening wrongly diluted). Disposition: **REFUSE** to wire; a real efficacy test needs a *fired* slow-bleed-into-second-leg crash (2000-03 or 2008), which needs pre-2011 data. The mechanism is the durable finding; the sign, where testable, is negative.

## Honest residuals (documented next steps — none required, all owner/data-scoped)
- **Broader / small-cap-inclusive universe.** Several nulls (MAX, low-vol, industry-momentum, seasonality) are documented in the literature to concentrate in small/micro-caps and broad cross-sections; the mega-cap panels used here are a conservative substrate that structurally can't see that segment. A small-cap-inclusive panel would be a genuine power upgrade (not a re-tread) — but survivorship gets *worse* the further back / broader you reach, and it needs a heavier data pull.
- **Pre-2011 crash data (2000-03/2008)** for a real momentum-crash-overlay efficacy test.
- **Survivorship-free / point-in-time universes** — every panel here uses today's survivors (a ceiling on any edge, never a floor).
- **The shipped-engine baseline itself** (Phase 3 of the campaign map): does the full multi-signal advisor score clear DSR net-of-cost? That is the offline net-cost validation the `StockSageHistoryCache` (shipped this window by another session) now enables — a separate lane, not duplicated here.
- **Signal ensembles / combinations** — low prior (combining null signals rarely helps), but untested.

## Bottom line for the owner
The fastest, most honest money remains the money not burned: the campaign map's roadmap #1 (refuse-list + turnover discipline) and the risk-discipline the engine already ships. Eleven vetted single-signal edges were measured this window and none survived retail costs at the honest bar. That is a real, durable result — it narrows the search and confirms the engine's honest self-description. The next genuine shot at a *measured* edge is either a broader/deeper data substrate for the small-cap-concentrated effects, or the shipped-engine baseline measurement — both data/owner-scoped, neither a quick single-signal ablation.
