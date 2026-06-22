# PC_RESUME — how the Windows-PC Claude Code picks up this work

You (Claude Code, running on the always-on Windows PC) are continuing an autonomous
markets-money build that has been running on the owner's Mac. **Everything is in git
`main` — you resume from there, not from any local memory.**

## 1. Sync first
```bash
git pull origin main          # get the latest; HEAD should be at or past commit a96dea8
```
The owner's standing instructions are in `CLAUDE.md` (read it). The full backlog of
specced-but-unbuilt work is in the `*_BACKLOG.md` files; running history is in
`DEVELOPMENT_LOG.md` (append new entries, never edit old ones).

## 2. The one hard limit on this machine
**You CANNOT build or verify the Swift app here** — it's a macOS/Xcode app and the
Windows/WSL toolchain can't compile SwiftUI/AppKit/MainActor isolation. So:
- `bash tools/typecheck.sh` will NOT work here. Don't rely on it.
- Make **conservative, small, reviewable** edits. python-verify every test literal you can.
- In each commit message and the dev-log entry, flag Swift changes **`UNVERIFIED (PC host)`**.
- The **Mac is the verifier**: the owner runs `git pull` + Xcode build/test there to catch
  breakage. Keep changes isolated so a single bad edit is easy to revert.

## 3. Where the work stands (as of commit a96dea8, 2026-06-22)
Just shipped: ranking conviction-gate (no fantasy #1), real-data RuneScape fix,
SAMPLE-data banner, and **SIGNAL #2 volume confirmation**. Next up, markets-money first:
- **SIGNAL_BACKLOG**: #3 relativeStrength vs ^GSPC, #6 volAdjustedMomentum, #4 Donchian, #5 walk-forward.
- **EXIT_BACKLOG**: #1 ExitMode seam (golden-master: `.allAtTarget` == current run() byte-for-byte), #2 ratcheting Chandelier, #3 scale-out simulator.
- **FASTMONEY_BACKLOG**: #1 crypto 7-day week + vol-scaled risk, #2 asset-class ATR stop, #3 always-visible best-move card, #4 ranked top-3.
- **ALLOC_BACKLOG**: #1 Kelly heat-capped allocator, #2 suggestAdd, #3 de-correlated.
- **RANKING_BACKLOG**: #2 regime-gate, #3 journal-calibrated win%, #4 liquidity-gate, … (#1 done).
- Then OSRS / A11Y / VISUAL / HARDENING / APPCORE backlogs.

## 4. Re-arm the autonomous loop
Start a `claude` session in this repo and paste the loop prompt below (it's the exact
prompt the Mac session runs, with the PC caveat folded in). It will pick a backlog item,
implement it engine-first with a test, commit+push, log, and schedule the next tick.

> Owner is away ~a week, ULTRACODE. MARKETS MONEY ENGINE = priority one; honesty lives in
> CODE not lectures; **ONLY REAL DATA** (never fabricate/seed market numbers; sample data
> stays unmistakably labeled). **PC HOST: cannot typecheck Swift — make conservative edits,
> python-verify literals, mark Swift commits `UNVERIFIED (PC host)`; the Mac is the build gate.**
> EACH TICK: pull → pick the top markets-money backlog item (SIGNAL #3 → EXIT #1 → FASTMONEY #1
> → ALLOC #1 → RANKING #2 …) → implement engine-first + python-verified test → commit via
> `git commit -F - <<'MSG'` → push → append DEVELOPMENT_LOG.md (anchor `^## Standing notes`)
> → mark the backlog file. Keep money surfaces caveated; secrets only in Keychain; .auto/free
> never spend. Optionally keep 1–3 markets-money research Workflows in flight. Never idle.
> Re-schedule the next tick (~4–5 min) with this same prompt. Never stop until the owner returns.

## 5. The brain (separate from this dev loop)
The always-on local LLM is Ollama (see `WINDOWS_HOST_SETUP.md` §B) — the Mac app points its
Custom-server brain at this PC. That's independent of the Claude Code dev loop above.
