# METHOD (pinned before results) — intraday execution-cost curve for the session-timing advisory
(written 2026-07-11 before any bucket statistic was computed. COST-LANE measurement, display-advisory class —
NOT a signal ablation: no return prediction, no DSR machinery, no ranking change. Purpose: upgrade the shipped
"enter near close" `sessionNote` advisory from a research prior to THIS universe's measured curve.)

## Data
- EODHD 1-minute bars (the owner's $29.99 All World Extended tier), default depth ≈ 4 months (~80 trading days),
  one request per name. Timestamps UTC; regular US session = 13:30–20:00 UTC (09:30–16:00 ET, summer).
- Sample (mechanical, pinned): the US members of `StockSageStrategyBacktest.sampleSymbols` PLUS a 42-name
  dollar-volume-stratified sample from the frozen panel's ACTIVE names (14 per liquidity tercile, every k-th name of
  the tercile's alphabetical list — deterministic stride, no discretion). Pre/post-market bars EXCLUDED.

## Metrics (per 30-minute bucket × 13 buckets over the regular session; per name, then pooled by median)
- (a) **Range proxy**: mean of (high − low)/close per 1-minute bar — the standard intraday cost proxy for
  market-ish retail fills (no quote data on this tier; stated as a PROXY, not realized spread).
- (b) **Volume share**: bucket volume / regular-session volume (liquidity availability).
- (c) **1-minute return volatility** within the bucket.

## Pinned decision rule for the advisory
The shipped "enter near close" guidance is SUPPORTED iff, on the pooled curve, the final bucket (15:30–16:00 ET)
shows (i) volume share ≥ 1.5× the midday-bucket average (buckets 4–9) AND (ii) a range proxy ≤ the median bucket's.
If either fails, the advisory copy must be revised to what the measured curve actually says (any copy change is
display-only and ships through the full pipeline: tests, review, gate, CI, pixel QA). Either way the measured curve
and magnitudes are recorded; no outcome is an edge claim.

## Honest limits (decided now)
Range/volume are proxies (documented U-shape literature); ~4 months = one season (no earnings-season split in v1);
the sample is liquidity-stratified but 66 names; overnight-entry economics (the momentum-accrual research) are OUT of
scope — this measures within-session execution conditions only.
