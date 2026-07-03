# Research: Industry/sector price momentum (Moskowitz & Grinblatt 1999, JF) — net-of-cost REAL-DATA ablation

**Date:** 2026-07-03 · **Author:** Opus session (autonomous ablation) · **Status:** NULL (no incremental edge; sector arm underperforms single-name momentum) — a win; indexed.

## Question
Moskowitz & Grinblatt (1999, JF): industry-level underreaction to common news produces a momentum
effect stronger/more persistent than single-stock momentum. Signal: `industryMomentum_i` = trailing
6-month skip-1mo return of stock i's sector (average of member returns), assigned to each member;
tilt long to top-momentum sectors. HYPOTHESIS: a sector-momentum tilt earns net-of-cost edge
INCREMENTAL to single-name momentum (later literature shows much of industry momentum loads on the
standard momentum factor, so the standalone test is not the interesting one).

## Method
- **Harness fidelity:** `StockSageDeflatedSharpe.swift` COMPILED FROM THE REAL SOURCE (zero port
  risk). `StockSageNetEdge.defaultCosts` bare-US round trip = 13bps (spread 8 + slippage 5), ported.
- **Universe (frozen, REUSED — no new fetch):** the multi-regime panel `/tmp/multiregime_panel/
  panel.json` — 25 US large-caps + ^GSPC, 15y daily 2011-07-05→2026-07-02 (3771 bars, calendar
  verified). Chosen for more names/sectors + more blocks than the 18-name precedent.
- **Sectors (frozen before analysis, thin — disclosed):** 8 sectors — tech {AAPL,MSFT,GOOGL,CSCO,
  INTC,IBM}(6), industrials {CAT,HON,MMM,GE}(4), staples {PG,KO,WMT}(3), health {JNJ,UNH,PFE}(3),
  discretionary {HD,MCD,DIS}(3), financials {JPM,BAC}(2), energy {XOM,CVX}(2), comm {T,VZ}(2).
  **6 of 8 sectors have only 2–4 members — the biggest limitation.**
- **Signal:** `timeSeriesMomentum(126, skipRecent:21)` = `(c[i-21]-c[i-126])/c[i-126]`, ported.
  `sectorMom_i` = simple average of member mom across the sector. `BASE_STOCK_MOM` = per-name.
- **No look-ahead:** signal ≤ i, enter open[i+1], exit open[i+1+H]; non-overlapping blocks stepped
  by H; warmup i≥126.
- **Three arms:** SECTOR = eq-wt long members of top-tercile-3 sectors (avg ~9.7 names); STOCK =
  eq-wt top-8 single names by mom; EQW = eq-wt all 25 (same rebalance cadence). Net 13bps each.
- **Block-level significance:** paired t across non-overlapping blocks on SEC−STOCK and SEC−EQW
  (t-CDF self-checked t=2.228/df=10→p=0.050). Horizons 21/42/63/126d. DSR selection-deflated
  trials=20 (5 arms × 4 horizons), varTrialSharpe=0.13502 (measured).

## Results
| H | nBlk | SECTOR net | STOCK net | EQW net | SECTOR abs DSR | SEC−STOCK net / t / p / DSR | SEC−EQW net / t / p / DSR |
|---|---|---|---|---|---|---|---|
| 21  | 173 | +74.3  | +104.7 | +93.5  | 0.000 | −30.4 / −1.91 / 0.058 / 0.000 | −19.2 / −1.22 / 0.225 / 0.000 |
| 42  | 86  | +177.0 | +226.3 | +194.5 | 0.001 | −49.3 / −1.55 / 0.124 / 0.000 | −17.5 / −0.51 / 0.609 / 0.000 |
| 63  | 57  | +235.8 | +367.6 | +296.8 | 0.020 | **−131.8 / −2.60 / 0.012 / 0.000** | −61.0 / −1.26 / 0.212 / 0.000 |
| 126 | 28  | +605.4 | +696.9 | +608.1 | 0.597 | −91.6 / −1.26 / 0.218 / 0.000 | −2.7 / −0.03 / 0.975 / 0.000 |

- **No absolute arm clears DSR>0.95 anywhere** (best STOCK/126d 0.828 — bull-market beta).
- **Sector momentum is NEGATIVE vs both baselines at EVERY horizon** — never positive incremental.
  SEC−STOCK block-significant at 63d (p=0.012), marginal at 21d (p=0.058); every incremental DSR
  = 0.000 (hard fail). Single-name momentum beat the sector-averaged version of the identical
  formula at 3/4 horizons — the OPPOSITE of the hypothesis.

## Conclusion
NULL — sector momentum is NOT incremental to single-name momentum; where it differs it is WORSE.
Averaging a 2–6-name sector bucket dilutes/adds noise rather than capturing a common-news
underreaction premium beyond what single-name momentum already prices. The "sector" transform of the
momentum factor is a pure cost here (lower Sharpe, negative increment). Keep engine as shipped; no
sector-momentum tilt.

## What this round did NOT establish
- NOT a disproof of Moskowitz-Grinblatt on the full CRSP universe with proper GICS sectors — this is
  a thin 25-name/8-sector mega-cap replica; a wider universe with 8+ names/sector could differ
  (the natural residual).
- NOT tested with vol-scaled/cap-weighted sector aggregation (simple eq-wt per spec).
- INCREMENTAL arms ARE market-neutral (bull beta stripped) and they fail negative, not just
  insignificant.
- Mechanistically DISTINCT from the null'd RS-rank (benchmark-relative percentile) and IRRX
  (industry-relative REVERSAL) — a fourth independently-falsified signal family, not a repackage.

## Honest limitations
- THIN sectors (2–4 names in 6/8) is the headline — plausible root cause of the negative increment.
- Survivorship WORSE at 15y (large-caps that stayed large-caps; every delisted sector-momentum loser
  excluded).
- 25+yr-old well-known anomaly = strong arbitraged-away prior, consistent with the null.
- H=126 (28 blocks) modest power — read as "not significant," not "proven zero."
- Sector-partition is one unswept researcher DoF (frozen before analysis; only one partition tried).

## Reproduce
`scratchpad/industry_mom/sector_mom.py` (stdlib, reads `/tmp/multiregime_panel/panel.json`) +
`main.swift` compiled with `StockSageDeflatedSharpe.swift`. Panel is a frozen local file → decimals
stable; only the conclusion needs rechecking if the panel is regenerated.
