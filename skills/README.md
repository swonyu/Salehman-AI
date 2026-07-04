# Project skill library — ideas-card / Markets (StockSage) workstream

Version-controlled home for the project skills that let a new engineer or a
smaller AI session (Sonnet-class, or Opus after the Fable handoff) debug,
extend, validate, and advance the **ideas card** — the StockSage money engine
(idea board / cards / detail sheet) in the Markets tab.

`.claude/` is git-ignored, so these live here (tracked) and are **symlinked**
into `.claude/skills/` on this machine so the Claude Code harness loads them.
This directory is the single source of truth for EVERY skill; edit the files
here. (The former three-dir exception ended 2026-07-03: run-salehman-ai and
markets-review-gate were promoted into `skills/` + symlinked; stocksage-engine
was deleted after its merge into stocksage-mental-model §7.)

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

### Campaign + reference (added 2026-07-02)
- **money-campaign-map** — the decision-gated campaign map for the "no proven edge" problem: phased state machine, ranked solution menu, fenced anti-edges, DSR/PSR promotion bar.
- **stocksage-flags-and-config** — every live engine flag with its ratified default, byte-identical-default params, the deliberately-UNWIRED module registry, and the @AppStorage keys that fake bugs.
- **ablation-harness** — how to run an empirical walk-forward / Deflated-Sharpe validation on real data (in-app Swift harness + standalone-script recipe; net-of-cost mandatory).
- **diagnostics-toolkit** — the `tools/` scripts (typecheck, bundle check, QA, grok-bridge tests) and what their verdict lines mean.
- **incident-ledger** — the canonical failure-archaeology table (IL-01…IL-30); cite rows by id, never retell an incident.

### Operational (promoted into `skills/` 2026-07-03 — the exception list is ended)
Two operational dirs that predated this library were PROMOTED here on
2026-07-03 (git mv preserving history + the driver's executable bit) and are
now symlinked from `.claude/skills/` like everything else; the third,
stocksage-engine, was deleted the same day (its content lives in
stocksage-mental-model §7). Verify with `ls skills/` — it shows both dirs:
- **run-salehman-ai** — build/typecheck/run/screenshot/test driver (`driver.sh`) + click map + launch gotchas.
- **markets-review-gate** — review gate on other sessions' / external code, plus the outbound external-handoff chores (bundle regen, PROJECT_CONTEXT freshness).
- **stocksage-engine** — RETIRED: merged into `stocksage-mental-model` §7 on 2026-07-02; the dir was deleted 2026-07-03 (no tombstone remains).

## Status (2026-07-03)

Authored + adversarially cold-read-reviewed by a Fable-xhigh workflow. The
review's fix pass **landed** 2026-07-02 in commit `0171621` ("Skill-library
fix pass"), repairing the three named findings: the `debugging-guide`
failed-test-extraction grep, `visual-qa`'s `calibrationChip` call-site count
(5 → 4), and `testing-discipline`'s NetEdge incident date. A same-day hygiene
pass then de-duplicated the owner-gate registry (canonical copy now ONLY in
`gated-scope` §1 — every other skill points there) and corrected the stale
"`tools/test_grok_bridge.py` is untracked" lines (it is TRACKED since
`713064e`); five campaign/reference skills were added the same day. On
2026-07-03 the promotion LANDED: `run-salehman-ai` and `markets-review-gate`
were `git mv`'d into `skills/` (history + executable bit preserved) and are
symlinked from `.claude/skills/` like everything else, and the retired
`stocksage-engine` dir was DELETED outright — its content lives in
`stocksage-mental-model` §7, no tombstone remains. The library stands at
**19 skills**, all canonical in `skills/`.
Verify: `ls skills/` (19 dirs) and `git log --oneline | grep 0171621`.

## Provenance and maintenance

- **Re-link after clone / when a skill is added:** the install loop above.
- **Source of truth is `skills/`;** `.claude/skills/<name>` are symlinks — never edit through the symlink expecting a separate copy.
- **Skill content drifts** when the repo's commands/paths/flags change; the domain/tooling/reference skills end with their own re-verification commands (Provenance sections) — run them if a skill sends you down a wrong path. The discipline/workflow skills carry no Provenance block; verify their claims against the tree directly.
