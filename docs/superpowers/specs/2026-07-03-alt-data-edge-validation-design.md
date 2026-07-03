# Design — Yahoo-independent net-of-cost edge-validation harness

**Date:** 2026-07-03 · **Author:** Claude #1 (Opus 4.8, autonomous money-engine mandate)
**Status:** design → autonomous execution (owner away 12h; standing mandate "improve the money
engine way more, do what you think is best, never stop, never make mistakes")

## Problem (grounded in the campaign map, not invented)

The money engine has **no proven edge** (DSR ≈ 0; value is risk-discipline). The campaign's job
is to *find a measured net-of-cost edge*. Two OPEN FRONTIER residuals are the live, non-owner-gated
work:
- **#1 IRRX** — the industry-relative reversal real-data ablation ran → NULL, but stays interim-open
  on ONE axis: the **earnings-window exclusion** (the actual "IRRX" cleaning) was never applied.
- **#2 concentration** — count-cap vs continuous-allocator ablation on real data (undone).

**Both need real data, and every existing validation path is hostage to the Yahoo v8 endpoint**,
which is throttled (poller stuck on 000660.KS, repeated 429). Alpha Vantage is 25 req/day (too few
for a rigorous equity panel); the prior IRRX `panel.json` died with its session. So a *rigorous*
real-data equity ablation is **not feasible this session** — forcing a data-starved one would be a
low-rigor result that pollutes the corpus (the mistake to avoid).

## Approach — remove the Yahoo dependency, don't fake data

Build the durable piece the campaign actually lacks: a **Yahoo-independent** net-of-cost
walk-forward validation path. Reuse, don't rebuild:
- **Machinery (unchanged, shipped):** `StockSageNetCostSim.simulate` (walk-forward folds,
  purge+embargo, per-side turnover costs) + `StockSageDeflatedSharpe` (DSR > 0.95 bar) +
  `StockSageNetEdge.defaultCosts`. O6 proved these work; they only ever lacked real panels.
- **New (small):**
  1. **Data adapter** — pull daily closes from Alpha Vantage (equity daily + EARNINGS dates) and
     CoinGecko (crypto, keyless/abundant) → a return-panel fixture JSON, every series labeled with
     source + as-of (honesty floor: provenance on every stat). No Yahoo.
  2. **Signal constructor** — industry-relative reversal **with the earnings-window exclusion**
     (the #1 residual's missing axis), formulas ported EXACTLY from the Swift source
     (spec-fidelity: derive/port, never call the code under test to make fixtures).
  3. **Driver** — feed panel + signal through the shipped `StockSageNetCostSim` → DSR verdict.

## Scope (realistic for one session, honest about power)

- **MVP — machinery-validation pilot on CoinGecko crypto** (keyless, abundant): proves the adapter
  + driver end-to-end on real data. Crypto has no earnings window, so it validates the *reversal +
  net-cost machinery*, NOT IRRX — labeled exactly that (the NetCostSim synthetic-fixture precedent:
  machinery validation ≠ edge claim). Honest crypto-reversal net verdict recorded (expected null;
  crypto reversal is fenced-adjacent, anti-edge #5).
- **Stretch — underpowered AV equity IRRX pilot** (~8 names within the 25/day budget): adds the
  earnings-window exclusion on a *small* panel, flagged **UNDERPOWERED — indicative, not
  conclusive**; advances #1's method even if N is too small for significance.
- **Deferred (needs Yahoo recovery / AV budget over days / owner fills):** the full rigorous
  24-name IRRX panel and the #2 concentration ablation — queued, runnable on this harness the moment
  data is available.

## Gates & honesty (non-negotiable)

- **No engine behavior change ships.** New files only (harness + fixtures + research index entry).
  Any survivor that clears DSR > 0.95 → owner-gated activation proposal (RANKING #10 precedent),
  never wired autonomously.
- **Parked gates untouched:** F01/F02, F03/F44, RANKING #10, cost-table (#4). The cost table stays
  byte-identical; the harness *consumes* `defaultCosts`, never edits it.
- **Nulls are wins** — indexed per research-memory §3/§4 with source+as-of, "did NOT establish"
  section, DSR/PSR numbers quoted (never "looks better").
- **Data provenance labeled**; underpowered runs labeled underpowered; gross vs net always labeled.

## Success criteria

Harness runs end-to-end on real (non-Yahoo) data, produces an honest DSR verdict, and is indexed +
shipped as new files through the pipeline (build/test verdict lines, dev-log, bundle, add-by-name,
CI, ff-merge). The Yahoo poller keeps running in parallel — its completion unblocks the full panels.
"Done" = a working, reusable validation path + an honest recorded result, not a claimed edge.
