# Research: TOM pooled max-t trial-control on same cache (strict continuation)

**Date:** 2026-07-09  
**Author:** GitHub Copilot (GPT-5.3-Codex)  
**Status:** INTERIM / UNDERPOWERED (reinforced)

## Purpose

Continue the stricter TOM walk-forward on the same cache with stronger trial accounting than per-symbol heuristics:

- pooled ETF monthly series
- max-over-config test statistic
- permutation null for selection-adjusted p-value

## Dataset (unchanged)

- Source: `salehman_history_cache.json`
- Symbols: `SPY VOO QQQ DIA IWM VTI XLF XLK XLE XLI`
- Cache span: `2025-07-07` to `2026-07-08`
- Common months across symbols/configs: `12`
- Cost: ETF round-trip `8 bps`

## Sweep and trial accounting

- Entry offsets: `{-2, -1}`
- Exit offsets: `{+3, +4}`
- Config count (trials): `4`
- For each config, built pooled equal-symbol-weight monthly TOM net return series.
- Test statistic: max t-stat across the 4 configs.
- Null calibration: random sign-flip permutation by month (paired-null), `B=4000`.

## Results

Per-config pooled series:

- `(-2,+3)`: n=12, mean net `0.005738`, Sharpe `0.423`, t `1.404`
- `(-2,+4)`: n=12, mean net `0.004238`, Sharpe `0.244`, t `0.808`
- `(-1,+3)`: n=12, mean net `0.003090`, Sharpe `0.383`, t `1.269`
- `(-1,+4)`: n=12, mean net `0.001578`, Sharpe `0.140`, t `0.466`

Best config by t/Sharpe: `(-2,+3)`.

Selection-adjusted result:

- observed max-t: `1.404`
- permutation max-t p-value: `0.1725` (B=4000)

Comparator:

- pooled buy-and-hold monthly Sharpe: `0.620`
- best TOM pooled Sharpe: `0.423`
- TOM does **not** beat buy-and-hold Sharpe.

## Interpretation

- After explicit max-over-sweep trial control, the apparent best TOM config is not significant.
- Even before significance gating, risk-adjusted performance trails buy-and-hold in this sample.
- This materially reinforces the prior strict note: still underpowered, no promotion case.

## Disposition

- Keep as interim evidence only.
- No parameter activation, no strategy wiring, no over-claim.
- Candidate remains open for a properly powered multi-year split-adjusted panel run.

## Repro

Executed as terminal Python on the same cache with fixed sweep and permutation max-t accounting.
