---
name: ideas-card-full-review
description: 'End-to-end full review and improvement pass for Salehman AI''s Markets ideas card, ideas board, and detail sheet. Use when asked to full review, audit, review and improve, make the ideas card better, improve the Markets UI, or run a complete shipped-state critique through findings, triage, highest-confidence fixes by default, verification, and visual QA.'
argument-hint: 'Optional scope override: review-only or full wave; default is review plus highest-confidence fixes'
---

# Ideas card full review and improvements

Use this skill when the ask spans BOTH review and improvement on the shipped
ideas-card surface. It is the orchestration layer over the existing project
skills; it does not replace them. Because this skill lives in the repo's tracked
`skills/` library and `.claude/skills` mirror, it is project-scoped only.

## What this skill produces

- A ranked findings list against the current shipped state.
- A triaged improvement set: fix now, hold for owner, reject, or route elsewhere.
- By default, the highest-confidence accepted fixes, unless the user explicitly
  asks for review-only or a formal full wave.
- If the task expands beyond local fixes, the smallest safe fix wave that matches
  the accepted findings.
- Verification evidence: build/test status for touched code and visual-QA status for
  any UI-visible change.

## Use this skill instead of improvising when

- The user says "full review", "audit the ideas card", "review and improve",
  "make the ideas card better", or asks for a broad ideas-surface pass.
- You need to decide whether the right output is findings only, a review-plus-fix
  pass, or a formal improvement wave.
- The request touches the board, cards, or detail sheet and may span copy, layout,
  honesty surfaces, interaction flow, or small engine-adjacent fixes.

Do NOT use this skill for narrower tasks:

- Review of another session's diff only: use [markets-review-gate](../markets-review-gate/SKILL.md).
- A pre-written plan being executed literally: use [executing-plans](../executing-plans/SKILL.md).
- A numbered improvement wave that already has critique + triage artifacts: use [wave-cycle](../wave-cycle/SKILL.md).
- Engine or ranking changes that need empirical validation: use [stocksage-mental-model](../stocksage-mental-model/SKILL.md), [research-memory](../research-memory/SKILL.md), and [ablation-harness](../ablation-harness/SKILL.md).

## Decision tree

1. Decide the mode before doing work.
  - Review plus fixes: the DEFAULT. Implement only the accepted, non-gated,
    highest-confidence local fixes.
  - Review-only: produce findings + triage, no code changes.
   - Full wave: follow [wave-cycle](../wave-cycle/SKILL.md) after the critique and written triage exist.
2. If the request is about someone else's in-flight diff or lane, stop and switch to
   [markets-review-gate](../markets-review-gate/SKILL.md).
3. If a finding changes a parked default, label, formula, ranking behavior, or other
   owner-gated surface, refuse that step and follow [gated-scope](../gated-scope/SKILL.md).
4. If the fix changes numbers, verdicts, calibration, ranking, or other engine output,
   stop treating it as a UI pass and route through
   [stocksage-mental-model](../stocksage-mental-model/SKILL.md).
5. If the change is UI-visible, visual QA is mandatory before calling it done.

## Procedure

### 1. Anchor on the shipped state

- Read the relevant entries in `MARKETS_TAB_MAP.md` before touching files.
- Read the newest relevant audit/review artifact and the recent `DEVELOPMENT_LOG.md`
  entries for the ideas surface; do not re-open closed findings as "new" without a
  fresh reason.
- If you expect to edit, check `COORDINATION.md` or the current lane owner first.

### 2. Gather evidence, not vibes

- Review the live surface named in the ask: ideas board, best-opportunity card,
  fast-lane strip, detail sheet, or all of them.
- Check honesty surfaces first because they are highest severity on this app:
  measured-vs-assumed calibration, gross-vs-net labeling, estimate disclaimers,
  missing-data honesty, gate wording, and any nil/Optional/NaN leakage.
- Then check workflow friction: scanability, decision order, button clarity,
  duplicated copy, density, truncation, keyboard or navigation gaps, and buy vs
  sell/reduce parity.

### 3. Classify every finding before changing code

- Fix now: local, non-gated, clearly correct, and testable.
- Hold: blocked by owner decision, missing evidence, or a lane conflict.
- Reject: not actually an improvement, duplicates an existing documented rejection,
  or weakens the honesty floor.
- Route: belongs to another workflow such as review-gate, research, ablation, or a
  broader wave.

Write the triage in the reply or in a short scratch artifact before implementing.
Silent drops are not allowed.

### 4. Choose the right execution shape

- One or two local findings: fix directly with the smallest edit and validate.
- Several connected UI findings: switch to [wave-cycle](../wave-cycle/SKILL.md) and
  create a written accepted-list artifact first.
- Findings in another session's lane: do not co-edit the monolith; route them with
  [markets-review-gate](../markets-review-gate/SKILL.md).

### 5. Validate at the same granularity as the change

- For code changes, run the narrowest build/test/typecheck that can falsify the fix.
- For string or copy relabels, grep pinned tests before changing text.
- For UI-visible changes, run [visual-qa](../visual-qa/SKILL.md) after the code-level
  gate. A green suite is not enough.
- For spec- or formula-bound expectations, follow
  [spec-fidelity](../spec-fidelity/SKILL.md) and
  [testing-discipline](../testing-discipline/SKILL.md).

### 6. Close honestly

- Report findings first, ordered by severity.
- State what was fixed, what was held, and what still needs owner input.
- If no changes were justified, say so explicitly; a no-op review is valid.
- If code changed, follow [shipping-changes](../shipping-changes/SKILL.md) before
  considering the task complete.

## Completion criteria

- Findings are ranked and each one is classified: fixed, held, rejected, or routed.
- No owner-gated or evidence-blocked step was silently pushed through.
- Any edited code has matching verification output.
- Any UI-visible fix has a visual-QA result.
- The final report distinguishes facts from proposals and names residual risks.

## Common failure modes

- Treating a "full review" as pure brainstorming with no shipped-state evidence.
- Mixing findings from another session's in-flight diff into the current task and
  then editing their lane.
- Filing already-closed audit items again because the recent log or audit wasn't read.
- Letting a UI pass drift into engine semantics without switching workflows.
- Calling the task done after tests while skipping pixels on a changed sheet or board.

## Suggested prompt forms

- `/ideas-card-full-review audit the current ideas card and fix the highest-confidence issues`
- `/ideas-card-full-review review-only: audit the current ideas card and rank the top 5 issues`
- `/ideas-card-full-review full wave: critique the shipped Markets ideas surface and drive an improvement wave`