---
name: stocksage-flags-and-config
description: The config-and-flags catalog for the StockSage engine in Salehman AI — every live engine flag with its ratified default and ratifying doc, the byte-identical-default params that are de-facto flags, the deliberately-UNWIRED module registry (and WHY each is unwired), the @AppStorage keys that fake bugs across sessions, and the checklist for adding a new flag. Use when asked whether a StockSage feature is on/off, before flipping/adding/wiring any flag or default, when a doc and the code disagree about a default, when the ideas board "looks broken" after a restart, or before activating an unwired module.
---

# StockSage flags & config — what's on, what's off, and why

**Grep the source; this table is a map, not the territory.** Shipped Swift defaults win
over ANY doc claim — including this file. The one time the repo trusted a doc over the
code, it was wrong (see the F46 rule below). Before relying on any flag state here, run
its re-verification command (each section carries one; all are collected at the end).

Definitions used throughout:
- **Flag** — a mutable `static var` on an engine type that gates a code path at runtime.
- **Ratified default** — a default value the owner (or an empirical ablation) explicitly
  decided; changing it is a product/engine decision, not a cleanup.
- **Byte-identical default** — a function parameter whose default value makes the function
  behave exactly as it did before the parameter existed; every caller that omits it gets
  the old behavior byte-for-byte.
- **UNWIRED** — code that exists, builds, and is tested, but is deliberately never called
  by production code (only by its tests). A decision, not an omission.

**When NOT to use this** — for how the idea pipeline works hop-by-hop, use
`stocksage-mental-model` instead; for the owner-gate registry (which decisions you must
refuse), the canonical list lives in `gated-scope` "How" step 1 — this skill only points
at it, never restates it; for landing a flag change, use `shipping-changes`.

## 1. Live engine flags (mutable static vars)

Enumerate them — never work from a remembered list:

```bash
grep -rn "nonisolated(unsafe) static var" "Salehman AI/StockSage/"
```

As of 2026-07-02 that grep returns exactly two. Gate on the grep output, not this table.

| Flag | Shipped default | Lives in | Gates | Ratified by |
|---|---|---|---|---|
| `StockSageAdvisor.relativeStrengthEnabled` | `false` | `StockSageAdvisor.swift` (declaration doc-comment block above it) | The ±0.08 benchmark-relative nudge inside `advise` — skipped entirely when off | Parsimony cut 2026-06-27 (commit `6ae1e4f`: DSR=0, partly redundant with the absolute trend term) + null ablation `RESEARCH_2026-07-02_confluence_rs_ablation.md` (no significant edge at any horizon) |
| `StockSageConvictionCalibration.candidateSelectorEnabled` | `true` | `StockSageConvictionCalibration.swift` (declaration doc-comment block) | The iter7 OOS candidate-selector in `fit(_:)` — picks {identity, Beta-3param, isotonic} by out-of-sample Brier score | Shipped OFF in commit `d9c62d5`, owner-ACTIVATED 2026-06-27 in commit `3b40058`; recorded in `research/INDEX.md` ("UPDATE 2026-06-27 (owner-approved)") |

Facts that matter when touching these:

- Both are `var` (not `let`) **on purpose**: a test may temporarily flip one to prove the
  gated path still works, then MUST reset it (use `defer`). Tests run in parallel — a
  leaked flip poisons other tests.
- `relativeStrengthEnabled`'s gated code is PRESERVED, not dead: flip to `true` to restore
  the exact prior behavior. If ever revived, the declaration comment says to consider a
  local TASI/sector benchmark instead of the S&P (Saudi-first app).
- `candidateSelectorEnabled = false` restores the byte-identical pre-iter7 Platt/isotonic
  seam — regression-locked by the test `flagOffIsByteIdenticalToCurrent` in
  `StockSageCalibrationSelectorTests.swift`. With the flag on, the identity conservative
  floor still yields byte-identical output whenever the OOS selector picks identity.
- KNOWN in-file drift: an inline comment at the `if candidateSelectorEnabled` gate in
  `fit(_:)` still reads "default OFF" from the pre-activation era. The **declaration**
  (`= true`) is the truth. Same lesson as F46, one file over.

Do not confuse `relativeStrengthEnabled` (advisor flag: ONE symbol vs the S&P benchmark)
with `StockSageRelativeStrength` (unwired module: cross-sectional rank of ideas against
each other — §4). The module's own header calls out the distinction.

## 2. Store-level runtime toggle (not persisted)

`StockSageStore.alertsEnabled` — `@Published var alertsEnabled = false` in
`StockSageStore.swift`. Gates the passive crossing-alerts layer (`StockSageAlerts`
appends flip/stop/target events to a capped alert log on each ideas refresh). Toggled by
the user via the switch bound to `$store.alertsEnabled` in MarketsView's Alerts section
(anchor by grepping `alertsEnabled` — the Toggle call has an empty label string, so don't
anchor on the full call). It is a plain `@Published` property, NOT `@AppStorage`: it resets to **off on
every app launch**. "Alerts stopped working after relaunch" is this default, not a bug.

```bash
grep -n "alertsEnabled" "Salehman AI/StockSage/StockSageStore.swift"
```

## 3. Byte-identical-default params — de-facto flags

These are ordinary function parameters, but their defaults are ratified behavior.
**Flipping a default is an engine change, not a param tweak**: every production caller
that omits the argument silently changes behavior, so a default flip needs the same
validation/owner gate as any ranking change (research-memory validation gate; gated-scope
registry for the specific owner-held ones).

| Param | Default | Declared in | What `true` does | Status |
|---|---|---|---|---|
| `preferVelocity` | `false` | `StockSageExpectedValue.bestOpportunity` | Ranks the "best opportunity" by EV/day instead of `qualityAdjustedEVR`, + conviction near-tie break | **OWNER-GATED (RANKING #10)**: shipped opt-in only; flipping MarketsView's default is refused pending the owner — see the canonical registry in `gated-scope` "How" step 1 |
| `preferConfluence` | `false` | `StockSageExpectedValue.bestOpportunity` | Near-tie break preferring three-timeframe-aligned ideas | Opt-in only per its declaration comment ("ship opt-in only") |
| `rrIsNet` | `false` | `StockSageTradeGate.evaluate` | Display-only: relabels the R:R check "Net reward:risk (after est. costs)" | Pass `true` ONLY when `rewardToRisk` is a resolved `StockSageNetEdge.netRR` (non-nil) — never for the `?? gross` fallback, which must stay labeled gross |

Verify no production caller has quietly opted in (all `bestOpportunity` call sites in
`MarketsView.swift` / `TodayView.swift` omit both prefer-params today):

```bash
grep -rn "bestOpportunity(\|preferVelocity\|preferConfluence" "Salehman AI/Views/"
```

Production callers DO pass `rrIsNet:` explicitly (as `resolvedNetRR != nil`) — the
default only protects callers that don't know about costs yet.

## 4. Deliberately-UNWIRED module registry

Confirmed by `MARKETS_TAB_MAP.md` (per-module Consumers lines) and
`AUDIT_2026-07-02_ideas_board.md` §1 "Deliberately UNWIRED (confirmed)". Wiring one of
these into production is an engine change: it needs the research-memory validation gate
(empirical validation or owner sign-off), never a drive-by "hook it up" commit.

| Module (all under `Salehman AI/StockSage/` unless noted) | What it is | WHY unwired |
|---|---|---|
| `StockSageAllocationOptimizer` | Frank-Wolfe mean-variance optimizer | Stretch module (ALLOC_BACKLOG #6) held for future activation; tested, never called |
| `StockSagePyramid` | Livermore-style scale-in ladder | Standalone opt-in calculator by design; main engine never scales in |
| `StockSageKelly` `CostProfile` / `portfolioCap` APIs | Cost-aware Kelly extensions | Tested, no production caller yet |
| `StockSageConvictionScaler` | Conviction-scaled per-trade risk fraction | Needs its own wiring + backtest pass before touching sizing (its source comment says so) |
| `StockSageCompoundingHorizon` | Weekly-return → time-to-double | Ships engine-only before UI wiring (the stated precedent pattern) |
| `StockSageRelativeStrength` | Cross-sectional RS rank of ideas | **Ablation verdict**: 2026-07-02 walk-forward showed no significant edge, mildly negative point estimate (`RESEARCH_2026-07-02_confluence_rs_ablation.md`) — unwired by conclusion, do not promote |
| `StockSageScreenAnalysis` | On-device screen-analysis brain | The only fully-unwired file: singleton exists, nothing calls it; UI plumbing never built |
| `StockSageVolStability.sizingReliability` | Vol-of-vol sizing-reliability score | Computed and surfaced as a rationale note only; wiring into sizing is a **deferred owner decision** (file header) |
| `StockSageIndicators.donchian` / `isBreakout` / `volumeConfirmation` | Channel-breakout + volume primitives | Dormant intent — a continuous distance term subsumed the binary trigger (AUDIT §1) |
| `MarketsRiskAllocationSection` (in `Views/`) | Extracted duplicate of MarketsView's three risk/allocation panels | Only its own `#Preview` instantiates it; wiring deferred to avoid clobbering concurrent MarketsView edits. DIVERGENCE HAZARD: edits to MarketsView's panels must be mirrored here |
| Smaller unwired APIs | `StockSageTrailingStop.recompute` (ratcheted form), `StockSageGapRisk.worstCase`/`fromPosition` | Defined + tested, no production callers |

Proof-of-unwired for any module (empty output = still unwired):

```bash
grep -rn "StockSageConvictionScaler\." --include='*.swift' "Salehman AI/" | grep -v Tests
```

(Substitute the module name. `Salehman AITests/` is a sibling of `Salehman AI/`, so the
search path already excludes the test target; the `grep -v Tests` only filters same-named
helper files inside the app tree.)

## 5. @AppStorage keys that fake bugs across sessions

`@AppStorage` = SwiftUI's UserDefaults-backed property wrapper — these persist across app
relaunches AND across your work sessions. A filter someone set last week makes today's
board "look broken". All Markets keys live in `MarketsView.swift`:

```bash
grep -n "@AppStorage" "Salehman AI/Views/MarketsView.swift"
```

| Key | Declared default | Classic fake-bug symptom |
|---|---|---|
| `marketsIdeaFilter` | `.all` | Board shows ONLY sell/reduce ideas (stuck on Sells) |
| `marketsIdeaMinConv` | `0.0` | Board nearly empty (min-conviction slider left high) |
| `marketsIdeaSort` | `.velocity` | "Ranking changed?" — no, the sort was switched |
| `marketsWatchlistOnly` | `false` | Universe silently shrunk to the watchlist |
| `marketsWatchSort` | `.feed` | Watchlist order "wrong" |
| `marketsFastLaneBoard` | `.both` | Fast-lane board missing a side |
| `velocityCryptoHoldDays` / `velocityEquityHoldDays` | `VelocityHoldDays.defaults` (crypto 3 / equity 12 — re-verify in `StockSageExpectedValue.swift`) | EV/day numbers differ from a fresh install |
| `marketsSizerAccount` / `marketsSizerRiskPct` | `"10000"` / `"1"` | Sizer outputs scaled to a stale account size |

**Reset** (app STOPPED first — a running instance rewrites its state on quit). Bundle id
is `SA.Salehman-AI` (verified in `project.pbxproj`):

```bash
# the four that most often fake a broken board:
for k in marketsIdeaFilter marketsIdeaMinConv marketsIdeaSort marketsWatchlistOnly; do
  defaults delete SA.Salehman-AI "$k" 2>/dev/null
done
```

**NEVER** run a bare `defaults delete SA.Salehman-AI` (whole domain): the same domain
holds real user data — `stocksage_user_symbols` (watchlist additions) and
`stocksage_price_alerts` (user price alerts), both set in `StockSageStore.swift`.
Delete named keys only.

Testing note (from CLAUDE.md): tests run in parallel — never have two tests mutate the
same UserDefaults key.

## 6. The F46 rule

F46 is the audit finding (`AUDIT_2026-07-02_ideas_board.md`, row F46) where
`research/INDEX.md` still said `candidateSelectorEnabled` was "off-by-default" after the
owner had activated it in code. The rule, verbatim from the `research-memory` skill:

> **The INDEX went stale against shipped code once** (F46): it said
> `candidateSelectorEnabled` was "off-by-default" after the owner had activated it.
> Shipped defaults win — verify any INDEX claim about a flag against the actual Swift
> file before relying on it, and fix the INDEX entry when you catch drift (that's
> extending, not re-researching).

Generalized: **shipped Swift defaults win over every doc** — INDEX entries, audit rows,
skill tables (this one included), commit messages, and even stale comments inside the
same source file (§1's "default OFF" inline comment). The declaration line is the only
truth; grep it.

## 7. How to add a flag (checklist)

Pattern proven by commit `d9c62d5` (added `candidateSelectorEnabled`; touched exactly:
`Salehman AI/StockSage/StockSageConvictionCalibration.swift`,
`Salehman AITests/StockSageCalibrationSelectorTests.swift` (new), `DEVELOPMENT_LOG.md`,
`research/INDEX.md`) and commit `6ae1e4f` (added `relativeStrengthEnabled`; touched the
engine file, the parity test file, `DEVELOPMENT_LOG.md`). Reproduce it:

1. **Declare** `nonisolated(unsafe) static var <name> = false` on the owning engine type,
   with a doc comment stating: why it exists, the ratifying doc/decision, and what
   flipping it restores/enables. `var` (not `let`) so tests can flip it — any test that
   flips it resets it with `defer`.
2. **Gate the entire new branch** behind `if <flag>` (or `if Self.<flag>`); the flag-off
   path must be byte-identical — thread existing arguments through UNCHANGED.
3. **Regression-lock both directions** in a new test file: flag-off ⇒ byte-identical to
   pre-flag output (pattern: `flagOffIsByteIdenticalToCurrent`), flag-on ⇒ the gated term
   is demonstrably live (pattern: `negativeControl_benchmarkTermIsLive` in
   `StockSageBacktestParityTests.swift`).
4. **Ship default-OFF.** Activation (`= true`) is a separate, owner-approved commit
   (exemplar: `3b40058`) and MUST update the flag's `research/INDEX.md` entry in the same
   change. `3b40058` itself did not (verified: its stat touches no INDEX file) — that
   omission is exactly how F46 happened; the INDEX was corrected later.
5. **Chores**: dated `DEVELOPMENT_LOG.md` entry; `research/INDEX.md` line if
   research-backed; then the full `shipping-changes` pipeline (bundle regen, MAP entry if
   material, add-by-name, CI). Gate on the verdict lines (`** BUILD SUCCEEDED **` /
   `** TEST SUCCEEDED **`), never on test counts — counts drift.
6. If the flag's natural default would resolve an owner-gated question (registry:
   `gated-scope` "How" step 1), REFUSE the default flip and ship opt-in only.

## Provenance and maintenance

Authored 2026-07-02 against main. Every fact above drifts with the code — re-verify
before relying on it (run from the repo root; these target specific paths, so the
`SOURCE_BUNDLE.md` / `External Artifacts` / `*_ARCHIVE.md` grep exclusions from CLAUDE.md
are not needed here, but ARE needed for any repo-wide grep):

```bash
# §1 engine flags — the complete current set + defaults:
grep -rn "nonisolated(unsafe) static var" "Salehman AI/StockSage/"
# §2 alertsEnabled default + non-persistence:
grep -n "alertsEnabled" "Salehman AI/StockSage/StockSageStore.swift"
# §3 byte-identical defaults still false / callers still opted out:
grep -rn "preferVelocity: Bool\|preferConfluence: Bool" "Salehman AI/StockSage/StockSageExpectedValue.swift"
grep -n "rrIsNet: Bool" "Salehman AI/StockSage/StockSageTradeGate.swift"
grep -rn "bestOpportunity(\|preferVelocity\|preferConfluence" "Salehman AI/Views/"
# §4 a module is still unwired (empty = unwired; swap the name):
grep -rn "StockSageAllocationOptimizer\." --include='*.swift' "Salehman AI/" | grep -v Tests
# §5 AppStorage keys + declared defaults; bundle id for reset commands:
grep -n "@AppStorage" "Salehman AI/Views/MarketsView.swift"
grep -m1 "PRODUCT_BUNDLE_IDENTIFIER" "Salehman AI.xcodeproj/project.pbxproj"
# §7 exemplar commits still say what this skill claims:
git show --stat d9c62d5 | head -30 ; git show --stat 6ae1e4f | head -20
git show --stat --format="" 3b40058 | grep -i "INDEX"   # empty output = §7 step 4's "touches no INDEX file" claim holds
```

If any command's output disagrees with this file: the output wins (F46 rule). Fix this
file in the same pass and log it.
