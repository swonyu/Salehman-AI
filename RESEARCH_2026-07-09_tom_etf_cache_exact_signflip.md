# Research: TOM exact sign-flip continuation (same cache)

**Date:** 2026-07-09  
**Author:** GitHub Copilot (GPT-5.3-Codex)  
**Status:** INTERIM / UNDERPOWERED (exact randomization)

## Objective

Run an exact randomization layer on the same pooled month-level TOM returns (12 months):

- exact two-sided sign-flip test for the monthly mean (locked and best configs)
- exact family-wise (FWER) sign-flip test on max absolute mean across the 4 sweep configs

This removes asymptotic approximation and uses finite-sample enumeration (`2^12` sign patterns).

## Setup

- Source: `salehman_history_cache.json`
- Cache span: `2025-07-07` to `2026-07-08`
- Symbols: `SPY VOO QQQ DIA IWM VTI XLF XLK XLE XLI`
- Sweep: entry `{-2,-1}`, exit `{+3,+4}`
- Cost: `8 bps` round trip
- Locked config from prior holdout: `(-1,+3)`
- Best-by-mean in this sweep: `(-2,+3)`

## Exact results

- months: `n=12`
- locked `(-1,+3)`:
  - observed mean: `+0.3090%/mo`
  - exact sign-flip two-sided `p = 0.243652`
- best-by-mean `(-2,+3)`:
  - observed mean: `+0.5738%/mo`
  - exact sign-flip two-sided `p = 0.190430`
- family-wise across all 4 configs (max `|mean|` statistic):
  - observed max `|mean| = 0.5738%/mo`
  - exact FWER `p = 0.324219`

## Interpretation

- Exact finite-sample tests do not support significance at conventional levels.
- After explicit family-wise adjustment over the 4-config sweep, evidence weakens further.
- This is consistent with prior max-t / holdout / LOOMO / nonparametric caution.

## Disposition

- Still underpowered and non-promotional.
- No wiring or activation changes.
- Candidate remains OPEN for multi-year powered validation.
