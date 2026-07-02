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
   The WHIPPYX test passed green while verifying nothing: a symbol typo ('WHIPPYX' def vs
   'WHIPPYEX' history key) made `buildIdeas` return empty and a soft `guard else return`
   exit silently. Assert the positive path (`#expect(ideas.count == 1)`) and paste the run output.
2. **The diff is the fact; reports are claims.** A wave-11 agent described its own edits as
   "pre-existing." Trust `git diff` and pasted command output over any narration — including your own.
3. **Expected test values come from the captured spec or a standalone hand-derivation
   (`swift /tmp/derive.swift`), NEVER from calling the code under test.** F40's fixtures
   sat at 13.4x and 0.40x around a 1.5x threshold — any constant in (0.41, 13.4) passed.
   When a fixture fails hand-math (NetEdge: reward 40 vs actual 30), re-derive; never edit
   the assertion to match the implementation. Boundary pins must genuinely straddle.
4. **Logs describe the FINAL tree, verified by reading it.** A dev-log entry claimed
   "Added 72px bottom spacer" after the correction pass had deleted it, and "Test fixtures
   updated: None" after +3 test files. Re-check the tree before writing the entry.
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
   → Read that section (~30 lines). These 8 items are the standing owner-gate list.
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
| **Queue for owner** | Every AUDIT §5 item (F01/F02 identity-calibration, F03/F44 gross-vs-net headline, F10 decimal-comma, F08/F21 term, F09, F13, F12, F19/F20); ANY EV/ranking/threshold/engine-constant change (RANKING #10 precedent); ANY honesty-guard removal or wording weakening; anything the `gated-scope` skill marks BLOCKED (unanswered owner decision / spec fact / measurement) | Write `BLOCKED: <exact question>` with options (the F01/F02 three-option pattern) and STOP. Gate 5: pending ≠ permission |
| **Recommend Fable (pay-per-use)** | Adversarial multi-lens verification of engine-math changes; deep-research fan-outs (the corpus standard is 3-vote adversarial verification, source+date per stat — see research/INDEX.md); architecture calls like the F19/F20 view-logic extractions | Tell the owner why the call exceeds your gates; don't attempt a cheap local version |

When unsure which row applies, it's the middle row. A wrong solo change to engine math
costs real money; a queued question costs a day.

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
  `spec-fidelity`, `executing-plans`, `markets-review-gate`, `stocksage-engine`, `run-salehman-ai`.
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
