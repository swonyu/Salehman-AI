# 🤝 Coordination — two Claude Code chats, one project

Two Claude Code sessions are working on this repo at the same time. There is **no
direct chat-to-chat channel** — this file is how we stay in sync. **Both chats read
and update this file.** When you start touching a file, claim it here.

## Golden rules
1. **One driver per file.** Don't edit a file the other chat owns (below). If you must, say so here first.
2. **Leave it green.** Build must pass before you hand a file back:
   `xcodebuild -scheme "Salehman AI" -destination 'platform=macOS' -configuration Debug CODE_SIGNING_ALLOWED=NO build`
3. **Don't revert the other chat's intentional work** (e.g. `LocalLLM.currentBrain()` / `BrainStatus`, or the Markets feature). Make changes *coexist*.
4. New `.swift` files anywhere under `Salehman AI/Salehman AI/` auto-compile (synchronized Xcode group) — no `project.pbxproj` edits.

## Ownership split

### Chat A — Markets feature + agent backbone (this chat)
- `Markets/**` (data, signals, stores — Phase 2+)
- `Views/Markets/**`, `Views/RootView.swift`, `Views/TabSwitcherBar.swift`, `Views/MarketsView.swift`, `Views/BackgroundView.swift`, `Views/MarketsStub.swift`
- `Agents/AgentPipeline.swift`, `Agents/AgentRegistry.swift`, `Agents/Orchestrator.swift`, `Agents/MissionMemory.swift`, `Agents/MissionPlan.swift`
- `Tools/StockAnalysisTool.swift`, `Tools/AnalyzeImageTool.swift`, `Tools/TranscribeMediaTool.swift`, `Tools/TelegramNotifier.swift`, `Tools/LocalNotifier.swift`, `Tools/AlertCenter.swift`
- `Media/LiveTranscriber.swift`, `Views/LiveTranscriptionView.swift` (perf — done)

### Chat B — Brain/status + chat UI (the other chat)
- `LLM/LocalLLM.swift`, `LLM/OllamaClient.swift`, `BrainStatus` (wherever it lives)
- `Views/ContentView.swift` (header/status, suggestions, chat behavior)
- `Views/SettingsView.swift` *(coordinate: Chat A adds a "Markets & Alerts" section here in Phase 5 — ping before editing)*

### Shared / coordinate before editing
- `App/AppSettings.swift` (both add `@Published` settings + `Keys`) — **append only**, don't reorder.
- `App/AppState.swift`, `App/Salehman_AIApp.swift`.
- `Tools/ToolPolicy.swift` (tool registry).

## Current state (update me!)
- ✅ Build is **GREEN** (verified 2026-06-04 by Chat B with the canonical command).
- ✅ Phase 0 (restored subsystems functional + transcribe perf) — committed.
- ✅ Phase 1 (Chat/Markets tab restructure: `RootView` + `TabSwitcherBar` + Markets shell) — building.
- 🔧 `AgentInput.onStream` is non-optional `@Sendable (String) -> Void` (no-op for non-final). Don't reintroduce the optional form (it ICEs the compiler).
- ✨ Chat B Swift-6 sweep: made these `nonisolated` so actor-isolated callers (ChatSession, AgentRegistry's concurrent task group) can read them without main-actor hops:
  - `LocalLLM.isAvailable / isActive / statusNote`
  - `ToolPolicy.activeTools() / instructionsToolMenu() / current / isExternalAllowed` (new helper to avoid `==` on a main-actor Equatable conformance from a nonisolated context)
  - `AppSettings.Keys.*` (immutable string constants)
  - `AgentRegistry.*` and `AgentDefinitions.pipeline` (Chat A's territory — touched to clear warnings, behaviour unchanged)
  - `AgentPipeline.buildPrompt(...)` (same — pure string work)
  - `MacControl.accessibilityGranted / click / move / type / keyPress` (CGEvent is thread-safe)
  - `ChatStore.fileURL / load / save` (file IO only)
- ✨ Chat B polish pass:
  - `LocalLLM.generate / generateStreaming / chat` now transparently fall back to Ollama qwen-coder when Apple Intelligence is off (no more "Apple Intelligence is turned off" canned reply on every send).
  - New `BrainStatus` (`LLM/BrainStatus.swift`) polls the live brain every 10s and reacts to the AI toggle; the header subtitle reads from it.
  - DesignSystem additions: `DS.Motion.smooth/cinematic/magnetic` cubic-bezier curves, `DS.Bezel` tokens + `Bezel` container, `Eyebrow`, `SuggestionCard`.
  - Empty-state Bento, `ConfirmationChip` (replaces the saturated Auto-run pill), `MessageBubble` fade-up-blur entry.
  - `SpeechOut.Delegate` no longer holds a `weak var owner` — uses the `shared` singleton directly, clearing the Sendable warning.
- 🪂 `Views/MarketsStub.swift` placeholder I created earlier was slimmed by Chat A (kept the `MarketStore` stub, dropped the placeholder `MarketsView` since the real one now lives in `Views/MarketsView.swift`). No further action needed — Chat A owns this file.
- ✨ Chat B finished the QoL/cleanup queue:
  - `BrainStatus.hasVision` — now polls `qwen2.5vl` reachability in parallel with the brain probe (`async let`). Settings still has its own one-shot Status panel; header dot/label still drives off `brain` for the *answering* brain only.
  - **Brain picker** in Settings (new `BrainPreference: auto | apple | ollama`, persisted under `Keys.brainPreference`). `LocalLLM.currentBrain()` honors it; `generate / generateStreaming / chat` use `appleAllowed` / `ollamaAllowed` gates so pinned modes skip the other brain entirely instead of silently falling back. `BrainStatus` re-polls on `brainPreference` change too.
  - Removed dead `DesignSystem.Chip` (replaced by `SuggestionCard`); `TypingIndicator` now uses a custom `timingCurve(0.42, 0, 0.58, 1.0)` instead of stock `easeInOut`.
  - `ContentView` `onChange(of:perform:)` deprecations migrated to the two-param closure form (build is now warning-free).
- ✨ **2026-06-04 Chat B — RAM overhaul (Phase 1 Core Intelligence)**:
  - **Default model is now `qwen2.5-coder:7b`** (`OllamaClient.codeModel`). Q4_K_M ≈ 4.7 GB resident, down from the 32B variant's ~19 GB. The 32B model is preserved as `OllamaClient.heavyCodeModel` for explicit opt-in; nothing in-tree defaults to it.
  - **New `LLM/MemoryManager.swift`** — actor singleton subscribed to `DispatchSource.makeMemoryPressureSource` + `ProcessInfo.thermalStateDidChangeNotification`. Pure-static policy functions `concurrencyLimit(pressure:thermal:physicalGB:)` and `shouldRefuseHeavyModel(...)` are unit-tested in isolation. Auto-evicts Ollama when pressure crosses `.warning`.
  - **`OllamaClient.Generation`** struct with `keepAlive` / `numCtx` / `numGPU`. Defaults: `keepAlive: 30s`, `numCtx: 2048`. Presets `.tight` (1024 ctx, 10 s keepAlive) and `.full` (8192 ctx). Plus `unloadAll()` / `unload(model:)` that hit `keep_alive: 0` for immediate eviction.
  - **`AgentPipeline.run` cross-lane touch (Chat A's file)**: each phase now reads `await MemoryManager.shared.concurrencyLimit()` and runs agents in size-`cap` batches instead of one wide TaskGroup. Re-read per phase so a long pipeline tracks current reality. **Diff is localized to the inner `for (_, indices) in phases` block** — please review and merge into your mental model; no other behaviour changed.
  - **23 new tests** in `Salehman AITests/MemoryManagerTests.swift` covering the pressure/thermal/RAM matrix + the 7B-default guards. Full unit suite green (`xcodebuild test … -only-testing:"Salehman AITests"` → `TEST SUCCEEDED`).
  - **What I deliberately did NOT do (and why)**:
    - Did *not* fabricate RAM benchmark numbers — I haven't run Instruments on this machine. Provide the harness via `MemoryManager.snapshot()` in-app; expected steady-state RAM drop is **~14 GB** based on public Q4_K_M model-card sizes (19 GB 32B → 4.7 GB 7B), but that needs your measurement to confirm.
    - Did *not* implement automatic mid-conversation model switching. Switching brains mid-stream breaks `ChatSession` memory + tool state. Instead the policy *refuses* the heavy model under pressure and the user/AgentPipeline must choose explicitly.
    - Did *not* add a separate auto-download flow. Ollama's `/api/generate` auto-pulls missing models on first call.
- ✨ **2026-06-04 Chat B — xAI Grok cloud brain (Phase 1 Core Intelligence)**:
  - **New `LLM/KeychainStore.swift`** — `SecItem*`-based macOS Keychain wrapper. Single `Account` enum case `.grokAPIKey`. `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly` (no iCloud sync). `Update`-then-`Add` upsert pattern. Idempotent delete.
  - **New `LLM/GrokClient.swift`** — OpenAI-compatible HTTP client against `https://api.x.ai/v1/chat/completions`. `chat(prompt:system:model:)`, `chatStream(...)` (SSE), `testConnection()`. Reads key from Keychain at call time; **the literal key never appears in source, UserDefaults, or `@State`** after the user saves it.
  - **`BrainPreference.grok`** added (alongside Chat A's `.claudeHaiku`). `LocalLLM.currentBrain()` returns `.grok` only when explicitly pinned; `.auto` stays strictly local-first.
  - **`AppSettings.grokModel`** added (`grok-4` or `grok-4-heavy`). Persisted in UserDefaults under `Keys.grokModel`. `grokModelCurrent` validates against `GrokClient.allModels` and falls back to `defaultModel` on any unknown value.
  - **`BrainStatus.hasGrokKey`** published — refreshed alongside the other probes; flips immediately when the user hits Save in Settings.
  - **`Views/SettingsView` "xAI Grok (Cloud)" section**: `SecureField` + Save (writes Keychain, wipes draft), Clear, model picker, Test connection button, privacy banner.
  - **10 new tests** in `Salehman AITests/GrokTests.swift`: model-ID pinning, Keychain account-string contract, BrainPreference visibility, grokModelCurrent fallback. Full suite green (`** TEST SUCCEEDED **`).
  - **Heads-up for Chat A — security divergence**: I stored the Grok key in **macOS Keychain**, while your `anthropicAPIKey` is in **UserDefaults** (cleartext plist on disk). Worth deciding whether to migrate Claude's key to `KeychainStore` for parity — the infrastructure is now in place. No-op from my side; flagging for your call.
- ✨ **2026-06-04 Chat B — four free cloud brains added (Phase 1)**:
  - **New `LLM/OpenAICompatibleClient.swift`** — generic client for the OpenAI `/v1/chat/completions` wire format. Parameterized by `displayName`, `baseURL`, `defaultModel`, `allModels`, `keychainAccount`, `consoleURL`. Adding the next OAI-compatible provider (Together, Fireworks, DeepInfra…) is now a ~30-line config in `CloudBrains.swift`, not a new file.
  - **New `LLM/CloudBrains.swift`** — three thin configs: `GroqClient.shared`, `MistralClient.shared`, `CerebrasClient.shared`. Each defines `defaultModel` + `allModels` + a `static let shared = OpenAICompatibleClient(…)`.
  - **New `LLM/GeminiClient.swift`** — Google's API isn't OpenAI-compatible (contents-array request shape, key as URL `?key=` param, distinct streaming SSE chunks). Its own client, same shape as `GrokClient` / `AnthropicClient`.
  - **`KeychainStore.Account`** gained four cases: `.geminiAPIKey, .groqAPIKey, .mistralAPIKey, .cerebrasAPIKey`. Each provider's key lives in its own Keychain slot (same `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly` posture as Grok).
  - **`AppSettings`**: four new published `*Model` props (geminiModel, groqModel, mistralModel, cerebrasModel), `Keys.*Model` entries, nonisolated `*ModelCurrent` accessors with validate-or-default fallback, init loads each.
  - **`BrainPreference`** gained `.gemini`, `.groq`, `.mistral`, `.cerebras`. Titles, subtitles, icons defined.
  - **`LocalLLM` refactor**: collapsed every `*Allowed` switch to one-line `pref == .X` checks (auto-cases stay multi-`||`). Eliminated the exhaustive-switch maintenance trap when adding the 10th brain. `Brain` enum gained four cases; `currentBrain()` / `currentBrainLabel()` updated; `generate / generateStreaming / chat` route through each cloud brain when pinned. New shared `LocalLLM.cloudSystemPrompt` constant prevents drift between providers' system-prompts in `chat()`.
  - **`BrainStatus.dotColor`**: four new branded colors (Google blue, Groq orange, Mistral amber, Cerebras magenta).
  - **`SettingsView`**: 4 new sections. The three OpenAI-compatible providers share a generic `cloudKeyRow / cloudModelRow / cloudTestRow` triplet that takes any `OpenAICompatibleClient` — adding a 4th OAI-compatible provider's Settings UI is ~10 lines of call site. Gemini has its own row triplet because of its distinct API. SecureField paste → Save (writes Keychain, wipes draft) → Clear → model picker → Test connection. Same security pattern as Grok.
  - **Build green; 21 new tests in `Salehman AITests/FreeCloudBrainsTests.swift`** pin every provider's `defaultModel` against its console catalog, assert unique Keychain account strings, verify `BrainPreference` visibility, and check the validate-or-default fallback path.
  - **Build-fix touch on `AppSettings.swift:216`**: Chat A's `OpenAIClient.defaultModel` reference was already replaced with the literal `"gpt-4o-mini"` in the version I built against — no action needed on my side. If you reintroduce the `OpenAIClient` symbol, the literal will become stale.
  - **Privacy posture preserved**: `.auto` still never picks a cloud brain — even with 6 cloud options now available, the user must explicitly pin one to leave the Mac. The privacy-banner subtitle on every cloud `BrainPreference` says so.
- ✨ **2026-06-04 Chat B — review + cleanup pass**:
  - **`KeychainStore.read/write/delete/has` + `service`** marked `nonisolated`. Was main-actor-isolated by default (the project uses `-default-isolation=MainActor`), which made it uncallable from `CopilotClient` and `OpenAIClient` and produced Swift-6 warnings. Keychain APIs are thread-safe; the annotation matches reality.
  - **`GrokClient` + `GeminiClient` private helpers** (`makeBody`, `extractContent`, `decodeDelta`, `extractStreamingDelta`) marked `nonisolated`. Required because the public `nonisolated static` methods that wrap them now (correctly) can't call MainActor-isolated helpers.
  - **`BrainStatus.dotColor`** + **`SettingsView.brainRow`** switches extended for Chat A's new `.codex` and `.copilot` cases — both switches were non-exhaustive and would have shipped broken without the additions.
  - **`Views/SettingsView.copilotRow`** placeholder added (Chat A is mid-flight on the GitHub OAuth device-flow). Stub renders a sign-in/sign-out row reading `copilotAuthed` state with the sign-out button disabled. Real OAuth UI replaces this when ready.
  - **`ChatSession.respond` defensive guards** kept (lines 460/462) — they're functionally unreachable through `LocalLLM.chat`'s routing, but `ChatSession.shared` is publicly addressable. Annotated with a comment explaining their defensive role so the next reader doesn't delete them.
  - **`LocalLLM.synthesize`** still has zero callers in-tree. Earlier session restored it explicitly per your ask — leaving it alone unless you say otherwise.
  - **Anthropic key** still stored in `UserDefaults` (Chat A's pattern), while Grok / Gemini / Groq / Mistral / Cerebras / OpenAI keys live in Keychain. Worth migrating for parity, but it's a Chat A decision — flagging here, not changing unilaterally.
  - Full unit suite green (`xcodebuild test … -only-testing:"Salehman AITests"` → `TEST SUCCEEDED`). Build green with **zero warnings on my files**. Remaining warnings (if any) are in Chat A's `LiveTranscriber` / Markets territory.
- ⏭️ Next (Chat B): nothing queued — ready for next ask. Adding additional OpenAI-compatible providers (Together, Fireworks, DeepInfra, Anyscale, OpenRouter) is now a ~10-line addition to `CloudBrains.swift` + 1 BrainPreference case + 1 `*Allowed` line + 1 `*ModelCurrent` accessor. Each future provider is a ~50-LOC PR.
- ⏭️ Next (Chat A): Phase 2 — Markets data layer. **Heads-up**: AgentPipeline's per-phase TaskGroup is now wrapped in a batch loop; if you re-touch that file, preserve the `let cap = await MemoryManager.shared.concurrencyLimit()` read and the `stride(...) → batches` chunking. Also: your `OpenAIClient` "Codex" cloud brain is half-wired in `AppSettings` (props + Keys exist, init uses a literal model id) but I haven't seen the `OpenAIClient.swift` file yet — when you finish it, the routing pattern is mirrored exactly by my `GrokClient` ⇒ feel free to copy.

## Notes / handoffs
- **2026-06-04 Chat B**: edited a few files outside my lane to clear Swift-6 warnings (Agents/AgentRegistry, Agents/AgentDefinitions, Agents/AgentPipeline.buildPrompt, Tools/MacControlTools). Changes are isolation-only (`nonisolated` annotations) — no behaviour change. Flagging here so Chat A isn't surprised next read.
- **2026-06-04 Chat B**: `AgentPipeline.run` now reads `MemoryManager.shared.concurrencyLimit()` per phase and runs agents in batches (see Phase 1 RAM overhaul above). I tried to keep the diff inside the `for (_, indices) in phases` block — if you object, ping back and we'll redesign.
- **2026-06-04 Chat A (URGENT — the 32B Ollama fallback froze the user's Mac)**: two RAM fixes, build green.
  1. `Agents/AgentPipeline.swift` (my lane): when `currentBrain() == .ollamaCoder`, the pipeline now ALWAYS runs a **single agent** (ignores response-mode), because each agent is a full qwen2.5-coder:32b inference and a phase runs them CONCURRENTLY → multiple ~20 GB loads → freeze. Apple Intelligence still honors fast/balanced/full.
  2. `LLM/OllamaClient.swift` (**your lane — heads up, please keep**): added `keep_alive: "30s"` to `/api/generate` (stream + non-stream) so Ollama evicts the model from RAM ~30s after idle (default is 5 min). Pure RAM-lifecycle change.
  - **Recommend (your Brain-picker lane):** prefer a *small* chat model if installed (`qwen2.5-coder:7b` / `llama3.2:3b`, ~4 GB vs ~20 GB) before the 32B. User explicitly asked to minimize RAM.
- **2026-06-04 Chat A — added Claude Haiku 4.5 as a 3rd brain (cloud), build green.** Touched brain-lane files (heads-up):
  1. NEW `LLM/AnthropicClient.swift` (mine) — REST Messages API client (`https://api.anthropic.com/v1/messages`, `x-api-key` + `anthropic-version: 2023-06-01`, model `claude-haiku-4-5`), non-stream `chat()` + SSE `chatStream()`, system prompt-caching. ~0 local RAM.
  2. `App/AppSettings.swift` — added `anthropicAPIKey` (+ `Keys.anthropicAPIKey`, `anthropicAPIKeyCurrent`) and a `BrainPreference.claudeHaiku` case. **All your switches over `BrainPreference` now need the `.claudeHaiku` case** (I updated the ones in LocalLLM + SettingsView; if you add new ones, handle it).
  3. `LLM/LocalLLM.swift` (**your lane**) — `Brain.claudeHaiku` case; `currentBrain()`/`currentBrainLabel()` handle it; new `claudeAllowed` gate (pinned-only — `.auto` stays local-first so we never silently spend on cloud); `generate`/`generateStreaming`/`chat` try Claude first when pinned.
  4. `LLM/BrainStatus.swift` (**your lane**) — added `.claudeHaiku` to the `dotColor` switch (terracotta).
  5. `Views/SettingsView.swift` (**your lane**) — `brainRow` ready-switch handles `.claudeHaiku` (ready == key entered); added an Anthropic API-key `SecureField` row in the Brain section.
  - Note: Haiku honors response-mode (not force-capped like Ollama) since cloud = no RAM risk; but Full = 15 API calls/msg, so Low/Balanced is the cheap default. Key is in UserDefaults (Keychain would be better — flagging for later).
- **2026-06-04 Chat A — staged measured RAM benchmarks (build green, test passes).** Two run-by-user artifacts (the model RAM lives in the `ollama serve` process, NOT the app — Instruments-on-the-app would miss it):
  1. NEW `scripts/ram-benchmark.sh` — raw-Ollama loop; samples `ollama ps` SIZE + `memory_pressure` free% across N turns, confirms 30s keep_alive eviction. Run `MODEL=qwen2.5-coder:7b` and `:32b`; the SIZE delta is the win. (Works even when the app build is red — hits Ollama directly.)
  2. NEW `Salehman AITests/OllamaRAMBenchmarkTests.swift` (Swift Testing) — drives `LocalLLM.chat()` ×10 with brain pinned `.ollama`, samples `ollama ps` SIZE + app `phys_footprint`. **XCTSkips cleanly when Ollama is down** (passes as no-op), so CI never fails. Distinct file — no overlap with your `MemoryManagerTests`.
  - ⏳ MEASURED: __pending__ — replace this once the user pastes script/test output (real 7B-vs-32B SIZE + eviction confirmation).
  - FYI saw your **xAI Grok** 4th brain land (GrokClient + BrainPreference.grok + dotColor/brainRow `.grok` cases) — build went green after your `case .grok` in SettingsView.brainRow. No action needed from me.
- **2026-06-04 Chat A — CLAIMING: adding two more brains, Codex (OpenAI) + Copilot (GitHub device-flow OAuth).** Please pause new brain work in `LLM/LocalLLM.swift`, `LLM/BrainStatus.swift`, `Views/SettingsView.swift`, `App/AppSettings.swift` until I land these (we keep red-building when both of us touch the brain switches). New files mine: `LLM/OpenAICompatible.swift`, `LLM/OpenAIClient.swift`, `LLM/CopilotClient.swift`, `Views/CopilotSignInView.swift`. Shared edits: `.codex`/`.copilot` cases in `BrainPreference`, `LocalLLM.Brain`, and every exhaustive switch (currentBrain/label/allowed-gates, dotColor, brainRow) + routing. Landing Codex first, then Copilot.
- **2026-06-04 Chat A — landed Codex (OpenAI) + Copilot (GitHub) brains, build green.** Reused your `OpenAICompatibleClient` + Keychain framework (no dup — I deleted my parallel `OpenAICompatible.swift`/`OpenAIClient.swift` and rebuilt on yours). Thanks for stubbing `copilotRow` + filling the `.codex`/`.copilot` cases in `dotColor`/`brainRow` — I replaced the stub with the real device-flow.
  - NEW (mine): `LLM/OpenAIClient.swift` (config on your `OpenAICompatibleClient`), `LLM/CopilotClient.swift` (`CopilotAuth` device-flow OAuth + token exchange + `CopilotClient` chat), `Views/CopilotSignInView.swift` (device-code sheet).
  - `KeychainStore.Account`: added `.openAIAPIKey` + `.copilotGitHubToken` (the latter holds the GitHub OAuth token; the short-lived Copilot token is memory-only).
  - `AppSettings`: dropped my early UserDefaults `openAIAPIKey` (key now in Keychain like the others); kept `openAIModel` (validated against `OpenAIClient.allModels`).
  - `SettingsView`: added "Codex / OpenAI" section (your `cloudKeyRow`/`cloudModelRow`/`cloudTestRow`) + "GitHub Copilot" section (sign-in/out + live Working badge) + sign-in sheet.
  - Now 9 brains. Next: a live "is the selected brain actually working" check in Settings + a cleanup pass (user-requested).
