---
name: stocksage-mental-model
description: How to THINK about and work on the StockSage money engine — the idea pipeline hop-by-hop, how to use MARKETS_TAB_MAP.md, the frozen nil-contracts, where every number on the idea card/sheet comes from, the advisor scoring weights, the conviction→win-prob calibration selector, the locked engine constraints, and the pointer to the owner-gate registry. Use when editing ANYTHING under Salehman AI/StockSage/* — advisor scoring, conviction/EV/velocity, calibration, backtester, position sizing — or the Markets views. Read this BEFORE touching either. (Absorbs the former stocksage-engine skill, merged 2026-07-02.)
---

# StockSage mental model (+ engine internals)

Deterministic rules-based advisor, **Deflated Sharpe ≈ 0 — no proven edge; its value is risk-discipline,
not alpha**. (Deflated Sharpe = Sharpe ratio corrected for multiple-testing/data-snooping.) Every design
choice below serves the honesty floor: nil = unknown (never fabricated), estimates labeled "assumed",
gross vs net always labeled, win-prob only from realized calibration, signal-strength never shown as
P(profit). Engine files: `Salehman AI/StockSage/*.swift`; UI: `Salehman AI/Views/MarketsView.swift`
(one very large file — navigate it by grepping SYMBOL NAMES, never by remembered line numbers) +
`MarketsTodayActionsCard.swift`. Build/test via the `run-salehman-ai` skill; the only test verdict that
counts is `** TEST SUCCEEDED **` (per-test counts fluctuate from parallel-runner log interleaving —
gate on the verdict line, never on counts).

**When NOT to use this skill:** build/run/screenshot mechanics → `run-salehman-ai`; landing a finished
change → `shipping-changes`; pixel-level UI verification → `visual-qa`; proposing a ranking/signal
change → read `research-memory` first (validation gate); writing tests → `testing-discipline`.

Jargon used below, once: **R** = one risk unit (entry→stop distance); **ATR** = Average True Range;
**DMA** = daily moving average; **12-1 trend** = 12-month return skipping the most recent month
(TSMOM = time-series momentum); **half-Kelly** = half the Kelly-optimal bet fraction; **OOS** =
out-of-sample; **Brier score** = mean squared error of probability forecasts (lower = better);
**Wilson-LCB** = Wilson lower confidence bound (a conservative haircut on a measured rate).

## 1. The idea pipeline (one idea, feed → card)

```
StockSageQuoteService (sole network boundary: Yahoo v8 keyless, ToolPolicy-gated, concurrency ≤ 6 sockets)
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
  netRR, clearsCost; `minNetEVPerDayFloor` 0.005 R/day (constant lives in `StockSageExpectedValue`)
  demotes, never hides
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

The brake-chain order (1→5) lives inside `StockSageCapitalAllocator.allocate()` — anchor by SYMBOL,
not line number: grep that file for `adjustedWeight`, `cryptoRiskScaler`, `sizingMultiplier`,
`correlationAdjustedWeights` and confirm they appear in that order (verified 2026-07-02).
Do not reorder it, and keep the help-string copies in MarketsView that enumerate it in sync
(grep `"correlation de-weighting"` — currently `sizeMetricHelp` + two `.help` modifiers).

## 2. MARKETS_TAB_MAP.md — the per-file truth

`MARKETS_TAB_MAP.md` (repo root) has one entry per Markets file:
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
`timeframeConfluence` nil on TSMOM/200DMA disagreement; `ev()` nil without stop+target; same convention
engine-wide, e.g. `moments()` in `StockSageDeflatedSharpe.swift` nil < 4 points). A caller somewhere renders "nothing" for each of those nils — change a nil to a default and
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
  win-prob is the assumed 0.35–0.58 prior; (b) the "win% measured" chip must key on the calibration
  `.method`, never merely on `!= nil`, because the iter7 selector can return an **identity** fit that is
  not a real measurement — the OOS-validated identity winner (n≥44) passes conviction through
  (`winProb(c) ≈ c`), the THIN-split identity (n∈[30,43]) is clamped to the prior (`min(c, prior)`,
  F01 CLOSED 2026-07-04 `64b1725`), and BOTH must render "assumed" (F02); (c) every EV/ranking function
  defaults `calibration: = nil` — forget to thread
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

Several product decisions are open and OWNER-HELD (example: RANKING #10, flipping `bestOpportunity`'s
default to `preferVelocity: true`). Implementing any of them "while you're in there" — even correctly —
overrides the owner. **The live registry — which decisions are gated, what each forbids, and where each
is recorded — lives ONLY in the `gated-scope` skill, "How" step 1 (marked CANONICAL REGISTRY).** Read it
before planning any StockSage change. It is deliberately NOT restated here: a copy is a divergence
waiting to happen. Response on hitting a gate: name the gate, cite its recording doc, stop.

## 7. Engine internals — scoring weights, calibration selector, locked constraints

*(Absorbed from the retired `stocksage-engine` skill; every constant below re-verified against
`StockSageAdvisor.swift` + `StockSageConvictionCalibration.swift` at HEAD, 2026-07-02.)*

**Grep the source first — this section is a map, not the territory** (F46: an index said a flag was off
while the shipped Swift default said on; the shipped default wins). Re-verification one-liners are in
"Provenance and maintenance" below.

### 7.1 Scoring — `advise()` in `Salehman AI/StockSage/StockSageAdvisor.swift`

`score` is additive (roughly −1…+1). The correlated **trend family** is summed first, then
post-processed (they all measure ONE trend factor — summing them as independent inflates conviction):

| Term (trend family) | Weight | Notes |
|---|---|---|
| Trend triad (price > 50DMA > 200DMA) | ±0.40 | ±0.15 when only price-vs-200DMA resolves; ±0.20 "lite" with < 200 bars (50DMA only) |
| Momentum | ±0.15 | 126-bar (~6-month) lookback; shorter histories use the true shorter window and say so in the rationale |
| MACD histogram | ±0.10 | confirmation — deliberately lighter than momentum (most redundant with the 0.40 term) |
| Vol-adjusted momentum | ±0.05 | needs highs/lows (ATR); fires only when \|vam\| ≥ 5 |
| Relative strength vs benchmark | ±0.08 | **GATED OFF**: `relativeStrengthEnabled = false` (parsimony cut 2026-06-27; null ablation `RESEARCH_2026-07-02_confluence_rs_ablation.md`). Code preserved; it is a `var` so a test can flip it |
| Volume confirmation | — | **REMOVED** 2026-06-27 (parsimony cut, owner-ratified) |

Family post-processing, in order (both inside `advise()`):
1. **× variance scalar** — `varianceScalar` = min(1, `varianceScalarTargetVol` 0.20 / realizedVol).
   Attenuation-only: calm never amplifies; missing/NaN/≤0 vol → 1.0 (no-op).
2. **Re-cap at `trendFamilyCap` 0.65** applied to the POST-scaled family.

OUTSIDE the family (independent terms — un-scaled, un-capped):
- **RSI**: range regime → oversold +0.25 ONLY when `oversoldBounceIsBuyable` (intact 12-1 uptrend;
  an oversold falling knife gets NO credit), overbought −0.25. Trending regime → RSI > 80 −0.10,
  RSI < 20 +0.10. (Regime split: `efficiencyRatio ≥ 0.30` = trending.)
- **52-week-high proximity**: max +0.010 = `highProximityWeight` 0.10 × (pth − `highProximityNeutralAnchor`
  0.90), pth clamped ≤ 1. Long-side-only (never subtracts), zeroed in a bearTrend regime, disabled
  entirely without real highs.

Then: `conviction = min(|score|, 1)` — a signal-strength ordinal, NOT a probability. Action mapping is
`actionForScore` (single source of truth): ≥ +0.5 strongBuy (inclusive) but −0.5 lands in `.reduce`,
not `.sell` — a deliberate long-side asymmetry (F34: shorts carry financing cost + unbounded loss).
Do not mirror the boundaries. Sizing constants: `riskPerTrade` 0.01, `maxWeight` 0.20 (mirrors
`StockSageKelly.maxFraction`), half-Kelly = f*/2. Stops: `stopMultiple(forVol:)` → 2.5×ATR at vol ≥ 0.70,
2.0× at ≥ 0.40, 1.5× below, and 2.0× when vol is nil/NaN (the honest neutral default).

### 7.2 Calibration — `StockSageConvictionCalibration.swift`

- **Runtime chain**: `StockSageStore.convictionCalibration` = journal fit (cached) `??`
  `backtestConvictionCalibration`; both nil → the linear prior `0.35 + 0.23·conviction` in
  `StockSageExpectedValue.winProbEstimate` (displayed band: `assumedWinBandLabel` "35–58%").
- **iter7 candidate-selector is ACTIVE**: `candidateSelectorEnabled = true` (owner-activated 2026-06-27).
  `selectCalibration` fits candidates {identity, Beta-3param (Kull et al. 2017), isotonic} on a
  chronological TRAIN split, scores them by OOS Brier on TEST, and refits the winner on ALL data.
  Identity wins ties (a candidate must beat it by > 1e-9) and is the only option when the sample is
  too thin to split honestly.
- **F01 CLOSED 2026-07-04 (`64b1725`, owner-approved clamp) — the thin-vs-OOS split now matters:**
  the **OOS-validated** identity winner (n≥44, empirically selected) passes conviction through
  (`winProb(c) ≈ c`), which EXCEEDS the nil-calibration prior for conviction ≳ 0.45 — acceptable because
  it is OOS-selected, not an unvalidated fallback (still renders "assumed", F02). The **thin-split**
  identity (n∈[30,43], no OOS validation) is now CLAMPED to the prior —
  `winProb = min(c, priorWinProb(c))` via `buildIdentity(clampToPrior:)` — so it is genuinely
  conservative (≤ prior everywhere; the old c ≳ 0.45 inversion is gone) and only ever lowers, never
  promotes an idea. Both prior paths route through the single `StockSageExpectedValue.priorWinProb(_:)`
  (F46 anti-drift). No longer owner-gated (the earlier F01/F43 note flagged the inversion; the clamp fixed it).
- **Provenance field**: `Method` enum {isotonicWilson, beta, platt, identity}. UI honesty wording keys
  on `.method`, never on `calibration != nil`; identity must always render "assumed" (see §5 trap b).
- **Flag-off legacy seam** (regression-locked by `flagOffIsByteIdenticalToCurrent`): below
  `isotonicMinSamples` 1000 → Platt sigmoid (central MLE, NOT conservative); at/above → Wilson-LCB +
  isotonic (measured AND conservative).

### 7.3 Honesty reads surfaced in the idea "Why" (flag-only, no sizing effect)

`StockSageReturnShape` (left-tail/skew: "worst days exceed what its vol implies; your stop may gap")
and `StockSageVolStability` (vol-of-vol: "whippy volatility; sizing inputs less reliable") append a
⚠ note to the rationale ONLY when the flag fires. Neither changes sizing — the vol-REGIME brake
(§1 step 3) is the one that does.

### 7.4 Locked constraints

Deterministic, no ML · half-Kelly 0.5× — never raise it (research-memory: verified decision) ·
Saudi-first (Aramco `2222.SR` stays first in the `StockSageQuoteService` universe) · honesty floor
(header of this skill) · reason from the real `StockSage/*.swift` files and cite symbols — never guess
a number, and NEVER Read `SOURCE_BUNDLE.md` (~530k tokens; regenerate it, don't read it).

### 7.5 Build/test for engine work

Use the `run-salehman-ai` skill (canonical commands, driver, verdict lines). One addition for
concurrent sessions: build in an isolated git worktree with its own `-derivedDataPath` — never run
two xcodebuilds against the same DerivedData.

## 8. Exit checklist for any StockSage change

1. Full suite green — `.claude/skills/run-salehman-ai/driver.sh test`; accept ONLY `** TEST SUCCEEDED **`.
2. `bash tools/bundle_source.sh` (never Read `SOURCE_BUNDLE.md` — ~530k tokens).
3. Dated `DEVELOPMENT_LOG.md` entry ABOVE the "Standing notes" anchor (Grep the anchor, don't Read the file).
4. Update the touched file's `MARKETS_TAB_MAP.md` entry if the change was material.
5. `git add` by name — never `git add -A`. Leave `PROJECT_CONTEXT.md` untouched (may be dirty from
   another session). `tools/test_grok_bridge.py` is TRACKED since 713064e (2026-07-02) — treat it like
   any other tracked file; the old "leave it untracked" rule is obsolete. Merges to main: fast-forward
   only; self-hosted CI runs on push (`gh` at `/opt/homebrew/bin/gh`).

## Provenance and maintenance

Merged from the former `.claude/skills/stocksage-engine/` skill on **2026-07-02**; every constant above
was re-verified against HEAD that day (the engine skill's dead `GROUND_TRUTH.md` reference was dropped —
the file does not exist). This skill is a map; the source is the territory (F46). Re-verify before
relying on any fact here:

```bash
cd /Users/saleh/ai
# Scoring weights, family cap, sizing constants, flags (expect ±0.40/0.15/0.20/0.15/0.10/0.05/0.08; cap 0.65; RS false)
grep -n 'score += 0\|score -= 0\|trendFamilyCap =\|relativeStrengthEnabled =\|riskPerTrade =\|maxWeight =\|varianceScalarTargetVol =\|highProximityWeight =\|highProximityNeutralAnchor =' "Salehman AI/StockSage/StockSageAdvisor.swift"
# Action thresholds + stop multiples
grep -n 'case 0.5\|case 0.2\|case -0.2\|case -0.5\|return 2.5\|return 2.0\|return 1.5' "Salehman AI/StockSage/StockSageAdvisor.swift"
# Calibration selector flag + isotonic seam (expect true, 1000)
grep -n 'candidateSelectorEnabled =\|isotonicMinSamples =' "Salehman AI/StockSage/StockSageConvictionCalibration.swift"
# Nil-calibration prior, band label, net-EV floor, rank sentinels
grep -n '0.35 + \|assumedWinBandLabel\|minNetEVPerDayFloor =\|1_000_000\|500_000' "Salehman AI/StockSage/StockSageExpectedValue.swift"
# Cost table by suffix (expect 70/7/8/30/13 bps)
grep -n 'CostAssumption(spreadBps' "Salehman AI/StockSage/StockSageNetEdge.swift"
# Brake-chain symbol order (expect adjustedWeight → cryptoRiskScaler → sizingMultiplier → correlationAdjustedWeights)
grep -n 'adjustedWeight\|cryptoRiskScaler\|sizingMultiplier\|correlationAdjustedWeights' "Salehman AI/StockSage/StockSageCapitalAllocator.swift"
# Calibration runtime chain
grep -n 'convictionCalibration' "Salehman AI/StockSage/StockSageStore.swift"
# Tracked-file rule (non-empty output ⇒ tracked)
git ls-files tools/test_grok_bridge.py
# Owner gates: open skills/gated-scope/SKILL.md, "How" step 1 (CANONICAL REGISTRY)
```

Standing drift rules: gate on the verdict line (`** TEST SUCCEEDED **` / `** BUILD SUCCEEDED **`),
never on test counts or universe sizes — they drift by design. Quote symbol names, not line numbers,
for anything in `MarketsView.swift` or `MARKETS_TAB_MAP.md`.
