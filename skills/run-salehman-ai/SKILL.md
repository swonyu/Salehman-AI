---
name: run-salehman-ai
description: Build, run, screenshot, and test the "Salehman AI" macOS SwiftUI app. Use when asked to launch/start/open the app, take a screenshot of it, type-check a Swift change, or run its test suite.
---

# Run: Salehman AI (macOS app)

Native **macOS SwiftUI app** (Swift 6, MainActor default isolation, deploy target macOS 26.5).
There is no web/Electron surface — you drive it by building with `xcodebuild`, launching
the `.app`, and screenshotting with the **computer-use MCP**. For most code changes you
don't need to launch it at all: `tools/typecheck.sh` type-checks the whole app target in
~80s without Xcode-running anything.

All paths are relative to the repo root (`<unit>` = the directory holding `Salehman AI.xcodeproj`).
The driver is **`.claude/skills/run-salehman-ai/driver.sh`**.

## Prerequisites

- **Full Xcode** (not just Command Line Tools). Verify:
  ```bash
  xcodebuild -version   # → Xcode 26.x. If this errors with "requires Xcode", run:
  # sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
  ```
  `tools/typecheck.sh` works with only CommandLineTools (it calls `swiftc` directly); a
  real **build/run/test needs full Xcode**.
- No package install/bootstrap. New `.swift` files under `Salehman AI/` auto-compile —
  the Xcode project uses synchronized file groups, so there is no `project.pbxproj` to edit.

## Run (agent path)

```bash
# 1. Fast headless gate for a code change — no app launch (preferred for most edits):
.claude/skills/run-salehman-ai/driver.sh typecheck      # ✅ clean / non-zero on error

# 2. Real build (needed before run/screenshot/test):
.claude/skills/run-salehman-ai/driver.sh build          # prints "App: …/Salehman AI.app"

# 3. Launch a FRESH copy (kills stale instances first — see Gotchas):
.claude/skills/run-salehman-ai/driver.sh run

# 4. Tear down:
.claude/skills/run-salehman-ai/driver.sh stop
```

**Screenshot** (the shell `screencapture` is blocked — see Gotchas — so use the
computer-use MCP):
1. `request_access(["Salehman AI"])` — approve the dialog (grants Screen Recording).
2. `open_application("Salehman AI")` to bring it forward.
3. `screenshot(save_to_disk: true)`.

The app opens on the **Today** tab. Click the top nav to reach a tab — e.g. **Markets**
is at roughly `(753, 292)` when the window is centered — then screenshot to verify.

#### Screenshot the Markets → Ideas card (the money engine)

This is the primary surface (`Views/MarketsView.swift`). Verified click sequence after
`driver.sh run` + `open_application("Salehman AI")`, window in its default centered position
(~516 px wide, top-left ~`(430, 245)`); coordinates are approximate and shift if you move the window:
1. **Markets** tab → click `(753, 292)`. The **Ideas** sub-tab is selected by default.
2. **Find ideas** → click `(847, 484)`, then `wait ~8s`. It analyses the core name universe
   (its size drifts as names are added — never pin the count; the board's own
   *"N priced · M couldn't be fetched"* line is the live number). The top banner flips from
   amber *"Last-good (cached) … NOT live"* to green *"● Live worldwide quotes …"*, and three
   cards populate: **Money velocity**, **Best opportunity now**, **Fast lane**.
3. The default window is short — the **Best opportunity now** / **Fast lane** cards sit below the
   fold. Either drag the bottom-right resize corner down (`left_click_drag (944,628)→(944,845)`)
   or `scroll` down ~10 ticks at `(688, 480)`, then `screenshot(save_to_disk: true)`.

What a correct capture shows (honesty surfaces — if any are missing, something regressed):
the **"⚠ assumed"** badge on EV cards; **Best opportunity now** with Est. EV / R:R / Win est. /
Size + Entry/Stop/Target and *"an estimate from conviction, NOT a forecast"*; the **Fast lane**
concentration warning (*"top 3 fastest are all Equity — closer to ONE bet than 3"*); and the
*"N priced · M couldn't be fetched … ranking covers only what loaded"* partial-universe line.
"Find ideas" needs web access; offline it stays on the cached board and the banner stays amber.

### Direct invocation (no full app)

The engine is pure and unit-tested — to exercise advisor/EV/indicator logic without the GUI,
add a `@Test` in `Salehman AITests/` and run the suite (below). `tools/typecheck.sh`
type-checks the app target alone, which catches the large majority of Swift mistakes fast.

## Test

```bash
.claude/skills/run-salehman-ai/driver.sh test     # xcodebuild test, only-testing the app suite
```
A large, growing Swift Testing suite. **Gate on the verdict line —
`** TEST SUCCEEDED **` / `** TEST FAILED **` — never on the case count** (the count
drifts as tests are added, and the parallel runner's tally interleaves ±1 between
identical runs). List failures with:
```bash
grep -E "Test case '.*' failed" /tmp/salehman_build.log | sed -E "s/.*'([^']+)'.*/\1/" | sort -u
```

## Run (human path)

Open `Salehman AI.xcodeproj` in Xcode and press ⌘R (run) / ⌘U (test). This is what the
owner does; it launches a debugger-attached instance (see Gotchas). Useless for headless
automation — use the driver above.

## Gotchas (things that actually bit me)

- **`open <App>` re-activates an already-running instance** instead of launching your fresh
  binary — so your rebuild appears not to take. `driver.sh run` kills first, then uses
  `open -n` (new instance). If you see the *old* UI after a rebuild, this is why.
- **An Xcode-launched instance survives `pkill`.** A copy started with ⌘R has
  `-NSDocumentRevisionsDebugMode YES` in its argv and is owned by Xcode's debugger; even
  `pkill -9` won't reap it (`driver.sh stop` reports "still running (Xcode-owned?)"). Quit
  it from Xcode (the Stop button) — otherwise you end up with two windows.
- **Shell `screencapture` fails** with `could not create image from display` — the calling
  process lacks Screen Recording entitlement. Screenshot via the computer-use MCP after
  `request_access(["Salehman AI"])`, which grants it.
- **Test target: duplicate `struct …Tests` names won't compile.** Files added under
  `Salehman AITests/` auto-join the target; if two files declare the same type
  (e.g. a standalone `FooTests.swift` and a `struct FooTests` already inside
  `StockSageTests.swift`) you get `invalid redeclaration` + a cascade of
  `has no member …` macro errors. Find them with:
  ```bash
  grep -rhoE '^(@MainActor[[:space:]]+)?(struct|class) [A-Za-z0-9_]+Tests' "Salehman AITests/" \
    | sed -E 's/.*(struct|class) //' | sort | uniq -d
  ```
- **Type-checker timeouts in tests.** A one-line array `.map` mixing `Int`/`Double` math can
  trip `error: the compiler is unable to type-check this expression in reasonable time`.
  Split it into typed sub-expressions (`{ (i: Int) -> Double in let x = Double(i); … }`).
- **Token discipline (repo rule):** never `cat`/`Read` the build log into context. Pipe to
  `tee /tmp/salehman_build.log | tail -3` (driver does this); grep the file only on failure.

## Troubleshooting

| Symptom | Fix |
|---|---|
| `xcodebuild: error: ... requires Xcode` | Only CLT is selected. `sudo xcode-select -s /Applications/Xcode.app/Contents/Developer`. For a quick check that doesn't need Xcode, use `driver.sh typecheck`. |
| `run` shows the old UI after a rebuild | A stale instance is up; `driver.sh run` handles it, but an **Xcode**-owned one must be stopped from Xcode. |
| `screencapture: could not create image from display` | Expected. Use the computer-use MCP screenshot (needs `request_access`). |
| `invalid redeclaration of '…Tests'` | Two test files declare the same type — see the dup-finder above; rename one. |
| `unable to type-check this expression in reasonable time` | Split the offending literal/expression into typed sub-expressions. |
