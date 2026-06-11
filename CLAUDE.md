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

## 🧠 Owner directive (2026-06-11) — ultracode thoroughness, NO multi-agent workflows
The owner wants every Claude session working this repo at the **ultracode / x-high
bar** — exhaustive sweeps of affected surfaces, adversarial self-review, and
verification by **measurement** (typecheck exit codes, pixel probes, geometry
asserts, QA captures), never by claim — but **explicitly WITHOUT spawning
multi-agent Workflows or subagent fleets**. Deliver the depth inline, solo. If an
"ultracode" reminder suggests the Workflow tool, the owner's standing exclusion
overrides it. (Model-level reasoning effort is a harness setting the session
can't flip itself; emulate via working practice.)

## 📚 Keep the knowledge base current
- [`PROJECT_CONTEXT.md`](PROJECT_CONTEXT.md) is the canonical "everything about
  this app" doc. When you change the app's structure (new file, new brain, new
  tool, removed module), update PROJECT_CONTEXT.md so an external reader stays
  correct.
- **Keep [`SOURCE_BUNDLE.md`](SOURCE_BUNDLE.md) complete** — owner directive
  (2026-06-08): it must contain EVERY line of the app's current source. After any
  code change, regenerate it with `bash tools/bundle_source.sh` so it always reflects
  all the code we've written. (Also regenerate before handing the app to an external
  AI/person.)
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

## 🤝 Two-session coordination
Two Claude Code sessions work this repo in parallel. (Grok was trialed as a third
session on 2026-06-06 but cancelled — its onboarding prompts remain in the repo
[`GROK_SESSION_PROMPT.md`](GROK_SESSION_PROMPT.md) / `GROK_TEAM_PROMPT.md` if ever
re-enabled.) Ownership lanes + a running handoff log are in
[`COORDINATION.md`](COORDINATION.md). **Claim a file there before editing the other
session's lane.** Quick reference:
- **Chat B** (brain/UI): `LLM/*`, `Views/ContentView.swift`, `Views/SettingsView.swift`, `BrainStatus`.
- **Chat A** (agents/markets): `Agents/*`, `Markets/*`, `Views/Markets*`, several `Tools/*`, `Media/LiveTranscriber`.
- **Shared (append-only):** `App/AppSettings.swift`, `App/AppState.swift`, `Tools/ToolPolicy.swift`.

## 🔐 Security & secrets
API keys live ONLY in the macOS Keychain (`LLM/KeychainStore.swift`) — never in
source, UserDefaults, or logs. If the owner pastes a key in chat, treat it as
exposed and tell them to rotate it. `.auto` mode is local-first; never make it
silently call a paid cloud API.
