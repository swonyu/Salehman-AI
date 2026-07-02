---
name: research-memory
description: How to use and extend the permanent research corpus for Salehman AI's StockSage/Markets workstream — research/INDEX.md is the ONLY durable record of every research run (transcripts auto-delete). Use before proposing ANY engine/ranking/signal change, when asked to research anything market-related, or when recording a finished research run or ablation.
---

# Research memory — the permanent corpus

Session transcripts auto-delete (~30 days). **`research/INDEX.md` is the only permanent
record of every research run ever done for this project.** If a finding isn't in the
index, it will be re-bought at full token price by a future session — or worse,
contradicted. All paths below are relative to the repo root (`/Users/saleh/ai`).

## The corpus map (verified 2026-07-02)

| File | What it is |
|---|---|
| `research/INDEX.md` | The catalog: one dated line per research item + key findings. Auto-loaded into every session via CLAUDE.md's `@research/INDEX.md` import. Keep **< ~200 lines** (46 now). |
| `research/RESEARCH_CORPUS_DIGEST.md` | Fast-load distillation of the 3 largest docs. **Originals win on any disagreement.** |
| `RESEARCH_*.md` (repo **root**, not `research/`) | Detail files — 5 exist, `RESEARCH_2026-06-26_quant_engine.md` … `RESEARCH_2026-07-02_week_horizon_velocity.md`. INDEX links use `../` because of this split. |
| `EDGE_RESEARCH.md`, `MARKETS_INTELLIGENCE_RESEARCH.md`, `DESIGN_RESEARCH_macOS27.md` | Legacy-named detail files, same status. |
| `AUDIT_2026-07-02_ideas_board.md` | The 54-finding ideas-board audit (F01–F54) + the owner-gate list. |

## Hard rules (in order)

### 1. Read before you propose — and NEVER re-research
Before the PLAN phase of any change touching scoring, ranking, EV, calibration, sizing,
or exits: read `research/INDEX.md` **in full**, then open the linked detail file for the
area you're touching. If a topic is already indexed, you do not research it again — you
**extend its entry** (dated `UPDATE` appended to the same line, like the 2026-06-27
candidate-selector activation note). Search for prior art with the repo exclusions:

```bash
grep -rn "TERM" /Users/saleh/ai --include="*.md" \
  --exclude=SOURCE_BUNDLE.md --exclude="*_ARCHIVE.md" --exclude-dir="External Artifacts"
```

### 2. The validation gate — no ranking/signal change ships on a story
A change to ranking, signals, or sizing ships ONLY with (a) empirical validation —
walk-forward on real data, deflated Sharpe, **net-of-cost** — or (b) explicit owner
sign-off. The harness exists: `StockSageBacktester.swift`, `StockSageStrategyBacktest.swift`,
`StockSageDeflatedSharpe.swift` under `Salehman AI/StockSage/`. Two shipped precedents to cite:

- **Confluence + RS ablation** (`RESEARCH_2026-07-02_confluence_rs_ablation.md`): 20-symbol/5-yr
  walk-forward, all p>0.10 at every horizon → **null result, correctly NOT promoted**. Null
  results are wins; they get indexed too.
- **Week-horizon** (`RESEARCH_2026-07-02_week_horizon_velocity.md`): NO 1–5-day equity edge
  survives retail costs standalone (canonical reversal +0.37%/mo gross → **−1.28%/mo net**,
  t=−6.02). The biggest lever is **cost-avoidance** (~1–1.7%/mo), not a new signal.

Validated ablations run the canonical gate and quote the verdict:
```bash
xcodebuild test -scheme "Salehman AI" -destination 'platform=macOS' -configuration Debug \
  CODE_SIGNING_ALLOWED=NO -only-testing:"Salehman AITests" 2>&1 | tee /tmp/salehman_build.log | tail -25
```
`** TEST SUCCEEDED **` is the ONLY verdict that counts. Per-test counts fluctuate ±1
across runs (parallel-runner log interleaving) — never treat a count delta as a result.

### 3. The fact-discipline bar for any NEW research
Full rules in the `fact-discipline` skill; the research-specific floor:
- Every load-bearing claim gets **3-vote adversarial verification** (the week-horizon run:
  25 claims voted, 23 confirmed, 2 killed — the killed ones are listed so nobody reuses them).
- Every statistic carries **source + as-of date** (`Novy-Marx & Velikov, RFS 2016`).
- **Absence claims require a documented search** — paste the command AND its empty output.
- Honesty floor applies to research output too: gross vs net labeled on every figure,
  estimates labeled "assumed", never quote a gross paper figure as an achievable net return,
  and a "What this round did NOT establish" section is mandatory (see the week-horizon file).

### 4. How to append a finished run
1. Write (or extend) the detail file at repo **root**: `RESEARCH_<YYYY-MM-DD>_<topic>.md` —
   question, verdicts with numbers, refuse-list additions, engine mapping, what was NOT established.
2. Append ONE dated line to `research/INDEX.md` under "Detail files", matching the existing
   format: `- **YYYY-MM-DD · topic** → [RESEARCH_....md](../RESEARCH_....md)` + a
   finding paragraph. Check `wc -l research/INDEX.md` — approaching ~200, roll old lines
   into the detail files, never delete findings.
3. DEVELOPMENT_LOG.md entry (required for ANY repo change): find the anchor with
   `grep -n "Standing notes" DEVELOPMENT_LOG.md` and insert ABOVE it, format
   `## <date> · <title>` / Files / What & why / Result.
4. If code shipped with it: `bash tools/bundle_source.sh`, update the touched file's entry
   in `MARKETS_TAB_MAP.md`, leave build+tests green.
5. Commit **by name** (`git add research/INDEX.md RESEARCH_2026-...md ...`). NEVER
   `git add -A` — `tools/test_grok_bridge.py` is deliberately untracked and
   `PROJECT_CONTEXT.md` may be dirty from the other session; never touch either.

### 5. The refuse-list is policy, not opinion
`RESEARCH_2026-07-02_week_horizon_velocity.md` §"Refuse-list" documents 7 verified
anti-edges (naive short-term reversal, standalone PEAD, ~90%-turnover rotation, overnight
round-trip harvesting, crypto funding-seasonality, illiquid-name anomaly implementations,
face-value published effect sizes — haircut 50–60%). These are **settled**. Do not
relitigate one without NEW evidence that itself clears the §3 bar — "Grok says" and
"I read a blog post" do not qualify (see `markets-review-gate`: never paste relayed code).

### 6. The audit and its owner gates
`AUDIT_2026-07-02_ideas_board.md` holds findings F01–F54. When you ship a fix for a
finding, mark its row **closed with the commit hash** in that file — an unmarked row gets
re-audited and re-fixed by the next session. The following are **owner-gated: you refuse
to decide them, you do not flag-and-do them** (present options, pick none):
- **RANKING #10** — EV-vs-velocity default (`preferVelocity`)
- **F01/F02** — identity-calibration semantics (the two CRITICALs)
- **F08** — canonical term "Conviction" vs "Signal strength"
- **F10** — decimal-comma locale policy ("2,5" → 2.5% vs reject)
- **F03/F44** — weekly-rollup gross-vs-net netting/labeling

## Gotchas (things that actually bit)

- **The INDEX went stale against shipped code once** (F46): it said `candidateSelectorEnabled`
  was "off-by-default" after the owner had activated it. Shipped defaults win — verify any
  INDEX claim about a flag against the actual Swift file before relying on it, and fix the
  INDEX entry when you catch drift (that's extending, not re-researching).
- **"Top-3 concentration" is a DISPLAY projection, not an allocator cap.** `maxConcurrent: 3`
  lives only in `StockSageExpectedValue` (fast-lane card math); the real
  `StockSageCapitalAllocator` is governed by maxHeat + half-Kelly + the correlation-aware
  optimizer. A past session nearly "fixed" this non-bug — the week-horizon file §"did NOT
  establish" documents why no code change follows.
- **Detail files live at repo root, INDEX in `research/`** — a link written without `../`
  renders fine in some viewers and 404s in others; copy an existing line's link shape.
- **NEVER Read `SOURCE_BUNDLE.md`** (~530k tokens) and never grep without the exclusions
  above — every repo-wide hit is otherwise duplicated 2–3×.
- **The digest is not the source.** `RESEARCH_CORPUS_DIGEST.md` is for fast recall; before
  acting on a load-bearing number, confirm it in the original detail file.
- **Question coverage ≠ topic coverage.** The week-horizon run produced ZERO verified claims
  on weekly top-3 concentration mechanics — that question is still open even though the
  file exists. Read the "did NOT establish" section before declaring a topic settled.
- **CI**: pushes trigger the self-hosted runner (`gh` is at `/opt/homebrew/bin/gh`, not on
  default PATH). Verify CI by reading the run LOG for `** BUILD SUCCEEDED **`, never the
  badge. Merges to main are fast-forward-only.
