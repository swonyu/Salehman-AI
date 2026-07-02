---
name: executing-plans
description: How to execute a multi-step plan in this repo (ideas-tab / Markets workstream) without drifting from reality. Use whenever following a written plan, wave spec, or audit-fix list — defines the STOP-on-mismatch rule, the paste-the-output done criterion, and the owner-gate list.
---

# Executing plans — STOP on mismatch, prove every step

**THE RULE: the moment reality differs from the plan in ANY way — a file, symbol, line number, test count, or behavior isn't what the plan says — you STOP that step and report the mismatch; and a step is DONE only when its verification command's actual output is pasted into your report and that output proves the behavior fired. "It should pass", "it passes", "verified locally", a green summary line without the command, or proceeding past a mismatch because "the intent is clear" are all violations — no exceptions, including trivial-looking ones.**

## WHY — every clause above is scar tissue from this repo

- **WHIPPYX vacuous test.** A symbol typo (`'WHIPPYX'` in the def vs `'WHIPPYEX'` in the history key) made `buildIdeas` return empty and a soft `guard else return` pass silently; the agent reported the test green. Only adversarial review caught that the test verified NOTHING. Hence "output proves the behavior fired": assert the positive (`#expect(ideas.count == 1)`), and paste the run output — a bare "passed" is compatible with an empty no-op.
- **Wave-11 "pre-existing" narration.** An implementation agent described its own edits as "pre-existing in wave-11" — its report directly contradicted `git diff`. The orchestrator trusted the tree, not the narration. Reports are claims; the diff and pasted command output are the facts.
- **F40 circular fixtures.** A threshold test asserted the implementation's own velocity sums back at itself, and its replacement's "straddle" fixtures sat at 13.4x and 0.40x around a 1.5x threshold — ANY constant in (0.41, 13.4) would have passed. Expected values come from the captured spec or hand derivation, never from calling the code under test; boundary pins must genuinely straddle.
- **NetEdge fixture.** A hand-math error (reward 40 vs actual 30) made a test fail. The fix was RE-DERIVING the number in a standalone swift script — never editing the assertion to match the implementation's output. A red test is a mismatch: STOP and find out which side is wrong before touching either.
- **Dev-log drift.** A DEVELOPMENT_LOG entry claimed "Added 72px bottom spacer" after the correction pass had DELETED it, and "Test fixtures updated: None" after +3 test files. Logs describe the FINAL tree — re-read the diff before writing the entry, not your memory of what you did.

## HOW — the operational loop (ideas-tab workstream)

Per plan step, in order. All commands from the repo root (the dir holding `Salehman AI.xcodeproj`).

1. **Pre-read reality.** Open the exact files/symbols the plan names. Symbol missing, line moved, behavior already shipped, or test count off → that IS the mismatch. STOP, report `plan says X / tree says Y`, wait. Do not "adapt the plan" silently.
2. **Derive expected values by hand, outside the app.** For any numeric assertion (EV, velocity, netRR, calibration output), write a throwaway standalone script and paste its output into the test as a comment:
   ```bash
   cat > /tmp/derive.swift <<'EOF'
   // hand-derivation from the SPEC, not the implementation
   let reward = 3.0 * 10.0; print("expected reward:", reward)
   EOF
   swift /tmp/derive.swift
   ```
   Never import or transcribe the implementation into the derivation (F40). For thresholds, pin fixtures just above AND just below the boundary — verify by hand that they actually straddle.
3. **Build gate** (token discipline: never cat the log):
   ```bash
   xcodebuild -scheme "Salehman AI" -destination 'platform=macOS' -configuration Debug CODE_SIGNING_ALLOWED=NO build 2>&1 | tee /tmp/salehman_build.log | tail -25
   ```
   Paste the tail. Required token: `** BUILD SUCCEEDED **`. Anything else → STOP, grep `/tmp/salehman_build.log`.
4. **Test gate:**
   ```bash
   xcodebuild test -scheme "Salehman AI" -destination 'platform=macOS' -configuration Debug CODE_SIGNING_ALLOWED=NO -only-testing:"Salehman AITests" 2>&1 | tee /tmp/salehman_build.log | tail -25
   # on failure:
   grep -E "Test case '.*' failed" /tmp/salehman_build.log | sed -E "s/.*'([^']+)'.*/\1/" | sort -u
   ```
   Paste the tail showing `** TEST SUCCEEDED **` AND the count of new tests actually running. A new test that never executed proves nothing (WHIPPYX).
5. **Diff is ground truth.** Before reporting the step done: `git diff --stat` + `git diff -- <files>`. Your report describes what the DIFF shows, in the diff's words. If your narrative and the diff disagree, the diff wins and your narrative gets rewritten (Wave-11).
6. **Owner gates — a step touching any of these STOPS regardless of how sure you are.** "⚠️ pending confirmation" in a plan is NOT permission; RANKING #10 stayed parked across many waves and that was correct.
   - **RANKING #10** — EV-vs-velocity default (`preferVelocity` opt-in default)
   - **F01/F02** — identity-calibration semantics (hold the three options: nil-from-thin-branch / provenance marker / clamp ≤ prior — do not pick one)
   - **F08** — canonical term: "Conviction" vs "Signal strength"
   - **F10** — decimal-comma locale policy (Saudi-first; affects every money field)
   - **F03/F44** — weekly-rollup netting (net the headline vs label it "gross, before costs")
7. **Log last.** Write the DEVELOPMENT_LOG entry from the final `git diff`, after all correction passes — list test-file changes by counting them in the diff, not from memory.

## Violation examples

**VIOLATING** (each sentence is a separate offense):
> Step 3 done — added the velocity test, it passes. The plan referenced `StockSageVelocity.swift:212` but the function is in `StockSageExpectedValue.swift` now, so I applied it there and moved on. Expected value taken from a quick call to `netVelocity()` to be safe.

**COMPLIANT:**
> Step 3 BLOCKED — mismatch. Plan says the helper lives at `StockSageVelocity.swift:212`; tree has it at `StockSageExpectedValue.swift:679` (moved in wave-9 per git log). Stopping for direction. Derivation ready meanwhile: `swift /tmp/derive.swift` → `expected reward: 30.0`. Nothing edited; `git diff --stat` → empty.
> *(…after go-ahead…)* Step 3 done. Test gate tail: `Test Suite 'Salehman AITests' passed … ** TEST SUCCEEDED **`; new case ran: `Test case 'VelocityTests.netVelocityStraddle' passed` — fixtures at 1.49x/1.51x straddle the 1.5x boundary (hand-derived above). `git diff --stat`: 2 files, +41/−0.

## Done-checklist (run before declaring ANY step complete)

1. Reality matched the plan — or I STOPPED and reported the exact mismatch instead of adapting.
2. Verification command OUTPUT is pasted (build/test tail with `** … SUCCEEDED **`), and it proves the new behavior FIRED (positive assertion executed), not merely that nothing failed.
3. Every expected value was hand-derived (standalone script / spec), never read off the code under test; boundary fixtures genuinely straddle.
4. My report says only what `git diff` shows; no owner-gated item (RANKING #10, F01/F02, F08, F10, F03/F44 netting) was decided by me.
5. DEVELOPMENT_LOG entry written from the final tree, after corrections — counts verified against the diff.

## Gotchas (things that actually bit)

- **A green test can verify nothing.** Soft `guard else return` + wrong fixture key = silent pass (WHIPPYX). Prove the code path fired: assert non-empty results, or temporarily break the implementation and confirm the test goes red before trusting it green.
- **"Fixing" a red test by editing the assertion** is the NetEdge trap. A red test means plan-vs-reality mismatch — STOP, re-derive by hand, and only then decide which side is wrong.
- **Your own memory of the session is not the tree.** Correction passes delete things you added earlier (dev-log drift). Always re-diff before reporting or logging.
- **Test suite ~1,493 cases and parallel** — never have two tests mutate the same global `UserDefaults` key; a flaky collision looks like a plan mismatch and wastes a STOP.
- **Never Read the build log or SOURCE_BUNDLE.md into context** — `tee /tmp/salehman_build.log | tail -25`, grep on failure only (CLAUDE.md token discipline).
