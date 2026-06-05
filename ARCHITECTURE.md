<!-- Auto-generated 2026-06-05 by the full-codebase-review workflow (Chat B). Grounded in the real source; refine as the app evolves. -->

# Salehman AI: Architecture Documentation

## Overview

**Salehman AI** is a native macOS SwiftUI chat application that provides a unified conversational interface to multiple AI backends. It features a sophisticated multi-agent reasoning system, memory management aware of hardware constraints, and pluggable cloud brain support.

**Core Architecture**: Swift 6 with strict concurrency (actors, MainActor isolation), SwiftUI, Foundation frameworks (Speech, Vision, PDFKit, ProcessInfo). Minimum deployment: macOS 15.0 (Sequoia).

**Key Innovation**: The app routes user messages through multiple "brains" (Apple Intelligence, Ollama local, or cloud APIs) with an intelligent fallback hierarchy. For complex tasks, it spawns a 15-agent team that runs in phases, with memory-aware concurrency caps to avoid freezing low-end hardware.

---

## Module Map

```
Salehman AI/
├── App/
│   ├── Salehman_AIApp.swift          # Entry point, window config, menu bar
│   ├── AppState.swift                # Lightweight bridge for menu commands
│   └── AppSettings.swift             # Preferences singleton (UserDefaults)
│
├── Views/
│   ├── RootView.swift                # Tab container (Chat / Agents / Markets)
│   ├── ContentView.swift             # Chat UI (1108 lines; core UX)
│   ├── AgentsView.swift              # Autonomous mode + agent progress
│   ├── SettingsView.swift            # Brain picker, API keys, preferences
│   ├── MarketsView.swift             # Stock monitoring
│   ├── LiveTranscriptionView.swift   # Real-time meeting transcription
│   └── ...other views
│
├── LLM/ (Brain layer)
│   ├── LocalLLM.swift               # Brain routing logic (896 lines)
│   ├── BrainStatus.swift            # Live brain availability monitor
│   ├── OpenAICompatibleClient.swift # Generic HTTP client for cloud brains
│   ├── CloudBrains.swift            # Provider configs (Groq, Mistral, etc.)
│   ├── GrokClient.swift             # xAI Grok
│   ├── GeminiClient.swift           # Google Gemini
│   ├── GroqClient.swift             # Groq
│   ├── MistralClient.swift          # Mistral
│   ├── CerebrasClient.swift         # Cerebras
│   ├── AnthropicClient.swift        # Anthropic Claude
│   ├── OpenAIClient.swift           # OpenAI / Codex
│   ├── CopilotClient.swift          # GitHub Copilot
│   ├── OllamaClient.swift           # Local Ollama server
│   ├── MemoryManager.swift          # RAM/thermal awareness (actor)
│   └── KeychainStore.swift          # Secure API key storage
│
├── Agents/ (Multi-agent orchestration)
│   ├── AgentPipeline.swift          # Main coordination (300+ lines)
│   ├── AgentDefinitions.swift       # The 15-agent team spec
│   ├── AgentRegistry.swift          # Handler lookup & lifecycle
│   ├── MissionMemory.swift          # Accumulates outputs + results
│   ├── MissionPlan.swift            # Problem statement
│   ├── Orchestrator.swift           # Autonomous mode
│   └── SelfImprove.swift            # Self-patching builds
│
├── Tools/ (Callable by agents, gated by policy)
│   ├── ToolPolicy.swift             # What tools are enabled (security)
│   ├── CommandApprovalCenter.swift  # User approval gate for shell
│   ├── ShellTool.swift              # Terminal command execution
│   ├── MacControlTools.swift        # Mouse/keyboard via Accessibility
│   ├── WebTools.swift               # DuckDuckGo search + URL fetch
│   ├── VisionAnalyzer.swift         # On-device image understanding
│   ├── AnalyzeImageTool.swift       # Wrapper for agents
│   ├── TranscribeMediaTool.swift    # Audio/video → text
│   ├── StockSageTool.swift          # Market data (sample)
│   ├── StockAnalysisTool.swift      # Offline TASI/Saudi analysis
│   ├── ImageGen.swift               # On-device Image Playground
│   ├── CodeTool.swift               # Delegate to Ollama qwen-coder
│   └── ...others
│
├── Persistence/
│   ├── Attachments.swift            # File/image/PDF/audio attachment handling
│   ├── MemoryStore.swift            # Long-term facts (embeddings-based)
│   └── PromptLibrary.swift          # Saved prompt templates
│
├── Media/
│   ├── Transcriber.swift            # Audio/video transcription (on-device)
│   ├── SpeechIn.swift               # Microphone dictation
│   ├── SpeechOut.swift              # Text-to-speech read-aloud
│   ├── LiveTranscriber.swift        # Real-time call transcription
│   └── MediaTranscribe.swift        # Format handling
│
├── StockSage/ (Financial data + analysis)
│   ├── StockSageModels.swift
│   ├── StockSageStore.swift
│   ├── StockSageBriefingService.swift
│   ├── StockSageSignalEngine.swift
│   ├── StockSageScreenAnalysis.swift
│   └── ...others
│
└── DesignSystem/
    └── DesignSystem.swift           # Unified theme (colors, motion)
```

---

## Data Flow Diagram (User Message → Response)

```
┌─────────────────────────────────────────────────────────────────┐
│ User Types Message & Presses Enter                              │
└─────────────────┬───────────────────────────────────────────────┘
                  │
                  ▼
        ┌─────────────────────┐
        │ ContentView.send()  │
        │ - Append user msg   │
        │ - isRunning = true  │
        │ - Schedule save     │
        └──────────┬──────────┘
                   │
                   ▼
      ┌────────────────────────────┐
      │ generateStreaming(prompt)  │
      │ [background Task]          │
      └────────────┬───────────────┘
                   │
                   ▼
      ┌────────────────────────────┐
      │ AgentPipeline.run()        │
      │ - LocalLLM.currentBrain()  │ ◄─────────── Brain routing decision
      │   ├─ Ensemble mode?        │
      │   ├─ FreeAuto mode?        │
      │   └─ Single brain?         │
      └────────────┬───────────────┘
                   │
        ┌──────────┴──────────┬──────────────────┐
        │                     │                  │
        ▼                     ▼                  ▼
    Ensemble:          FreeAuto:            Single Brain:
   (all brains)    (race free clouds    (pinned brain
                     + local backstop)      only)
        │                     │                  │
        │                     │                  ▼
        │                     │         ┌──────────────────┐
        │                     │         │ Complexity test  │
        │                     │         │ + Response mode  │
        │                     │         │ = agent spec     │
        │                     │         └──────────┬───────┘
        │                     │                    │
        │                     └────────┬───────────┘
        │                              │
        ▼                              ▼
   [Fan-out to     ┌──────────────────────────────────┐
    each brain      │ Phase 0 Agents (parallel)       │
    in parallel]    │ - Grok Victor (orchestrate)     │
                    │ - Questioning Strategist        │
                    │ - Reasoning Strategist (tools)  │
                    │ - saleh (product owner)         │
                    └──────────────┬───────────────────┘
                                   │
                                   ▼
                    ┌──────────────────────────────────┐
                    │ Phase 1 Agents (parallel)        │
                    │ - Mission Memory Architect       │
                    │ - Prompt Engineering Lead       │
                    │ - On-Device AI Specialist       │
                    │ - Principal System Architect    │
                    │ - Swift & Concurrency Master    │
                    │ - SwiftUI Experience           │
                    │ - Code Quality Guardian         │
                    └──────────────┬───────────────────┘
                                   │
                                   ▼
                    ┌──────────────────────────────────┐
                    │ Phase 2 Synthesis                │
                    │ - Result Synthesis Lead          │
                    └──────────────┬───────────────────┘
                                   │
                                   ▼
                    ┌──────────────────────────────────┐
                    │ Phase 3 QA (parallel)            │
                    │ - Evaluation Lead                │
                    │ - Testing & Reliability          │
                    └──────────────┬───────────────────┘
                                   │
                                   ▼
                    ┌──────────────────────────────────┐
                    │ Phase 4 Final                     │
                    │ - Final Output Quality Owner     │
                    └──────────────┬───────────────────┘
                                   │
        ┌──────────────────────────┤
        │                          │
        ▼                          ▼
    [Cumulative                [Streamed to UI via
     response text]             onUpdate callback]
        │                          │
        └──────────┬───────────────┘
                   │
                   ▼
        ┌──────────────────────┐
        │ onUpdate(text)       │◄─── Feeds StreamingBubble in UI
        └──────────┬───────────┘
                   │
                   ▼
        ┌──────────────────────┐
        │ Append ChatMessage   │
        │ - isUser = false     │
        │ - text = response    │
        └──────────┬───────────┘
                   │
                   ▼
        ┌──────────────────────┐
        │ ChatStore.save()     │
        │ → chat_history.json  │
        └──────────┬───────────┘
                   │
                   ▼
        ┌──────────────────────┐
        │ isRunning = false    │
        │ Update UI            │
        └──────────────────────┘
```

---

## Brain Preference & Routing Matrix

| Preference | Primary | Fallback | Scope | Cost |
|------------|---------|----------|-------|------|
| `.auto` | Apple Intelligence | Ollama qwen-coder | Local only | $0 |
| `.apple` | Apple Intelligence | Ollama qwen-coder | Local only | $0 |
| `.ollama` | Ollama qwen-coder | Apple Intelligence | Local only | $0 |
| `.freeAuto` | Free clouds (race) | Ollama → Apple Intl | Hybrid | $0 |
| `.claudeHaiku` | Claude Haiku (API key required) | None | Cloud only | Pay-per-token |
| `.grok` | xAI Grok (API key required) | None | Cloud only | Pay-per-token |
| `.gemini` | Google Gemini (free tier available) | None | Cloud only | Free/$$ |
| `.groq` | Groq (free tier available) | None | Cloud only | Free/$$ |
| `.mistral` | Mistral (free tier available) | None | Cloud only | Free/$$ |
| `.cerebras` | Cerebras (free tier available) | None | Cloud only | Free/$$ |
| `.codex` | OpenAI GPT (API key required) | None | Cloud only | Pay-per-token |
| `.copilot` | GitHub Copilot (subscription) | None | Cloud only | Subscription |
| `.openRouter` | OpenRouter aggregator (free models available) | None | Cloud only | Free/$$ |
| `.ensemble` | All configured brains (parallel) | None | Hybrid | Highest cost (all APIs hit) |

---

## Extension Points: Adding a New Brain

### 1. Define the Client Config in `CloudBrains.swift`

```swift
enum NewProviderClient {
    nonisolated static let defaultModel = "model-name"
    nonisolated static let allModels = ["light", "medium", "heavy"]
    
    nonisolated static let shared = OpenAICompatibleClient(
        displayName: "New Provider",
        baseURL: "https://api.newprovider.com/v1",
        defaultModel: defaultModel,
        allModels: allModels,
        keychainAccount: .newProviderAPIKey,
        consoleURL: "https://console.newprovider.com/keys"
    )
}
```

### 2. Add Keychain Account

In `KeychainStore.swift`:

```swift
enum Account: String {
    case newProviderAPIKey = "newprovider-api-key"
}
```

### 3. Update Settings

In `AppSettings.swift`:

```swift
@Published var newProviderModel: String {
    didSet { UserDefaults.standard.set(newProviderModel, forKey: Keys.newProviderModel) }
}

nonisolated static var newProviderModelCurrent: String {
    let raw = UserDefaults.standard.string(forKey: Keys.newProviderModel) ?? ""
    return NewProviderClient.allModels.contains(raw) ? raw : NewProviderClient.defaultModel
}

enum Keys {
    nonisolated static let newProviderModel = "set_newProviderModel"
}
```

### 4. Add Brain Preference

In `AppSettings.swift`:

```swift
enum BrainPreference: String, CaseIterable {
    case newProvider
    
    var title: String {
        case .newProvider: return "New Provider (Cloud)"
    }
    var subtitle: String {
        case .newProvider: return "Cloud · fast · needs API key"
    }
    var icon: String {
        case .newProvider: return "star.fill"
    }
}
```

### 5. Wire Reachability Check

In `LocalLLM.currentBrain()`:

```swift
case .newProvider: return NewProviderClient.shared.hasKey() ? .newProvider : .none
```

### 6. Update Ensemble & FreeAuto Logic (if applicable)

In `LocalLLM.generateEnsemble()` or `LocalLLM.generateFreeAuto()`, add:

```swift
if NewProviderClient.shared.hasKey() {
    roster.append { await NewProviderClient.shared.chat(prompt: prompt, system: sys, model: model) }
}
```

**That's it.** The entire pipeline (agent tool invocation, streaming, error handling, model picker UI) works automatically.

---

## Gotchas & Known Constraints

### 1. **Deterministic Sentinel for offMessage**

The "no model reachable" message is a **static let**, not a computed property. This is intentional: old messages in persisted history must render with the text that was generated at the time, not re-interpreted based on current settings.

**Fix**: Use `LocalLLM.unavailableMessage` (computed) for **current** turn feedback; use `LocalLLM.offMessage` (constant) for persisted comparisons.

### 2. **RAM Pressure & Concurrency Limits**

Running Ollama's 32B model concurrently with 3+ agents can exhaust swap on 16 GB Macs. The `MemoryManager` caps concurrency based on `DispatchSource.makeMemoryPressureSource` + `ProcessInfo.thermalStateDidChangeNotification`.

**Fix**: Always consult `await MemoryManager.shared.concurrencyLimit()` before spinning up parallel tasks in the agent pipeline.

### 3. **Ollama Reachability is Cached**

`OllamaClient` caches the result of an HTTP probe for **30 seconds**. Rapid toggles between `.auto` and `.ollama` may see stale results.

**Fix**: Call `BrainStatus.refresh()` after user manually toggles a setting.

### 4. **Model Deprecation in Cloud APIs**

Groq, Cerebras, and OpenRouter rotate their model inventories. A model ID that works today may return 404 tomorrow. Always keep `allModels` up to date and have a `defaultModel` fallback.

**Fix**: Store model selections in `UserDefaults` but validate against the provider's current `allModels` on every read. Fall back to `defaultModel` if the stored ID is stale.

### 5. **Large File Uploads**

The app rejects files > 200 MB. Text attachments are capped at 20 KB. Audio/video files are transcribed on-device (can be slow for long recordings).

**Fix**: Set reasonable file size expectations in the UI. For long audio, consider splitting into chunks.

### 6. **Keychain Permissions**

If the user revokes Keychain access or is on a read-only filesystem, `KeychainStore.read()` and `KeychainStore.write()` return `nil` / `false` silently. The app gracefully degrades but may not inform the user why a cloud brain suddenly became unreachable.

**Fix**: Emit a status message when Keychain write fails (e.g., during API key entry).

### 7. **Shell Command Timeouts**

Commands that produce > 8 KB of output are truncated. Commands running > 60 seconds are terminated. Long-running builds (e.g., `xcodebuild test`) may fail if the output buffer fills.

**Fix**: Redirect large output to files within the command itself (e.g., `xcodebuild ... > /tmp/build.log 2>&1`).

### 8. **Debate Over Ensemble vs Single Brain**

Ensemble mode hits every cloud API on every message. For a user with 5 cloud keys, a single request costs 5× the tokens. There is no smart deduplication.

**Fix**: Users should either pick a favorite brain OR use `.ensemble` deliberately for high-value decision-making, knowing the cost.

### 9. **FreeAuto Mode Doesn't Distinguish Between "Slow" and "Failed"**

If a free brain is rate-limited (429), the race continues and a sibling brain answers. If a brain just takes 10 seconds to respond, the race is already over (another brain won).

**Fix**: This is by design — the "first usable answer" model favors speed. For guaranteed latency, pin a single brain.

### 10. **Main Actor Hops in Agent Callbacks**

The agent pipeline runs off the main actor, but periodic UI updates (e.g., `MissionProgress.applyAdapted()`) require hopping back:

```swift
Task.detached(priority: .utility) {
    let map = await adaptTitles(...)
    if !map.isEmpty { await MainActor.run { MissionProgress.shared.applyAdapted(map) } }
}
```

This is necessary but can add latency. Keep these hops lean.

---

## Performance & Scalability Notes

- **Conversation history**: Loaded entirely into memory on app launch. For > 1000 messages, consider lazy-loading or pagination.
- **Long-term memory embeddings**: Computed on-device per fact. Recall is O(n) cosine similarity. For > 10k facts, consider a vector DB.
- **Agent phases**: Phases run sequentially; agents within a phase run concurrently (capped by RAM). A 15-agent full pipeline on a 8 GB Mac may take 30–60 seconds.
- **Ollama concurrency**: The local model can run at most 1–3 parallel agent inferences on typical hardware. Concurrency cap respects this.

---

## Testing Recommendations

1. **Unit tests**: `MemoryManagerTests` (concurrency limits), `FreeAutoTests` (race semantics), `CloudClientParsingTests` (SSE parsing)
2. **Integration tests**: End-to-end message flow with mocked brains, ensemble + freeAuto routing
3. **Performance tests**: Measure latency of agent phases on target hardware (8 GB, 16 GB, 32 GB)
4. **Stress tests**: Attach 100 MB file, send 500-message conversation, rapid preference toggling
5. **Security tests**: Keychain permissions, shell command blocklist enforcement, approval gate flow

---

## Future Enhancements

1. **Multi-conversation management**: Tab-based conversation history instead of a single live chat
2. **Prompt templates library**: Saved/shareable agent configurations
3. **Custom agent definitions**: User-defined roles & phases (not just the hardcoded 15)
4. **Real-time collaboration**: Share a chat session with another user
5. **Streaming vision**: Pass image frames to Ollama's vision model in real-time
6. **Plugin system**: Agents can declare custom tools; third-party tools registered at runtime
7. **Batch processing**: Queue multiple requests and execute them overnight
8. **Analytics dashboard**: Track which brains you use most, total API spend, agent success rates

