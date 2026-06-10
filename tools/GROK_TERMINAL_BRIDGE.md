# Grok Terminal Bridge

`grok_terminal_bridge.py` turns Grok's web chat into a real local execution agent.
No API key. No credits. Uses the Grok subscription you already have via Safari.

```
task → [bridge injects primer + task into grok.com via Safari JS]
     → Grok replies: CMD: <command>
     → bridge runs it locally, captures real output
     → bridge pastes output back to Grok
     → repeat until [[DONE]]
```

---

## One-time Safari setup

```
Safari → Settings → Advanced → check "Show features for web developers"
Safari → Develop → Allow JavaScript from Apple Events
```

---

## Commands

### Standard run (most common)
```bash
cd "/Users/saleh/Desktop/Salehman AI" && \
python3 "tools/grok_terminal_bridge.py" --auto --yolo \
  --cwd "/Users/saleh/Desktop/Salehman AI" \
  "YOUR TASK HERE"
```

### With auto branch creation (recommended)
```bash
cd "/Users/saleh/Desktop/Salehman AI" && \
python3 "tools/grok_terminal_bridge.py" --auto --yolo \
  --cwd "/Users/saleh/Desktop/Salehman AI" \
  --branch "fix json leak" \
  "YOUR TASK HERE"
```
Creates `grok/fix-json-leak-20260610-1430` and switches to it automatically.

### With task file (for long briefs)
```bash
cd "/Users/saleh/Desktop/Salehman AI" && \
python3 "tools/grok_terminal_bridge.py" --auto --yolo \
  --cwd "/Users/saleh/Desktop/Salehman AI" \
  "$(cat /tmp/grok_task.txt)"
```

### Auto-fix build errors
```bash
cd "/Users/saleh/Desktop/Salehman AI" && \
python3 "tools/grok_terminal_bridge.py" --mode autofix --safari --yolo \
  --cwd "/Users/saleh/Desktop/Salehman AI"
```
Runs xcodebuild itself, sends errors to Grok, loops until green. No task needed.

### Branch management after a session
```bash
# Keep the work:
git checkout main && git merge grok/BRANCH-NAME

# Throw it away:
git checkout main && git branch -D grok/BRANCH-NAME

# Clean up all merged grok/* branches:
bash tools/cleanup_grok_branches.sh

# Force-delete all grok/* branches (unmerged too):
bash tools/cleanup_grok_branches.sh --force
```

---

## Flags

| Flag | Effect |
|------|--------|
| `--auto` | Shortcut: `--mode auto --safari` (the normal way) |
| `--yolo` | Zero prompts — run everything instantly |
| `--auto-approve` | Auto-run safe commands; still confirm dangerous ones |
| `--branch NAME` | Create `grok/<name>-<timestamp>` branch before running |
| `--verify` | Append `git status/diff` to every feedback turn (auto-enabled in --auto) |
| `--no-new-chat` | Reuse the current grok.com conversation instead of starting fresh |
| `--log FILE` | Append all turns to a log file (auto mode defaults to `~/grok_sessions/<session>.log`) |
| `--tasks A B C` | Run multiple tasks in sequence |

---

## Task brief template

Write to `/tmp/grok_task.txt`, then run with `"$(cat /tmp/grok_task.txt)"`.

```
TASK: <one-line description>

CONTEXT:
- <relevant file or commit>
- <pattern to follow (e.g. "use MemoryStore as the model")>

STEP 1 — Read these files first:
CMD: cat "Salehman AI/Path/To/File.swift"
CMD: cat "Salehman AITests/SomeTest.swift"

STEP 2 — Make this exact change:
<describe the change — be explicit about before/after>

STEP 3 — Build:
CMD: xcodebuild -scheme "Salehman AI" -destination 'platform=macOS' -configuration Debug CODE_SIGNING_ALLOWED=NO build 2>&1 | grep -E "error:|BUILD (SUCCEEDED|FAILED)"

STEP 4 — Test:
CMD: xcodebuild test -scheme "Salehman AI" -destination 'platform=macOS' -configuration Debug CODE_SIGNING_ALLOWED=NO -only-testing:"Salehman AITests/TargetTestSuite" 2>&1 | grep -E "passed|failed|TEST (SUCCEEDED|FAILED)"

STEP 5 — Log to DEVELOPMENT_LOG.md (append, never edit existing entries).

Files to change: <list>
Do NOT touch: MarketsView.swift, StockSage/, or any unrelated file.
Do NOT run: git commit, git push, git reset.
Make REAL edits. git diff will be verified after DONE.
```

**Rules for writing good briefs:**
- Use `CMD:` for example commands in the brief, not ` ```run ` fences (Grok copies the format back)
- Name the exact files to change and the exact files to leave alone
- Give before/after snippets for edits — Grok fails at inference, succeeds at copy
- Always end with "Do NOT run: git commit/push/reset" — let Claude Code handle commits
- **Verify the file exists before writing the brief** — Grok will hallucinate task descriptions
  using file names that don't exist in the project. Run `find . -name "*.swift" | grep -i keyword`
  first, or ask Claude Code to confirm the target file exists.

### Real Phase 1 example (ScratchpadStore injectable seam, 2026-06-10)

This task ran successfully against the updated primer:

```bash
cd "/Users/saleh/Desktop/Salehman AI" && \
python3 "tools/grok_terminal_bridge.py" --auto --yolo \
  --cwd "/Users/saleh/Desktop/Salehman AI" \
  --branch "scratchpad-store-seam" \
  "$(cat /tmp/grok_task.txt)"
```

Task brief (`/tmp/grok_task.txt`):
```
TASK: Add injectable testing seam to ScratchpadStore + enable 2 disabled tests.

CONTEXT:
- JSONFileStore already accepts baseDirectory: URL? in its init.
- MemoryStore was JUST updated (commit 4d9e70d) with the same pattern — use it as your model.

STEP 1 — Read these files first:
CMD: sed -n '1,25p' "Salehman AI/Persistence/MemoryStore.swift"
CMD: sed -n '1,100p' "Salehman AI/Persistence/ScratchpadStore.swift"

STEP 2 — Apply this EXACT change to ScratchpadStore.swift.
Change:
  private let store = JSONFileStore<Snapshot>(filename: "scratchpad.json")
  private init() { load() }
To:
  private let store: JSONFileStore<Snapshot>
  private init() {
      self.store = JSONFileStore<Snapshot>(filename: "scratchpad.json")
      load()
  }
  init(testingBaseDirectory: URL) {
      self.store = JSONFileStore<Snapshot>(filename: "scratchpad.json", baseDirectory: testingBaseDirectory)
      load()
  }

STEP 3 — Build:
CMD: xcodebuild -scheme "Salehman AI" -destination 'platform=macOS' -configuration Debug CODE_SIGNING_ALLOWED=NO build 2>&1 | grep -E "error:|BUILD (SUCCEEDED|FAILED)"

Files to change: Salehman AI/Persistence/ScratchpadStore.swift
Do NOT touch: MarketsView.swift, StockSage/, or any other file.
Do NOT run: git commit, git push, git reset.
```

**Note:** This task was ultimately completed by Claude Code because Grok went into roleplay mode
before the updated primer was deployed. With the new primer, the same task should run cleanly.

---

## How the protocol works

Grok receives the **primer** (injected automatically by the bridge), then the task.

The primer tells Grok:
- Its entire reply must be one line: `CMD: <command>`
- No prose, no markdown, no code fences
- Read before editing (`cat` first)
- Verify every edit (`git diff` after)
- Run `git diff --stat` before signalling done
- Signal done with only `[[DONE]]`

The bridge:
- Parses `CMD:` lines (priority 1), then shell-looking fenced blocks (priority 2)
- Skips blocks that look like prose (validated by `_block_looks_like_shell`)
- Rejects `[[DONE]]` if `git status --porcelain` is identical to session-start snapshot
- Skips duplicate commands (logs a note in the report)
- Strips "Upgrade to SuperGrok" UI overlay text inline before parsing

---

## What Grok is good at via the bridge

- Reading and summarizing files (`cat`, `grep`, `sed`)
- Applying precise diffs to Python/shell files
- Writing new shell scripts / Python tools
- Running build commands and reading error output
- Appending to log files (`cat >>`)

## What Grok struggles at (Claude Code does these instead)

- Swift 6 strict concurrency — it refuses or produces wrong code
- Multi-file Swift refactors — context window gets confused
- Anything requiring Xcode knowledge — it suggests GUI steps
- `git commit` — let Claude Code handle commits so DEVELOPMENT_LOG.md is always updated

---

## Logs

Every `--auto` session writes to `~/grok_sessions/<session-id>.log`.
View the latest: `ls -lt ~/grok_sessions/ | head -5`
