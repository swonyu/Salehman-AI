# Research: Net-of-cost real-data ablation of the IRRX reversal overlay (OPEN FRONTIER #1)

**Date:** 2026-07-03 · **Author:** Opus session (autonomous run) · **Status:** NULL (net edge not demonstrated) — a win; indexed.
**Gate discharged:** `research/INDEX.md` OPEN FRONTIER #1 (IRRX-cleaned reversal overlay, week-horizon roadmap #3) — the real-data run the interim 2026-07-03 note said "closure still requires."

## Question
The industry-relative, earnings-window-excluded ("IRRX") reversal is the one short-horizon equity
signal that survives the modern era **gross** of costs (~58 bps/mo, t=3.29 post-decimalization;
108 bps/mo full-sample; Novy-Marx RRLP, verified 3-0 ×4 in
`RESEARCH_2026-07-02_week_horizon_velocity.md`). The plausible **net** retail magnitude is
"0–30 bps/mo at best … NOT a standalone book." Roadmap item #3 GATES any activation behind a real
net-of-cost simulation clearing the honest edge bar (Deflated Sharpe > 0.95), "same rigor as the
2026-07-02 confluence/RS ablation." **Does the shipped IRRX overlay clear that gate on real data?**

## Method
- **Harness = the shipped code, not a re-port.** A standalone Swift driver compiled the ACTUAL
  `StockSageNetCostSim.simulate` + `StockSageDeflatedSharpe` source files (both Foundation-only,
  self-contained) and fed them a real return panel. This eliminates formula-port risk — the exact
  arithmetic the app ships (industry-relative reversal weights, per-side turnover costing,
  walk-forward purge+embargo folds, PSR/DSR) computed the verdict. Driver + fetcher preserved in the
  session scratchpad; panel fetched from Yahoo's chart endpoint (the source `StockSageQuoteService`
  uses).
- **Universe (frozen before analysis):** 24 liquid US large-caps, 6 industries × 4 —
  Semis {NVDA,AMD,MU,AVGO}, MegaTech {AAPL,MSFT,GOOGL,META}, Banks {JPM,BAC,WFC,C},
  Energy {XOM,CVX,COP,SLB}, Staples {PG,KO,PEP,WMT}, Healthcare {JNJ,UNH,PFE,MRK}.
  IRRX is *industry-relative*, so the universe was built with ≥4 names/industry (unlike the
  confluence ablation's single cross-section). Frozen first; no symbol added/dropped after results.
- **Data:** 5y daily, 2021-07-06 → 2026-07-02. All 24 share one NYSE calendar (1254 bars → 1253
  simple-return periods; verified equal length after intersection alignment).
- **Signal (ported EXACTLY by compiling the source):** `past[s]=Σ ret[s][t−lookback..t)`;
  `score[s]=past[s]−mean(past over s's industry)`; `raw[s]=−score[s]` (reversal: long laggards);
  demean + L1-normalize so Σ|w|=1 (dollar-neutral). Held over `[t,t+hold)`, non-overlapping.
- **No look-ahead:** weights at `t` use only `[t−lookback,t)`; forward return over `[t,t+hold)`;
  rebalances step by `hold` (non-overlapping, genuinely independent blocks).
- **Net-of-cost (mandatory):** roundTripBps = **13** (the real US large-cap default,
  `StockSageNetEdge.defaultCosts`, spread 8 + slippage 5), charged per-side on Σ|Δw| turnover.
- **Horizon sweep (days-to-weeks-to-month, per "measure at days-to-weeks frequency"):**
  (lookback,hold) ∈ {(5,5),(10,10),(21,21),(21,5),(21,10),(42,42)}.
- **Verdict:** Deflated Sharpe on the net rebalance-return series — both full-series and the
  stricter pooled walk-forward OOS blocks (folds=3, embargo=1). Selection haircut applied:
  DSR trials=6 (whole sweep), varTrialSharpe=0.00551 (measured variance of the 6 net Sharpes).
- **One disclosed scope-shrink:** the earnings-window exclusion (the "X") needs per-name earnings
  dates not fetched here; the primary run is industry-relative reversal WITHOUT it (see Limitations).

## Results
Per-rebalance means in per-mille (1‰ = 10 bps). **Every config fails the net gate.**

| (lb,hold) | nReb | net Sharpe | gross ‰/reb | net ‰/reb | net-OOS DSR (gate) | clears? |
|-----------|------|-----------|-------------|-----------|--------------------|---------|
| (5,5)     | 249  | −0.147    | −0.817      | −1.737    | 0.000              | no |
| (10,10)   | 124  | −0.147    | −1.860      | −2.782    | 0.015              | no |
| (21,21)   | 58   | +0.000    | **+0.919**  | **+0.001**| 0.143              | no |
| (21,5)    | 246  | −0.123    | −1.124      | −1.560    | 0.001              | no |
| (21,10)   | 123  | −0.124    | −1.351      | −1.980    | 0.003              | no |
| (42,42)   | 28   | +0.013    | +1.344      | +0.433    | 0.176              | no |

Two robust patterns, both consistent with the literature:
1. **Short 1–2 week holds are negative even GROSS** ((5,5),(10,10),(21,5),(21,10): gross ‰ all < 0).
   Recent industry-laggards kept lagging at daily-to-2-week frequency — no reversal to harvest; this
   is the "transient, then flips to momentum" regime the research names. Net is simply worse.
2. **A positive gross reversal appears only at monthly+ holds** — (21,21) realizes **+9.2 bps/month
   gross** — and **costs erase essentially all of it**: net **+0.01 bps/month**, net Sharpe 0.000,
   DSR 0.143. (42,42): +13.4 bps gross / 42d → +4.3 bps net (~2 bps/mo), DSR 0.176.

The best net-OOS DSR across the entire sweep is **0.176 ≪ 0.95**. `clearsNetOfCost = no` everywhere.
Even the GROSS monthly verdict (DSR 0.311) does not clear — this liquid-24 replica has no
statistically-honest edge before costs, let alone after.

## Conclusion
**NULL — the IRRX overlay does not clear the net-of-cost gate on real data; it stays refused / not
activated.** This is the deliverable, not a failure: the harness did exactly what it exists to do —
falsify. On live liquid large-caps, the industry-relative reversal is negative gross at 1–2 week
holds and, at the monthly frequency where a gross reversal exists, transaction costs consume all of
it (net ≈ 0). This empirically reproduces the research net prior ("0–30 bps/mo at best … NOT a
standalone book"): the realized net here is ~0–4 bps/mo at monthly holds — below both that band's
top and the DSR>0.95 detectability bar at this sample power. No activation candidate emerges; the
engine's `StockSageRefuseList` naive-reversal entry and the "unproven edge" honesty floor stand.

## Honest limitations (disclosed, not hidden)
- **Earnings-window exclusion NOT applied.** This tests industry-relative reversal, not the full
  "IRRX." Strictly, full IRRX-with-exclusion remains formally untested → this is "net edge not
  demonstrated," NOT "IRRX disproven." However, the exclusion removes only ≤~4 days/quarter per name
  (a small fraction of a 21-day formation/hold), and it cannot plausibly lift a net-≈0 / DSR-0.14
  monthly result to DSR>0.95 at this power. The frontier line is updated to interim, not closed.
- **Low breadth / low power.** 24 liquid large-caps is a far smaller, liquid-only cross-section than
  the full-CRSP value-weighted decile spread behind the 58 bps/mo figure. Lower realized gross is
  EXPECTED — liquid large-caps are where the reversal is weakest and breadth lowest. This run tests
  "does an edge survive net-of-cost in a liquid retail-accessible replica," NOT the full-universe
  magnitude. A wider/deeper universe could show more gross; whether it survives costs net is the
  open question a larger run (Fable/owner-scoped) would address.
- **Single 5y window (2021-07→2026-07).** One regime era; Yahoo's 5y window slides daily, so exact
  decimals drift — the stable, reproducible claim is the CONCLUSION (net does not clear), never the
  decimals or a sign at a single config.
- **Summed simple returns** (the shipped harness sums daily returns over the hold rather than
  compounding) — faithful to the shipped math; a ≤ second-order approximation at these horizons.
- **Cost model = labeled estimate** (13 bps round-trip), not venue fills; final book never
  liquidated (understates cost by one exit, per the harness's own COST ACCOUNTING note) — both bias
  toward LESS cost, i.e. they make the null CONSERVATIVE (real costs would only lower net further).
- **Multiple comparisons:** 6 configs scanned; DSR deflated for it (trials=6, varTrialSharpe measured).

## Reproduce
Scratchpad `fetch_panel.py` (Yahoo, stdlib) → `panel.json`; `main.swift` compiled with the two real
source files:
`swiftc -O "Salehman AI/StockSage/StockSageNetCostSim.swift" "Salehman AI/StockSage/StockSageDeflatedSharpe.swift" main.swift -o runner`.
Expect the null to hold (best net-OOS DSR well below 0.95); exact ‰ and signs at short holds drift
with the sliding 5y window.
