# 🧠 PROJECT_CONTEXT — Salehman AI (complete handoff knowledge base)

> ## 📌 READ ME FIRST — instructions for any AI (Grok, Claude, …) or person
>
> This is the **canonical, complete context** for the *Salehman AI* macOS app.
> If you were handed this file (or `SOURCE_BUNDLE.md`), you now have everything
> you need to understand the whole app. Read this doc top-to-bottom, then dive
> into the source.
>
> **If you change anything in this app**, you MUST append a dated entry to
> [`DEVELOPMENT_LOG.md`](DEVELOPMENT_LOG.md) (format defined there). This is an
> explicit, standing instruction from the owner as of **2026-06-05** — every
> change, from today onward, gets logged. Keep this file current when the
> structure changes, and regenerate the source bundle with
> `bash tools/bundle_source.sh` before any handoff.
>
> Companion docs: [`ARCHITECTURE.md`](ARCHITECTURE.md) (deep data-flow),
> [`COORDINATION.md`](COORDINATION.md) (how two parallel Claude sessions split
> the work), [`DEVELOPMENT_LOG.md`](DEVELOPMENT_LOG.md) (running change journal),
> [`SOURCE_BUNDLE.md`](SOURCE_BUNDLE.md) (all source in one file).

---

## 1. What this app is

**Salehman AI** is a native **macOS SwiftUI** desktop app: a multi-brain AI chat
assistant. It can answer from several "brains" — Apple Intelligence (on-device),
a local **Ollama** model (`qwen2.5-coder:7b`), or cloud providers (Claude, xAI
Grok, Google Gemini, Groq, Mistral, Cerebras, OpenAI/Codex, GitHub Copilot,
OpenRouter). It has a multi-agent pipeline, on-device tools (shell, mouse/keyboard
control, vision, transcription, web), live audio transcription, a StockSage
market-analysis subsystem, and persistent chat + long-term memory.

- **Language / runtime:** Swift 6 **language mode** (`SWIFT_VERSION = 6.0`, enforced as of 2026-06-09 — data races are compile errors, not warnings), `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` on the app target and, mirrored, the test targets. Off-main work is explicitly `nonisolated`/`nonisolated(unsafe)`.
  Pure utility statics are marked `nonisolated`.
- **UI:** SwiftUI, custom dark "DS" design system (no stock chrome).
- **Secrets:** API keys live ONLY in the macOS **Keychain** (never UserDefaults,
  never source).
- **Privacy posture:** `.auto` mode is strictly local-first; cloud brains are
  used only when the user explicitly pins one (or picks Free·Auto / All-Brains).

### Build, run, test
```bash
# Build (canonical command — used everywhere in this repo):
xcodebuild -scheme "Salehman AI" -destination 'platform=macOS' -configuration Debug CODE_SIGNING_ALLOWED=NO build

# Run the unit tests:
xcodebuild test -scheme "Salehman AI" -destination 'platform=macOS' -configuration Debug CODE_SIGNING_ALLOWED=NO -only-testing:"Salehman AITests"

# Launch the built app:
open "/Users/saleh/Library/Developer/Xcode/DerivedData/Salehman_AI-ddepspaxspvcrmggcktxzotioijc/Build/Products/Debug/Salehman AI.app"
```
New `.swift` files anywhere under `Salehman AI/Salehman AI/` auto-compile
(synchronized Xcode group — **no `project.pbxproj` edits needed**).

---

## 2. Repo map — every source file & its job

### `App/` — entry point & global state
| File | Purpose |
|---|---|
| `Salehman_AIApp.swift` | `@main` SwiftUI App; window/scene setup, menu commands. |
| `AppState.swift` | Bridge between menu-bar `.commands` and the view layer. |
| `AppSettings.swift` | **Central persisted settings** (`@Published` + UserDefaults). Holds `BrainPreference`, per-provider model selections, response mode, toggles. `Keys.*` are the UserDefaults keys; `*ModelCurrent` accessors validate-or-fallback. `MachineInfo` (RAM/cores) lives here too. **Shared file — append-only between sessions.** |

### `LLM/` — the brain layer (Chat B's lane)
| File | Purpose |
|---|---|
| `LocalLLM.swift` | **The brain router** (896 lines). `BrainPreference`→`Brain` resolution (`currentBrain`), the `*Allowed` gates, and `generate` / `generateStreaming` / `chat`. Houses `generateEnsemble` (All-Brains parallel) and `generateFreeAuto` (free parallel-race + local backstop). Apple Intelligence (Foundation Models) path lives here. |
| `OllamaClient.swift` | Local Ollama server (`localhost:11434`). Model resolver (7b→14b→32b), `keep_alive`/`num_ctx`, `unloadAll()`. Default coder model `qwen2.5-coder:7b`. |
| `OpenAICompatibleClient.swift` | Generic `/v1/chat/completions` client (+ SSE streaming + error decoding). Groq/Mistral/Cerebras/OpenAI/OpenRouter are thin configs of this. |
| `CloudBrains.swift` | The thin configs: `GroqClient`, `MistralClient`, `CerebrasClient`, `OpenRouterClient` (endpoint + model lists + Keychain account). |
| `GrokClient.swift` | xAI Grok (`api.x.ai`) — OpenAI-ish chat + SSE. |
| `GeminiClient.swift` | Google Gemini (non-OpenAI shape: contents array, `?key=` param). |
| `AnthropicClient.swift` | Claude Haiku via Anthropic Messages API. |
| `OpenAIClient.swift` | The "Codex" brain → OpenAI chat completions. |
| `CopilotClient.swift` | GitHub Copilot (OAuth device-flow, no API key). |
| `KeychainStore.swift` | `SecItem*` Keychain wrapper. `Account` enum = one slot per provider. `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`. |
| `MemoryManager.swift` | Actor: subscribes to memory-pressure + thermal notifications; `concurrencyLimit()` + `shouldRefuseHeavyModel()`; auto-evicts Ollama under pressure. |
| `BrainStatus.swift` | MainActor `ObservableObject`; polls which brain is live every 10s; drives the header dot/label (`dotColor`). |

### `Agents/` — multi-agent pipeline (Chat A's lane)
| File | Purpose |
|---|---|
| `AgentPipeline.swift` | `run(mission:)` — short-circuits to ensemble/freeAuto, else runs a complexity-tiered agent team (1 → 15 agents). Batches by `MemoryManager.concurrencyLimit()`. |
| `AgentDefinitions.swift` | The 15-agent team; roles auto-adapt to the user message. |
| `AgentRegistry.swift` | Per-agent execution input (Sendable) + handler registry. |
| `Orchestrator.swift` | Top-level orchestration; reads run outcome for rating. |
| `MissionMemory.swift` / `MissionPlan.swift` | Outcome memory + lightweight plan structs. |
| `SelfImprove.swift` | Build→parse compiler errors→ask local model for a patch→apply with backup→rebuild. **Project-escape guarded** (`isInsideProject`, symlink-resolving). |

### `Tools/` — what the assistant can DO (security-sensitive)
| File | Purpose |
|---|---|
| `ToolPolicy.swift` | **Gate:** whether external/non-local tools are allowed; the active tool set + instructions menu. |
| `CommandApprovalCenter.swift` | Bridges background tool exec → UI approval; `confirmationEnabled` toggle. |
| `ShellTool.swift` | Runs shell commands on the Mac (gated by approval). |
| `MacControlTools.swift` | Mouse/keyboard control via CGEvent (needs Accessibility permission). |
| `WebTools.swift` | DuckDuckGo search + page fetch. **SSRF-guarded** (`ssrfRejectionReason` blocks non-http(s) + private/loopback/link-local hosts). |
| `VisionAnalyzer.swift` / `AnalyzeImageTool.swift` | On-device image understanding (Apple Vision). |
| `TranscribeMediaTool.swift` | On-device audio/video → text. |
| `CodeTool.swift` | Delegate coding to a local qwen2.5-coder model. |
| `ImageGen.swift` | On-device image generation (Image Playground). |
| `StockAnalysisTool.swift` / `StockSageMini.swift` / `StockSageTool.swift` | Saudi/TASI stock analysis tools. |

### `Views/` — UI (ContentView + SettingsView = Chat B's lane)
| File | Purpose |
|---|---|
| `ContentView.swift` | The chat UI (1108 lines): message list, composer, streaming bubbles, `ChatStore` (persistence), approval card. |
| `SettingsView.swift` | Settings panel (1170 lines): Apple-Intelligence toggle, **compact Brain grid**, **collapsible Free / Paid API-key groups**, per-provider key/model/test rows, performance/voice/privacy/status sections. |
| `RootView.swift` / `TabSwitcherBar.swift` / `BackgroundView.swift` | Tab container (**6 tabs**, Today-first, lazy-kept via `.opacity`; `BottomShortcutBar` pinned at the bottom), frosted segmented bar (sliding `matchedGeometryEffect` pill + **responsive labels**: collapse to icon-only when narrow, threshold scales with tab count), shared gradient background. |
| `TodayView.swift` | **Today tab (⌘1, default landing)** — home dashboard: greeting + Quick Actions + live stat cards (notes/tasks, knowledge docs, market) reading the real stores. Read-only navigation surface. |
| `AgentsView.swift` | **Agents tab (⌘3)**: live agent status + Autonomous Mode loop. |
| `MarketsView.swift` / `MarketsStub.swift` | **Markets tab (⌘4)** shell + placeholder store (Chat A). |
| `ScratchpadView.swift` | **Notes tab (⌘5)** — notes + tasks UI over `ScratchpadStore`; same data the `capture_note`/`add_task`/… tools write. |
| `KnowledgeView.swift` | **Knowledge tab (⌘6)** — private document Q&A: add files (button/drag-drop) or paste text, grounded answers w/ sources over `KnowledgeStore`; on-device-only generation; chat reaches it via `search_documents`. |
| `BottomShortcutBar.swift` | Always-visible footer of clickable shortcut hints (⌘K · ⌘N · ⌘J · ⌘/ · ⌘,); flips the same `AppState` flags as the menu bar. |
| `VoiceModeView.swift` | **Hands-free Voice (⌘J)** — full-screen dictate→answer→speak loop (`Voice/VoiceSession`); "Save to Notes" writes the transcript to `ScratchpadStore`. |
| `OnboardingView.swift` / `CommandPalette.swift` (⌘K) / `ShortcutsView.swift` (⌘/) | First-run welcome; searchable command palette; keyboard-shortcuts cheat sheet. |
| `MemoryView.swift` | "What I know about you" — durable facts list. |
| `MarkdownText.swift` | Lightweight markdown renderer (fenced code blocks, etc.). |
| `LiveTranscriptionView.swift` / `CopilotSignInView.swift` | Live-transcription UI; Copilot device-flow sheet. |

### `Persistence/`, `Media/`, `StockSage/`, `Knowledge/`, `Voice/`, `DesignSystem/`
- **Persistence:** `Attachments.swift` (attached items + screen capture), `MemoryStore.swift` (long-term user facts), `PromptLibrary.swift` (reusable prompts), `ScratchpadStore.swift` (notes + tasks; `@MainActor ObservableObject`, JSON in App Support).
- **Knowledge:** `KnowledgeStore.swift` (`@unchecked Sendable` doc vault — chunk + keyword-primary/`NLEmbedding`-boosted search, JSON-persisted) + `SearchDocumentsTool.swift` (the `search_documents` FM tool).
- **Voice:** `VoiceSession.swift` / `VoiceTurn.swift` — hands-free dictate→LocalLLM→TTS loop driving `VoiceModeView`.
- **Media:** `LiveTranscriber.swift` (system-audio live transcription), `MediaTranscribe.swift`/`Transcriber.swift` (file transcription), `SpeechIn.swift` (mic dictation), `SpeechOut.swift` (TTS).
- **StockSage:** `StockSageModels/Store/SignalEngine/BriefingService/ScreenAnalysis/Monitor/BriefingTool` — namespaced market subsystem (in-memory store, pure signal engine, real LocalLLM briefings + real vision; theater dropped).
- **DesignSystem:** `DesignSystem.swift` — `DS.*` tokens, motion curves (`DS.Motion.snappy/smooth/…`), `Bezel`/`Eyebrow`/`SuggestionCard`.

---

## 3. The brain system (the heart of the app)

Two enums drive everything:
- **`BrainPreference`** (`AppSettings.swift`) — what the USER pinned: `.auto`,
  `.freeAuto`, `.apple`, `.ollama`, `.claudeHaiku`, `.grok`, `.gemini`, `.groq`,
  `.mistral`, `.cerebras`, `.codex`, `.copilot`, `.openRouter`, `.ensemble`.
  Persisted under `Keys.brainPreference`.
- **`LocalLLM.Brain`** — which brain actually ANSWERS (resolved from the pref +
  live availability), used for the header label/dot.

**Routing** lives in `LocalLLM`:
- `currentBrain()` resolves pref → Brain (returns `.none` if the pinned brain is
  unreachable, so the UI shows an honest "unavailable" message).
- `generate` / `generateStreaming` / `chat` each branch at the top:
  `if isFreeAutoMode { generateFreeAuto } ; if isEnsembleMode { generateEnsemble }`,
  then the single-brain `*Allowed` gates (`claudeAllowed`, `grokAllowed`, …).
- ⚠️ **`generate` is NOT on-device** — it routes to the pinned (possibly paid cloud)
  brain. Features that PROMISE privacy must use **`generateOnDevice(_:maxTokens:) -> String?`**
  (local tier only: Apple Intelligence → Ollama; `nil` if neither). The Knowledge
  vault uses it (added 2026-06-05 after an audit caught the leak — see DEVELOPMENT_LOG).
- `AgentPipeline.run` short-circuits ensemble/freeAuto BEFORE spawning the agent
  team (those modes ask the raw prompt, not a 15-agent pipeline).

**Special modes:**
- **All Brains at Once (`.ensemble`)** — `generateEnsemble`: runs every reachable
  brain in parallel, returns one combined `### <brain>` labeled doc. On a <24 GB
  Mac it SKIPS the local Ollama model (RAM-safety) and notes the skip.
- **Free · Auto (`.freeAuto`)** — `generateFreeAuto`: races the *configured free*
  cloud brains (Groq/Cerebras/Gemini/Mistral/OpenRouter) in parallel, returns the
  **first usable** answer (a 429/error/empty reply loses the race via
  `isUsableFreeAnswer`); if all free cloud brains fail it falls back to LOCAL
  (Apple → Ollama) **sequentially** (never concurrent — preserves the RAM
  guardrail). Effectively never blocked. Never uses paid brains.

---

## 4. Cloud providers

| Brain | Client | Endpoint | Keychain account | Notes / default model |
|---|---|---|---|---|
| Claude Haiku | `AnthropicClient` | Anthropic Messages API | `anthropic-api-key` | paid |
| xAI Grok | `GrokClient` | `api.x.ai/v1` | `grok-api-key` | paid; models incl. `grok-build-0.1` (probe) |
| Google Gemini | `GeminiClient` | generativelanguage API | `gemini-api-key` | **free tier**; key looks like `AIza…` |
| Groq | `GroqClient` | `api.groq.com/openai/v1` | `groq-api-key` | **free**; default `llama-3.3-70b-versatile` |
| Mistral | `MistralClient` | `api.mistral.ai/v1` | `mistral-api-key` | free tier; `mistral-small-latest` |
| Cerebras | `CerebrasClient` | `api.cerebras.ai/v1` | `cerebras-api-key` | **free**; default `gpt-oss-120b` (only `gpt-oss-120b`/`zai-glm-4.7` served) |
| OpenAI / Codex | `OpenAIClient` | `api.openai.com/v1` | `openai-api-key` | **paid** (needs billing); `gpt-4o-mini` |
| GitHub Copilot | `CopilotClient` | Copilot API | `copilot-github-token` | OAuth device-flow (subscription) |
| OpenRouter | `OpenRouterClient` | `openrouter.ai/api/v1` | `openrouter-api-key` | **free `:free` models**; default `openai/gpt-oss-120b:free` |

⚠️ **Cloud model IDs rotate.** Defaults are best-effort; verify against each
provider's `GET /v1/models`. The app's `*ModelCurrent` accessors fall back to the
provider default if a stored model is no longer offered.

---

## 5. Tools & security model

The assistant can run shell commands, control the mouse/keyboard, fetch the web,
read/transcribe local files, and self-edit. This is intended (a user-authorized
local assistant), but gated:
- **`ToolPolicy`** decides whether non-local tools are active.
- **Tool loop** (`LocalLLM.chatOllamaWithTools` / `chatOpenAICompatWithTools`) — the
  set of tools any brain (local Ollama or OpenAI-compatible cloud) can actually call.
  Built by `ollamaToolSpecs(externalAllowed:)`; executed by the shared
  `runLocalTool(_:_:)` (on-device) + per-loop switch (terminal/web). **Always
  available** (on-device, no network): `run_terminal_command` (approval-gated),
  `search_documents`, `capture_note`, `add_task`, `remember_fact`. **Only when
  external access is on:** `web_search`, `fetch_url`. The spec list *is* the security
  gate — a model can't call a tool it was never handed (pinned by `OllamaToolGateTests`).
- **`CommandApprovalCenter`** gates shell exec behind a UI approval (toggle:
  `confirmationEnabled`).
- **`WebTools.fetch`** has an SSRF denylist (no `file://`/non-web schemes; no
  `localhost`/`127.*`/`10.*`/`192.168.*`/`172.16-31.*`/`169.254.*`/`::1`).
- **`SelfImprove.isInsideProject`** resolves symlinks before allowing a write, so
  a planted symlink can't escape the project root.

See **§7 Known issues** for the items still open.

---

## 6. Tests
Swift Testing (`import Testing`, `@Test`, `#expect`), under `Salehman AITests/`.
Notable suites: `FreeAutoTests` (race filter + mode), `EnsembleTests`,
`FreeCloudBrainsTests` (provider model-ID contracts), `CloudClientParsingTests`,
`CloudErrorDecoderTests`, `CloudSystemPromptTests`, `GeminiURLEncodingTests`,
`MemoryManagerTests`, `GrokTests`, `OpenRouterTests`, `StockSageTests`,
`TrivialMissionTests` (complexity tiers), `SecurityHardeningTests` (SSRF + symlink
guards), `OllamaPriorityResolverTests`, `OllamaRAMBenchmarkTests`,
`LocalLLMOffMessageTests`. 

**Grok Tab A (2026-06-06) added 8 new suites per CODEBASE_REVIEW.md §4 (start of coverage for highest-blast-radius logic):**
- Direct (enabled, green): `KnowledgeRAGTests` (chunk/keyword/cosine/search), `ShellSecurityTests` (isBlocked + run harness + looksRisky limits), `WebToolsOfflineGateTests` (FM tool gates + decodeDDG/stripHTML), `SelfImprovePatchTests` (applyPatch/parseErrors/isInside/backup — locks the double-patch-original fix).
- `LiveTranscriberSegmentTests` (enabled; public surface + notes on internal recycle fix already in source).
- Refactor-dependent (disabled with header, per COORDINATION): `BrainRoutingDispatchTests`, `PersistenceRoundTripTests`, `SettingsBrainReadyTests` — wait for Tab B (BrainAdapter registry + JSONFileStore + brainReady extract).

Tests run **in parallel** — never have two tests mutate the same global (`UserDefaults.standard`) key, or they race (see the `brainPreference` lesson in the log). Use `@Suite(.serialized)` + explicit restore/clear for any shared FS/UD/singleton stores.

---

## 7. Known issues (from the 2026-06-05 multi-agent review)

**Fixed & shipped:** WebTools SSRF guard; SelfImprove symlink escape; ensemble
"Not working" false-negative; stale Groq/Cerebras/OpenRouter model IDs.

**Open / flagged for the other session (Agents lane):**
- `AnalyzeImageTool` / `TranscribeMediaTool` follow symlinks (arbitrary file read).
- `AgentPipeline.lastOutcome` is `nonisolated(unsafe)` → data race with `Orchestrator`.
- `AgentRegistry` first-run registration race (`nonisolated(unsafe)` + unguarded once-init).

**Recommendations (not yet applied):**
- `CommandApprovalCenter.alwaysAllow()` disables the shell gate in one click with
  no friction/expiry — add a confirm or time-box.
- Perf: debounce `AppSettings` UserDefaults writes; use `Set` for model-list
  lookups; make `SettingsView`/`BrainStatus` polling demand-driven; extract
  sub-views from the 1100+-line views.
- Refactor: a data-driven brain registry would kill the ~8-exhaustive-switch
  tax every new brain adds.

---

## 8. Coordination & glossary

- **Two parallel Claude Code sessions** work this repo; lanes are defined in
  [`COORDINATION.md`](COORDINATION.md). **Chat B** = brain/LLM layer + chat UI +
  design system. **Chat A** = Markets, agent pipeline/backbone, some cloud
  clients, live transcription. Don't edit the other lane's files without claiming
  it in COORDINATION.md first.
- **Glossary:** *brain* = an answering backend; *ensemble* = all brains in
  parallel, show all; *freeAuto* = free brains raced, first good answer wins, local
  backstop; *gate* = a `*Allowed` boolean controlling whether a brain is used;
  *off-message* = the sentinel returned when no brain is reachable.

---

_Keep this file current. Last refreshed: 2026-06-05._
