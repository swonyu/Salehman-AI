# Cap-vs-continuous ablation robustness check — regime split re-run (real data, net-of-cost)

**Date:** 2026-07-09  
**Author:** GitHub Copilot (GPT-5.3-Codex)  
**Scope:** Extend the 2026-07-07 cap-vs-continuous study with explicit subperiod robustness on the same frozen 20-name Yahoo panel.  
**Verdict:** **NULL / not stable across subperiods.** The earlier full-window cap lead is not robust once split into two independent windows; no hard-cap promotion case is supported.

## Question

Does the 2026-07-07 in-sample cap-vs-continuous lead remain statistically supported when the same panel is split into earlier and later subperiods?

## Method

- Reused the same frozen panel from `tools/cap_ablation/panel.json` (20 US large-caps, 1254 shared daily bars, 2021-07-07 to 2026-07-06).
- Compiled and ran the same shipped harness path (`tools/cap_ablation/main.swift`) against shipped:
  - `StockSageCorrelationCluster.correlationAdjustedWeights`
  - `StockSageDeflatedSharpe`
  - `StockSagePortfolioAnalytics`
- Costing unchanged: round-trip 13 bps (6.5 bps one-way turnover charge).
- Created two bar-split subpanels from the frozen panel:
  - First-half: bars `0..629` (630 bars), 75 weekly rebalances.
  - Second-half: bars `620..1253` (634 bars), 76 weekly rebalances.
- Ran the same raw and exposure-matched increment tests: `d_t = net(CAP-N) - net(CONTINUOUS)`, block size 4 weeks.

## Repro commands

```bash
cd tools/cap_ablation
swiftc -O main.swift ../../"Salehman AI"/StockSage/StockSageCorrelationCluster.swift ../../"Salehman AI"/StockSage/StockSageDeflatedSharpe.swift ../../"Salehman AI"/StockSage/StockSagePortfolioAnalytics.swift -o /tmp/cap_ablate_main
/tmp/cap_ablate_main panel.json | tee /tmp/cap_ablate_full_2026-07-09.log
/tmp/cap_ablate_main panel_firsthalf.json | tee /tmp/cap_ablate_firsthalf_2026-07-09.log
/tmp/cap_ablate_main panel_secondhalf.json | tee /tmp/cap_ablate_secondhalf_2026-07-09.log
```

## Results

### Full window (repro check of 2026-07-07 baseline)

- Matches prior baseline behavior.
- RAW increments: CAP-3 `+1.62 bps/wk` (`p=0.044`), CAP-5 `+1.66 bps/wk` (`p=0.0107`), CAP-1/2 raw null.
- Exposure-matched increments positive for all N with `p<0.05`.

This is a reproduction check, not new evidence by itself.

### First-half split (75 weekly rebalances)

- RAW increments: CAP-1 `+0.34` (`p=0.842`), CAP-2 `+1.42` (`p=0.302`), CAP-3 `+1.55` (`p=0.219`), CAP-5 `+1.57` (`p=0.091`).
- Exposure-matched: CAP-1 `+8.71` (`p=0.0535`), CAP-2 `+5.29` (`p=0.0554`), CAP-3 `+2.89` (`p=0.102`), CAP-5 `+1.57` (`p=0.091`).
- Harness verdict line: `ANY_CAP_BEATS_CONTINUOUS_SIG ...: NO — null holds`.

### Second-half split (76 weekly rebalances)

- RAW increments: CAP-1 `-0.88` (`p=0.557`), CAP-2 `+0.16` (`p=0.878`), CAP-3 `+1.89` (`p=0.167`), CAP-5 `+1.57` (`p=0.182`).
- Exposure-matched: CAP-1 `+3.24` (`p=0.406`), CAP-2 `+2.57` (`p=0.297`), CAP-3 `+3.27` (`p=0.119`), CAP-5 `+1.49` (`p=0.203`).
- Harness verdict line: `ANY_CAP_BEATS_CONTINUOUS_SIG ...: NO — null holds`.

## Interpretation

- The cap lead is not stable out of the pooled full-window sample.
- Both independent split windows fail the harness significance condition for cap superiority.
- This increases confidence that the 2026-07-07 positive full-window signal is regime/sample-fragile and should remain non-actionable.
- Disposition remains unchanged:
  - No hard top-N cap promotion.
  - Keep shipped continuous allocator policy unchanged.
  - Any allocator change stays owner-gated.

## Caveats

- These are subperiod cuts of a single frozen panel, not new universes.
- The panel is still survivor-tilted and large-cap only.
- This run is robustness evidence, not a final OOS multi-regime + delisting-inclusive closure.

## Artifacts

- Logs:
  - `/tmp/cap_ablate_full_2026-07-09.log`
  - `/tmp/cap_ablate_firsthalf_2026-07-09.log`
  - `/tmp/cap_ablate_secondhalf_2026-07-09.log`
- Harness inputs retained in repo: `tools/cap_ablation/panel.json`.
- Temporary split panels used during run were deleted after execution.
