---
name: stocksage-engine
description: Knowledge + build/test for the StockSage deterministic trading engine in Salehman AI (Swift 6 / macOS). Use when working on anything under StockSage/* — the advisor scoring, conviction/EV/velocity, calibration, backtester, or position sizing. Captures the architecture, the honesty floor, the lean current state, and the verified ground-truth facts so you reason from truth, not memory.
---

# StockSage engine

A deterministic, rules-based stock advisor (the "Ideas card"). **Deflated Sharpe ≈ 0 — no statistically proven edge.** Its value is **risk-discipline, not alpha**. Honesty floor: never surface a number, badge, conviction %, or win-rate that isn't computed from real data — a tool that overstates confidence is worse than none.

## Scoring — `advise()` in `StockSageAdvisor.swift`
Additive `score` (~ −1…+1). A **trend family** is summed, then × a variance-scalar (`targetVol 0.20 / realizedVol`, ≤1), then **hard-capped at 0.65**:
- trend ±0.40 (price>50DMA>200DMA) · ±0.15 partial (vs 200DMA) · ±0.20 lite (50DMA only)
- momentum ±0.15 (6-mo) · MACD ±0.10 · vol-adjusted-momentum ±0.05
- relative-strength ±0.08 — **GATED OFF** (`relativeStrengthEnabled = false`, parsimony cut 2026-06-27; code preserved, flip to re-enable)
- volume-confirmation ±0.05 — **REMOVED** (parsimony cut 2026-06-27)

Outside the cap: RSI nudges (±0.25 non-trending / ±0.10 trending) + 52-week-high proximity (up to +0.01). `conviction = min(|score|, 1)` — a signal-strength ordinal, NOT a probability. Sizing: **half-Kelly 0.5×**, `maxWeight 0.20`, `riskPerTrade 0.01`.

## Calibration — `StockSageConvictionCalibration.swift`
conviction→win-prob map. `convictionCalibration = fit(fromJournal:) ?? backtestConvictionCalibration`; nil → conservative prior `0.35 + 0.23·conviction`. **iter7 candidate-selector** ({identity, Beta-3param Kull2017, isotonic}, OOS-Brier-selected on a leak-free chronological split, identity-floored) is **active** via `candidateSelectorEnabled` — it never applies a calibration that isn't out-of-sample better than no-calibration.

## Honesty reads, surfaced in the idea "Why"
- `StockSageReturnShape` (#4): downside-skew / left-tail — "worst days exceed what its vol implies; your stop may gap."
- `StockSageVolStability` (#5): vol-of-vol — "whippy volatility; sizing inputs less reliable, trade smaller."
Both **honesty-only** (no sizing change), **flag-only** (appended to rationale only when the flag fires).

## Build / test
Canonical (leave it green): `xcodebuild -scheme "Salehman AI" -destination 'platform=macOS' -configuration Debug CODE_SIGNING_ALLOWED=NO build` and `… test -only-testing:"Salehman AITests"`. Pipe `2>&1 | tee /tmp/log | tail -25` (verdict is in the tail). New `.swift` files auto-compile (synchronized group).
**Concurrent sessions:** build in an isolated git worktree with `-derivedDataPath <worktree>/.dd` so you never corrupt another session's DerivedData. Never run 2 xcodebuilds on the same DerivedData.

## Locked constraints
Deterministic / no ML · half-Kelly 0.5× · Saudi-first (`2222.SR` first) · honesty-floor (no guaranteed-profit language). **NEVER read `SOURCE_BUNDLE.md`** (~530k tokens). Reason from `GROUND_TRUTH.md` (if present) or the real `StockSage/*` files + cite `file:line` — never guess a symbol or a number.
