# Project skill library — ideas-card / Markets (StockSage) workstream

Version-controlled home for the project skills that let a new engineer or a
smaller AI session (Sonnet-class, or Opus after the Fable handoff) debug,
extend, validate, and advance the **ideas card** — the StockSage money engine
(idea board / cards / detail sheet) in the Markets tab.

`.claude/` is git-ignored, so these live here (tracked) and are **symlinked**
into `.claude/skills/` on this machine so the Claude Code harness loads them.
This directory is the single source of truth; edit the files here.

## Activate on a fresh clone (install step)

The harness only auto-loads skills from `.claude/skills/`. After cloning, link
each tracked skill into that (git-ignored) directory:

```bash
cd <repo-root>
mkdir -p .claude/skills
for s in skills/*/; do n=$(basename "$s"); ln -sfn "../../skills/$n" ".claude/skills/$n"; done
# (use `cp -R` instead of `ln -sfn` if your harness build does not follow symlinked skill dirs)
```

Verify: `ls -la .claude/skills/` shows the symlinks, and each resolves to a
`SKILL.md`.

## The skills

### Discipline gates (how to behave — load on every substantive task)
- **executing-plans** — a step is done only when its verification OUTPUT is pasted; STOP on any plan-vs-reality mismatch.
- **spec-fidelity** — an expected value mirroring an external API/spec/formula comes only from the captured spec; never fix a failing contract test by editing the assertion.
- **gated-scope** — work blocked on an unanswered owner/external question is refused, not flagged-and-proceeded.
- **fact-discipline** — every statistic carries a source + as-of date; tier-X claims need tier-X evidence; absence claims need a documented search.
- **testing-discipline** — hand-derived fixtures via standalone scripts, genuine boundary straddles, hard assertions (no vacuous soft guards).

### Domain + workflow (how the ideas card works and how change moves through it)
- **stocksage-mental-model** — the idea pipeline hop-by-hop, the frozen contracts, where every displayed number comes from.
- **wave-cycle** — the critique → triage → spec → implement → adversarial-verify → gate → ship → visual-QA methodology (ideas-board waves 1–12).
- **shipping-changes** — the merge pipeline + per-change chores (build/test gate, DEVELOPMENT_LOG, SOURCE_BUNDLE regen, MARKETS_TAB_MAP, branch→CI→ff-merge).
- **debugging-guide** — verdict-first log reading, the narrowing ladder, the known traps.
- **visual-qa** — the live-app QA checklist for UI-visible changes (honesty surfaces, no truncation, buy + sell/reduce sheets).
- **research-memory** — using and extending research/INDEX.md (the only durable research record) and the validation gate for ranking/signal changes.
- **opus-operating** — session onboarding read order, model-routing, and maintenance triggers for Opus 4.8 running this workstream.

Also present (operational, not part of this handoff library, still living only
in `.claude/skills/`): `run-salehman-ai` (build/run/screenshot driver),
`markets-review-gate`, `stocksage-engine`.

## Status (2026-07-02)

Authored + adversarially cold-read-reviewed by a Fable-xhigh workflow. The
review's **fix pass did not run** (Fable usage limit; resets Jul 7). A few
skills therefore carry known, unfixed review findings to resolve when that
workflow resumes — notably: `debugging-guide` (the failed-test-extraction grep
is buggy), `visual-qa` (says "5 call sites" for `calibrationChip`; it is 4),
`testing-discipline` (wrong date attributed to the NetEdge reward-40 incident).
Treat those specific lines with suspicion until the fix pass lands.

## Provenance and maintenance

- **Re-link after clone / when a skill is added:** the install loop above.
- **Source of truth is `skills/`;** `.claude/skills/<name>` are symlinks — never edit through the symlink expecting a separate copy.
- **Skill content drifts** when the repo's commands/paths/flags change; each SKILL.md ends with its own re-verification commands — run them if a skill sends you down a wrong path.
