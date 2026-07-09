# Research: Turn-of-month ETF probe on app cache (token-free, 1y horizon) — interim measurement

**Date:** 2026-07-09  
**Author:** GitHub Copilot (GPT-5.3-Codex)  
**Status:** INTERIM / UNDERPOWERED (not promotion-eligible). This run is a cache-constrained progress check, not a frontier close.

## Why this run

The candidate-edge backlog retained one live validation candidate: turn-of-month (TOM) index-ETF seasonality. External split-adjusted equity feeds were previously blocked/token-gated. This run uses the app's on-disk cache only, so it is token-free and executable now.

## Data scope (hard constraint)

From `~/Library/Application Support/salehman_history_cache.json` (decoded with Swift `Date` epoch semantics, seconds since 2001-01-01):

- cache entries with dates: 2415
- global cache span: 2025-07-07 to 2026-07-08
- savedAt: 2026-07-08
- cache depth is intentionally ~252 bars (1y), matching `StockSageHistoryCache.defaultMaxBars = 252` and quote fetch default `range: "1y"`.

This means TOM is tested over ~12 monthly windows only, which is far below the power required to close this candidate.

## Method

- Symbols tested (liquid ETFs present in cache):
  `SPY VOO QQQ DIA IWM VTI XLF XLK XLE XLI`
- TOM window definition (fixed, no parameter sweep):
  enter at close of last trading day of month, exit at close of 3rd trading day of next month.
- Cost assumption: ETF round-trip cost 8 bps (`0.0008`) per monthly TOM round trip (same tier used in prior TOM candidate note).
- Metrics per symbol:
  - mean gross TOM return per month
  - mean net TOM return per month
  - TOM net Sharpe (monthly TOM windows)
  - buy-and-hold monthly Sharpe (end-of-month close-to-close)

## Results

Per symbol (`n=12` monthly TOM windows each):

- SPY: mean net 0.001434, net Sharpe 0.197, BH Sharpe 0.399
- VOO: mean net 0.001389, net Sharpe 0.190, BH Sharpe 0.386
- QQQ: mean net 0.001449, net Sharpe 0.103, BH Sharpe 0.357
- DIA: mean net 0.003883, net Sharpe 0.385, BH Sharpe 0.562
- IWM: mean net 0.006729, net Sharpe 0.516, BH Sharpe 0.613
- VTI: mean net 0.001940, net Sharpe 0.255, BH Sharpe 0.416
- XLF: mean net 0.004907, net Sharpe 0.290, BH Sharpe 0.190
- XLK: mean net 0.002556, net Sharpe 0.106, BH Sharpe 0.346
- XLE: mean net 0.002794, net Sharpe 0.138, BH Sharpe 0.344
- XLI: mean net 0.003822, net Sharpe 0.239, BH Sharpe 0.328

Aggregate over tested ETFs:

- average gross TOM monthly return: 0.003890
- average net TOM monthly return: 0.003090
- symbols where TOM net Sharpe > buy-and-hold monthly Sharpe: 1 / 10

## Interpretation (honesty floor)

- The run is directionally useful but statistically weak due to horizon depth (`n=12` windows/symbol).
- In this cache slice, TOM net Sharpe usually trails buy-and-hold monthly Sharpe (9/10 symbols), so this does not support a promotion claim.
- Because the sample is one year only, this is explicitly not a closure of the TOM candidate.

## Disposition

- Record as interim evidence only.
- No code change, no wiring, no policy change.
- Frontier status for TOM remains open pending a multi-year split-adjusted ETF panel run with proper walk-forward significance and DSR gating.

## Repro

Used one-shot Python in terminal against the local cache JSON with fixed TOM window and 8 bps ETF round-trip cost assumption.
