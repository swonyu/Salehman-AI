---
name: debugging-guide
description: How to localize a failure in Salehman AI without burning context — verdict-first log reading, the narrowing ladder, the known traps that fake failures, and the hard stop-and-escalate lines. Use when a build or test fails, the app misbehaves after a change, or you must decide whether a regression is real.
---

# Debugging guide — localize cheap, verify hard

The failure mode this skill prevents is not "can't find the bug" — it is **burning 100k
tokens reading logs and source before knowing what question you're answering**. Logs are
grep targets, the map is the index, and the tree is the only witness that never lies.

## 1. Verdict first — never read a log, grep it

Canonical commands (from `CLAUDE.md`) already keep output out of context:
```bash
xcodebuild -scheme "Salehman AI" -destination 'platform=macOS' -configuration Debug CODE_SIGNING_ALLOWED=NO build 2>&1 | tee /tmp/salehman_build.log | tail -25
xcodebuild test -scheme "Salehman AI" -destination 'platform=macOS' -configuration Debug CODE_SIGNING_ALLOWED=NO -only-testing:"Salehman AITests" 2>&1 | tee /tmp/salehman_build.log | tail -25
```
(`.claude/skills/run-salehman-ai/driver.sh build|test` wraps the same, logging to `/tmp/salehman_build.log`.)

- The verdict is in the tail: `** BUILD SUCCEEDED **` / `** TEST SUCCEEDED **` /
  `** TEST FAILED **`. **That line is the gate — nothing else counts as a pass.**
- ONLY on failure, extract the failing cases:
  ```bash
  grep -hoE "Test [Cc]ase '[^']+' failed" /tmp/salehman_*.log | sed -E "s/Test [Cc]ase '([^']+)' failed/\1/" | sort -u
  ```
- **Never `cat`/Read a whole build log into context** — they run to megabytes and the
  answer is always one grep away. Same ban as `SOURCE_BUNDLE.md` (~530k tokens, never Read).

## 2. Test-count ±1 is noise, the verdict line is signal

The suite (~1,100+ Swift Testing cases) runs in parallel and the runner's per-test
tally interleaves in the log — counts fluctuate ±1 across identical runs. Do NOT chase
a "missing test": if the tail says `** TEST SUCCEEDED **`, it succeeded. A count delta
is only meaningful alongside a `Test case '…' failed` line.

## 3. Known traps — check these BEFORE suspecting your change

Each of these has produced a fake "regression" in this repo (details in
`run-salehman-ai/SKILL.md` Gotchas):

| Symptom | Actual cause | Fix |
|---|---|---|
| Rebuild "didn't take", old UI shows | `open <App>` re-activates the stale running instance | `driver.sh run` (kills first, then `open -n`) |
| App won't die, two windows | Xcode-launched (⌘R) instance survives `pkill -9` — debugger-owned | Stop it from Xcode; `driver.sh stop` reports "still running (Xcode-owned?)" |
| `screencapture: could not create image from display` | Shell lacks Screen Recording entitlement — expected | computer-use MCP: `request_access(["Salehman AI"])` → `screenshot` |
| `invalid redeclaration of '…Tests'` + cascade of weird macro errors | Two test files declare the same struct (auto-joined target) | `grep -rhoE '^(@MainActor[[:space:]]+)?(struct\|class) [A-Za-z0-9_]+Tests' "Salehman AITests/" \| sed -E 's/.*(struct\|class) //' \| sort \| uniq -d` — rename one |
| `unable to type-check this expression in reasonable time` | One-liner mixing `Int`/`Double` math | Split into typed sub-expressions (`{ (i: Int) -> Double in … }`) |
| Phantom build corruption, both sessions failing | Two xcodebuilds on one DerivedData | `pgrep -f xcodebuild` first; build with `-derivedDataPath /tmp/<name>-dd` |

## 4. Localization ladder — narrowest step that answers the question, then STOP

Run in order; stop the moment you have the cause. Skipping to step 5 is the
context-burn anti-pattern.

1. **Reproduce with the narrowest command.** One failing test, not the suite:
   ```bash
   xcodebuild test -scheme "Salehman AI" -destination 'platform=macOS' -configuration Debug CODE_SIGNING_ALLOWED=NO \
     -only-testing:"Salehman AITests/StockSageAdvisorStopTargetTests/stopTargetIsSymmetricForLongsAndShorts" 2>&1 | tee /tmp/salehman_one.log | tail -10
   ```
   (Format is `Target/StructName/testFunctionName` — struct and function, not file name.)
2. **Read the map entry, not the file.** `MARKETS_TAB_MAP.md` has a per-file entry
   (Purpose / Key symbols / Inputs / Consumers / Invariants / Gotchas) for every
   Markets-tab module — the unit-scale traps (vol is a FRACTION, returns are PERCENT)
   and nil-vs-0 sentinels that cause most "wrong number" bugs live under its Gotchas.
3. **Hand-derive the expected value.** Standalone script in the scratchpad that computes
   the number from the spec formula — importing NOTHING from the code under test
   (repo precedent: `derive_hardening.swift`) — then compare:
   ```bash
   swift /path/to/scratchpad/derive_<topic>.swift   # paste ITS number next to the test's
   ```
   If derivation and code disagree, one is wrong — find out which. NEVER edit the
   assertion toward the implementation's output (the NetEdge rule).
4. **Find the last touch, read-only:**
   ```bash
   git log --oneline -5 -- "Salehman AI/StockSage/StockSageAdvisor.swift"
   ```
5. **Only now read broadly** — and always with the exclusions, or every hit triples:
   ```bash
   grep -rn "TERM" "Salehman AI/" --include="*.swift"    # Grep tool: --glob '!SOURCE_BUNDLE.md' --glob '!External Artifacts/**' --glob '!*_ARCHIVE.md'
   ```

## 5. Ground truth — the tree beats every narration

- **`git diff` / `git status` over any report** — yours, another agent's, Grok's, the
  plan's. A wave-11 agent described its own edits as "pre-existing"; the diff said
  otherwise; the diff won. Pasted command output over memory, always.
- **If the tree contradicts a DEVELOPMENT_LOG entry, the tree wins and the log gets
  corrected** (append the correction above the "Standing notes" anchor — precedent: an
  entry claimed a spacer that a later pass had deleted).
- Reading `git status` here: `?? tools/test_grok_bridge.py` is a permanently untracked
  fixture — leave it; a dirty `PROJECT_CONTEXT.md` may belong to ANOTHER live session —
  never touch or "clean it up". Stage by name only (`git add <file> …`), **never
  `git add -A`** — it would sweep in both.
- After any fix lands: `bash tools/bundle_source.sh`, DEVELOPMENT_LOG entry above
  "Standing notes", and the `MARKETS_TAB_MAP.md` entry if a mapped file materially
  changed. A fix without these is not done.

## 6. STOP and escalate — do not "fix" these

Some failures are not bugs; they are open questions with an owner. Write
`BLOCKED: <exact question>`, present options, and stop (full procedure: `gated-scope`).

- **Engine math disagrees with your expectation** → check `research/INDEX.md` FIRST.
  Many "wrong-looking" behaviors are ratified research decisions: half-Kelly 0.5×,
  the 0.65 trend cap, `skipRecent:21` TSMOM, RS gated OFF, identity-floored
  calibration. Changing engine math without citing the index entry is a violation,
  not a fix.
- **Anything on the owner-gate registry** — refuse, don't flag-and-do:
  RANKING #10 (`preferVelocity` default), F01/F02 (identity-calibration semantics —
  three options stand, pick none), F08 (Conviction vs Signal-strength term),
  F10 (decimal-comma locale), F03/F44 (weekly-rollup gross-vs-net).
- **Honesty floor** — a "fix" that fabricates a nil (unknown), drops an "assumed"
  label, blurs gross vs net, or shows signal-strength as P(profit) is a regression by
  definition, even if it makes a test green.
