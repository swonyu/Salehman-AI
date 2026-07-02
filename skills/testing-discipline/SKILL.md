---
name: testing-discipline
description: How tests are written in Salehman AI (Swift Testing) — hand-derived fixtures via standalone scripts, genuine boundary straddles, hard assertions, and the never-edit-the-assertion rule. Use whenever writing, fixing, or reviewing a test under Salehman AITests/.
---

# Testing discipline (Swift Testing, Salehman AITests/)

## THE RULE
**Every asserted numeric/string literal is HAND-DERIVED via a standalone script that replicates the engine's documented formula — never eyeballed, and NEVER produced by calling the code under test.** Asserting `velocity(for: idea)` equals a number you got by running `velocity(for: idea)` verifies nothing (circularity — audit finding F40). The derivation lives in a throwaway `derive_<topic>.swift` in your session scratchpad; its printed numbers go into the test as literals, with the arithmetic pasted as a comment.

Tests are Swift Testing: `import Testing`, `@testable import Salehman_AI`, `struct FooTests`, `@Test func`, `#expect`, `Issue.record`. No XCTest.

## The pattern — worked example (real, from `StockSageFastLaneThresholdTests.swift`)
Derive script (imports NOTHING from the app; replicates the spec'd formulas):
```swift
// scratchpad/derive_velocity.swift — run: swift <path>/derive_velocity.swift
let conviction = 0.7
let winProb = 0.35 + conviction * 0.23                    // 0.511  (linear prior, StockSageExpectedValue)
let rewardR = min((130.0 - 100.0) / (100.0 - 90.0), 50)   // 3.0    (entry 100, stop 90, target 130; cap 50)
let evR = winProb * rewardR - (1 - winProb)               // 1.044  (p·R − (1−p))
let velocity = evR / 12                                   // 0.087  (equity hold 12d default)
print(winProb, rewardR, evR, velocity)                    // → 0.511 3.0 1.044 0.087
```
Test asserts the HAND-DERIVED literal, arithmetic in the comment:
```swift
// AAPL: winProb = 0.35 + 0.7*0.23 = 0.511; rewardR = min(30/10, 50) = 3.0
// evR = 0.511*3 − 0.489 = 1.044; vel = 1.044/12 = 0.087  (derived in derive_velocity.swift)
let vel = StockSageExpectedValue.velocity(for: aapl)
#expect(vel != nil && abs(vel! - 0.087) < 0.001)
```
Repo precedent: `derive_hardening.swift` (cited throughout `StockSageBuildIdeasDirectTests.swift`). Formula sources: `StockSage/StockSageExpectedValue.swift` (prior 0.35+0.23·c at line ~75, `ev` ~81, `velocity` ~135), hold defaults crypto 3d / equity 12d (`VelocityHoldDays.defaults`).

## Boundary pins must GENUINELY straddle
A threshold test only pins the constant if its fixtures sit just above AND just below it. **The F40 failure (2026-07-02):** a first-draft "straddle" for the fast-lane 1.5× crypto-dominance threshold used fixtures whose actual ratios were **13.4× and 0.40×** — any constant in (0.41, 13.4) passed, so the test pinned nothing while claiming to. The real fix (in `StockSageFastLaneThresholdTests.swift`): BTC target 108.7 → ratio 1.533 (flag TRUE) vs target 108.5 → ratio 1.455 (flag FALSE) against a shared AAPL spine (vel 0.087) — pinning 1.5 to the interval (1.455, 1.533).

Gate: after deriving a straddle pair, print BOTH ratios from the derive script and check they bracket the constant tightly (within ~±10%). "Fixtures on both sides" is not enough — verify the numbers.

## No vacuous tests — hard `#expect` counts FIRST
**The WHIPPYX failure (2026-07-02):** a symbol typo (`WHIPPYX` in the def vs `WHIPPYEX` in the history key) made `buildIdeas` return empty; a soft `guard let idea = ideas.first else { return }` passed silently and the test was reported green having verified NOTHING. Fixture/key typos read as "no data," not errors.

Required shape (the post-fix pattern in `StockSageBuildIdeasDirectTests.swift`):
```swift
#expect(ideas.count == 1)                                                  // hard count FIRST
guard let idea = ideas.first else { Issue.record("buildIdeas returned no ideas"); return }
#expect(idea.advice.rationale.joined(separator: " ").contains("Whippy volatility"))
```
Never a bare `guard … else { return }` in a test body — every early exit records an `Issue`. A test must be able to FAIL on the empty/no-op path.

## A failing test is fixed by RE-DERIVING, never by re-asserting
When your fixture and the engine disagree, one of them is wrong — find out which with a fresh standalone derivation. **The NetEdge case (2026-07-02, week-horizon roadmap #2):** a draft fixture hardcoded `reward: 40` for entry 100 / stop 90 / target 130, when `abs(130−100)` is 30. The failure surfaced immediately; the fix was re-deriving via a standalone Swift snippet and correcting the FIXTURE. Editing the assertion to whatever the engine printed would have laundered an unknown into a green checkmark — that is the one move this skill exists to forbid. If re-derivation says the ENGINE is wrong, that's a bug report, not a test edit.

## Mechanics that actually bite
- **Parallel runner + global state:** Swift Testing parallelizes across suites — **no two tests may mutate the same `UserDefaults` key** (CLAUDE.md hard rule). `@Suite(.serialized)` only serializes WITHIN one suite; two serialized suites still race each other. When a global key has no injection seam, use the `BrainPreferenceTestLock.swift` pattern: shared `NSLock`, `lock.lock()` THEN `defer { lock.unlock() }` (that order — a defer declared first would unlock a lock never taken and trap).
- **Duplicate `struct …Tests` names break the whole target** (`invalid redeclaration` + a cascade of bogus `has no member` macro errors). Before adding a test type, run the dup-finder from the repo root:
  ```bash
  grep -rhoE '^(@MainActor[[:space:]]+)?(struct|class) [A-Za-z0-9_]+Tests' "Salehman AITests/" \
    | sed -E 's/.*(struct|class) //' | sort | uniq -d          # any output = fix before building
  ```
- **Type-checker timeout:** a one-line array `.map` mixing `Int`/`Double` math can hit `unable to type-check this expression in reasonable time`. Split into typed sub-expressions: `{ (i: Int) -> Double in let x = Double(i); … }`.
- **Tests auto-join the target.** Any `.swift` file under `Salehman AITests/` compiles into the suite (synchronized file groups — no `project.pbxproj` edit). Corollary: never park scratch/draft test files there.

## Fixture price series — deterministic, and long enough
Engine reads return nil (or a neutral no-op) below hard bar minimums — a too-short series makes your test silently exercise the fallback path instead of the behavior. Build series with a deterministic loop (no randomness) and put the derivation in a comment, e.g. `StockSageBuildIdeasDirectTests.swift`'s alternating low/high-vol blocks: "158 bars, CoV = 0.3895 (see derive_hardening.swift)". Verified minimums (defaults, from source):

| Read | Needs | Below it |
|---|---|---|
| `StockSageVolStability.volStability` | ≥ 147 closes (21+126) | nil |
| `StockSageVolRegime.regime` | ≥ 273 closes (21+252) | nil |
| `StockSageReturnShape.returnShape` | ≥ 30 returns (31 closes) | nil |
| `StockSageIndicators.macd` | ≥ 35 closes (26+9) | nil |
| `timeframeConfluence` long leg (TSMOM 12-1) | ≥ 253 closes | `aligned` = nil, not false |
| `momentumQuality` | > 20 closes for any signal | neutral 1.0 (no penalty) |

When testing "nil below the minimum," also test non-nil AT the minimum (the F05 pattern: nil at exactly 20 closes, non-nil at 21) — otherwise an off-by-one in the guard passes. Tolerance conventions: `±0.001` for derived EV/velocity literals, `±1e-6` for pinned composed sizing math (the F06 `requestedHeat` 0.00271875 pin).

## The gate — full suite, verdict line only
```bash
xcodebuild test -scheme "Salehman AI" -destination 'platform=macOS' -configuration Debug \
  CODE_SIGNING_ALLOWED=NO -only-testing:"Salehman AITests" 2>&1 | tee /tmp/salehman_build.log | tail -25
```
- `** TEST SUCCEEDED **` in the tail is the ONLY passing verdict. Anything else — including a plausible-looking summary — is a fail.
- **Do not gate on the per-test count**: it fluctuates ±1 between runs from parallel-runner log interleaving. Chase the verdict line, not the count.
- The verdict alone doesn't prove YOUR new test verified anything (WHIPPYX passed the verdict). Also grep for the named case:
  ```bash
  grep -o "Test case '[^']*yourNewTestName[^']*' passed" /tmp/salehman_build.log
  ```
- On failure: `grep -E "Test case '.*' failed" /tmp/salehman_build.log | sed -E "s/.*'([^']+)'.*/\1/" | sort -u`
- Never `cat`/Read the log into context — `tee | tail` then grep the file. `.claude/skills/run-salehman-ai/driver.sh test` wraps the same command.

## Gotchas (things that actually bit)
- **Test-only changes are still changes.** Append a dated DEVELOPMENT_LOG.md entry ABOVE the "Standing notes" anchor (find it with Grep, not a full-file Read), and run `bash tools/bundle_source.sh` — the bundle includes `Salehman AITests/`. If a `MARKETS_TAB_MAP.md`-mapped file materially changed, update its entry.
- **`git add` by name, never `git add -A`** — `tools/test_grok_bridge.py` stays untracked-untouched, and `PROJECT_CONTEXT.md` may be dirty from another concurrent session (never touch or stage it).
- **Never Read `SOURCE_BUNDLE.md`** (~530k tokens). Grep with `--glob '!SOURCE_BUNDLE.md' --glob '!External Artifacts/**' --glob '!*_ARCHIVE.md'` or every hit triples.
- **Tests never quietly ratify an owner-gated decision.** RANKING #10 (`preferVelocity` default), F01/F02 (identity-calibration options), F08 (Conviction↔Signal-strength term), F10 (decimal-comma locale), F03 (weekly-rollup gross-vs-net) are REFUSED until the owner answers — do not write a test that pins one side of a parked decision. Full list + procedure: `gated-scope` skill.
- **Honesty floor holds in tests too:** nil means unknown — assert nil STAYS nil on insufficient data (the engine's own convention, e.g. `volStability` nil <147 bars); never "fix" a nil by feeding a fabricated fallback into the fixture.
- **Floating-point boundary literals:** a constant like 0.02 isn't exactly representable in binary64 — an exact-boundary test can fail despite correct math (bit `StockSageRebalanceTests.driftExactlyAtBandEdge`, 2026-07-01). Pick bit-exact fixture values (powers-of-two-friendly, e.g. 0.25 with 2500/7500) or assert with a tolerance.
- **Two xcodebuilds on one DerivedData corrupt each other.** Concurrent session → isolated worktree + `-derivedDataPath <worktree>/.dd` (see `stocksage-engine` skill).

## Pre-merge checklist (run all 7, every test change)
1. Every asserted literal traces to a derive script you RAN (`swift <scratchpad>/derive_<topic>.swift`) — arithmetic pasted as a comment next to the assertion, never produced by the code under test.
2. Threshold tests: both straddle ratios printed and verified to bracket the constant tightly (F40).
3. No soft `guard else return` — hard `#expect` count first, `Issue.record` on every early exit (WHIPPYX).
4. Any failure during development was resolved by re-derivation, never by editing the assertion toward the output (NetEdge).
5. Dup-finder grep is silent; no shared `UserDefaults` key mutated without the lock pattern.
6. Full suite: `** TEST SUCCEEDED **` pasted AND your named new cases grepped as `passed` in the log.
7. Test names state the behavior (`cryptoRotationDominantFalseWhenCryptoEVNegative`, not `testCase7`); tautology tests (asserting X == X) deleted, not kept for the count.

## Cross-references
`fact-discipline` (evidence tiers — pasted output, source+date), `gated-scope` (owner gates, BLOCKED protocol), `executing-plans` (plan-vs-tree mismatches), `run-salehman-ai` (driver, typecheck, screenshots).
