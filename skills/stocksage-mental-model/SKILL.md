---
name: stocksage-mental-model
description: How to THINK about the StockSage money engine before touching it — the idea pipeline hop-by-hop, how to use MARKETS_TAB_MAP.md, the frozen nil-contracts, where every number on the idea card/sheet comes from, and the owner-gate registry of decisions you must refuse. Read this BEFORE editing anything under Salehman AI/StockSage/* or the Markets views.
---

# StockSage mental model

Deterministic rules-based advisor, **Deflated Sharpe ≈ 0 — no proven edge; its value is risk-discipline,
not alpha**. Every design choice below serves the honesty floor: nil = unknown (never fabricated),
estimates labeled "assumed", gross vs net always labeled, win-prob only from realized calibration,
signal-strength never shown as P(profit). Engine files: `Salehman AI/StockSage/*.swift`; UI:
`Salehman AI/Views/MarketsView.swift` (~4900 lines) + `MarketsTodayActionsCard.swift`. Build/test via
the `run-salehman-ai` skill; the only test verdict that counts is `** TEST SUCCEEDED **` (per-test
counts fluctuate ±1 from parallel-runner log interleaving — never compare counts, compare the verdict).

## 1. The idea pipeline (one idea, feed → card)

```
StockSageQuoteService (sole network boundary: Yahoo v8 keyless, ToolPolicy-gated, ≤6 sockets)
  └ StockSageQuoteCache (last-good snapshot to App Support — offline board is real data, never sample)
        ↓ OHLCV histories (newest-last)
StockSageStore.refreshIdeas → buildIdeas (pure, Task.detached, 120s watchdog; skips Index class)
        ↓ per symbol
StockSageAdvisor.advise → TradeAdvice: score → conviction=min(|score|,1), action, regime,
  ATR stop (stopMultiple 1.5/2.0/2.5× by vol) + 2:1 target, suggestedWeight (half-Kelly ≤ 0.20)
        ↓ conviction + entry/stop/target
StockSageExpectedValue: winProbEstimate (0.35+0.23·c prior OR calibration.winProb) →
  evR = p·R−(1−p) (rewardR capped 50:1), velocity = EV/day, rank keys with demotion
  sentinels (regime-ban −1M · cost-fail −500k · thin-liquidity −3000 · earnings −2000 · low-conv −1000)
        ↓ gross edge
StockSageNetEdge: defaultCosts by suffix (crypto 70bps / FX 7 / index 8 / intl 30 / US 13) →
  netRR, clearsCost, minNetEVPerDayFloor = 0.005 R/day (demotes, never hides)
        ↓ net edge
StockSageCapitalAllocator.allocate (maxHeat 0.08): cost gate FIRST (no shares for net-negative) →
  StockSageKelly.compute (suggestedFraction = half-Kelly ≤ maxFraction 0.20), then PER-POSITION IN ORDER:
    1. regime bias      weight = Regime.adjustedWeight(...)   (up-bias clipped at cap; down applies fully)
    2. vol-targeting    weight /= ExpectedValue.cryptoRiskScaler(realizedVol)
    3. vol-regime brake weight *= idea.volRegime.sizingMultiplier   (floor 0.25)
    4. correlation      /K de-weight for ≥0.70 cliques (CorrelationCluster)
    5. heat cap         uniform scale so Σ risk ≤ 0.08 → StockSagePositionSizer.size (whole shares)
        ↓ sized plan
StockSageTradeGate.evaluate (via StockSageTodayPlan, NET RR input) → clear / caution / blocked
        ↓
MarketsView ideaCard + ideaDetailSheet · MarketsTodayActionsCard (blocked ⇒ strikethrough DO NOT TRADE)
```

The brake-chain order (1→5) is verified at `StockSageCapitalAllocator.swift` `allocate()` lines ~76–115.
Do not reorder it, and keep the two `.help` strings in MarketsView that enumerate it in sync.

## 2. MARKETS_TAB_MAP.md — the per-file truth

`MARKETS_TAB_MAP.md` (repo root, ~718 lines) has one entry per Markets file:
Purpose / Key symbols / Inputs / Consumers / Invariants / Gotchas, grouped in 9 domains.

- **Before editing ANY StockSage or Markets file, read its map entry first.** The Gotchas are unit-scale
  traps and sentinel semantics that have each already bitten someone.
- **`UNWIRED` means deliberately not called by production** (AllocationOptimizer, Pyramid, ConvictionScaler,
  CompoundingHorizon, RelativeStrength, ScreenAnalysis, MarketsRiskAllocationSection…). Do NOT wire one
  up as a drive-by "improvement" — several are unwired by ablation conclusion or pending owner decision.
- **After materially changing a mapped file, update its entry** (same commit). This is a standing repo rule.
- **Line refs in the map drift** — trust symbol names and re-grep; never trust `file.swift:NNNN` blindly.
  Grep with the CLAUDE.md exclusions: `--glob '!SOURCE_BUNDLE.md' --glob '!External Artifacts/**' --glob '!*_ARCHIVE.md'`.

## 3. Frozen contracts (treat as API)

**`StockSageIndicators` and `StockSageExpectedValue` nil-on-insufficient-data returns are the honesty
floor's foundation.** Grep 2026-07-02: 12 production files consume Indicators, 13 consume ExpectedValue.
Every function is total: nil on short history, never NaN, never a guessed value (`trendOK` nil < 253 bars;
`timeframeConfluence` nil on TSMOM/200DMA disagreement; `ev()` nil without stop+target; `moments()` nil
< 4 points). A caller somewhere renders "nothing" for each of those nils — change a nil to a default and
a fabricated number silently appears on a money surface.

Hard gate for touching either file's nil/guard behavior: run the FULL suite (not just the module's tests),
including `StockSageIndicatorsTests`, `StockSageMathInvariantTests`, `StockSageExpectedValueTests`,
`StockSageAdvisorTests`, and `StockSageBacktestParityTests` (pins backtest-path ≡ live-path decisions),
then grep every consumer file for the changed symbol and re-check each call site's nil handling.

## 4. Where every number on the idea card / sheet comes from

| Displayed figure | Computing symbol | Gross/net | Label duty |
|---|---|---|---|
| Price | QuoteService/QuoteCache via Store | — | feed banner states live / cached / sample |
| Action badge | `TradeAdvice.action` | — | +0.5→strongBuy but −0.5→**reduce** (long-side bias, F34) |
| Signal strength N/100 (card: conviction meter) | `conviction = min(\|score\|,1)` | — | "rules-based score, not a win probability" |
| Est. EV | `ExpectedValue.ev → evR` | **GROSS** — "(gross)" tag | calibrationChip must sit adjacent |
| Win est. | `winProbEstimate` (prior band `assumedWinBandLabel` "35–58%", or `calibration.winProb`) | — | chip: "win% assumed" / "win% measured · n=X" |
| Velocity R/day | `velocity()` = EV/day | **GROSS** — "R/day gross"; net R/day shown beside when `netVelocity` non-nil | sort key is a DIFFERENT quantity (§5) |
| R:R | `StockSageRewardRisk.assess` | **GROSS** — "gross" in note | net R:R separately via `NetEdge.netRR`; "Net" label ONLY when netRR resolved (`rrIsNet`) |
| Entry/Stop/Target | Advisor `stopTarget` (ATR-tiered stop, 2:1 target) | — | `adaptivePrice` (2/4/6 dp) — duplicated in 3 files, keep in sync |
| Base size % | `advice.suggestedWeight` (half-Kelly ≤ 0.20) | — | stored 0–1, displayed ×100 |
| Regime size / Vol-adj | `Regime.adjustedWeight` / `× volRegime.sizingMultiplier` | — | Vol-adj shown only < 0.85; help must state "Deploy plan is authoritative" |
| Shares · $ at risk | `StockSagePositionSizer.size` | — | riskFraction 0–1 IN, `pctOfAccount` 0–100 OUT |
| Gate verdict | `StockSageTradeGate.evaluate` (net RR in) | NET input | blocked ⇒ strikethrough + "DO NOT TRADE" |
| Est./week R and $ | `expectedWeeklyR/Dollars` (0.70× concentration haircut) | **GROSS** (netting is owner-gated F03) | heavy caveat, never a promise |

## 5. Gotchas (each one already bit a session)

- **momentumQuality's neutral sentinel is 1.0, and it must never render.** The engine function returns
  **1.0** ("no computable signal → no penalty") when closes ≤ 20 bars. 1.0 ≥ 2/3 = the "hot" green dot.
  Two guards prevent that: Store only computes it when `closes.count > 20` (else the idea field is nil),
  and the views render NOTHING for nil. Wiring a new surface? Replicate BOTH guards or no-data renders "hot".
- **A calibration object existing ≠ measured win-probs.** Three traps: (a) `store.convictionCalibration`
  is nil until a journal fit succeeds or the owner taps Run on the Strategy backtest — until then every
  win-prob is the assumed 0.35–0.58 prior; (b) the "win% measured" chip keys solely on `!= nil`, but the
  iter7 selector can return an **identity** fit (`winProb(c) = c` — conviction passed through, F01/F02,
  owner-gated); (c) every EV/ranking function defaults `calibration: = nil` — forget to thread
  `store.convictionCalibration` at a new call site and that surface silently reverts to the assumed prior.
- **Velocity ranking is net-adjusted; the displayed R/day is gross-labeled.** `velocityRankKey` (hidden
  sort: log-growth at half-Kelly × net/gross ratio, demotion sentinels) and `velocity()` (displayed: gross
  EV/day) are intentionally different quantities. The "(gross)" label IS the honesty mechanism — do not
  "fix" the mismatch by netting the display or ranking on the displayed number (F03-adjacent, owner-gated).
- **The 50:1 rewardR cap protects the sentinel bands.** Remove it and a hair-thin stop inflates EV past
  −1,000,000, letting a regime-BANNED idea rank #1.
- **Unit-scale traps:** `annualizedVolatility` returns a FRACTION (0.20) but `returnOverPeriod` a PERCENT
  (20); `DrawdownScenario.drawdownPct` fraction vs `UnderwaterCurve.maxDrawdown` percent; `heatPct` and
  `totalHeat` fractions ×100 at display. Check the map entry's Gotchas before mixing any two.

## 6. Owner-gate registry — REFUSE, don't flag-and-do

These are open product decisions. Implementing any of them "while you're in there" — even correctly —
overrides the owner. Response: name the gate, cite the doc, stop.

| Gate | What you must NOT do | Where it's recorded |
|---|---|---|
| RANKING #10 | Flip `bestOpportunity` default to `preferVelocity: true` (shipped strictly opt-in) | `RANKING_BACKLOG.md` #10 |
| F01/F02 | Pick identity-calibration semantics (nil-the-thin-branch vs provenance marker vs clamp ≤ prior) | `AUDIT_2026-07-02_ideas_board.md` §5.1 |
| F03/F44 | Net the weekly headline (`expectedWeeklyR/Dollars`) vs label it — either change | audit §5.2 |
| F08/F21 | Choose the canonical term "Conviction" vs "Signal strength" and sweep it | audit §5.4 |
| F10 | Change decimal-comma parsing in `StockSageInput.clean` (Saudi locale policy) | audit §5.3 |

## 7. Exit checklist for any StockSage change

1. Full suite green — `.claude/skills/run-salehman-ai/driver.sh test`; accept ONLY `** TEST SUCCEEDED **`.
2. `bash tools/bundle_source.sh` (never Read `SOURCE_BUNDLE.md` — ~530k tokens).
3. Dated `DEVELOPMENT_LOG.md` entry ABOVE the "Standing notes" anchor (Grep the anchor, don't Read the file).
4. Update the touched file's `MARKETS_TAB_MAP.md` entry if the change was material.
5. `git add` by name — never `git add -A`. Leave `tools/test_grok_bridge.py` (untracked) and
   `PROJECT_CONTEXT.md` (may be dirty from another session) untouched. Merges to main: fast-forward only;
   self-hosted CI runs on push (`gh` at `/opt/homebrew/bin/gh`).
