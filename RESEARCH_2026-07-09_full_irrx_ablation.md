# RESEARCH 2026-07-09 — FULL IRRX (earnings-window exclusion POPULATED) net-of-cost ablation — OPEN FRONTIER #1's last axis

**Verdict: NULL — the earnings-window exclusion does not rescue the reversal overlay. WITH full exclusion (61/61 symbols, real dates, ±2-day windows, 5,297 symbol-period drops): best net-OOS DSR 0.553 vs 0.541 without — a +0.012 nudge, no config clears DSR>0.95, and net means are NEGATIVE at 12/12 configs both ways. OPEN FRONTIER #1's residual ("the X was never applied") is answered; the row can CLOSE.**

## Why this run (and what unblocked it)
The 2026-07-03 IRRX ablation returned NULL but with one honest caveat that kept the frontier
row interim-open for six days: `Panel.earningsExcludedAt` was EMPTY — industry-relative
reversal was tested, not full IRRX — because no historical-earnings-dates source existed
(Yahoo quoteSummary was crumb-gated; EODHD needed a token; an underpowered AV run was
declined as corpus pollution). **Unblocked 2026-07-09** by the same discovery that unblocked
the universe lane: Yahoo serves the app's CFNetwork stack where it throttles python. A
cookie+crumb flow through URLSession (`~/.claude/salehman-universe/earnings_fetch.swift`,
Yahoo visualization API) returns ~30 historical earnings dates per symbol — verified against
AAPL's known quarterly cadence back to 2015.

## Panel (source + as-of, pasted from the build)
```
61 shipped-StockSageSector equities × 5y Yahoo v8 adjclose (2021-07-09..2026-07-08,
1254 common days, 0 split-leak events), earnings dates via Yahoo visualization API
(cookie+crumb, CFNetwork) for 61/61 symbols, exclusion window ±2 trading days
(fetch_eodhd_panel.py convention), rt=13bps.
```
- **61 names = every equity in the shipped `StockSageSector` map** (the 07-09 multiyear run's
  curation rule: real industry resolution, zero "Other" degeneracy) — wider than the original
  24-name IRRX panel, multi-regime (2022 bear + two bulls).
- **Exclusion coverage: 61/61 symbols, 926 excluded period-entries, 5,297 symbol-period
  drops** — the first populated earnings exclusion on any equity panel in this project.
- Harness: `tools/altdata_ablation` — the VERBATIM shipped `StockSageNetCostSim` +
  `StockSageDeflatedSharpe` compiled from source (zero port risk), 12-config grid
  lb∈{5,10,21,63}×hold∈{5,10,21}, walk-forward folds=3/embargo=1, selection-deflated
  (trials=12, measured varTrialSharpe), net of 13bps.

## Result (pasted)
**WITHOUT exclusion (replicates the 07-03 run at 2.5× breadth):** best net-OOS DSR 0.541
(lb5/hd21); ANY config clears: **NO**; meanNet negative at 12/12 configs; meanGross negative
at 11/12.
**WITH full earnings-window exclusion:** best net-OOS DSR **0.553** (same lb5/hd21 cell);
ANY config clears: **NO**; meanNet still negative at 12/12 configs. The exclusion flips a
few gross means marginally positive (e.g. lb5/hd21 −0.00022→+0.00044; lb10/hd21
−0.00147→+0.00025) — the mechanism is real but TINY, and costs erase it entirely.

## What this closes
1. **OPEN FRONTIER #1's residual axis is DONE.** The six-day caveat — "net edge not
   demonstrated ≠ IRRX disproven, because the X was never applied" — no longer holds: the X
   is applied, with real dates, full coverage, on a wider panel, and the verdict is the same
   NULL. The 2026-07-03 prediction ("E-exclusion ≤~4 days/qtr can't lift net-≈0 to DSR>0.95
   at this power") is confirmed by measurement: it lifted DSR by 0.012.
2. **The RefuseList naive-reversal fence + "unproven edge" floor stand**, now with the
   strongest version of the overlay tested.
3. **The earnings-dates axis is permanently unblocked** for future research
   (`earnings_fetch.swift`, durable, reusable — also the input the app-side earnings
   features could one day validate against).

## Honesty caveats
Survivorship (today's 61 large-cap survivors); single vendor (Yahoo adjclose + Yahoo
earnings dates — a wrong/missing earnings date weakens the exclusion, though 61/61 coverage
at ~30 dates/name matches the expected quarterly cadence); 13bps US round-trip (research-
ratified 2026-07-09); the exclusion window (±2 trading days) is the harness's shipped
convention, not swept. A null here closes the overlay's LAST open axis at this breadth/power;
it does not preclude a CRSP-grade delisting-inclusive rerun from reading differently.
