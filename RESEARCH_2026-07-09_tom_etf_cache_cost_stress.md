# Research: TOM transaction-cost stress continuation (same cache)

**Date:** 2026-07-09  
**Author:** GitHub Copilot (GPT-5.3-Codex)  
**Status:** INTERIM / UNDERPOWERED (cost sensitivity)

## Objective

Stress TOM evidence against higher round-trip costs on the same cache and same config universe.

## Setup

- Source: `salehman_history_cache.json`
- Cache span: `2025-07-07` to `2026-07-08`
- Symbols: `SPY VOO QQQ DIA IWM VTI XLF XLK XLE XLI`
- Locked config: `(-1,+3)`
- Best-by-mean config at 8 bps baseline: `(-2,+3)`
- Cost grid tested: `0, 8, 16, 24 bps` round trip
- Sample length: `n=12` pooled month-level observations

## Results

### Locked config `(-1,+3)`

- `0 bps`: mean `+0.3890%/mo`, t `1.598`, sign `p=0.146`, boot95 `[-0.0448%, +0.8931%]`
- `8 bps`: mean `+0.3090%/mo`, t `1.269`, sign `p=0.3877`, boot95 `[-0.1188%, +0.7905%]`
- `16 bps`: mean `+0.2290%/mo`, t `0.940`, sign `p=0.3877`, boot95 `[-0.1922%, +0.7165%]`
- `24 bps`: mean `+0.1490%/mo`, t `0.612`, sign `p=1.0000`, boot95 `[-0.2694%, +0.6366%]`

### Best-by-mean config `(-2,+3)`

- `0 bps`: mean `+0.6538%/mo`, t `1.600`, sign `p=0.7744`, boot95 `[-0.0625%, +1.4653%]`
- `8 bps`: mean `+0.5738%/mo`, t `1.404`, sign `p=0.7744`, boot95 `[-0.1498%, +1.3851%]`
- `16 bps`: mean `+0.4938%/mo`, t `1.209`, sign `p=0.7744`, boot95 `[-0.2261%, +1.2861%]`
- `24 bps`: mean `+0.4138%/mo`, t `1.013`, sign `p=0.7744`, boot95 `[-0.3066%, +1.2246%]`

## Interpretation

- Cost increases monotonically degrade mean/t-stat as expected.
- Across tested costs, inference remains weak: sign tests non-significant and CIs cross zero.
- No cost level rescues a promotion-grade conclusion in this short sample.

## Disposition

- Underpowered and non-promotional.
- No wiring/activation changes.
- Candidate remains OPEN pending larger-horizon powered evaluation.
