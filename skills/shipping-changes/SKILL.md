---
name: shipping-changes
description: The merge pipeline and per-change chores for Salehman AI — independent build+test gate, DEVELOPMENT_LOG entry, SOURCE_BUNDLE regen, MARKETS_TAB_MAP update, add-by-name commit, self-hosted CI gate, ff-only merge to main, rollback. Use when ANY change (code, docs, tests; wave or single fix) is ready to land, or when a landed change must be reverted.
---

# Shipping changes — the pipeline EVERY change goes through

This applies to every change, wave or not — a one-line label fix ships through the same
six steps as a 20-file wave. All commands run from the repo root (`/Users/saleh/ai`).
The repo is `swonyu/Salehman-AI` (private); CI runs on a **self-hosted Mac runner** on
every push; `gh` lives at **`/opt/homebrew/bin/gh`** (NOT on the Bash tool's default PATH).

**Step 0 — owner-gate check.** Before shipping, confirm nothing in the diff crosses a
parked owner gate: RANKING #10 (`preferVelocity` default flip), F01/F02 (identity-calibration
engine options), F08 (Conviction ↔ Signal-strength term), F10 (decimal-comma locale),
F03 (weekly-rollup gross→net). These are **refused, not flagged-and-done** — full procedure
and the current registry live in the `gated-scope` skill. Same for the honesty floor: no new
surface may fabricate a nil, show an unlabeled estimate, mix gross/net unlabeled, or present
signal-strength as P(profit).

## 1. Independent full build + suite (after your LAST edit, including the correction pass)

```bash
xcodebuild -scheme "Salehman AI" -destination 'platform=macOS' -configuration Debug CODE_SIGNING_ALLOWED=NO build 2>&1 | tee /tmp/salehman_build.log | tail -25
xcodebuild test -scheme "Salehman AI" -destination 'platform=macOS' -configuration Debug CODE_SIGNING_ALLOWED=NO -only-testing:"Salehman AITests" 2>&1 | tee /tmp/salehman_build.log | tail -25
```
- Gate on the **verdict LINE**: `** BUILD SUCCEEDED **` / `** TEST SUCCEEDED **`. NOT on `$?`
  — the pipe's exit code is `tail`'s (always 0). This exact false-green happened in CI until
  `set -o pipefail` was added to `ci.yml`.
- The suite is ~1,450+ Swift Testing cases; **per-test counts fluctuate ±1** from
  parallel-runner log interleaving — never gate on "Executed N tests", only on the verdict.
- On failure, list the failures (never Read/cat the log into context):
  ```bash
  grep -E "Test case '.*' failed" /tmp/salehman_build.log | sed -E "s/.*'([^']+)'.*/\1/" | sort -u
  ```
- If a fix/correction pass touched anything after this ran, **run BOTH again**. "It passed
  before the correction pass" is not a verdict for the tree you're about to commit.

## 2. DEVELOPMENT_LOG.md entry — ANY change gets one (owner directive 2026-06-05)

Find the anchor (never full-file Read the ~9k-line log):
```bash
grep -n '^## Standing notes' DEVELOPMENT_LOG.md    # → e.g. 9106:## Standing notes / known issues
```
Insert your entry **ABOVE that line**, in the format defined at the top of the file:
```
## <YYYY-MM-DD> · <short title>
**Files:** <paths touched>
**What & why:** <what changed and the reason>
**Result:** <build/test status; follow-ups>
```
**The entry describes the FINAL tree, not your narrative.** The 72px-spacer incident: a
wave-11 log draft claimed "added a 72px bottom spacer" after the correction pass had already
DELETED it (it double-gapped under `.safeAreaInset`; the shipped tree uses `DS.Space.sm`),
and claimed "Test fixtures updated: None" after +3 test files. So: run `git diff --stat`,
write the entry from what the diff shows, and count the test files in it before you write
"None". Failures and reversals get logged too — they're the useful part.

## 3. Regenerate the source bundle (after ANY code change)

```bash
bash tools/bundle_source.sh
# → Wrote SOURCE_BUNDLE.md: NNNNNN lines, N.NM, NNN swift files (NNNNN LOC) + markdown docs.
```
`SOURCE_BUNDLE.md` is **tracked** — commit the regenerated file (by name, step 5).
**NEVER Read/cat it** (~530k tokens); and Grep the repo with the CLAUDE.md exclusions:
`--glob '!SOURCE_BUNDLE.md' --glob '!External Artifacts/**' --glob '!*_ARCHIVE.md'`.

## 4. MARKETS_TAB_MAP.md — update the entry for any mapped file you materially changed

If a file with an entry in `MARKETS_TAB_MAP.md` changed behavior, invariants, key symbols,
signatures, consumers, or gained a gotcha, update that file's entry (the Purpose / Key
symbols / Inputs / Consumers / Invariants / Gotchas fields). Repo precedent records even
label-threshold changes (e.g. the F37 momentum-label bar) — when in doubt, update: a stale
map entry misleads every future session. Commit it with the change.

## 5. Git: branch → add by name → commit → push → CI gate → ff-only merge

```bash
git checkout main && git pull --ff-only
git checkout -b <area>/<slug>          # house patterns: ideas-card/iter6-net-cost-ev-day, engine/skew-leftrail, pinned-bar-qa-fix
# ... work + steps 1-4 ...
git add "Salehman AI/StockSage/Foo.swift" "Salehman AITests/FooTests.swift" \
        DEVELOPMENT_LOG.md SOURCE_BUNDLE.md MARKETS_TAB_MAP.md   # EVERY file BY NAME (quote the spaces)
git status --porcelain                 # staged set == exactly your files; nothing else
git commit -m "<Title: what shipped, one line>" \
  -m "<Body: what/why + how it was verified>" \
  -m "Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
git push -u origin <branch>
```
- **NEVER `git add -A` / `-a` / `git add .`** — the working tree routinely carries a
  concurrent session's in-flight edits. `PROJECT_CONTEXT.md` may be dirty from another
  session: never stage, revert, or stash it. (`tools/test_grok_bridge.py` is TRACKED since
  713064e, 2026-07-02 — the old "keep it untracked" rule is obsolete; treat it like any
  other tracked file.)

**CI gate** (push triggers CI on every branch; runs take ~20s–a few min on the runner):
```bash
/opt/homebrew/bin/gh run list --branch <branch> --limit 1
# → completed  success  <commit title>  CI  <branch>  push  <run-id>  22s  <timestamp>
/opt/homebrew/bin/gh run watch <run-id> --exit-status        # blocks; non-zero exit if the run failed
/opt/homebrew/bin/gh run view <run-id> --log | grep -m1 "TEST SUCCEEDED"   # verify by LOG, never the badge
```
Gate = first two columns read `completed success` AND the verdict line is in the log.
If the run sits `queued`, the self-hosted runner is offline (jobs don't fail — they expire
in ~24h): restart the runner service on this Mac; do NOT merge around the gate.

**Merge (fast-forward ONLY):**
```bash
git checkout main && git pull --ff-only
git merge --ff-only <branch>           # refused? main moved — rebase the branch, re-run CI, retry. Never a merge commit, never force.
git push origin main
/opt/homebrew/bin/gh run list --branch main --limit 1        # the main push triggers CI too — wait for completed success
git branch -d <branch> && git push origin --delete <branch>  # delete BOTH sides
```

## 6. End state: fully clean tree

```bash
git status --porcelain
```
Every file YOU touched must be gone from this output (committed and merged) — the expected
end state is EMPTY output (`tools/test_grok_bridge.py` has been tracked since 713064e,
2026-07-02, so it no longer appears as an acceptable `??` line). Any ` M` line that
predates your session belongs to a concurrent session — leave it exactly as found.

## Rollback

- **Merged locally but not pushed:** `git checkout main && git reset --hard origin/main`.
- **Pushed and CI is red / a regression surfaced:**
  ```bash
  git revert --no-edit <sha>            # range: git revert --no-edit <oldest-bad>^..HEAD
  git push origin main                  # then wait for CI 'completed success' on the revert itself
  ```
  Plus a DEVELOPMENT_LOG entry for the revert (step 2 — reversals are logged).
- **A failed CI means fix-or-revert. Never bypass:** no merging over a red run, no re-running
  a red pipeline hoping for green, no `push --force` to main, no "it passed locally".

## Gotchas (things that actually bit)

- **`tail` eats the failure exit code.** Locally AND in CI the xcodebuild pipe ends in `tail`;
  a `BUILD FAILED` once shipped as green because only `$?` was checked. The verdict line is
  the only gate (CI now has `set -o pipefail`, your local shell does not).
- **Log-entry drift (the 72px spacer).** Entries written from memory of the plan, not the
  diff, poison the canonical journal — describe the FINAL tree (step 2).
- **`git add -A` in a two-session repo** stages the other session's half-finished lane and a
  dirty `PROJECT_CONTEXT.md`. Add by name, verify with `git status --porcelain`, every time.
- **`--ff-only` refused** = another session landed on main while your CI ran. Rebase, re-run
  CI on the rebased branch, retry. A merge commit on main breaks the linear-history invariant.
- **Concurrent builds corrupt DerivedData.** `pgrep -f xcodebuild` first; if another session
  is building, use an isolated `-derivedDataPath /tmp/<name>-dd` (see `markets-review-gate`).
- **`gh` not found** = you used bare `gh`. It's `/opt/homebrew/bin/gh` (authed as `swonyu`).
