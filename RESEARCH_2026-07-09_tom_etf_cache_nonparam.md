# Research: TOM nonparametric continuation (same cache)

**Date:** 2026-07-09  
**Author:** GitHub Copilot (GPT-5.3-Codex)  
**Status:** INTERIM / UNDERPOWERED (nonparametric check)

## Objective

Add a stricter small-sample robustness layer for the same TOM setup by reducing distributional assumptions:

- exact two-sided sign test on pooled monthly TOM net returns
- bootstrap 95% CI for monthly mean net return

This is continuation evidence only, not a promotion gate pass.

## Data and setup

- Source: `salehman_history_cache.json`
- Cache span: `2025-07-07` to `2026-07-08`
- Symbols: `SPY VOO QQQ DIA IWM VTI XLF XLK XLE XLI`
- Costs: `8 bps` round trip
- Sweep universe: entry offsets `{-2,-1}`, exit offsets `{+3,+4}`
- Locked config from prior holdout step: `(-1,+3)`
- Sample length: `n=12` pooled month-level observations

## Results

### Locked config `(-1,+3)`

- mean net: `+0.3090%/mo`
- median net: `+0.2548%/mo`
- sign test (two-sided): `p = 0.3877` (`8` positive, `4` negative)
- bootstrap 95% CI (mean): `[-0.1227%, +0.8068%]`

Interpretation: non-significant sign balance and CI includes zero.

### Best-by-mean config on same sweep `(-2,+3)`

- mean net: `+0.5738%/mo`
- median net: `+0.5914%/mo`
- sign test (two-sided): `p = 0.7744` (`7` positive, `5` negative)
- bootstrap 95% CI (mean): `[-0.1502%, +1.4037%]`

Interpretation: despite higher sample mean, nonparametric tests remain non-significant and CI includes zero.

### Full sweep snapshot

- `(-2,+3)`: sign `p=0.7744`, boot95 `[-0.1583%, +1.3756%]`
- `(-2,+4)`: sign `p=0.7744`, boot95 `[-0.5455%, +1.4324%]`
- `(-1,+3)`: sign `p=0.3877`, boot95 `[-0.1142%, +0.8030%]`
- `(-1,+4)`: sign `p=1.0000`, boot95 `[-0.4877%, +0.7906%]`

All CIs include zero.

## Conclusion

- Nonparametric checks agree with prior t-stat / max-t / holdout / LOOMO story.
- Evidence remains underpowered (`n=12`) and non-promotional.
- No wiring or activation changes.
- Candidate remains OPEN pending multi-year, split-adjusted, pre-registered validation.
