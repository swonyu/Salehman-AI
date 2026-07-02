---
name: spec-fidelity
description: Hard gate for the Markets/ideas-tab workstream — any expected value that mirrors an external API, spec, or financial formula must come from the captured spec or an independent hand-derivation, never from the code under test; a failing contract test is never fixed by editing the assertion. Use whenever writing/fixing tests, fixtures, thresholds, or anything pinned to a spec.
---

# Spec fidelity — the assertion never bends to the code

**THE RULE:** Every expected value in a test that pins an external API, captured spec, or
financial formula must be transcribed from the captured spec document or produced by a
standalone hand-derivation that imports nothing from the app — and when such a test fails,
the implementation is the suspect: you may NOT edit the assertion until a re-derivation
(pasted, not summarized) proves the fixture itself was wrong. "The code outputs X, so I set
expected to X" is the violation, in every phrasing.

## Why (all of these happened in THIS repo)

Full stories live in the `incident-ledger` skill — cite rows, never retell:
- **F40 circular fixtures** (incident-ledger IL-24): circular expected values and
  non-straddling pins both verify nothing — a "straddle" that any wide range of constants
  passes pins nothing.
- **NetEdge fixture** (incident-ledger IL-25): a failing contract test is fixed by a
  standalone re-derivation that proves which side is wrong — NOT by editing the assertion to
  match the implementation. Same edit, opposite epistemics: the derivation makes it legal.
- **WHIPPYX vacuous test** (incident-ledger IL-23): a test is evidence only when its pasted
  output proves the behavior fired (e.g. `#expect(ideas.count == 1)`), never when "it passes."
- **Wave-11 narration** (incident-ledger IL-26): reports are claims; `git diff` and pasted
  command output are the facts. (Dev-log drift, incident-ledger IL-27, is the same disease.)

## How (ideas-tab operational procedure)

1. **Capture before code.** The spec source is the doc, not memory: `research/INDEX.md` →
   the linked `RESEARCH_*.md` / `EDGE_RESEARCH.md` detail file, or
   `AUDIT_2026-07-02_ideas_board.md`. Cite doc + section in the fixture comment.
2. **Hand-derive expected values** with a standalone script (the ONLY legal source besides
   direct spec transcription):
   ```bash
   cat > /tmp/derive.swift <<'EOF'
   // Inputs typed BY HAND from <doc §section>. Imports NOTHING from the app.
   let entry = 100.0, target = 110.0, qty = 3.0
   print("reward:", (target - entry) * qty)
   EOF
   swift /tmp/derive.swift        # paste this output into the test's fixture comment
   ```
3. **Boundary pins genuinely straddle:** threshold ± epsilon (a 1.5x gate gets fixtures at
   ~1.49x and ~1.51x), and each side asserts a DIFFERENT observable outcome. Prove the test
   can fail: flip the constant once, watch it go red, flip it back.
4. **Run the gates; paste the tails** (never cat the log — grep it only on failure):
   ```bash
   xcodebuild -scheme "Salehman AI" -destination 'platform=macOS' -configuration Debug \
     CODE_SIGNING_ALLOWED=NO build 2>&1 | tee /tmp/salehman_build.log | tail -25
   xcodebuild test -scheme "Salehman AI" -destination 'platform=macOS' -configuration Debug \
     CODE_SIGNING_ALLOWED=NO -only-testing:"Salehman AITests" 2>&1 | tee /tmp/salehman_build.log | tail -25
   grep -E "Test case '.*' failed" /tmp/salehman_build.log   # only when FAILED
   ```
5. **Ground-truth the tree, not the narration:** `git diff --stat && git diff -- <claimed files>`
   before writing the `DEVELOPMENT_LOG.md` entry; the entry describes the FINAL tree you just
   read, not what you remember doing.
6. **Owner gates — parked means parked.** The canonical owner-gate registry lives ONLY in
   the `gated-scope` skill §1 — check it there; never restate it.
   Unique to spec work: if a failing test's "natural fix" would resolve a gated question —
   e.g. by pinning one side of a parked decision into an assertion — stop and ask; a
   fixture is never how an owner decision gets made.

## Violation examples

**VIOLATING** (assertion bent to the code):
> `NetEdgeTests.breakEven` failed: expected 40, got 30. The implementation computes 30, so
> the fixture must be stale — updated the assertion to `#expect(reward == 30)`. Green now. Done.

**COMPLIANT** (re-derivation first; the edit is a consequence of the derivation):
> `NetEdgeTests.breakEven` failed: expected 40, got 30. Re-deriving before touching anything:
> `swift /tmp/derive_netedge.swift` (formula typed from EDGE_RESEARCH.md #2, inputs by hand)
> → `reward: 30.0`. My fixture's 40 used qty 4 by mistake; the implementation is correct.
> Fixing the fixture comment + assertion to the re-derived 30, derivation output pasted above.

## Before declaring ANY step done (run all 5)

1. Verification OUTPUT is pasted (test-gate tail / `#expect` values) — never the word "passes."
2. The output proves the behavior FIRED (counts/values asserted; an empty-result path would fail it).
3. Every expected value traces to the captured spec or a pasted standalone derivation — zero from calling the code under test.
4. `git diff` agrees with every claim in your report and your dev-log entry.
5. No owner-gated surface (canonical registry: `gated-scope` §1) was resolved without sign-off.

## Gotchas (things that actually bit)

- **Fixture/key typos read as "no data," not errors** (WHIPPYX): assert the positive count,
  never just absence-of-crash, or a `guard else return` eats the typo silently.
- **"Straddle" fixtures that don't straddle** (F40): if a wide range of constants passes your
  boundary pin, it pins nothing — derive both sides at threshold ± epsilon.
- **Green-on-first-run is a smell** for a new contract test: prove it CAN fail before trusting it.
- **Your own narration will drift** (wave-11, dev-log): re-read the diff and the final tree
  before reporting; never describe intentions as outcomes.
