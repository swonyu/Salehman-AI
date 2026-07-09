# Research: Frog-in-the-pan information-discreteness momentum-quality filter — net-of-cost REAL-DATA ablation

**Date:** 2026-07-03 · **Author:** Opus session (autonomous ablation) · **Status:** NULL (net edge not demonstrated) — a win; indexed.

## Question
Da, Gurun & Warachka (2014, RFS) "frog in the pan": momentum that arrives as many small
continuous moves (LOW information-discreteness) persists and reverses little; momentum that
arrives in discrete jumps (HIGH ID) reverses. ID = sign(formationReturn) × (%negative-days −
%positive-days) over the formation window. HYPOTHESIS: conditioning a momentum/TSMOM entry on
LOW-ID names improves NET-of-cost forward returns vs unconditional momentum, PRIMARILY by
lowering turnover/whipsaw. Does the low-ID filter clear the honest edge bar (DSR>0.95,
net-of-cost) on real data?

## Method
- **Harness fidelity:** the port-risky helper (`StockSageDeflatedSharpe` — Acklam inverse-normal,
  PSR/expected-max-Sharpe) was COMPILED FROM THE REAL SOURCE (with `StockSageNetEdge`,
  `StockSageLiquidity`, `StockSageAllocation`) into a standalone Swift runner — zero port risk on
  the verdict math, same recipe as the 2026-07-03 IRRX ablation. `defaultCosts` suffix bps ported
  exactly (US 13 / intl-dotted 30).
- **Universe (frozen BEFORE analysis):** 24 names — 18 US large-caps across 6 sectors {NVDA,AVGO,MU;
  AAPL,MSFT,GOOGL; JPM,BAC; XOM,CVX; PG,KO,WMT; JNJ,UNH,PFE; HD,CAT} + 6 global/Saudi dotted
  {SHEL.L, AZN.L, SAP.DE, 2222.SR (Aramco), 1120.SR (Al Rajhi), 2010.SR (SABIC)} for the intl cost
  tier + global/Saudi spread. FIP is a PER-SYMBOL signal, so mixed calendars are handled natively
  (no cross-sectional alignment needed); blocks are calendar-anchored. All 24 fetched cleanly
  (1246–1273 bars), none dropped.
- **Data:** 5y daily, Yahoo v8 chart endpoint (the source `StockSageQuoteService` uses), fetched
  gently (concurrency 1, ~2s spacing, backoff). No HTTP-429 encountered.
- **Signal (candidate spec, exact):** formation = 126 bars; formationReturn = (c[i]−c[i−126])/c[i−126];
  ID = sign(formRet)×(%neg−%pos) over the 126 daily returns in the window. Momentum WINNER =
  formRet>0 (long candidate). LOW-ID (continuous) = ID<0; HIGH-ID (jumpy) = ID≥0 — a threshold-free,
  economically-grounded, look-ahead-free split (in an uptrend, more up-days than down = continuous).
- **No look-ahead:** signal from closes[0..i]; enter open[i+1], exit open[i+1+H]; as-of index
  stepped by exactly H (non-overlapping, independent blocks).
- **Three arms:** UM = all winners (unconditional momentum); LID = low-ID winners (⊂ UM); HID =
  high-ID winners. Primary hypothesis test = LID vs UM. Mechanism test = LID vs HID.
- **Net-of-cost (mandatory):** net = gross forward return − roundTripBps/1e4 (one round trip per
  long entry/exit); 13bp US, 30bp intl-dotted, from real `defaultCosts`.
- **Block-level significance:** one net number per non-overlapping calendar-anchored block (mean
  across active symbols), then paired t across blocks on the LID−UM and LID−HID differences
  (t-CDF implemented from scratch, self-checked t=2.228/df=10→p=0.0500). Incremental (LID−UM,
  LID−HID) series are market-neutral → they isolate the FILTER's value from bull-market beta.
- **DSR gate:** real `StockSageDeflatedSharpe.deflated` on each per-block net series; Sharpe=mean/sd,
  nTrades=block count; selection-deflated trials=20 (4 horizons × 5 arms), varTrialSharpe=0.0538
  (measured across the 20 configs).
- **Horizon sweep:** 21 / 42 / 63 / 126 trading days.

## Results
Per-block NET means (bp) and DSR (real `StockSageDeflatedSharpe`, trials=20):

| H | nBlk | UM tr | LID tr | HID tr | UM net | LID net | HID net | LID DSR | LID−UM net / DSR / p | LID−HID net / DSR |
|---|---|---|---|---|---|---|---|---|---|---|
| 21  | 56 | 777 | 671 | 106 | +115.3 | +124.6 | −2.2 | 0.204 | +9.3 / 0.008 / 0.372 | +104.5 / 0.044 |
| 42  | 27 | 373 | 321 | 52  | +282.7 | +303.7 | +53.0 | 0.684 | +21.1 / 0.094 / 0.329 | +189.4 / 0.125 |
| 63  | 18 | 249 | 218 | 31  | +307.7 | +320.1 | +126.5 | 0.443 | +12.4 / 0.063 / 0.814 | +125.5 / 0.121 |
| 126 | 9  | 116 | 106 | 10  | +805.9 | +777.6 | +199.8 | 0.732 | −28.3 / 0.015 / 0.490 | +3.8 / 0.163 |

- **NO config clears DSR>0.95.** Best absolute = LID/42d 0.684 (≈ 2021–2026 bull beta, not the
  filter). Best incremental = LID−HID/42d 0.125. Every incremental DSR ≤ 0.125.
- **FIP direction CONFIRMED but not significant:** high-ID (jumpy) winners are near-flat forward
  (gross/trade 32bp@21d, 38bp@63d) vs low-ID continuous winners (135bp, 434bp) — the paper's core
  mechanism is visible. But the LID−HID block spread is not significant (p 0.23–1.0; HID arm thin,
  n=45→6), and LID adds only +9 to +21bp/block over unconditional momentum (sign-flips negative at
  126d), never block-significant (all p>0.22).
- **Turnover:** LID cuts trade count 13.6% (21d), 13.9% (42d), 12.4% (63d), 8.6% (126d). But
  net≈gross everywhere: per-trade cost 13–30bp is dwarfed by the 120–820bp holding-period return,
  so cutting 14% of trades saves a negligible amount.

## Conclusion
**NULL — the low-ID momentum-quality filter does not clear the net-of-cost DSR>0.95 gate on real
data; keep the engine as shipped, do not add an ID filter.** The frog-in-the-pan DIRECTION is
real in the data (jumpy winners don't persist), but three things kill it as a shippable filter:
(1) the incremental value over unconditional momentum is tiny (≤+21bp/block) and never
block-significant; (2) at the 1–6-month horizons where momentum lives, transaction cost is a small
fraction of the return, so the filter's headline mechanism — turnover/whipsaw reduction — has
almost nothing to reduce; (3) the DSR gate rejects at every horizon, absolute and incremental. This
reproduces the standing prior: net edges do not clear the honest bar in a liquid retail replica.

## What this round did NOT establish
- **Not** a disproof of frog-in-the-pan as a cross-sectional academic anomaly — the direction is
  present; only the FILTER-vs-unconditional-momentum NET increment is falsified here at DSR power.
- **Not** tested at daily-to-weekly turnover, where the turnover-reduction mechanism could matter
  more — but the week-horizon precedent already shows no equity edge survives retail costs there.
- **Not** the paper's cross-sectional tercile ID split — a fixed ID<0 threshold in a 2021–2026
  bull market is unbalanced (86–91% low-ID), leaving HID thin/low-power. A same-calendar
  cross-sectional split would balance it but excludes the Saudi/global spread (own calendars). A
  wider/deeper universe with a cross-sectional split is the residual (Fable/owner-scoped).
- **Not** benchmark-subtracted on the absolute arms (they carry bull beta); the incremental arms
  ARE market-neutral and those are the clean tests — and they fail.

## Reproduce
Scratchpad `fetch_panel.py` (Yahoo, stdlib, gentle) → `panel.json`; `fip.py` (stdlib, per-symbol
FIP + blocks + paired-t) → `series.json`; `main.swift` compiled with the real source:
`swiftc -O StockSageAllocation.swift StockSageLiquidity.swift StockSageNetEdge.swift StockSageDeflatedSharpe.swift main.swift -o runner`.
Expect the null to hold (best DSR well below 0.95); short-horizon decimals/signs drift with Yahoo's
sliding 5y window — only the CONCLUSION (net does not clear) is stable.

**UPDATE 2026-07-09 (corpus reconciliation — text-vs-table inconsistency, verdict unaffected):**
the Results section's prose ("Best incremental = LID−HID/42d 0.125. Every incremental DSR ≤ 0.125")
undercounts its own table above: the H=126 row's LID−HID DSR is **0.163**, not 0.125 — the true
best-incremental value across the whole table (LID−UM column max 0.094 @42d; LID−HID column max
0.163 @126d). Corrected in `research/INDEX.md`'s frog-in-the-pan line. Does not change the verdict:
0.163 is still ≪ 0.95, NO config clears, NULL stands.
