# Research: TOM holdout robustness (locked config, no reselection) on same cache

**Date:** 2026-07-09  
**Author:** GitHub Copilot (GPT-5.3-Codex)  
**Status:** INTERIM / UNDERPOWERED (explicitly non-promotional)

## Goal

Continue strict no-overclaim TOM testing by removing holdout reselection:

- choose TOM config on train split only
- lock that config
- evaluate unchanged in holdout

## Dataset and constraints

- Source: `salehman_history_cache.json`
- Cache span: `2025-07-07` to `2026-07-08`
- Symbols: `SPY VOO QQQ DIA IWM VTI XLF XLK XLE XLI`
- Common monthly TOM windows: `12`
- Cost: `8 bps` round trip

Power is extremely limited by horizon depth.

## Pre-registered split protocol

- Sweep configs (train-only selection):
  - entry offsets `{-2,-1}` trading days before month-end
  - exit offsets `{+3,+4}` trading days after month start
- Split:
  - TRAIN = first 6 months
  - HOLDOUT = last 6 months
- Selection rule:
  - pick highest train Sharpe config
  - no holdout reselection allowed

## Results

Locked config selected from train: `(-1,+3)`.

- TRAIN (`n=6`):
  - mean net: `+0.2839%/mo`
  - Sharpe: `0.267`
  - t-stat: `0.596`
- HOLDOUT (`n=6`):
  - mean net: `+0.3341%/mo`
  - Sharpe: `0.810`
  - t-stat: `1.811`

Comparator (pooled ETF buy-and-hold monthly):

- BH TRAIN Sharpe: `1.214`
- BH HOLDOUT Sharpe: `0.594`
- HOLDOUT locked TOM Sharpe > HOLDOUT BH Sharpe: `True`

Sweep transparency:

- `(-2,+3)`: TRAIN Sharpe 0.180, HOLDOUT Sharpe 0.631, HOLDOUT t 1.412
- `(-2,+4)`: TRAIN Sharpe 0.015, HOLDOUT Sharpe 0.392, HOLDOUT t 0.876
- `(-1,+3)`: TRAIN Sharpe 0.267, HOLDOUT Sharpe 0.810, HOLDOUT t 1.811
- `(-1,+4)`: TRAIN Sharpe 0.108, HOLDOUT Sharpe 0.172, HOLDOUT t 0.385

## Interpretation (honesty floor)

- This is a better anti-overfit protocol than best-of-full-sample selection.
- However, split sample size is only `6` months per side; HOLDOUT t=1.811 is still below conventional significance.
- Therefore, despite holdout Sharpe improvement, this remains underpowered and non-promotional.

## Disposition

- Record as interim robustness evidence only.
- No wiring/activation changes.
- TOM candidate remains OPEN for a multi-year split-adjusted panel run.

## Repro

Executed as terminal Python walk-forward against the same cache with train-locked configuration and holdout-only evaluation.
