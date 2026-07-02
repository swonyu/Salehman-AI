---
name: diagnostics-toolkit
description: The measure-don't-eyeball tool inventory for Salehman AI — every live measurement tool (driver.sh subcommands, tools/typecheck.sh, tools/qa.sh in-process snapshot QA, tools/bundle_check.sh), its exact invocation and verdict semantics, the two QA-capture paths and which to use when, and which tools/ scripts are Grok-era legacy. Use when you need to VERIFY something by measurement (a type-check, a build, a visual state, bundle freshness), when choosing between in-process snapshots and computer-use screenshots, or when deciding whether a tools/ script is live or legacy.
---

# Diagnostics toolkit — measure, don't eyeball

The repo's standing bar (CLAUDE.md ultracode directive): verification by
**measurement** — "typecheck exit codes, pixel probes, geometry asserts, QA
captures" — **never by claim**. This skill is the inventory of what actually
measures, how to invoke each tool, and what its verdict looks like.

**When NOT to use this** — this skill tells you *which instrument to point*;
siblings own the procedures around it:
- localizing a failure you already have → **debugging-guide**
- launch/screenshot/test mechanics + click map → **run-salehman-ai**
- the UI checklist itself (what to look FOR on the ideas board) → **visual-qa**
- landing a verified change → **shipping-changes**
- owner-gated decisions → the canonical registry is **gated-scope §1** (never restated here)

**Map, not territory (F46 rule):** every default and path below was verified
2026-07-02 by reading the script/source. Defaults drift — grep the source
before relying on any row (one-liners in Provenance).

**Verdict rule (house-wide):** gate on the **verdict line + exit code**, never
on counts (test counts, surface counts, universe sizes all drift by design).

## Live measurement tools

### 1. `driver.sh` — the app driver (build/run lifecycle)

Location: `.claude/skills/run-salehman-ai/driver.sh` (run from repo root).
Subcommands and their verdicts (verified against the script 2026-07-02):

| subcommand | what it measures / does | verdict semantics |
|---|---|---|
| `typecheck` | delegates to `tools/typecheck.sh` (below) | exit 0 + `✅ Salehman AI app target type-checks clean` |
| `build` | real `xcodebuild` build | greps `** BUILD SUCCEEDED **` from `/tmp/salehman_build.log`; on failure prints `BUILD FAILED — see /tmp/salehman_build.log`, exit 1; on success prints `App: <path>` |
| `path` | prints the built `.app` path from build settings | exit 1 with `no build settings — run 'build' first` if never built |
| `run` | kills stale instances, `open -n` a FRESH copy | exit 1 `did not start` if `pgrep` finds nothing after ~6s |
| `stop` | SIGTERM→SIGKILL all instances | `all stopped` vs `still running (Xcode-owned? quit Xcode)` — an Xcode-debugger-owned copy survives pkill |
| `test` | `xcodebuild test`, app suite only | gate on `** TEST SUCCEEDED **` / `** TEST FAILED **` in the tail — never the case count |

Build/test output stays out of context: the driver already pipes through
`tee /tmp/salehman_build.log | tail -N`; grep the log only on failure.

### 2. `tools/typecheck.sh` — sandbox-safe whole-app type-check

**Why it exists** (from its header): inside the Claude Code agent sandbox,
`xcodebuild` cannot run — its build daemon (XCBBuildService) is denied the
DerivedData write ("Operation not permitted"). This script drives `swiftc`
**directly**, writing only a module cache under `TMPDIR`, and type-checks every
app source file together in Swift 6 mode with the project's exact isolation
settings (`-swift-version 6 -default-isolation MainActor
-strict-concurrency=complete`). It does NOT link, compile assets, or run tests.

```bash
bash tools/typecheck.sh        # ~1–2 min. Exit 0 + "✅ … type-checks clean" = pass.
```
Warnings may scroll above the verdict; only a non-zero exit is a failure.
Tested 2026-07-02: exit 0, verdict line printed. This is the right gate for
most code edits; use `driver.sh build`/`test` (needs full Xcode, no sandbox)
before shipping.

### 3. `tools/qa.sh` + the in-process snapshot harness

**What it is:** the app photographs and judges ITSELF. Dropping
`qa/SNAPSHOT_REQUEST` and launching the app with the `--qa` argument makes
`QASnapshots.checkAndRun()` render every surface offscreen to
`qa/snapshots/*.png` + `INDEX.md` (manifest) + `contact_sheet.png`, then
`QAAudit` writes `AUDIT.json` — the machine verdict — plus `report.html` and
per-surface `*_diff.png` heat-maps vs adopted baselines. Color-vision variants
(`*_deuter/_protan.png`) and geometry asserts (views opt in with
`.qaGeometry("key")`, `QAGeometry.swift`) ride along. No Screen Recording
permission needed. All outputs are gitignored — never commit them.

**Verdict semantics:** the ONLY machine verdict is `AUDIT.json` →
`"failures": []` (the UI-test gate asserts exactly that). `INDEX.md`'s header
also prints `N/N surfaces OK` — gate on that ratio being full, never on N.
⚠️ `tools/qa.sh` itself exits 0 even when the capture never happened — its
printed summary is informational, NOT a gate.

**Verified state 2026-07-02 (live test, both paths exercised):**
- `bash tools/qa.sh` as shipped **fails on this machine**: its default
  `SALEHMAN_APP` points at a DerivedData hash that no longer exists →
  `❌ Debug app not found`, exit 1. Override with `SALEHMAN_APP=<app path>`
  (get it from `driver.sh path`).
- Even with `SALEHMAN_APP` set, the loop **mis-targets**: `qa.sh` touches and
  watches `<repo>/qa/`, but the app's `QASnapshots.qaDir` default is the
  **hardcoded** `~/Desktop/Salehman AI/qa` — a STALE clone of this repo that
  still exists on disk. Live test: the capture ran fine and landed in the
  Desktop clone (INDEX.md stamped with the *clone's* HEAD — `qaDir`'s parent
  `.git` supplies the commit stamp) while `qa.sh` reported
  `(no manifest — capture may have failed)`.
- The env override **works** but only via direct binary exec (`open` does not
  propagate env vars). This is the invocation that verifiably captures the
  live repo:

```bash
APP="$(.claude/skills/run-salehman-ai/driver.sh path)"      # build first if this errors
.claude/skills/run-salehman-ai/driver.sh stop                # stale-binary trap: old instance = yesterday's UI
touch qa/SNAPSHOT_REQUEST
QA_SNAPSHOT_DIR="$PWD/qa" "$APP/Contents/MacOS/Salehman AI" --qa &
# gate on the capture markers, not on elapsed time:
until [ ! -f qa/SNAPSHOT_REQUEST ]; do sleep 3; done         # request consumed = capture succeeded
python3 -c "import json;d=json.load(open('qa/snapshots/AUDIT.json'));print('failures:',d['failures'])"
.claude/skills/run-salehman-ai/driver.sh stop
```
Tested 2026-07-02: wrote `INDEX.md` (all surfaces OK, commit stamp = live-repo
HEAD), `AUDIT.json` `failures: []`, `CAPTURE_DONE.txt` into `qa/snapshots/`.
Timing note (measured once): with baselines present the capture+audit took ~3
minutes — longer than `qa.sh`'s built-in ~75s of wait loops — another reason to
gate on request-consumption + `AUDIT.json` mtime, not on `qa.sh`'s printout.
Baseline adoption: `touch qa/ADOPT_BASELINES` before launch (or
`bash tools/qa.sh --adopt` once its paths are fixed). Docs: `tools/QA.md`,
`qa/README.md` (note: `QA.md` references a `run.sh` that no longer exists —
`driver.sh` is the driver).

### 4. The two QA-capture paths — which is canonical for what

Two genuinely different instruments; don't treat them as substitutes:

| use-case | canonical path | why |
|---|---|---|
| Layout/style regression sweep across ALL surfaces; machine-judged before/after diffs; screen-blind sessions | **in-process snapshots** (§3) | deterministic offscreen renders, `AUDIT.json` verdict, baseline heat-maps, no permissions — but STATIC: no hover, focus, or sheet states |
| Behavior/interaction QA on the live Markets/ideas surface — honesty badges after "Find ideas", buy/sell sheets, truncation at real window sizes | **computer-use pixels** (visual-qa checklist + run-salehman-ai click map) | only real on-screen pixels show interactive/sheet/hover states; `request_access` → `screenshot`; shell `screencapture` is blocked |

UNCERTAIN (2026-07-02): no repo doc records an owner preference between the
two, and `tools/qa.sh`'s stale paths (above) suggest the in-process loop has
not been run from this repo location before today. Both are live; the table is
the working doctrine until the owner ratifies one. Wave visual-QA gates
(wave-cycle / visual-qa) currently mean the computer-use path.

**Zoom / geometry-probe doctrine** (measure, don't eyeball — CLAUDE.md
ultracode + visual-qa): reading small text off a full-window screenshot is a
claim, not a measurement. Use the computer-use `zoom` tool on the exact region;
assert layout invariants via `.qaGeometry("key")` opt-ins so they become
`AUDIT.json` checks; verify type-safety by `typecheck.sh` exit code, presence
by grep, freshness by mtime — never by "it looks right".

### 5. `tools/bundle_check.sh` — SOURCE_BUNDLE freshness gate

```bash
bash tools/bundle_check.sh    # PASS: … newer than all .swift files → exit 0
                              # ERROR: … NOT newer + stale-file list → exit 1
```
Mtime comparison of `SOURCE_BUNDLE.md` vs every `.swift` under `Salehman AI/`.
On FAIL, regenerate with `bash tools/bundle_source.sh` (NEVER Read the bundle —
~530k tokens). Not wired into CI (`.github/workflows/ci.yml` builds + tests
only); it's a manual pre-handoff / shipping-pipeline chore check.
Tested 2026-07-02: PASS, exit 0.

### 6. `tools/auto_checkpoint.sh` — WIP safety net (currently INERT here)

Header: every-6h launchd job that snapshots the whole working tree to an
`auto-backup` branch via a throwaway index + `git commit-tree`, force-pushes
only that branch, never touches main/index/working files. **Verified
2026-07-02: inert for this repo** — its `REPO=` is hardcoded to
`/Users/saleh/Desktop/Salehman AI` (the stale clone) and no
`com.salehmanai.autocheckpoint` job is loaded (`launchctl list` shows only the
CI runner). Session-death protection today = worktree WIP commits, not this
script. Do NOT run it ad hoc (it pushes to the remote).

### 7. `tools/test_grok_bridge.py` — TRACKED bridge test suite

Tracked in git (since commit `713064e` — any doc claiming "untracked" is
stale). Pure-logic unit tests for the Grok bridge's command parser and safety
floor; no Safari, no network.

```bash
python3 tools/test_grok_bridge.py    # trailing "OK" + exit 0 = pass
```
Tested 2026-07-02: OK, exit 0. Run it whenever bridge code is touched; gate on
OK/exit-code, not the test count.

## tools/ inventory — live vs legacy (headers read 2026-07-02)

"Grok-era" = tooling for the grok.com terminal-bridge fleet, trialed and
cancelled 2026-06-06 per CLAUDE.md ("onboarding prompts remain … if ever
re-enabled"). Dormant, not deleted; none of it is a diagnostic.

| script | class | one-line verdict |
|---|---|---|
| `typecheck.sh`, `qa.sh`, `bundle_check.sh`, `bundle_source.sh` | **LIVE diagnostic/chore** | see sections above |
| `auto_checkpoint.sh` | live-intent, **INERT here** | stale `REPO=` + launchd job not loaded (§6) |
| `test_grok_bridge.py` | **LIVE tracked tests** | guards the dormant bridge (§7) |
| `grok_terminal_bridge.py` | Grok-era core (dormant) | the web-Grok→terminal bridge; kept honest by the tracked tests |
| `fleet_supervisor.sh`, `run_parallel_grok.sh`, `run_parallel_safari.sh`, `start_grok_session.sh`, `grok_status.sh`, `apply_grok_diff.sh`, `cleanup_grok_branches.sh`, `grok_cleanup.py`, `grok_sessions_summary.py` | Grok-era orchestration (dormant) | fleet launch/monitor/apply/cleanup around the bridge; no in-repo callers outside `tools/` |
| `GROK_TERMINAL_BRIDGE.md`, `PARALLEL_GROK_GUIDE.md`, `BUGS_bridge_*.md` | Grok-era docs | read only if the bridge is re-enabled |
| `grok_parser.py` | misnamed utility — NOT grok.com | generic log parser using logstash-style "Grok patterns"; no in-repo callers found — classify by header, not filename |
| `export_chat_training.py`, `finetune_export.py`, `finetune_local_mlx.sh`, `finetune_export.jsonl`, `ingest_sessions.py` | training/ingest kit | not measurement tools; out of scope here |
| `zip_to_desktop.sh` | stale-path utility | zips `/Users/saleh/Desktop/Salehman AI` — the STALE clone, not this repo |
| `QA.md` | LIVE doc (one stale ref) | the QA-system spec; its `run.sh` pointer is dead — use `driver.sh` |

## Provenance and maintenance

Verified 2026-07-02 against the working tree (main @ `0f32d31`) by reading
every script header/source named above and by LIVE-running: `typecheck.sh`,
`bundle_check.sh`, `test_grok_bridge.py`, `qa.sh` (default-path fail +
`SALEHMAN_APP` mis-target + `QA_SNAPSHOT_DIR` direct-exec success).
Re-verify any fact before leaning on it:

- driver subcommands: `grep -E '^\s+(typecheck|build|path|run|stop|test)\)' .claude/skills/run-salehman-ai/driver.sh`
- typecheck rationale/flags: `head -20 tools/typecheck.sh` · run: `bash tools/typecheck.sh; echo $?`
- qa.sh default app path: `grep -n 'SALEHMAN_APP' tools/qa.sh`
- app-side qa dir default + env override: `grep -n 'QA_SNAPSHOT_DIR\|Desktop/Salehman AI' "Salehman AI/Tools/QASnapshots.swift"`
- `--qa` launch gate: `grep -rn -- '--qa' "Salehman AI/Tools/QASnapshots.swift" "Salehman AI/Tools/QACapture.swift"`
- machine verdict: `python3 -c "import json;print(json.load(open('qa/snapshots/AUDIT.json'))['failures'])"`
- bundle gate: `bash tools/bundle_check.sh; echo $?`
- bridge tests tracked + green: `git ls-files tools/test_grok_bridge.py` · `python3 tools/test_grok_bridge.py; echo $?`
- auto-checkpoint inertness: `launchctl list | grep -i checkpoint; grep -n 'REPO=' tools/auto_checkpoint.sh`
- DerivedData → source-tree mapping: `for d in ~/Library/Developer/Xcode/DerivedData/Salehman_AI-*; do /usr/libexec/PlistBuddy -c 'Print :WorkspacePath' "$d/info.plist"; done`
- legacy classifications: `head -15 tools/<script>` — headers are the ground truth, filenames lie (`grok_parser.py`).
