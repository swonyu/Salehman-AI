---
name: opus-operating
description: Operating protocol for Claude Opus 4.8 running the Markets/ideas-tab workstream in Salehman AI — session onboarding read order, model-routing table (solo vs owner-gated vs Fable-escalated), artifact maintenance triggers, and install/verification. Use at the start of every session on this repo, after any context compaction, and whenever deciding if a change is yours to make.
---

# Opus operating protocol (Markets / ideas tab)

Fable 5 ran this repo on judgment; you run it on **hard gates**. When a gate and your
instinct disagree, the gate wins. Every gate below exists because the failure it blocks
actually happened here.

## Hard gates (non-negotiable — each cites the real failure it blocks)

1. **Done = pasted verification OUTPUT proving the behavior FIRED.** Never "it passes."
   The WHIPPYX test (incident-ledger IL-23) passed green while verifying nothing.
   Assert the positive path (`#expect(ideas.count == 1)`) and paste the run output.
2. **The diff is the fact; reports are claims.** A wave-11 agent described its own edits as
   "pre-existing" (incident-ledger IL-26). Trust `git diff` and pasted command output over
   any narration — including your own.
3. **Expected test values come from the captured spec or a standalone hand-derivation
   (`swift /tmp/derive.swift`), NEVER from calling the code under test.** F40's fixtures
   didn't straddle (incident-ledger IL-24); when a fixture fails hand-math
   (incident-ledger IL-25, NetEdge), re-derive; never edit the assertion to match the
   implementation. Boundary pins must genuinely straddle.
4. **Logs describe the FINAL tree, verified by reading it.** The 72px-spacer entry
   (incident-ledger IL-27) described deleted work as shipped. Re-check the tree before
   writing the entry.
5. **A "⚠️ pending confirmation" note is NOT permission to proceed.** RANKING #10 stayed
   parked across many waves; audit F01/F02 held with three options presented, F08 held. Hold gates the same way.
6. **Every stat carries source+date; unknowns stay labeled.** nil = unknown, never fabricated;
   the board says "191 priced · 1 couldn't be fetched — ranking covers only what loaded"; an
   owner-relayed "50% weekly usage cap" claim was flagged unconfirmed, not repeated as fact.

## 1. Session onboarding protocol

Exact read order (CLAUDE.md is auto-loaded — obey it; then):

1. **`research/INDEX.md` in full** (charter caps it < ~200 lines). Open a linked
   `RESEARCH_*.md` detail file only before proposing a change in that area.
2. **`MARKETS_TAB_MAP.md`** — Read lines 1–14 (header + "How to read"), then ONLY the
   entries for files you will touch: `grep -n '^### <File>.swift' MARKETS_TAB_MAP.md`
   → Read at that offset (~40 lines). **Never the whole file (~228 KB / 78 entries).**
3. **`AUDIT_2026-07-02_ideas_board.md` §5** — `grep -n '## 5. Needs owner decision'`
   → Read that section (~30 lines) for per-finding detail on parked items. The canonical
   owner-gate registry itself lives ONLY in the `gated-scope` skill §1 — it wins on any
   disagreement.
4. **`DEVELOPMENT_LOG.md` tail** — `grep -n 'Standing notes' DEVELOPMENT_LOG.md`
   → Read the ~60 lines above the anchor (entries append just above it). Never a full-file Read.

**Tool routing (context economy — CLAUDE.md rules, restated because they get skipped):**
- Every Grep: `--glob '!SOURCE_BUNDLE.md' --glob '!External Artifacts/**' --glob '!*_ARCHIVE.md'`
  (git grep: `':!SOURCE_BUNDLE.md' ':!External Artifacts' ':!*_ARCHIVE.md'`).
- Build/test: `.claude/skills/run-salehman-ai/driver.sh typecheck|build|test`, or the canonical
  `xcodebuild … 2>&1 | tee /tmp/salehman_build.log | tail -25`. Grep the log only on failure.
- **NEVER Read `SOURCE_BUNDLE.md`** (~530k tokens, generated). Read real source files.
- QA: read the audit/report text first; open only the failing surface's PNG, never all captures.

**After a context compaction, re-read before touching anything:** your mandate/scratchpad
note; `git log --oneline -10`; `git status`; the MARKETS_TAB_MAP entries for in-flight files.
Do not trust compacted memories of numbers or line refs — re-grep the `file:line`.

## 2. Model-routing table

| Route | What | Gate |
|---|---|---|
| **Opus solo** | Display/label/copy/comment changes; test-only additions; doc updates; QA screenshot passes (`run-salehman-ai` skill) | `driver.sh build` + `test` green with the verdict line pasted; hard gates 1–4 above |
| **Queue for owner** *(2026-07-09: the owner-gate CLASS is retired — verbatim directive + dispositions in `gated-scope` §1. The "owner decision" branch of this row now resolves ON EVIDENCE through the pipeline; what REMAINS queued: honesty-guard removal/weakening, and anything blocked on an unanswered spec fact or missing measurement — those were never owner-gates)* | Historically: everything on the registry + AUDIT §5 rows; ANY EV/ranking/threshold/engine-constant change still requires EMPIRICAL VALIDATION (the "or owner sign-off" branch is what the lift replaced); honesty-guard removal or wording weakening; unanswered spec facts / missing measurements | For the still-blocked classes: write `BLOCKED: <exact question>` with options and STOP |
| **Recommend Fable (pay-per-use)** | Adversarial multi-lens verification of engine-math changes; deep-research fan-outs (the corpus standard is 3-vote adversarial verification, source+date per stat — see research/INDEX.md); architecture calls like the F19/F20 view-logic extractions | Tell the owner why the call exceeds your gates; don't attempt a cheap local version |

When unsure which row applies, it's the middle row. A wrong solo change to engine math
costs real money; a queued question costs a day.

**Workflow model split (9th rev, 2026-07-16 — owner-requested improvement ("can u make the
model-split directive better?"), Claude-authored from this session's measured incidents;
supersedes the 8th rev below):** when a multi-agent Workflow / subagent fleet runs:

*Roles (core unchanged, fallback + effort tiering added):*
- **Planner / adjudicator / final-verifier lenses: Fable 5 xhigh** (`{model:'fable', effort:'xhigh'}`).
  **FALLBACK LADDER (new — encodes the 2026-07-11 weekly-limit incident, where all six critic
  agents died mid-run):** Fable unavailable/limit-hit → **Opus 4.8 xhigh** takes these roles for
  the rest of the session. Never Sonnet for adjudication; never stall the pipeline waiting for
  Fable; record the substitution in the run's log entry.
- **Implementation: Sonnet 5** — `effort:'xhigh'` for real implementation, **but tier the effort
  to the stage (new):** mechanical stages (file copies, renames, enumeration, boilerplate,
  log-scraping) run at `'low'`/Haiku; only genuinely hard code gets xhigh. Quality lives in the
  verify stages, not in burning xhigh on `sed`.
- **Adversarial review / red-team / refactor: Opus 4.8 xhigh** (unchanged), and reviews are
  **bound to shapes, not vibes (new):** (a) engine-math / financial-display changes get a
  falsifiability probe run at CLASS granularity — deep single-method `-only-testing` vacuously
  passes (WHIPPYX, re-confirmed 2026-07-16); (b) research/measurement claims get 2-lens
  verification (code audit + independent re-implementation); (c) copy/a11y changes get the
  honesty-floor checklist (nil≠fabricated, gross/net labeled, assumed/measured provenance).
- **Haiku = recon/enumeration only** — NEVER financial math or honesty copy; NEVER rig external
  API bridges (DeepSeek/Gemini relay stays DROPPED).

*Fleet discipline (new section — codifies what actually bit):*
- **Fleet ≤ 5 concurrent agents** (owner 2026-07-07, unchanged).
- **Single-writer monoliths:** agents never co-edit `MarketsView.swift` or any shared monolith.
  Fleet agents produce self-contained NEW files + an exact wiring instruction (anchor + snippet);
  the orchestrator applies all shared-file wiring serially.
- **One build per DerivedData at a time:** concurrent typecheck/test/QA builds trip the build-DB
  lock and report a FALSE `** TEST FAILED **` (incident 2026-07-16) — wait for builds to idle.
- **Worktree isolation only when agents must mutate the same tree**; prefer disjoint-file
  assignment (cheaper, no merge step).

*Constants:* orchestrator = the session model and ALWAYS runs the independent build+test gate +
merge pipeline itself; never downgrade subagent tiers to compensate for the orchestrator model;
verification floor regardless of who implements — verdict lines pasted, tests fired BY NAME,
probes fail BY NAME, pixels for UI-visible changes. Full revision history + verbatim directives
live in the `feedback-workflow-models` memory.

*Superseded 8th rev (2026-07-07):* three models all at xhigh by role (Fable plan/verify, Sonnet
impl, Opus review); ≤5 fleet; no fallback ladder, no effort tiering, no fleet-discipline rules.
*Superseded 7th rev (2026-07-06):* orchestrator = session model; impl = Fable 5 @ max;
review/verify = Sonnet 5 @ xhigh.

## 3. Maintenance rules (trigger → artifact)

| Trigger | You MUST update |
|---|---|
| Material change to a Markets-tab file | Its `MARKETS_TAB_MAP.md` entry (Purpose/Invariants/Gotchas kept true) |
| ANY code change | `SOURCE_BUNDLE.md` via `bash tools/bundle_source.sh` (never by hand, never Read it) |
| ANY repo change (code, docs, config) | `DEVELOPMENT_LOG.md` entry above "Standing notes" — describing the FINAL tree (gate 4) |
| Any research performed | `research/INDEX.md` dated line + detail file; NEVER re-research an indexed item — extend it |
| An audit finding ships | Mark it closed in `AUDIT_2026-07-02_ideas_board.md` with the commit hash |
| Owner changes the model split | This skill + the routing table above |

## 4. Install steps

- Skills activate by existing: this file lives at `.claude/skills/opus-operating/SKILL.md`;
  the harness reads the frontmatter and lists it in every session's available-skills reminder.
  No registration step. `CLAUDE.md` already auto-loads separately. Companion skills in the
  same directory activate the same way: `gated-scope` (refuse, don't flag), `fact-discipline`,
  `spec-fidelity`, `executing-plans`, `markets-review-gate`, `stocksage-mental-model`
  (absorbed the retired `stocksage-engine`), `run-salehman-ai`.
- Add this pointer line to CLAUDE.md's knowledge-base section (**owner or a session with an
  explicit mandate edits CLAUDE.md — do not add it yourself from this skill**):

  `- **Opus operating protocol:** \`.claude/skills/opus-operating/SKILL.md\` — read at session start: onboarding order, solo-vs-owner-vs-Fable routing, artifact refresh triggers.`

- Verify visibility:
  ```bash
  ls /Users/saleh/ai/.claude/skills/*/SKILL.md          # opus-operating listed
  head -3 /Users/saleh/ai/.claude/skills/opus-operating/SKILL.md   # frontmatter has name:
  ```
  Then in a FRESH session, confirm `opus-operating` appears in the available-skills list
  (or invoke it via the Skill tool). If absent: frontmatter must be the first bytes of the
  file with `name:` + `description:` keys.
