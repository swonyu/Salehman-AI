# Research: TOM leave-one-symbol-out continuation (same cache)

**Date:** 2026-07-09  
**Author:** GitHub Copilot (GPT-5.3-Codex)  
**Status:** INTERIM / UNDERPOWERED (concentration check)

## Objective

Measure concentration dependence by leaving out one ETF at a time (LOSO) for the locked TOM config.

## Setup

- Source: `salehman_history_cache.json`
- Cache span: `2025-07-07` to `2026-07-08`
- Base basket: `SPY VOO QQQ DIA IWM VTI XLF XLK XLE XLI`
- Locked config: `(-1,+3)`
- Cost: `8 bps` round trip
- Observation count: `n=12` monthly pooled points per LOSO panel

## Baseline

Full 10-symbol panel for locked config:

- mean `+0.3090%/mo`
- Sharpe `0.383`
- t `1.269`

## LOSO summary

Mean net return range after dropping one symbol:

- minimum mean: drop `IWM` -> `+0.2686%/mo`
- maximum mean: drop `VOO` -> `+0.3279%/mo`

Per-drop diagnostics (all underpowered):

- drop `IWM`: mean `+0.2686%`, Sharpe `0.326`, t `1.130`, sign `p=0.3877`, boot95 `[-0.1493%, +0.7193%]`
- drop `XLF`: mean `+0.2888%`, Sharpe `0.327`, t `1.133`, sign `p=0.7744`, boot95 `[-0.1660%, +0.7967%]`
- drop `DIA`: mean `+0.3002%`, Sharpe `0.347`, t `1.203`, sign `p=0.3877`, boot95 `[-0.1353%, +0.7983%]`
- drop `XLI`: mean `+0.3009%`, Sharpe `0.373`, t `1.293`, sign `p=0.1460`, boot95 `[-0.1054%, +0.7617%]`
- drop `XLE`: mean `+0.3123%`, Sharpe `0.341`, t `1.182`, sign `p=0.7744`, boot95 `[-0.1482%, +0.8428%]`
- drop `XLK`: mean `+0.3150%`, Sharpe `0.386`, t `1.338`, sign `p=0.1460`, boot95 `[-0.0951%, +0.8026%]`
- drop `VTI`: mean `+0.3218%`, Sharpe `0.374`, t `1.295`, sign `p=0.1460`, boot95 `[-0.1164%, +0.8114%]`
- drop `QQQ`: mean `+0.3273%`, Sharpe `0.387`, t `1.340`, sign `p=0.1460`, boot95 `[-0.0917%, +0.8432%]`
- drop `SPY`: mean `+0.3274%`, Sharpe `0.377`, t `1.306`, sign `p=0.1460`, boot95 `[-0.0989%, +0.8340%]`
- drop `VOO`: mean `+0.3279%`, Sharpe `0.378`, t `1.309`, sign `p=0.1460`, boot95 `[-0.1022%, +0.8319%]`

## Interpretation

- No single ETF drives a collapse or creates significance.
- The range is modest but inference remains weak in all LOSO variants.
- CIs cross zero across the board.

## Disposition

- Underpowered and non-promotional.
- No wiring/activation changes.
- Candidate remains OPEN for broader-horizon testing.
