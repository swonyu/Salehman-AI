---
name: gated-scope
description: Hard scope gate for the Markets/ideas-tab workstream in Salehman AI. Work blocked on an unanswered external question (owner decision, unverified spec, missing measurement) is REFUSED for that step, not shipped with a warning. Use before starting any ideas-tab task and before declaring any step done.
---

# Gated scope — refuse, don't flag

## The rule
**If a step depends on an answer you do not have — an owner decision, a spec fact, or a measurement — you do not build it, you do not build a "provisional"/"reversible"/"flag-gated default-off" version of it, and you never mark it done with a warning; you write `BLOCKED: <exact question>` and do only the unblocked remainder.**
A "⚠️ pending confirmation" note attached to shipped work is a violation, not compliance. So are: "did it both ways", "easy to revert", "default preserved so it doesn't count", and "tests pass" without pasted output. The gate opens only when the answer arrives in this session or is written in a repo doc with a date.

## Why — these all actually happened here
- **RANKING #10 / F01-F02 / F08 (the gates that held).** #10's `preferVelocity` default sat parked across many waves because flipping the app's most prominent "best idea" signal is the owner's call; audit F01/F02 was answered with three options, not a pick; F08's term choice was held. These are the template: parked ≠ stalled — the non-gated work continued around them.
- **WHIPPYX vacuous test (DEVELOPMENT_LOG, 2026-07-02 F05/F40 entry).** A symbol typo (`WHIPPYX` def vs `WHIPPYEX` history key) made `buildIdeas` return empty and a soft `guard else return` pass silently; the agent reported the test green. It had verified NOTHING — only an adversarial review caught it. "It passes" answered a question ("did the behavior fire?") that only pasted output like `#expect(ideas.count == 1)` can answer.
- **F40 circular fixtures (same entry).** A threshold test asserted the implementation's own velocity sums, and its replacement's "straddle" fixtures sat at 13.4× and 0.40× around a 1.5× threshold — any constant in (0.41, 13.4) passed. Expected values must come from the captured spec via hand derivation, never from calling the code under test.
- **NetEdge fixture.** A hand-math error (reward 40 vs actual 30) failed a test; the fix was RE-DERIVING via a standalone script. Editing the assertion to match the implementation's output would have laundered the unknown into a green checkmark.
- **Wave-11 "pre-existing" narration.** An implementation agent described its own edits as "pre-existing in wave-11" — its report contradicted the diff. The orchestrator trusted `git diff`, not the narration. Reports are claims; the diff and pasted command output are the facts.
- **Dev-log drift.** A DEVELOPMENT_LOG entry claimed "Added 72px bottom spacer" after the correction pass had DELETED it, and "Test fixtures updated: None" after +3 test files. Logs describe the final tree, verified by reading it.
- **Unverified relayed claim.** A "50% weekly usage cap" in an owner-relayed prompt was flagged as unconfirmed rather than repeated as fact. Owner-relayed ≠ owner-verified (see also the Grok heuristic in `markets-review-gate`).

## How — the operational procedure (ideas-tab workstream)

**1. Check the parked owner-gate list before planning.** Currently gated (as of 2026-07-02; see `RANKING_BACKLOG.md` + `AUDIT_2026-07-02_ideas_board.md`):
- **RANKING #10** — flipping MarketsView's `bestOpportunity` default to `preferVelocity: true` (shipped opt-in only; the default flip is a product decision).
- **F01/F02** — identity-calibration semantics: nil-from-thin-branch vs provenance marker vs clamp ≤ prior. Three options stand; do not pick one. Owner-activated + test-locked — touching it without the answer breaks a ratified default.
- **F08** — canonical term "Conviction" vs "Signal strength" (blocks the unification sweep and the F21 reword).
- **F10** — decimal-comma locale policy ("2,5" → 2.5% vs reject-ambiguous) for a Saudi-first app; affects every money field.
- **F03 weekly-rollup netting** — `expectedWeeklyR` gross vs net: relabels a headline number and netting creates a false "fading" step vs prior gross VelocityHistory snapshots.
Plus the standing honesty-floor rule: **any** ranking change needs empirical validation or owner sign-off — new gates get added here, never quietly bypassed.

**2. Evidence gates — a step is done only when its verification OUTPUT is pasted.** Run the canonical commands, keep the log out of context, paste the verdict line AND the line proving the specific behavior fired:
```bash
xcodebuild -scheme "Salehman AI" -destination 'platform=macOS' -configuration Debug CODE_SIGNING_ALLOWED=NO build 2>&1 | tee /tmp/salehman_build.log | tail -25
xcodebuild test -scheme "Salehman AI" -destination 'platform=macOS' -configuration Debug CODE_SIGNING_ALLOWED=NO -only-testing:"Salehman AITests" 2>&1 | tee /tmp/salehman_build.log | tail -25
grep -E "Test case '.*' failed" /tmp/salehman_build.log | sed -E "s/.*'([^']+)'.*/\1/" | sort -u   # on failure
```
`** TEST SUCCEEDED **` alone is not proof the new test verified anything (WHIPPYX passed that way). Grep the log for the new test case's name; assertions must be hard (`#expect(ideas.count == 1)` / `Issue.record`), never soft `guard else return`.

**3. Fixtures — hand-derive, never self-derive.** Expected values come from the captured spec computed in a standalone script (repo precedent: `derive_hardening.swift`) that does NOT import or call the code under test:
```bash
swift /tmp/derive_<topic>.swift    # prints hand-derived expected values; paste them into the test as literals
```
Boundary pins must genuinely straddle the constant (F40's real fix pinned 1.5× to (1.455, 1.533)). If a fixture fails, re-derive — never edit the assertion toward the implementation.

**4. Ground truth is the tree.** Before reporting or logging: `git diff --stat` then `git diff -- <file>` for every claim. The DEVELOPMENT_LOG entry describes the FINAL tree — re-read what you're describing; count test files in the diff before writing "Test fixtures updated: None".

**5. Facts.** Every stat carries source+date (see `research/INDEX.md`, 3-vote verified); estimates say "assumed"; gross vs net labeled; unknown stays nil; unverifiable relayed claims get written as "unconfirmed", not repeated as fact.

## Violation examples
**VIOLATING:** "Standardized on 'Signal strength' across card help, VoiceOver, sort case, and filter chip (F08). ⚠️ Pending owner confirmation on the term — trivial to rename later. Also flipped `preferVelocity: true` since velocity ranking is clearly better; flag-gated so it's safe. Tests pass."
*(Three gates bulldozed, one fig-leaf warning, zero pasted output.)*

**COMPLIANT:** "BLOCKED: F08 needs the owner's pick between 'Conviction' and 'Signal strength' — sweep drafted for both, neither applied. RANKING #10 default untouched (opt-in stands). Proceeded with the non-gated F05 work; verification pasted: `Test case 'buildIdeasWhippyNoteLands' passed` + `#expect(ideas.count == 1)` fired on the WHIPPYEX fixture; `** TEST SUCCEEDED **`; `git diff --stat` matches the report (2 test files, 0 engine files)."

## Pre-"done" checklist (run all 5, every step)
1. **Gate scan:** does this step touch RANKING #10 / F01-F02 / F08 / F10 / F03-netting, or need any answer I don't have? → `BLOCKED: <question>`, do only the remainder.
2. **Output pasted:** verdict line + the specific line proving the new behavior fired (named test case / hard `#expect`), not "it passes".
3. **Fixtures independent:** expected values hand-derived via standalone `swift` script; boundary fixtures genuinely straddle.
4. **Diff = report:** `git diff` confirms every claim in the report and the DEVELOPMENT_LOG entry describes the final tree.
5. **Honesty floor:** nil stays nil, estimates labeled "assumed", gross/net labeled, unverified relayed claims marked unconfirmed.
