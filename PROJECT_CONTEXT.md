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
> [`MARKETS_TAB_MAP.md`](MARKETS_TAB_MAP.md) (per-file knowledge map of every
> StockSage engine module + Markets view: purpose, consumers, invariants, gotchas),
> [`COORDINATION.md`](COORDINATION.md) (how two parallel Claude sessions split
> the work), [`DEVELOPMENT_LOG.md`](DEVELOPMENT_LOG.md) (running change journal),
> [`SOURCE_BUNDLE.md`](SOURCE_BUNDLE.md) (all source in one file).

---

## 1. What this app is

**Salehman AI** is a native **macOS SwiftUI** desktop app: a multi-brain AI chat
assistant. **It is local-only** (owner-directed full cloud-provider removal,
2026-06-18 — "delete anthropic, grok, gemini, groq, mistral, cerebras, openAI,
copilot, openRouter … go local-only"). Every brain answers on this Mac (or a
box you personally point it at) — there is no third-party cloud client left in
the app. It can answer from several local "brains": the **Salehman** chain
(on-device MLX → Ollama custom model — no external servers, ever), a local
**Ollama** model (`qwen2.5-coder:7b`, server URL configurable in Settings —
defaults to `localhost:11434`, can point at e.g. an always-on PC over
Tailscale), local OpenAI-compatible servers you configure the endpoint for
(**Unsloth Studio**, **vLLM** — also usable to reach your OWN fine-tune served
on a free cloud GPU via Colab/Kaggle → cloudflared, since you provide the URL),
or an **Uncensored** local model (abliterated ~3B via Ollama, web-search
capable, added 2026-06-18). (Apple Intelligence was removed 2026-06-08;
DeepSeek's direct API was removed 2026-06-12; all remaining cloud providers
were removed 2026-06-18.) It has a multi-agent pipeline, on-device tools
(shell, vision, transcription, web), live audio transcription, a StockSage
market-analysis subsystem, and persistent chat + long-term memory.

- **Language / runtime:** Swift 6 **language mode** (`SWIFT_VERSION = 6.0`, enforced as of 2026-06-09 — data races are compile errors, not warnings), `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` on the app target and, mirrored, the test targets. Off-main work is explicitly `nonisolated`/`nonisolated(unsafe)`.
  Pure utility statics are marked `nonisolated`.
- **UI:** SwiftUI, custom dark "DS" design system (no stock chrome).
- **Secrets:** the few remaining Keychain entries (NVIDIA NIM key — currently
  orphaned/unused after the cloud removal, Unsloth API token, HF token, vLLM
  bearer token for a publicly-hosted server) live ONLY in the macOS
  **Keychain** (never UserDefaults, never source); no chat brain requires one.
- **Privacy posture:** every brain is local by construction — there is no
  cloud provider left to silently pin. `.unslothStudio`/`.vllm` only leave the
  Mac if you type a non-loopback endpoint yourself (`generateOnDevice`, used by
  the Knowledge vault, additionally gates on `isLocalLoopback` so it never
  treats a remote endpoint as on-device).

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

### `LLM/` — the brain layer (Chat B's lane) — **local-only since 2026-06-18**
| File | Purpose |
|---|---|
| `LocalLLM.swift` | **The brain router** (~1150 lines). `generate` / `generateStreaming` / `chat` each `switch` on `BrainRouting.dispatch` (per-brain EXECUTION lives here — `SalehmanEngine`/`UnslothStudio`/`VLLM`/`OllamaClient` calls); `currentBrain` = `BrainRouting.reachableBrain` over a `BrainRouteConfig.live()` snapshot. `generateOnDevice` is the local-tier-only entry point for privacy-promising features (Knowledge vault). Houses the **tool loop** (`ollamaToolSpecs`, `runLocalTool`, `chatOllamaWithTools` / `chatOpenAICompatWithTools`). (`generateEnsemble`/`generateFreeAuto` — the All-Brains/Free·Auto cloud composite modes — were deleted with the cloud providers.) |
| `BrainRouting.swift` | **The routing PLAN (R1 seam, 2026-06-12)** — pure + hermetically tested (`BrainRoutingDispatchTests`): `BrainRouteConfig` (snapshot; `.live()` probes lazily per-pref: Ollama/uncensored/MLX/custom-model readiness + Unsloth/vLLM configured), `BrainRouting` (`dispatch` — exactly one target per pref, all targets local; `reachableBrain`/`anyBrainReachable`). Change a routing rule HERE, nowhere else. (`enum CloudProvider` and every cloud branch were deleted 2026-06-18 — the app is local-only.) |
| `OllamaClient.swift` | Local Ollama server. Model resolver (7b→14b→32b), `keep_alive`/`num_ctx`, `unloadAll()`. Default coder model `qwen2.5-coder:7b`. Server URL is now **user-configurable** (`AppSettings.ollamaServerURL`, added 2026-06-22) — defaults to `localhost:11434`, can point at a remote box (e.g. an always-on PC over Tailscale) so generation runs on that machine's GPU; both the Chat tab and the Code tab read the same setting. |
| `OpenAICompatibleClient.swift` | Generic `/v1/chat/completions` client (+ SSE streaming + error decoding). `UnslothStudio` and `VLLM` are thin configs of this — the only two consumers left after the cloud removal. |
| `SalehmanEngine.swift` / `SalehmanLeader.swift` / `SalehmanPersona.swift` | The **`.salehman` default brain** — **on-device only**: resolution order is (1) on-device MLX if loaded, (2) Ollama's `salehman` custom model. No external servers are ever contacted (`SalehmanEngine.hasAnyCloud` is a hardcoded `false`, kept only so call sites compile unchanged). `SalehmanLeader` finalizes pipeline output in the Salehman voice. |
| `MLXSalehmanEngine.swift` | Local MLX (Apple-Silicon) inference path for the fine-tuned Salehman weights. |
| `UnslothStudio.swift` / `VLLM.swift` | Local OpenAI-compatible servers (Unsloth Studio / `mlx_lm.server` / LM Studio / llama.cpp's server; `vllm serve` `:8000/v1`) as explicitly-pinned brains — you supply the endpoint URL in Settings, no auto-fallback. Also the route to serve your OWN fine-tune on a free cloud GPU (Kaggle/Colab → cloudflared URL). Each has an `isLocalLoopback` guard so a non-loopback endpoint doesn't qualify for the on-device-only `generateOnDevice` privacy path. |
| `BrainAdapter.swift` / `OllamaBrainAdapter.swift` | `BrainAdapter` protocol + adapters — start of the data-driven brain registry (CODEBASE_REVIEW §3 R1). `BrainAdapterFactory` gives Ollama a dedicated adapter; every other local brain falls through to `LocalLLMFallbackAdapter` (delegates to `LocalLLM.generate()`). |
| `KeychainStore.swift` | `SecItem*` Keychain wrapper. `Account` enum is now just 4 local-adjacent entries: `nvidiaAPIKey` (orphaned — the NVIDIA cloud client it served was deleted with the rest; no code reads it), `unslothStudioAPIKey` (only for the Settings "use with Claude Code" copy snippet, not required by the chat brain), `hfToken` (used outside the app, by the cloud-GPU-serving notebook), `vllmAPIKey` (optional bearer token when self-hosting vLLM on a public GPU box). `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`. |
| `MemoryManager.swift` | Actor: subscribes to memory-pressure + thermal notifications; instance `concurrencyLimit()` + pure static policy funcs (`concurrencyLimit(pressure:thermal:physicalGB:)`, `shouldRefuseHeavyModel(...)`); auto-evicts Ollama under pressure. |
| `BrainStatus.swift` | MainActor `ObservableObject`; polls which brain is live every 10s; drives the header dot/label (`dotColor`/`symbol`) over the 5 local `LocalLLM.Brain` cases + `.none`. |

*(Deleted 2026-06-18 as part of the owner-directed local-only migration — do not re-add references to these: `AnthropicClient.swift`, `AnthropicBrainAdapter.swift`, `GrokClient.swift`, `GeminiClient.swift`, `OpenAIClient.swift`, `CopilotClient.swift`, `CloudBrains.swift` (held `GroqClient`/`MistralClient`/`CerebrasClient`/`OpenRouterClient`/`NvidiaClient`), `Views/CopilotSignInView.swift`. DeepSeek's direct client was removed earlier, 2026-06-12.)*

### `Agents/` — multi-agent pipeline (Chat A's lane)
| File | Purpose |
|---|---|
| `AgentPipeline.swift` | `run(mission:)` — runs a complexity-tiered agent team (1 → 15 agents) for every (local) brain. Batches by `MemoryManager.concurrencyLimit()`. (The ensemble/freeAuto/freeCoding/cloudCoding short-circuits were removed with the cloud composite modes, 2026-06-18.) |
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
| `SettingsView.swift` | Settings panel: **compact Brain grid** (4 selectable local brains), Ollama server URL row, Unsloth Studio / vLLM endpoint+model rows, Effort picker, performance/voice/privacy/status sections. No cloud key rows remain post local-only migration. Brain-grid readiness reads ONLY cached `@State` engine-probe flags — no Keychain syscalls in body recomputes (2026-06-12 perf fix). |
| `SettingsBrainReadiness.swift` | Pure logic seam for SettingsView (2026-06-12, rewritten local-only 2026-06-18): `BrainReadiness` (per-`BrainPreference` reachability rules over the 6 local brains' cached flags), `ActiveBrainProbe` (overlapping "is it working" run model), `BrainPing` (ping-reply verdict). No UI imports; pinned by `SettingsBrainReadyTests`. |
| `RootView.swift` / `TabSwitcherBar.swift` / `BackgroundView.swift` | Tab container (**8 tabs** — Today/Chat/Code/Agents/Markets/Notes/Knowledge/RuneScape; `AppTab.hidden` (now empty) can gate any tab off every surface at once. **Markets restored 2026-06-20** (was hidden 2026-06-12 while sample-only; un-hidden once a live worldwide feed landed). **RuneScape tab added 2026-06-20** (⌘8, live Grand Exchange prices). Today-first, lazy-kept via `.opacity`; `BottomShortcutBar` pinned at the bottom), frosted segmented bar (sliding `matchedGeometryEffect` pill + **responsive labels**: collapse to icon-only when narrow, threshold scales with tab count), shared gradient background. |
| `TodayView.swift` | **Today tab (⌘1, default landing)** — home dashboard: greeting + Quick Actions + live stat cards (notes/tasks, knowledge docs, market) reading the real stores. Read-only navigation surface. |
| `CodeView.swift` / `CodeSyntaxView.swift` / `FileTree.swift` | **Code tab (⌘3)** — agentic coding workspace (file tree + syntax-highlighted editor). |
| `AgentsView.swift` | **Agents tab (⌘4)**: live agent status + Autonomous Mode loop. |
| `MarketsView.swift` / `MarketsStub.swift` | **Markets tab (⌘5)** — live worldwide feed (Chat A). Sections: Watchlist (with **search/add any ticker** → persisted user list) / **Ideas** (advisor-ranked what/when/how-much board; per-card sparkline + **tap-through detail sheet** with full advice + inline 5y backtest) / heatmap / portfolio (**risk-parity sizing**) / alerts / briefing. Over `StockSageStore` (heavy advisor/backtest compute runs **off-main** via `Task.detached`), backed by `StockSageQuoteService` (keyless Yahoo `v8/chart`; universe = **901 names, Tadawul + NASDAQ ONLY** since the 2026-07-16 owner directive — 29 `.SR` incl. ^TASI.SR + 872 NASDAQ-listed [AlphaVantage LISTING_STATUS-classified]; 9 market groups. Was ~99 → ~210 → 2,420 worldwide pre-restriction. SAR FX rate now fetched as engine infra, not a universe member) + `StockSageAdvisor`/`Backtester`/`RiskParity`. Hardened by two adversarial review-workflow passes (15 defects fixed). `MarketsStub` is the legacy market-status placeholder store. |
| `RuneScapeMarketView.swift` | **RuneScape tab (⌘8)** — live Old School RuneScape Grand Exchange item prices (curated blue-chip watchlist + full-mapping search) over `RuneScapeStore`/`RuneScapeMarketService` (keyless `prices.runescape.wiki`). |
| `ScratchpadView.swift` | **Notes tab (⌘6)** — notes + tasks UI over `ScratchpadStore`; same data the `capture_note`/`add_task`/… tools write. |
| `KnowledgeView.swift` | **Knowledge tab (⌘7)** — private document Q&A: add files (button/drag-drop) or paste text, grounded answers w/ sources over `KnowledgeStore`; on-device-only generation; chat reaches it via `search_documents`. |
| `BottomShortcutBar.swift` | Always-visible footer of clickable shortcut hints (⌘K · ⌘N · ⌘J · ⌘/ · ⌘,); flips the same `AppState` flags as the menu bar. |
| `VoiceModeView.swift` | **Hands-free Voice (⌘J)** — full-screen dictate→answer→speak loop (`Voice/VoiceSession`); "Save to Notes" writes the transcript to `ScratchpadStore`. |
| `OnboardingView.swift` / `CommandPalette.swift` (⌘K) / `ShortcutsView.swift` (⌘/) | First-run welcome; searchable command palette; keyboard-shortcuts cheat sheet. |
| `MemoryView.swift` | "What I know about you" — durable facts list. |
| `MarkdownText.swift` | Lightweight markdown renderer (fenced code blocks, etc.). |
| `LiveTranscriptionView.swift` | Live-transcription UI. (`CopilotSignInView.swift` — the Copilot OAuth device-flow sheet — was deleted 2026-06-18 with the rest of the cloud providers.) |

### `Persistence/`, `Media/`, `StockSage/`, `Knowledge/`, `Voice/`, `DesignSystem/`
- **Persistence:** `Attachments.swift` (attached items + screen capture), `MemoryStore.swift` (long-term user facts), `PromptLibrary.swift` (reusable prompts), `ScratchpadStore.swift` (notes + tasks; `@MainActor ObservableObject`, JSON in App Support).
- **Knowledge:** `KnowledgeStore.swift` (`@unchecked Sendable` doc vault — chunk + keyword-primary/`NLEmbedding`-boosted search, JSON-persisted; the `search_documents` tool is implemented inline in `LocalLLM.runLocalTool`) + `ExternalToolsKnowledge.swift`.
- **Voice:** `VoiceSession.swift` / `VoiceTurn.swift` — hands-free dictate→LocalLLM→TTS loop driving `VoiceModeView`.
- **Media:** `LiveTranscriber.swift` (system-audio live transcription), `MediaTranscribe.swift`/`Transcriber.swift` (file transcription), `SpeechIn.swift` (mic dictation), `SpeechOut.swift` (TTS).
- **StockSage:** `StockSageModels/Store/SignalEngine/BriefingService/ScreenAnalysis/Monitor/Portfolio/QuoteService` — namespaced market subsystem (in-memory store, pure signal engine, real LocalLLM briefings + real vision; theater dropped). **`StockSageQuoteService` (2026-06-20)** is the live worldwide feed: keyless Yahoo Finance `v8/chart`, bounded-concurrency fan-out, gated by `ToolPolicy.isExternalAllowed`; `StockSageUniverse.worldwide` seeds **901 names — Tadawul + NASDAQ ONLY** (owner directive 2026-07-16: 29 `.SR` incl. ^TASI.SR + 872 NASDAQ-listed, classified via AlphaVantage LISTING_STATUS and baked as `nasdaqListed`; the full curated literals remain in source as history, `build(_:)` filters at the single choke point; 9 market groups. Progression: ~99 → ~210 → 2,420 worldwide → 901 restricted. The SAR→USD rate is fetched as engine INFRA — `StockSageStore.infraFX`, never an idea/feed row) — equities on 28 exchanges plus world indices, **FX (`EURUSD=X`…, incl. `USDSAR=X`) and crypto (`BTC-USD`…)**. **`StockSageIndicators` + `StockSageAdvisor` + `StockSageBacktester` + `StockSageRiskParity` + `StockSageRegime` (2026-06-20)** are the trading-intelligence engine (all pure + `nonisolated`, heavy work runs off-main): technical indicators + a regime-filtered advisor (`TradeAdvice`: action/conviction/stop/target/fixed-fractional size/caveat), a no-look-ahead walk-forward backtester, inverse-vol risk-parity sizing, and a **market regime gauge** (S&P-vs-200DMA + breadth + VIX + momentum → risk-on/off + a position-size bias). **`StockSageVolRegime` (2026-06-27, EDGE_RESEARCH #1)**: per-symbol realized-vol regime brake (VIX-free; works on Tadawul/FX/crypto). Rolls 21-bar annualized vol over 252 historical windows, ranks via empirical CDF, computes a continuous `sizingMultiplier ≤1` that composes with the market-regime bias and the crypto risk scaler in `StockSageCapitalAllocator`. Also surfaces a ⚠ note in the idea's "Why" rationale when elevated. Evidence + design: `MARKETS_INTELLIGENCE_RESEARCH.md`. `ScreenAnalysis` is built-but-unwired (pending a chat-tool hookup decision).
- **RuneScape:** `RuneScapeModels/MarketService/Store` (+ `Views/RuneScapeMarketView`) — live OSRS Grand Exchange market (2026-06-20). Keyless community feed (`prices.runescape.wiki`: `/mapping` items + `/latest` instant-buy/sell), gated by `ToolPolicy`. Curated featured watchlist + name search over the full ~4k-item mapping; honest "community data, educational only" framing. Owner confirmed = Old School RuneScape.
- **RuneLite plugin (`runelite-plugin/`, outside the Xcode target):** a standalone Java/Gradle **RuneLite extension** ("Salehman GE Flips", 2026-06-20; substantially expanded 2026-06-25) — the OSRS GE feature as a RuneLite side-panel flip finder over the same `prices.runescape.wiki` API. Ranks by post-tax margin / ROI / profit-per-limit / gp-hour and a **realized gp/hour** (gp/hour × a freshness-confidence multiplier that down-ranks stale quotes — the default sort). Panel: item icons, profit/ROI hero line, freshness dot, live "updated" clock, in-panel sort, name search, **favourites** (persisted, pin-to-top), a **budget allocator** ("I have N gp → buy this", buy-limit aware), an **"alch instead"** cue (highalch − nature − item cost vs realized gp/hour), a **thin-volume** badge, optional **auto-refresh** + threshold **notifications**, and a click-to-expand **price sparkline** (`/timeseries`). Robustness: per-call HTTP timeouts, mapping cache TTL with stale-serve-on-failure, single-flight refresh. Pure logic (FlipFinder/BudgetPlanner/Sparkline.mids) is JUnit-tested. **Runs locally in a dev-mode client** (see README + `play.sh`/`capture-jagex.sh`, incl. a Jagex-account login bridge); NOT yet submitted to the Plugin Hub. Not part of the macOS app build.
- **Intelligence:** `Effort.swift` (effort ladder: candidates × self-critique rounds × judge — **wired 2026-06-11 into `SalehmanLeader.finalize`**: leader pass runs at the configured effort; pinned `.salehman` drafts get critique-only refinement (`refineRounds`, gated on the Leader toggle); coding modes excluded; default `.instant` = exact pre-Effort call count, higher effort opt-in) + `SelfCritique.swift` (refine loop, used by Effort).
- **DesignSystem:** `DesignSystem.swift` — `DS.*` tokens, motion curves (`DS.Motion.snappy/smooth/…`), `Bezel`/`Eyebrow`/`SuggestionCard`.

---

## 3. The brain system (the heart of the app)

**The app is local-only** (owner-directed full cloud removal, 2026-06-18 — see
§1). Two enums drive everything:
- **`BrainPreference`** (`AppSettings.swift`) — what the USER pinned. **6 cases,
  all local:** `.auto`, `.ollama`, **`.salehman` (the default)**,
  `.unslothStudio`, `.vllm`, **`.uncensored`** (local abliterated ~3B via
  Ollama — unfiltered, web-search capable, free/key-less; added 2026-06-18).
  Persisted under `Keys.brainPreference`. `selectableCases` (what the Brain
  picker shows) is `[.salehman, .auto, .unslothStudio, .uncensored]` — `.ollama`
  and `.vllm` still work if set directly (e.g. via the rotation hotkey) but
  aren't surfaced in the menu. `isPaid` is a hardcoded `false` for every case.
  (`.apple` was removed with Apple Intelligence, 2026-06-08; `.deepSeek`
  removed 2026-06-12; all 9 `CloudProvider` cases — `.freeAuto`/`.freeCoding`/
  `.cloudCoding`/`.ensemble`/`.claudeHaiku`/`.grok`/`.gemini`/`.groq`/
  `.mistral`/`.cerebras`/`.codex`/`.copilot`/`.openRouter` — removed
  2026-06-18.)
- **`LocalLLM.Brain`** — which brain actually ANSWERS (resolved from the pref +
  live availability), used for the header label/dot. 5 cases + `.none`:
  `.ollamaCoder`, `.salehman`, `.unslothStudio`, `.vllm`, `.uncensored`.

**Routing** lives in `BrainRouting.swift` (the pure routing PLAN) + `LocalLLM`
(execution):
- `BrainRouting.dispatch(pref:offlineOnly:)` maps every `BrainPreference` to
  exactly one `Dispatch` target — `.salehman`, `.unslothStudio`, `.vllm`,
  `.localTier` (`.auto`/`.ollama` → Ollama), or `.uncensoredLocal` (forces the
  abliterated model). `generate` / `generateStreaming` / `chat` in `LocalLLM`
  each `switch` on this dispatch and call the matching engine directly — there
  is no cloud branch left to gate.
- `BrainRouting.reachableBrain(_:)` (over a `BrainRouteConfig.live()` snapshot)
  resolves pref → `LocalLLM.Brain`, returning `.none` if the pinned brain is
  unreachable so the UI shows an honest "unavailable" message instead of
  silently falling back.
- `generate` **routes to the pinned local brain** — since every brain is local
  there is no "paid cloud" risk, but `.unslothStudio`/`.vllm` still accept an
  arbitrary user-typed endpoint URL. Features that PROMISE on-device-only
  behavior must use **`generateOnDevice(_:maxTokens:) -> String?`**, which
  additionally requires `UnslothStudio`/`VLLM` to be on a **loopback** host
  (`isLocalLoopback`) before treating them as on-device — a non-loopback
  endpoint is still pinnable as a normal brain, just not for this path. The
  Knowledge vault uses it (added 2026-06-05 after an audit caught a leak — see
  DEVELOPMENT_LOG).
- The `.salehman` brain itself (`SalehmanEngine.generate`) resolves in a fixed
  order: **(1) on-device MLX** (if the fine-tune is loaded), **(2) Ollama**
  (the `salehman` custom model) — no network call is ever made from this path.

**`.salehman` vs `.unslothStudio`/`.vllm`:** these are three *separate* pins,
not a fallback chain into each other. `.salehman` is MLX→Ollama only. If you
want the app to talk to your OWN fine-tune served elsewhere (a local
`mlx_lm.server`/LM Studio/llama.cpp instance, a `vllm serve` box, or a free
Colab/Kaggle GPU tunneled via cloudflared), pin `.unslothStudio` or `.vllm`
explicitly and set its endpoint URL in Settings (or via the `/connect` chat
command for the cloud-GPU case) — there's no key needed for either.

**No composite/cloud modes remain.** All Brains at Once (`.ensemble`) and
Free · Auto (`.freeAuto`/`.freeCoding`/`.cloudCoding`) — which used to race or
fan out across the cloud providers — were deleted with those providers on
2026-06-18. `AgentPipeline.run` no longer needs to short-circuit for them;
every pinned brain now runs the normal multi-agent path.

---

## 4. Local inference endpoints

There are no cloud providers left — every brain answers on-device or on a
server whose URL/model you configure yourself. No API key is required for any
of them (a couple of Keychain slots remain for optional/adjacent uses — see
`KeychainStore.swift` in §2 — but none gate whether a chat brain works).

| Brain (`BrainPreference`) | Engine | Where it runs | Config | Notes |
|---|---|---|---|---|
| `.salehman` (default) | `SalehmanEngine` → `MLXSalehmanEngine` / `OllamaClient` | on-device MLX, else the `salehman` Ollama custom model | none — automatic | Never contacts an external server (`hasAnyCloud == false`, hardcoded). |
| `.auto` / `.ollama` | `OllamaClient` | Ollama server | `AppSettings.ollamaServerURL` (default `localhost:11434`; can point at a remote GPU box, e.g. over Tailscale) | Default coder model `qwen2.5-coder:7b`; resolver falls back 7b→14b→32b. |
| `.uncensored` | `OllamaClient` forced to the abliterated model | same Ollama server as above | none — automatic model pin | `OllamaClient.uncensoredModel` (`huihui_ai/llama3.2-abliterate:3b`); web-search capable via the tool loop; warmed into RAM on launch when pinned. |
| `.unslothStudio` | `UnslothStudio` → `OpenAICompatibleClient` | any local OpenAI-compatible server, or your own fine-tune on a free cloud GPU (Colab/Kaggle → cloudflared) | `AppSettings.unslothStudioEndpoint` + `unslothStudioModel` (Settings, or `/connect` chat command) | Unauthenticated by default (`requiresKey: false`); typically Unsloth Studio `/v1` on `:8000`, `mlx_lm.server` `:8080/v1`, LM Studio, llama.cpp's server. |
| `.vllm` | `VLLM` → `OpenAICompatibleClient` | a `vllm serve` box (local or remote, e.g. RunPod) | `AppSettings.vllmEndpoint` + `vllmModel` | Unauthenticated for `localhost`; `KeychainStore.Account.vllmAPIKey` is available if you self-host on a public GPU with `--api-key`. |

⚠️ **`.unslothStudio`/`.vllm` endpoints are user-typed URLs** — only a loopback
host (`localhost`/`127.0.0.1`/`::1`) is treated as on-device by
`generateOnDevice`; a public URL still works as a normal pinned brain but
doesn't qualify for privacy-promising features (the Knowledge vault).

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

_Keep this file current. Last refreshed: 2026-07-01 (§11 added)._


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
- **`StockSageTickSize.swift`** — Tadawul tick-band table (Saudi Exchange regime effective 2025-06-29;
  sourced Argaam #1823880 + Sahm Capital) + nearest-tick rounding; `placeabilityNote` appends a DISPLAY-ONLY
  advisory to the copied `.SR` order plan when a displayed (2-dp) engine level is off the tick grid, each leg
  rounded with its own band tick. Engine stop/target and all EV/R:R math untouched.
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

## 11. New StockSage engines (2026-07-01 backlog closeout)

The `StockSage/` directory has grown substantially since §10 (2026-06-21) across many iterations not
individually cataloged here — `SOURCE_BUNDLE.md` is the authoritative full-source reference and
`DEVELOPMENT_LOG.md` is the chronological record of every change. This entry covers only what landed
in the 2026-07-01 backlog-closeout session (RANKING/ALLOC/HARDENING/A11Y/FASTMONEY docs), so a reader
of just this file isn't missing the newest capabilities:

- **`StockSagePyramid.swift`** — standalone scale-in (pyramiding) ladder, mirrors `StockSagePartialLadder`'s
  scale-out shape. `levels(entry:stop:initialFraction:riskCap:)` → 3 shrinking tiers (100/50/25%) at
  0/+0.5R/+1.5R, uniformly scaled to respect `riskCap` (default `StockSageKelly.maxFraction`). Pure,
  zero `advise()`/`buildIdeas` wiring — an opt-in calculator, not an automatic signal.
- **`StockSageConvictionScaler.swift`** — `scaledRiskFraction(base:conviction:regimeBias:)`: an explicit,
  hard-capped-at-2% conviction- and regime-scaled per-trade risk fraction. Deliberately NOT wired into
  `advise()`/`suggestedWeight()`/`StockSageCapitalAllocator` — ships engine-only pending its own
  backtest, matching `StockSageCompoundingHorizon`'s earlier graduation pattern.
- **`StockSageSectorRotation.swift`** — `analyze(allTrades:minTrades:topN:)` ranks the OWNER's own closed
  trades by realized R/trade per sector, flags the top-N as "rotating in." Reframed from the original
  backlog spec to be flag-only (a surfaced `rationale` note via `buildIdeas`, same pattern as
  `StockSageReturnShape`/`StockSageVolStability`) — never a conviction input, since it's the same
  momentum-chasing premise class as the ablated `relativeStrengthEnabled` term.
- **`StockSageRelativeStrength.swift`** — `rank(_:[String:Double]) -> [RelativeStrengthRank]`: pure
  cross-sectional percentile ranking of ideas against each other (tie-averaged, single-holding-neutral).
  Ships as a standalone, fully-tested but completely UNWIRED utility — no multi-symbol backtest harness
  exists yet to validate whether it should influence ranking, so it influences nothing today.
- **`StockSageIndicators.timeframeConfluence(closes:dailyDirection:...)`** + `TradeAdvice.timeframeAligned`/
  `.confluenceNote` — three-timeframe (long/daily/short) trend-agreement read, computed in `advise()` as a
  pure POST-HOC observer of the already-resolved score (never fed back into it). Surfaced as a "3-TF
  confluence" badge on `ideaCard`; not wired into any ranking comparator (a separate, explicit
  owner-sign-off decision, same bar as `bestOpportunity`'s `preferVelocity` opt-in below).
- **`StockSageExpectedValue.bestOpportunity(..., preferVelocity:, holds:)`** — opt-in (default `false`,
  byte-identical) alternate ranking: EV/day instead of quality-adjusted EV, with a conviction tie-break.
- **`StockSageCapitalAllocator.rebalanceToEdge(...)`** — EV-weighted whole-book reweight (distinct from
  the existing risk-parity rebalance): trims/grows held names by positive buy-family `evR`, correlation-
  gates brand-new entries, closed-form churn-caps new-idea share. Returns `EdgeRebalancePlan`.
- **`StockSageTodayPlan.rankedActions`/`copyAllText`** + `MarketsTodayActionsCard` — top-N fast-lane setups
  collapsed to one sized+gated row each (`StockSagePositionSizer` + `StockSageTradeGate`), wired into
  `MarketsView` below `fastLaneStrip`.
- **`StockSageExpectedValue.momentumQuality`/`rankByVelocityWeighted`** — fast-lane re-rank by
  velocity × short-horizon momentum quality (Kaufman efficiency ratio + MACD + 21-bar return). Engine
  shipped and tested; the UI "momentum dot" is a deferred follow-up (needs a cached-closes field on
  `StockSageIdea`).
- **`StockSageExpectedValue.fastLaneByClass`/`cryptoRotationDominant`/`laneCorrelation`** — crypto vs
  equity fast-lane board split + live cross-group correlation, wired into `fastLaneStrip`'s
  `Both/Crypto/Equities` picker.

## 12. StockSage — 2026-07-03 merges (crypto-risk trio · refuse-list · net-cost gate · calibration fix)

Five merges landed on `main` overnight 2026-07-02→03. `DEVELOPMENT_LOG.md` is the chronological record
and `SOURCE_BUNDLE.md` the authoritative full source; this entry catalogs what a single-file reader would
otherwise miss. All modules below are pure/deterministic and honesty-floor-bound (labeled estimates, never
quotes; `nil`=unknown; gross vs net always distinguished).

**Fenced anti-edges (the refuse-list)**
- **`StockSageRefuseList.swift`** — `enum StockSageRefuseList` + `RefusedSetup`: "the coded refuse-list
  (research refuse-list items 1–7, verbatim substance)" from `RESEARCH_2026-07-02_week_horizon_velocity.md` —
  naive standalone reversal, standalone PEAD, ~90%-turnover rotation, overnight/intraday round-trip harvesting,
  crypto funding-seasonality timing, anomaly-in-illiquid-names. `mcLeanPontiffDecay` holds the #7 decay-haircut
  policy constants "for future ablations, not runtime multipliers — nothing in production math reads these."

**Crypto-risk trio + tier-aware cost (CRYPTO_RISK #1–4)**
- **`StockSageNetEdge`** — tier-aware crypto round-trip cost estimate (CRYPTO_RISK #1, `// MARK: - Tier-aware
  crypto round-trip cost estimate` ~line 143): richer than the flat 70 bps default that "treats BTC and a
  microcap alt identically." (The dead double-charging `allInCost` was deleted this session — D-2.)
- **`StockSageCryptoLiquidityGate.swift`** (`CryptoLiquidityGate`, #3) — ADV$ floor/ceiling; below the floor a
  name is "skip" (unfillable at advisor size), between floor and ceiling → resting limits, sized down.
- **`StockSageCryptoHonesty.swift`** (`CryptoNetEdgeHonesty`, #2) — pure net-edge verdict classifier composed
  over `StockSageBacktester.run` + the gate; a `thinNote` from the liquidity gate "forces 'unproven' regardless
  of the R numbers."
- **`StockSageCryptoFunding.swift`** (`CryptoFundingDrag`, #4) — perp funding drag in R (`dailyFunding =
  annualBps/10 000/365`); estimate band ≈3–30% APR, "can be NEGATIVE; owner-tunable, never a quote" (no
  live/paid funding feed exists in the app).

**Net-of-cost simulation gate**
- **`StockSageNetCostSim.swift`** — deterministic walk-forward (purge/embargo) harness for the IRRX reversal
  overlay (week-horizon roadmap item 3): industry-relative earnings-excluded reversal weights → round-trip cost
  netting (per-side cost accounting, revised in review) → `StockSageDeflatedSharpe` verdict. Honest result on
  its fixtures: the overlay does **NOT** clear net-of-cost (`clearsNetOfCost=false`), matching "58 bps/mo gross,
  net unproven." Runs on caller-supplied return panels; not wired into production ranking.

**Calibration honesty fix (D-1/D-1b)**
- **`StockSageConvictionCalibration`** — the Beta drop-and-refit branches (`.dropA`/`.dropB`) now re-anchor the
  intercept to the intercept-only MLE when the surviving slope clamps to 0, so a monotonicity-violating sample
  yields the honest base rate instead of a flat OVERSTATED `σ(c)`. (Fix of an audit finding; red-first fixtures.)

**Risk & display honesty**
- **`StockSageGapRisk.swift`** — `enum StockSageGapRisk` + `GapRiskScenario`/`TradeSide`: `scenario`/`worstCase`/
  `fromPosition` overnight-gap loss, long/short aware.
- **`StockSageLossLimit.swift`** — `LossLimitPolicy`/`LossLimitState` daily-loss halt with a fail-closed
  missing-data window.
- **`Views/MarketsView.swift`** — `BacktestVerdict.metricColor(positive:significant:)` gates the verdict COLOR
  (not just the caption) on statistical significance — "an insignificant sample renders these NEUTRAL," never
  green (AUDIT_FINDINGS_2 #1).

**Staged / unmerged (NOT on main — do not describe as shipped):**
- *(2026-07-09 truth pass: this section's two former entries both RESOLVED — kept here as pointers.)*
  The universe-1024 plan was SUPERSEDED (the analyzed universe has been the equity-2000 promotion's
  ~2,420 names since 2026-07-08 — now **2,418 all-verified** after the 2026-07-09 dead-symbol
  removals ROG.SW + SQ; the 1,024 verified manifest shipped as a research artifact only:
  `research/UNIVERSE_VERIFIED_2026-07-03.md`, plan marked DO-NOT-IMPLEMENT). The ux-wave-2
  branch merged 2026-07-07 (a45ebac) after owner release + visual QA. Nothing is currently
  staged/unmerged.

**2026-07-09 state changes an external reader needs (detail: DEVELOPMENT_LOG.md entries of that date):**
- **Owner-gate class RETIRED** (verbatim directive in `skills/gated-scope/SKILL.md` §1) — decisions
  resolve on evidence through the pipeline; honesty floor + empirical-validation bar unchanged.
- **TOM seasonal rank tilt** owner-activated then RATIFIED KEEP with a powered multi-year NULL in
  hand (lane closed); tilt is direction-aware, |t|<1 noise-gated, and DISCLOSED on every crowned
  surface (`MoneyVelocityCopy.tomTiltSuffix`).
- **Cost table re-ratified** with a `.SR` Tadawul tier (60bps RT); weekly money headlines are
  NET-FIRST with labeled gross; "est. costs" vocabulary unified.
- **All four whole-array persistence stores** (paper, journal, portfolio, velocity-history) now
  reconcile-on-save (cross-process lost-update fix, found from live data).
- **OPEN FRONTIER research rows closable on available data are ALL CLOSED** (full-IRRX with a
  populated earnings exclusion: NULL; TOM multi-year: NULL; cap-vs-continuous split: NULL) —
  the engine's measured value remains risk-discipline (DSR≈0 on every axis).

**Operating/discipline skill library:** `.claude/skills/` (19 skills) + `skills/` — durable session-operating
and discipline docs (opus-operating, gated-scope, incident-ledger, testing-discipline, ablation-harness,
money-campaign-map, stocksage-mental-model, …). Dev tooling, not app runtime.

## 13. `tools/stocksage_cli/` — query the real engine from any Claude chat (2026-07-04)

A **free** Swift CLI + thin Python MCP (`tools/stocksage_cli/`, OUTSIDE the app Xcode target — no app
build/runtime impact) that exposes the REAL StockSage engine by compiling the app's own PURE engine files
verbatim (**zero port risk** — no second copy of the math to drift, F46). Three tools:
- `netcost --entry E --stop S --target T --symbol SYM` → real `StockSageNetEdge`: net R:R, break-even
  win-rate `p*=1/(1+netRR)`, asset-class cost breakdown.
- `deflated-sharpe --returns "…" [--trials N] [--var-trial-sharpe X]` → real `StockSageDeflatedSharpe`:
  Sharpe/PSR/DSR, `passesDSRbar`=DSR>0.95 (the honest "real edge" bar; trials≥2 applies the selection-bias haircut).
- `indicators --coin <coingecko-id> [--days N]` → fetches FREE CoinGecko daily closes (crypto only — the
  equity/Yahoo path stays throttled) and runs real `StockSageIndicators` (rsi/sma/tsMomentum/trendOK/
  efficiencyRatio/vol). `nil`=unknown (insufficient history), never fabricated.
`build.sh` compiles; `check.sh` verifies against hand-derivations; `setup_mcp.sh` creates a venv (system
python is PEP-668) and registers the MCP. Honesty floor carried verbatim ("no proven edge, DSR≈0"). The MCP
runs from a dedicated worktree `/Users/saleh/ai-mcp`. Dev/analysis tool, NOT app runtime; never for advice.

