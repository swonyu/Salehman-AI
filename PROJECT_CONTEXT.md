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
assistant. It can answer from several "brains" — the **Salehman** chain (default:
cloud-first NVIDIA-hosted DeepSeek → free frontier tiers, with a
local MLX/Ollama floor), a local **Ollama** model (`qwen2.5-coder:7b`), local
OpenAI-compatible servers (**Unsloth Studio**, **vLLM**), or cloud providers
(Claude, xAI Grok, Google Gemini, Groq, Mistral, Cerebras, NVIDIA NIM,
OpenAI/Codex, GitHub Copilot, OpenRouter). (Apple Intelligence was removed
2026-06-08.) It has a multi-agent pipeline, on-device tools (shell, vision,
transcription, web), live audio transcription, a StockSage market-analysis
subsystem, and persistent chat + long-term memory.

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
| `LocalLLM.swift` | **The brain router** (~1500 lines). `generate` / `generateStreaming` / `chat` each `switch` on `BrainRouting.dispatch` (per-provider EXECUTION lives here in `cloudOneShot`/`cloudStream`/`cloudConversational`); `currentBrain` = `BrainRouting.reachableBrain` over a `BrainRouteConfig.live()` snapshot. Houses `generateEnsemble` (All-Brains parallel), `generateFreeAuto` (free parallel-race + local backstop), and the **tool loop** (`ollamaToolSpecs`, `runLocalTool`, `chatOllamaWithTools` / `chatOpenAICompatWithTools`). |
| `BrainRouting.swift` | **The routing PLAN (R1 seam, 2026-06-12)** — pure + hermetically tested (`BrainRoutingDispatchTests`): `CloudProvider` (the ten providers + free/coding/ensemble roster constants + key checks + model/client maps), `BrainRouteConfig` (snapshot; `.live()` probes lazily per-pref), `BrainRouting` (`dispatch` — exactly one target per pref, **Offline Mode hard-gates the ten cloud pins**; roster builders — offline empties every cloud roster; `reachableBrain`/`anyBrainReachable`). Change a routing rule HERE, nowhere else. |
| `OllamaClient.swift` | Local Ollama server (`localhost:11434`). Model resolver (7b→14b→32b), `keep_alive`/`num_ctx`, `unloadAll()`. Default coder model `qwen2.5-coder:7b`. |
| `OpenAICompatibleClient.swift` | Generic `/v1/chat/completions` client (+ SSE streaming + error decoding). Groq/Mistral/Cerebras/NVIDIA/OpenAI/OpenRouter are thin configs of this. |
| `CloudBrains.swift` | The thin configs: `GroqClient`, `MistralClient`, `CerebrasClient`, `OpenRouterClient`, `NvidiaClient` (endpoint + model lists + Keychain account). (DeepSeek's direct client removed 2026-06-12 — owner: "remove deepseek".) |
| `SalehmanEngine.swift` / `SalehmanLeader.swift` / `SalehmanPersona.swift` | The **`.salehman` default brain**: cloud-first provider chain + persona/system-prompt; `SalehmanLeader` finalizes pipeline output in the Salehman voice. |
| `MLXSalehmanEngine.swift` | Local MLX (Apple-Silicon) inference path for the fine-tuned Salehman weights. |
| `UnslothStudio.swift` / `VLLM.swift` | Local OpenAI-compatible servers (Unsloth Studio `:8888`/`:8000`; `vllm serve` `:8000/v1`) as pinnable brains. |
| `BrainAdapter.swift` / `OllamaBrainAdapter.swift` / `AnthropicBrainAdapter.swift` | `BrainAdapter` protocol + adapters — start of the data-driven brain registry (CODEBASE_REVIEW §3 R1). |
| `GrokClient.swift` | xAI Grok (`api.x.ai`) — OpenAI-ish chat + SSE. |
| `GeminiClient.swift` | Google Gemini (non-OpenAI shape: contents array, `?key=` param). |
| `AnthropicClient.swift` | Claude Haiku via Anthropic Messages API. |
| `OpenAIClient.swift` | The "Codex" brain → OpenAI chat completions. |
| `CopilotClient.swift` | GitHub Copilot (OAuth device-flow, no API key). |
| `KeychainStore.swift` | `SecItem*` Keychain wrapper. `Account` enum = one slot per provider. `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`. |
| `MemoryManager.swift` | Actor: subscribes to memory-pressure + thermal notifications; instance `concurrencyLimit()` + pure static policy funcs (`concurrencyLimit(pressure:thermal:physicalGB:)`, `shouldRefuseHeavyModel(...)`); auto-evicts Ollama under pressure. |
| `BrainStatus.swift` | MainActor `ObservableObject`; polls which brain is live every 10s; drives the header dot/label (`dotColor`/`symbol`). |

### `Agents/` — multi-agent pipeline (Chat A's lane)
| File | Purpose |
|---|---|
| `AgentPipeline.swift` | `run(mission:)` — short-circuits to ensemble/freeAuto, else runs a complexity-tiered agent team (1 → 15 agents). Batches by `MemoryManager.concurrencyLimit()`. |
| `AgentDefinitions.swift` | The 15-agent team; roles auto-adapt to the user message. |
| `AgentRegistry.swift` | Per-agent execution input (Sendable) + handler registry. |
| `Orchestrator.swift` | Top-level orchestration; reads run outcome for rating. |
| `MissionMemory.swift` / `MissionPlan.swift` | Outcome memory + lightweight plan structs. |
| `SelfImprove.swift` | Self-patching **primitives**: compiler-error parsing (`parseErrors`), patch application with timestamped backups (`applyPatch`/`backup`), **project-escape guarded** (`isInsideProject`, symlink-resolving). The build→fix→rebuild loop that drove them went with the FM tool layer (2026-06-08); primitives are test-covered and kept. |

### `Tools/` — what the assistant can DO (security-sensitive)
| File | Purpose |
|---|---|
| `ToolPolicy.swift` | **Gate:** whether external/non-local tools are allowed (`isExternalAllowed`, `webToolsDisabledReason`) + the `CommandRisk` blocked/risky command vocabulary. |
| `CommandApprovalCenter.swift` | Bridges background tool exec → UI approval; `confirmationEnabled` toggle. |
| `ShellTool.swift` | Runs shell commands on the Mac (gated by approval). |
| `WebTools.swift` | DuckDuckGo search + page fetch. **SSRF-guarded** (`ssrfRejectionReason` blocks non-http(s) + private/loopback/link-local hosts). |
| `MediaSearch.swift` | `image_search` / `video_search` tools — DuckDuckGo `i.js`/`v.js` (SafeSearch **off**, `p=-1`). `MediaItem` (Codable image/video result) + `MediaCapture` (@MainActor per-turn side-channel: the tool loop returns text to the model, the actual media flows here → `ChatMessage.media` → inline gallery). `authenticityBiased` appends a region's native-language term for relevance. Network tools — hidden offline like the web tools. |
| `VisionAnalyzer.swift` | On-device image understanding (Apple Vision: scene/text/barcodes). |
| `RepoPacker.swift` | `pack_repository` tool — Repomix-style whole-codebase digest. |
| `GrokWatchTool.swift` | `read_grok_session` tool — snapshot of the latest Grok terminal-bridge session log. |
| `StockSageMini.swift` | Canonical Saudi/TASI educational disclaimer (rendered by MarketsView). |
| `QASnapshots.swift` | Self-snapshot QA harness: renders every main surface to `qa/snapshots/*.png` via `ImageRenderer` (no Screen Recording permission needed). Triggers: `qa/SNAPSHOT_REQUEST` file at launch, or View ▸ "Capture QA Snapshots". Lets a screen-blind AI session see the UI; paired with `Salehman AIUITests/ChatTabUITests.swift` (composer/search/menu flow tests + a test that captures snapshots during gate runs). |

*(The actual model-callable tools are defined inline in `LocalLLM`'s tool loop — see §5. The FM-era per-tool files — AnalyzeImageTool, TranscribeMediaTool, CodeTool, StockAnalysisTool, ImageGen, MacControlTools — were removed with the Apple-Intelligence layer / 2026-06-11 cleanup.)*

### `Views/` — UI (ContentView + SettingsView = Chat B's lane)
| File | Purpose |
|---|---|
| `ContentView.swift` | The chat UI: document-flow message list (hover action pills — copy/speak/regenerate/**quote**/per-reply timing on assistant rows, **edit-and-resend**+copy on user rows), Claude-style composer with **Code-tab parity colors** (signature accent ring), **slash commands** (`/summarize /continue /clear /copy /export /find /voice` + every saved prompt as `/slugged-title`), **Brain/Effort quick-controls menu** (live `· salehman14b` serving badge), **multi-file attachments** (chips per file, multi-select/drop/paste; merged to one synthetic attachment at submit so the pipeline stays single-attachment), **draft persistence** across relaunches, ↑-recall, Esc stops/dismisses, welcome that mirrors `CodeView.welcome` 1:1 (flat disc hero, 3 capsule pills, status line, full-tab optical centering). Presentation/input/focus/search only — conversation + send pipeline live in `ChatViewModel`. QA hooks: `qaForceEmptyState`, `qaShowActions`, `.qaGeometry()` probes (2026-06-11). |
| `ChatViewModel.swift` | `@MainActor ObservableObject` owning the conversation (`messages`, `isRunning`) + the send/stop/regenerate/**extractForEdit**/transcribe pipeline (wired to `Orchestrator`/`MediaTranscribe`, auto-continue, vision, speech). Extracted from `ContentView` (2026-06-09). Drains `MediaCapture` per turn → `reply.media`. |
| `MediaGallery.swift` | Inline image/video gallery rendered under an assistant reply (`message.media`). Double-bezel tray + concentric tiles, hover lift, button-in-button play well, duration/source chips. Images open in browser; direct-file videos play inline (AVKit sheet). Fed by `image_search`/`video_search` via `MediaCapture`. |
| `SettingsView.swift` | Settings panel: **compact Brain grid**, **collapsible Free / Paid API-key groups**, per-provider key/model/test rows, Unsloth Studio / vLLM endpoints, Effort picker, performance/voice/privacy/status sections. Brain-grid readiness reads ONLY cached `@State` key flags — no Keychain syscalls in body recomputes (2026-06-12 perf fix). |
| `SettingsBrainReadiness.swift` | Pure logic seam for SettingsView (2026-06-12): `BrainReadiness` (per-`BrainPreference` reachability rules over cached flags), `ActiveBrainProbe` (overlapping "is it working" run model), `BrainPing` (ping-reply verdict), `AnthropicKeyPresentation` (no-leak key subtitle). No UI imports; pinned by `SettingsBrainReadyTests`. |
| `RootView.swift` / `TabSwitcherBar.swift` / `BackgroundView.swift` | Tab container (**8 tabs** — Today/Chat/Code/Agents/Markets/Notes/Knowledge/RuneScape; `AppTab.hidden` (now empty) can gate any tab off every surface at once. **Markets restored 2026-06-20** (was hidden 2026-06-12 while sample-only; un-hidden once a live worldwide feed landed). **RuneScape tab added 2026-06-20** (⌘8, live Grand Exchange prices). Today-first, lazy-kept via `.opacity`; `BottomShortcutBar` pinned at the bottom), frosted segmented bar (sliding `matchedGeometryEffect` pill + **responsive labels**: collapse to icon-only when narrow, threshold scales with tab count), shared gradient background. |
| `TodayView.swift` | **Today tab (⌘1, default landing)** — home dashboard: greeting + Quick Actions + live stat cards (notes/tasks, knowledge docs, market) reading the real stores. Read-only navigation surface. |
| `CodeView.swift` / `CodeSyntaxView.swift` / `FileTree.swift` | **Code tab (⌘3)** — agentic coding workspace (file tree + syntax-highlighted editor). |
| `AgentsView.swift` | **Agents tab (⌘4)**: live agent status + Autonomous Mode loop. |
| `MarketsView.swift` / `MarketsStub.swift` | **Markets tab (⌘5)** — live worldwide feed (Chat A). Sections: Watchlist (with **search/add any ticker** → persisted user list) / **Ideas** (advisor-ranked what/when/how-much board; per-card sparkline + **tap-through detail sheet** with full advice + inline 5y backtest) / heatmap / portfolio (**risk-parity sizing**) / alerts / briefing. Over `StockSageStore` (heavy advisor/backtest compute runs **off-main** via `Task.detached`), backed by `StockSageQuoteService` (keyless Yahoo `v8/chart`, ~99 instruments across ~33 markets incl. FX/crypto) + `StockSageAdvisor`/`Backtester`/`RiskParity`. Hardened by two adversarial review-workflow passes (15 defects fixed). `MarketsStub` is the legacy market-status placeholder store. |
| `RuneScapeMarketView.swift` | **RuneScape tab (⌘8)** — live Old School RuneScape Grand Exchange item prices (curated blue-chip watchlist + full-mapping search) over `RuneScapeStore`/`RuneScapeMarketService` (keyless `prices.runescape.wiki`). |
| `ScratchpadView.swift` | **Notes tab (⌘6)** — notes + tasks UI over `ScratchpadStore`; same data the `capture_note`/`add_task`/… tools write. |
| `KnowledgeView.swift` | **Knowledge tab (⌘7)** — private document Q&A: add files (button/drag-drop) or paste text, grounded answers w/ sources over `KnowledgeStore`; on-device-only generation; chat reaches it via `search_documents`. |
| `BottomShortcutBar.swift` | Always-visible footer of clickable shortcut hints (⌘K · ⌘N · ⌘J · ⌘/ · ⌘,); flips the same `AppState` flags as the menu bar. |
| `VoiceModeView.swift` | **Hands-free Voice (⌘J)** — full-screen dictate→answer→speak loop (`Voice/VoiceSession`); "Save to Notes" writes the transcript to `ScratchpadStore`. |
| `OnboardingView.swift` / `CommandPalette.swift` (⌘K) / `ShortcutsView.swift` (⌘/) | First-run welcome; searchable command palette; keyboard-shortcuts cheat sheet. |
| `MemoryView.swift` | "What I know about you" — durable facts list. |
| `MarkdownText.swift` | Lightweight markdown renderer (fenced code blocks, etc.). |
| `LiveTranscriptionView.swift` / `CopilotSignInView.swift` | Live-transcription UI; Copilot device-flow sheet. |

### `Persistence/`, `Media/`, `StockSage/`, `Knowledge/`, `Voice/`, `DesignSystem/`
- **Persistence:** `Attachments.swift` (attached items + screen capture), `MemoryStore.swift` (long-term user facts), `PromptLibrary.swift` (reusable prompts), `ScratchpadStore.swift` (notes + tasks; `@MainActor ObservableObject`, JSON in App Support).
- **Knowledge:** `KnowledgeStore.swift` (`@unchecked Sendable` doc vault — chunk + keyword-primary/`NLEmbedding`-boosted search, JSON-persisted; the `search_documents` tool is implemented inline in `LocalLLM.runLocalTool`) + `ExternalToolsKnowledge.swift`.
- **Voice:** `VoiceSession.swift` / `VoiceTurn.swift` — hands-free dictate→LocalLLM→TTS loop driving `VoiceModeView`.
- **Media:** `LiveTranscriber.swift` (system-audio live transcription), `MediaTranscribe.swift`/`Transcriber.swift` (file transcription), `SpeechIn.swift` (mic dictation), `SpeechOut.swift` (TTS).
- **StockSage:** `StockSageModels/Store/SignalEngine/BriefingService/ScreenAnalysis/Monitor/Portfolio/QuoteService` — namespaced market subsystem (in-memory store, pure signal engine, real LocalLLM briefings + real vision; theater dropped). **`StockSageQuoteService` (2026-06-20)** is the live worldwide feed: keyless Yahoo Finance `v8/chart`, bounded-concurrency fan-out, gated by `ToolPolicy.isExternalAllowed`; `StockSageUniverse.worldwide` seeds ~99 instruments across ~33 markets (Saudi first) — equities on 28 exchanges plus world indices, **FX (`EURUSD=X`…, incl. `USDSAR=X`) and crypto (`BTC-USD`…)**. **`StockSageIndicators` + `StockSageAdvisor` + `StockSageBacktester` + `StockSageRiskParity` + `StockSageRegime` (2026-06-20)** are the trading-intelligence engine (all pure + `nonisolated`, heavy work runs off-main): technical indicators + a regime-filtered advisor (`TradeAdvice`: action/conviction/stop/target/fixed-fractional size/caveat), a no-look-ahead walk-forward backtester, inverse-vol risk-parity sizing, and a **market regime gauge** (S&P-vs-200DMA + breadth + VIX + momentum → risk-on/off + a position-size bias). **`StockSageVolRegime` (2026-06-27, EDGE_RESEARCH #1)**: per-symbol realized-vol regime brake (VIX-free; works on Tadawul/FX/crypto). Rolls 21-bar annualized vol over 252 historical windows, ranks via empirical CDF, computes a continuous `sizingMultiplier ≤1` that composes with the market-regime bias and the crypto risk scaler in `StockSageCapitalAllocator`. Also surfaces a ⚠ note in the idea's "Why" rationale when elevated. Evidence + design: `MARKETS_INTELLIGENCE_RESEARCH.md`. `ScreenAnalysis` is built-but-unwired (pending a chat-tool hookup decision).
- **RuneScape:** `RuneScapeModels/MarketService/Store` (+ `Views/RuneScapeMarketView`) — live OSRS Grand Exchange market (2026-06-20). Keyless community feed (`prices.runescape.wiki`: `/mapping` items + `/latest` instant-buy/sell), gated by `ToolPolicy`. Curated featured watchlist + name search over the full ~4k-item mapping; honest "community data, educational only" framing. Owner confirmed = Old School RuneScape.
- **RuneLite plugin (`runelite-plugin/`, outside the Xcode target):** a standalone Java/Gradle **RuneLite extension** ("Salehman GE Flips", 2026-06-20; substantially expanded 2026-06-25) — the OSRS GE feature as a RuneLite side-panel flip finder over the same `prices.runescape.wiki` API. Ranks by post-tax margin / ROI / profit-per-limit / gp-hour and a **realized gp/hour** (gp/hour × a freshness-confidence multiplier that down-ranks stale quotes — the default sort). Panel: item icons, profit/ROI hero line, freshness dot, live "updated" clock, in-panel sort, name search, **favourites** (persisted, pin-to-top), a **budget allocator** ("I have N gp → buy this", buy-limit aware), an **"alch instead"** cue (highalch − nature − item cost vs realized gp/hour), a **thin-volume** badge, optional **auto-refresh** + threshold **notifications**, and a click-to-expand **price sparkline** (`/timeseries`). Robustness: per-call HTTP timeouts, mapping cache TTL with stale-serve-on-failure, single-flight refresh. Pure logic (FlipFinder/BudgetPlanner/Sparkline.mids) is JUnit-tested. **Runs locally in a dev-mode client** (see README + `play.sh`/`capture-jagex.sh`, incl. a Jagex-account login bridge); NOT yet submitted to the Plugin Hub. Not part of the macOS app build.
- **Intelligence:** `Effort.swift` (effort ladder: candidates × self-critique rounds × judge — **wired 2026-06-11 into `SalehmanLeader.finalize`**: leader pass runs at the configured effort; pinned `.salehman` drafts get critique-only refinement (`refineRounds`, gated on the Leader toggle); coding modes excluded; default `.instant` = exact pre-Effort call count, higher effort opt-in) + `SelfCritique.swift` (refine loop, used by Effort).
- **DesignSystem:** `DesignSystem.swift` — `DS.*` tokens, motion curves (`DS.Motion.snappy/smooth/…`), `Bezel`/`Eyebrow`/`SuggestionCard`.

---

## 3. The brain system (the heart of the app)

Two enums drive everything:
- **`BrainPreference`** (`AppSettings.swift`) — what the USER pinned. 20 cases:
  `.auto`, `.freeAuto`, `.freeCoding`, `.cloudCoding`, `.ollama`, `.claudeHaiku`,
  `.grok`, `.gemini`, `.groq`, `.mistral`, `.cerebras`, `.codex`, `.copilot`,
  `.openRouter`, `.ensemble`, **`.salehman` (the default)**,
  `.unslothStudio`, `.vllm`, **`.uncensored`** (local abliterated ~3B via Ollama —
  unfiltered, web-search capable, free/key-less; 4th in `selectableCases`, added
  2026-06-18). Persisted under `Keys.brainPreference`.
  (`.apple` was removed with Apple Intelligence, 2026-06-08; `.deepSeek` removed 2026-06-12.)
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
  (local tier only; `nil` if no local brain is reachable). The Knowledge
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
  `isUsableFreeAnswer`); if all free cloud brains fail it falls back to the LOCAL
  tier **sequentially** (never concurrent — preserves the RAM
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
| NVIDIA NIM | `NvidiaClient` | `integrate.api.nvidia.com/v1` | `nvidia-api-key` | **free tier** — hosts real DeepSeek V4; default `deepseek-ai/deepseek-v4-flash` |

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
- `PersistenceRoundTripTests` — now ACTIVE (the R4 seams landed: `MemoryStore(baseDirectory:)`, `ScratchpadStore(testingBaseDirectory:)`, `StockSagePortfolio(userDefaults:)`).
- `SettingsBrainReadyTests` — now ACTIVE (2026-06-12, Chat D): the brainReady extract landed as `Views/SettingsBrainReadiness.swift`; 7 tests pin the readiness rules (`.auto` local-only, `.freeAuto` never-spends, `.salehman` cloud-first), the active-brain probe overlap rules, the ping verdict, and the no-leak key subtitle.
- `BrainRoutingDispatchTests` — now ACTIVE (2026-06-12, Chat D): the routing plan extracted to `LLM/BrainRouting.swift`; 5 tests pin single-dispatch/no-fallthrough, the `.auto`-never-cloud invariant, the Offline-Mode hard-gate + empty rosters (the Offline-leak fix), the freeAuto free-only roster, and documented roster membership (the historic ensemble/DeepSeek drift dissolved with the provider's removal, 2026-06-12). All 8 review suites are now enabled.

Tests run **in parallel** — never have two tests mutate the same global (`UserDefaults.standard`) key, or they race (see the `brainPreference` lesson in the log). Use `@Suite(.serialized)` + explicit restore/clear for any shared FS/UD/singleton stores.

---

## 7. Known issues (from the 2026-06-05 multi-agent review)

**Fixed & shipped:** WebTools SSRF guard; SelfImprove symlink escape; ensemble
"Not working" false-negative; stale Groq/Cerebras/OpenRouter model IDs.

**Since resolved (verified 2026-06-11):**
- `AnalyzeImageTool` / `TranscribeMediaTool` symlink follow — moot: both files were removed with the FM tool layer.
- `AgentPipeline.lastOutcome` data race — now `NSLock`-guarded (`_lastOutcome` + `lastOutcomeLock`).
- `AgentRegistry` first-run registration race — now a thread-safe `registerToken` static-let once-init.

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


## 9. New Intelligence Layer Additions (2026-06-10)

### Effort Control
The Effort control in Salehman AI/Intelligence/Effort.swift provides runtime-adjustable reasoning depth, token budget, and computational effort for the intelligence layer. It enables the orchestrator (and agents) to scale effort per-task — low for quick factual answers, high for complex multi-step reasoning or self-critique. This is a core Phase 1 deliverable for quality-over-quantity intelligence.

## 10. Markets money-velocity system (2026-06-21)

A cohesive "what should I do to make money the fastest, honestly?" layer over the Markets
tab + the RuneLite OSRS plugin. Owner directive: surface the highest-velocity (fastest
expected payoff per unit time) opportunities — **with a hard honesty floor**: every number
is an ESTIMATE or a PAST/own-history path, never a forecast; risk control > signal; each
surface carries its caveat. All engines are pure + `nonisolated` + unit-tested (hand-verified
literals); the gate is `tools/typecheck.sh` (now `-strict-concurrency=complete`, matching Xcode —
it cannot run tests, so test arithmetic is verified by hand and by adversarial review workflows).

### Engines (`Salehman AI/StockSage/`)
- **`StockSageExpectedValue.swift`** — the core. `ExpectedValue` + `ev(…)` = pWin·rewardR − (1−pWin),
  where pWin is an ESTIMATE mapped from conviction into a conservative 35–58% band (`winProbEstimate`).
  `expectedHoldDays`/`velocity` (EV ÷ hold = EV/day), `rankByEV`, `rankByVelocity`, `fastLane`
  (positive-EV + has-velocity, ranked by EV/day), `bestOpportunity` (highest positive-EV buy; nil if none),
  `expectedWeeklyR` (top-N velocities × ~5 days), `expectedWeeklyDollars` (× account × risk %),
  `summary` → `MoneyVelocitySummary` (best/fastest/weekly + worst-run drawdown brake), `playbook`
  (copyable ordered action list). `VelocityHoldDays` (tunable per-class hold; defaults crypto 3 / equity 12)
  is a defaulted `holds:` param threaded through every velocity function (defaults preserve behavior).
- **`StockSageGEFlip.swift`** — OSRS flip velocity: `gpPerHour = (sell − buy − GE tax) × buyLimit ÷ 4h`,
  `sellTax` (floor(rate·sell), 5M cap, <50 exempt; rate a parameter, default 2% — live OSRS since 2025-05-29), `flips` ranks listings.
- **`StockSageDrawdownScenario.swift`** — `StockSageRiskOfRuin.scenario` → `DrawdownScenario`: k 1R stop-outs
  at risk f shrink the account by (1−f)^k; `isSteep` ≥20%. The velocity counterweight ("stay in the game").
  (Named `RiskOfRuin` to avoid colliding with the existing `StockSageDrawdown` underwater-curve engine.)
- **`StockSageVelocityHistory.swift`** — `VelocitySnapshot`/`record`/`trend` (recent-half vs early-half
  weekly-R, rising/flat/fading, nil <4 days) + `@MainActor StockSageVelocityHistoryStore` (UserDefaults JSON,
  one snapshot per UTC day, capped 60). "Your own history, not a forecast."
- **`StockSageGlossary.swift`** — `MoneyVelocityTerm` (8 terms) + `explain(_:)` plain-English explainers,
  each restating its honest hedge (enforced by a test); `moneyVelocityHelp` umbrella. Surfaced as ⓘ tooltips.
- Drawdown/streak inputs come from the existing `StockSageJournal` (`equityRisk`, `compoundingCurve`).

### Surfaces
- **`Views/MarketsView.swift`** — top-of-tab **money-velocity summary card** (best · fastest · est. weekly ·
  history trend+sparkline · drawdown brake · **Copy plan**); the **Ideas** board's 3-way sort (EV / EV-per-day /
  signal), the **"Best opportunity now"** card, the **"Fast lane"** strip (EV/day + weekly-R + $/week + tunable
  hold-day Steppers), per-idea EV badge + detail-sheet EV/EV-day lines; journal compounding ×growth +
  drawdown survival lines. `@AppStorage` persists the hold-day assumptions.
- **`Views/RuneScapeMarketView.swift`** — per-row "≈ N gp/hr" + a "Fastest flips — gp/hour" strip.
- **RuneLite Java plugin (`runelite-plugin/…`, ⚠️ UNVERIFIED — cannot compile here):** `FlipItem.gpPerHour`,
  `FlipFinder` gp/hour + `VELOCITY` comparator, `SortBy.VELOCITY`, panel gp/hour + buy-limit cells. Mirrors
  `StockSageGEFlip`; must be built with RuneLite before trusting. GE tax stays config-driven (default 2%, live since 2025-05-29).

Tests: `StockSageExpectedValueTests`, `StockSageRiskOfRuinTests`, `StockSageGEFlipTests`,
`StockSageVelocityHistoryTests`, `StockSageGlossaryTests` (+ journal tests for compounding). Hardened by
adversarial review workflows (passes 23–28; the few findings were honesty/label fixes, not math).

