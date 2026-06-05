# CLAUDE.md — standing instructions for Claude Code (and any AI) in this repo

This file is auto-loaded at the start of every Claude Code session. Follow it.

## 🟥 Owner directive (2026-06-05) — LOG EVERYTHING FROM TODAY ONWARD
**After ANY change to this repo — code, docs, config, fixes, features — append a
dated entry to [`DEVELOPMENT_LOG.md`](DEVELOPMENT_LOG.md)** using the format
defined at the top of that file (date · what changed · files · why · result).
This is a hard, standing requirement from the owner. It applies to you (Claude)
and to any other AI (e.g. Grok) the owner hands this repo to. Do not skip it,
even for "small" changes. Failures/reversals get logged too — they're the useful
part.

## 📚 Keep the knowledge base current
- [`PROJECT_CONTEXT.md`](PROJECT_CONTEXT.md) is the canonical "everything about
  this app" doc. When you change the app's structure (new file, new brain, new
  tool, removed module), update PROJECT_CONTEXT.md so an external reader stays
  correct.
- Before the owner hands the app to an external AI/person, regenerate the
  single-file source dump: `bash tools/bundle_source.sh` → `SOURCE_BUNDLE.md`.
- [`ARCHITECTURE.md`](ARCHITECTURE.md) holds the deep data-flow; keep it honest.

## 🛠 Build / test (canonical commands)
```bash
xcodebuild -scheme "Salehman AI" -destination 'platform=macOS' -configuration Debug CODE_SIGNING_ALLOWED=NO build
xcodebuild test -scheme "Salehman AI" -destination 'platform=macOS' -configuration Debug CODE_SIGNING_ALLOWED=NO -only-testing:"Salehman AITests"
```
**Leave it green** — build + tests must pass before you hand work off. New
`.swift` files under `Salehman AI/Salehman AI/` auto-compile (no `project.pbxproj`
edits). Tests run in parallel — never have two tests mutate the same global
`UserDefaults` key.

## 🤝 Three-session coordination
Up to three build sessions work this repo in parallel: **two Claude Code** + **one
Grok**. Ownership lanes + a running handoff log are in
[`COORDINATION.md`](COORDINATION.md). **Claim a file there before editing another
session's lane.** Quick reference:
- **Chat B** (brain/UI): `LLM/*`, `Views/ContentView.swift`, `Views/SettingsView.swift`, `BrainStatus`.
- **Chat A** (agents/markets): `Agents/*`, `Markets/*`, `Views/Markets*`, several `Tools/*`, `Media/LiveTranscriber`.
- **Grok** (tests/docs): `Salehman AITests/*` (test coverage — start with the 8 suites in `CODEBASE_REVIEW.md` §4), plus doc accuracy + new self-contained modules. Onboarding prompt: [`GROK_SESSION_PROMPT.md`](GROK_SESSION_PROMPT.md).
- **Shared (append-only):** `App/AppSettings.swift`, `App/AppState.swift`, `Tools/ToolPolicy.swift`.

## 🔐 Security & secrets
API keys live ONLY in the macOS Keychain (`LLM/KeychainStore.swift`) — never in
source, UserDefaults, or logs. If the owner pastes a key in chat, treat it as
exposed and tell them to rotate it. `.auto` mode is local-first; never make it
silently call a paid cloud API.
