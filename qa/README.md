# qa/ — the app photographs and judges itself

The sandboxed AI session that polishes this UI cannot see the screen, but it
can read files. So the app delivers pictures and verdicts here.

## How to get fresh pictures
- `touch qa/SNAPSHOT_REQUEST` and launch the app (request is consumed only
  after a successful capture), **or** View ▸ "Capture QA Snapshots".
- `touch qa/WINDOW_REQUEST` and launch → `window_*_live.png`: TRUE pixels of
  the real on-screen window (`QACapture.swift` — apps may photograph their own
  windows; no Screen Recording permission involved), **or** View ▸ "Capture
  Live Window".
- Running the UI test `ChatTabUITests/testCaptureQASnapshotsMenuProducesFiles`
  also produces everything (it clicks the menu).

## What lands in `qa/snapshots/` (gitignored)
- 13 surface PNGs (Code tab, main chat live + deterministic galleries,
  narrow-width variants, every other tab, Settings) — rendered offscreen
  through a real `NSHostingView` (round 1 proved plain `ImageRenderer`
  silently blanks ScrollView/AppKit content).
- `INDEX.md` — per-file manifest (what it shows, size, render time, commit).
- `contact_sheet.png` — one-glance montage.
- `CAPTURE_DONE.txt` — completion marker (watched by the AI session).
- `AUDIT.json` — **the verdict** (`QAAudit.swift`): per-snapshot checks
  (`nonBlank`, `canvasFlat` vs the design-language greys, `baselineDiff` %)
  plus a `failures` list. The UI-test gate asserts `failures == []`, so a
  visual regression fails the build.
- `<name>_diff.png` — red heat-map wherever a snapshot moved >0.5% vs its
  baseline.

## Baselines (`qa/baselines/`, gitignored)
Adopt the current snapshots as the comparison baseline with
`touch qa/ADOPT_BASELINES` + launch, or View ▸ "Adopt QA Baselines".
After that, every capture reports per-surface change percentages.

## Known limits
Offscreen renders are static: no hover, focus, or sheet states (UI tests +
the manual checklist cover those). `chat_live.png`/`window_*_live.png` show
the owner's real chat — that's why this folder stays out of git.
