---
name: wave-cycle
description: The improvement methodology that produced ideas-board waves 1–12 in Salehman AI — multi-lens critique → written triage → spec → single-writer implement → adversarial verify → fix → independent gate → ship → visual QA, as a HARD sequence. Use whenever running an improvement wave on the Markets/ideas surface (or any shipped surface), and whenever tempted to "just improve" something without a critique/triage artifact behind it.
---

# Wave cycle (the ideas-surface improvement methodology)

A **wave** is one full improvement cycle over the CURRENT shipped state of a surface.
Waves 1–12 on the ideas board (all logged in `DEVELOPMENT_LOG.md`, 2026-07-02 entries)
shipped ~60 accepted improvements with zero engine regressions reaching main — because the
steps below ran **in order, every time**. Skipping a step is how regressions ship: wave 8
buried the position sizer for sell/reduce ideas and only step 4 (three independent
verifiers converging) caught it; build+tests alone never would have.

The cycle is a hard sequence. Do not reorder, merge, or skip steps.

## 1. CRITIQUE — multi-lens, against the SHIPPED state

- Spawn 3–5 **read-only** critique agents, each with a **distinct written brief** (lens).
  Real lens sets that worked: wave 4 `trader-workflow / honesty-clarity / badge-density /
  board-scan`; wave 10 `ergonomics / hierarchy / trust / coherence` (Fable-xhigh lenses).
- Each lens critiques the **current tree / running app** — never the plan, never a summary
  of the code. Lenses run independently; no shared drafts, or convergence (step 2's
  strongest signal) is fabricated.
- Each lens returns **ranked proposals** AND **explicit anti-proposals** — changes that
  look like improvements but must not be made, with reasons. The anti-proposal list is as
  valuable as the proposal list; it is what stops the next hasty session.

## 2. TRIAGE — the orchestrator decides, in writing

- Accept / reject / hold **every** proposal with a written reason. No silent drops.
- **Convergence across independent lenses is the strongest accept signal.** Wave 11's #1
  item (pinned verdict CTA bar) was ranked #1-or-top-3 by all four lenses independently.
- **Anything on the owner-gate registry is HELD, never implemented** — refused, not
  flagged-and-done. The canonical registry lives ONLY in the `gated-scope` skill §1 —
  link it from the spec, never restate it there; per-finding detail is in
  `AUDIT_2026-07-02_ideas_board.md`'s "owner decision" rows.
- **Write the accepted list to a spec file BEFORE implementing** (precedent:
  `wave11_accepted.md` in the session scratchpad). The spec names, per item: target files,
  approximate line anchors, the change class (below), known risks (e.g. "engine string
  change may break label-substring test pins — grep the test files first"), and the
  HELD/REJECTED lists so the implementer can't "helpfully" pick one up.

## 3. IMPLEMENT — one writer per file, exact spec

- **One writer per file — across ALL concurrent workstreams, not just this wave.** Two
  agents in one file is last-save-wins clobbering (see `markets-review-gate`); check
  `COORDINATION.md` lanes before assigning. One sequential implementer (historically
  Sonnet at max effort) covering all of a wave's files beats parallel writers colliding.
- Implement the spec **exactly** — deviations go back to triage, not into the diff
  (`executing-plans` STOP-on-mismatch rule).
- **Name the change class and honor it.** The classes used across waves 1–12:
  - *display/label-only*: HARD RULE zero ranking/numeric/decision change, no honesty
    caveat weakened (wave 12's standing rule — say it in the spec verbatim);
  - *engine* (ranking/numeric/verdict): needs tests with hand-derived fixtures
    (`spec-fidelity`), byte-identical defaults for existing callers (precedent:
    `rrIsNet: Bool = false`, `preferVelocity: Bool = false`), and usually an owner gate.
- Gate each edit with the canonical commands (CLAUDE.md — this exact shape):
  ```bash
  xcodebuild -scheme "Salehman AI" -destination 'platform=macOS' -configuration Debug CODE_SIGNING_ALLOWED=NO build 2>&1 | tee /tmp/salehman_build.log | tail -25
  ```

## 4. ADVERSARIAL VERIFY — instructed to BREAK it

- Spawn **independent read-only reviewers** (fresh context, no access to the implementer's
  reasoning) whose brief is to **break the change** — trace call sites, hunt regressions,
  attack the honesty labels. A reviewer may report "clean" only after *failing* to break it.
- **Reports are claims — `git diff` and pasted command outputs are facts.** The wave-11
  incident: an implementation agent described its own edits as "pre-existing"; the diff
  contradicted the narration and the diff won. Never log or accept a verifier's (or your
  own) narration without the diff/output behind it (`fact-discipline` rule 3).
- Scale: wave 9's four verify lenses returned 18 findings on the wave-8 restructure,
  including the sizer regression three of them converged on. Expect real findings; a
  0-finding verify pass on a large wave is itself suspicious.

## 5. FIX residuals

- Triage the findings exactly like step 2 — verifiers are also just claimants, and some
  findings get **rejected with a written reason** (wave 9 rejected the epsilon alert-dedup
  proposal as view-vs-store semantic divergence and documented it instead of "fixing" it).
- Any new/changed fixture is hand-derived by a standalone script, never read off the code
  under test (`spec-fidelity`; precedent `derive_wave11f.swift`). Derivations get preserved
  as inline comments in the test file — the scratchpad is ephemeral.

## 6. INDEPENDENT GATE — re-run it YOURSELF

- The orchestrator re-runs the full build + suite with their own hands. **Never trust an
  agent's green** — waves 8+9 and 11 both record "independently re-run/re-verified (fresh
  build + full suite)" as the merge condition, and that is the standard.
  ```bash
  xcodebuild test -scheme "Salehman AI" -destination 'platform=macOS' -configuration Debug CODE_SIGNING_ALLOWED=NO -only-testing:"Salehman AITests" 2>&1 | tee /tmp/salehman_build.log | tail -25
  ```
- `** TEST SUCCEEDED **` is the ONLY verdict that counts. Per-test counts fluctuate ±1
  between runs from parallel-runner log interleaving — never gate on the count, and never
  "explain" a count delta instead of reading the verdict line. On failure:
  ```bash
  grep -E "Test case '.*' failed" /tmp/salehman_build.log | sed -E "s/.*'([^']+)'.*/\1/" | sort -u
  ```

## 7. SHIP

Follow the `shipping-changes` skill (`.claude/skills/shipping-changes/SKILL.md`) for the
full procedure. The wave-specific must-dos: DEVELOPMENT_LOG entry appended **above the
"Standing notes" anchor** describing the FINAL tree (write it after re-reading the hunks —
the wave-11 log once claimed a spacer that the correction pass had deleted, incident-ledger IL-27);
`bash tools/bundle_source.sh` after any code change; update the `MARKETS_TAB_MAP.md` entry
for any mapped file that materially changed; `git add` by name, never `git add -A`
(`PROJECT_CONTEXT.md` may be dirty from another session — never touch it;
`tools/test_grok_bridge.py` is TRACKED since 713064e — treat it like any other tracked file).

## 8. VISUAL QA — after any UI wave, on LIVE data

Builds and tests do not see pixels. The post-merge live-app QA of waves 11+12 (real
live-board data) caught "Backtest 5 years" wrapping as "Backtes/t 5 years" and — after the
first fix — the verdict chip truncating to "Proceed…", the one element whose legibility is
the bar's whole point. Wave 6 was an entire wave of this for waves 1–5. Defer to the
`visual-qa` skill (`.claude/skills/visual-qa/SKILL.md`); the screenshot mechanics are in
`run-salehman-ai`. A UI wave is not done at step 7.

## What a wave must NOT do

- **Churn for quota.** A wave with no accepted proposals is a valid, cheap outcome — write
  the triage reasons and stop. Never inflate a wave to justify having run one.
- **Unvalidated ranking/engine changes.** Ranking defaults change only with empirical
  validation or owner sign-off — the confluence premise was ablated on 20 symbols × 5 years
  and showed NO significant edge (all p>0.10, `RESEARCH_2026-07-02_confluence_rs_ablation.md`),
  so it stays a `false`-default tie-break. RANKING #10 has been held across every wave.
- **Hiding honesty content behind disclosure.** DisclosureGroups/tabs "to shorten the
  sheet" were unanimously rejected as an honesty-floor violation (wave-10 anti-proposals);
  same for rescaling meters to observed ranges (fabricates confidence) and matching the
  gate to gross R:R (overstates edge). The honesty floor is non-negotiable: nil=unknown
  never fabricated, estimates labeled "assumed", gross vs net labeled, win-prob only from
  realized calibration, signal-strength never shown as P(profit).

## Gotchas (things that actually bit)

- **Narration ≠ diff (wave 11).** An agent's "pre-existing" claim about its own edits was
  false. Diff first, then believe.
- **Label relabels break test pins.** Engine string changes propagate to Copy-plan/Today's
  plan tests asserting substrings — grep `Salehman AITests/` for the old string *before*
  editing, and update pins with hand-derived fixtures, never by copying the new output.
- **"Display-only" drifts into engine.** Wave 8's sizer-panel burial was scoped as a
  display restructure. The verify lenses exist because the class label is a claim too.
- **Grep with the CLAUDE.md exclusions** (`--glob '!SOURCE_BUNDLE.md' --glob '!External
  Artifacts/**' --glob '!*_ARCHIVE.md'`) and never Read `SOURCE_BUNDLE.md` — critique
  lenses that skip this drown in duplicated hits and burn their context.
- **Spec files are session-scratchpad artifacts.** Anything a future session needs
  (derivations, held-item reasons) must land in the repo (test comments, DEVELOPMENT_LOG,
  the audit file) before the session ends.
