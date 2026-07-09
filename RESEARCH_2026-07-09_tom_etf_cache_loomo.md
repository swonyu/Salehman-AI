# Research: TOM leave-one-month-out fragility (locked config, same cache)

**Date:** 2026-07-09  
**Author:** GitHub Copilot (GPT-5.3-Codex)  
**Status:** INTERIM / UNDERPOWERED (fragility-confirming)

## Objective

Continue strict robustness checks on the same cache by quantifying month-level dependence for the previously locked TOM config:

- locked config: `(-1, +3)`
- leave-one-month-out (LOOMO) influence analysis

## Data

- Source: `salehman_history_cache.json`
- Cache span: `2025-07-07` to `2026-07-08`
- Symbols: `SPY VOO QQQ DIA IWM VTI XLF XLK XLE XLI`
- TOM months used: `12`
- Cost: `8 bps` round trip

## Baseline (all 12 months)

Locked config pooled monthly TOM net series:

- mean net: `+0.3090%/mo`
- Sharpe: `0.383`
- t-stat: `1.269`

Already non-significant and underpowered.

## LOOMO fragility results

When dropping one month at a time (`n=11` each):

- mean range: `+0.1219%/mo` to `+0.4127%/mo`
- Sharpe range: `0.226` to `0.541`
- t-stat range: `0.714` to `1.710`

Most influential dropped months (by mean shift):

- drop `(2025,12)`: mean falls to `+0.1219%/mo`, Sharpe `0.226`, t `0.714`
- drop `(2025,10)`: mean rises to `+0.4127%/mo`, Sharpe `0.541`, t `1.710`
- drop `(2025,7)`: mean rises to `+0.4087%/mo`, Sharpe `0.531`, t `1.679`
- drop `(2026,3)`: mean falls to `+0.2381%/mo`, Sharpe `0.295`, t `0.933`

## Interpretation

- The locked TOM estimate is materially sensitive to individual months in this short sample.
- No LOOMO variant reaches convincing significance; all remain below conventional t-thresholds.
- This reinforces that current evidence is not stable enough for promotion or wiring.

## Disposition

- Interim fragility evidence only.
- No activation/wiring changes.
- Candidate remains OPEN for multi-year split-adjusted validation.

## Repro

Executed as cache-only terminal Python against the locked config from prior holdout run.
