# PLAN 2026-07-03 — CALC-QUALITY WAVE 2: turnover/cost honesty, risk-engine correctness, crypto cost honesty, significance gating, concurrency fixes

- **Written against:** HEAD `c807861` (`git rev-parse --short HEAD`), tree clean. Pinned file sizes at this SHA:
  `StockSage/StockSageNetEdge.swift` 178 lines · `StockSageExpectedValue.swift` 977 · `StockSageGapRisk.swift` 79 ·
  `StockSageCapitalAllocator.swift` 394 · `StockSageLossLimit.swift` 103 · `StockSageMonitor.swift` 309 ·
  `StockSageStore.swift` 1198 · `StockSageGlossary.swift` 138 · `Views/MarketsView.swift` 5476.
  Line numbers below are orientation only — **every edit anchors on exact text**; anchor missing or
  non-unique → mismatch → **STOP** (executing-plans rule 1).
- **Execution contract:** `.claude/skills/executing-plans` + `gated-scope` + `spec-fidelity` +
  `testing-discipline`. Read them before Step 1. A step is DONE only when its verification command's
  actual OUTPUT is pasted and proves the behavior fired (WHIPPYX rule).
- **EXECUTION CONTEXT (owner directives):** the implementer (Fable-xhigh — owner override: calculations
  are Fable-only) works in a **git WORKTREE on branch `ideas-card/calc-wave-2`**, never on main:
  ```bash
  cd /Users/saleh/ai && git worktree add ../ai-calc-wave-2 -b ideas-card/calc-wave-2 c807861
  cd ../ai-calc-wave-2
  ```
  Use an isolated DerivedData for every xcodebuild in the worktree: append
  `-derivedDataPath .dd` to EVERY build/test command below (two xcodebuilds on one DerivedData
  corrupt each other — testing-discipline). **After EVERY completed step: WIP-commit by file name**
  (owner durability directive — never lose work to a session limit):
  ```bash
  git add "<each file this step touched, by name>" && git commit -m "wip: calc-wave-2 step <k> — <title>"
  ```
  Never `git add -A` (leaves `tools/test_grok_bridge.py` untracked-untouched, `PROJECT_CONTEXT.md`
  unstaged). **No pushes, no merges, no touching main** — the orchestrator owns the pipeline.
- **Scope origin:** owner-approved calc-quality wave-2 brainstorm, five independent items (A–E). Items
  are separable: a reviewer can reject any one item's steps without sinking the rest (each item's steps
  touch a disjoint edit surface except MarketsView, where the three items' edits are in disjoint
  functions).

## 1. Goal (one sentence)

Every calculation surface this wave touches becomes cost/turnover/significance-HONEST — a coded
refuse-list + weekly re-cycle disclosure (research roadmap #1), four risk-engine correctness fixes,
four crypto cost-honesty engines, significance-gated backtest verdict colors, and two
await-interleaving fixes — with **zero change to any displayed gross number and zero un-labeled new
numbers**.

## 2. Owner-gate check (consulted → verdict) — these are REFUSE-gates, not tasks

Consulted: `AUDIT_2026-07-02_ideas_board.md` §5, `.claude/skills/stocksage-mental-model` §6 registry,
`RANKING_BACKLOG.md` #10, `gated-scope`.

| Gate | What it parks | This plan touches it? |
|---|---|---|
| RANKING #10 | `preferVelocity` default flip | **No.** No `bestOpportunity` call site changes; `preferVelocity` stays opt-in. If any step appears to need it → STOP. |
| F01/F02 | identity-calibration ENGINE semantics | **No.** No calibration code touched anywhere. Every new EV-adjacent helper threads `calibration` as an opaque parameter only. |
| F03/F44 | weekly NETTING of `expectedWeeklyR/Dollars` | **No numeric change.** Item A adds LABELS ONLY (turnover disclosure in the two existing `.help` tooltips). The gross figures are byte-identical. A step that nets, shrinks, or re-computes the weekly headline is a plan violation → STOP. |
| F08/F21 | "Conviction" vs "Signal strength" term unification | **No.** All new copy avoids the contested term (uses "win probability estimate", "edge", "setup"). |
| F10 | decimal-comma locale (`StockSageInput.clean`) | **No.** No money-input parsing touched. |
| Honesty floor | ranking/numeric change without validation or sign-off; nil=unknown fabricated; unlabeled numbers; removed nil-guards | **No ranking key, no demotion band, no default cost, no displayed number changes.** All new numeric constants are LABELED ESTIMATES with sources; every new engine returns nil on insufficient/invalid data; no existing nil-guard is weakened (Item B's LossLimit fix makes a fallback MORE conservative). |

**Verdict: NOT GATED — proceed.** Re-scan at Done-means. A "⚠️ pending confirmation" note anywhere is
NOT permission (RANKING #10 stayed correctly parked across many waves). If any step drifts into a
gate mid-execution, STOP and report — do not ship "with a warning".

## 3. REJECTED / DEFERRED register (owner-visible; evidence, not tasks)

1. **Item B / BUGHUNT_NEWENGINES #6 (GapRisk side-correctness) — ALREADY FIXED at `c807861`.**
   Evidence: `StockSageGapRisk.swift:45-48` carries the exact side guards the finding asked for
   (`case .long: guard stop < entry else { return nil }` / `.short: guard stop > entry`), and
   `StockSageGapRiskTests.swift:37-38` pins both malformed sides to nil. The `⬜` status in
   `BUGHUNT_NEWENGINES.md` is stale → corrected in the docs step, no code task.
2. **Item B / BUGHUNT_NEWENGINES #2 (surface GapRisk+LossLimit) — SUBSTANTIALLY SHIPPED 2026-06-22.**
   Evidence: `MarketsView.swift:1509` renders `lossLimitBanner` (STOP-TRADING / warn states,
   defined 1839–1891); `MarketsView.swift:4272-4291` renders `StockSageLeverage.assess` +
   `StockSageGapRisk.scenario(gapPct: 0.20)` on the position-sizer panel with engine caveats on
   `.help` (dev-log 2026-06-22 entries at DEVELOPMENT_LOG.md:6849/6868). Residual shipped here:
   the full `worstCase` LADDER in the gap row's tooltip (Step 8). The finding's "UI/integration
   assertion that the caveats are reachable from a rendered view" is **REJECTED**: the repo has no
   SwiftUI view-introspection tooling; caveat CONTENT is already test-pinned
   (StockSageGapRiskTests / StockSageLossLimitTests / StockSageHonestyGuardTests) and rendered-surface
   reachability is the `visual-qa` skill's job, not a unit assert.
3. **Item A / additional entry-timing (overnight) surface — REJECTED (research says done).**
   `RESEARCH_2026-07-02_week_horizon_velocity.md` roadmap #2 records: session-timing note SHIPPED
   (`StockSageExecutionTiming.sessionNote`, wired in `buildIdeas`), short-side overnight financing
   SHIPPED (`StockSageNetEdge.defaultShortBorrowRate` threaded through `netEVR`/`netVelocity`), and
   the liquidity-screen leg **deliberately DEFERRED with written reasoning** (no intraday data;
   redundant with the shipped RSI>80 demotion). "Roadmap item #2 is now fully actioned." Nothing
   further is research-supported — adding more overnight copy would be unsourced.
4. **Item A / a NEW turnover demotion band in the rank keys — REJECTED (would double-count).**
   iter6 already prices turnover CONTINUOUSLY: `netEVR` charges the full round-trip per cycle,
   `netVelocity = netEVR ÷ hold` amortizes it per day (shorter hold ⇒ bigger per-day drag),
   `velocityRankKey` scales by net/gross and the `minNetEVPerDayFloor` demotes (−500k)
   (StockSageExpectedValue.swift:242-300, 398-427). The only refuse-list setups detectable in this
   app's idea stream (thin-liquidity short-horizon names) are ALREADY demoted −3000 via
   `liquidityRankPenalty`. Item A therefore ships the refuse-list as CODED POLICY + LABELS with
   **zero rank-key change** — mirroring the research's own deferral discipline.
5. **Item C / re-pointing `defaultCosts`' crypto branch at the new tier estimates — REJECTED.**
   `CRYPTO_RISK.md` #1's "BLOCKING COLLISION: the existing test asserts 50bps" is STALE — at
   `c807861` the crypto default is **70bps incl. a 20bps round-trip taker fee**
   (`StockSageNetEdge.swift:89`), pinned by `StockSageNetEdgeTests.swift:72-73` and
   `StockSageHonestyGuardTests.swift:32`. Changing `defaultCosts` would silently move every crypto
   idea's net EV, rank key, and cost gate — a production ranking/numeric change with no ablation
   (honesty floor). `cryptoCosts(...)` ships as a **NEW accessor**; `defaultCosts` stays
   byte-identical. Re-pointing is a future owner-reviewed change.
6. **Item E / a unit test for the Monitor cancellation guards — REJECTED as tautology.**
   `runCycle`/`runWatchlistCycle` are @MainActor + live-network + `StockSageStore.shared` singleton;
   `StockSageMonitorTests.swift:5-11` documents the house decision to test only the extracted pure
   decision seams. A test that `Task.isCancelled` propagates is testing the Swift runtime
   (testing-discipline: "tautology tests deleted, not kept for the count"). Step 15 is verified by
   exact guard-count greps + build + the untouched pure-seam tests.
7. **Item C / UI wiring of the four crypto engines — DEFERRED (out of scope, own wave).**
   `CRYPTO_RISK.md`'s own mandate is "implement engine-first + python-verified test". The engines
   ship pure + tested and are recorded as UNWIRED in MARKETS_TAB_MAP (the map's explicit convention
   for deliberately-not-yet-called modules). Wiring them into MarketsView is a separate,
   visual-QA-gated wave.

## 4. Exact file list

| # | File | Touch |
|---|---|---|
| 1 | `Salehman AI/StockSage/StockSageRefuseList.swift` | **NEW** (Step 1) |
| 2 | `Salehman AITests/StockSageRefuseListTests.swift` | **NEW** (Step 2) |
| 3 | `Salehman AI/StockSage/StockSageExpectedValue.swift` | edit — 1 insertion (Step 3) |
| 4 | `Salehman AITests/StockSageWeeklyTurnoverTests.swift` | **NEW** (Step 4) |
| 5 | `Salehman AI/Views/MarketsView.swift` | edit — 5 locations (Steps 5, 8, 13) |
| 6 | `Salehman AI/StockSage/StockSageGapRisk.swift` | edit — 2 locations (Step 6) |
| 7 | `Salehman AITests/StockSageGapRiskTests.swift` | edit — append 2 tests (Step 7) |
| 8 | `Salehman AI/StockSage/StockSageCapitalAllocator.swift` | edit — 1 location (Step 9) |
| 9 | `Salehman AITests/StockSageCapitalAllocatorTests.swift` | edit — append 1 test (Step 9) |
| 10 | `Salehman AI/StockSage/StockSageLossLimit.swift` | edit — 2 locations (Step 10) |
| 11 | `Salehman AITests/StockSageLossLimitTests.swift` | edit — append 1 test (Step 10) |
| 12 | `Salehman AI/StockSage/StockSageNetEdge.swift` | edit — append extension (Step 11) |
| 13 | `Salehman AITests/StockSageCryptoCostTests.swift` | **NEW** (Step 11) |
| 14 | `Salehman AI/StockSage/StockSageCryptoLiquidityGate.swift` | **NEW** (Step 12a) |
| 15 | `Salehman AI/StockSage/StockSageCryptoHonesty.swift` | **NEW** (Step 12b) |
| 16 | `Salehman AI/StockSage/StockSageCryptoFunding.swift` | **NEW** (Step 12c) |
| 17 | `Salehman AITests/StockSageCryptoLiquidityGateTests.swift` | **NEW** (Step 12d) |
| 18 | `Salehman AITests/StockSageCryptoHonestyTests.swift` | **NEW** (Step 12d) |
| 19 | `Salehman AITests/StockSageCryptoFundingTests.swift` | **NEW** (Step 12d) |
| 20 | `Salehman AITests/BacktestVerdictColorTests.swift` | **NEW** (Step 13) |
| 21 | `Salehman AI/StockSage/StockSageMonitor.swift` | edit — 6 locations (Step 14) |
| 22 | `Salehman AI/StockSage/StockSageStore.swift` | edit — 3 locations (Step 15) |
| 23 | `Salehman AITests/StockSageIdeasMissingTests.swift` | **NEW** (Step 15) |
| 24 | `DEVELOPMENT_LOG.md` · `MARKETS_TAB_MAP.md` · `BUGHUNT_NEWENGINES.md` · `CRYPTO_RISK.md` · `LEVERAGE_RISK.md` · `AUDIT_FINDINGS_2.md` · `CONCURRENCY_BUGHUNT.md` · `RESEARCH_2026-07-02_week_horizon_velocity.md` · `research/INDEX.md` | docs, LAST (Step 16) |
| 25 | `SOURCE_BUNDLE.md` | regenerated by `bash tools/bundle_source.sh` ONLY (Step 16; never hand-edited, never Read) |

`Salehman AITests/` is a synchronized file group — new test files join the target automatically;
**no `project.pbxproj` edit**. **NO other file.** A step appearing to need any other file is a
mismatch → STOP and report.

## 5. Pre-flight captures (run ALL before editing; any deviation → STOP, report `plan says X / tree says Y`)

```bash
cd "$(git rev-parse --show-toplevel)"

# PF-1 — tree identity (in the worktree, HEAD is the branch tip = c807861 before step 1)
git rev-parse --short HEAD
# EXPECTED: c807861
git status --short
# EXPECTED: (empty)

# PF-2 — new type/symbol names are unclaimed
grep -rn "StockSageRefuseList\|RefusedSetup\|assumedWeeklyRoundTrips\|weeklyTurnoverNote\|weeklyGrossHelp\|CryptoCostEstimate\|CryptoLiquidityTier\|cryptoTier\|cryptoCosts\|CryptoNetEdgeHonesty\|StockSageCryptoHonesty\|CryptoLiquidityGate\|CryptoFundingDrag\|StockSageCryptoFunding\|BacktestVerdict\|positionOrder\|sevenDayFallbackStart\|missingAfterScan" "Salehman AI" "Salehman AITests" --include="*.swift"
# EXPECTED: (no output)

# PF-3 — GapRisk anchors (Item B): side guards PRESENT (=#6 already fixed), sort ABSENT, clamp ABSENT
grep -n "guard stop < entry else { return nil }" "Salehman AI/StockSage/StockSageGapRisk.swift"
# EXPECTED: 46:        case .long:  guard stop < entry else { return nil }   // a long's stop sits BELOW entry
grep -c "gaps.sorted()" "Salehman AI/StockSage/StockSageGapRisk.swift"
# EXPECTED: 0
grep -n "gapFill = stop \* (1 - gapPct)" "Salehman AI/StockSage/StockSageGapRisk.swift"
# EXPECTED: 51:        case .long:  gapFill = stop * (1 - gapPct); lossPerShare = entry - gapFill   // gaps below the stop

# PF-4 — CapitalAllocator sort anchor (Item B #8)
grep -n 'let sorted = positions.sorted' "Salehman AI/StockSage/StockSageCapitalAllocator.swift"
# EXPECTED: 131:        let sorted = positions.sorted { $0.riskFraction != $1.riskFraction ? $0.riskFraction > $1.riskFraction : $0.symbol < $1.symbol }

# PF-5 — LossLimit weekly fallback anchor (Item B #9: the fail-OPEN `?? dayStart`)
grep -n '?? dayStart' "Salehman AI/StockSage/StockSageLossLimit.swift"
# EXPECTED: 56:        let weekStart = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? dayStart

# PF-6 — NetEdge: crypto default is 70bps (NOT the stale 50 in CRYPTO_RISK.md) and file tail is the anchor
grep -n 'spreadBps: 30, slippageBps: 20' "Salehman AI/StockSage/StockSageNetEdge.swift"
# EXPECTED: 89:        if s.hasSuffix("-USD") { return CostAssumption(spreadBps: 30, slippageBps: 20, assetClass: "crypto", takerFeeBps: 20) } // 70bps incl. ~0.1%/fill taker
grep -n 'roundTripBps == 70' "Salehman AITests/StockSageNetEdgeTests.swift"
# EXPECTED: 72:        #expect(NE.defaultCosts(forSymbol: "BTC-USD").roundTripBps == 70)

# PF-7 — ExpectedValue insertion anchor (Item A) + weekly-path symbols
grep -n 'Trading days per week for the fast lane' "Salehman AI/StockSage/StockSageExpectedValue.swift"
# EXPECTED: 752:    /// Trading days per week for the fast lane. Equities trade ~5 days; crypto is 24/7 (~7).
grep -c 'nonisolated static func expectedWeeklyR' "Salehman AI/StockSage/StockSageExpectedValue.swift"
# EXPECTED: 1

# PF-8 — MarketsView anchors: the two weekly .help sites, gap row, two backtest metric blocks, EOF comment
grep -c 'Gross, before costs — sums the top fast-lane GROSS velocities. It can include ideas the net-cost floor demotes on the boards; the .Fastest. pick excludes them. An estimate, not income.' "Salehman AI/Views/MarketsView.swift"
# EXPECTED: 2
grep -n 'gapPct: 0.20, accountEquity: acct' "Salehman AI/Views/MarketsView.swift"
# EXPECTED: 4284:                                                           shares: Double(ps.shares), gapPct: 0.20, accountEquity: acct) {
grep -n 'color: s.blendedWinRate >= 1.0 / 3' "Salehman AI/Views/MarketsView.swift"
# EXPECTED: 3947:                               color: s.blendedWinRate >= 1.0 / 3 ? DS.Palette.successSoft : DS.Palette.danger)
grep -n 'color: bt.winRate >= 1.0 / 3' "Salehman AI/Views/MarketsView.swift"
# EXPECTED: 4064:                                   color: bt.winRate >= 1.0 / 3 ? DS.Palette.successSoft : DS.Palette.danger)
grep -c "Concrete improvement: EV badge" "Salehman AI/Views/MarketsView.swift"
# EXPECTED: 1        (the file's final line — Step 13's append anchor)

# PF-9 — Monitor: exactly ONE Task.isCancelled today (the while condition)
grep -c 'Task.isCancelled' "Salehman AI/StockSage/StockSageMonitor.swift"
# EXPECTED: 1

# PF-10 — Store: retry re-reads trackedDefs() AFTER its await (the #3 bug), refreshIdeas does not
grep -n 'ideasMissing = trackedDefs' "Salehman AI/StockSage/StockSageStore.swift"
# EXPECTED: 394:        ideasMissing = trackedDefs().map(\.symbol).filter {
grep -n 'ideasMissing = universe.map' "Salehman AI/StockSage/StockSageStore.swift"
# EXPECTED: 354:        ideasMissing = universe.map(\.symbol).filter {

# PF-11 — liquidity constants the crypto tier map reuses (NOT new constants)
grep -n 'thinBelow\|deepAbove' "Salehman AI/StockSage/StockSageLiquidity.swift" | head -2
# EXPECTED:
# 35:    nonisolated static let thinBelow = 2_000_000.0
# 36:    nonisolated static let deepAbove = 50_000_000.0

# PF-12 — duplicate-test-struct guard (run again after every new test file)
grep -rhoE '^(@MainActor[[:space:]]+)?(struct|class) [A-Za-z0-9_]+Tests' "Salehman AITests/" | sed -E 's/.*(struct|class) //' | sort | uniq -d
# EXPECTED: (no output)

# PF-13 — green baseline build + STATIC @Test baseline (grep count is deterministic; the RUNTIME
# count fluctuates ±1 from parallel-runner log interleaving and is NEVER the gate — testing-discipline)
xcodebuild -scheme "Salehman AI" -destination 'platform=macOS' -configuration Debug CODE_SIGNING_ALLOWED=NO -derivedDataPath .dd build 2>&1 | tee /tmp/salehman_calcwave2_build.log | tail -5
# EXPECTED: contains ** BUILD SUCCEEDED **
grep -ch '@Test' "Salehman AITests"/*.swift | awk '{s+=$1} END {print s}'
# EXPECTED: 1502     (record YOUR number as B if different — the final gate expects B + 30)
```

Current-behavior pins (the "before" this plan changes): the two weekly `.help` tooltips carry NO
turnover/re-cycle disclosure (PF-8 count 2 of the un-extended string); `worstCase` returns caller
order (PF-3 sort absent); allocator ties beyond symbol are unspecified (PF-4); LossLimit weekly
window falls back to a single day (PF-5); backtest Win/AvgR/TotalR are green/red even when
`isSignificant == false` (PF-8 color lines); a cancelled monitor cycle keeps alerting (PF-9 count 1);
retry re-reads the universe post-await (PF-10).

---

# ITEM A — Turnover-aware cost honesty: coded refuse-list + weekly re-cycle disclosure

Read `RESEARCH_2026-07-02_week_horizon_velocity.md` first (roadmap #1). Register entries 3–4 above
bound this item: the continuous turnover cost machinery already ships (iter6); Item A adds the
**coded refuse-list policy module**, the **published-effect haircut constants**, and the **weekly
re-cycle disclosure labels** — zero rank/numeric change, F03/F44 untouched (labels only).

### Step 1 — NEW `Salehman AI/StockSage/StockSageRefuseList.swift` (complete file)

```swift
import Foundation

// MARK: - Week-horizon refuse-list (coded policy, not a silent omission)
//
// RESEARCH_2026-07-02_week_horizon_velocity.md (deep-research 2026-07-02; 23 claims verified by
// adversarial 3-vote; roadmap item #1 — "the biggest lever"): at the 1–5 day horizon essentially
// NO documented equity edge survives realistic retail transaction costs as a standalone strategy.
// The fastest money at this horizon is the ~1–1.7%/month of COST-AVOIDANCE from refusing the
// documented net-negative setups — so the refuse-list is encoded HERE, in code, where it is
// testable, surfaceable in the UI, and consulted before any future short-horizon signal ships —
// instead of living only in a research markdown a future session may not read.
//
// POLICY/ADVISORY ONLY — nothing here touches score, conviction, sizing, or any rank key. The
// continuous turnover-aware cost machinery already ships (iter6: netEVR charges the round-trip
// per cycle, netVelocity amortizes it per day, the net-cost floor demotes at −500k, thin
// liquidity demotes at −3000). A second turnover penalty here would double-count it.

/// One documented net-negative-after-retail-costs short-horizon setup. Every number in
/// `evidence` is sourced + adversarially verified in RESEARCH_2026-07-02_week_horizon_velocity.md.
struct RefusedSetup: Sendable, Equatable, Identifiable {
    let id: String
    let title: String
    let evidence: String
}

enum StockSageRefuseList {
    /// The coded refuse-list (research refuse-list items 1–7, verbatim substance).
    nonisolated static let all: [RefusedSetup] = [
        RefusedSetup(id: "naive-reversal",
                     title: "Naive short-term reversal as a standalone weekly strategy",
                     evidence: "Canonical reversal decile: +0.37%/mo GROSS becomes −1.28%/mo NET (t=−6.02) after ~1.65%/mo costs (Novy-Marx & Velikov, RFS 2016; verified 3-0)."),
        RefusedSetup(id: "standalone-pead",
                     title: "Standalone PEAD / earnings-drift trading",
                     evidence: "Costs consume 70–100% of paper PEAD profits; the drift is 0.04%/mo in liquid names vs 2.43%/mo in illiquid (untradeable) ones (verified 3-0)."),
        RefusedSetup(id: "anomaly-rotation",
                     title: "~90%-turnover monthly anomaly rotation",
                     evidence: "Round-trip costs exceed 1%/mo — more than the gross spread of all but two documented variants (verified)."),
        RefusedSetup(id: "overnight-roundtrip",
                     title: "Daily overnight/intraday round-trip harvesting",
                     evidence: "The overnight premium is real but the DAILY round-trip is cost-devoured — the source paper itself calls it cost-unattractive, and the NightShares ETF implementations shut down (verified). Hold the overnight session via entry timing instead (already shipped, zero added turnover)."),
        RefusedSetup(id: "funding-seasonality",
                     title: "Crypto funding-rate-seasonality timing",
                     evidence: "Peak-to-trough intraday funding spread ~2.5bps vs 4–10bps/side retail taker fees; single mid-tier source, ~3-month sample — weak evidence AND a negative conclusion (verified)."),
        RefusedSetup(id: "illiquid-anomaly",
                     title: "Implementing any anomaly in the small/illiquid names where its paper edge lives",
                     evidence: "The paper edge concentrates exactly where retail fills cannot: real slippage in thin names is worse than any modeled cost; the tradable-liquidity version of the same anomaly is typically near zero (verified 3-0)."),
        RefusedSetup(id: "unhaircut-effect",
                     title: "Taking any published in-sample effect size at face value",
                     evidence: "Published predictors decay 26% out-of-sample and 58% post-publication (McLean & Pontiff, JF; verified 3-0 ×3) — haircut 50–60% BEFORE evaluating, then demand a net-of-cost simulation."),
    ]

    /// McLean & Pontiff decay — the mandatory haircut applied to ANY published effect size before
    /// it may even be EVALUATED for this engine (refuse-list #7). Policy constants for future
    /// signal ablations, not runtime multipliers — nothing in production math reads these.
    nonisolated static let outOfSampleDecay = 0.26
    nonisolated static let postPublicationDecay = 0.58

    /// The permanent honesty tail every surfacing of this policy must carry.
    nonisolated static let caveat = "A refuse-list is cost-avoidance, not alpha — the ~1–1.7%/mo it protects is money you stop burning, not money it earns. Policy from adversarially-verified research (2026-07-02); estimates from historical samples, never a promise."

    /// One-paragraph policy line for tooltips/help surfaces (the weekly-R sites use this).
    nonisolated static var policyNote: String {
        "REFUSED at the 1–5 day horizon (documented net-negative after retail costs): "
        + all.map(\.title).joined(separator: "; ")
        + ". " + caveat
    }
}
```

**Verify:**
```bash
grep -n "enum StockSageRefuseList" "Salehman AI/StockSage/StockSageRefuseList.swift"
xcodebuild -scheme "Salehman AI" -destination 'platform=macOS' -configuration Debug CODE_SIGNING_ALLOWED=NO -derivedDataPath .dd build 2>&1 | tee /tmp/salehman_calcwave2_build.log | tail -5
```
**EXPECTED OUTPUT:** `27:enum StockSageRefuseList {` (±3) and `** BUILD SUCCEEDED **`.

**HASTY-MODEL TRAP:** wiring the refuse-list into a rank key or `buildIdeas` "while you're in
there" — register entry 4 REJECTED that with evidence (double-counting iter6 + the −3000 thin
band). This module has ZERO production callers except the Step 5 tooltip. Second trap: "improving"
the evidence numbers from memory — every figure is a verbatim transfer from the research file;
if a number looks wrong, STOP and re-read the research, don't "fix" it.

---

### Step 2 — NEW `Salehman AITests/StockSageRefuseListTests.swift`

**2a — derivation (spec-fidelity: expected values come from the CAPTURED RESEARCH, not code).**
The asserted literals below are transcribed from `RESEARCH_2026-07-02_week_horizon_velocity.md`:
refuse-list count = 7 (items 1–7); reversal net figure "−1.28" (t=−6.02); PEAD "70–100%";
McLean-Pontiff decay 26% OOS / 58% post-publication → constants 0.26 / 0.58. No derive script
needed — the spec file IS the derivation source; cite it in comments.

**2b — file (complete):**
```swift
import Testing
@testable import Salehman_AI

// MARK: - Refuse-list policy (Item A, week-horizon research roadmap #1)
//
// Expected values transcribed from RESEARCH_2026-07-02_week_horizon_velocity.md (the captured,
// adversarially-verified spec) — never from the code under test (spec-fidelity/F40).

struct StockSageRefuseListTests {

    @Test func policyEncodesAllSevenVerifiedRefusals() {
        // Research refuse-list has exactly 7 numbered items.
        #expect(StockSageRefuseList.all.count == 7)
        #expect(Set(StockSageRefuseList.all.map(\.id)).count == 7)   // ids unique
        // Every entry carries load-bearing EVIDENCE, not a bare opinion. Six of the seven
        // spec entries cite a number; item 4 (overnight-roundtrip) is digit-free IN THE SPEC
        // (RESEARCH_2026-07-02_week_horizon_velocity.md:35 — "explicitly cost-unattractive per
        // the source paper; ETF implementations shuttered"), so it is pinned on its load-bearing
        // spec phrases instead. [Amendment A-1, 2026-07-02: the original universal digit-assert
        // contradicted the digit-free spec entry — plan bug, not code bug; adding a figure to
        // the evidence would have fabricated a stat the research corpus does not contain.]
        for setup in StockSageRefuseList.all {
            #expect(!setup.title.isEmpty)
            if setup.id == "overnight-roundtrip" {
                #expect(setup.evidence.contains("cost-devoured"))
                #expect(setup.evidence.contains("shut down"))
            } else {
                #expect(setup.evidence.rangeOfCharacter(from: .decimalDigits) != nil)
            }
        }
        // The single most load-bearing verified number: reversal flips to −1.28%/mo NET.
        guard let reversal = StockSageRefuseList.all.first(where: { $0.id == "naive-reversal" }) else {
            Issue.record("naive-reversal entry missing"); return
        }
        #expect(reversal.evidence.contains("−1.28"))
    }

    @Test func publishedEffectHaircutMatchesMcLeanPontiff() {
        // Research: predictors decay 26% out-of-sample / 58% post-publication (verified 3-0 ×3).
        #expect(StockSageRefuseList.outOfSampleDecay == 0.26)
        #expect(StockSageRefuseList.postPublicationDecay == 0.58)
    }

    @Test func policySurfacesStayHonest() {
        let note = StockSageRefuseList.policyNote.lowercased()
        let caveat = StockSageRefuseList.caveat.lowercased()
        #expect(note.contains("refused"))
        #expect(caveat.contains("not alpha") && caveat.contains("never a promise"))
        // Honesty floor: no promise language anywhere in the policy surfaces.
        for banned in ["guarantee", "sure thing", "free money", "risk-free"] {
            #expect(!note.contains(banned))
        }
    }
}
```

**2c — Verify (named cases MUST appear — WHIPPYX rule):**
```bash
xcodebuild test -scheme "Salehman AI" -destination 'platform=macOS' -configuration Debug CODE_SIGNING_ALLOWED=NO -derivedDataPath .dd -only-testing:"Salehman AITests/StockSageRefuseListTests" 2>&1 | tee /tmp/salehman_calcwave2_build.log | tail -8
grep -o "StockSageRefuseListTests/[a-zA-Z]*()" /tmp/salehman_calcwave2_build.log | sort -u
```
**EXPECTED OUTPUT:** `** TEST SUCCEEDED **` and exactly these 3:
```
StockSageRefuseListTests/policyEncodesAllSevenVerifiedRefusals()
StockSageRefuseListTests/policySurfacesStayHonest()
StockSageRefuseListTests/publishedEffectHaircutMatchesMcLeanPontiff()
```

**2d — Falsifiability probe:** Edit `== 7)` (the count assert) → `== 6)`, re-run 2c →
`** TEST FAILED **` naming `policyEncodesAllSevenVerifiedRefusals()`; restore to `== 7)`, re-run →
`** TEST SUCCEEDED **`. Paste both outputs.

**HASTY-MODEL TRAP:** the "−1.28" assert uses a UNICODE MINUS (U+2212, copied from the research
file) — if your Step 1 file used an ASCII hyphen the test rightly fails; fix the SOURCE STRING to
match this plan (both use U+2212 here), never the assertion (NetEdge rule). Also: no bare
`guard else { return }` — the `Issue.record` on the reversal lookup is mandatory.

---

### Step 3 — Weekly re-cycle disclosure helpers (engine, label-only)

**File:** `Salehman AI/StockSage/StockSageExpectedValue.swift` · **Anchor:** the doc comment of
`tradingDaysForLane` (line ~752, unique per PF-7). Insert the two new functions ABOVE it.

**OLD (exact):**
```swift
    /// Trading days per week for the fast lane. Equities trade ~5 days; crypto is 24/7 (~7).
```

**NEW:**
```swift
    /// How many ROUND TRIPS the weekly projection implicitly assumes. `expectedWeeklyR`
    /// multiplies each top-N idea's per-day velocity by `tradingDays` — i.e. it assumes each
    /// slot stays deployed all week, re-entering as its setups resolve: tradingDays ÷
    /// expectedHold re-cycles per slot (a 3-day crypto hold ⇒ ~1.7 round trips in a 5-day
    /// week; a 12-day equity swing ⇒ ~0.4 — you pay its round trip roughly every 2.4 weeks).
    /// Each re-cycle pays the full round-trip frictions the GROSS weekly figure excludes —
    /// week-horizon research roadmap #1 (turnover awareness): turnover is the #1 documented
    /// edge-killer at the 1–5d horizon. DISCLOSURE ONLY: consumed by display labels; nothing
    /// in ranking/sizing reads it. nil when the fast lane is empty or no top idea has a hold
    /// (mirrors expectedWeeklyR's own nil — never a fabricated cadence).
    nonisolated static func assumedWeeklyRoundTrips(_ ideas: [StockSageIdea], maxConcurrent: Int = 3,
                                                    tradingDays: Double = 5,
                                                    holds: VelocityHoldDays = .defaults,
                                                    calibration: StockSageConvictionCalibration? = nil) -> Double? {
        let lane = fastLane(ideas, holds: holds, calibration: calibration).prefix(Swift.max(0, maxConcurrent))
        let cycles = lane.compactMap { idea -> Double? in
            guard let hold = expectedHoldDays(for: idea, holds: holds), hold > 0 else { return nil }
            return tradingDays / hold
        }
        guard !cycles.isEmpty else { return nil }
        return cycles.reduce(0, +)
    }

    /// F03/F44-SAFE disclosure line for the weekly-R display sites: names the re-cycle count
    /// the gross figure assumes. LABEL ONLY — never alters the number itself (the gross→net
    /// netting decision stays owner-held, F03/F44). nil when no cadence is estimable.
    nonisolated static func weeklyTurnoverNote(_ ideas: [StockSageIdea], maxConcurrent: Int = 3,
                                               tradingDays: Double = 5,
                                               holds: VelocityHoldDays = .defaults,
                                               calibration: StockSageConvictionCalibration? = nil) -> String? {
        guard let trips = assumedWeeklyRoundTrips(ideas, maxConcurrent: maxConcurrent, tradingDays: tradingDays,
                                                  holds: holds, calibration: calibration) else { return nil }
        return String(format: "Assumes ≈%.1f round trips across the top %d this week — every re-entry pays the est. round-trip frictions this gross figure excludes (turnover is the #1 documented edge-killer at this horizon).",
                      trips, Swift.max(0, maxConcurrent))
    }

    /// Trading days per week for the fast lane. Equities trade ~5 days; crypto is 24/7 (~7).
```

**Verify:**
```bash
grep -n "assumedWeeklyRoundTrips\|weeklyTurnoverNote" "Salehman AI/StockSage/StockSageExpectedValue.swift" | head -4
xcodebuild -scheme "Salehman AI" -destination 'platform=macOS' -configuration Debug CODE_SIGNING_ALLOWED=NO -derivedDataPath .dd build 2>&1 | tee /tmp/salehman_calcwave2_build.log | tail -5
```
**EXPECTED OUTPUT:** two definition hits (one per function, line ~752–790 region) + one internal
call hit (`assumedWeeklyRoundTrips(ideas,` inside `weeklyTurnoverNote`) and `** BUILD SUCCEEDED **`.

**HASTY-MODEL TRAP:** flooring cycles at 1 (`max(1, tradingDays/hold)`) because "0.4 round trips
reads oddly" — that would OVERSTATE the assumed churn for slow swings and understate how much
friction-free the weekly gross figure looks; the un-floored value is the truthful cadence (the doc
comment explains 0.4 = one round trip per ~2.4 weeks). Second trap: netting — computing "≈X R of
friction excluded" and subtracting it anywhere. F03/F44 REFUSE-gate: the note names the CYCLE
COUNT only; the R number is untouched.

---

### Step 4 — NEW `Salehman AITests/StockSageWeeklyTurnoverTests.swift`

**4a — derivation FIRST (standalone, imports nothing from the app):**
```bash
cat > /tmp/derive_weekly_turnover.swift <<'EOF'
import Foundation   // String(format:)
// Hand-derivation from the SPEC (Step 3 doc): cycles per slot = tradingDays / expectedHold.
// Fixture ideas carry NO dailyMove and spark [] (<3 points), so expectedHoldDays falls back to
// the per-class base: equity 12d, crypto 3d (VelocityHoldDays.defaults — engine doc, map entry).
print("two equities, tradingDays 5: 5/12 + 5/12 =", 5.0/12 + 5.0/12)          // 0.8333...
print("%.1f format of it:", String(format: "%.1f", 5.0/12 + 5.0/12))          // "0.8"
print("three cryptos, tradingDays 5: 3 * 5/3 =", 3 * (5.0/3))                 // 5.0
print("if the 4th (weak) crypto were wrongly included: +5/3 =", 3 * (5.0/3) + 5.0/3)  // 6.666...
// Top-3 selection certainty: rank key = grossLogGrowth(p,R)*netRatio/hold; p = 0.35 + 0.23*c.
// c=0.9 -> p=0.557 ; c=0.45 -> p=0.4535. Same R (3.0), same hold (3d), same costs (crypto 70bps)
// => every factor is strictly increasing in p, so the three c=0.9 ideas STRICTLY out-rank c=0.45.
print("p(0.9) =", 0.35 + 0.23*0.9, "> p(0.45) =", 0.35 + 0.23*0.45)
EOF
swift /tmp/derive_weekly_turnover.swift
```
**EXPECTED OUTPUT (verbatim-shape):**
```
two equities, tradingDays 5: 5/12 + 5/12 = 0.8333333333333334
%.1f format of it: 0.8
three cryptos, tradingDays 5: 3 * 5/3 = 5.0
if the 4th (weak) crypto were wrongly included: +5/3 = 6.666666666666667
p(0.9) = 0.5569999999999999 > p(0.45) = 0.4535
```
(The 0.55699… is binary-float display of 0.557 — expected, not an error.)

**4b — file (complete):**
```swift
import Testing
@testable import Salehman_AI

// MARK: - Weekly turnover disclosure (Item A, label-only)
//
// Fixtures + expected values HAND-DERIVED in /tmp/derive_weekly_turnover.swift (output pasted
// in plans/PLAN_2026-07-03_calc_wave2_cost_honesty.md Step 4a) — never from the code under test.
// Ideas carry spark [] and no dailyMove, so expectedHoldDays = the class base (equity 12, crypto 3).

struct StockSageWeeklyTurnoverTests {
    typealias EV = StockSageExpectedValue

    private func idea(_ symbol: String, conviction: Double = 0.9) -> StockSageIdea {
        StockSageIdea(symbol: symbol, market: "M", price: 100,
                      advice: TradeAdvice(action: .buy, conviction: conviction, regime: .bullTrend,
                                          rationale: [], stopPrice: 90, targetPrice: 130,
                                          suggestedWeight: 0.05, caveat: "x"),
                      spark: [])
    }

    @Test func twoEquitySlotsSumTheirWeeklyCycles() {
        // derive_weekly_turnover: 5/12 + 5/12 = 0.8333…
        let trips = EV.assumedWeeklyRoundTrips([idea("AAA"), idea("BBB")], tradingDays: 5)
        #expect(trips != nil && abs(trips! - (5.0 / 12 + 5.0 / 12)) < 1e-9)
    }

    @Test func topThreePrefixExcludesTheWeakestCrypto() {
        // derive_weekly_turnover: top-3 of {3× c=0.9, 1× c=0.45} = the 0.9s (strict rank order),
        // sum = 3·(5/3) = 5.0 exactly; a wrongly-included 4th would read 6.667.
        let ideas = [idea("AAA-USD"), idea("BBB-USD"), idea("CCC-USD"), idea("DDD-USD", conviction: 0.45)]
        let trips = EV.assumedWeeklyRoundTrips(ideas, maxConcurrent: 3, tradingDays: 5)
        #expect(trips != nil && abs(trips! - 5.0) < 1e-9)
    }

    @Test func noCadenceMeansNilNeverAFabricatedNumber() {
        // FX has no hold (expectedHoldDays nil) → out of the fast lane → nil, not 0.
        #expect(EV.assumedWeeklyRoundTrips([idea("EURUSD=X")], tradingDays: 5) == nil)
        #expect(EV.assumedWeeklyRoundTrips([], tradingDays: 5) == nil)
        #expect(EV.weeklyTurnoverNote([], tradingDays: 5) == nil)
    }

    @Test func noteDisclosesTripCountAndStaysLabelOnly() {
        let note = EV.weeklyTurnoverNote([idea("AAA"), idea("BBB")], tradingDays: 5)
        guard let note else { Issue.record("note should exist for two equity ideas"); return }
        #expect(note.contains("≈0.8 round trips"))            // derive: %.1f of 0.8333
        #expect(note.contains("gross figure excludes"))       // names the exclusion, nets nothing
        #expect(!note.lowercased().contains("guarantee"))
    }
}
```

**4c — Verify:**
```bash
xcodebuild test -scheme "Salehman AI" -destination 'platform=macOS' -configuration Debug CODE_SIGNING_ALLOWED=NO -derivedDataPath .dd -only-testing:"Salehman AITests/StockSageWeeklyTurnoverTests" 2>&1 | tee /tmp/salehman_calcwave2_build.log | tail -8
grep -o "StockSageWeeklyTurnoverTests/[a-zA-Z]*()" /tmp/salehman_calcwave2_build.log | sort -u
```
**EXPECTED OUTPUT:** `** TEST SUCCEEDED **` + exactly the 4 named cases.

**4d — Falsifiability probe:** in `twoEquitySlotsSumTheirWeeklyCycles` change `5.0 / 12 + 5.0 / 12`
→ `5.0 / 12`, re-run → `** TEST FAILED **` naming that case; restore → green. Paste both.

**HASTY-MODEL TRAP:** if `topThreePrefixExcludesTheWeakestCrypto` comes out 6.667, the eager fix is
editing the assertion to 6.667 — WRONG (NetEdge rule): 6.667 means the prefix(maxConcurrent) is
missing or the rank order broke; re-derive (4a proves the 0.9s strictly out-rank) and fix the CODE.
Also: don't "help" the FX case by giving `EURUSD=X` a stop/target so it gets a velocity — FX has no
hold by design (nil contract); the test pins exactly that.

---

### Step 5 — Surface the disclosure + policy on the two weekly `.help` sites (labels only)

**File:** `Salehman AI/Views/MarketsView.swift` · 3 edits. The gross numbers and all visible text
are UNTOUCHED — only the two hover tooltips gain content (zero layout risk, no visual-QA gate).

**5a — shared tooltip builder.** Anchor: `private func weeklyGrossHelp` must not exist (PF-2).
Insert directly ABOVE the `lossLimitBanner` definition (unique anchor):

**OLD (exact):**
```swift
    // The loss-limit circuit breaker, surfaced. R-based + loss-streak policy (no account needed):
```
**NEW:**
```swift
    /// Shared tooltip for the two weekly-R display sites: the existing F03/F44 gross label + the
    /// Item-A turnover disclosure (assumed re-cycles) + the coded refuse-list policy line.
    /// LABEL-ONLY — the weekly number itself stays GROSS (netting is owner-gated F03/F44).
    private func weeklyGrossHelp(_ base: String) -> String {
        var s = base
        if let note = StockSageExpectedValue.weeklyTurnoverNote(
            store.ideas,
            tradingDays: StockSageExpectedValue.tradingDaysForLane(store.ideas, holds: velocityHolds, calibration: store.convictionCalibration),
            holds: velocityHolds, calibration: store.convictionCalibration) {
            s += "\n\n" + note
        }
        s += "\n\n" + StockSageRefuseList.policyNote
        return s
    }

    // The loss-limit circuit breaker, surfaced. R-based + loss-streak policy (no account needed):
```

**5b — summary-card site.** Anchor (unique via the `ideaMetric("Est./week"` line):

**OLD (exact):**
```swift
                            ideaMetric("Est./week", String(format: "%+.1fR", wk), sub: "gross, if you run top 3", subColor: .secondary)
                                .help("Gross, before costs — sums the top fast-lane GROSS velocities. It can include ideas the net-cost floor demotes on the boards; the 'Fastest' pick excludes them. An estimate, not income.")
```
**NEW:**
```swift
                            ideaMetric("Est./week", String(format: "%+.1fR", wk), sub: "gross, if you run top 3", subColor: .secondary)
                                .help(weeklyGrossHelp("Gross, before costs — sums the top fast-lane GROSS velocities. It can include ideas the net-cost floor demotes on the boards; the 'Fastest' pick excludes them. An estimate, not income."))
```

**5c — fast-lane footer site.** Anchor (unique via the `Text(String(format: "≈ %+.1fR/week gross` line):

**OLD (exact):**
```swift
                    Text(String(format: "≈ %+.1fR/week gross, before costs, if you run the top %d — estimate, high variance, assumes you take and re-cycle these. Not a promise.", wk, Swift.min(3, lane.count)))
                        .font(.system(size: mvFont9, weight: .medium))
                        .foregroundStyle(DS.Palette.successSoft).fixedSize(horizontal: false, vertical: true)
                        .help("Gross, before costs — sums the top fast-lane GROSS velocities. It can include ideas the net-cost floor demotes on the boards; the 'Fastest' pick excludes them. An estimate, not income.")
```
**NEW:**
```swift
                    Text(String(format: "≈ %+.1fR/week gross, before costs, if you run the top %d — estimate, high variance, assumes you take and re-cycle these. Not a promise.", wk, Swift.min(3, lane.count)))
                        .font(.system(size: mvFont9, weight: .medium))
                        .foregroundStyle(DS.Palette.successSoft).fixedSize(horizontal: false, vertical: true)
                        .help(weeklyGrossHelp("Gross, before costs — sums the top fast-lane GROSS velocities. It can include ideas the net-cost floor demotes on the boards; the 'Fastest' pick excludes them. An estimate, not income."))
```

**Verify:**
```bash
grep -c 'weeklyGrossHelp' "Salehman AI/Views/MarketsView.swift"
xcodebuild -scheme "Salehman AI" -destination 'platform=macOS' -configuration Debug CODE_SIGNING_ALLOWED=NO -derivedDataPath .dd build 2>&1 | tee /tmp/salehman_calcwave2_build.log | tail -5
```
**EXPECTED OUTPUT:** `3` (1 definition + 2 call sites — the doc-comment mention inside the
definition does not match the bare identifier count differently; if you see 4+, an extra call site
crept in → STOP) and `** BUILD SUCCEEDED **`.

**HASTY-MODEL TRAP:** "while I'm here" adding the note as VISIBLE caption text under the weekly
figures — that changes layout (visual-QA-gated) and was not approved; tooltips only. Second trap:
inlining the whole help expression at both call sites instead of the builder — the two sites then
drift (the exact disagreement the shared-string convention exists to prevent), and the long inline
closure can blow the SwiftUI type-checker budget (house scar: "unable to type-check this
expression in reasonable time").

**WIP commit** (after each of Steps 1–5, per the header contract), e.g.:
```bash
git add "Salehman AI/StockSage/StockSageRefuseList.swift" "Salehman AITests/StockSageRefuseListTests.swift" && git commit -m "wip: calc-wave-2 step 1-2 — refuse-list policy module + tests"
```

---

# ITEM B — Risk-engine correctness + residual wiring (BUGHUNT_NEWENGINES #7 #8 #9 #10 + ladder tooltip)

Register entries 1–2 bound this item: #6 already fixed, #2 substantially shipped. Four small
engine fixes + one tooltip enrichment. **Never remove a nil-guard** — every fix below ADDS
conservatism.

### Step 6 — GapRisk: sort the worstCase ladder (#7) + clamp the long gap fill at $0 (#10)

**File:** `Salehman AI/StockSage/StockSageGapRisk.swift` · 2 edits.

**6a — #10 clamp.** Anchor: the long branch of the fill switch (line ~51, unique per PF-3).

**OLD (exact):**
```swift
        case .long:  gapFill = stop * (1 - gapPct); lossPerShare = entry - gapFill   // gaps below the stop
```
**NEW:**
```swift
        // #10: a gap of ≥100% cannot fill below $0 — clamp the long fill at zero (a total
        // wipeout of the position, the honest physical maximum), never a negative price.
        // Shorts have no analogous ceiling (loss above entry is unbounded — deliberately unclamped).
        case .long:  gapFill = Swift.max(0, stop * (1 - gapPct)); lossPerShare = entry - gapFill   // gaps below the stop
```

**6b — #7 sort.** Anchor: the `worstCase` body (lines ~63–71).

**OLD (exact):**
```swift
    /// A ladder of canonical adverse gaps (weekend 5%, earnings 8%, crypto-flash 20%,
    /// halt-reopen 35% by default), each a separate scenario — the "a stop is not a fill" table.
    /// Magnitudes are illustrative, NOT predicted probabilities.
    nonisolated static func worstCase(side: TradeSide, entry: Double, stop: Double, shares: Double,
                                      accountEquity: Double,
                                      gaps: [Double] = [0.05, 0.08, 0.20, 0.35]) -> [GapRiskScenario] {
        gaps.compactMap { scenario(side: side, entry: entry, stop: stop, shares: shares, gapPct: $0,
                                   accountEquity: accountEquity) }
    }
```
**NEW:**
```swift
    /// A ladder of canonical adverse gaps (weekend 5%, earnings 8%, crypto-flash 20%,
    /// halt-reopen 35% by default), each a separate scenario — the "a stop is not a fill" table.
    /// Magnitudes are illustrative, NOT predicted probabilities. #7: `gaps` is SORTED ascending
    /// before mapping, so the documented ascending-in-loss ladder holds for ANY caller order
    /// (loss is monotonic in gapPct; non-strictly once a long gap ≥ 100% plateaus at the $0 fill).
    nonisolated static func worstCase(side: TradeSide, entry: Double, stop: Double, shares: Double,
                                      accountEquity: Double,
                                      gaps: [Double] = [0.05, 0.08, 0.20, 0.35]) -> [GapRiskScenario] {
        gaps.sorted().compactMap { scenario(side: side, entry: entry, stop: stop, shares: shares, gapPct: $0,
                                            accountEquity: accountEquity) }
    }
```

**Verify:**
```bash
grep -n "gaps.sorted()" "Salehman AI/StockSage/StockSageGapRisk.swift"
grep -n "Swift.max(0, stop \* (1 - gapPct))" "Salehman AI/StockSage/StockSageGapRisk.swift"
xcodebuild -scheme "Salehman AI" -destination 'platform=macOS' -configuration Debug CODE_SIGNING_ALLOWED=NO -derivedDataPath .dd build 2>&1 | tee /tmp/salehman_calcwave2_build.log | tail -5
```
**EXPECTED OUTPUT:** one hit each + `** BUILD SUCCEEDED **`.

**HASTY-MODEL TRAP:** clamping the SHORT branch too "for symmetry" — a short's loss above entry is
genuinely unbounded; clamping it would UNDERSTATE loss and breach the sacred never-understate floor
(LEVERAGE_RISK: accountLossPct is NEVER clamped). Only the long fill has a physical $0 floor.

---

### Step 7 — GapRisk tests for #7/#10 (append to `StockSageGapRiskTests.swift`)

**7a — derivation FIRST:**
```bash
cat > /tmp/derive_gapladder.swift <<'EOF'
// Hand-derivation from the SPEC (LEVERAGE_RISK #1 formulas): long fill = stop·(1−gapPct),
// loss/sh = entry − fill, $ = shares·loss/sh. Fixture: entry 100, stop 95, shares 100.
for g in [0.05, 0.20, 0.35] {
    let fill = 95.0 * (1 - g), loss = 100.0 - fill
    print("gap \(g): fill \(fill)  loss/sh \(loss)  dollars \(100 * loss)")
}
// #10 clamp: gap 1.5 → raw fill 95·(−0.5) = −47.5 → clamped 0 → loss/sh = entry = 100.
print("gap 1.5 raw fill:", 95.0 * (1 - 1.5), "→ clamped 0, loss/sh 100, dollars", 100 * 100.0)
// short is UNCLAMPED: gap 1.5 short → fill 105·2.5 = 262.5, loss/sh 162.5.
print("short gap 1.5 fill:", 105.0 * (1 + 1.5), "loss/sh", 105.0 * 2.5 - 100.0)
EOF
swift /tmp/derive_gapladder.swift
```
**EXPECTED OUTPUT:**
```
gap 0.05: fill 90.25  loss/sh 9.75  dollars 975.0
gap 0.2: fill 76.0  loss/sh 24.0  dollars 2400.0
gap 0.35: fill 61.75  loss/sh 38.25  dollars 3825.0
gap 1.5 raw fill: -47.5 → clamped 0, loss/sh 100, dollars 10000.0
short gap 1.5 fill: 262.5 loss/sh 162.5
```

**7b — append INSIDE `struct StockSageGapRiskTests` (before its closing `}`; anchor: the final
existing `#expect(GR.scenario(side: .short, entry: 100, stop: 95, shares: 100, gapPct: 0.1, accountEquity: 10_000) == nil)`
line and the two closing braces after it):**
```swift
    @Test func worstCaseSortsAnyCallerLadderAscending() {
        // #7 — derive_gapladder: sorted [.05,.20,.35] → $975, $2400, $3825 ascending,
        // regardless of the caller passing [0.20, 0.05, 0.35].
        let wc = GR.worstCase(side: .long, entry: 100, stop: 95, shares: 100,
                              accountEquity: 10_000, gaps: [0.20, 0.05, 0.35])
        #expect(wc.count == 3)
        #expect(wc.map(\.gapPct) == [0.05, 0.20, 0.35])
        #expect(abs(wc[0].dollarsLost - 975) < 1e-9)
        #expect(abs(wc[1].dollarsLost - 2400) < 1e-9)
        #expect(abs(wc[2].dollarsLost - 3825) < 1e-9)
    }

    @Test func longGapBeyondFullWipeoutClampsFillAtZeroShortStaysUnclamped() {
        // #10 — derive_gapladder: long gap 1.5 → fill max(0, −47.5) = 0, loss/sh = entry = 100
        // (a total wipeout, not a negative price); the SHORT side must stay unclamped (262.5).
        let long = GR.scenario(side: .long, entry: 100, stop: 95, shares: 100, gapPct: 1.5, accountEquity: 10_000)
        #expect(long != nil && long!.gapFillPrice == 0)
        #expect(long != nil && abs(long!.lossPerShare - 100) < 1e-9 && abs(long!.dollarsLost - 10_000) < 1e-9)
        let short = GR.scenario(side: .short, entry: 100, stop: 105, shares: 100, gapPct: 1.5, accountEquity: 10_000)
        #expect(short != nil && abs(short!.gapFillPrice - 262.5) < 1e-9 && abs(short!.lossPerShare - 162.5) < 1e-9)
    }
```

**7c — Verify:**
```bash
xcodebuild test -scheme "Salehman AI" -destination 'platform=macOS' -configuration Debug CODE_SIGNING_ALLOWED=NO -derivedDataPath .dd -only-testing:"Salehman AITests/StockSageGapRiskTests" 2>&1 | tee /tmp/salehman_calcwave2_build.log | tail -8
grep -o "StockSageGapRiskTests/[a-zA-Z]*()" /tmp/salehman_calcwave2_build.log | sort -u
```
**EXPECTED OUTPUT:** `** TEST SUCCEEDED **` + 3 named cases (the pre-existing
`gapRiskExceedsOneRAndCanExceedAccount` and the 2 new ones).

**7d — Falsifiability probe:** flip `== [0.05, 0.20, 0.35]` → `== [0.20, 0.05, 0.35]`, re-run →
`** TEST FAILED **` naming `worstCaseSortsAnyCallerLadderAscending()`; restore → green. Paste both.

**HASTY-MODEL TRAP:** asserting only "ascending" (`zip(wc, wc.dropFirst()).allSatisfy(<)`) without
the exact gapPct order — with the old unsorted code and the DEFAULT ladder that assertion is
already green (F40 shape: a test that can't fail on the bug it claims to pin). The unsorted-input
fixture + exact-order assert is the point.

---

### Step 8 — Gap-row tooltip gains the full worstCase ladder (BUGHUNT #2 residual)

**File:** `Salehman AI/Views/MarketsView.swift` · **Anchor:** the gap-risk block in
`positionSizerPanel` (lines ~4282–4291, unique per PF-8's `gapPct: 0.20, accountEquity: acct` hit).

**OLD (exact):**
```swift
                    // Gap risk: a stop is a TRIGGER, not a fill — show the worst-case 20% gap-through loss.
                    let gapSide: TradeSide = isShortIdea ? .short : .long
                    if let gap = StockSageGapRisk.scenario(side: gapSide, entry: entry, stop: stop,
                                                           shares: Double(ps.shares), gapPct: 0.20, accountEquity: acct) {
                        Text("⚠︎ " + gap.verdict)
                            .font(.system(size: mvFont9))
                            .foregroundStyle(gap.exceedsAccount ? DS.Palette.danger : DS.Palette.warningSoft)
                            .fixedSize(horizontal: false, vertical: true)
                            .help(StockSageGapRisk.caveat)
                            .accessibilityLabel("Gap risk warning. " + gap.verdict)
                    }
```
**NEW:**
```swift
                    // Gap risk: a stop is a TRIGGER, not a fill — show the worst-case 20% gap-through loss.
                    let gapSide: TradeSide = isShortIdea ? .short : .long
                    if let gap = StockSageGapRisk.scenario(side: gapSide, entry: entry, stop: stop,
                                                           shares: Double(ps.shares), gapPct: 0.20, accountEquity: acct) {
                        // BUGHUNT_NEWENGINES #2 residual: the row keeps the single 20% headline;
                        // the hover tooltip now carries the FULL what-if ladder (weekend 5% /
                        // earnings 8% / crypto-flash 20% / halt-reopen 35%) — the "a stop is not
                        // a fill" table, without adding card height. Illustrative magnitudes,
                        // never probabilities (the caveat leads the tooltip and says so).
                        let ladder = StockSageGapRisk.worstCase(side: gapSide, entry: entry, stop: stop,
                                                                shares: Double(ps.shares), accountEquity: acct)
                            .map { "• " + $0.verdict }.joined(separator: "\n")
                        Text("⚠︎ " + gap.verdict)
                            .font(.system(size: mvFont9))
                            .foregroundStyle(gap.exceedsAccount ? DS.Palette.danger : DS.Palette.warningSoft)
                            .fixedSize(horizontal: false, vertical: true)
                            .help(ladder.isEmpty ? StockSageGapRisk.caveat : StockSageGapRisk.caveat + "\n\n" + ladder)
                            .accessibilityLabel("Gap risk warning. " + gap.verdict)
                    }
```

**Verify:**
```bash
grep -n "StockSageGapRisk.worstCase" "Salehman AI/Views/MarketsView.swift"
xcodebuild -scheme "Salehman AI" -destination 'platform=macOS' -configuration Debug CODE_SIGNING_ALLOWED=NO -derivedDataPath .dd build 2>&1 | tee /tmp/salehman_calcwave2_build.log | tail -5
```
**EXPECTED OUTPUT:** exactly 1 hit (~4290) + `** BUILD SUCCEEDED **`.

**HASTY-MODEL TRAP:** rendering the ladder as VISIBLE rows (`ForEach`) — that restructures the
sizer panel (visual-QA-gated, register entry 2 chose the tooltip). Also: don't drop the
`ladder.isEmpty` fallback — `worstCase` composes `scenario`, which can return [] for degenerate
inputs the outer `if let gap` didn't fully exclude; an empty-suffixed tooltip must still carry the
caveat.

---

### Step 9 — CapitalAllocator: total-order deterministic sort (#8)

**File:** `Salehman AI/StockSage/StockSageCapitalAllocator.swift` · **Anchor:** the Step-5 sort
(line ~131, unique per PF-4).

**OLD (exact):**
```swift
        // Step 5: realized heat + deterministic order (desc risk, tie-break asc symbol).
        let totalHeat = positions.reduce(0) { $0 + $1.dollarsAtRisk } / account
        let sorted = positions.sorted { $0.riskFraction != $1.riskFraction ? $0.riskFraction > $1.riskFraction : $0.symbol < $1.symbol }
```
**NEW:**
```swift
        // Step 5: realized heat + deterministic order (desc risk, tie-break asc symbol).
        let totalHeat = positions.reduce(0) { $0 + $1.dollarsAtRisk } / account
        let sorted = positions.sorted(by: positionOrder)
```

Then append the comparator INSIDE `enum StockSageCapitalAllocator`, directly ABOVE
`nonisolated static func suggestAdd(` (unique anchor: the doc comment line
`    /// Marginal sizing for ONE new idea against the LIVE book — "I have an idea + an open`):

**OLD (exact):**
```swift
    /// Marginal sizing for ONE new idea against the LIVE book — "I have an idea + an open
```
**NEW:**
```swift
    /// #8 (BUGHUNT_NEWENGINES): the position sort is a TOTAL order, not just (risk desc, symbol
    /// asc). `Array.sorted(by:)` is not guaranteed stable, so two rows tying on BOTH keys
    /// (duplicate symbols at equal half-Kelly — the allocator does not dedup symbols) previously
    /// had unspecified relative order, defeating this file's "Pure + deterministic" contract.
    /// Chain: riskFraction desc → symbol asc (raw `<`: "BTC" < "btc", case pairs never tie —
    /// deliberate, keeps every pre-existing distinct-symbol order byte-identical) →
    /// dollarsAtRisk desc → notional desc. Exposed (not private) so the test can pin the chain.
    nonisolated static func positionOrder(_ a: AllocatedPosition, _ b: AllocatedPosition) -> Bool {
        if a.riskFraction != b.riskFraction { return a.riskFraction > b.riskFraction }
        if a.symbol != b.symbol { return a.symbol < b.symbol }
        if a.dollarsAtRisk != b.dollarsAtRisk { return a.dollarsAtRisk > b.dollarsAtRisk }
        return a.notional > b.notional
    }

    /// Marginal sizing for ONE new idea against the LIVE book — "I have an idea + an open
```

Append to `Salehman AITests/StockSageCapitalAllocatorTests.swift` (inside its struct, before the
closing brace). Fixtures are hand-built `AllocatedPosition` values — no engine call, nothing to
derive beyond reading the chain:
```swift
    @Test func positionOrderIsATotalOrderOverTheDocumentedChain() {
        func pos(_ symbol: String, risk: Double, dollars: Double, notional: Double) -> AllocatedPosition {
            AllocatedPosition(symbol: symbol, riskFraction: risk, shares: 1,
                              dollarsAtRisk: dollars, notional: notional, halfKelly: 0.1, evR: 1.0)
        }
        typealias CA = StockSageCapitalAllocator
        // 1. riskFraction desc dominates everything.
        #expect(CA.positionOrder(pos("ZZZ", risk: 0.03, dollars: 1, notional: 1), pos("AAA", risk: 0.02, dollars: 999, notional: 999)))
        // 2. symbol asc breaks a risk tie ("BTC" < "btc" raw compare — case pairs don't tie).
        #expect(CA.positionOrder(pos("AAA", risk: 0.02, dollars: 1, notional: 1), pos("BBB", risk: 0.02, dollars: 999, notional: 999)))
        #expect(CA.positionOrder(pos("BTC", risk: 0.02, dollars: 1, notional: 1), pos("btc", risk: 0.02, dollars: 999, notional: 999)))
        // 3. NEW: duplicate symbol + equal risk → dollarsAtRisk desc decides (was unspecified).
        #expect(CA.positionOrder(pos("AAA", risk: 0.02, dollars: 995, notional: 9900), pos("AAA", risk: 0.02, dollars: 990, notional: 9950)))
        #expect(!CA.positionOrder(pos("AAA", risk: 0.02, dollars: 990, notional: 9950), pos("AAA", risk: 0.02, dollars: 995, notional: 9900)))
        // 4. NEW: …then notional desc.
        #expect(CA.positionOrder(pos("AAA", risk: 0.02, dollars: 995, notional: 9950), pos("AAA", risk: 0.02, dollars: 995, notional: 9900)))
        // 5. Strict-weak-ordering sanity: fully equal rows are incomparable in BOTH directions.
        let x = pos("AAA", risk: 0.02, dollars: 995, notional: 9950)
        #expect(!CA.positionOrder(x, x))
    }
```

**Verify:**
```bash
xcodebuild test -scheme "Salehman AI" -destination 'platform=macOS' -configuration Debug CODE_SIGNING_ALLOWED=NO -derivedDataPath .dd -only-testing:"Salehman AITests/StockSageCapitalAllocatorTests" 2>&1 | tee /tmp/salehman_calcwave2_build.log | tail -8
grep -o "positionOrderIsATotalOrderOverTheDocumentedChain()" /tmp/salehman_calcwave2_build.log | sort -u
```
**EXPECTED OUTPUT:** `** TEST SUCCEEDED **` (the file's PRE-EXISTING tests must also stay green —
the first two comparator keys are byte-identical in behavior) + the named case.
Falsifiability probe: flip assert 3's expectation (`#expect(` → `#expect(!` on the 995-vs-990
line), re-run → red naming the case; restore → green. Paste both.

**HASTY-MODEL TRAP:** normalizing/merging duplicate symbols "properly" instead — that CHANGES
observable output for existing inputs (a ranking/numeric change, honesty-floor gated). The fix is
determinism only: same inputs, one canonical order, all existing distinct-symbol orders unchanged.

---

### Step 10 — LossLimit: weekly window fails CLOSED, never collapses to one day (#9)

**File:** `Salehman AI/StockSage/StockSageLossLimit.swift` · 2 edits.

**10a —** Anchor: line ~56 (PF-5).

**OLD (exact):**
```swift
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? dayStart
```
**NEW:**
```swift
        // #9 fail-CLOSED: if the calendar ever fails to produce a week interval (never, for
        // valid Gregorian dates — but this is a safety breaker), the weekly window must NOT
        // silently collapse to [startOfToday, now] (a guardrail failing OPEN: weekly losses
        // under-counted, no halt on a bad week). Fall back to a trailing 7-day window, which
        // always covers ⊇ any calendar week containing `now` — strictly more conservative.
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: now)?.start
            ?? sevenDayFallbackStart(dayStart: dayStart, calendar: calendar)
```

**10b —** Append the helper INSIDE `enum StockSageLossLimit`, directly ABOVE
`    /// Aggregate realized losses + the consecutive-loss run vs \`policy\`. Open trades (no`
(unique anchor):

**OLD (exact):**
```swift
    /// Aggregate realized losses + the consecutive-loss run vs `policy`. Open trades (no
```
**NEW:**
```swift
    /// #9's fail-closed fallback: the start of a trailing 7-day window (dayStart − 6 days).
    /// Any calendar week containing `now` starts at most 6 days before today's start, so
    /// [dayStart − 6d, now] ⊇ [weekStart, now] — the fallback can only count MORE losses than
    /// the real week (halt earlier), never fewer. Exposed (not private) so the test pins it.
    nonisolated static func sevenDayFallbackStart(dayStart: Date, calendar: Calendar = utcCalendar) -> Date {
        calendar.date(byAdding: .day, value: -6, to: dayStart) ?? dayStart.addingTimeInterval(-6 * 86_400)
    }

    /// Aggregate realized losses + the consecutive-loss run vs `policy`. Open trades (no
```

Append to `Salehman AITests/StockSageLossLimitTests.swift` (inside its struct, before the closing
brace). Derivation: 6 days × 86 400 s = **518 400 s** (UTC Gregorian has no DST, so
`date(byAdding: .day, -6)` is exactly −518 400 s — hand arithmetic, in the comment):
```swift
    @Test func weeklyFallbackWindowIsSevenDaysNotOneDay() {
        // #9 — fail-closed: the fallback start is dayStart − 6·86 400 s = −518 400 s exactly
        // (UTC Gregorian, no DST). The OLD code fell back to dayStart itself: a weekly gate
        // scoped to a single day, silently failing open.
        let dayStart = Date(timeIntervalSince1970: 1_751_500_800)
        let fallback = StockSageLossLimit.sevenDayFallbackStart(dayStart: dayStart)
        #expect(fallback.timeIntervalSince1970 == 1_751_500_800 - 518_400)
        #expect(fallback < dayStart)   // the property the old `?? dayStart` violated
    }
```

**Verify:**
```bash
xcodebuild test -scheme "Salehman AI" -destination 'platform=macOS' -configuration Debug CODE_SIGNING_ALLOWED=NO -derivedDataPath .dd -only-testing:"Salehman AITests/StockSageLossLimitTests" 2>&1 | tee /tmp/salehman_calcwave2_build.log | tail -8
grep -o "weeklyFallbackWindowIsSevenDaysNotOneDay()" /tmp/salehman_calcwave2_build.log | sort -u
```
**EXPECTED OUTPUT:** `** TEST SUCCEEDED **` with the file's pre-existing tests still green (the
normal weekly path is byte-identical — only the never-taken `??` arm changed) + the named case.
Falsifiability probe: change `- 518_400` → `- 604_800`, re-run → red naming the case; restore →
green. Paste both.

**HASTY-MODEL TRAP:** trying to force the nil `dateInterval` path in a test — `Calendar` is a
struct (not subclassable) and never returns nil for valid Gregorian dates; the honest pin is the
FALLBACK COMPUTATION as a named, exposed helper. Do not fabricate an exotic calendar fixture to
"cover" an unreachable branch, and do not delete the `?? …` arm as dead code — it is the breaker's
belt-and-suspenders (fail-closed defense in depth).

**WIP commit** after each of Steps 6–10 (files by name, message `wip: calc-wave-2 step <k> — …`).

---

# ITEM C — Crypto cost honesty (CRYPTO_RISK.md #1–#4, engine-first, all UNWIRED into production ranking)

Register entries 5 & 7 bound this item: `defaultCosts` stays byte-identical; no UI wiring this
wave. Dependency order (from the doc): #1 → #3 → #2(wires #3) → #4. Every constant below is a
LABELED ESTIMATE BAND midpoint, never a venue quote.

### Step 11 — CRYPTO_RISK #1: tier-aware `CryptoCostEstimate` (new accessor on StockSageNetEdge)

**11a — derivation FIRST:**
```bash
cat > /tmp/derive_cryptocost.swift <<'EOF'
// Hand-derivation from the SPEC (CRYPTO_RISK.md #1 band anchors; roundTrip = 2·halfSpread +
// slippage + 2·takerPerSide; low/high = same formula over the band ends). Midpoints by hand:
// majorBTCETH: half 1-3→2, slip 3-8→5.5, taker 8-20→14 ; large: 5.5, 14, 17.5 ;
// mid: 17.5, 40, 25 ; thin: 55, 130, 30.
let tiers: [(String, Double, Double, Double, (Double, Double, Double), (Double, Double, Double))] = [
    ("major", 2, 5.5, 14, (1, 3, 8),  (3, 8, 20)),
    ("large", 5.5, 14, 17.5, (3, 8, 10), (8, 20, 25)),
    ("mid", 17.5, 40, 25, (10, 20, 15), (25, 60, 35)),
    ("thin", 55, 130, 30, (30, 60, 20), (80, 200, 40)),
]
for (name, h, s, t, lo, hi) in tiers {
    let rt = 2*h + s + 2*t
    let low = 2*lo.0 + lo.1 + 2*lo.2, high = 2*hi.0 + hi.1 + 2*hi.2
    print("\(name): roundTrip \(rt)  low \(low)  high \(high)  band-ok \(low < rt && rt < high)")
}
// Composition through NetEdge.evaluate (entry 100, stop 90, target 130; formulas from the file
// header: cost = bps/10000·entry; netReward = 30 − cost; netRisk = 10 + cost; netRR = nR/nRk):
for (name, bps) in [("major", 37.5), ("thin", 300.0)] {
    let cost = bps / 10_000 * 100.0
    print("\(name): cost \(cost)  netRR \((30 - cost) / (10 + cost))")
}
EOF
swift /tmp/derive_cryptocost.swift
```
**EXPECTED OUTPUT:**
```
major: roundTrip 37.5  low 21.0  high 54.0  band-ok true
large: roundTrip 60.0  low 34.0  high 86.0  band-ok true
mid: roundTrip 125.0  low 70.0  high 180.0  band-ok true
thin: roundTrip 300.0  low 160.0  high 440.0  band-ok true
major: cost 0.375  netRR 2.855421686746988
thin: cost 3.0  netRR 2.076923076923077
```

**11b — File:** `Salehman AI/StockSage/StockSageNetEdge.swift` · **Anchor:** the file's final lines
(unique tail). Append an extension AFTER the closing brace.

**OLD (exact — the current end of file):**
```swift
        return NetEdge(grossRR: grossRR, netRR: netRR, costPerShare: cost,
                       costAsPctOfReward: costPct, netExpectancyR: netExpR,
                       breakEvenWinRate: breakEven, verdict: verdict)
    }
}
```
**NEW:**
```swift
        return NetEdge(grossRR: grossRR, netRR: netRR, costPerShare: cost,
                       costAsPctOfReward: costPct, netExpectancyR: netExpR,
                       breakEvenWinRate: breakEven, verdict: verdict)
    }
}

// MARK: - Tier-aware crypto round-trip cost estimate (CRYPTO_RISK #1)
//
// The flat crypto default above (70bps) treats BTC and a microcap alt identically. This richer
// estimate tiers by liquidity and itemizes the legs (half-spread crossed twice + slippage +
// taker fee on BOTH fills — the advisor's stop/target are crossing events, not resting limits).
// NEW ACCESSOR ONLY: `defaultCosts` is deliberately UNTOUCHED (byte-identical production
// ranking/gating — re-pointing it is a future owner-reviewed change; see the wave-2 plan's
// REJECTED register). Every band is a LABELED ESTIMATE midpoint, never a venue quote.
extension StockSageNetEdge {
    enum CryptoLiquidityTier: String, Sendable, CaseIterable {
        case majorBTCETH, large, mid, thin
    }

    struct CryptoCostEstimate: Sendable, Equatable {
        let tier: CryptoLiquidityTier
        let halfSpreadBps: Double        // one crossing; paid twice per round trip
        let slippageBps: Double          // round-trip
        let takerFeeBpsPerSide: Double   // per fill; paid twice per round trip
        let estimateLowBps: Double       // band edges — surfaced so no UI can show a false point
        let estimateHighBps: Double
        let assetClass: String           // always "crypto"
        let isEstimate: Bool             // always true
        nonisolated var roundTripBps: Double { 2 * halfSpreadBps + slippageBps + 2 * takerFeeBpsPerSide }
        nonisolated var disclaimer: String { "ESTIMATE only — your venue/tier/size differ; not a quote and not a promise." }
        /// Bridge into the existing `evaluate()` seam. CostAssumption's spread/slippage/taker are
        /// ROUND-TRIP by convention (see `defaultCosts`' 70bps comment), so: spread = 2·half,
        /// taker = 2·perSide.
        nonisolated var asCostAssumption: CostAssumption {
            CostAssumption(spreadBps: 2 * halfSpreadBps, slippageBps: slippageBps,
                           assetClass: assetClass, takerFeeBps: 2 * takerFeeBpsPerSide)
        }
    }

    /// Liquidity tier from the symbol + (optional) average daily dollar volume. Honesty floor:
    /// an UNKNOWN alt (advDollar nil) is `.mid`, never assumed deep. Reuses the liquidity
    /// engine's existing floors (thinBelow 2M / deepAbove 50M) — no new magic numbers.
    nonisolated static func cryptoTier(forSymbol symbol: String, advDollar: Double?) -> CryptoLiquidityTier {
        let s = symbol.uppercased()
        if s == "BTC-USD" || s == "ETH-USD" { return .majorBTCETH }
        guard let adv = advDollar else { return .mid }
        if adv < StockSageLiquidity.thinBelow { return .thin }
        if adv >= StockSageLiquidity.deepAbove { return .large }
        return .mid
    }

    /// The tier's labeled estimate bands (midpoint anchors hand-derived in the wave-2 plan;
    /// see /tmp/derive_cryptocost.swift): major 37.5bps RT (21–54), large 60 (34–86),
    /// mid 125 (70–180), thin 300 (160–440).
    nonisolated static func cryptoCosts(forSymbol symbol: String, advDollar: Double?) -> CryptoCostEstimate {
        switch cryptoTier(forSymbol: symbol, advDollar: advDollar) {
        case .majorBTCETH:
            return CryptoCostEstimate(tier: .majorBTCETH, halfSpreadBps: 2, slippageBps: 5.5,
                                      takerFeeBpsPerSide: 14, estimateLowBps: 21, estimateHighBps: 54,
                                      assetClass: "crypto", isEstimate: true)
        case .large:
            return CryptoCostEstimate(tier: .large, halfSpreadBps: 5.5, slippageBps: 14,
                                      takerFeeBpsPerSide: 17.5, estimateLowBps: 34, estimateHighBps: 86,
                                      assetClass: "crypto", isEstimate: true)
        case .mid:
            return CryptoCostEstimate(tier: .mid, halfSpreadBps: 17.5, slippageBps: 40,
                                      takerFeeBpsPerSide: 25, estimateLowBps: 70, estimateHighBps: 180,
                                      assetClass: "crypto", isEstimate: true)
        case .thin:
            return CryptoCostEstimate(tier: .thin, halfSpreadBps: 55, slippageBps: 130,
                                      takerFeeBpsPerSide: 30, estimateLowBps: 160, estimateHighBps: 440,
                                      assetClass: "crypto", isEstimate: true)
        }
    }
}
```

**11c — NEW `Salehman AITests/StockSageCryptoCostTests.swift` (complete):**
```swift
import Testing
@testable import Salehman_AI

// MARK: - Tier-aware crypto cost estimate (CRYPTO_RISK #1)
//
// All literals hand-derived in /tmp/derive_cryptocost.swift (output pasted in
// plans/PLAN_2026-07-03_calc_wave2_cost_honesty.md Step 11a) — never from the code under test.

struct StockSageCryptoCostTests {
    typealias NE = StockSageNetEdge

    @Test func tierMappingHonorsHonestyFloor() {
        // Majors are majors regardless of a (noisy) advDollar — even one below the thin floor.
        #expect(NE.cryptoTier(forSymbol: "BTC-USD", advDollar: nil) == .majorBTCETH)
        #expect(NE.cryptoTier(forSymbol: "eth-usd", advDollar: 1_000) == .majorBTCETH)
        // Unknown depth is NOT assumed liquid: nil → .mid.
        #expect(NE.cryptoTier(forSymbol: "DOGE-USD", advDollar: nil) == .mid)
        // Straddle the reused liquidity floors (thinBelow 2M, deepAbove 50M — PF-11):
        #expect(NE.cryptoTier(forSymbol: "ALT-USD", advDollar: 1_999_999) == .thin)
        #expect(NE.cryptoTier(forSymbol: "ALT-USD", advDollar: 2_000_000) == .mid)
        #expect(NE.cryptoTier(forSymbol: "ALT-USD", advDollar: 49_999_999) == .mid)
        #expect(NE.cryptoTier(forSymbol: "ALT-USD", advDollar: 50_000_000) == .large)
    }

    @Test func frictionIsStrictlyMonotonicAcrossTiersAndBandsBracketTheMidpoint() {
        // derive_cryptocost: RT 37.5 < 60 < 125 < 300; low < RT < high per tier.
        let major = NE.cryptoCosts(forSymbol: "BTC-USD", advDollar: nil)
        let large = NE.cryptoCosts(forSymbol: "ALT-USD", advDollar: 60_000_000)
        let mid   = NE.cryptoCosts(forSymbol: "ALT-USD", advDollar: 10_000_000)
        let thin  = NE.cryptoCosts(forSymbol: "ALT-USD", advDollar: 1_000_000)
        #expect(abs(major.roundTripBps - 37.5) < 1e-9 && abs(large.roundTripBps - 60) < 1e-9)
        #expect(abs(mid.roundTripBps - 125) < 1e-9 && abs(thin.roundTripBps - 300) < 1e-9)
        for e in [major, large, mid, thin] {
            #expect(e.estimateLowBps < e.roundTripBps && e.roundTripBps < e.estimateHighBps)
            // Algebra: roundTrip == 2·half + slip + 2·taker to 1e-9.
            #expect(abs(e.roundTripBps - (2 * e.halfSpreadBps + e.slippageBps + 2 * e.takerFeeBpsPerSide)) < 1e-9)
        }
    }

    @Test func composesThroughTheUnchangedEvaluateSeam() {
        // derive_cryptocost: entry 100 / stop 90 / target 130 → major netRR 2.85542…,
        // thin netRR 2.07692… — both in (0, gross 3.0), thin strictly worse than major.
        let major = NE.cryptoCosts(forSymbol: "BTC-USD", advDollar: nil).asCostAssumption
        let thin  = NE.cryptoCosts(forSymbol: "ALT-USD", advDollar: 1_000_000).asCostAssumption
        let neMajor = NE.evaluate(entry: 100, stop: 90, target: 130, spreadBps: major.spreadBps,
                                  slippageBps: major.slippageBps, takerFeeBps: major.takerFeeBps)
        let neThin = NE.evaluate(entry: 100, stop: 90, target: 130, spreadBps: thin.spreadBps,
                                 slippageBps: thin.slippageBps, takerFeeBps: thin.takerFeeBps)
        guard let neMajor, let neThin else { Issue.record("evaluate returned nil on a clean setup"); return }
        #expect(abs(neMajor.netRR - 2.855421686746988) < 1e-9)
        #expect(abs(neThin.netRR - 2.076923076923077) < 1e-9)
        #expect(neThin.netRR < neMajor.netRR && neMajor.netRR < 3.0 && neThin.netRR > 0)
    }

    @Test func estimateNeverReadsAsAQuoteAndDefaultsStayByteIdentical() {
        let e = NE.cryptoCosts(forSymbol: "BTC-USD", advDollar: nil)
        #expect(e.isEstimate)
        let d = e.disclaimer.lowercased()
        #expect(d.contains("estimate") && !d.contains("guarantee") && !d.contains("guaranteed"))
        // Backward-compat (register entry 5): production defaults UNCHANGED — 70bps crypto.
        #expect(NE.defaultCosts(forSymbol: "BTC-USD").roundTripBps == 70)
        #expect(NE.defaultCosts(forSymbol: "BTC-USD").takerFeeBps == 20)
    }
}
```

**11d — Verify:**
```bash
xcodebuild test -scheme "Salehman AI" -destination 'platform=macOS' -configuration Debug CODE_SIGNING_ALLOWED=NO -derivedDataPath .dd -only-testing:"Salehman AITests/StockSageCryptoCostTests" -only-testing:"Salehman AITests/StockSageNetEdgeTests" 2>&1 | tee /tmp/salehman_calcwave2_build.log | tail -10
grep -o "StockSageCryptoCostTests/[a-zA-Z]*()" /tmp/salehman_calcwave2_build.log | sort -u
```
**EXPECTED OUTPUT:** `** TEST SUCCEEDED **` — BOTH suites (the pre-existing NetEdge suite proves
`defaultCosts`/`evaluate` byte-compat) + the 4 named CryptoCost cases.
**Falsifiability probe:** change `37.5` → `38.5` in the monotonic test, re-run → red naming it;
restore → green. Paste both.

**HASTY-MODEL TRAP:** "reconciling" CRYPTO_RISK.md's stale `50bps` collision note by editing
`defaultCosts` or `StockSageNetEdgeTests.swift:72` — register entry 5 REJECTED that; the doc is
stale, the tree is truth (70bps, taker included). Second trap: making `asCostAssumption` pass
`takerFeeBps: takerFeeBpsPerSide` (per-side) — `CostAssumption.takerFeeBps` is ROUND-TRIP by
convention (the 70bps comment: "20" = ~0.1%/fill × 2); halving it would understate crypto cost
through the whole evaluate path.

---

### Step 12a — CRYPTO_RISK #3: NEW `Salehman AI/StockSage/StockSageCryptoLiquidityGate.swift` (complete)

```swift
import Foundation

// MARK: - Crypto liquidity gate (CRYPTO_RISK #3)
//
// Two crypto-specific overstatements the backtester cannot see: (1) on a thin alt, a modeled
// stop/target "fill" exceeds the visible book — the fill is fiction (partial fills walking the
// book, or no fill); (2) 24/7 books thin on weekends/off-hours and stops blow through far past
// the level. This gate classifies tradability from the symbol's OWN history (ADV$ + worst
// adverse open-vs-prior-close drift) and composes IN FRONT of StockSageCryptoHonesty: a thin
// gate forces "unproven" (an unfillable edge is not an edge). nil for non-crypto — equities are
// byte-identical. Yahoo crypto volume is venue-AGGREGATED, so it OVERSTATES any single book you
// would actually trade — the floors are deliberately conservative, LABELED ESTIMATES, not
// fillability promises. Pure + deterministic; no network.

struct CryptoLiquidityGate: Sendable, Equatable {
    let advDollar: Double?            // ~average daily $ volume over the window; nil = unknown
    let isThinForCrypto: Bool
    let cryptoThinFloor: Double       // the floor used, surfaced for labeling
    let maxAdverseGapPct: Double      // worst (priorClose − nextOpen)/priorClose in sample, ≥ 0
    let recommendation: String        // "skip" | "limit-only, size down" | "tradeable"
    let note: String
}

enum StockSageCryptoLiquidityGate {
    /// LABELED ESTIMATE, owner-tunable: below ~this venue-aggregated ADV$, treat a crypto name
    /// as unfillable at advisor size (recommendation "skip"). NOT a measured microstructure fact.
    nonisolated static let cryptoThinFloorUSD = 5_000_000.0
    /// Between the thin floor and this ceiling: fills are plausible but the book is shallow —
    /// resting limits only, sized down. 4× the floor; same labeled-estimate status.
    nonisolated static let cautionCeilingUSD = 20_000_000.0

    /// Mean of close·volume over the trailing `window` bars. nil on mismatched/empty inputs or
    /// a non-positive result (no usable volume — unknown, never assumed liquid).
    nonisolated static func averageDollarVolume(closes: [Double], volumes: [Double], window: Int = 20) -> Double? {
        guard closes.count == volumes.count, !closes.isEmpty else { return nil }
        let n = Swift.min(Swift.max(1, window), closes.count)
        let sum = zip(closes.suffix(n), volumes.suffix(n)).reduce(0.0) { $0 + $1.0 * $1.1 }
        let adv = sum / Double(n)
        return adv > 0 ? adv : nil
    }

    /// Worst adverse "overnight" drift: max over i of (closes[i−1] − opens[i]) / closes[i−1],
    /// clamped ≥ 0. 0 when nothing gapped down, lengths mismatch, or < 2 bars (no crash, no
    /// fabricated read). On 24/7 UTC-bucketed candles there is no literal session close — this
    /// measures real prior-close-vs-next-open drift, descriptive of the past, not predictive.
    nonisolated static func maxAdverseOvernightGapPct(opens: [Double], closes: [Double]) -> Double {
        guard opens.count == closes.count, closes.count >= 2 else { return 0 }
        var worst = 0.0
        for i in 1..<closes.count {
            let prior = closes[i - 1]
            guard prior > 0 else { continue }
            worst = Swift.max(worst, (prior - opens[i]) / prior)
        }
        return Swift.max(0, worst)
    }

    /// nil for non-crypto symbols (no "-USD" suffix) — the equity path is untouched.
    nonisolated static func assess(symbol: String, closes: [Double], opens: [Double],
                                   volumes: [Double], window: Int = 20) -> CryptoLiquidityGate? {
        guard symbol.uppercased().hasSuffix("-USD") else { return nil }
        let adv = averageDollarVolume(closes: closes, volumes: volumes, window: window)
        let gap = maxAdverseOvernightGapPct(opens: opens, closes: closes)
        let isThin: Bool
        let recommendation: String
        let note: String
        if let adv {
            isThin = adv < cryptoThinFloorUSD
            if isThin {
                recommendation = "skip"
                note = String(format: "THIN crypto liquidity (~$%.1fM/day est., venue-aggregated — any single book is thinner) — modeled fills are optimistic; real slippage is worse. Worst adverse open gap in sample ≈ %.0f%%.", adv / 1_000_000, gap * 100)
            } else if adv < cautionCeilingUSD {
                recommendation = "limit-only, size down"
                note = String(format: "Shallow crypto book (~$%.1fM/day est.) — resting limits only, size down; modeled fills may be optimistic. Worst adverse open gap in sample ≈ %.0f%%.", adv / 1_000_000, gap * 100)
            } else {
                recommendation = "tradeable"
                note = String(format: "~$%.0fM/day est. (venue-aggregated; overstates any single book). Worst adverse open gap in sample ≈ %.0f%%. Depth is an estimate — it can vanish in a stress event.", adv / 1_000_000, gap * 100)
            }
        } else {
            // Honesty floor: unknown depth is never assumed liquid — but claiming "thin" would
            // fabricate a read we don't have. Middle recommendation, labeled unknown.
            isThin = false
            recommendation = "limit-only, size down"
            note = "Unknown crypto depth (no usable volume data) — est. only; treat fills as limit-only and size down."
        }
        return CryptoLiquidityGate(advDollar: adv, isThinForCrypto: isThin,
                                   cryptoThinFloor: cryptoThinFloorUSD, maxAdverseGapPct: gap,
                                   recommendation: recommendation, note: note)
    }
}
```

**Verify:** build only (tests in 12d):
```bash
grep -n "enum StockSageCryptoLiquidityGate" "Salehman AI/StockSage/StockSageCryptoLiquidityGate.swift"
xcodebuild -scheme "Salehman AI" -destination 'platform=macOS' -configuration Debug CODE_SIGNING_ALLOWED=NO -derivedDataPath .dd build 2>&1 | tee /tmp/salehman_calcwave2_build.log | tail -5
```
**EXPECTED OUTPUT:** the enum hit + `** BUILD SUCCEEDED **`.

**HASTY-MODEL TRAP:** classifying `advDollar == nil` as thin "to be safe" — that FABRICATES a
thin read from no data (nil = unknown, the frozen contract); unknown gets the middle
recommendation with an explicit "unknown" label. Opposite trap: `return 0` from
`averageDollarVolume` on empty input instead of nil — 0 would read as "measured zero volume".

---

### Step 12b — CRYPTO_RISK #2: NEW `Salehman AI/StockSage/StockSageCryptoHonesty.swift` (complete)

```swift
import Foundation

// MARK: - Crypto net-edge honesty (CRYPTO_RISK #2)
//
// A "profitable" crypto backtest can be net-negative invisibly: the equity curve flatters
// crypto because frictions are estimates and nothing reports HOW MUCH of the gross edge was
// friction. This engine runs the SAME real history through the EXISTING backtester three times
// — frictionless, at the tier's midpoint cost estimate, and at the high band — and surfaces the
// single most important honesty fact: did the edge flip from profitable to net-negative after
// costs. COMPOSES StockSageBacktester.run (never re-implements the walk) and CryptoLiquidityGate
// (a thin gate forces "unproven" — an unfillable edge is not an edge). Backward-looking,
// inherits every backtester caveat (survivorship, fixed rules, small samples). Pure.

struct CryptoNetEdgeHonesty: Sendable, Equatable {
    let grossAvgR: Double
    let netAvgRMid: Double
    let netAvgRWorst: Double
    let grossTotalR: Double
    let netTotalRMid: Double
    let netTotalRWorst: Double
    let frictionDragR: Double          // grossAvgR − netAvgRMid, floored at 0
    let trades: Int
    let isSignificant: Bool            // trades ≥ significanceFloor (same 20-trade bar as BacktestResult)
    let edgeSurvivesCostsMid: Bool
    let edgeSurvivesCostsWorst: Bool
    let liquidityGate: CryptoLiquidityGate?   // the gate consulted, surfaced; nil = not assessed
    let verdict: String
    let caveat: String
}

enum StockSageCryptoHonesty {
    nonisolated static let significanceFloor = 20

    nonisolated static let caveat = "A backward-looking estimate on ESTIMATED cost bands — your venue/tier/size differ, and past performance is not predictive. Inherits every backtester caveat (survivorship, fixed rules, sample size). 'Survives costs' means only 'historically net-positive after estimated frictions at this sample size' — never a profit promise. The stop is still the floor."

    /// Pure verdict classifier — split out so every branch is testable with hand numbers
    /// (the flip fixture cannot be honestly hand-derived THROUGH the walk-forward engine;
    /// spec-fidelity forbids deriving it FROM the engine). `thinNote` non-nil = the liquidity
    /// gate found the name thin, which forces "unproven" regardless of the R numbers.
    nonisolated static func classify(grossTotalR: Double, netTotalRMid: Double, netTotalRWorst: Double,
                                     trades: Int, thinNote: String? = nil)
        -> (verdict: String, survivesMid: Bool, survivesWorst: Bool) {
        if let thin = thinNote {
            return (thin + " An unfillable edge is not an edge — treat this backtest as UNPROVEN.", false, false)
        }
        guard trades >= significanceFloor else {
            return ("Too few trades (\(trades)) to judge — noise, not edge.", false, false)
        }
        if grossTotalR <= 0 {
            return ("No edge even BEFORE costs in this sample — nothing for frictions to eat.", false, false)
        }
        if netTotalRMid <= 0 {
            return ("This crypto edge exists ONLY before costs — after est. frictions it is net-negative. Do not trade it.", false, false)
        }
        if netTotalRWorst <= 0 {
            return ("Edge survives midpoint costs but dies under the high-cost estimate — fragile; treat as unproven.", true, false)
        }
        return ("Edge survives the est. cost haircut at this sample size — still an estimate; past performance is not predictive.", true, true)
    }

    /// Three runs of the EXISTING backtester (compose, never duplicate): frictionless, midpoint,
    /// high-band. The worst leg prices the whole high band as spread (taker/slippage already
    /// aggregated into `estimateHighBps` — see the CryptoCostEstimate band derivation).
    nonisolated static func evaluate(_ history: StockSagePriceHistory,
                                     costs: StockSageNetEdge.CryptoCostEstimate,
                                     warmup: Int = 200,
                                     liquidityGate: CryptoLiquidityGate? = nil) -> CryptoNetEdgeHonesty {
        let gross = StockSageBacktester.run(history, warmup: warmup, costs: nil)
        let netMid = StockSageBacktester.run(history, warmup: warmup, costs: costs.asCostAssumption)
        let netWorst = StockSageBacktester.run(history, warmup: warmup,
            costs: StockSageNetEdge.CostAssumption(spreadBps: costs.estimateHighBps, slippageBps: 0,
                                                   assetClass: "crypto-worst"))
        let thinNote: String? = (liquidityGate?.isThinForCrypto == true) ? liquidityGate?.note : nil
        let c = classify(grossTotalR: gross.totalR, netTotalRMid: netMid.totalR,
                         netTotalRWorst: netWorst.totalR, trades: netMid.trades, thinNote: thinNote)
        return CryptoNetEdgeHonesty(grossAvgR: gross.avgR, netAvgRMid: netMid.avgR,
                                    netAvgRWorst: netWorst.avgR, grossTotalR: gross.totalR,
                                    netTotalRMid: netMid.totalR, netTotalRWorst: netWorst.totalR,
                                    frictionDragR: Swift.max(0, gross.avgR - netMid.avgR),
                                    trades: netMid.trades,
                                    isSignificant: netMid.trades >= significanceFloor,
                                    edgeSurvivesCostsMid: c.survivesMid,
                                    edgeSurvivesCostsWorst: c.survivesWorst,
                                    liquidityGate: liquidityGate,
                                    verdict: c.verdict, caveat: caveat)
    }
}
```

**Verify:** build:
```bash
grep -n "enum StockSageCryptoHonesty" "Salehman AI/StockSage/StockSageCryptoHonesty.swift"
xcodebuild -scheme "Salehman AI" -destination 'platform=macOS' -configuration Debug CODE_SIGNING_ALLOWED=NO -derivedDataPath .dd build 2>&1 | tee /tmp/salehman_calcwave2_build.log | tail -5
```
**EXPECTED OUTPUT:** the enum hit + `** BUILD SUCCEEDED **`.

**HASTY-MODEL TRAP:** re-implementing a mini price walk inside `evaluate` "to control the trade
count" — the spec's hard rule is COMPOSE `StockSageBacktester.run` so the gross leg is provably
identical to the real backtester (test 12d pins byte-equality). Second trap: putting the
significance check BEFORE the thin check in `classify` — a thin name with 30 trades would then
read "survives", laundering unfillable fills into a green verdict.

---

### Step 12c — CRYPTO_RISK #4: NEW `Salehman AI/StockSage/StockSageCryptoFunding.swift` (complete)

```swift
import Foundation

// MARK: - Crypto perp funding drag (CRYPTO_RISK #4)
//
// The entire cost stack (NetEdge, Backtester) models ONE-TIME entry/exit frictions. A
// perpetual-futures position — how most LEVERED crypto is actually traded — pays a RECURRING
// funding rate for the whole hold, invisible to a price-only backtest: a 20-day hold at 5×
// positive funding can eat multiple R. This overlay charges an owner-tunable, LABELED
// annualized-funding ESTIMATE BAND against the spot net expectancy. It NEVER fabricates a live
// rate; funding is regime-dependent and can go NEGATIVE (longs get PAID) — the note must say
// so. A pure spot (non-perp) position has no funding leg and simply never calls this. Pure math.

struct CryptoFundingDrag: Sendable, Equatable {
    let leverage: Double
    let holdDays: Double
    let annualFundingBpsLow: Double
    let annualFundingBpsHigh: Double
    let fundingDragRMid: Double        // R eaten at the band midpoint (can be negative — paid)
    let fundingDragRHigh: Double       // R eaten at the band's costly end
    let netEdgeRAfterFunding: Double   // spotNetExpectancyR − fundingDragRMid
    let stillPositiveMid: Bool
    let note: String
    let caveat: String
}

enum StockSageCryptoFunding {
    /// ESTIMATE band ≈ 3%–30% APR — regime-dependent, can be NEGATIVE; owner-tunable, never a
    /// quote. No live/paid funding feed exists in this app; if real rates ever arrive they must
    /// be labeled live-vs-estimate, never hardcoded here.
    nonisolated static let defaultAnnualFundingBps = (low: 300.0, high: 3000.0)

    nonisolated static let caveat = "Funding is the most regime-dependent cost in crypto and the hardest to estimate honestly — this is an owner-tunable ESTIMATE band, not a forecast and never a quote. It can flip sign (a negative-funding regime pays the long side to hold). Applies to perp/levered positions only. The stop is still the floor."

    /// Funding drag in R for a perp position: dailyFunding = annualBps/10 000/365; drag as a
    /// fraction of 1R = leverage · dailyFunding · holdDays ÷ riskFractionOfNotional. nil on
    /// degenerate inputs (leverage ≤ 0, holdDays < 0, riskFraction ≤ 0, or an inverted band).
    nonisolated static func drag(spotNetExpectancyR: Double, riskFractionOfNotional: Double,
                                 leverage: Double, holdDays: Double,
                                 annualFundingBps: (low: Double, high: Double) = defaultAnnualFundingBps)
        -> CryptoFundingDrag? {
        guard leverage > 0, holdDays >= 0, riskFractionOfNotional > 0,
              annualFundingBps.low <= annualFundingBps.high else { return nil }
        func dragR(_ annualBps: Double) -> Double {
            leverage * (annualBps / 10_000 / 365) * holdDays / riskFractionOfNotional
        }
        let mid = dragR((annualFundingBps.low + annualFundingBps.high) / 2)
        let high = dragR(annualFundingBps.high)
        let after = spotNetExpectancyR - mid
        let note = String(format: "Est. funding drag over %.0f day(s) at %.1f×: −%.2fR mid (−%.2fR at the high band) off a %+.2fR spot net edge → %+.2fR left (mid). Funding can flip sign — a negative-funding regime PAYS longs to hold. Estimate, not a forecast; the stop is still your floor.",
                          holdDays, leverage, mid, high, spotNetExpectancyR, after)
        return CryptoFundingDrag(leverage: leverage, holdDays: holdDays,
                                 annualFundingBpsLow: annualFundingBps.low,
                                 annualFundingBpsHigh: annualFundingBps.high,
                                 fundingDragRMid: mid, fundingDragRHigh: high,
                                 netEdgeRAfterFunding: after, stillPositiveMid: after > 0,
                                 note: note, caveat: caveat)
    }
}
```

**Verify:** build (grep the enum + `** BUILD SUCCEEDED **`, same pattern as 12a/12b).

**HASTY-MODEL TRAP:** "fixing" the note's `−%.2fR` for a negative mid drag (paid funding renders
as `−-0.12R`) by clamping mid at 0 — clamping HIDES the negative-funding case the caveat promises
to disclose. If the double-sign rendering offends, the fix is presentation (`%+.2f`), never a
clamp; this plan ships the format exactly as written above.

---

### Step 12d — The three crypto test files (complete) + verify

**Derivation FIRST:**
```bash
cat > /tmp/derive_cryptorisk.swift <<'EOF'
import Foundation
// Gate ADV fixtures (mean of close·volume over the trailing window, window ≥ count → all bars):
print("thin:", (100.0*40_000 + 100.0*59_998) / 2)          // 4_999_900 < 5M floor → skip
print("at floor:", (100.0*40_000 + 100.0*60_000) / 2)      // 5_000_000 == floor → NOT thin → limit-only
print("caution:", (100.0*200_000 + 100.0*199_999) / 2)     // 19_999_950 < 20M → limit-only
print("tradeable:", (100.0*200_000 + 100.0*200_000) / 2)   // 20_000_000 == ceiling → tradeable
// Adverse gap: closes [100, 102, 101], opens [100, 85, 101] → max((100−85)/100, (102−101)/102) = 0.15
print("gap:", max((100.0-85)/100, (102.0-101)/102))
// Uptrend-history gate ADV: closes 100+i (i 0..599), volumes 1000; last 20 closes 680...699,
// mean 689.5 → ADV$ 689_500 < 5M → thin.
print("uptrend adv:", (680...699).reduce(0.0){ $0 + Double($1) } / 20 * 1000)
// Funding algebra (spec test c): lev 1, hold 365, band (3650,3650), risk 0.05:
print("funding 7.3R:", 1.0 * (3650.0/10_000/365) * 365 / 0.05)
// Funding monotonic base: lev 1, hold 10, band (300,3000) → mid 1650, risk 0.05:
print("funding base:", 1.0 * (1650.0/10_000/365) * 10 / 0.05)   // 0.09041095890410959
EOF
swift /tmp/derive_cryptorisk.swift
```
**EXPECTED OUTPUT:**
```
thin: 4999900.0
at floor: 5000000.0
caution: 19999950.0
tradeable: 20000000.0
gap: 0.15
uptrend adv: 689500.0
funding 7.3R: 7.3
funding base: 0.09041095890410959
```

**NEW `Salehman AITests/StockSageCryptoLiquidityGateTests.swift`:**
```swift
import Testing
@testable import Salehman_AI

// MARK: - Crypto liquidity gate (CRYPTO_RISK #3). Literals from /tmp/derive_cryptorisk.swift.

struct StockSageCryptoLiquidityGateTests {
    typealias Gate = StockSageCryptoLiquidityGate

    @Test func adverseGapIsWorstPriorCloseToOpenDrop() {
        // derive: max((100−85)/100, (102−101)/102) = 0.15
        #expect(abs(Gate.maxAdverseOvernightGapPct(opens: [100, 85, 101], closes: [100, 102, 101]) - 0.15) < 1e-9)
        #expect(Gate.maxAdverseOvernightGapPct(opens: [100, 101, 102], closes: [100, 101, 102]) == 0)  // no drop
        #expect(Gate.maxAdverseOvernightGapPct(opens: [100, 85], closes: [100, 102, 101]) == 0)        // mismatch → 0, no crash
        #expect(Gate.maxAdverseOvernightGapPct(opens: [100], closes: [100]) == 0)                      // <2 bars
    }

    @Test func nonCryptoIsNilAndUnknownDepthIsNeverAssumedLiquid() {
        #expect(Gate.assess(symbol: "AAPL", closes: [100, 100], opens: [100, 100], volumes: [1e6, 1e6]) == nil)
        // No usable volume → advDollar nil, NOT thin (no fabricated read), middle recommendation.
        let unknown = Gate.assess(symbol: "ALT-USD", closes: [100, 100], opens: [100, 100], volumes: [0, 0])
        guard let unknown else { Issue.record("crypto assess returned nil"); return }
        #expect(unknown.advDollar == nil && !unknown.isThinForCrypto)
        #expect(unknown.recommendation == "limit-only, size down")
        #expect(unknown.note.lowercased().contains("unknown"))
    }

    @Test func recommendationTiersStraddleTheLabeledFloors() {
        func gate(_ v0: Double, _ v1: Double) -> CryptoLiquidityGate? {
            Gate.assess(symbol: "ALT-USD", closes: [100, 100], opens: [100, 100], volumes: [v0, v1])
        }
        // derive: 4_999_900 < 5M → thin/skip ; 5_000_000 == floor → limit-only ;
        //         19_999_950 < 20M → limit-only ; 20_000_000 == ceiling → tradeable.
        #expect(gate(40_000, 59_998)?.isThinForCrypto == true && gate(40_000, 59_998)?.recommendation == "skip")
        #expect(gate(40_000, 60_000)?.isThinForCrypto == false && gate(40_000, 60_000)?.recommendation == "limit-only, size down")
        #expect(gate(200_000, 199_999)?.recommendation == "limit-only, size down")
        #expect(gate(200_000, 200_000)?.recommendation == "tradeable")
    }

    @Test func notesStayHonest() {
        let thin = Gate.assess(symbol: "ALT-USD", closes: [100, 100], opens: [100, 100], volumes: [40_000, 59_998])
        guard let thin else { Issue.record("thin gate nil"); return }
        let n = thin.note.lowercased()
        #expect(n.contains("thin") && n.contains("optimistic") && n.contains("est"))
        for g in [thin] {
            let all = (g.note + " " + g.recommendation).lowercased()
            #expect(!all.contains("guarantee") && !all.contains("risk-free") && !all.contains("safe"))
        }
    }
}
```

**NEW `Salehman AITests/StockSageCryptoHonestyTests.swift`:**
```swift
import Testing
import Foundation
@testable import Salehman_AI

// MARK: - Crypto net-edge honesty (CRYPTO_RISK #2)
//
// classify() branches take HAND numbers (spec-fidelity: a "flip" fixture cannot be derived
// THROUGH the walk-forward engine); evaluate() is pinned by INVARIANTS on the house's own
// 600-bar uptrend fixture (StockSageBacktestTests precedent: it provably produces winning
// trades) plus byte-equality of the gross leg against an independent run — compose-not-duplicate.

struct StockSageCryptoHonestyTests {
    typealias H = StockSageCryptoHonesty

    private func uptrendHistory() -> StockSagePriceHistory {
        // Same shape as StockSageBacktestTests.cleanUptrendProducesWinningTargetTrades:
        // 100 → 699 over 600 bars, ~0.17%/day, vol ≈ 2.7% ⇒ buy signals fire normally.
        let closes = (0..<600).map { 100.0 + Double($0) }
        return StockSagePriceHistory(
            symbol: "TST-USD",
            dates: closes.enumerated().map { Date(timeIntervalSince1970: Double($0.offset) * 86_400) },
            opens: closes, highs: closes.map { $0 + 1 }, lows: closes.map { $0 - 1 },
            closes: closes, volumes: closes.map { _ in 1000 })
    }

    @Test func classifyCoversEveryVerdictBranchHonestly() {
        // Hand numbers; branch order matters (thin → noise → no-gross → flip → fragile → survives).
        let thin = H.classify(grossTotalR: 9, netTotalRMid: 8, netTotalRWorst: 7, trades: 30,
                              thinNote: "THIN crypto liquidity (~$3.0M/day est.) — modeled fills are optimistic.")
        #expect(!thin.survivesMid && !thin.survivesWorst && thin.verdict.contains("UNPROVEN"))
        let noise = H.classify(grossTotalR: 9, netTotalRMid: 8, netTotalRWorst: 7, trades: 19)
        #expect(!noise.survivesMid && noise.verdict.contains("noise"))
        let noGross = H.classify(grossTotalR: -1, netTotalRMid: -2, netTotalRWorst: -3, trades: 30)
        #expect(!noGross.survivesMid && noGross.verdict.contains("BEFORE costs"))
        let flip = H.classify(grossTotalR: 5, netTotalRMid: -0.5, netTotalRWorst: -1, trades: 30)
        #expect(!flip.survivesMid && flip.verdict.contains("net-negative") && flip.verdict.contains("Do not trade"))
        let fragile = H.classify(grossTotalR: 5, netTotalRMid: 2, netTotalRWorst: -0.1, trades: 30)
        #expect(fragile.survivesMid && !fragile.survivesWorst && fragile.verdict.contains("fragile"))
        let survives = H.classify(grossTotalR: 5, netTotalRMid: 4, netTotalRWorst: 2, trades: 30)
        #expect(survives.survivesMid && survives.survivesWorst && survives.verdict.contains("estimate"))
        for v in [thin, noise, noGross, flip, fragile, survives] {
            #expect(!v.verdict.lowercased().contains("guarantee") && !v.verdict.lowercased().contains("risk-free"))
        }
    }

    @Test func evaluateComposesTheRealBacktesterExactly() {
        let history = uptrendHistory()
        let costs = StockSageNetEdge.cryptoCosts(forSymbol: "BTC-USD", advDollar: nil)
        let h = H.evaluate(history, costs: costs)
        #expect(h.trades > 0)                                        // hard count FIRST (WHIPPYX)
        let independentGross = StockSageBacktester.run(history, costs: nil)
        #expect(h.grossAvgR == independentGross.avgR && h.grossTotalR == independentGross.totalR)
        #expect(h.netAvgRMid < h.grossAvgR)                          // strict: positive cost, winning trades
        #expect(h.netAvgRWorst <= h.netAvgRMid)                      // high band ≥ midpoint cost
        #expect(h.frictionDragR > 0 && abs(h.frictionDragR - (h.grossAvgR - h.netAvgRMid)) < 1e-12)
        #expect(H.evaluate(history, costs: costs) == h)              // deterministic, byte-equal
    }

    @Test func thinLiquidityGateForcesUnproven() {
        // derive_cryptorisk: the uptrend's own volumes (1000/bar) → ADV$ 689_500 < 5M → thin.
        let history = uptrendHistory()
        let gate = StockSageCryptoLiquidityGate.assess(symbol: "TST-USD", closes: history.closes,
                                                       opens: history.opens, volumes: history.volumes)
        guard let gate else { Issue.record("gate nil for a -USD symbol"); return }
        #expect(gate.isThinForCrypto)
        let h = H.evaluate(history, costs: StockSageNetEdge.cryptoCosts(forSymbol: "TST-USD", advDollar: gate.advDollar),
                           liquidityGate: gate)
        #expect(h.trades > 0)                                        // the numbers were fine…
        #expect(!h.edgeSurvivesCostsMid && !h.edgeSurvivesCostsWorst)  // …but thin forces UNPROVEN
        #expect(h.verdict.contains("UNPROVEN") && h.liquidityGate == gate)
    }

    @Test func caveatIsPermanentAndHedged() {
        let c = StockSageCryptoHonesty.caveat.lowercased()
        #expect(c.contains("estimate") && c.contains("past performance") && !c.contains("guarantee"))
    }
}
```

**NEW `Salehman AITests/StockSageCryptoFundingTests.swift`:**
```swift
import Testing
@testable import Salehman_AI

// MARK: - Crypto perp funding drag (CRYPTO_RISK #4). Literals from /tmp/derive_cryptorisk.swift.

struct StockSageCryptoFundingTests {
    typealias F = StockSageCryptoFunding

    @Test func algebraPinsTheRateDayLeverageChain() {
        // derive: lev 1 · (3650bps/10 000/365) · 365d ÷ 0.05 risk = 7.3R exactly.
        let d = F.drag(spotNetExpectancyR: 10, riskFractionOfNotional: 0.05,
                       leverage: 1, holdDays: 365, annualFundingBps: (low: 3650, high: 3650))
        guard let d else { Issue.record("drag nil on valid inputs"); return }
        #expect(abs(d.fundingDragRMid - 7.3) < 1e-9 && abs(d.fundingDragRHigh - 7.3) < 1e-9)
        #expect(abs(d.netEdgeRAfterFunding - 2.7) < 1e-9 && d.stillPositiveMid)
    }

    @Test func dragIsMonotonicInLeverageHoldAndRate() {
        // derive: base (lev 1, hold 10, band 300–3000 → mid 1650, risk 0.05) = 0.09041095890410959.
        func mid(lev: Double = 1, hold: Double = 10, band: (low: Double, high: Double) = (300, 3000)) -> Double {
            F.drag(spotNetExpectancyR: 1, riskFractionOfNotional: 0.05, leverage: lev,
                   holdDays: hold, annualFundingBps: band)!.fundingDragRMid
        }
        #expect(abs(mid() - 0.09041095890410959) < 1e-9)
        #expect(mid(lev: 2) > mid() && mid(hold: 20) > mid() && mid(band: (600, 6000)) > mid())
        #expect(F.drag(spotNetExpectancyR: 1, riskFractionOfNotional: 0.05, leverage: 1, holdDays: 0)!.fundingDragRMid == 0)
    }

    @Test func fundingCanFlipAPositiveSpotEdgeNegative() {
        // spot +0.5R, drag mid 7.3R → after −6.8R: the sign-flip the spot backtest can't see.
        let d = F.drag(spotNetExpectancyR: 0.5, riskFractionOfNotional: 0.05,
                       leverage: 1, holdDays: 365, annualFundingBps: (low: 3650, high: 3650))
        guard let d else { Issue.record("drag nil"); return }
        #expect(!d.stillPositiveMid && d.netEdgeRAfterFunding < 0)
        #expect(d.note.lowercased().contains("funding"))
        #expect(d.fundingDragRHigh >= d.fundingDragRMid)
    }

    @Test func honestyStringsAndGuards() {
        let d = F.drag(spotNetExpectancyR: 1, riskFractionOfNotional: 0.05, leverage: 2, holdDays: 5)
        guard let d else { Issue.record("drag nil"); return }
        let n = d.note.lowercased(), c = d.caveat.lowercased()
        #expect(n.contains("flip sign") && n.contains("pays"))          // negative-funding disclosure
        #expect(n.contains("not a forecast") && c.contains("estimate")) // 'forecast' only negated
        #expect(!n.contains("guarantee") && !c.contains("guarantee"))
        // Degenerate inputs → nil, never a fake 0-cost read.
        #expect(F.drag(spotNetExpectancyR: 1, riskFractionOfNotional: 0.05, leverage: 0, holdDays: 5) == nil)
        #expect(F.drag(spotNetExpectancyR: 1, riskFractionOfNotional: 0, leverage: 1, holdDays: 5) == nil)
        #expect(F.drag(spotNetExpectancyR: 1, riskFractionOfNotional: 0.05, leverage: 1, holdDays: -1) == nil)
    }
}
```

**Verify (all three suites + the named cases):**
```bash
xcodebuild test -scheme "Salehman AI" -destination 'platform=macOS' -configuration Debug CODE_SIGNING_ALLOWED=NO -derivedDataPath .dd -only-testing:"Salehman AITests/StockSageCryptoLiquidityGateTests" -only-testing:"Salehman AITests/StockSageCryptoHonestyTests" -only-testing:"Salehman AITests/StockSageCryptoFundingTests" 2>&1 | tee /tmp/salehman_calcwave2_build.log | tail -12
grep -oE "StockSageCrypto(LiquidityGate|Honesty|Funding)Tests/[a-zA-Z]*\(\)" /tmp/salehman_calcwave2_build.log | sort -u
```
**EXPECTED OUTPUT:** `** TEST SUCCEEDED **` + exactly 12 named cases (4 per suite).
**Falsifiability probe (one per suite, then restore — paste red+green for each):**
gate: `0.15` → `0.16`; honesty: in `classifyCoversEveryVerdictBranchHonestly` change
`trades: 19` → `trades: 20` (the noise branch must stop firing → red); funding: `7.3` → `7.4`.

**HASTY-MODEL TRAP:** if `thinLiquidityGateForcesUnproven` fails because the uptrend history's
`StockSagePriceHistory` field spelling differs (`opens/highs/lows/closes/volumes` — copy the
EXACT initializer from `StockSageBacktestTests.swift:13-22`), fix the FIXTURE constructor, never
weaken the assertions. If `evaluateComposesTheRealBacktesterExactly` shows `h.trades == 0`, the
history fixture is wrong (warmup eats it) — the house fixture is 600 bars for exactly that
reason; do NOT lower `warmup`.

**WIP commit** after each of Steps 11–12d.

---

# ITEM D — Backtest significance gates the verdict COLOR (AUDIT_FINDINGS_2 #1, display-only)

The color IS the verdict: today an insignificant sample still paints Win/AvgR/TotalR green/red
in BOTH backtest panels; the small-sample warning is only a caption below. Zero numeric change.

### Step 13 — `BacktestVerdict.metricColor` + both panels + test

**13a — the pure helper.** File: `Salehman AI/Views/MarketsView.swift` · **Anchor:** the file's
final line (unique, PF-8: `grep -c "Concrete improvement: EV badge" → 1`).

**OLD (exact — the current last line of the file):**
```swift
// Concrete improvement: EV badge in ideaCard now has accessibilityLabel (a11y gap fixed, DS tokens used, no hardcoded colors) - line ~2610
```
**NEW:**
```swift
// Concrete improvement: EV badge in ideaCard now has accessibilityLabel (a11y gap fixed, DS tokens used, no hardcoded colors) - line ~2610

// MARK: - Backtest verdict color (significance-gated — AUDIT_FINDINGS_2 #1)

/// The green/red on a backtest metric IS a verdict ("this worked" / "this lost") — painting it
/// on a statistically meaningless sample over-claims. Below the significance bar every verdict
/// metric renders NEUTRAL (the same textSecondary the house uses for "estimate, not a realized
/// gain"), and the existing "treat as illustrative" caption carries the words. Top-level
/// (internal, not nested private) so `Salehman AITests` reaches it via @testable import —
/// the SheetCandidateNavigation testability pattern.
enum BacktestVerdict {
    nonisolated static func metricColor(positive: Bool, significant: Bool) -> Color {
        guard significant else { return DS.Palette.textSecondary }
        return positive ? DS.Palette.successSoft : DS.Palette.danger
    }
}
```

**13b — strategyBacktestPanel.** Anchor: the metric block (unique via `s.blendedWinRate`, PF-8).

**OLD (exact):**
```swift
                    // Break-even for the fixed 2:1 exit is 1/(1+2) ≈ 33%, not 50% — coloring danger
                    // below 50% would flag every profitable 35-49% win-rate system as a loser.
                    ideaMetric("Win", String(format: "%.0f%%", s.blendedWinRate * 100),
                               color: s.blendedWinRate >= 1.0 / 3 ? DS.Palette.successSoft : DS.Palette.danger)
                    ideaMetric("Avg R", String(format: "%+.2f", s.avgR),
                               color: s.avgR >= 0 ? DS.Palette.successSoft : DS.Palette.danger)
                    ideaMetric("Total R", String(format: "%+.0f", s.totalR),
                               color: s.totalR >= 0 ? DS.Palette.successSoft : DS.Palette.danger)
```
**NEW:**
```swift
                    // Break-even for the fixed 2:1 exit is 1/(1+2) ≈ 33%, not 50% — coloring danger
                    // below 50% would flag every profitable 35-49% win-rate system as a loser.
                    // AUDIT_FINDINGS_2 #1: significance gates the COLOR (the verdict), not just
                    // the caption — an insignificant sample renders these NEUTRAL.
                    ideaMetric("Win", String(format: "%.0f%%", s.blendedWinRate * 100),
                               color: BacktestVerdict.metricColor(positive: s.blendedWinRate >= 1.0 / 3, significant: s.isSignificant))
                    ideaMetric("Avg R", String(format: "%+.2f", s.avgR),
                               color: BacktestVerdict.metricColor(positive: s.avgR >= 0, significant: s.isSignificant))
                    ideaMetric("Total R", String(format: "%+.0f", s.totalR),
                               color: BacktestVerdict.metricColor(positive: s.totalR >= 0, significant: s.isSignificant))
```

**13c — backtestPanel (per-symbol).** Anchor: the metric block (unique via `bt.winRate`, PF-8).

**OLD (exact):**
```swift
                        // Break-even for the fixed 2:1 exit is 1/(1+2) ≈ 33%, not 50%.
                        ideaMetric("Win", String(format: "%.0f%%", bt.winRate * 100),
                                   color: bt.winRate >= 1.0 / 3 ? DS.Palette.successSoft : DS.Palette.danger)
                        ideaMetric("Avg R", String(format: "%+.2f", bt.avgR),
                                   color: bt.avgR >= 0 ? DS.Palette.successSoft : DS.Palette.danger)
                        ideaMetric("Total R", String(format: "%+.1f", bt.totalR),
                                   color: bt.totalR >= 0 ? DS.Palette.successSoft : DS.Palette.danger)
```
**NEW:**
```swift
                        // Break-even for the fixed 2:1 exit is 1/(1+2) ≈ 33%, not 50%.
                        // AUDIT_FINDINGS_2 #1: significance gates the COLOR — see BacktestVerdict.
                        ideaMetric("Win", String(format: "%.0f%%", bt.winRate * 100),
                                   color: BacktestVerdict.metricColor(positive: bt.winRate >= 1.0 / 3, significant: bt.isSignificant))
                        ideaMetric("Avg R", String(format: "%+.2f", bt.avgR),
                                   color: BacktestVerdict.metricColor(positive: bt.avgR >= 0, significant: bt.isSignificant))
                        ideaMetric("Total R", String(format: "%+.1f", bt.totalR),
                                   color: BacktestVerdict.metricColor(positive: bt.totalR >= 0, significant: bt.isSignificant))
```

**13d — NEW `Salehman AITests/BacktestVerdictColorTests.swift` (complete):**
```swift
import Testing
import SwiftUI
@testable import Salehman_AI

// MARK: - Significance-gated backtest verdict color (AUDIT_FINDINGS_2 #1)
//
// Truth table from the finding's own spec (python sketch in AUDIT_FINDINGS_2.md #1):
// color(pos, sig) = neutral if !sig else (green if pos else red). Token equality, not RGB.

struct BacktestVerdictColorTests {
    @Test func insignificantSamplesRenderNeutralRegardlessOfSign() {
        #expect(BacktestVerdict.metricColor(positive: true, significant: false) == DS.Palette.textSecondary)
        #expect(BacktestVerdict.metricColor(positive: false, significant: false) == DS.Palette.textSecondary)
        #expect(BacktestVerdict.metricColor(positive: true, significant: true) == DS.Palette.successSoft)
        #expect(BacktestVerdict.metricColor(positive: false, significant: true) == DS.Palette.danger)
        // The gate must actually distinguish: neutral ≠ either verdict token.
        #expect(DS.Palette.textSecondary != DS.Palette.successSoft)
        #expect(DS.Palette.textSecondary != DS.Palette.danger)
    }
}
```

**Verify:**
```bash
grep -c "BacktestVerdict.metricColor" "Salehman AI/Views/MarketsView.swift"
xcodebuild test -scheme "Salehman AI" -destination 'platform=macOS' -configuration Debug CODE_SIGNING_ALLOWED=NO -derivedDataPath .dd -only-testing:"Salehman AITests/BacktestVerdictColorTests" 2>&1 | tee /tmp/salehman_calcwave2_build.log | tail -8
grep -o "insignificantSamplesRenderNeutralRegardlessOfSign()" /tmp/salehman_calcwave2_build.log | sort -u
```
**EXPECTED OUTPUT:** `6` (3 per panel — a 7th would be an unplanned call site → STOP),
`** TEST SUCCEEDED **`, the named case.
**Falsifiability probe:** in 13a swap `guard significant else { return DS.Palette.textSecondary }`
→ `guard significant else { return DS.Palette.successSoft }`, re-run → red naming the case;
restore → green. Paste both.

**HASTY-MODEL TRAP:** also neutralizing "Worst-name DD" / "Max DD" (always danger) or Sharpe —
those are RISK figures, not win/lose verdicts; the finding names exactly Win/AvgR/TotalR.
Second trap: adding the finding's optional "Illustrative only" title prefix — the existing
captions already carry "treat as illustrative" (MarketsView 3958-3961 / 4074-4077); duplicating
the words is copy churn, and F08 counsels against new contested terminology. Color is the fix.
DISCLOSED DEVIATION from the 2026-06-22 finding text: it suggested XCTest — this repo is Swift
Testing (`#expect`), per testing-discipline.

---

# ITEM E — Concurrency correctness (CONCURRENCY_BUGHUNT #2 #3)

The bughunt's line numbers pre-date the current Monitor/Store — Steps 14–15 re-anchor every edit
on the CURRENT symbols (verified at `c807861`). Substance of both bugs confirmed present (PF-9,
PF-10).

### Step 14 — StockSageMonitor: `stop()` actually stops the in-flight cycle (#2)

**File:** `Salehman AI/StockSage/StockSageMonitor.swift` · 6 edits. No new tests (REJECTED
register entry 6 — the pure decision seams stay untouched and their tests keep passing).

**14a — loop: don't start a cycle for a monitor that was just stopped.**
**OLD (exact):**
```swift
                if scoped {
                    await self?.runWatchlistCycle(watch)
                } else {
                    // Evaluate on LIVE quotes: pull a fresh worldwide snapshot before
                    // each cycle (no-ops cleanly when offline / web access is off).
                    await StockSageStore.shared.refresh()
                    await self?.runCycle()
                }
```
**NEW:**
```swift
                if scoped {
                    await self?.runWatchlistCycle(watch)
                } else {
                    // Evaluate on LIVE quotes: pull a fresh worldwide snapshot before
                    // each cycle (no-ops cleanly when offline / web access is off).
                    await StockSageStore.shared.refresh()
                    // CONCURRENCY #2: stop() during the refresh await must not start a whole
                    // evaluation cycle for a monitor the user just turned off.
                    guard !Task.isCancelled else { break }
                    await self?.runCycle()
                }
```

**14b — runCycle: bail out of the symbol loop when cancelled.**
**OLD (exact):**
```swift
        var strong: [StockSageSignal] = []
        var nowStrong: [String: StockSageRecommendation] = [:]
        for symbol in store.fetchAllSymbols() {
            guard let signal = StockSageSignalEngine.generateSignal(for: symbol) else { continue }
```
**NEW:**
```swift
        var strong: [StockSageSignal] = []
        var nowStrong: [String: StockSageRecommendation] = [:]
        for symbol in store.fetchAllSymbols() {
            // CONCURRENCY #2: stop() cancels the loop task, but a cancelled task keeps executing
            // past its awaits (the sendAlert below) unless it checks — without this, alerts kept
            // firing AFTER monitoring was toggled off, and a quick stop→start overlapped two
            // cycles on the same lastAlerted state (double-fired or suppressed pushes).
            guard !Task.isCancelled else { break }
            guard let signal = StockSageSignalEngine.generateSignal(for: symbol) else { continue }
```

**14c — runCycle: a dying cycle must not write the dedupe map.**
**OLD (exact):**
```swift
        if liveNotify { for (sym, rec) in nowStrong { lastAlerted[sym] = rec } }
```
**NEW:**
```swift
        // CONCURRENCY #2: a dying cycle must not write the dedupe map (two overlapping writers).
        if liveNotify, !Task.isCancelled { for (sym, rec) in nowStrong { lastAlerted[sym] = rec } }
```

**14d — runCycle: nor fire the price/idea alert tail.**
**OLD (exact):**
```swift
        if notify {
            await checkPriceAlerts()
            // Tracked-idea stop/target pushes: same honesty gate as the strong-signal path
```
**NEW:**
```swift
        if notify, !Task.isCancelled {
            await checkPriceAlerts()
            // Tracked-idea stop/target pushes: same honesty gate as the strong-signal path
```

**14e — runWatchlistCycle: same body-top bail.**
**OLD (exact):**
```swift
        for ticker in watch {
            guard let q = quotes[ticker.uppercased()], q.price > 0, q.previousClose > 0 else { continue }
```
**NEW:**
```swift
        for ticker in watch {
            // CONCURRENCY #2: same cooperative-cancellation bail as runCycle.
            guard !Task.isCancelled else { break }
            guard let q = quotes[ticker.uppercased()], q.price > 0, q.previousClose > 0 else { continue }
```

**14f — runWatchlistCycle: guarded merge + guarded alert tail (two adjacent edits).**
**OLD (exact):**
```swift
        if notify { for (s, r) in nowStrong { lastAlerted[s] = r } }
```
**NEW:**
```swift
        if notify, !Task.isCancelled { for (s, r) in nowStrong { lastAlerted[s] = r } }
```
**OLD (exact):**
```swift
        if notify {
            await checkPriceAlerts()
            await checkIdeaAlerts(prices: freshPrices)
        }
```
**NEW:**
```swift
        if notify, !Task.isCancelled {
            await checkPriceAlerts()
            await checkIdeaAlerts(prices: freshPrices)
        }
```
(Deliberately NOT guarded: `StockSageStore.shared.mergeLiveQuotes(quotes)` — publishing freshly
fetched real prices to the board is honest regardless of monitor state; only ALERT side-effects
and the dedupe map are the bug.)

**Verify:**
```bash
grep -c 'Task.isCancelled' "Salehman AI/StockSage/StockSageMonitor.swift"
grep -n 'Task.isCancelled' "Salehman AI/StockSage/StockSageMonitor.swift"
xcodebuild test -scheme "Salehman AI" -destination 'platform=macOS' -configuration Debug CODE_SIGNING_ALLOWED=NO -derivedDataPath .dd -only-testing:"Salehman AITests/StockSageMonitorTests" 2>&1 | tee /tmp/salehman_calcwave2_build.log | tail -8
```
**EXPECTED OUTPUT:** count `8` (1 pre-existing `while !Task.isCancelled` + the 7 new: 14a, 14b,
14c, 14d, 14e, 14f×2), the 8 hits listed (one in the while, one per edit), `** TEST SUCCEEDED **`
with all 7 pre-existing MonitorTests cases green (the pure seams are untouched).

**HASTY-MODEL TRAP:** `return` instead of `break` in 14b/14e — `return` skips the function's
remaining bookkeeping entirely and silently changes the non-cancelled contract; `break` falls
through to the (now-guarded) merge/tail exactly like a completed loop. Second trap: guarding
`checkAlertsNow`-style DIRECT calls "for symmetry" — direct callers run in a non-cancelled task,
so their behavior is byte-identical by construction; add no guards outside the 6 edits.

---

### Step 15 — StockSageStore: retry uses ONE pre-await universe snapshot (#3) + shared pure helper

**File:** `Salehman AI/StockSage/StockSageStore.swift` · 3 edits + NEW test file.

**15a — the pure, shared helper.** Anchor: insert directly ABOVE `nonisolated static func buildIdeas`'s
doc comment (unique):

**OLD (exact):**
```swift
    /// Build ranked ideas off the main actor (the advisor runs every indicator over each
```
**NEW:**
```swift
    /// CONCURRENCY #3: the "couldn't be fetched" list, derived from ONE pre-await `universe`
    /// snapshot — shared by refreshIdeas AND retryFailedIdeas so the two paths cannot disagree.
    /// A ticker ADDED during the await is absent from `universe` → never falsely bannered as a
    /// fetch failure (the next full refresh scans it); a ticker REMOVED during the await is
    /// dropped via `stillTracked`; indices are never "missing" (not buyable, no idea to build).
    /// Pure + testable (StockSageIdeasMissingTests).
    nonisolated static func missingAfterScan(universe: [String], analyzed: Set<String>,
                                             stillTracked: Set<String>) -> [String] {
        universe.filter {
            stillTracked.contains($0.uppercased()) &&
            !analyzed.contains($0.uppercased()) &&
            StockSageAllocation.assetClass($0) != "Index"
        }
    }

    /// Build ranked ideas off the main actor (the advisor runs every indicator over each
```

**15b — refreshIdeas rewires to the helper (behavior-identical — same three clauses).**
**OLD (exact):**
```swift
        ideasMissing = universe.map(\.symbol).filter {
            stillTracked.contains($0.uppercased()) &&                                   // dropped mid-fetch → not "missing"
            !analyzed.contains($0.uppercased()) && StockSageAllocation.assetClass($0) != "Index"
        }
```
**NEW:**
```swift
        ideasMissing = Self.missingAfterScan(universe: universe.map(\.symbol),
                                             analyzed: analyzed, stillTracked: stillTracked)
```

**15c — retryFailedIdeas: snapshot ONCE, report against that snapshot.** Two edits.
**OLD (exact):**
```swift
        let retrySet = Set(ideasMissing.map { $0.uppercased() })
        let defs = trackedDefs().filter { retrySet.contains($0.symbol.uppercased()) }
```
**NEW:**
```swift
        let retrySet = Set(ideasMissing.map { $0.uppercased() })
        // CONCURRENCY #3: ONE universe snapshot BEFORE the await — the missing-list below must
        // be computed against the same set that was scanned, not a fresh post-await read that
        // can contain a just-added (priced, on-board) ticker and falsely banner it as a failure.
        let universe = trackedDefs()
        let defs = universe.filter { retrySet.contains($0.symbol.uppercased()) }
```
**OLD (exact):**
```swift
        let analyzed = Set(merged.map { $0.symbol.uppercased() })
        ideasMissing = trackedDefs().map(\.symbol).filter {
            !analyzed.contains($0.uppercased()) && StockSageAllocation.assetClass($0) != "Index"
        }
```
**NEW:**
```swift
        let analyzed = Set(merged.map { $0.symbol.uppercased() })
        ideasMissing = Self.missingAfterScan(universe: universe.map(\.symbol),
                                             analyzed: analyzed, stillTracked: stillTracked)
```

**15d — NEW `Salehman AITests/StockSageIdeasMissingTests.swift` (complete).** Fixtures are hand
sets — the expected output is counted by hand in the comments (no engine call to derive from):
```swift
import Testing
@testable import Salehman_AI

// MARK: - missingAfterScan (CONCURRENCY #3) — one snapshot, no false failure banners.

struct StockSageIdeasMissingTests {

    @Test func filtersByTrackedAnalyzedAndIndexClass() {
        // By hand: AAPL — tracked ✓, not analyzed ✓, Equity ✓ → MISSING.
        //          GONE — removed mid-await (not in stillTracked) → dropped.
        //          ^GSPC — Index class → never "missing" (not buyable).
        //          2222.SR — analyzed → not missing.
        //          nvda — lowercase in universe, tracked as NVDA → MISSING (case-insensitive), casing preserved.
        let missing = StockSageStore.missingAfterScan(
            universe: ["AAPL", "GONE", "^GSPC", "2222.SR", "nvda"],
            analyzed: ["2222.SR"],
            stillTracked: ["AAPL", "^GSPC", "2222.SR", "NVDA"])
        #expect(missing == ["AAPL", "nvda"])
    }

    @Test func tickerAddedDuringTheAwaitIsNeverBanneredAsAFailure() {
        // NEWB was added (and priced, on the board) DURING the retry await: it is in the CURRENT
        // tracked set but NOT in the pre-await universe snapshot — it must not appear as a
        // "couldn't be fetched" failure. The old code re-read trackedDefs() post-await and did
        // exactly that.
        let missing = StockSageStore.missingAfterScan(
            universe: ["AAPL"],
            analyzed: [],
            stillTracked: ["AAPL", "NEWB"])
        #expect(missing == ["AAPL"])
        #expect(!missing.contains("NEWB"))
    }
}
```

**Verify:**
```bash
grep -c "missingAfterScan" "Salehman AI/StockSage/StockSageStore.swift"
xcodebuild test -scheme "Salehman AI" -destination 'platform=macOS' -configuration Debug CODE_SIGNING_ALLOWED=NO -derivedDataPath .dd -only-testing:"Salehman AITests/StockSageIdeasMissingTests" 2>&1 | tee /tmp/salehman_calcwave2_build.log | tail -8
grep -o "StockSageIdeasMissingTests/[a-zA-Z]*()" /tmp/salehman_calcwave2_build.log | sort -u
```
**EXPECTED OUTPUT:** `3` (1 definition + 2 call sites), `** TEST SUCCEEDED **`, both named cases.
**Falsifiability probe:** change `#expect(missing == ["AAPL", "nvda"])` → `== ["AAPL"]`, re-run →
red naming the case; restore → green. Paste both.

**HASTY-MODEL TRAP:** the retry path's missing-list previously had NO `stillTracked` clause —
because the fresh `trackedDefs()` re-read made it implicit. Once you switch to the pre-await
`universe`, forgetting `stillTracked` would resurrect a mid-await REMOVED ticker into the failure
banner (the exact class of bug #1 already fixed in refresh()). The helper carries all three
clauses precisely so neither call site can forget one. Note `stillTracked` at retry's line ~388
is ALREADY computed post-await from a fresh read — correct for removals; do not "snapshot" it.

---

### Step 16 — Docs, LAST, written from the final diff (executing-plans rule 7)

Run `git diff c807861 --stat` and read it FIRST; every claim below must match the diff before it
is appended (the "72px spacer"/"fixtures: None" scar — logs describe the FINAL tree).

**16a — `DEVELOPMENT_LOG.md`:** insert ABOVE `## Standing notes / known issues` (find it with
`grep -n 'Standing notes' DEVELOPMENT_LOG.md` — never a full-file Read):

```markdown
## 2026-07-03 · CALC-QUALITY WAVE 2 — turnover/cost honesty · risk-engine fixes · crypto cost engines · significance-gated verdict colors · concurrency fixes
**Files:** StockSage/StockSageRefuseList.swift (new) · StockSageExpectedValue.swift · StockSageGapRisk.swift · StockSageCapitalAllocator.swift · StockSageLossLimit.swift · StockSageNetEdge.swift · StockSageCryptoLiquidityGate.swift (new) · StockSageCryptoHonesty.swift (new) · StockSageCryptoFunding.swift (new) · StockSageMonitor.swift · StockSageStore.swift · Views/MarketsView.swift · 8 test files (+30 @Test) · backlog docs statuses · SOURCE_BUNDLE.md (regenerated)
**What & why:** (A) Week-horizon research roadmap #1 coded: `StockSageRefuseList` (7 verified net-negative setups + McLean-Pontiff 0.26/0.58 haircut constants, policy/advisory-only — iter6 already prices turnover continuously, so NO new rank penalty) + `assumedWeeklyRoundTrips`/`weeklyTurnoverNote` disclosure appended to the two weekly-R tooltips via `weeklyGrossHelp` (LABELS ONLY — the gross numbers are byte-identical; F03/F44 netting stays owner-held). (B) BUGHUNT_NEWENGINES: #7 `worstCase` sorts any caller ladder; #10 long gap fill clamps at $0 (short deliberately unclamped); #8 allocator `positionOrder` total-order comparator (determinism only, existing distinct-symbol orders unchanged); #9 LossLimit weekly fallback fails CLOSED (trailing 7-day window, `sevenDayFallbackStart`); gap-row tooltip now carries the full worstCase ladder; #6 confirmed already fixed (stale doc status corrected); #2 confirmed already wired 2026-06-22. (C) CRYPTO_RISK #1–#4 engine-first, all UNWIRED into production ranking: `StockSageNetEdge.cryptoCosts` tier estimate bands (major 37.5bps RT / large 60 / mid 125 / thin 300, low<mid<high per tier; `defaultCosts` byte-identical — the doc's "50bps collision" was stale, tree pins 70), `StockSageCryptoLiquidityGate` (ADV$ tiers + adverse-gap read, nil for non-crypto, unknown≠liquid), `StockSageCryptoHonesty` (3× backtester runs gross/mid/high + pure `classify`; thin forces UNPROVEN; gross leg byte-equal to `StockSageBacktester.run`), `StockSageCryptoFunding` (perp funding drag band, sign-flip disclosed). (D) AUDIT_FINDINGS_2 #1: `BacktestVerdict.metricColor` — insignificant samples render Win/AvgR/TotalR NEUTRAL in both backtest panels (display-only, zero numeric change). (E) CONCURRENCY_BUGHUNT #2: 7 cooperative-cancellation guards in Monitor (stop() now actually stops the in-flight cycle; dying cycles neither alert nor write `lastAlerted`); #3: retryFailedIdeas uses ONE pre-await universe snapshot via shared pure `missingAfterScan` (a mid-await added ticker is never falsely bannered as a fetch failure).
**Owner gates re-scanned:** RANKING #10 / F01-F02 / F03-F44 / F08 / F10 untouched; no ranking key, demotion band, default cost, or displayed number changed; all new constants labeled estimates with sources.
**Result:** build + full suite green (`** TEST SUCCEEDED **`, @Test grep count <B> → <B+30>); every new fixture hand-derived (derive scripts in the plan); falsifiability probes pasted in the execution report.
```
Substitute `<B>`/`<B+30>` with YOUR PF-13 measurement (1502 → 1532 at `c807861`). If execution
deviated anywhere, rewrite the entry from the diff — do not paste this text over a different
reality.

**16b — `MARKETS_TAB_MAP.md`:** four NEW entries (follow the exact house shape — Purpose / Key
symbols / Inputs / Consumers / Invariants / Gotchas, matching the `StockSageExecutionTiming.swift`
entry): `StockSageRefuseList.swift` (Consumers: MarketsView `weeklyGrossHelp` tooltips + tests;
Gotchas: policy/advisory only, NEVER a rank input — iter6 already prices turnover),
`StockSageCryptoLiquidityGate.swift`, `StockSageCryptoHonesty.swift`, `StockSageCryptoFunding.swift`
(each marked **UNWIRED** into production ranking/UI — engine-first per CRYPTO_RISK.md; consumers:
tests + each other). Plus UPDATE the existing entries whose Key symbols/Gotchas materially changed:
`StockSageNetEdge.swift` (add `cryptoTier`/`cryptoCosts`/`CryptoCostEstimate` — NEW accessor,
`defaultCosts` deliberately untouched), `StockSageExpectedValue.swift` (add
`assumedWeeklyRoundTrips`/`weeklyTurnoverNote` — label-only), `StockSageGapRisk.swift` (#7 sort,
#10 clamp), `StockSageCapitalAllocator.swift` (`positionOrder`), `StockSageLossLimit.swift`
(`sevenDayFallbackStart`), `StockSageMonitor.swift` (cancellation guards), `StockSageStore.swift`
(`missingAfterScan`), `MarketsView.swift` (weeklyGrossHelp, gap-ladder tooltip, BacktestVerdict).

**16c — status flips in the backlog docs (each a 1–3 line edit, dated 2026-07-03):**
- `BUGHUNT_NEWENGINES.md`: header line → "#2 wired 2026-06-22 (+ladder tooltip 2026-07-03); #6
  found already-fixed at c807861; #7 #8 #9 #10 ✅ DONE 2026-07-03 (calc-wave-2)". Flip the four
  `⬜` markers to `✅ DONE` with one-line what-shipped notes; #6 gets "✅ ALREADY FIXED (side
  guards + tests present at c807861; this doc was stale)".
- `CRYPTO_RISK.md`: flip #1–#4 to "✅ ENGINE SHIPPED 2026-07-03 (calc-wave-2) — UNWIRED into
  production ranking/UI (deliberate; wiring is its own visual-QA-gated wave). #1 note: the 50bps
  collision caveat was STALE — defaultCosts pins 70bps at c807861 and was left byte-identical;
  the tier estimate is a NEW accessor."
- `LEVERAGE_RISK.md` #3: append "2026-07-03: worstCase ladder added to the gap row's tooltip
  (single 20% headline row unchanged)."
- `AUDIT_FINDINGS_2.md` #1: `⬜` → "✅ DONE 2026-07-03 — BacktestVerdict.metricColor gates both
  panels' Win/AvgR/TotalR colors; Swift Testing (not XCTest) per testing-discipline."
- `CONCURRENCY_BUGHUNT.md` #2/#3: `⬜` → "✅ DONE 2026-07-03" with one-line notes (7 guards;
  one-snapshot missingAfterScan).
- `RESEARCH_2026-07-02_week_horizon_velocity.md`: inside roadmap item **1**, append an
  "**Implemented 2026-07-03:**" note (mirroring item 2's existing implementation notes):
  refuse-list coded as `StockSageRefuseList` (policy/labels; NO new rank penalty — iter6 already
  turnover-aware, reasoning recorded in the wave-2 plan's REJECTED register), weekly re-cycle
  disclosure via `assumedWeeklyRoundTrips` on the weekly-R tooltips.
- `research/INDEX.md`: extend the 2026-07-02 week-horizon line with "· roadmap #1 implemented
  2026-07-03 (refuse-list module + weekly turnover labels; no rank change)". Do NOT add a new
  research line — no new research was performed (research-memory rule: extend the entry).

**16d — regenerate the bundle (never Read it):**
```bash
bash tools/bundle_source.sh
git status --short SOURCE_BUNDLE.md
# EXPECTED:  M SOURCE_BUNDLE.md
```

**Verify (docs step):**
```bash
grep -n "CALC-QUALITY WAVE 2" DEVELOPMENT_LOG.md | head -1
grep -c "2026-07-03" BUGHUNT_NEWENGINES.md CRYPTO_RISK.md AUDIT_FINDINGS_2.md CONCURRENCY_BUGHUNT.md LEVERAGE_RISK.md
grep -n "roadmap #1 implemented" research/INDEX.md
```
**EXPECTED OUTPUT:** the dev-log hit above the Standing-notes anchor; a non-zero 2026-07-03 count
per doc; the INDEX hit.

**HASTY-MODEL TRAP:** pasting 16a's `<B>` placeholders literally, or logging counts you did not
measure (the sheet-nav plan's dry run caught exactly this). Also: appending a NEW line to
`research/INDEX.md` instead of extending the existing one — the index stays lean by rule.

---

## 6. Full-suite gate (after Step 16, before handoff)

```bash
xcodebuild test -scheme "Salehman AI" -destination 'platform=macOS' -configuration Debug CODE_SIGNING_ALLOWED=NO -derivedDataPath .dd -only-testing:"Salehman AITests" 2>&1 | tee /tmp/salehman_calcwave2_build.log | tail -25
# on failure ONLY:
grep -E "Test case '.*' failed" /tmp/salehman_calcwave2_build.log | sed -E "s/.*'([^']+)'.*/\1/" | sort -u
# STATIC new-test accounting (deterministic, unlike the runtime count):
grep -ch '@Test' "Salehman AITests"/*.swift | awk '{s+=$1} END {print s}'
# duplicate-suite guard (must still be silent):
grep -rhoE '^(@MainActor[[:space:]]+)?(struct|class) [A-Za-z0-9_]+Tests' "Salehman AITests/" | sed -E 's/.*(struct|class) //' | sort | uniq -d
```
**EXPECTED:** tail contains `** TEST SUCCEEDED **` (the ONLY passing verdict — do not gate on the
runtime per-test count, it interleaves ±1); `@Test` grep count = **PF-13 baseline + 30**
(1502 + 30 = **1532** at `c807861`; substitute your measured B); dup-finder silent; AND the log
contains the new suites' named cases — re-grep the Step 2c/4c/7c/9/10/11d/12d/13/15d case names
(a green suite in which the new tests never RAN proves nothing; WHIPPYX rule). New-@Test ledger:
Step 2: 3 · Step 4: 4 · Step 7: 2 · Step 9: 1 · Step 10: 1 · Step 11: 4 · Step 12d: 12 ·
Step 13: 1 · Step 15d: 2 = **30**.

## 7. Rollback (exact)

```bash
cd "$(git rev-parse --show-toplevel)"
git restore --source=c807861 --staged --worktree \
  "Salehman AI/StockSage/StockSageExpectedValue.swift" \
  "Salehman AI/StockSage/StockSageGapRisk.swift" \
  "Salehman AI/StockSage/StockSageCapitalAllocator.swift" \
  "Salehman AI/StockSage/StockSageLossLimit.swift" \
  "Salehman AI/StockSage/StockSageNetEdge.swift" \
  "Salehman AI/StockSage/StockSageMonitor.swift" \
  "Salehman AI/StockSage/StockSageStore.swift" \
  "Salehman AI/Views/MarketsView.swift" \
  "Salehman AITests/StockSageGapRiskTests.swift" \
  "Salehman AITests/StockSageCapitalAllocatorTests.swift" \
  "Salehman AITests/StockSageLossLimitTests.swift" \
  DEVELOPMENT_LOG.md MARKETS_TAB_MAP.md BUGHUNT_NEWENGINES.md CRYPTO_RISK.md LEVERAGE_RISK.md \
  AUDIT_FINDINGS_2.md CONCURRENCY_BUGHUNT.md "RESEARCH_2026-07-02_week_horizon_velocity.md" \
  research/INDEX.md SOURCE_BUNDLE.md
rm -f "Salehman AI/StockSage/StockSageRefuseList.swift" \
      "Salehman AI/StockSage/StockSageCryptoLiquidityGate.swift" \
      "Salehman AI/StockSage/StockSageCryptoHonesty.swift" \
      "Salehman AI/StockSage/StockSageCryptoFunding.swift" \
      "Salehman AITests/StockSageRefuseListTests.swift" \
      "Salehman AITests/StockSageWeeklyTurnoverTests.swift" \
      "Salehman AITests/StockSageCryptoCostTests.swift" \
      "Salehman AITests/StockSageCryptoLiquidityGateTests.swift" \
      "Salehman AITests/StockSageCryptoHonestyTests.swift" \
      "Salehman AITests/StockSageCryptoFundingTests.swift" \
      "Salehman AITests/BacktestVerdictColorTests.swift" \
      "Salehman AITests/StockSageIdeasMissingTests.swift"
git status --short
# EXPECTED: (empty — the worktree is back at c807861 content; WIP commits remain on the branch,
#            which the orchestrator can simply delete: the branch is disposable by design)
```

## 8. Done-means (every box needs PASTED OUTPUT — `executing-plans` contract)

- [ ] PF-1…PF-13 ran first and matched, or execution STOPPED at the first mismatch with a
      `plan says X / tree says Y` report (no silent adaptation).
- [ ] Every step closed with pasted verification output containing its required token
      (`** BUILD SUCCEEDED **` / `** TEST SUCCEEDED **` / the exact grep hits + counts) —
      never "it passes".
- [ ] Every derive script's output pasted and matching (Steps 4a, 7a, 11a, 12d); every asserted
      numeric literal traces to a derive script or the captured research/spec doc, NEVER to the
      code under test (F40/NetEdge rule); every named falsifiability probe pasted red-then-green.
- [ ] Full-suite gate: `** TEST SUCCEEDED **` + @Test grep count = B + 30 + the new case names
      present in the log (WHIPPYX rule).
- [ ] `git diff c807861 --stat` pasted; files touched ⊆ §4 list ("NO other file" held); the report
      and the 16a log entry describe what the DIFF shows (Wave-11 rule).
- [ ] Owner gates re-scanned post-hoc: RANKING #10 / F01-F02 / F03-F44 / F08 / F10 untouched; the
      weekly gross figures, `defaultCosts`, every rank key and demotion band byte-identical
      (grep-prove: `git diff c807861 -- "Salehman AI/StockSage/StockSageExpectedValue.swift"` shows
      ONLY the Step-3 insertion; the NetEdge diff shows ONLY the appended extension).
- [ ] A WIP commit exists per completed step (`git log --oneline` pasted — owner durability
      directive); no push occurred.
- [ ] Docs step done LAST from the final diff: dev-log entry (with YOUR measured counts), 4 new +
      9 updated map entries, 5 backlog-doc status flips, research-file implementation note +
      INDEX extension, `bash tools/bundle_source.sh` ( M SOURCE_BUNDLE.md).
- [ ] REJECTED register re-checked: nothing from it was "helpfully" implemented — no defaultCosts
      re-point, no weekly netting, no new rank penalty, no Monitor tautology test, no crypto UI
      wiring.








## Amendment A-1 (2026-07-02, planner ruling after executor STOP at Step 2)
**STOP report:** Step 2b's universal digit-assert (`evidence.rangeOfCharacter(from: .decimalDigits) != nil` over ALL entries) contradicted Step 1's verbatim evidence for `overnight-roundtrip`, which is digit-free — and the SPEC (RESEARCH_2026-07-02_week_horizon_velocity.md:35, refuse-list item 4) is also digit-free, verified independently by the executor and the adversarial verifier (static scan + runtime reproduction, `** TEST FAILED **` on both runners).
**Ruling (option a):** the digit heuristic yields to spec fidelity. Step 2b's loop is amended in place (see the updated code block above): `overnight-roundtrip` is pinned on its load-bearing spec phrases (`"cost-devoured"`, `"shut down"`) — hard asserts, still falsifiable — all other six entries keep the digit assert. Option (b) — adding a figure to evidence #4 — REJECTED: it would fabricate a statistic the research corpus does not contain (fact-discipline) and alter the verbatim spec string (Step-1 trap).
**Executor deviation ratified:** the disclosed `import Foundation` addition to the Step-2b test file (the plan block omitted it; the plan's own Step-12d sibling includes it) is correct and stands.
**Resume:** apply the amended 2b block to `Salehman AITests/StockSageRefuseListTests.swift` (currently RED at WIP `0ee4a3f`), run 2c (expect `** TEST SUCCEEDED **` + the same 3 named cases) and the 2d falsifiability probe (unchanged — flips the `== 7` count), then continue at Step 3. Steps 3–15 pre-flight anchors were all verified green pre-STOP.
