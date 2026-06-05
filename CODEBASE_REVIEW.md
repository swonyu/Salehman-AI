# 🔬 Codebase Review — Salehman AI

> Generated 2026-06-06 from a multi-agent review (11 subsystems · 47 agents · adversarially verified). **Read-only analysis** — no source was modified. Covers: performance, security/correctness, implementation review, architecture explanation, a refactor plan, and a test plan. Confirmed = survived an independent skeptic verifier (≥0.6 confidence).

**Status note:** the working tree was red at review time (the other session's in-progress Unsloth Studio). Fixes below are **proposed, not applied**; they'll be applied once the tree is green and per the lane rules in `COORDINATION.md`. Several findings extend the 2026-06-06 privacy/a11y audit logged in `DEVELOPMENT_LOG.md`.

---

## Executive summary
Salehman AI is a structurally healthy, feature-rich macOS app whose biggest risks are concentrated in a few well-defined seams rather than spread thinly. The dominant theme is duplication-driven drift: the brain-routing ladder is re-implemented three times across eight parallel lists, cloud clients hand-roll the same SSE/error boilerplate, web-access and command-risk gates exist in three divergent copies, and persistence/card-chrome/locale strings are copy-pasted across stores and views. That drift has already produced real defects — most severely a live-transcription engine that stops after one utterance, an Offline-mode web leak, a self-improve backup that overwrites the original it promises to preserve, and a Copilot client that hides real auth failures behind a generic "no brain" message. Performance hot spots are real but localized: unthrottled per-token Markdown re-parsing (O(n^2) on the main thread during streaming) and ~25 synchronous Keychain syscalls per Settings body recompute are the two that users actually feel. Test coverage is strong on pure predicates (caps, cooldowns, complexity, SSRF) but absent on the highest-blast-radius code: SelfImprove patch/path logic, the shell denylist, Knowledge RAG chunk/search, persistence round-trips, and the FM web-tool offline gate — largely because stores and view logic aren't structured for injection. Prioritize the four confirmed correctness bugs and the two streaming/Keychain perf fixes first, then attack the routing-ladder and gate duplication that is the root cause of the drift class.

---

## 1. Performance — ranked optimizations
*Each verified to sit on a genuinely hot path (per-token / per-frame / large-N), not a one-off.*

### P1. Throttle streaming UI updates to ~15-20 Hz instead of re-parsing Markdown every token
- **Where:** `Salehman AI/Agents/AgentPipeline.swift (stream, ~line 51, 212); Salehman AI/Views/ContentView.swift (StreamingBubble ~743-748, 1347-1363)`
- **Impact:** Eliminates O(n^2) main-thread Markdown parsing during every reply. MissionProgress.stream currently writes @Published streamingAnswer on every token (line 51 stores text verbatim), re-running MarkdownText.segments over the whole cumulative string each time. This is the single most user-visible jank source on long answers.
- **Fix:** Coalesce writes in MissionProgress.stream against a stored lastStreamPush Date (or a small repeating Timer publishing the latest buffered partial). Keep onUpdate firing per token; rate-limit only the @Published write to ~15-20 Hz.

### P2. Cache cloud-brain configured flags so brainReady() does zero Keychain syscalls
- **Where:** `Salehman AI/Views/SettingsView.swift:435-478 (brainReady), 19-67 (existing @State flags)`
- **Impact:** Collapses ~25+ synchronous SecItemCopyMatching calls per Settings body pass to zero. brainReady is called once per visible grid cell; .ensemble alone fires ~10 live hasKey()/isConfigured/isAuthed() reads and .freeAuto ~5 more, and body recomputes on every 5s Ollama poll tick and every keystroke. The cached @State Bools (grokKeySaved, geminiKeySaved, copilotAuthed, etc.) already exist but brainReady ignores them.
- **Fix:** Have brainReady read the existing cached @State Bools instead of calling the live Keychain accessors. Refresh those flags in the same .task poll loop and after every Save/Clear (the pattern at line 930 already does this for grokKeySaved).

### P3. Skip adaptTitles cosmetic LLM generation on serial local brains
- **Where:** `Salehman AI/Agents/AgentPipeline.swift:143-148, 384-409`
- **Impact:** Removes an entire extra LocalLLM.generate(maxTokens:300) call per multi-agent run that only renames UI step labels. On Ollama/MLX brains (effectiveCap forces serial inference) it directly delays the user's real answer by contending for the single model server; on paid cloud brains it is an extra billed request per message.
- **Fix:** Gate adaptTitles behind a default-off setting or skip it entirely when brain == .ollamaCoder/.salehman/.unslothStudio so it never contends with the serial inference queue. At minimum derive a static specialty label instead.

### P4. Bound and single-pass stripHTML before truncation
- **Where:** `Salehman AI/Tools/WebTools.swift:142-154`
- **Impact:** stripHTML runs six full-document regex passes (script/style/head/nav/footer + tag strip) with .dotMatchesLineSeparators over the entire multi-hundred-KB fetched page, even though only the first 8000 chars of the result are kept. A malformed tag from a hostile page can drive heavy .*? backtracking.
- **Fix:** Truncate raw HTML to ~200KB before stripping, combine the block removals into one alternation pass, and compile the NSRegularExpression once as a static instead of rebuilding per fetch.

### P5. Build CommandPalette command list once with stable identity
- **Where:** `Salehman AI/Views/CommandPalette.swift:15-54`
- **Impact:** commands is a computed property assigning Command.id = UUID() at init, so every keystroke rebuilds ~17 structs with fresh UUIDs. ForEach sees a new identity set each keystroke, tearing down/rebuilding every row instead of diffing, and breaking hover highlight (hoveredID can never match a freshly-generated id).
- **Fix:** Make commands a stored let (built once) or make Command Identifiable on a stable String key (the title) instead of a fresh UUID, so filtered only filters a stable array.

---

## 2. Correctness & security — confirmed findings
*All adversarially verified against source.*

### C1. [HIGH] LiveTranscriber stops permanently after the first finalized segment
- **Where:** `Salehman AI/Salehman AI/Media/LiveTranscriber.swift:227-240`
- **Fix:** Confirmed in source: commit() calls teardownTasks() (line 230) which sets capturing=false, so the guard capturing at line 238 always returns before startTasks() (line 239) is reached; restart() (243) also guards on capturing and can't recover. After one final SFSpeech result, recs is empty and every subsequent audio buffer is dropped at the line 267 guard. Fix: don't call full teardownTasks() from commit(); end/cancel just the current requests+tasks and clear partials without flipping capturing, or capture let wasCapturing=capturing before teardown and re-arm with if wasCapturing { capturing=true; startTasks() }.

### C2. [HIGH] FM web tools ignore Offline mode (divergent gate from Ollama path)
- **Where:** `Salehman AI/Tools/WebTools.swift:208,226`
- **Fix:** Confirmed: WebSearchTool.call (line 208) and FetchURLTool.call (line 226) gate only on AppSettings.boolDefaultTrue(webAccess); they never consult isOfflineOnly, while the Ollama executor gates on ToolPolicy.isExternalAllowed. A LanguageModelSession built while online keeps these tools in its schema and the tool's own guard lets the network call through after the user enables Offline mode. Fix: change both guards to consult ToolPolicy.isExternalAllowed (or add && !AppSettings.isOfflineOnly) so the executor-level gate matches the Ollama path regardless of when the session was built.

### C3. [HIGH] SelfImprove backup folder is shared for the whole process and backups overwrite each other
- **Where:** `Salehman AI/Salehman AI/Agents/SelfImprove.swift:277-293`
- **Fix:** Confirmed: backupTimestamp is a static let frozen once per process (line 277), and backup() writes every file to the same backupDir with dest keyed only on lastPathComponent (lines 289-291). Patching the same file twice in one run (common after a failed no-progress iteration) overwrites the iteration-1 backup, so the original pre-edit contents are lost — defeating the documented recovery guarantee. Fix: make the timestamp per-invocation (thread a run-id/Date into selfImprove → backup) and never overwrite an existing backup for a file (skip the copy if a backup exists, or suffix with the iteration number).

### C4. [MEDIUM] Reasoning Strategist (tools) agent discards all conversation history and prior-agent context
- **Where:** `Salehman AI/Salehman AI/Agents/AgentRegistry.swift:55-57`
- **Fix:** Confirmed: the usesTools handler returns await LocalLLM.chat(input.mission) (line 57), passing only the raw mission and ignoring input.history (rolling transcript + recalled memories) and input.context (phase framing). The one agent that runs terminal commands is the only one blind to prior turns, so follow-ups like 'now do the same for the other folder' lose the antecedent (cloud brains go single-turn here regardless). Fix: prepend input.history and the memory-recall block to the message, or add a history parameter to chat().

### C5. [MEDIUM] CopilotClient returns nil on non-200 for both streaming and non-streaming, hiding the real failure
- **Where:** `Salehman AI/LLM/CopilotClient.swift:158,179-184`
- **Fix:** Confirmed: the streaming branch (line 158) and non-streaming branch (lines 179-184) both return nil on any non-200, with no error diagnostic. A lapsed Copilot subscription (403), expired token, or transient 429 all surface as the generic offMessage ('sign in / no brain reachable') and are indistinguishable from each other. Fix: add a Copilot errorText(data:status:) (OpenAI error shape) and return it on non-200 in both branches so isUsableFreeAnswer and the UI see a real reason.

### C6. [MEDIUM] CommandApprovalCenter.looksRisky (the session-bypass re-confirm gate) is untested and lets destructive shapes through
- **Where:** `Salehman AI/Salehman AI/Tools/CommandApprovalCenter.swift:91-97`
- **Fix:** looksRisky decides which commands STILL re-confirm after 'Always run' (sessionBypass), yet is pure/static with zero tests. Its substring markers miss shapes Shell.isBlocked doesn't catch: the redirect marker is literally ' > ' with spaces, so echo x>file runs silently under bypass; dd of=, curl | sh, git checkout -- ., npm publish, pip install also slip through. Fix: normalize whitespace before matching (treat >file and > file identically) and add a CommandApprovalCenterTests suite pinning both the true cases and the documented current limits so any change is conscious.

---

## 3. Refactor plan — highest-leverage maintainability moves
*The review's dominant theme is duplication-driven drift; these target the root causes.*

### R1. Replace the three copies of the brain-routing ladder with one BrainAdapter registry
- **Files:** Salehman AI/LLM/LocalLLM.swift (generate 795-886, generateStreaming 927-1079, chat 1084-1209) + currentBrain/anyBrainReachable/freeAuto+ensemble rosters
- **Why:** This is the single biggest maintainability hazard. generate/generateStreaming/chat each re-implement the identical freeAuto→ensemble→claude→grok→...→local cascade, and adding one provider means editing eight+ parallel lists in lockstep. Introduce a BrainAdapter protocol (chat, chatStream, isConfigured, displayLabel, dotColor, isFree, isPaid) and one ordered [BrainPreference: BrainAdapter] registry; the three entry points become one generic dispatch and ensemble/freeAuto/anyBrainReachable iterate registry.values.filter(\.isConfigured). This also creates the injection seam needed to finally unit-test routing/privacy invariants.

### R2. Centralize the web-access gate and the command-risk vocabulary into single sources of truth
- **Files:** Salehman AI/Tools/WebTools.swift (gates at 208,226); Salehman AI/LLM/LocalLLM.swift (Ollama executor ~732,736); Salehman AI/Tools/ShellTool.swift (blockedSubstrings/blockedCommands); Salehman AI/Tools/CommandApprovalCenter.swift (looksRisky)
- **Why:** The web gate lives in three places that already disagree (the Offline-mode high-sev bug is a direct consequence), and the blocked-vs-risky command keywords live in three overlapping-but-inconsistent lists. Add a ToolPolicy.webToolsDisabledReason() -> String? consulting both webAccess and isOfflineOnly, used by all three call sites, and a single command-risk namespace with named constants documenting blocked ⊂ refused and risky ⊂ re-confirm-under-bypass. Kills the divergence class behind two confirmed/likely security gaps.

### R3. Fold OpenAI-shape cloud clients together and extract the shared SSE line-reader
- **Files:** Salehman AI/LLM/GrokClient.swift, Salehman AI/LLM/OpenAICompatibleClient.swift, Salehman AI/LLM/AnthropicClient.swift, Salehman AI/LLM/CopilotClient.swift
- **Why:** GrokClient is a near-line-for-line duplicate of OpenAICompatibleClient and qualifies to be a config of it; Anthropic and Copilot each re-hand-roll the data:/[DONE] SSE loop and the non-200 error path — which is precisely why the CopilotClient non-200-returns-nil inconsistency exists. Fold Grok into OpenAICompatibleClient and extract a shared SSE reader (prefix strip + [DONE] + per-chunk decode closure) so the streaming-error contract is implemented once and the bespoke clients supply only their delta decoder.

### R4. Introduce a JSONFileStore helper with an injectable base directory for all persistent stores
- **Files:** Salehman AI/Salehman AI/Persistence/MemoryStore.swift, Salehman AI/Salehman AI/Persistence/ScratchpadStore.swift, Salehman AI/Salehman AI/Persistence/PromptLibrary.swift, Salehman AI/Salehman AI/Knowledge/KnowledgeStore.swift
- **Why:** All four stores hand-roll the same appSupport/SalehmanAI/<name>.json + createDirectory + atomic-write boilerplate, with a latent crash (.first ?? temp vs [0]) drift, and a hard-coded private fileURL that makes them untestable singletons — the structural reason persistence has 0% coverage. A JSONFileStore<T: Codable> owning the URL, atomic write, and decode-or-default, parameterized by an injectable base dir (default Application Support), standardizes safety and unblocks the entire stores test plan. Also extract the duplicated embed()/cosine() into one Embeddings helper while here (fixes MemoryStore's missing empty-array guard).

### R5. Extract a ChatViewModel and consolidate AppSettings observation
- **Files:** Salehman AI/Views/ContentView.swift (1480-line file: send/regenerate/transcribe + ChatStore + ChatExporter); Salehman AI/App/AppSettings.swift (~28 @Published props)
- **Why:** ContentView buries non-trivial send/regenerate/transcribe business logic inside the View, making it untestable without UI, and observes the whole ~28-property AppSettings wholesale so flipping autoSpeak or editing a cloud model id invalidates the chat transcript body. Extract a @MainActor @Observable ChatViewModel (messages/isRunning/send/regenerate/stop) and either migrate AppSettings to @Observable for per-property tracking or split the rarely-changing provider-model-id cluster into its own CloudModelSettings object only SettingsView observes. Unblocks the chat-orchestration and grouping test suites.

---

## 4. Test plan — highest-value missing suites
*Coverage is strong on pure predicates, absent on high-blast-radius logic. Concrete case names below.*

### SelfImprovePatchTests
- **Target:** `Salehman AI/Salehman AI/Agents/SelfImprove.swift (applyPatch, parseErrors, isInsideProject, backup)`
- **Cases:**
  - Valid single-line patch REPLACE_RANGE: 42-42 rewrites only that line and backs up first
  - Out-of-bounds range (end>lineCount, start<1, end<start) returns false and does NOT modify the file
  - Malformed patch missing WITH or END returns false; a body containing the literal token END is handled by the backwards match without truncating valid content
  - parseErrors: 'file.swift:42:10: error: msg' parses file/line/col; 'file.swift:42: error: msg' parses with col==nil; duplicate identical errors collapse preserving order; warnings/note: lines are ignored
  - isInsideProject: file under root → true; sibling '<root>-evil/x.swift' → false (the '/' boundary); a ../ escape and a symlink pointing outside the root → false after canonicalization
  - backup: patching the same file twice in one run preserves the ORIGINAL pre-edit contents (locks the confirmed overwrite fix)

### LiveTranscriberSegmentTests
- **Target:** `Salehman AI/Salehman AI/Media/LiveTranscriber.swift (commit, bestPartial, segment recycle)`
- **Cases:**
  - After a commit(), startTasks() runs and recs is repopulated while capturing is still true (currently FAILS — pins the high-sev recycle bug)
  - Feeding two final results produces two segments / two startTasks() arms
  - bestPartial returns the longest of multiple LangRec partials and '' when recs is empty
  - A recognition callback whose segmentAtStart != current segment is ignored (staleness guard); publishPartial throttles to <=~9 Hz and only on changed text

### WebToolsOfflineGateTests
- **Target:** `Salehman AI/Tools/WebTools.swift (WebSearchTool.call, FetchURLTool.call, decodeDDG, stripHTML)`
- **Cases:**
  - offlineOnly=true, webAccess=true: WebSearchTool().call returns a refusal and does NOT hit the network (locks the confirmed Offline leak fix)
  - offlineOnly=true: FetchURLTool().call returns a refusal
  - webAccess=false: both FM tools refuse (pins existing guard)
  - decodeDDG unwraps //duckduckgo.com/l/?uddg=ENCODED&rut=... to the percent-decoded target and passes a bare //host through as https://host
  - stripHTML removes script/style/head/nav/footer blocks, collapses tags to spaces, decodes &amp;/&lt;/&#39;/&nbsp;, and caps work to the truncation bound

### ShellSecurityTests
- **Target:** `Salehman AI/Tools/ShellTool.swift (isBlocked, run) + Salehman AI/Salehman AI/Tools/CommandApprovalCenter.swift (looksRisky, requestApproval)`
- **Cases:**
  - isBlocked refuses 'rm -rf /', chained 'echo hi; rm -rf /', '/sbin/reboot' (path-prefix strip), and 'X="rm -rf /"; eval $X' (eval); allows 'ls -la' and 'sw_vers' (no false positives)
  - run with >200000 chars of output returns truncated output with the 8KB marker and does not hang; run('sleep 5', timeout:1) returns timedOut=true with a terminated process; run('true') returns exitCode 0
  - looksRisky true for 'rm foo','git push','sudo x','kill 123','git reset --hard'; false for 'ls'/'cat file'
  - looksRisky documents current limits: 'echo x>file' is currently NON-risky (pin until whitespace-normalization lands); a risky command under sessionBypass still creates a pending approval (does not auto-return true)

### KnowledgeRAGTests
- **Target:** `Salehman AI/Salehman AI/Knowledge/KnowledgeStore.swift (chunk, keywordScore, cosine, search)`
- **Cases:**
  - chunk: empty/whitespace returns []; input shorter than size returns one trimmed chunk; length 2*size yields overlapping chunks whose union covers all non-whitespace text with ~overlap on a whitespace boundary; a single token > size still terminates
  - keywordScore: terms <3 chars ignored; 2-of-3 distinct terms present → 0.666…; empty query → 0
  - cosine: identical → 1, orthogonal → 0, mismatched lengths → 0, zero-magnitude → 0 (no NaN)
  - search: returns at most k hits all with score>0 ordered descending; search(inDocument:) returns only that doc's chunks; empty store returns []

### BrainRoutingDispatchTests
- **Target:** `Salehman AI/LLM/LocalLLM.swift (generate/chat/generateStreaming via a fakeable BrainAdapter registry)`
- **Cases:**
  - Each pinned BrainPreference dispatches to exactly one adapter and returns its reply without trying others (no fall-through)
  - '.auto' and '.apple'/'.ollama' pins never invoke ANY cloud adapter (local-first privacy invariant)
  - Offline Mode forces every cloud pref to .none in currentBrain and excludes cloud adapters from the ensemble/freeAuto rosters
  - freeAuto includes only free providers and never a paid client (Anthropic/Grok/Codex/Copilot)

### PersistenceRoundTripTests
- **Target:** `Salehman AI/Salehman AI/Persistence/MemoryStore.swift, ScratchpadStore.swift; Salehman AI/Salehman AI/StockSage/StockSagePortfolio.swift (after injectable-base-dir refactor)`
- **Cases:**
  - MemoryStore.remember dedupes case-insensitively and no-ops on blank; recall returns keyword-fallback hits when no embedding is available and caps at k; recall on empty store returns []
  - ScratchpadStore.completeTask matches the first open task by case-insensitive substring and returns true, returns false when none match, and does not re-complete a done task; Snapshot encode→decode preserves order/ids
  - StockSagePortfolio.add no-ops on blank symbol / shares<=0 / negative costBasis and trims+uppercases on valid add; encode→decode into a fresh store asserts equality and that remove/clear persist

### SettingsBrainReadyTests
- **Target:** `Salehman AI/Views/SettingsView.swift (brainReady, testActiveBrain classification, anthropicSubtitle)`
- **Cases:**
  - freeAuto returns true when only a free cloud key is present and false when only a paid key (Anthropic/Grok/Codex/Copilot) is present
  - auto returns true for (apple+useAppleIntelligence) alone and for (ollamaUp+hasCoder) alone, false when neither; salehman false when customModelName empty even with ollamaUp
  - A superseded testActiveBrain run (pinned no longer matches) does NOT write activeBrainWorking AND still clears activeBrainTesting; replies equal to offMessage / empty / prefixed '[Claude Haiku' classify as not-working while a normal '[' JSON reply classifies as working
  - anthropicSubtitle: a non-sk-ant key echoes only 'sk-…' (never real prefix bytes) and returns .orange — locks the no-secret-leak guarantee

---

## 5. Architecture — how each subsystem works
*Plain-English explanation per subsystem (the documentation deliverable).*

### brain (LLM layer: LocalLLM routing, cloud clients, Ollama, MLX engine, Keychain, BrainStatus, MemoryManager, persona)
The `LLM/` directory is the "brain" layer: it decides WHICH model answers a prompt and talks to each one over HTTP (or on-device).

Core router — `LocalLLM` (an `enum` namespace, all `nonisolated static`): every chat/agent call enters through `generate`, `generateStreaming`, or `chat`. It reads the user's `BrainPreference` (`AppSettings.brainPreferenceCurrent`) and routes to exactly one brain, or to a fan-out mode. Brains: `.apple` (Apple Intelligence via FoundationModels), `.ollama` (local qwen2.5-coder), `.salehman` (the brand persona, backed by MLX-Swift → custom Ollama model → Apple Intelligence in that order), `.unslothStudio` (any local OpenAI-compatible server), and the cloud pins `.claudeHaiku/.grok/.gemini/.groq/.mistral/.cerebras/.codex/.copilot/.openRouter`. Two orchestration modes: `.ensemble` ("All Brains at Once" — fan out to every reachable brain, join into one labeled markdown doc) and `.freeAuto` (race the configured FREE cloud brains, first usable reply wins, local backstop if all fail). Design invariants: `.auto` is strictly local-first (never silently spends on cloud); cloud pins are strict (no silent fallback); `offMessage` is a `let` sentinel used for `==` equality checks while `unavailableMessage` is the display-only context-aware variant; `generateOnDevice` is the privacy-promise path that runs ONLY local brains (Apple → Ollama → loopback-only Unsloth Studio).

Cloud clients: most providers speak the OpenAI `/v1/chat/completions` wire format, so `OpenAICompatibleClient` is a single parameterized struct that Groq/Mistral/Cerebras/OpenRouter/OpenAI (`CloudBrains.swift`, `OpenAIClient.swift`, `UnslothStudio.swift`) configure in ~20 lines each. `GrokClient` mirrors that surface as a standalone enum. `GeminiClient` is bespoke (Google's non-OpenAI shape, `?key=` auth, array-wrapped SSE). `AnthropicClient` is bespoke (Messages API, `x-api-key`, prompt-cache on the system block). `CopilotClient` is bespoke (GitHub device-flow OAuth via the `CopilotAuth` actor → short-lived Copilot token + integration headers). Every client exposes `chat`/`chatStream`/`hasKey`/`testConnection` and (by convention) returns a bracketed `[Provider error STATUS: msg]` string on HTTP errors so the failure surfaces in chat; `nil` is reserved for "couldn't reach the server."

Supporting pieces: `OllamaClient` (local server probe with a 30s reachability/model-list cache `actor`, tool-calling `/api/chat` turn parser, KV-cache/keep-alive tuning, model eviction); `KeychainStore` (the ONLY place key material lives — per-account generic-password items); `BrainStatus` (`@MainActor ObservableObject` polled every 10s + on settings changes, drives the header dot/label); `MemoryManager` (`actor` subscribing to memory-pressure + thermal signals, deriving a pure `concurrencyLimit`/`shouldRefuseHeavyModel` policy and auto-evicting Ollama under pressure); `MLXSalehmanEngine` (`actor` wrapping MLX-Swift for truly-standalone on-device inference, compiles to a stub until the package is linked); `SalehmanPersona` (the brand system prompt). The free-auto race uses the `FreeAutoCooldown` actor to skip brains that failed within a 120s window.

### agents
The agents subsystem implements Salehman AI's multi-agent pipeline plus a self-improvement loop. Entry point is `Orchestrator.runAndReturnResult(mission:)` (Orchestrator.swift), which delegates to `AgentPipeline.run(mission:)` and then reads back a single global `AgentPipeline.lastOutcome` for a success rating (0/1).

AgentPipeline.run is the core. It (1) bails with `LocalLLM.offMessage` if no brain is reachable; (2) short-circuits ensemble and free-auto modes to `LocalLLM.generateEnsemble/generateFreeAuto` (these bypass the team entirely); (3) otherwise selects how many agents run from a 2-axis decision: a pure text-heuristic `complexity(of:)` tier (.simple/.moderate/.hard) crossed with the user's `responseMode` ceiling (.fast/.balanced/.full). Only (.hard, .full) unlocks the full 15-agent team from `AgentDefinitions.pipeline`; otherwise it runs just the tools agent ("Reasoning Strategist") or that plus the streamed final agent. `isTrivialMission`/`complexity` are pure, nonisolated, and unit-tested (TrivialMissionTests.swift).

The 15 agents are grouped into phases (0..4). Phases run sequentially; agents within a phase run concurrently via `withTaskGroup`, batched by a RAM-aware `MemoryManager.concurrencyLimit()` that `effectiveCap(brain:baseCap:)` forces to 1 for single-instance local servers (ollamaCoder/salehman/unslothStudio) to avoid shared RAM/VRAM OOM (AgentPipelineConcurrencyTests.swift locks this). Each agent's handler is looked up in `AgentRegistry` (a write-once `[String: AgentHandler]` populated by a `static let registerToken` for race-free init); the registered handler calls `LocalLLM.chat` (tools agent), `LocalLLM.generateStreaming` (final agent, streams partials into `MissionProgress.shared.streamingAnswer`), or `LocalLLM.generate` (others). Outputs are folded into a `MissionMemory` value (MissionMemory.swift) wrapping a `MissionPlan`; `buildContext(for:)` re-serializes accumulated tool results + prior agent outputs (each capped 800 chars) as the next phase's prompt context. Live UI state lives in `MissionProgress` (ObservableObject singleton) consumed by AgentsView/ContentView. A rolling 8-turn `ConversationStore` actor supplies cross-turn history.

SelfImprove.swift is a separate self-coding loop: runs `xcodebuild build|test`, regex-parses compiler errors (`parseErrors`), asks the on-device model for a `REPLACE_RANGE/WITH/END` patch per error (max 5/iter, up to 3 iters, stops on no-progress), and applies it via `applyPatch` after a backup. `isInsideProject` canonicalizes through symlinks to refuse writes outside the project root. Exposed to Apple FoundationModels as `SelfImproveTool`.

### tools
The tools subsystem exposes on-device capabilities to the assistant brains (both Apple Foundation Models and the local Ollama qwen loop) as callable tools, with security gating layered on top.

Key components:
- Shell.swift (ShellTool): `Shell.runApproved(_:)` is the single gated entry point shared by both brains. It (1) refuses obviously destructive commands via `isBlocked` (a substring denylist of dangerous operations/paths plus a token-aware denylist of command names checked per `;|&\n\r`-separated segment, with path-prefix stripping so `/sbin/reboot` is caught), (2) routes through `CommandApprovalCenter.requestApproval` for user consent, then (3) runs the command with `/bin/zsh -c` from the home directory under a 60s DispatchSource timeout, draining stdout/stderr concurrently via a readability handler into a lock-guarded `OutputCollector` so large output can't deadlock `waitUntilExit()`. Output is capped at 8KB. `RunTerminalCommandTool` is the Foundation Models wrapper.
- CommandApprovalCenter.swift: a `@MainActor ObservableObject` singleton that bridges background tool execution to the UI via a `Pending` continuation. Two distinct consents: `confirmationEnabled` (durable Settings preference, default ON) and `sessionBypass` ("Always run", in-memory, reset on `didResignActive`, never applied to `looksRisky` commands).
- WebTools.swift (Web): DuckDuckGo HTML search + page fetch with HTML stripping. `Web.fetch` runs an SSRF denylist (`ssrfRejectionReason`) rejecting non-http(s) schemes and loopback/private/link-local hosts (IPv4 + IPv6 literals + IPv4-mapped IPv6), and re-validates every redirect target via a `RedirectGuard` URLSession delegate plus the final resolved URL. `WebSearchTool`/`FetchURLTool` are the FM wrappers.
- ToolPolicy.swift: computes the active tool set and the instructions menu from user Settings (`webAccess`, `vision`, `codeModel`) and `isOfflineOnly`. `isExternalAllowed` is the master gate that web tools are added behind; offline mode is the strongest constraint.
- ScratchpadTool.swift / Knowledge tools (SearchDocumentsTool, GetDocumentTool, ListDocumentsTool): always-on local-core FM tools over `ScratchpadStore` and `KnowledgeStore`. `KnowledgeStore` is an NSLock-guarded `@unchecked Sendable` singleton doing keyword + optional NLEmbedding-cosine retrieval over chunked, on-device-persisted documents.

Data flow: a brain emits a tool call → the FM `Tool.call` or the Ollama executor switch dispatches it → shell calls funnel through `Shell.runApproved` (denylist → approval → run); web calls funnel through `Web.search`/`Web.fetch` (SSRF guard on fetch); knowledge/scratchpad calls hit the on-device stores. ToolPolicy decides which tools are even visible to the model.

### chat-ui
The chat-ui subsystem renders the primary conversation surface of Salehman AI (a native macOS SwiftUI app).

Files & roles:
- ContentView.swift (~1480 lines) is the chat screen. It owns conversation @State (`messages: [ChatMessage]`, `isRunning`, `attachment`, search/scroll state), composes header / conversation / inputBar, and drives the send pipeline. `send(_:)` builds the mission (resolving image vision first), kicks off `Orchestrator.runAndReturnResult`, and appends the assistant reply. `transcribeMedia` handles pasted YouTube/media URLs. `regenerate` re-runs the prior user turn. It also hosts modal sheets (Settings, Live transcription), the command-approval overlay, and menu-bar command bridges via AppState `*Requested` flags.
- Data/model layer in the same file: `ChatMessage` (Codable/Equatable), `ChatStore` (debounced + termination-flushed JSON persistence to Application Support), `ChatExporter` (Markdown copy/save).
- View components: `MessageBubble` (Apple-Messages-style grouped bubbles with asymmetric "tail" corners, avatars on the last message of a burst, hover/regenerate/copy/speak actions, fade-up entry animation), `StreamingBubble` (live answer), `RunningProgressView`/`AgentRunView`/`AgentRow` (multi-agent progress, isolating MissionProgress observation), `TypingIndicator`, `BrainStatusDot`, `ScrollToLatestButton`, `TimeSeparator`, `CachedImage`, `ApprovalCard`.
- MarkdownText.swift is a dependency-free Markdown renderer: splits fenced code blocks from prose (CodeBlock with copy button) and renders headings/bullets/numbered lists/blockquotes/rules. It memoizes parsed `[Segment]` and inline `AttributedString` in two static NSLock-guarded dictionaries (cap 200, bulk-evicted).
- RootView.swift is the tab container: ContentView stays mounted across tabs (kept via `.opacity`/`allowsHitTesting`) so in-flight tasks/streaming survive; other tabs are lazily mounted on first visit.
- TabSwitcherBar.swift is the frosted segmented tab bar with a matchedGeometryEffect sliding highlight, width-driven label collapsing, and a live market-status pill + Settings gear.
- BackgroundView.swift is the shared state-free gradient + `.drawingGroup()`-cached accent glows.

Data flow for a turn: user text → `send` → optional Ollama vision on image attachments → `Orchestrator.runAndReturnResult`. During the run, the final agent's streaming callback pushes cumulative text to `MissionProgress.shared.stream(_:)` on the MainActor; `RunningProgressView` observes `MissionProgress` (deliberately isolated from ContentView's body) and renders `StreamingBubble`, which re-renders MarkdownText each update. On completion the reply is appended to `messages`, which triggers debounced persistence and gated auto-scroll. Auto-scroll uses a 1pt invisible bottom sentinel to track `atBottom` and a floating "N new" pill when scrolled up.

### settings-ui
The settings-ui subsystem is two SwiftUI views under Salehman AI/Views/.

SettingsView.swift (~1530 lines) is the app's single Settings sheet (560x640, dark, presented as a sheet). It is the configuration surface for every brain, capability, voice, and privacy toggle. Structure:
- State: `@ObservedObject AppSettings.shared` and `CommandApprovalCenter.shared`, plus ~40 `@State` vars. The cloud-key vars follow a strict convention: `<provider>KeyDraft` (what the user is typing right now), `<provider>KeySaved` (Bool initialized from a synchronous Keychain `hasKey()` at view-init), `<provider>Testing` (Bool spinner), and `<provider>TestStatus` (tri-state String?: nil = idle, "" = OK, non-empty = error message). The literal key only ever lives in the `…KeyDraft` @State while typing; on Save it is written to Keychain via KeychainStore and the draft is wiped. Two `@AppStorage` flags (`settings.showFreeKeys`, `settings.showPaidKeys`) persist the collapse state of the key groups.
- body: a ScrollView of `section(...)` cards — Intelligence, Brain (a LazyVGrid of `brainGridCell` cells, one per `BrainPreference.selectableCases`), Salehman engine (MLX standalone + custom-weights folder + Ollama model name), Unsloth Studio (local OpenAI-compat server), a `collapsibleGroup` of Free API keys (Gemini/Groq/Mistral/Cerebras/OpenRouter), Performance (ResponseMode rows), Capabilities, Voice, Privacy, and Status.
- Reusable helpers: generic `cloudKeyRow`/`cloudModelRow`/`cloudTestRow` take an `OpenAICompatibleClient` so Groq/Mistral/Cerebras/OpenRouter share one implementation; Grok, Gemini, and Anthropic have their own bespoke row triplets. `testStatusText`/`testStatusColor` centralize the tri-state presentation. `workingBadge` renders the spinner/✓/✗ for live "is it working" checks.
- Two polling loops drive live status: (1) a top-level `.task` re-polls Ollama (`isUp`, `hasModel(vision)`, `activeCodeModel`) every 5s and writes `ollamaUp`/`hasVision`/`hasCoder`; it also runs the active-brain test once on first appear for local brains. (2) `mlxEngineRow`'s `.task(id:"mlx-poll")` polls the MLXSalehmanEngine actor's `state` every 500ms (5s once `.ready`). An `.onChange(of: settings.brainPreference)` clears the stale verdict and re-tests local brains on switch.
- `brainReady(_:)` is the single source of truth for whether a brain's status dot is green; it reads the cached in-memory probe vars plus synchronous Keychain `hasKey()`/`isConfigured`/`isAuthed()` checks.
- `testActiveBrain()` pings the pinned brain through the real `LocalLLM.generate` path (or `anyBrainReachable()` for ensemble) and guards against overlapping runs by capturing `pinned` and only publishing if the pin still matches.

CopilotSignInView.swift (~86 lines) is the GitHub Copilot OAuth device-flow sheet: it requests a device code, displays the one-time user code with Copy/Open-GitHub buttons, opens the verification URL, and a `pollTask` polls `CopilotAuth.pollForToken` until authorized, then stores the token and calls `onSignedIn`. The poll task is cancelled on Cancel and on `.onDisappear`.

Data flow: user input → @State drafts → KeychainStore (secrets) or AppSettings/UserDefaults (preferences) → BrainStatus.shared.refresh() to update the header dot. Status flows the other way: background probes → polling `.task` → @State → `brainReady` → grid cell dots.

### feature-ui (Views/: Knowledge, Today, Scratchpad, Memory, VoiceMode, LiveTranscription, CommandPalette, Shortcuts, Onboarding, About, Markets)
This subsystem is the collection of secondary feature surfaces for the "Salehman AI" macOS app — every tab/sheet that isn't the main chat. All views are SwiftUI, MainActor-isolated, and styled exclusively through the `DS.*` design-system tokens (Palette/Space/Radius/Typography/Motion/Elevation). None of them own business logic; they are thin presentation layers bound to shared singleton stores.

Data flow and key types:
- KnowledgeView (+ private DocDetailSheet): a private on-device document vault. Reads/writes `KnowledgeStore.shared` (a `@unchecked Sendable`, non-ObservableObject store), ingests files via `AttachmentLoader`, and answers questions strictly via `LocalLLM.generateOnDevice` (returns nil rather than falling back to cloud — privacy contract). Embedding/search/generation are pushed off the main actor with `Task.detached`. An `inFlight` counter (not a Bool) tracks concurrent ingests so the spinner stays up until all drops finish.
- TodayView: glanceable dashboard. Observes `AppState.shared`, `ScratchpadStore.shared`, `MarketStore.shared`; caches `knowledgeCount` and refreshes it on appear / when its tab becomes active. Quick actions flip the same `AppState` edge-trigger flags the menu bar and Command Palette use. Private `ActionTile`/`StatTile` own their hover state.
- ScratchpadView: notes/tasks UI over `ScratchpadStore.shared` (an ObservableObject); a one-tap "Organize"/"Summarize" calls `LocalLLM.generate`.
- MemoryView: lists durable facts from `MemoryStore.shared` (non-ObservableObject; loaded into `@State` on appear), with search, copy, per-fact delete, and a confirm-gated clear-all.
- VoiceModeView: hands-free talk↔listen chrome bound to a `@StateObject VoiceSession`; can save the transcript to Notes.
- LiveTranscriptionView: live system-audio transcription bound to `LiveTranscriber.shared`; speaker bubbles with RTL detection for Arabic, autoscroll, search, copy, and "Summarize"/"Answer the questions" actions that hand a prompt back to chat via an `onAsk` closure. Footer honestly reports on-device vs cloud transcription.
- CommandPalette: ⌘K searchable action list; reads `AppState`/`AppSettings`, flips edge-trigger flags, and appends one "Switch brain" command per `BrainPreference.selectableCases`.
- ShortcutsView / AboutView / OnboardingView: static reference / identity / first-run sheets. AboutView reads version from Info.plist.
- MarketsView: the StockSage front-end with sections (watchlist/all/heatmap/portfolio/alerts/briefing). Pulls symbols from `StockSageStore.shared`, recommendations from the pure `StockSageSignalEngine`, holdings from `StockSagePortfolio.shared`, and alerts from `StockSageMonitor.shared`. Honestly flags sample data and shows a financial-advice disclaimer footer.

### stores (Persistence: MemoryStore, ScratchpadStore, PromptLibrary, Attachments; Knowledge: KnowledgeStore + 3 FoundationModels tools; ConversationStore; StockSageStore)
This subsystem holds all of Salehman AI's on-device persistent/working data. Each store is a singleton, all data lives in ~/Library/Application Support/SalehmanAI/*.json (one file per store), and nothing leaves the Mac.

MemoryStore (Persistence/MemoryStore.swift): long-term user facts. `@unchecked Sendable` final class guarded by an NSLock so the FoundationModels `RememberFactTool` can call it off the main actor. Each `MemoryItem` is {text, vector:[Double]?} where the vector is an on-device `NLEmbedding.sentenceEmbedding(.english)` sentence vector. `remember` dedups case-insensitively and appends; `recall(query,k)` embeds the query, cosine-ranks all items, keeps the top-k with score > 0.25, and falls back to a keyword-overlap scan when no embedding/match. Persisted by re-encoding the whole `[MemoryItem]` array to JSON on every mutation. Consumed by AgentPipeline.run (prepends recalled facts to the agent transcript) and by RememberFactTool (registered in Tools/ToolPolicy.swift).

KnowledgeStore (Knowledge/KnowledgeStore.swift): the private document vault, same `@unchecked Sendable`+NSLock pattern. Holds `docs:[KnowledgeDoc]` (metadata) and `chunks:[KnowledgeChunk]` ({docID, docName, ordinal, text, vector:[Double]?}). `addDocument` chunks fullText into ~800-char passages with 150-char overlap (`chunk`), embeds each (heavy work done before taking the lock), then inserts. `search(query,k,inDocument:)` scores every chunk = keywordScore (fraction of >=3-char query terms present) + cosine(queryVec, chunkVec), sorts, returns top-k with score>0. `text(forDocument:)` concatenates a doc's chunks in ordinal order, capped. Persisted as a {docs,chunks} Snapshot re-encoded on every mutation. Consumed by the three FoundationModels tools (search/list/get_document) and KnowledgeView (which correctly wraps the heavy calls in `Task.detached`).

ScratchpadStore (Persistence/ScratchpadStore.swift): `@MainActor ObservableObject` of notes + tasks, shared by the Notes/Today UI and the scratchpad FoundationModels tools (which `await`-hop to the main actor). Persisted as a {notes,tasks} Snapshot, encoded synchronously on the main actor on every mutation.

PromptLibrary (Persistence/PromptLibrary.swift): `@MainActor ObservableObject` list of reusable composer prompts, seeded with 4 starters on first run, JSON-persisted.

Attachments (Persistence/Attachments.swift): not a store — a stateless `AttachmentLoader` enum that turns a file URL into an Attachment by extracting text (Vision for images, PDFKit for PDFs, Transcriber for media, UTF-8/Latin-1 otherwise), plus screenshot helpers. Uses a `ResumeBox` (NSLock) to guarantee single continuation resume for OCR.

ConversationStore (in Agents/AgentPipeline.swift): an `actor` holding a rolling 8-turn transcript, each turn capped at 4000 chars.

StockSageStore (StockSage/StockSageStore.swift): `@MainActor ObservableObject` of tracked symbols. In-memory only (no persistence) and seeded with clearly-labeled SAMPLE data; `isSampleData` flips false when a real feed calls `replaceAll`.

### stocksage
StockSage is the Markets/signals subsystem, a de-SwiftData'd rework of an external "StockSage v32" package into plain value types + MainActor singletons. Data flow: StockSageStore (MainActor ObservableObject singleton, in-memory) holds [StockSageSymbol], each carrying a [StockSageQuote] history (price + previousPrice + time). It seeds a small, explicitly-flagged SAMPLE set (isSampleData=true) and exposes upsert/replaceAll so a future live feed (Chat A's Yahoo feed) can swap in real quotes with isSample:false; every downstream layer is data-source-agnostic.

StockSageSignalEngine is the one pure, deterministic core: it maps a percent move to a StockSageRecommendation (|Δ|>6% strong buy/sell, >2.5% buy/sell, else hold) with confidence = min(absChange/8, 0.92) (flat 0.65 for hold). It has both a primitive (currentPrice/previousPrice) and a convenience (for: StockSageSymbol, using its latest quote) entry point.

StockSageBriefingService.deterministicSummary builds a hallucination-free gainers/losers/tone string purely from the engine; generateBriefing wraps those facts in a prompt and routes them through LocalLLM.generateOnDevice (Apple Intelligence -> Ollama, on-device ONLY — never the pinned cloud brain, honoring the privacy promise), falling back verbatim to the deterministic text when no local model is reachable. StockSageBriefingTool exposes this to the assistant as the "market_briefing" Foundation Models tool and prefixes a "Sample data" warning when isSampleData.

StockSageMonitor is a cancellable MainActor polling loop (default 45s, doubled when MemoryManager.concurrencyLimit() <= 1 indicates memory/thermal pressure). Each runCycle derives a signal per stored symbol and fires a real UNUserNotificationCenter alert for strong buy/sell, accumulating fired tickers in a smartWatchlist set. StockSageScreenAnalysis captures the screen (AttachmentLoader.captureNow), sends it to on-device vision (OllamaClient.vision / qwen2.5vl), and supports grounded follow-ups via LocalLLM.generate over a capped rolling history. StockSagePortfolio is a tiny UserDefaults-backed (JSON) holdings record; value/P&L is computed by MarketsView against the store's latest prices (no price coupling in the store). MarketsView is the sole UI consumer, rendering watchlist/heatmap/portfolio/alerts/briefing sections.

### media-voice
The media-voice subsystem provides four speech/transcription capabilities, all built on Apple's Speech (SFSpeechRecognizer) and AVFoundation frameworks, plus a hands-free conversation loop.

Files & responsibilities:
- Media/LiveTranscriber.swift — A singleton (`LiveTranscriber.shared`, NSObject + ObservableObject + SCStreamDelegate/SCStreamOutput) that captures the Mac's SYSTEM audio via ScreenCaptureKit and transcribes it live. It configures an SCStream with `capturesAudio = true`, a tiny 128x72 video output (a no-op video output is required to keep the audio pipeline pumping), and `excludesCurrentProcessAudio = true`. Audio CMSampleBuffers arrive on a private serial `queue` ("salehman.live.audio"), are wrapped into AVAudioPCMBuffers in their native format (no resampling) and appended to one or more `SFSpeechAudioBufferRecognitionRequest`s. In "Auto" mode it runs an English and an Arabic recognizer in parallel and keeps the longest hypothesis (`bestPartial`). A `segment` counter guards stale recognition callbacks; partial results are throttled to ~9 Hz before publishing to `@Published partialThem`; finalized lines accumulate in `lines` (capped at 1,500). `isFullyOnDevice` is published so the UI footer can honestly state on-device vs cloud routing. All recognizer state (`recs`, `capturing`, `segment`, throttle gates) is queue-confined; @Published mutations hop to the main queue.

- Media/Transcriber.swift — A stateless enum for on-device transcription of audio/video FILES. Uses `SFSpeechURLRecognitionRequest`, extracts audio from video first via `AVAssetExportSession` (Apple M4A preset). Wraps the callback in a `ResumeBox` (resume-once guard) plus a `LockedString` (NSLock-protected) to capture the latest partial as a fallback, and a 600s timeout safety-net so the continuation never hangs.

- Media/MediaTranscribe.swift — Routes pasted strings: detects YouTube links (fetches the caption track over plain HTTP, parsing `captionTracks` JSON + the timed-text XML with NSRegularExpression, decoding HTML entities), direct media URLs (downloads then hands to Transcriber), and local file paths. Pure string/regex parsing, dependency-free.

- Media/SpeechIn.swift — A @MainActor singleton for live MICROPHONE dictation using AVAudioEngine's input tap feeding an SFSpeechAudioBufferRecognitionRequest. Publishes `transcript` and `isListening`.

- Media/SpeechOut.swift — A @MainActor singleton TTS wrapper around AVSpeechSynthesizer. Auto-detects Arabic vs English by scanning for Arabic script, honors a chosen voice ID / rate from AppSettings, and publishes `speakingID` (nil when idle). A nested NSObject Delegate hops to the main actor to clear `speakingID` on finish/cancel.

- Voice/VoiceSession.swift — A @MainActor ObservableObject driving the hands-free loop: listen -> 1.2s silence -> think (Orchestrator.runAndReturnResult) -> speak (SpeechOut) -> re-arm. It subscribes to `SpeechIn.$transcript` and `SpeechOut.$speakingID` via Combine, uses a cancellable `silenceTimer` Task as the end-of-utterance detector, and gates mic re-arm on `speakingID == nil` plus a 400ms settle delay to avoid capturing TTS tails.

- Voice/VoiceTurn.swift — A pure Sendable value type (id/role/text/date) for one spoken exchange.

Consumers: LiveTranscriptionView (the live panel), VoiceModeView (hands-free orb), ContentView (paste-to-transcribe via MediaTranscribe, autoSpeak via SpeechOut), SettingsView (voice preview).

### app-design (App/ + DesignSystem/)
This subsystem is the app's global state spine plus its visual design tokens.

App/AppState.swift — `AppState` is a `@MainActor`, singleton `ObservableObject` (`AppState.shared`) that acts as an edge-trigger bridge between the App-scene `.commands` menu (which can't reach ContentView's local `@State`) and the views. It holds `selectedTab: AppTab` plus ~10 boolean "request" flags (newChatRequested, stopRequested, showSettingsRequested, showCommandPaletteRequested, etc.). A view observes a flag via `.onChange`, performs the action, then resets the flag to false. `AppTab` is a `String`-backed enum (today/chat/agents/markets/scratchpad/knowledge) whose case order defines both the tab-bar layout and the Cmd-1..6 mapping, and which carries `title`/`icon`.

App/AppSettings.swift — `AppSettings.shared` is the persisted user-settings store, also `@MainActor` + `ObservableObject`. It exposes ~28 `@Published` properties (Apple-Intelligence master switch, brainPreference, customModelName, MLX path, Unsloth endpoint/model, rotationBrains, per-provider model ids for OpenAI/Grok/Gemini/Groq/Mistral/Cerebras/OpenRouter, responseMode, autoSpeak, speechRate/VoiceID, webAccess, useCodeModel, useVision, autonomousMode, offlineOnly, hideFromCapture). Each property mirrors itself to `UserDefaults.standard` in a `didSet`. A nested `Keys` enum holds `nonisolated` string constants, and a family of `nonisolated static var ...Current` accessors let off-main-actor layers (LocalLLM, ToolPolicy, clients) read settings directly from UserDefaults without an actor hop, validating stored model ids against each client's `allModels` and falling back to a default. `BrainPreference` (the brain enum) lives here with `isPaid`/`selectableCases`/title/subtitle/icon metadata, and `MachineInfo` derives a recommended `ResponseMode` from RAM+core count. The class also owns screen-capture privacy: `applyCapturePrivacy()` sets every NSWindow's `sharingType`, and `installCaptureObservers()` registers 5 NSWindow notification observers to re-apply it to newly appearing windows. Rotation mode (`isRotating`/`toggleRotation`/`advanceRotation`) cycles the active `brainPreference` through a user-checked set, one hop per sent message.

App/Salehman_AIApp.swift — the `@main` `App`. A single `WindowGroup` hosts `RootView`, applies one global `.tint(DS.Palette.accent)`, and attaches five sheets driven by AppState flags (onboarding, command palette, shortcuts, about, voice mode). `.commands` rebuilds the menu bar (About/New Chat/View tabs/Settings/Conversation) wiring each menu item to an AppState flag + keyboard shortcut.

DesignSystem/DesignSystem.swift — the `DS` namespace: Space (4-pt scale), Radius, Palette (Apple-Music red/pink accent + dark canvas, with measured WCAG contrast notes), Typography, Motion (custom cubic-bezier + spring curves), Elevation (shadow scale + accentGlow), Bezel (double-bezel tokens), Gradient (brand/userBubble/bg computed LinearGradients). It also ships reusable components: CircleIconButton, Card, PrimaryButtonStyle/SecondaryButtonStyle, Bezel, Eyebrow, SuggestionCard, and a `.dsShadow(_:)` View extension. The legacy `Theme` enum (in ContentView) forwards into `DS`.

Data flow: menu/keyboard -> AppState flag -> view `.onChange` -> action + reset. Settings UI binds two-way to AppSettings `@Published` props -> `didSet` persists to UserDefaults; off-actor consumers read the same keys back through the `nonisolated ...Current` accessors. BrainStatus subscribes to three AppSettings publishers via Combine to refresh the header label on change.

### tests
The test target (Salehman AITests/, Swift Testing framework, `@testable import Salehman_AI`) is a suite of ~25 files that deliberately target PURE, side-effect-free decision functions extracted as "testability seams" so they run network-free and deterministically. Coverage is genuinely strong and intentional in several areas:

CLOUD BRAIN LAYER (best-covered): CloudClientParsingTests pins makeBody/extractContent/decodeDelta for Grok, Gemini, and the shared OpenAICompatibleClient (Groq/Mistral/Cerebras/OpenAI) — including the critical "streamed deltas must NOT be trimmed" regression. CloudErrorDecoderTests pins each provider's errorText() against empty/plaintext/truncated/canonical bodies. GeminiURLEncodingTests pins URLComponents percent-encoding of API keys. Grok/Gemini/FreeCloudBrains/OpenRouter tests pin default model IDs, allModels lists, baseURLs, and Keychain account strings (rename = silent key loss). CloudSystemPromptTests pins the semantic constraints of the single shared cloud system prompt.

ROUTING / MODE PREDICATES: EnsembleTests (formatEnsemble labeling + answered-count + offMessage non-collision), FreeAutoTests (isUsableFreeAnswer error-string rejection across every real client failure format + isFreeAutoMode), FreeAutoCooldown + ToolLoop (120s window boundary, clear-on-success), LocalLLMOffMessage (sentinel stability vs context-aware message), ToolLoop PaidBrainHiding (selectableCases excludes paid).

SECURITY GATES: ToolPolicyTests (external-tool gate + instructions menu), SecurityHardeningTests (SSRF reject loopback/private/IPv6/IPv4-mapped + SelfImprove path-escape), OllamaToolGate/OllamaToolSpecs (web tools hidden when offline). Shell blocklist (case-insensitive, chained, path-prefixed).

ENGINE / POLICY: StockSageSignalEngine (every recommendation branch + confidence cap + zero-division), MemoryManagerPolicy (concurrencyLimit/shouldRefuseHeavyModel across RAM/pressure/thermal corners), AgentPipeline effectiveCap (Ollama serial-cap OOM guard), TrivialMission/MissionComplexity, Ollama tool-call parsing + preferred-model ordering.

The suite carefully manages Swift Testing's default parallelism: any test mutating the global `Keys.brainPreference` UserDefaults key takes BrainPreferenceTestLock (a shared NSLock across suites because brainPreferenceCurrent reads UserDefaults.standard with no injection seam). ToolPolicyTests uses @Suite(.serialized) for its own globals.

THE GAPS: Several pure, easily-testable, USER-DATA-and-SECURITY-critical modules have ZERO unit tests: KnowledgeStore (chunk/keywordScore/cosine/search — the on-device RAG retrieval engine), MemoryStore.recall (embedding+keyword fallback), CommandApprovalCenter.looksRisky (the shell risk classifier that decides which commands re-confirm under "Always run"), MissionMemory.buildContext/getSummary, Web.search HTML parsing + stripHTML + decodeDDG, and StockSagePortfolio input validation. These are exactly the "store logic / chunk/search" areas the audit flagged.
