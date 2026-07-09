---
name: money-campaign-map
description: The executable, decision-gated campaign map for the hardest live problem in Salehman AI's StockSage/Markets workstream — the engine has NO PROVEN EDGE (measured Deflated Sharpe ≈ 0; its value today is risk-discipline), and the campaign goal is a genuinely MEASURED net-of-costs edge at retail scale. Use when asked to "make money faster/fastest", advance the money/edge campaign, decide what to build next on the ideas card, evaluate/promote any new signal or edge candidate, judge whether the engine "works", or resume the week-horizon TOP-3 roadmap. Defines numbered phases with commands and expected observations, the ranked solution menu with derivation obligations, the fenced wrong paths (verified anti-edges), and the DSR/PSR promotion bar.
---

# Money campaign map — from "no proven edge" to a measured one

**The problem (owner-acknowledged assumption, 2026-07-02 — the owner may override this framing):** the hardest live
problem is that StockSage has **no proven edge** — the strategy backtest's own source states
"the measured DSR is ≈ 0, the verdict is 'unproven edge'" (`StockSageStrategyBacktest.swift`,
doc comment on `deflatedSharpe`), and the mental-model header states "Deflated Sharpe ≈ 0 — no
proven edge; its value is risk-discipline, not alpha". **"Beyond SOTA" here = a genuinely
MEASURED net-of-costs edge at retail scale** — victory is a metric, never an impression.

**When NOT to use this skill:** this is the campaign map (which phase, which gate, what counts
as done). For HOW to run one empirical study, use `skills/ablation-harness`. For recording/looking up research,
use `research-memory`. For a per-iteration improvement wave, use `wave-cycle`. Before editing
any engine file, use `stocksage-mental-model`. For the merge pipeline, use `shipping-changes`.

## Definitions (each term once)

| Term | Meaning here |
|---|---|
| **R** | Profit/loss as a multiple of the initial risk (entry-to-stop distance). +2R = you made twice what the stop would have lost. |
| **Walk-forward** | Backtest where every signal at bar *i* uses only data ≤ *i*; fills at bar *i+1*'s open ("no peeking"). |
| **Net-of-cost** | After spread + slippage + fees per `StockSageNetEdge.defaultCosts(forSymbol:)`. Never quote a gross figure as achievable net. |
| **PSR** | Probabilistic Sharpe Ratio — P(true Sharpe > benchmark) given sample size, skew, fat tails. `StockSageDeflatedSharpe.probabilisticSharpe`. |
| **DSR** | Deflated Sharpe Ratio — PSR evaluated against the expected-max Sharpe of all strategy variants tried (selection-bias haircut). A probability in [0,1]. |
| **The bar** | `StockSageDeflatedSharpe.Result.passes` = `dsr > 0.95` — the shipped "honest real-edge" threshold. |
| **Anti-edge** | A documented setup that LOSES money net of retail costs (the refuse-list). |
| **Owner gate** | A decision only the owner may make. Registry lives ONLY in the `gated-scope` skill ("How", step 1) — never restated here. |
| **TSMOM / PEAD / IRRX** | Time-series (own-trend 12-1) momentum / post-earnings-announcement drift / industry-relative, earnings-window-excluded reversal. |
| **Honesty floor** | nil = unknown (never fabricated), estimates labeled "assumed", gross vs net always labeled, signal-strength never shown as P(profit). |

> **Map, not territory (F46 rule):** every default, threshold, and ship-state below drifts.
> Grep the source before relying on any of them — re-verification commands are at the end.

## The campaign state machine

Run phases in order. Each gate says what you should observe and where to branch if you don't.
**Never gate on counts** (test counts, universe sizes, trade counts fluctuate) — gate on the
verdict line / the named symbol / the metric.

### Phase 0 — Orient (every session that touches the campaign)

1. Read `research/INDEX.md` in full (auto-loaded via CLAUDE.md), especially its
   **OPEN FRONTIER** section — each open item states its falsifiable "you have a result when…".
2. Scan the owner-gate registry in `gated-scope`. Any campaign step touching
   **RANKING #10, F01/F02, F08, F10, or F03/F44 is REFUSED pending owner** — write
   `BLOCKED: <exact question>` and do only the unblocked remainder. A "⚠ pending
   confirmation" note on shipped work is a violation, not compliance.
3. Confirm the honesty floor (see Definitions) — it binds every phase below.

### Phase 1 — Cost gate + refuse-list (roadmap #1: the biggest lever, ~1–1.7%/mo of cost-avoidance)

The week-horizon research (`RESEARCH_2026-07-02_week_horizon_velocity.md`) verified that at
1–5-day holds essentially NO equity edge survives retail costs standalone — so the fastest
money is the money you stop burning. The continuous turnover machinery already ships (iter6:
`netEVR`, `netVelocity`, net-cost floor demotion); what roadmap #1 adds is the **coded
refuse-list policy module + weekly re-cycle disclosure labels**.

```bash
cd /Users/saleh/ai
ls "Salehman AI/StockSage/StockSageRefuseList.swift"
```
- **File exists** → Phase 1 landed. Verify its tests by name, then go to Phase 2:
  ```bash
  xcodebuild test -scheme "Salehman AI" -destination 'platform=macOS' -configuration Debug \
    CODE_SIGNING_ALLOWED=NO -only-testing:"Salehman AITests/StockSageRefuseListTests" 2>&1 \
    | tee /tmp/salehman_build.log | tail -8
  ```
  EXPECTED: `** TEST SUCCEEDED **` (the verdict line, nothing else, is the gate).
- **File missing** (state as of 2026-07-02) → it is IN FLIGHT: calc wave 2 Item A, spec'd
  step-by-step in `plans/PLAN_2026-07-03_calc_wave2_cost_honesty.md`, executing in a separate
  worktree on branch `ideas-card/calc-wave-2`. **Do NOT re-implement it in the main tree** —
  duplicate symbols will collide at merge.
- **File missing AND the plan is abandoned** (only the owner can declare that) → execute plan
  Item A yourself via `executing-plans` (the plan has exact anchors, derivations, and traps).

**Gate discipline for this phase:** Item A is labels-only — the weekly gross numbers are
byte-identical (F03/F44 — SETTLED 2026-07-09: the NET headline shipped through the pipeline after the owner lifted the gate class; see gated-scope §1). A step that nets, shrinks, or re-computes the
weekly headline is a plan violation → STOP.

### Phase 2 — Zero-turnover execution timing (roadmap #2: SHIPPED — verify, don't rebuild)

```bash
grep -n "sessionNote" "Salehman AI/StockSage/StockSageExecutionTiming.swift" | head -3
grep -n "defaultShortBorrowRate" "Salehman AI/StockSage/StockSageNetEdge.swift" | head -2
```
EXPECTED: `sessionNote(action:regime:)` defined (flag-only advisory wired in `buildIdeas`);
`defaultShortBorrowRate = 0.03   // 3%/year` threaded into short-side EV. If either grep is
empty → the shipped state regressed; STOP and check DEVELOPMENT_LOG before proceeding.

The third leg (reversal-as-liquidity-screen) was **deliberately DEFERRED with written
reasoning** (no intraday data; redundant with the shipped `RSI > 80` demotion — see the
research file, roadmap #2). Do not "complete" it: that would double-count an existing
mechanism. Roadmap #2 is fully actioned.

### Phase 3 — Measure the baseline (the number the whole campaign moves)

The measurement surface is in-app: launch via the `run-salehman-ai` skill → Markets tab →
the strategy-backtest panel (symbol anchor: `strategyBacktestPanel` in `MarketsView.swift`;
its button calls `store.refreshStrategyBacktest()`, which runs
`StockSageBacktester.runDetailed` with `StockSageNetEdge.defaultCosts` over
`StockSageStrategyBacktest.sampleSymbols`, ~5y each, then aggregates). Requires network
(Yahoo v8 keyless).

EXPECTED (as of 2026-07-02): an **unproven-edge verdict** — `significanceVerdict` copy like
"not significant; likely noise" or "isn't statistically meaningful yet", and DSR ≈ 0.
- **If instead you see a PASS** (`passesHonestSignificance` true / `deflatedSharpe.passes`
  true) → do NOT declare victory. Branch: (a) re-run — one run is one sample; (b) check
  `estimatedStrategyTrials` (a deliberate LOWER bound — undercounting trials makes the DSR bar
  easier) and the `StockSageDeflatedSharpe.caveat` (a scan over correlated names makes DSR
  optimistic); (c) survivorship bias — the sample is currently-listed names, so the measured
  Sharpe is a CEILING (the module's own `caveat` says so); (d) adversarial review + owner
  review BEFORE recording any "edge proven" claim via Phase 6.

### Phase 4 — IRRX overlay (roadmap #3) — **CLOSED 2026-07-09: the FULL-exclusion run executed (earnings axis unblocked, 61/61 coverage) and returned NULL (best net-OOS DSR 0.553; RESEARCH_2026-07-09_full_irrx_ablation.md). Overlay REFUSED at its strongest tested form; this phase is done, not pending.**

The one short-horizon equity signal surviving the modern era GROSS of costs is the
industry-relative, earnings-window-excluded reversal: 58 bps/mo gross, t=3.29
post-decimalization (verified 3-0 ×4). Plausible NET retail magnitude: **0–30 bps/mo at
best**, in liquid large caps, as an entry-timing tilt — never a standalone book.

**Derivation obligations before ANY build step:**
1. Haircut the published effect 26% (out-of-sample) / 58% (post-publication) BEFORE evaluating
   (McLean & Pontiff — refuse-list #7).
2. Run a net-of-cost walk-forward simulation at the ablation-precedent rigor
   (`skills/ablation-harness`, or the Method of `RESEARCH_2026-07-02_confluence_rs_ablation.md`):
   real data, formulas ported EXACTLY from the Swift source, no look-ahead, non-overlapping
   blocks with block-level significance, horizon sweep, costs from
   `StockSageNetEdge.defaultCosts`.
3. Gate: **net edge significant** → it becomes a ranking change → Phase 6 (empirical validation
   recorded + owner sign-off for wiring). **Net ≤ 0 or insignificant** → index the null (a null
   is a win — the confluence/RS ablation precedent, all p>0.10, correctly promoted nothing) and
   close roadmap #3 as refused.

### Phase 5 — Frontier expansion (only after Phases 1–4 are settled)

Pick an item from `research/INDEX.md` § OPEN FRONTIER; its "you have a result when…" line IS
the exit criterion. Any new research must meet the `research-memory` §3 bar: 3-vote adversarial
verification, source + as-of date on every stat, documented-absence for absence claims, and a
mandatory "did NOT establish" section.

### Phase 6 — Validation & promotion protocol (how anything ships)

1. **Gate scan** (`gated-scope`): 2026-07-09 the owner-gate CLASS was retired (dispositions in §1) — the scan now checks the EVIDENCE bar and data-blocks instead; unanswered spec facts/measurements still BLOCK.
2. **Validation** (`research-memory` §2): a ranking/signal/sizing change ships ONLY with
   empirical validation (walk-forward, deflated Sharpe, net-of-cost) or explicit owner
   sign-off. No stories.
3. **Record** (`research-memory` §4): detail file at repo root + one dated INDEX line + extend
   the touched OPEN FRONTIER item. Null results get indexed too.
4. **Ship** (`shipping-changes` steps 0–6): build+test verdict lines pasted, DEVELOPMENT_LOG
   entry describing the FINAL tree, `bash tools/bundle_source.sh`, MARKETS_TAB_MAP entry,
   add-by-name commit (note: `tools/test_grok_bridge.py` is TRACKED since 713064e — ignore any
   older skill text saying "keep it untracked"), CI gate by log, ff-only merge.
5. **Success is the metric**: quote the verdict line and the DSR/PSR values in the log entry.
   "Looks better on the board" is not a result.

## Solution menu (ranked; each row's obligation is mandatory before building)

| # | Lever | Expected size (sourced, 2026-07-02) | Derivation obligation | Promotion gate |
|---|---|---|---|---|
| 1 | Refuse-list + turnover disclosure (roadmap #1) | ~1–1.7%/mo cost-AVOIDANCE (not alpha) | None new — research verified; execute per plan Item A | Build/test verdicts; labels only (F03/F44 untouched) |
| 2 | Execution timing (roadmap #2) | Single-digit → low-tens bps/mo, zero added turnover | SHIPPED — verify the Phase 2 greps | Already landed |
| 3 | IRRX-cleaned reversal overlay (roadmap #3) | 0–30 bps/mo NET at best (58 bps/mo is GROSS — never quote as net) | Haircut + net-of-cost walk-forward sim clears | Sim verdict + owner sign-off for ranking wiring |
| 4 | Weekly concentration mechanics | UNKNOWN — zero verified claims exist | Fresh 3-vote research or an allocator ablation | `research-memory` §3 bar |
| 5 | Any brand-new signal | Assume ≈half its paper size, then net costs | Full stack: INDEX read → haircut → ablation → DSR | `research-memory` §2 + `gated-scope` |

## Fenced wrong paths (verified anti-edges — settled policy, not opinion)

Do not build, propose, or relitigate these without NEW evidence that itself clears the
`research-memory` §3 bar. All seven verified in `RESEARCH_2026-07-02_week_horizon_velocity.md`:

| # | Refused setup | The killing number |
|---|---|---|
| 1 | Naive short-term reversal, standalone weekly | +0.37%/mo gross → **−1.28%/mo net** (t=−6.02) |
| 2 | Standalone PEAD / earnings-drift trading | Costs eat 70–100%; tradable-liquidity drift ≈ 0.04%/mo |
| 3 | ~90%-turnover monthly anomaly rotation | Round-trip costs >1%/mo, exceed nearly every gross spread |
| 4 | Daily overnight/intraday round-trip harvesting | Cost-devoured per its own source; NightShares ETFs shut down |
| 5 | Crypto funding-rate-seasonality timing | ~2.5 bps spread vs 4–10 bps/side taker fees |
| 6 | Anomalies implemented in small/illiquid names | The paper edge lives exactly where retail fills can't |
| 7 | Published effect sizes at face value | Decay 26% OOS / 58% post-publication — haircut first |

Also fenced:
- **Top-3 weekly concentration mechanics carry ZERO verified claims** — never cite them as
  established. And do NOT add a hard top-3 cap to `StockSageCapitalAllocator`: `maxConcurrent: 3`
  is a display projection in `StockSageExpectedValue` only; the real allocator (maxHeat +
  half-Kelly + correlation-aware clique de-weighting via `StockSageCorrelationCluster` —
  NOT the unwired `StockSageAllocationOptimizer`) is the more principled mechanism (documented in the
  week-horizon file's "did NOT establish" follow-up audit — a past session nearly "fixed" this non-bug).
- **Two REFUTED claims — never reuse:** (a) PEAD-style earnings momentum survives costs among
  mid-turnover strategies; (b) a mispricing factor systematically loses near the close.
- **UNWIRED modules stay unwired** (`stocksage-mental-model` §2): several are unwired by
  ablation conclusion or pending owner decision — wiring one up is not an improvement, it is an
  unvalidated ranking change.
- **Never edit an assertion toward the implementation** (`spec-fidelity`); harness output is
  research evidence, never a test fixture.

## Provenance and maintenance

Authored 2026-07-02 against the main tree (calc wave 2 in flight in a separate worktree).
Re-verify before trusting any claim above:

- Refuse-list ship state: `ls "Salehman AI/StockSage/StockSageRefuseList.swift"` (absent 2026-07-02 = in flight; plan: `plans/PLAN_2026-07-03_calc_wave2_cost_honesty.md` Item A).
- Execution timing shipped: `grep -n "sessionNote" "Salehman AI/StockSage/StockSageExecutionTiming.swift"` and `grep -n "defaultShortBorrowRate" "Salehman AI/StockSage/StockSageNetEdge.swift"`.
- The DSR bar: `grep -n "dsr > 0.95" "Salehman AI/StockSage/StockSageDeflatedSharpe.swift"` (→ `passes`).
- Significance semantics: `grep -n "passesHonestSignificance\|clearsMultipleTestingBar\|estimatedStrategyTrials" "Salehman AI/StockSage/StockSageStrategyBacktest.swift"`.
- Measurement surface: `grep -n "strategyBacktestPanel\|refreshStrategyBacktest" "Salehman AI/Views/MarketsView.swift" "Salehman AI/StockSage/StockSageStore.swift" | head -5`.
- Roadmap + anti-edge numbers: re-read `RESEARCH_2026-07-02_week_horizon_velocity.md` (roadmap §1–3, Refuse-list, "did NOT establish").
- Open items + milestones: `grep -n "OPEN FRONTIER" research/INDEX.md` (section added 2026-07-02).
- Owner-gate registry: read `gated-scope` ("How", step 1) — the ONLY canonical copy; if this skill's gate IDs (RANKING #10, F01/F02, F08, F10, F03/F44) disagree with it, gated-scope wins.
- Suite/universe sizes are deliberately NOT stated anywhere above — gate on verdict lines and named symbols, never counts.
