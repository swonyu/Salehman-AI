# Research: Stricter TOM walk-forward on app cache (offset sweep + trial accounting)

**Date:** 2026-07-09  
**Author:** GitHub Copilot (GPT-5.3-Codex)  
**Status:** INTERIM / STILL UNDERPOWERED (explicitly non-promotional)

## Objective

Run a stricter turn-of-month (TOM) variant on the same cache-only dataset by adding:

- offset sweep across entry/exit windows
- trial accounting for configuration selection
- explicit conservative no-overclaim disposition

## Data (same cache as prior probe)

Source: `~/Library/Application Support/salehman_history_cache.json`.

- cache span: 2025-07-07 to 2026-07-08
- effective depth: ~252 bars (1 year, by design)
- symbols tested: `SPY VOO QQQ DIA IWM VTI XLF XLK XLE XLI`
- windows per symbol: `n=12` monthly TOM windows

This horizon remains power-limited and cannot close the candidate.

## Stricter walk-forward spec

- Entry offsets: `{-2, -1}` trading days before month-end
- Exit offsets: `{+3, +4}` trading days after month start
- Trial count from sweep: `4`
- Cost: ETF round-trip `8 bps` per TOM trade
- For each symbol:
  - compute all 4 configs with no look-ahead
  - select the best config by net Sharpe
  - evaluate with conservative trial-aware gate (selection-penalized)

## Results (best config per symbol after sweep)

- SPY: best `(-2,+3)`, net mean `0.454%/mo`, net Sharpe `0.321`, t `1.065`, BH Sharpe `0.399`
- VOO: best `(-2,+3)`, net mean `0.447%/mo`, net Sharpe `0.316`, t `1.047`, BH Sharpe `0.386`
- QQQ: best `(-2,+3)`, net mean `0.478%/mo`, net Sharpe `0.222`, t `0.735`, BH Sharpe `0.357`
- DIA: best `(-2,+3)`, net mean `0.639%/mo`, net Sharpe `0.510`, t `1.691`, BH Sharpe `0.562`
- IWM: best `(-1,+3)`, net mean `0.673%/mo`, net Sharpe `0.516`, t `1.710`, BH Sharpe `0.613`
- VTI: best `(-2,+3)`, net mean `0.496%/mo`, net Sharpe `0.342`, t `1.135`, BH Sharpe `0.416`
- XLF: best `(-1,+3)`, net mean `0.491%/mo`, net Sharpe `0.290`, t `0.962`, BH Sharpe `0.190`
- XLK: best `(-2,+3)`, net mean `0.609%/mo`, net Sharpe `0.177`, t `0.586`, BH Sharpe `0.346`
- XLE: best `(-2,+3)`, net mean `0.362%/mo`, net Sharpe `0.153`, t `0.508`, BH Sharpe `0.344`
- XLI: best `(-2,+3)`, net mean `0.949%/mo`, net Sharpe `0.519`, t `1.720`, BH Sharpe `0.328`

Aggregate (best-of-sweep, 10 symbols):

- average net mean TOM return: `+0.560%/mo`
- average net Sharpe: `0.336`
- symbols with TOM net Sharpe > buy-and-hold monthly Sharpe: `2/10`
- symbols passing conservative trial-accounted significance gate: `0/10`

## Interpretation

- The sweep improves point estimates versus the fixed-window probe, but once trial selection is accounted for, there are **no significant passes**.
- With only 12 monthly windows per symbol and 4 trial configs, this is exactly where overfitting risk is highest.
- Therefore this run is explicitly **still underpowered** and **not promotion-eligible**.

## Disposition

- Record as stricter interim evidence only.
- No strategy wiring, no parameter activation, no promotion claim.
- Candidate remains OPEN pending multi-year split-adjusted ETF panel + full walk-forward significance and DSR-grade gating.

## Repro

Executed as a cache-only Python walk-forward script in terminal (same cache source, strict offset sweep, conservative trial accounting).
