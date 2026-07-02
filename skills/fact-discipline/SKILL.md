---
name: fact-discipline
description: The evidence rules for the Markets/ideas-tab workstream in Salehman AI — every statistic carries a source and as-of date, every claim carries tier-matched evidence, every "done" carries pasted proof. Use whenever reporting a result, writing a test fixture, logging a change, citing a number, or declaring a step complete.
---

# Fact discipline (ideas-tab workstream)

## The rule
**Every statistic carries a source and an as-of date; a claim about X is admissible only with X-tier evidence (pasted command output for "it works", a hand-derived number for "expected value", a git diff for "what changed", a documented search for "doesn't exist"); anything else is a claim, not a fact — and a claim never closes a step.**
No exceptions for "obvious", "small", "I just ran it", or "the agent said so".

## Why — every one of these happened in THIS repo
- **WHIPPYX vacuous test.** A symbol typo (def `WHIPPYX` vs history key `WHIPPYEX`) made `buildIdeas` return empty; a soft `guard else return` passed silently and the agent reported the test green. Only adversarial review caught that the test verified NOTHING. "It passes" is claim-tier; a done step needs the pasted assertion output proving the behavior *fired* (e.g. `#expect(ideas.count == 1)`).
- **Wave-11 "pre-existing" narration.** An implementation agent described its own edits as "pre-existing in wave-11" — its report contradicted `git diff`. The orchestrator trusted the tree, not the narration. Reports are claims; the diff and the pasted output are the facts.
- **F40 circular fixtures.** A threshold test asserted the implementation's own velocity sums; its "straddle" replacement sat at 13.4× and 0.40× around a 1.5× threshold — any constant in (0.41, 13.4) passed. Expected values come from the captured spec / hand derivation, and boundary pins must genuinely straddle.
- **NetEdge fixture.** A hand-math error (reward 40 vs actual 30) failed a test; the fix was RE-DERIVING with a standalone script — never editing the assertion to match the implementation's output. When derivation and code disagree, one of them is wrong; find out which.
- **Dev-log drift.** A DEVELOPMENT_LOG entry claimed "Added 72px bottom spacer" after the correction pass had DELETED it, and "Test fixtures updated: None" after +3 test files. Logs describe the final tree, verified by reading it — not your memory of intermediate states.
- **What good looks like here:** research corpus uses 3-vote adversarial verification with source+date on every stat (`research/INDEX.md`); the board says "191 priced · 1 couldn't be fetched — ranking covers only what loaded"; an owner-relayed "50% weekly usage cap" claim was flagged unconfirmed, not repeated as fact.

## How — the operational procedure
1. **"It works" ⇒ paste the output.** Run the canonical gates and quote the verdict line + the specific assertion:
   ```bash
   xcodebuild -scheme "Salehman AI" -destination 'platform=macOS' -configuration Debug CODE_SIGNING_ALLOWED=NO build 2>&1 | tee /tmp/salehman_build.log | tail -25
   xcodebuild test -scheme "Salehman AI" -destination 'platform=macOS' -configuration Debug CODE_SIGNING_ALLOWED=NO -only-testing:"Salehman AITests" 2>&1 | tee /tmp/salehman_build.log | tail -25
   grep -E "Test case '.*' failed" /tmp/salehman_build.log | sed -E "s/.*'([^']+)'.*/\1/" | sort -u   # on failure
   ```
   For a new test, additionally prove it CAN fail (run it against a deliberately broken input once, or paste the assertion showing a non-trivial count/value — WHIPPYX rule).
2. **"Expected value is N" ⇒ standalone hand derivation.** Write a throwaway `derive.swift` in the scratchpad that computes N from the SPEC's formula with the fixture inputs — importing nothing from the code under test — and run `swift derive.swift`. Paste both the script's number and the test's. NetEdge rule: a mismatch means re-derive, never re-assert.
3. **"What changed" ⇒ `git diff` is ground truth.** Before reporting or logging: `git diff --stat` then `git diff -- <file>`. Your narration, another agent's report, and the plan are all claims; the diff arbitrates (wave-11 rule). DEVELOPMENT_LOG entries describe the FINAL tree — re-read the touched files/hunks before writing the entry.
4. **"X doesn't exist / is unused" ⇒ paste the search.** The claim is only as good as the command:
   ```bash
   grep -rn "TERM" "Salehman AI/" --include="*.swift" --exclude-dir="External Artifacts"   # plus: never search SOURCE_BUNDLE.md / *_ARCHIVE.md
   ```
   Paste the command AND its empty output. "I didn't see it" is not evidence.
5. **Every statistic ⇒ source + as-of date.** Numbers in code comments, log entries, UI copy, and reports name where they came from and when (`Barber-Odean 2000`, `research/INDEX.md 2026-07-02`, `driver.sh test run 2026-07-02`). Estimates are labeled "assumed"; gross vs net is labeled; partial data says so ("N priced · M couldn't be fetched"). `nil` means unknown — never backfill it with a plausible number.
6. **Owner-relayed and Grok-relayed claims are claims.** Verify against the tree/docs before acting; if unverifiable, carry them forward explicitly flagged "unconfirmed" (the 50%-cap precedent). Never paste relayed code (see `markets-review-gate`).

## Owner gates — "⚠️ pending confirmation" is NOT permission
These decisions are parked for owner sign-off. Do not pick a side, "temporarily" default one, or bundle them into adjacent work (`AUDIT_2026-07-02_ideas_board.md`, `RANKING_BACKLOG.md`):
- **RANKING #10** — EV-vs-velocity default (`preferVelocity`). Held across many waves; ranking changes require empirical validation or owner sign-off.
- **F01/F02** — identity-calibration semantics (nil-from-thin-branch vs provenance marker vs clamp-≤-prior). Present all three; pick none.
- **F08** — canonical term "Conviction" vs "Signal strength" (blocks the F21 sweep).
- **F10** — decimal-comma locale policy ("2,5" → 2.5% vs reject-ambiguous) for a Saudi-first app; touches every money field.
- **Weekly-rollup netting (F03/F44)** — gross vs net for `expectedWeeklyR`; relabeling/netting a headline number and the VelocityHistory continuity break are owner calls.

## Violation examples
**Violating:** "Added the velocity floor. Tests pass, build is green. Also went ahead and defaulted `preferVelocity = true` since the audit leans that way, and updated the log ('fixtures: none')."
— zero pasted output; "leans that way" breaches an owner gate; the log claim is unverified narration.

**Compliant:** "Floor wired at `StockSageExpectedValue.swift:679`. `** TEST SUCCEEDED **` (tail pasted); new pin `#expect(ideas.count == 1)` printed `1` and fails when the floor is disabled (output pasted). Expected 0.62R re-derived via scratchpad `derive.swift` → 0.62 (script output pasted). `git diff --stat`: 2 files. RANKING #10 untouched — still owner-gated. Log entry written after re-reading both hunks."

## The 5-line done-checklist (run before declaring ANY step done)
1. Verification OUTPUT pasted, and it proves the behavior FIRED (non-vacuous assertion) — not "it passes".
2. Every expected value hand-derived by a standalone script from the spec — never from the code under test; boundaries genuinely straddle.
3. `git diff` read and it matches what I'm about to report; the log entry describes the final tree.
4. Every number I'm reporting has a source + as-of date; estimates labeled "assumed"; gross/net labeled; absences backed by a pasted search.
5. Nothing I touched decides an owner gate (RANKING #10, F01/F02, F08, F10, weekly netting) — if it would, STOP and present options instead.
