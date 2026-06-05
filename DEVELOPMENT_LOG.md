# 📓 Development Log — Salehman AI

A running, honest record of changes. Two Claude Code sessions worked this repo in
parallel (see `COORDINATION.md`): **Chat B** = brain/LLM layer + chat UI + design
system; **Chat A** = Markets feature, agent pipeline/backbone, Anthropic/OpenAI/
Copilot clients, live transcription. Entries below are mostly Chat B's work (the
author of this log); Chat A's parallel work is noted where the two intersect.

Failures, reversals, and dead ends are included on purpose — they're the most
useful part of a log.

Format: newest at the bottom. Dates are when the work happened (2026-06-04/05).

> ## 📌 INSTRUCTIONS FOR ANY AI OR PERSON
> This is the **canonical change journal** for Salehman AI. **From 2026-06-05
> onward, every change to this repo gets an entry here** — owner directive (see
> `CLAUDE.md` / `PROJECT_CONTEXT.md`). If you (Claude, Grok, anyone) modify the
> app, append an entry just above the "Standing notes" section, in this format:
>
> ```
> ## <YYYY-MM-DD> · <short title>
> **Files:** <paths touched>
> **What & why:** <what changed and the reason>
> **Result:** <build/test status; follow-ups>
> ```
> Log failures and reversals too — they're the useful part.

---

## 1. "Hide from screen capture" — cover every window
**File:** `App/AppSettings.swift`
- Original `applyCapturePrivacy()` only set `sharingType = .none` on windows that
  existed *at the moment the toggle flipped*. Sheets (Settings, Live
  Transcription), the approval card, popovers, and any later-opened window stayed
  visible in screen shares.
- Added 5 `NSWindow` lifecycle observers (`didBecomeKey`, `didBecomeMain`,
  `didChangeScreen`, `didChangeOcclusionState`, `didExpose`) that re-apply the
  sharing type to each new window + sweep siblings. Installed once in `init`.

## 2. UI performance pass
**File:** `Views/ContentView.swift`
- Extracted the gradient + glow background into a state-free `BackgroundView`
  wrapped in `.drawingGroup()`; dropped blur radius 160 → 90 (the 160px blur on a
  480px circle was the dominant GPU cost on integrated Macs).
- Pulled `MissionProgress.shared` observation out of `ContentView` into a new
  `RunningProgressView`, so streaming tokens stop invalidating the whole
  `LazyVStack` of message bubbles on every token.

## 3. SelfImprove tool
**Files:** `Agents/SelfImprove.swift` (new), `LLM/LocalLLM.swift` (tool registration)
- New `SelfImprove` enum + `SelfImproveTool`: runs `xcodebuild`, parses
  `file:line: error:` diagnostics, asks the on-device model for a minimal
  `REPLACE_RANGE` patch per error, applies it with a timestamped backup under
  `~/.salehman_ai_self_improve_backups/`, rebuilds. Capped iterations, bails on
  no-progress. Path-scoped to the project root so a hallucinated path can't
  rewrite unrelated files.

## 4. Centralized ToolPolicy gate
**Files:** `Tools/ToolPolicy.swift`, `LLM/LocalLLM.swift`
- `ToolPolicy.activeTools()` became the single source of truth for which tools a
  `LanguageModelSession` receives; external tools (web) gated behind settings.
  `ChatSession` instructions now list only the *enabled* tools so the model
  doesn't promise web access when it's off.

## 5. Apple-Intelligence-off → Ollama fallback (the big unblock)
**Files:** `LLM/LocalLLM.swift`, `LLM/OllamaClient.swift`, `Agents/AgentPipeline.swift`
- **Root cause of "every reply is the canned off-message":** `AgentPipeline.run`
  short-circuited with `guard LocalLLM.isEnabledByUser`. Replaced with
  `if await LocalLLM.currentBrain() == .none`.
- `generate / generateStreaming / chat` now fall through Apple Intelligence →
  Ollama qwen-coder transparently. Added `OllamaClient.chat / chatStream`.
- New `LocalLLM.Brain` enum + `currentBrain()` / `currentBrainLabel()`.

## 6. BrainStatus + header indicator
**Files:** `LLM/BrainStatus.swift` (new), `Views/ContentView.swift`
- `@MainActor` observable polling the live brain every 10s + reacting to the AI
  toggle. Header shows a colored dot + honest label (green Apple / blue Ollama /
  orange none / purple Thinking). Later extended with `hasVision` and `hasGrokKey`.

## 7. Design-system + UI polish
**Files:** `DesignSystem/DesignSystem.swift`, `Views/ContentView.swift`
- Added custom cubic-bezier motion curves (`smooth`, `cinematic`, `magnetic`),
  `Bezel` double-bezel container, `Eyebrow` microtag, `SuggestionCard`.
- Rebuilt the empty state as a 2×2 Bento of rich suggestion cards; replaced the
  saturated Auto-run pill with a calmer `ConfirmationChip` (neutral glass + a
  colored status dot); added a fade-up-blur entry animation to `MessageBubble`.
- Removed dead `Chip` component; replaced `TypingIndicator`'s stock `.easeInOut`
  loop with a cubic-bezier curve.

## 8. Swift-6 `nonisolated` sweep
**Files:** many (`LocalLLM`, `ToolPolicy`, `AppSettings.Keys`, `AgentRegistry`,
`AgentDefinitions`, `AgentPipeline.buildPrompt`, `MacControl`, `ChatStore`)
- Project builds with `-default-isolation=MainActor`, so pure utility statics
  were main-actor-isolated by default and unreachable from actor contexts.
  Annotated the pure/thread-safe ones `nonisolated`. Cleared all warnings.
- `SpeechOut.Delegate` stopped holding a `weak var owner` (used the shared
  singleton directly) to clear a Sendable warning.

## 9. Brain picker + vision status
**Files:** `App/AppSettings.swift`, `LLM/LocalLLM.swift`, `LLM/BrainStatus.swift`, `Views/SettingsView.swift`
- `BrainPreference` enum (`auto | apple | ollama`, later +cloud cases) persisted
  in UserDefaults. `currentBrain()` honors it; `*Allowed` gates skip non-pinned
  brains instead of silently falling back. Settings gained a Brain section with
  live "Ready / Unavailable" pills. `BrainStatus.hasVision` probes qwen2.5vl.

## 10. RAM overhaul (Phase 1 Core Intelligence)
**Files:** `LLM/OllamaClient.swift`, `LLM/MemoryManager.swift` (new), `Agents/AgentPipeline.swift`, `Salehman AITests/MemoryManagerTests.swift` (new)
- **Default Ollama model 32B → `qwen2.5-coder:7b`** (~19 GB → ~4.7 GB resident).
- New `MemoryManager` actor: subscribes to `DispatchSource` memory-pressure +
  thermal-state signals; pure policy fns `concurrencyLimit(...)` /
  `shouldRefuseHeavyModel(...)`; auto-evicts Ollama on pressure.
- `OllamaClient.Generation` (keepAlive / numCtx / numGPU); `unloadAll()`.
- AgentPipeline reads `MemoryManager.concurrencyLimit()` per phase, batches agents.
- 23 unit tests for the pressure/thermal/RAM matrix.
- **Did NOT** fabricate benchmark numbers, do mid-conversation model switching,
  or add an auto-download flow (Ollama auto-pulls).

## 11. xAI Grok cloud brain
**Files:** `LLM/KeychainStore.swift` (new), `LLM/GrokClient.swift` (new), `App/AppSettings.swift`, `LLM/LocalLLM.swift`, `LLM/BrainStatus.swift`, `Views/SettingsView.swift`, `Salehman AITests/GrokTests.swift` (new)
- **Keychain-backed key storage** (`SecItem`, `…AfterFirstUnlockThisDeviceOnly`,
  no iCloud sync). The literal key never lives in source, UserDefaults, or
  `@State` after Save.
- `GrokClient` (OpenAI-compatible wire format). `BrainPreference.grok`. Settings
  section with SecureField → Save → model picker → Test connection. 10 tests.
- ⚠️ **Security divergence noted:** Chat A stored the *Anthropic* key in
  UserDefaults; Grok + all later cloud keys use Keychain. Flagged, not migrated.

## 12. Four free cloud brains
**Files:** `LLM/OpenAICompatibleClient.swift` (new), `LLM/CloudBrains.swift` (new), `LLM/GeminiClient.swift` (new), `App/AppSettings.swift`, `LLM/LocalLLM.swift`, `Views/SettingsView.swift`, `Salehman AITests/FreeCloudBrainsTests.swift` (new)
- `OpenAICompatibleClient` generic base → **Groq, Mistral, Cerebras** as ~15-line
  configs in `CloudBrains.swift`. **Gemini** got its own client (Google's
  non-OpenAI shape, key in URL param).
- Collapsed every `*Allowed` switch in `LocalLLM` into one-line `pref == .X`
  checks (was an exhaustive-switch maintenance trap). Generic
  `cloudKeyRow/cloudModelRow/cloudTestRow` Settings helpers. 21 tests.

## 13. Review + cleanup pass
**Files:** `LLM/KeychainStore.swift`, `LLM/GrokClient.swift`, `LLM/GeminiClient.swift`, `LLM/BrainStatus.swift`, `Views/SettingsView.swift`
- Build was broken by Chat A adding `OpenAIClient` + `CopilotClient` (cloud brains
  6 & 7) in parallel → non-exhaustive switches + `KeychainStore` actor-isolation.
  Fixed: `KeychainStore` methods `nonisolated`; cloud-client private helpers
  `nonisolated`; added `.codex`/`.copilot` cases to `BrainStatus.dotColor` and
  `SettingsView.brainRow`.

## 14. `offMessage` sentinel split
**Files:** `LLM/LocalLLM.swift`, `Salehman AITests/LocalLLMOffMessageTests.swift` (new)
- `offMessage` had drifted into a context-aware computed `var` — which broke the
  three call sites that compare against it as an equality sentinel the moment the
  user toggled `brainPreference`. Restored it to a deterministic `static let`;
  added a separate `unavailableMessage` computed `var` for context-aware *display*.
  4 tests lock the contract (sentinel stable across reads + preference toggles).

## 15. Streaming-fallback bug (real user-facing)
**File:** `LLM/LocalLLM.swift`
- In balanced/full modes the streaming agent pushed the `offMessage` *sentinel*
  into the live UI via `onUpdate(...)` when a cloud `chatStream` returned nil — so
  a working Grok looked "unreachable" mid-call. Fix: each cloud brain now falls
  back to its own *non-streaming* `chat` before giving up, and the sentinel is
  never pushed into `onUpdate`.

## 16. Cloud error surfacing
**Files:** `LLM/GrokClient.swift`, `LLM/GeminiClient.swift`, `LLM/OpenAICompatibleClient.swift`
- Cloud clients used to swallow non-200 responses into `nil` (→ generic
  sentinel). Now they drain the body and return `[Provider error STATUS: MSG]`
  (e.g. `[Grok error 404: model … does not exist]`), so the user sees the real
  failure. `nil` is reserved for "couldn't reach the server at all." Matches the
  pattern Chat A's `AnthropicClient` already used.
- The `errorText(...)` decoders were relaxed `private` → internal + covered by
  `CloudErrorDecoderTests.swift`.

## 17. Grok model catalog corrections (two mistakes, both mine)
**Files:** `LLM/GrokClient.swift`, `Salehman AITests/GrokTests.swift`
- **Mistake 1:** shipped `grok-4-heavy-4.3` in the picker — not a real xAI model →
  404. Removed from `allModels` (kept as reserved constant).
- **Mistake 2:** `grok-4-heavy` *also* isn't API-accessible (grok.com-only). Removed
  too; added the real accessible catalog `grok-4 / grok-3 / grok-3-mini`.
- `AppSettings.init` auto-migrates a stuck stored selection to `grok-4`. Tests pin
  the heavy variants OUT of `allModels`.

## 18. Anthropic 401 diagnostics
**File:** `Views/SettingsView.swift`
- User hit persistent `[Claude Haiku error 401: invalid x-api-key]` insisting the
  key was valid. Added a **key-prefix display** (`sk-ant-api03…` + "looks like an
  Anthropic key" / ⚠️ "doesn't start with sk-ant-") and a **Test connection**
  button so the user can see *which* key family is stored + the verbatim API error
  without sending a chat. (Root cause is account-side, not app-side.)

## 19. SettingsView live polling
**File:** `Views/SettingsView.swift`
- The Ollama "Ready/Unavailable" picker rows were frozen at the snapshot taken
  when Settings opened (one-shot `.task`). Wrapped in a 5s poll loop (cheap —
  `OllamaClient` memoizes probes 30s) so the rows track reality and converge with
  the top "Is X working?" panel. Loop auto-cancels on dismiss.

## 20. Autonomous Mode loop (and an OOM I caused)
**Files:** `Views/AgentsView.swift`, `Agents/AgentPipeline.swift`
- "Start Autonomous Run" was a one-shot, not a loop. Rebuilt as a cancellable
  `Task` that chains `AgentPipeline.run` calls, feeding each result into the next
  mission, with a Stop button + iteration counter. Then, per user request, made it
  **run forever** (no cap; Stop or `AUTONOMOUS_DONE` are the only exits).
- ⚠️ **Then I caused an OOM:** I'd also removed the Ollama single-agent pin from
  `AgentPipeline`, reasoning that 7B + Ollama serialization made it safe. With 15
  agents fanning out against a 9 GB-resident 14B model the Mac ran out of
  application memory. **Fix:** re-added a hard `cap = 1` for `brain == .ollamaCoder`
  in AgentPipeline (agents run sequentially on Ollama; spec count preserved so the
  UI still shows all 15 steps). Cloud/Apple brains keep the dynamic MemoryManager cap.

## 21. Ollama model priority resolver
**Files:** `LLM/OllamaClient.swift`, `LLM/LocalLLM.swift`, `Salehman AITests/OllamaPriorityResolverTests.swift` (new)
- User's `ollama pull qwen2.5-coder:7b` failed at 14% — **disk full** (100% on a
  228 GB volume; macOS update banner had been warning). Reclaimed ~649 MB of
  partial-download blobs.
- Rather than force a re-download, added `preferredCodeModels` (`7b → 14b → 32b`)
  + `activeCodeModel()` that picks the first variant actually pulled. User already
  had 14B → app works immediately. `codeModel` stays the documented 7B default;
  resolver is a mechanism layered on top.

## 22. Heavy quality pass (in progress, 2026-06-05)
**Files:** cloud clients (visibility), `Salehman AITests/CloudClientParsingTests.swift` (new), `Views/SettingsView.swift`, `Views/ContentView.swift`
- Ran 3 read-only Explore audits, reconciled findings (rejected several false
  positives — e.g. trimming streamed deltas would join words across chunks).
- Relaxed `makeBody/extractContent/decodeDelta` to internal in the 3 cloud clients
  for direct unit-test coverage of the happy-path parsers.
- (Continuing) bug fixes: SettingsView polling cancel-check, single Keychain read
  per render, drop a pointless `.value` await in `ChatStore.scheduleSave`,
  defensive Grok key trim, Gemini error-wording alignment.
- **Flagged for Chat A (their lane, not edited):** `AnthropicClient.chatStream`
  swallows non-200 into nil (should surface the error like GrokClient — this is
  the brain that's been 401-ing the user); `CopilotClient` non-streaming path
  doesn't check HTTP status before JSON-parsing.

---

## 2026-06-05 · Crash post-mortem + RAM guardrail
**Files:** `LLM/LocalLLM.swift` (`generateEnsemble`); Ollama models (ops, not code)
**What & why:** Owner's 16 GB Mac hard-froze (power-button hold) — RAM exhaustion with no swap headroom (data disk 97% full) while the 9 GB `qwen2.5-coder:14b` ran. Freed 19 GB by removing the unused 32B, pulled the 4.7 GB 7B, and made **ensemble SKIP the local Ollama model on <24 GB Macs** (cloud-only + honest note) so "All Brains" can't fire a heavy local model alongside cloud calls.
**Result:** Disk 6.4→25 GB free; Ollama footprint 9→4.6 GB; guardrail shipped, build/tests green.

## 2026-06-05 · Ensemble "Not working" false-negative fixed
**Files:** `LLM/LocalLLM.swift`, `Views/SettingsView.swift`, `Salehman AITests/EnsembleTests.swift`
**What & why:** Ensemble was wired only in `AgentPipeline`; the model layer (`generate`/`chat`/`generateStreaming`) had no `.ensemble` branch, so the Settings health-probe (`generate("ping")`) fell through to `offMessage` → "Not working" even though ensemble chat worked. Added the ensemble branch to all three model-layer entries; made the Settings test ensemble-aware (reachability check, zero paid calls).
**Result:** Build + suite green; added `EnsembleRoutingTests`.

## 2026-06-05 · "Free · Auto" parallel-race brain mode
**Files:** `LLM/LocalLLM.swift`, `App/AppSettings.swift`, `LLM/BrainStatus.swift`, `Views/SettingsView.swift`, `Agents/AgentPipeline.swift`, `Salehman AITests/FreeAutoTests.swift`
**What & why:** New `BrainPreference.freeAuto` answering "free must have unlimited usage" + "make them parallel". `generateFreeAuto` races the configured FREE cloud brains (Groq/Cerebras/Gemini/Mistral/OpenRouter) in parallel, returns the first usable answer (`isUsableFreeAnswer` drops empty + `[…error…]` sentinels, so a 429 just loses the race); if all free cloud brains fail, falls back to LOCAL (Apple→Ollama) **sequentially** (never concurrent — preserves the RAM guardrail). Effectively never blocked; never uses paid brains. New Brain/BrainPreference cases handled across all exhaustive switches; routed in generate/stream/chat + AgentPipeline short-circuit.
**Result:** Build + full suite green.

## 2026-06-05 · Fixed stale cloud model IDs (keys worked, models were dead)
**Files:** `LLM/CloudBrains.swift`, `Salehman AITests/FreeCloudBrainsTests.swift`
**What & why:** Owner's free keys exposed that the app's default models were decommissioned — Groq `llama-3.1-70b-versatile`→400, Cerebras `llama3.1-8b`→404, OpenRouter free list had dead IDs. Verified live against each provider's `/v1/models` and corrected (Groq→`llama-3.3-70b-versatile`, Cerebras→`gpt-oss-120b`+`zai-glm-4.7`, OpenRouter→`openai/gpt-oss-120b:free` set). Made the pinned-ID tests rotation-proof instead of asserting exact strings.
**Result:** Build + suite green. (Converged with the other session's parallel edits; verified.)

## 2026-06-05 · Security: SSRF + symlink hardening (multi-agent review)
**Files:** `Tools/WebTools.swift`, `Agents/SelfImprove.swift`, `Salehman AITests/SecurityHardeningTests.swift`
**What & why:** An 18-agent review (adversarially verified) found `WebTools.fetch` would reach localhost/LAN/cloud-metadata (SSRF) and `SelfImprove.isInsideProject` was symlink-bypassable. Added `ssrfRejectionReason` (rejects non-http(s) schemes + private/loopback/link-local hosts) and switched the project-escape check to `resolvingSymlinksInPath()`. 3 more confirmed issues in the Agents lane (symlink-following file tools, two `nonisolated(unsafe)` races) flagged for the other session in `COORDINATION.md`. 3 review claims were rejected as false-positives.
**Result:** Build + suite green; new `SecurityHardeningTests` pins both guards.

## 2026-06-05 · Complete handoff knowledge base + this logging system
**Files:** `PROJECT_CONTEXT.md` (new), `CLAUDE.md` (new), `tools/bundle_source.sh` (new), `SOURCE_BUNDLE.md` (generated), `ARCHITECTURE.md` (new, earlier today), `DEVELOPMENT_LOG.md` (this preamble + format)
**What & why:** Owner directive — a complete "send to Grok / whoever, they know everything" kit + log everything from today onward + remind self and external AIs. Built the master `PROJECT_CONTEXT.md` (file-by-file map, brain system, providers, security, known issues), the all-source `SOURCE_BUNDLE.md` + its regenerator script, and the standing `CLAUDE.md` logging rule.
**Result:** Bundle = 79 Swift files / 12,304 LOC + docs (644 K). Knowledge base in place; this directive also saved to Claude's persistent memory.

## 2026-06-05 · ChatStore save-on-quit fix + test-target cleanup (+ a real SSRF gap caught)
**Files:** `Views/ContentView.swift`, `Tools/WebTools.swift`, `Salehman AITests/{SecurityHardeningTests,EnsembleTests}.swift`
**What & why:** (1) `ChatStore` now flushes its 1.5 s debounced save on `NSApplication.willTerminateNotification` (added `import AppKit`), so the last messages survive a quit that lands inside the debounce window (`onDisappear` isn't guaranteed on app termination). (2) Found that my earlier `SecurityHardeningTests.swift` had been written to a **stray outer `Salehman AITests/` dir not in the build** — so those tests never ran. Relocated it to the real inner target and removed the stray dir. (3) Running them then caught a **real gap in my own SSRF fix**: `fetch` prepended `https://` to `file://`/`ftp://` inputs, so the scheme check never fired — fixed to reject explicit non-web schemes outright. (4) Removed the racy `isEnsembleModeTracksThePreference` test (it mutated the global `brainPreference` key in parallel with the freeAuto routing test → flaked); the freeAuto suite keeps the sole mutator.
**Result:** Build + full suite green; SSRF + symlink guards now genuinely covered by tests in the real target.

## 2026-06-05 · UI/UX Wave 1 (accessibility) applied + ToolPolicy gate test + measured contrast
**Files:** `Views/TabSwitcherBar.swift`, `Views/ContentView.swift`, `Views/SettingsView.swift`, `DesignSystem/DesignSystem.swift`, `Salehman AITests/ToolPolicyTests.swift` (new)
**What & why:** Applied Wave 1 of the UI/UX transformation — the accessibility fixes that close real WCAG failures: VoiceOver labels/hints/`.isSelected` on TabSwitcherBar pills + market-dot `accessibilityValue`; brain-grid cells now show a **"Connected/Offline" text label** (not color-only — WCAG 1.4.1) with soft-tint dots + `accessibilityLabel`; `MessageBubble` reads as one labeled element ("You said / Assistant replied"), avatars `accessibilityHidden`, action buttons labeled; `ApprovalCard` marked `.isModal` with command `accessibilityLabel` + button hints; contrast token bumps. Added `ToolPolicyTests` (serialized) pinning the security gate (`isExternalAllowed` + the instructions-menu web-tool gating). **Then measured actual WCAG ratios** (alpha-composited math) which **corrected two of my own review claims**: `textSecondary@0.60` was already 7.21:1 (not "borderline"); the hairline at 0.12 is only 1.37:1 (does NOT meet 3:1) — fixed the false code comments to say it's decorative (state/contrast carried by the status indicators, measured ~9.8:1).
**Result:** Build + full suite green; app relaunched. Status indicators measure 9.76–9.93:1. NOT done (environment limits): real Accessibility-Inspector/VoiceOver session, screenshots, Instruments profiling — these need a human-driven Xcode session.

## 2026-06-05 · 🔴 Free·Auto bug: error string won the race (caught via user screenshots)
**Files:** `LLM/LocalLLM.swift` (`isUsableFreeAnswer`), `Salehman AITests/FreeAutoTests.swift`
**What & why:** User screenshots showed Free·Auto returning `[Mistral request failed (HTTP 401)…]` as the *answer* instead of falling back to a working brain. Root cause: clients emit TWO failure formats — `[X error <status>: …]` AND `[X request failed (HTTP …)…]` — and `isUsableFreeAnswer` only rejected strings containing the word "error". The Mistral 401 used the "request failed" form (no "error"), so the filter accepted it, it won the parallel race (401s return fast), and the user saw the failure as their reply — defeating the whole "never blocked" guarantee. Fix: reject any fully-bracketed (`[`…`]`) reply containing `error` / `request failed` / `(http ` / `couldn't complete`, covering every client format incl. the on-device one. Requiring full-bracket wrap avoids false-rejecting markdown answers that merely start with `[`. Added `rejectsTransportFailureFormat` regression test.
**Result:** Build + full suite green; relaunched. Failing brains now correctly lose the race → a healthy sibling (Groq/Cerebras/OpenRouter) or the local backstop (Apple/Ollama) answers. (User-side note: the OpenAI key "h" + a wrong Mistral key are bad keys — they're now skipped gracefully; clearing them in Settings removes the wasted attempts.)

## 2026-06-05 · "Do all 4" batch: cooldown + verification tooling + UI Wave 2 wins + pipeline races (other session)
**Files:** `LLM/LocalLLM.swift` (`FreeAutoCooldown` actor, restructured `generateFreeAuto`); `Views/ContentView.swift` (composer focus ring, StreamingBubble pulsing avatar); `Salehman AITests/{BrainPreferenceTestLock,FreeAutoTests,LocalLLMOffMessageTests}.swift`; `VERIFICATION.md` (new)
**What & why:** Four-part follow-up from the review self-critique:
- **#1 Free·Auto smart cooldown** — added a `private actor FreeAutoCooldown` (Swift-6-clean, no `nonisolated(unsafe)`) that remembers per-brain failure timestamps with a 2-min window. Restructured `generateFreeAuto`'s roster to `[(name, thunk)]`, skip brains in cooldown when building the active list, and record `recordSuccess` / `recordFailure` from the race loop. Effect: a known-bad key (e.g. the wrong Mistral key in user's saved state) no longer costs a round-trip every turn; success clears the mark immediately so transient rate-limits self-heal.
- **#2 Verification tooling** — added `VERIFICATION.md` with a printable Instruments capture checklist (subsystem `com.salehman.ai`, category `Brain`) + an Accessibility Inspector + VoiceOver sweep guide. The parallel session had already wired `OSSignposter` with `freeAuto` / `ensemble` intervals in `LocalLLM`; aligned the docs to the actual subsystem.
- **#3 Pipeline races** — confirmed **both fixed by the other session**: `AgentRegistry` now uses a `static let registerToken` lazy initializer (Swift's once-init kills the TOCTOU); `AgentPipeline.lastOutcome` is now an `NSLock`-guarded computed property. The COORDINATION.md handoff worked.
- **#4 UI Wave 2 bounded wins** — composer focus ring upgraded from a 1px / 0.6-opacity single-color stroke to a 2px gradient stroke + accent glow + animated icon tint (`DS.Motion.smooth`). StreamingBubble's sparkles avatar now pulses via `.symbolEffect(.pulse.byLayer, options: .repeating)` while streaming, giving a real "alive" affordance; `accessibilityHidden(true)` since the bubble label conveys the speaker. The risky bits (Settings 440→120 row de-dup; the streaming Timer char-reveal that could fight real token streaming) are deferred — they need more careful design than a one-pass apply.
- **Plus a robustness fix the suite needed:** the brain-preference test race resurfaced because three suites (`FreeAutoTests`, `LocalLLMOffMessageTests`, formerly `EnsembleTests`) mutate the same global `Keys.brainPreference`. Swift Testing's `.serialized` is per-suite only — added a shared `BrainPreferenceTestLock` (`NSLock`) all three now acquire, eliminating the cross-suite race permanently.
**Result:** Build + full suite green; relaunched. UI: composer feels distinctly more premium on focus; streaming avatar visibly pulses. Free·Auto skips known-bad keys for 2 minutes; logged in `VERIFICATION.md` how to capture real Instruments / Accessibility-Inspector evidence to validate the review's *estimated* perf and a11y numbers.

## 2026-06-05 · Race fixes (the 2 high ones) + Free·Auto filter widened + cooldown (Chat B's half of the same batch)
**Files:** `Agents/AgentPipeline.swift`, `Agents/AgentRegistry.swift`, `LLM/LocalLLM.swift`, `Salehman AITests/FreeAutoTests.swift`
**What & why:** Three of the four items the owner approved as "do all 4" landed in my hands. (1) **`AgentRegistry.registerDefaultsOnce()` TOCTOU race** — the old `guard !didRegister { didRegister = true }` could let two concurrent `run()` calls both enter and mutate the `handlers` dict. Replaced with a lazy `private static let registerToken: Void = {…}()`; Swift's runtime guarantees lazy static initializers run **exactly once, thread-safely** (dispatch_once-style). `didRegister` deleted; `handlers` stays `nonisolated(unsafe)` honestly (now only written from inside the one-time init, then read-only). (2) **`AgentPipeline.lastOutcome` data race** — `nonisolated(unsafe) static var` written in async `run()`, read in `Orchestrator` with no sync → UB. Lock-guarded via a backing `_lastOutcome` + `NSLock`; the public `lastOutcome` keeps the same get/set surface so `Orchestrator` is untouched (no signature ripple in a contended file). The single-slot semantic limit (concurrent missions overwriting each other) is documented in code — fine for this app's serialized send path. (3) **Free·Auto filter widening** — `isUsableFreeAnswer` only rejected the `[X error …]` format, so `[Mistral request failed (HTTP 401)…]` slipped through and **won the race**, showing the failure as the user's answer (visible in the user's screenshots before the fix). Now requires the reply to be fully bracketed (`[…]`) and contain any of `error` / `request failed` / `(http ` / `couldn't complete`; pinned by a new `rejectsTransportFailureFormat` test. (4) **Cooldown** — new `FreeAutoCooldown` actor (proper thread-safety, deliberately *not* `nonisolated(unsafe)`) records per-brain failures; `generateFreeAuto` skips a brain for 120 s after a failure and clears the mark on success, so a known-bad key no longer costs a round-trip every turn. Roster restructured to carry brain names so failures/successes can be attributed. Signposter (`LocalLLM.signposter`) wraps `freeAuto` / `ensemble` intervals — see the parallel session's `VERIFICATION.md` for how to capture them in Instruments.
**Result:** Build + full suite green; app relaunched. Cross-lane edits to `Agents/*` were owner-authorized and announced in `COORDINATION.md`. The two race fixes used minimal surface (no ripple to callers) deliberately — a cleaner "return outcome from `run()`" refactor was rejected as too contended-file-risky right now.

## 2026-06-05 · 🍎 Apple-Music color identity (whole-app recolor via DS token swap)
**Files:** `DesignSystem/DesignSystem.swift`, `App/Salehman_AIApp.swift`
**What & why:** Owner asked to "upgrade the gui completely to colors similar to apple music." Re-skinned the entire app from cool blue/purple to the Apple-Music **warm-dark + red/pink** identity by swapping **four constants** in the DS token layer — that's the whole change. `Palette.accent` `(0.40, 0.55, 1.0)` → `(0.98, 0.18, 0.29)` (#FA2D4A, Apple-Music red); `accent2` `(0.62, 0.40, 1.0)` → `(1.00, 0.33, 0.55)` (#FF548C, pink-magenta); `bgTop`/`bgBottom` shifted from cool indigo to warm near-black `(0.09, 0.05, 0.07)` / `(0.03, 0.02, 0.03)`. Because `Gradient.brand` is a *computed* `LinearGradient([accent, accent2])`, the tab bar's selected pill, the send button, the brand logo tile, the suggestion-card icon, the input focus-ring stroke, the BackgroundView glows, and the `ConfirmationChip` accent all flipped to red→pink with **zero view edits**. `Gradient.userBubble` (hardcoded blue→purple) updated separately to a slightly hotter red→pink so user messages still "lead" visually. Added **one global `.tint(DS.Palette.accent)`** on `RootView()` in `Salehman_AIApp.swift` so the ~13 `Color.accentColor` call sites in `SettingsView.brainGridCell` / `AgentsView` / `CopilotSignInView` (system-blue bypass) pick up the red too — avoids editing those contended files.
**Result:** Build green; app relaunched. Whole UI reads Apple-Music: tab-selection pill is red, send button + brand logo are red→pink, user bubbles are pink, background glows are warm. The status colors (`successSoft` / `warningSoft` green/amber) are intentionally **kept** — they're functional semantics, not brand. Layout polish (bolder nav titles, more breathing room) deferred pending visual review of the recolor.

## 2026-06-05 · Recolor completion (accentColor fills) + chat-header "Salehman AI" de-dup
**Files:** `Views/SettingsView.swift`, `Views/AgentsView.swift`, `Views/CopilotSignInView.swift`, `Views/ContentView.swift`
**What & why:** (1) The global `.tint` covers controls that read `\.tint`, but NOT `Color.accentColor` used as a **fill / foregroundStyle** (e.g. the brain-grid selection `Color.accentColor.opacity(0.15)` background + stroke, the active-agent icon, the Copilot sign-in glyph) — those stayed system-blue in the red app. Replaced every `Color.accentColor`/`.accentColor` literal → `DS.Palette.accent` across those views to finish the recolor. (2) **Owner: "why is Salehman written twice in the chat section?"** — the top tab bar already shows the brand "Salehman AI", and the chat header repeated it (leftover from before the tab bar existed). Dropped the duplicate title; the chat header now leads with the live brain status (the useful, non-redundant info), keeping "Salehman AI" only in the VoiceOver label. (Build hiccup: the status `Text` ternary mixed `HierarchicalShapeStyle.secondary` with `Color.white` → typed both as `Color`.)
**Result:** Build + full suite green; relaunched. No more double "Salehman AI" on the Chat screen; brain-grid selection + agent icons now red, not blue.

## 2026-06-05 · "Improve everything" UI elevation — Waves 1–2 + bubbles + code blocks
**Files:** `DesignSystem/DesignSystem.swift`, `Views/TabSwitcherBar.swift`, `Views/MarketsView.swift`, `Views/AgentsView.swift`, `Views/MarkdownText.swift`, `Views/ContentView.swift`
**What & why:** Owner: "improve everything." A read-only multi-agent design pass (3 designers + synthesizer, reality-checked against live code) drove a surface-by-surface elevation, applied with a build after each surface. **Wave 1 (foundation):** `DS.Elevation` (shadow1/2/3 + `accentGlow`) + `dsShadow(_:)` helper, `DS.Motion.stagger`/`.entrance`, tiered `DS.Radius` (8/12/14/16/20/24, bubble 18→16 etc.) — pure tokens, cascade everywhere; TabSwitcherBar brand cluster (36pt tile + stacked "Salehman/AI" logotype + accent glow) and market dot (halo + soft pill). **Wave 2:** rebuilt `MarketsView` from a bare placeholder into a premium hero (gradient-washed surface + glow) + feature roadmap; `AgentsView` grid → themed `AgentCard` struct (extracted so it can own `@State hovering` — a `@State` can't live in a func) with status-colored icon circle + hover lift, header gained a subtitle. **Wave 3a (bubbles, the original ask):** capped reading width (580pt), `UnevenRoundedRectangle` tail toward the avatar, assistant gradient surface, user red glow, 16/12 padding — *converged with the parallel session, verified consistent.* **Wave 3c:** `MarkdownText.CodeBlock` got a tinted uppercase language badge, neutral-readable code color (was harsh terminal-green), line-spacing, soft-success copied state, capped width.
**Result:** Build + full suite green; relaunched. Much of Wave 1–3a converged with the parallel session (sliding tab pill, bubble shape) — verified rather than duplicated. **Deferred (deliberate):** Wave 3b (message grouping + time separators + floating scroll-to-latest pill) — it's the one piece on the **protected streaming/scroll path** in a concurrently-edited file; doing it wrong breaks auto-scroll, so it needs a careful focused pass, not a fast apply. Send-button ripple skipped (gimmicky, low value).

## 2026-06-05 · 🌐 Fix: Ollama replied in Arabic to English prompts
**Files:** `LLM/LocalLLM.swift`
**What & why:** Owner screenshot: pinned to local **qwen2.5-coder**, the assistant answered English prompts ("DO 3B") in Arabic. Two causes: (1) the **agent path** (`generate` l.618/628 + `generateStreaming` l.723/745) called `OllamaClient.chat/chatStream(prompt:)` with **NO `system:`** — so the language-mirror rule never reached qwen on those generations (the most-visible streamed final answer included); qwen, a strongly multilingual model, then drifted to Arabic. (2) Even where the rule WAS passed, it was a soft mid-prompt clause qwen followed weakly. Fix: pass `system: Self.ollamaChatSystem` to all four Ollama calls, and rewrote the language rule in BOTH `cloudSystemPrompt` + `ollamaChatSystem` as a forceful, front-positioned **"CRITICAL LANGUAGE RULE: reply in the SAME language as the user's latest message … never switch on your own (you are multilingual and must not default to Arabic)."**
**Result:** Build + full suite green; relaunched. English in → English out; Arabic in → Arabic out, across the single-brain and agent paths.

## 2026-06-05 · GUI polish: premium Settings section headers + ApprovalCard re-brand + MemoryView halo
**Files:** `Views/SettingsView.swift` (section helper), `Views/ContentView.swift` (ApprovalCard icon), `Views/MemoryView.swift` (empty state)
**What & why:** Owner: "improve everything GUI" — another pass on the surfaces the earlier waves didn't touch. **(1) SettingsView `section(...)` helper** — every section card in Settings (Intelligence, Brain, Free/Paid keys, Performance, Capabilities, Voice, Privacy, Status) now leads with a **3pt brand-gradient stripe + tracked uppercase title** instead of a flat greyed label; tokenized the card fill/stroke (`DS.Palette.surface`/`surfaceStroke` was hardcoded `Color.white.opacity(0.05/0.08)`) and added `DS.Elevation.shadow1` for gentle depth. Single-helper change → cascades through every section. **(2) ApprovalCard icon** — was Color.orange (UI-standard "caution" but dissonant in the red app); now `DS.Palette.accent` + `accentGlow(0.45)`. Red itself signals warning (Apple uses red for destructive/cautionary), so this stays cautious AND on-brand. **(3) MemoryView empty state** — added a blurred-Circle halo behind the brain glyph + tinted the icon brand-accent, mirroring the chat empty-state's halo idiom so an empty admin sheet still feels lived-in.
**Result:** Build + full suite green; relaunched. Settings reads distinctly more premium (every section card now has visual identity, not just text); approval modal now harmonizes with the brand; empty Memory sheet no longer feels abandoned. Cascading helper-edit pattern (one change → ~10 affected sections) is the recurring leverage point in this codebase — same pattern as the DS token recolor.

## 2026-06-05 · 🖥️ Terminal control for the FREE local (Ollama) brain
**Files:** `LLM/OllamaClient.swift`, `LLM/LocalLLM.swift`, `Tools/ShellTool.swift` + brain pref set to `apple` (ops)
**What & why:** Owner: "I want my AI to control the terminal." It already could — but ONLY on Apple Intelligence (the only brain wired to the tool-enabled `ChatSession`); on Ollama/cloud it just suggested the command as text. Owner picked "Both": (1) **switch now** — set `set_brainPreference = apple` via `defaults` so Apple Intelligence (which supports tool-calling) drives + runs `run_terminal_command`; (2) **build it for the free local brain** — added Ollama function-calling: `OllamaClient.chatTurn(bodyData:)` hits `/api/chat` with a `tools` array and parses `message.tool_calls` (handles both the object- and string-arguments shapes); `LocalLLM.chatOllamaWithTools` runs the propose→approve→run→feed-back loop (≤5 rounds) and `ollamaReply` routes the local tier through it (falling back to plain chat). Both brains execute through the SAME safety path — extracted `Shell.runApproved(_:)` (blocked-command list → `CommandApprovalCenter` approval card → run → report), and refactored the FM `RunTerminalCommandTool.call` to call it too (one executor, zero divergence). Sendable-safe: the caller serializes the `[[String:Any]]` body to `Data` so the non-Sendable dicts never cross into the `nonisolated` client.
**Result:** Build + full suite green; relaunched. qwen2.5-coder now actually runs commands (e.g. "what's my macOS version" → it calls `sw_vers`, you approve, it reports back), with the same approval gate + destructive-command refusals as Apple Intelligence. Tidied a cosmetic `nonisolated(unsafe)`-on-`Void` warning. NOT done: only `run_terminal_command` is exposed to Ollama tool-calling (not web/vision/etc.) — terminal was the ask; the others can be added to `terminalToolSpec`'s array later.

## 2026-06-05 · Autonomous "improve more" pass — chat a11y, Autonomous glass-hero, banner re-tone
**Files:** `Views/ContentView.swift`, `Views/AgentsView.swift`, `Views/LiveTranscriptionView.swift`
**What & why:** Owner: "improve more and more nd more — go autonomous mode." Three focused, low-risk polish moves, each verified with a green build. **(1) Chat a11y — ungated Copy / Regenerate.** The bubble action row had `if hovering { actionButton(...) }`, which removes the buttons from the view tree entirely — VoiceOver + keyboard users couldn't reach them since hover is a pointer-only signal. Switched to always-mounted with `.opacity(hovering ? 1 : 0.45)`: discoverable, focusable, accessible, while still visually receding when the user isn't pointing at the row. Also added `.lineSpacing(2)` on the assistant `MarkdownText` for calmer long-reply rhythm (was the one missed item from the Wave 3a plan), and mirrored the same `.lineSpacing(2)` on `StreamingBubble`'s `MarkdownText` — without parity the line rhythm would jump the moment streaming finishes and the bubble finalises. **(2) AgentsView Autonomous control → glass hero.** Was a plain `Card` with an off-brand yellow sparkle (the page's *lead* element looked like every other section). Rewrote chrome only (protected `toggleAutonomousRun` / `sendDirectCommand` / autonomous `Task` verbatim): brand-tinted sparkle in a blurred-Circle halo + 18pt rounded-bold title; container is a layered glass — neutral `DS.Palette.surface` base + diagonal accent→accent2→clear gradient wash + `DS.Palette.accent` stroke @ 0.35 + `dsShadow(DS.Elevation.accentGlow(0.35))`; "Send direct command" TextField swapped its hardcoded `Color.white.opacity(0.08)` for tokenized `DS.Palette.surface` + `surfaceStroke`. **(3) LiveTranscriptionView permission banner.** Hardcoded `Color.yellow` icon + `Color.yellow.opacity(0.12)` background — off-brand on a red app. Re-toned to `DS.Palette.accent` + accent-tinted bg + 30%-accent stroke; "Open Settings" button got the brand tint too. (Apple Music uses red as its caution color, so this stays *more* cautionary, not less.)
**Result:** Build + full suite green; relaunched. The Agents tab now has a clear visual hierarchy (Autonomous card reads as the page's hero, not a peer of the agent grid); hover-only controls are gone (this is the second a11y regression where a "polish" decision had blocked assistive-tech users — same pattern as the earlier focus-ring contrast fix); the screen-recording banner harmonizes with the brand. Token-discipline note: the chat input bar still uses raw `cornerRadius: 22` (no clean DS match — `field=20` is close but visually shifts the bar), and `Color(red:0.13,green:0.09,blue:0.11)` appears once in ContentView — both kept as-is, since a token sweep without taste regresses rhythm. The only remaining warning is in `BrainPreferenceTestLock.swift` (Chat A's lane) — `nonisolated(unsafe)` on a `Sendable` NSLock, left for that session.

---

## 2026-06-05 · 📝 Markdown headings/lists rendering + 🌐 web tools for the local brain
**Files:** `Views/MarkdownText.swift`, `LLM/LocalLLM.swift`, `LLM/OllamaClient.swift`, `Tools/ShellTool.swift`
**What & why:** Owner: "continue improving the design… also [web tools]… go autonomous mode." Two verified wins this round. **(1) Markdown block rendering (design).** `MarkdownText` already did inline markdown (bold/italic/code/links) via `AttributedString`, but rendered the whole text segment as ONE `Text` — so `##` headings and `- `/`1.` lists showed as literal "##"/"-". Replaced the single `Text` with a per-line `lineView` that classifies each line by prefix: headings (`#`/`##`/`###` → 19/16/14.5pt rounded-bold white), bullets (`- `/`* `/`• ` → accent "•" + indented text), numbered (`12. ` → accent marker, with a guard so `3.14` isn't mistaken for a list) — inline markdown still layered *within* each line. Every multi-section reply now reads as real document structure. (Follow-up, same round: also **blockquotes** `>` → accent left-bar + muted text, and **horizontal rules** `---`/`***`/`___` → a hairline divider.) **(2) Web tools for the Ollama brain (capability, builds on terminal control).** Extended the Ollama `/api/chat` tool loop: when `ToolPolicy.isExternalAllowed` (web on AND not Offline mode), the local qwen brain is also offered `web_search` (DuckDuckGo) + `fetch_url` (with its SSRF guard) alongside `run_terminal_command`. Executor `switch` routes them to the existing `Web.search`/`Web.fetch`; defense-in-depth re-checks `isExternalAllowed` at execution even though the spec is only sent when allowed. So the free local brain can now search → read → run the terminal, end-to-end.
**Result:** Build + full suite green (after a re-run: an initial run flaked on the two subprocess-spawning tests — `ShellToolTests.runHonoursTimeout` + `OllamaRAMBenchmarkTests` — because a chained `pkill`/relaunch raced the parallel session's test run on shared DerivedData; standalone re-run was clean). Relaunched. **Lesson logged:** never chain `pkill -f "Salehman AI"` + `open` in the same command as `xcodebuild test`. NOT done: only terminal + web tools are exposed to Ollama tool-calling (not vision/self-improve/write-code) — terminal + web were the asks; the others can join `toolSpecs` later.

---

## 2026-06-05 · 🛡️ Audit-driven hardening wave (solo) — security + a11y + LLM correctness
**Files:** `Tools/ShellTool.swift`, `Tools/CommandApprovalCenter.swift`, `Tools/WebTools.swift`, `DesignSystem/DesignSystem.swift`, `LLM/LocalLLM.swift`, `Agents/AgentPipeline.swift`, `Salehman AITests/Salehman_AITests.swift`, `Salehman AITests/SecurityHardeningTests.swift`
**What & why:** Owner: "never stop … you're working alone now" + ultracode. Ran an exhaustive **multi-agent audit workflow** (8 dimensions × parallel finders → a skeptic agent refuting each finding against live code → ranked plan): 96 findings proposed, **84 verified real**, 27-item plan. Now solo (parallel session gone), so the plan's collision/lane deferrals are moot — implemented top-down, keeping only the streaming-path byte-care. This wave (audit ranks 1–5, 8, 12–15):
- **ShellTool blocklist (rank 1):** two-layer matching — dangerous *substrings* (anywhere, so `foo; rm -rf /` is caught) + dangerous *command names* matched as the leading token of each `;`/`&&`/`|`-split segment (catches `x && sudo rm`, `/sbin/reboot` path-prefix, and the `eval $X` indirection bypass). Expanded coverage (chmod -R/chown -R/chgrp/launchctl/diskutil reformat/spctl/nvram/su/doas/poweroff/fdisk). Deliberately kept `/dev/disk` blunt (over-block a rare raw-disk *read* beats letting a *wipe* through). +11 tests (rank 2): case-insensitivity, chaining, path-prefix, indirection, and NO over-blocking of `chmod +x`/`git commit -m 'halt…'`/`ps aux | grep`.
- **CommandApprovalCenter (rank 3):** the card's "Always run" used to flip the *persisted* `confirmationEnabled` off **forever** — one tap permanently disabled the shell gate across launches. Split the two consents: `confirmationEnabled` stays the durable Settings/chip pref; "Always run" now sets an in-memory `sessionBypass` that resets on `didResignActiveNotification` (app loses focus) + at launch, and **never** applies to risky commands (`looksRisky`).
- **WebTools SSRF (rank 4):** `URLSession.shared` silently follows redirects → a public host could `301 → http://127.0.0.1:11434`. Added a `RedirectGuard` URLSession delegate that re-runs the denylist on every redirect target (cancels internal ones) + re-validates the final `response.url`. Also closed an IPv4-mapped-IPv6 hole (`::ffff:127.0.0.1`) by extracting the embedded v4 and reusing the v4 denylist; made `ssrfRejectionReason`/`isPrivateIPv4` internal. +SSRF unit tests (rank 5): IPv6 private/mapped, public-passes, v4 classifier (deterministic, no network).
- **CircleIconButton (ranks 14/15):** macOS `.help()` is only a tooltip — every icon-only button (~7: Send, export, search, settings, new-chat, live, mic) was unlabeled for VoiceOver. Added `.accessibilityLabel` (defaults to `help`). Disabled state now desaturates the glyph + drops the brand gradient/glow (not just half-opacity), so a disabled Send reads clearly inactive. One edit cascades to all callers.
- **LLM correctness (ranks 12/13):** `ChatSession.respond` retry path stopped masking the retry error with `try?` — now distinguishes transient (retry succeeds) from persistent (retry also throws → surfaces both causes); preserves the bracketed-failure contract, doesn't touch `offMessage`. Extracted `freeAnswerErrorMarkers`; `recordSuccess` uses explicit `removeValue`.
- **AgentPipeline (rank 8):** scattered magic numbers (4000/8/700/110/40/200/30/300) → a documented `Thresholds` enum.
**Result:** Build + full suite green (caught + fixed one compile error mid-wave: `self.session?` vs the `guard let session` shadow). Relaunched. The audit's remaining ranks (6,7,9,11,16–27: more test coverage, DS token cascades, Views a11y/perf, Dynamic Type) are queued for the next waves. Audit output: `tasks/w5k9eqs2g.output`.

---

## 2026-06-05 · 🧪 Audit Wave 2 — test seams for security/OOM/cooldown invariants + DRY bytes-per-GB
**Files:** `Agents/AgentPipeline.swift`, `LLM/LocalLLM.swift`, `LLM/MemoryManager.swift`, `App/AppSettings.swift`, `Salehman AITests/AgentPipelineConcurrencyTests.swift` (new), `Salehman AITests/OllamaToolGateTests.swift` (new), `Salehman AITests/FreeAutoCooldownTests.swift` (new)
**What & why:** Continuing the audit-plan implementation autonomously. Wave 2 = pure-helper extractions + tests that lock in three invariants the codebase had no test coverage for, plus one DRY constant:
- **`AgentPipeline.effectiveCap(brain:baseCap:)` (audit rank 7).** The pipeline forces serial execution on `.ollamaCoder` regardless of the `MemoryManager` base cap — the line that prevents a 16 GB Mac from going OOM and freezing WindowServer during multi-agent fan-out. Extracted as a `nonisolated static` pure function; the cap site (was `let cap = (brain == .ollamaCoder) ? 1 : baseCap`) now reads `Self.effectiveCap(brain:baseCap:)`, with `max(1, ...)` folded into the helper so cap-of-0 from a degenerate `MemoryManager` can't hang the pipeline. **+3 tests** sweeping across baseCap=1/2/4/8/16 (not a single value — a single-value test would still pass if the `.ollamaCoder` branch were *removed* entirely, since baseCap=1 happens to produce cap=1; the sweep verifies the cap is forced to 1 *specifically* for Ollama).
- **`LocalLLM.ollamaToolNames(externalAllowed:)` (audit rank 6b).** Sendable mirror of `ollamaToolSpecs` exposing just the tool names — the security-relevant property ("the local brain never even *sees* web tools while offline") is the set of names, but `[[String: Any]]` isn't trivially assertable. Names are *derived* from the specs so the two stay in lockstep when a future tool is added. **+3 tests**: offline → `["run_terminal_command"]` only; online → terminal+web_search+fetch_url; names/specs count consistency.
- **`LocalLLM.FreeAutoCooldown` lifted from `private` → `internal` (audit rank 6d).** The actor's `cooling(_:now:)` API already injects the clock as a parameter — that's the textbook clock-injection seam, the only thing needed was visibility for `@testable import`. **+4 tests** pinning the exact 120 s boundary (119.9 s still cooling, 120.1 s cleared) and `recordSuccess` clearing the mark *immediately* even mid-window so a self-healed brain isn't penalized. Each test instantiates its own actor (Swift Testing parallelizes by default; reaching for `.shared` would race).
- **`ByteConstants.bytesPerGB` (audit rank 11).** Centralized the `1_073_741_824` literal that was inlined in three files (`LocalLLM.swift`, `MemoryManager.swift`, `AppSettings.swift`). Living in `MemoryManager.swift` since that's the memory subsystem; the magic literal isn't self-documenting and three copies drift the day someone "tunes" one without grepping the other two.
**Result:** Build + full suite green; relaunched (lesson from the prior wave applied — `pkill`/`open` run as a separate command from `xcodebuild test`, no flake). Deferred: audit rank 9 (`@Sendable` streaming-closure nesting) — load-bearing per its own doc, low value, would touch the protected streaming path; explicitly skipped. Remaining: audit ranks 16–27 (DS token cascades, Views a11y/perf, Dynamic Type, polish) — Wave 3.

---

## 2026-06-05 · 🙈 Hide every paid API + Wave 2 seams (solo, ultracode)
**Files:** `App/AppSettings.swift`, `Views/SettingsView.swift`, `LLM/LocalLLM.swift`, `Agents/AgentPipeline.swift`, `Salehman AITests/ToolLoopTests.swift` (new)
**What & why:** **(1) Hide every paid API** (owner request). Added `BrainPreference.isPaid` (`.claudeHaiku`/`.grok`/`.codex`/`.copilot`) + `selectableCases` (= `allCases` minus paid) as the single source of truth. The Brain picker grid now iterates `selectableCases`, and the entire "Paid keys" Settings group is unmounted. Free-tier clouds (Gemini/Groq/Mistral/Cerebras/OpenRouter), local brains, and the orchestration modes stay. Reversible: the paid key-entry rows + `showPaidKeys` are retained, just not rendered; restore by re-adding one `collapsibleGroup`. **+`PaidBrainHidingTests`** pins the paid set + that `selectableCases` never leaks one. **(2) Wave 2 testability seams** — extracted three pure functions so audit-flagged behaviors are unit-testable: `AgentPipeline.effectiveCap(brain:baseCap:)` (the Ollama-serial OOM guard, rank 7), `LocalLLM.ollamaToolSpecs(externalAllowed:)` (the web-tool gate, rank 6b), `LocalLLM.isStillCooling(failedAt:now:window:)` (the FreeAuto cooldown window, rank 6d). Each is wired into the production call site (no behavior change) + covered in `ToolLoopTests.swift`.
**Result:** Build + full suite green; relaunched. **Heavy convergence with the now-departed parallel session:** it had already shipped much of Wave 2 — `AgentPipelineConcurrencyTests`, `OllamaToolGateTests`/`OllamaToolCallParsingTests`, a `FreeAutoCooldownTests` (it lifted the actor to `internal`; I extracted a pure `isStillCooling` — both coexist), `ByteConstants.bytesPerGB` (rank 11), and the `DS.Palette.modalBG`/`surfaceAlt` tokens (rank 16). Renamed my colliding `FreeAutoCooldownTests` → `CooldownWindowSeamTests`; my seams + tests are kept as complementary coverage. Deferred (unchanged): rank 9. Remaining: Wave 3 — the rank 16 token *call-site migrations* (20/21/22) + Views a11y/perf (17/18/19/23/24/25) + Dynamic Type (26).
**Now solo** — `COORDINATION.md`'s two-session lane model no longer applies; future edits can touch any file (streaming-path byte-care still stands as a correctness rule).

---

## 2026-06-05 · 🎨 Audit Wave 3 + dramatic UI pass — DS tokens + perf + a11y + signature moments
**Files:** `DesignSystem/DesignSystem.swift`, `Views/BackgroundView.swift`, `Views/ContentView.swift`, `Views/SettingsView.swift`, `Views/AgentsView.swift`, `Views/LiveTranscriptionView.swift`
**What & why:** Owner: "improve the gui ui/ux dramatically" + autonomous audit-plan continuation. Combines the remaining safe audit items with a focused dramatic pass on the *visible heartbeat* moments (status + waiting + first impression):
- **New DS tokens (audit rank 16).** `DS.Palette.modalBG` (the warm-dark lifted surface that was inlined as `Color(red:0.13,green:0.09,blue:0.11)` in ContentView) and `DS.Palette.surfaceAlt` (a slightly stronger lifted surface for nested cards). Pure additions — enables the migrations below to be one-liners later.
- **BackgroundView perf (audit rank 19).** Pulled `.drawingGroup()` off the outer `ZStack` and wrapped *just* the two 90 px blur circles. The expensive blur convolution now rasterizes into a cached texture ONCE; the cheap gradient composites natively on top, instead of being re-rasterized along with the blurs every time anything upstream invalidates. Both layers are state-free, so the cached texture survives all parent redraws.
- **A11y for Pickers/Toggles (audit rank 22).** `Picker("", ...)` everywhere → `Picker("Grok model", ...)` / `Picker("Gemini model", ...)` / `Picker("Voice", ...)` / `Picker("\(displayName) model", ...)` with `.labelsHidden()` preserving the visual look. The `toggle(...)` helper got `.accessibilityLabel(title)` (`labelsHidden()` drops the visual label from VoiceOver too). AgentsView "Autonomous Mode" Toggle got a real title.
- **LiveTranscriptionView a11y + contrast + radii (audit rank 17).** Search TextField got `.accessibilityLabel("Search transcript")` (placeholder isn't enough). Live-partial opacity 0.55 → 0.66 (measured ~3.9:1 → ~5.7:1, clearing WCAG AA 4.5:1 for body text). Hardcoded `cornerRadius: 10` (×3) → `DS.Radius.small`.
- **ContentView token migrations (audit rank 20, protected lines skipped).** ApprovalCard literal → `DS.Palette.modalBG`; image/approval-card `cornerRadius:12` → `DS.Radius.chip`; AgentRunView `Color.white.opacity(0.06)` → `DS.Palette.surfaceAlt`. The protected streaming lines (`StreamingBubble` shadow, the `.id("typing")` chain) stayed byte-identical.
- **🎭 Dramatic pass — the visible heartbeat:**
  - **`BrainStatusDot` (new).** Replaces the inline header circle. Was off-brand purple + flat shadow; now tracks `brain.dotColor` when idle and flips to `DS.Palette.accent` while running, with a halo that EXPANDS (12 → 22 px) and pulse-breathes. Cinematic "AI is thinking" signal in the chrome.
  - **`TypingIndicator` rewrite.** Avatar gets a 58 px brand-accent halo that breathes (`scaleEffect` + opacity, 1.4 s sine); dots became `LinearGradient([accent, accent2])` instead of generic white; bubble has a 0.22-opacity accent stroke. The view enters with `.transition(.opacity.combined(with: .scale(scale: 0.94, anchor: .leading)))`.
  - **`EmptyStateLogo` (new).** Pulled the empty-state hero ZStack into its own subview so the `breathing` `@State` is scoped to the empty state (doesn't survive once the user starts chatting). 3.5 s sine scale on the brand tile makes the first-screen logo feel *alive*.
**Result:** Build + full suite green; relaunched. The TypingIndicator + brain dot are now the cinematic center of "Salehman AI is working"; the empty-state logo breathes. Deferred from this pass: audit ranks 23/24/25 (ContentView/AgentsView per-frame re-eval extractions — higher-risk, touch the protected scroll triggers + ContentView body re-evaluation paths), rank 21 (SettingsView status-color dedupe + `successSoft`/`warningSoft`/`danger` token migration — ~10 call sites, candidate for a focused next wave), rank 26 (incremental Dynamic Type via `@ScaledMetric`), rank 27 (opportunistic polish).

---

## 2026-06-05 · 🧹 Audit Wave 3 follow-on — status-color dedupe, Stop confirmation, contrast polish
**Files:** `Views/SettingsView.swift`, `Views/AgentsView.swift`, `Views/ContentView.swift`, `Views/MarkdownText.swift`
**What & why:** Continuing the autonomous audit-plan implementation. Picked the remaining safe items where the value/risk ratio is high:
- **Rank 21 — SettingsView status colors + grok helper dedupe.** Two parallel test-status helper trees existed: `grokTestStatusText`/`grokTestStatusColor` (lines 600/741) byte-identical to the shared `testStatusText(_:)`/`testStatusColor(_:)` (lines 853/861). Deleted the grok copies and pointed the call sites (575, 577) at the shared helpers. Token-migrated the shared `testStatusColor`: full-saturation `.green`/`.orange` → `DS.Palette.successSoft`/`warningSoft` (the desaturated tokens specifically created for inline status indicators where full saturation reads as alarming on the dark canvas — see DS.Palette docstring). One edit cascades to all SEVEN cloud-provider test rows.
- **Rank 25 (partial) — Stop-confirmation dialog on Autonomous Run.** The autonomous-run Stop button had no guard: an accidental click discarded mid-iteration work. Added `@State showStopConfirm` + a `.confirmationDialog("Stop the autonomous run?", role: .destructive)`. Starting is still a single tap (no confirmation needed — it's the safe direction); stopping requires the explicit Stop choice. Cancels show "Keep running."
- **Rank 27 polish — contrast + hit-target wins:**
  - **TimeSeparator** opacity 0.45 → 0.66 (measured ~3.0 → ~5.7:1, clears AA 4.5:1 for large secondary text). Same bump as the LiveTranscription live-partial line.
  - **CodeBlock Copy button** got a comfortable hit target: `.frame(minWidth: 56, minHeight: 24)` + `.contentShape(Rectangle())` so the whole zone is clickable (the bare 10pt `Label` was hard to land on with assistive pointers / Voice Control). Plus `.help` tooltip + explicit `.accessibilityLabel("Copy code to clipboard")`.
**Result:** Build + full suite green; relaunched. Deferred from this pass (lower value / higher risk): rank 23 (ContentView header/input subview extraction — touches body tree near the protected scroll path), rank 24 (cache `filteredMessages` + disable-input-while-running — the input-disable UX is debatable since Claude.ai/most chat UIs intentionally keep the input live while streaming so users can draft the next message), rank 26 (Dynamic Type via `@ScaledMetric` — needs a sweep across many `.font(.system(size:))` sites; better as a focused refactor with measured-at-150%/200% verification).

---

## 2026-06-05 · 🧠 "Salehman (your model)" — run your OWN local model, nothing else
**Files:** `App/AppSettings.swift`, `LLM/OllamaClient.swift`, `LLM/LocalLLM.swift`, `LLM/BrainStatus.swift`, `Agents/AgentPipeline.swift`, `Views/SettingsView.swift`
**What & why:** Owner: "I wanna run my AI model salehman, not anything else — add it to the settings." Added a first-class **`BrainPreference.salehman`** brain backed by a user-configurable Ollama model name (`AppSettings.customModelName`, default `"salehman"`, persisted; `customModelNameCurrent` nonisolated accessor). New Settings section **"Your model (Salehman)"** with a text field for the model name + guidance to `ollama pull` / Modelfile it; the brain auto-appears in the picker grid (it's non-paid, so `selectableCases` includes it). **Exclusivity is the whole point:** `OllamaClient.activeChatModel()` returns the custom model ONLY when `.salehman` is pinned (and actually pulled) — never silently falling back to qwen — and `chat`/`chatStream`/`chatOllamaWithTools` all resolve through it. `LocalLLM`'s `chat`/`generate`/`generateStreaming` got a dedicated `salehmanAllowed` branch that runs the custom model and returns `offMessage` on failure (no Apple/qwen/cloud fallback). Brain enum `.salehman` + `currentBrain` (only reachable when `OllamaClient.hasCustomModel()`), `currentBrainLabel` ("Local · <name> (your model)"), `unavailableMessage` (names the missing model + the `ollama pull` remedy), `BrainStatus.dotColor` (brand red), and `AgentPipeline.effectiveCap` (serial cap-1 OOM guard — it's an Ollama model like qwen) all handle it. Offline mode does NOT block it (it's local). The model also drives the whole agent pipeline + tool loop (terminal/web) when pinned.
**Result:** Build + full suite green; relaunched. (Fixed two mid-build errors: `&&`-autoclosure can't `await` → guard form; and `SettingsView.brainReady` exhaustive-switch needed the case — used a synchronous proxy `ollamaUp && nameSet`, exact "is it pulled" stays the async runtime check.) **Two-session note:** `LLM/*` + `Views/SettingsView.swift` + `BrainStatus` are my (Chat B) lane; `AppSettings.swift` add is append-only; `AgentPipeline.effectiveCap` is the one Chat-A-lane touch (1 line, behavior-preserving). **Queued next (owner):** clickable checkmarks to multi-select brains + run multiple in rotation; then "make Salehman the best — add more features."

---

## 2026-06-05 · 🔄 Multi-select brains + rotation
**Files:** `App/AppSettings.swift`, `Views/SettingsView.swift`, `Views/ContentView.swift`
**What & why:** Owner: "a checkmark I can click next to every model so I choose the AIs myself and run multiple in any rotation." Each Brain-grid cell now has a **clickable ✓** (top-left) — a SEPARATE button from the cell's pin tap (ZStack overlay, so they don't fight) — that toggles the brain into `AppSettings.rotationBrains` (persisted `[BrainPreference]`, order = rotation order). When **≥2** are checked (`isRotating`), a banner shows the cycle (`A → B → C`) and `send()` calls `advanceRotation()` once per message, which hops `brainPreference` to the next chosen brain. Mutating the pin REUSES the entire single-pin routing (zero new gates) and the highlighted cell visibly moves so the user sees the rotation. Build + full suite green; relaunched. Limitation logged: rotation cycles through ALL chosen brains even if one is momentarily unreachable (that message shows its unavailable text, the next rotates on) — skip-unavailable needs an async check, deferred.

## 2026-06-05 · 🛑 Honest boundary — "train Salehman 20000×" / "run it without Ollama, alone"
**Files:** none (intentionally — would have been fabricated)
**What & why:** Owner asked to make "Salehman" a standalone model that runs without Ollama/Apple, and to "train it 20000 times." Did NOT implement, because it would be theatre: this app is a **client/orchestrator**, not a trainable model — there are no weights, no dataset, no training loop, and Swift on a Mac can't train an LLM in-app. (Precedent: the earlier `OnDeviceTrainingEngine` was deleted for exactly this reason — "fabricated theater.") A fake progress bar counting to 20000 would lie to the owner. The REAL paths (offered in chat, awaiting the owner's pick): (1) back "Salehman" with **Apple Intelligence** — already a true standalone, on-device, no-Ollama brain; (2) a custom **Ollama Modelfile** that wraps a base model with a Salehman persona/system-prompt (still needs the Ollama runtime); (3) **embed an inference engine** (MLX / llama.cpp) + bundle a small model so the app runs a local model with NO separate Ollama process — a real, sizable project; (4) **fine-tune** a base model OUTSIDE the app (MLX-LM/LoRA on a dataset, on real compute) then import it as an Ollama model — real, but not an in-app button. Logged so the boundary + the honest options are on record.

---

## 2026-06-05 · 🧠 Salehman as a standalone brain (Apple Intelligence + persona, Ollama optional)
**Files:** `LLM/SalehmanPersona.swift` (NEW), `LLM/LocalLLM.swift`, `App/AppSettings.swift`, `Views/SettingsView.swift`
**What & why:** Owner: "I want it even without Ollama, just it alone." Followed Chat B's option-1 path from the previous entry (treat "Salehman" as a brand/persona, swap engine underneath). New `SalehmanPersona.swift` holds a structured, refined system prompt — identity, voice, the critical language-mirror rule (English in → English only; Arabic in → Arabic; never default), expertise areas, honesty + tool-use guidance, formatting. The persona is the brand layer; the engine is implementation detail.
**Wiring:** `chatOllamaWithTools` + `ollamaReply` got an optional `systemPrompt:` override (default unchanged, no behavior change for the existing `.ollama` brain). The three `.salehman` routing branches in `chat()` / `generate()` / `generateStreaming()` now: (1) try the user's custom Ollama model with the Salehman persona if they pulled one, (2) else fall through to **Apple Intelligence with the Salehman persona** via `LanguageModelSession(tools:instructions:)` — no install required, so Salehman works out of the box. No further fallback (no plain Apple-without-persona, no qwen, no cloud — exclusivity preserved). `currentBrain()` now returns `.salehman` when EITHER engine is available; `currentBrainLabel` collapsed to "Salehman · on-device"; `unavailableMessage` rewritten for the dual-engine reality; `SettingsView.brainReady` matches.
**Settings copy:** the section is now "Salehman engine" (was "Your model (Salehman)") with corrected guidance — Apple Intelligence is the default, the Ollama field is optional.
**Result:** Build + full suite green; relaunched. Salehman now answers without Ollama running, identifies as Salehman (never names the underlying model), and the persona's language-mirror rule replaces the previous one-line clause with a properly weighted system-prompt section. Honestly noted in chat: "training 30,000 times" isn't possible in-app (no weights, no compute) — the persona refinement + the existing long-term memory system are the real surfaces where Salehman improves with use.

---

## 2026-06-05 · 🎓 `salehman-training/` — real fine-tuning kit (Unsloth / MLX)
**Files:** `salehman-training/{README.md, Modelfile, dataset.jsonl, finetune_unsloth_colab.py, finetune_mlx.sh}` (new folder; no app code)
**What & why:** Owner picked the real-training path and asked "can I use Unsloth." Yes — but Unsloth is **CUDA-only (no Mac)**, so the kit documents both routes: **Unsloth on a free Colab GPU** and **MLX-LM on Apple Silicon** (the Mac-native equivalent). Honest, runnable artifacts — no faked in-app training. Pipeline: `dataset.jsonl` (chat-format examples in Salehman's voice) → LoRA fine-tune (Unsloth `save_pretrained_gguf` / MLX `lora`+`fuse`+llama.cpp→GGUF) → `ollama create salehman -f Modelfile` → pin "Salehman (your model)". The `Modelfile` doubles as a **persona-only** quick start (`FROM llama3.1:8b`). README corrects "train 20,000 times": it's steps/epochs, and dataset quality > step count (20k steps on few examples overfits). Dovetails with the **parallel session's** same-day rework that made `.salehman` run on **Apple Intelligence with a Salehman persona** (works with no Ollama) — so: persona today (their work), fine-tuned weights when you want them (this kit).
**Result:** Files written (docs/scripts — no build needed). **Boundary held:** real workflow, zero fabricated training.

---

## 2026-06-05 · 🎓 Real Unsloth fine-tuning scaffold for Salehman
**Files:** `training/README.md` (new), `training/salehman_finetune.py` (new), `training/Modelfile.salehman` (new), `training/dataset/salehman_persona.jsonl` (new)
**What & why:** Owner answered the honesty fork with "can i use unsloth" — so I scaffolded the real workflow. `training/` is a complete, runnable Unsloth fine-tuning kit: README documents the end-to-end flow (write dataset → Colab T4 LoRA → GGUF export → `ollama create salehman` → pin Salehman in app), `salehman_finetune.py` is a real cell-marked script that loads `Qwen2.5-7B-Instruct-bnb-4bit`, attaches r=16 / α=32 LoRA on attn+MLP modules, trains via SFTTrainer (2 epochs, LR 2e-4, AdamW-8bit, sensible defaults), eyeballs a sample, and exports Q4_K_M GGUF. `Modelfile.salehman` is the Ollama import (FROM gguf + compact SYSTEM persona excerpt + Qwen2.5 stop tokens + sensible PARAMETERs). `dataset/salehman_persona.jsonl` is 20 seed conversations in Salehman's voice — bilingual EN/AR, includes refusals (the Overwatch-hacks one), terse acknowledgments, code answers, "I don't know" examples — designed to be expanded by the owner to 200-500 for a quality fine-tune. **Honesty boundary preserved:** README is explicit about what LoRA delivers (voice/identity/format — real) vs what it doesn't (new knowledge, smarter reasoning — false promise), no fake progress bars anywhere. Convergence: the parallel session had already built `SalehmanPersona.swift` + wired the persona into `LocalLLM.chat/generate/generateStreaming` so `.salehman` already works via Apple Intelligence with the persona today (no install required); the training/ scaffold is the **second** engine option (custom Ollama model with the user's own weights).
**Result:** Build + scaffold green; no Swift edits this turn (Salehman's persona routing was fully landed by the parallel session — verified by reading current `LocalLLM.currentBrain/chat/generate/generateStreaming` for `.salehman`, all three honor "custom Ollama first → Apple Intelligence with persona → offMessage" with no qwen/cloud fallback). Owner directives addressed: (a) "train it 20000 times" → real LoRA fine-tune scaffold (no theatre); (b) "without Ollama just alone" → already shipped via Apple Intelligence backing; (c) "improve" → real lever via dataset iteration. **Deferred** (next turns): Settings TextEditor to override SalehmanPersona at runtime (user-editable personality), and the rotation feature's skip-unreachable upgrade.

---

## 2026-06-05 · ✨ First-run Onboarding/Welcome flow
**Files:** `Views/OnboardingView.swift` (new), `App/Salehman_AIApp.swift` (small hook)
**What & why:** Owner: "add more features + improve the GUI everywhere." Picked a self-contained, collision-free win (the other session is active in the brain/UI files): a polished first-run welcome that also teaches the app's vision. `OnboardingView` — 4 paged cards (Meet Salehman / Private by design / Choose your brain — or many / It can actually do things), brand-gradient glyph tile with animated `.transition` per page, stretch-pill progress dots, gradient "Get Started" CTA (`.keyboardShortcut(.defaultAction)`), Back/Skip, full a11y label per step. 100% `DS.*` tokens so it re-skins with the design system. Hooked via `@AppStorage("hasSeenOnboarding")` in `Salehman_AIApp` as a one-time `.sheet` over `RootView` (root file is far less contended than ContentView). New file = zero collision; the App-file touch is a tiny additive `.sheet`.
**Result:** Build + full suite green; relaunched with the flag reset so it shows. **Two-session note:** flagged a DUPLICATION in `COORDINATION.md` — both sessions built a fine-tune kit (my `salehman-training/` + their `training/`); the other session is now actively enriching `salehman-training/` (Route C `build_mac.sh`, `validate_dataset.py`, `personas/`), so it's converging there. I've stopped touching both folders to avoid a destructive race; consolidation is the other session's call.

---

## 2026-06-05 · 🧰 Expanded `training/` (personas + validator + Mac pipeline + TIPS) + folder consolidation
**Files:** `training/{personas/*.jsonl, validate_dataset.py, build_mac.sh, finetune_mlx.sh, TIPS.md}`, `training/README.md` (appended section), `COORDINATION.md`; deleted `salehman-training/` (duplicate)
**What & why:** Owner: "more features / improve everywhere" + the prior "use Unsloth." Made the Salehman customisation kit substantially more capable, all in its own folder (zero collision with the parallel session's active Views/LLM/Settings work). Added: **themed persona starters** (`personas/{coder,writer,tutor,casual}.jsonl` — concrete examples in Salehman's voice across four flavors, English+Arabic where it matters), a **dataset validator** (`validate_dataset.py` — catches the silent bugs that waste training time: role typos, empty assistant content, missing-Arabic warning, dataset-too-small overfitting warning; runnable + verified), a **one-command Mac pipeline** (`build_mac.sh` — validate → MLX LoRA → `mlx_lm.fuse` → llama.cpp `convert_hf_to_gguf` → `ollama create salehman` in a single script, with env-var tunables), and a **dataset-craft tips doc** (`TIPS.md` — the practical wisdom most fine-tuning tutorials skip: size rules of thumb, the five common mistakes with fixes, the real iteration loop). **Folder consolidation:** the parallel session had also made a `training/` folder (with Unsloth Colab + 20-row seed dataset); both were untracked. Per their proposal in `COORDINATION.md`, made `training/` canonical, `cp`-merged my files in (updated `build_mac.sh` to reference their `Modelfile.salehman` + `dataset/salehman_persona.jsonl`), `diff`-verified nothing unique was lost, then `rm -rf salehman-training/`. Pinged them in `COORDINATION.md`.
**Result:** One canonical `training/` (no duplicate). Validator on the current data: **50 rows · 0 errors · 6 size-warnings** (accurate — the starters are starters; the warnings tell the user to add their own examples). No app code changed; no build or tests needed.

---

## 2026-06-05 · ⌘K Command Palette
**Files:** `Views/CommandPalette.swift` (new), `App/AppState.swift` (+1 flag), `App/Salehman_AIApp.swift` (⌘K command + sheet)
**What & why:** Owner picked Command Palette as one of three non-colliding lanes ("more features + GUI everywhere"). A searchable ⌘K palette: navigate (Chat/Agents/Markets), New Chat, Settings, Live Transcription, Find, Stop, and a **"Switch brain: X"** row per `BrainPreference.selectableCases` (paid stay hidden — reuses the same gate). Self-contained — it only flips the existing `AppState` edge-trigger flags + sets `brainPreference`, so it adds zero new control paths. Auto-focused search, hover highlight via a `hoveredID`, `esc` hint, full-width empty state, `.keyboardShortcut(.defaultAction)` on Enter runs the top match. Action runs are deferred 0.15s after dismiss so the palette sheet and any follow-on sheet/tab change don't fight. Added `View` menu: ⌘1/2/3 = Chat/Agents/Markets (Markets moved ⌘2→⌘3 to make room for Agents).
**Result:** Build + full suite green; relaunched (press ⌘K). New file + append-only `AppState` flag + a small App-root `.sheet` (stacks cleanly beside the onboarding sheet) — zero collision with the other session's brain/UI work.

---

## 2026-06-05 · 📝 Doc correction — Unsloth now runs on macOS (was wrong)
**Files:** `training/README.md`, `training/finetune_mlx.sh`
**What & why:** Owner pasted Unsloth's current docs, which explicitly state: *"Mac: Training, MLX and GGUF inference are ALL supported."* The kit's `training/README.md` (parallel session's) said the opposite — "Unsloth is CUDA-first … NOT on your Mac" — and called the MLX path "Apple-Silicon-only path (no Colab, no CUDA)." Both were correct when written; both are now wrong. Fixed: rewrote the trade-off paragraph to list THREE Mac routes in order of ease (**Unsloth Studio on Mac** = recommended; **Unsloth on Colab** = no-local-setup; **MLX-LM CLI scripts** = headless/scriptable). Added a new **Step 2a — Unsloth Studio on your Mac** section with the exact `curl … | sh` install + `unsloth studio` launch + Studio UI workflow + the "100 % offline, no telemetry" note from their FAQ. Renamed the "Apple-Silicon-only path" header to "MLX-LM CLI route (headless / scriptable)" with a historical-note callout. Softened the `finetune_mlx.sh` header from "the Mac-native alternative to Unsloth" to "a scriptable/headless Mac route." Doc-only — no app code touched.
**Result:** Kit docs match reality. Lesson logged about technical-doc rot: a confident "X doesn't work on Mac" claim is *exactly* the kind of fact that quietly inverts when a tool releases a new build, so flagging the dated assertion was the right catch by the owner.

---

## 2026-06-05 · 📈 Markets tab wired to StockSage + 🧠 Memory search/copy
**Files:** `Views/MarketsView.swift`, `Views/MemoryView.swift`
**What & why:** Owner picked three non-colliding lanes ("more features + GUI everywhere"); these are 2 of 3 (Command Palette was the first). **Markets (lane 1):** replaced the "coming soon" placeholder with real `StockSage` wiring — `signalList` renders each `StockSageStore.shared.symbol` as a card (ticker, market, latest price, green/red change%, and a `StockSageSignalEngine` **Strong Buy/Buy/Hold/Sell/Strong Sell** pill + confidence%, colored via DS success/warning/danger), the **Briefing** section generates an AI daily briefing (`StockSageBriefingService.generateBriefing`, with the deterministic summary as the resting state), and an honest **"sample data"** banner shows while `isSampleData` (no live feed yet). Heatmap/Portfolio/Alerts get a clean "coming soon" card. The previously-built-but-unwired StockSage subsystem is now visible + interactive. **Memory (lane 3):** added a **search field** (shown when >3 facts, case-insensitive filter + "no match" state) and a **per-fact Copy** button (NSPasteboard) alongside delete; full a11y labels. Pure view additions — no `MemoryStore` API change (pin/edit deferred, they'd need store support).
**Result:** Build + full suite green; relaunched. Both in distinct lanes (Markets = Chat A's StockSage area; MemoryView = a focused sheet) — no clash with the active session's brain/UI work. Owner's "both" (more features + GUI everywhere) delivered across 3 lanes + onboarding + rotation, all this session.

---

## 2026-06-05 · 🟩 Markets heatmap + ⌘/ keyboard-shortcuts sheet
**Files:** `Views/MarketsView.swift`, `Views/ShortcutsView.swift` (new), `App/AppState.swift` (+1 flag), `App/Salehman_AIApp.swift` (⌘/ command + sheet)
**What & why:** Owner: "continue" — two more non-colliding GUI wins. **Heatmap (Markets/`.heatmap`):** a `LazyVGrid` of tiles, one per `StockSageStore` symbol, colored green→red by `changePercent` with opacity scaling to the move magnitude (flat = neutral); ticker + change% per tile, a11y-labeled. Fills the section that was "coming soon"; single-file change in the MarketsView I own — zero hooks, zero collision. **Shortcuts sheet (⌘/):** new `ShortcutsView` — a grouped cheat sheet (General / Navigation / Conversation) of every shortcut, presented as a root sheet via a new `AppState.showShortcutsRequested` flag + a "Keyboard Shortcuts" item in the View menu. Pairs with the ⌘K palette for discoverability. New file + append-only flag + a stacked root `.sheet` (now 3: onboarding, palette, shortcuts) — collision-free.
**Result:** Build + full suite green; relaunched (Markets ⌘3 → Heatmap; ⌘/ anywhere). Continues the "GUI everywhere" pass entirely in new files / my-owned MarketsView, so it never touches the active session's brain/UI work.

---

## 2026-06-05 · 💼 Markets Portfolio (real subsystem, persisted)
**Files:** `StockSage/StockSagePortfolio.swift` (new), `Views/MarketsView.swift` (`.portfolio` section)
**What & why:** Owner: "continue" — the next real (non-cosmetic) feature in the Markets lane. `StockSagePortfolio` is a `@MainActor ObservableObject` holding `PortfolioPosition` records (symbol / shares / per-share cost basis), JSON-persisted in UserDefaults (`add` validates non-blank symbol + positive shares; `remove`/`clear`). The `.portfolio` MarketsView section computes **live value + P&L** against `StockSageStore`'s latest prices (positions whose symbol isn't tracked show "— no price" rather than faking one): a summary card (total value + total P&L %, green/red), an inline add-form (symbol / shares / cost), and per-position rows with value, P&L, and delete. No price coupling in the store — the view does the lookup, so a real feed later "just works."
**Result:** Build + full suite green; relaunched (Markets → Portfolio). Collision-free: new `StockSage/` file (new name) + the `.portfolio` case in the MarketsView I own. The Markets tab now has 4 live sections (Watchlist/All signals, Heatmap, Portfolio, Briefing); Alerts remains the one "coming soon" (needs the `StockSageMonitor` wired + an alerts store — next).

---

## 2026-06-05 · 🧊 Salehman alone — MLX-Swift on-device standalone engine
**Files:** `LLM/MLXSalehmanEngine.swift` (new, ~190 lines), `LLM/LocalLLM.swift` (5 surgical inserts — `currentBrain`/`chat`/`generate`/`generateStreaming`/`unavailableMessage`), `Views/SettingsView.swift` (mlxEngineRow + status text + control + state polling)
**What & why:** Owner: *"why can't I run it alone without Ollama or Apple Intelligence?"* Honest answer was that the app is the *interface*, not the AI — it had no inference engine and no model weights bundled. This change ships the missing piece: a real on-device LLM engine.

**The engine** (`MLXSalehmanEngine.shared`, a Sendable `actor`): wraps Apple's [MLX-Swift](https://github.com/ml-explore/mlx-swift-examples) `LLMModelFactory` + `ModelContainer` + `MLXLMCommon.generate` to run a quantized model directly on Apple Silicon (Neural Engine + GPU). Default model: **Llama 3.2 1B Instruct 4-bit** (~800 MB, ~50–80 tok/s on M-series). Lifecycle: `.unavailable → .downloading(progress) → .loading → .ready`. Persona is applied via `SalehmanPersona.systemPrompt` baked into the `UserInput.messages` system role.

**The wiring** in `LocalLLM` — three call sites (chat / generate / generateStreaming) each get **MLX inserted at the FRONT of the `.salehman` fallback chain**: `MLX standalone → custom Ollama → Apple Intelligence with persona → offMessage`. `currentBrain()` now returns `.salehman` reachable when *any* of the three engines is available. `unavailableMessage` is context-aware: when the MLX package isn't linked, it omits the standalone-engine line (no point telling the user to download when there's no engine to download into).

**The Settings UI** — a new `mlxEngineRow` at the top of the "Salehman engine" section: SF Symbol `cpu.fill` + status text + a context-sensitive control (Download Model button / inline progress bar / loading spinner / "Ready" success chip). When the package isn't linked yet, the control is a warning-tinted "Add package" chip with a tooltip pointing at File → Add Package Dependencies. A `.task(id:)` modifier polls the actor's state every 500 ms while busy and every 5 s when ready — cheap because reads are just an actor property hop.

**The honest tradeoff** vs the previous "Salehman = Apple Intelligence persona" path: Apple's model is already warm in macOS (~0 cost to use), while the MLX engine costs a one-time ~800 MB download and a ~1–2 s cold-start, but **it runs with no Ollama and no Apple Intelligence — truly alone**, even offline. Owner gets to pick per-Mac.

**The build stays green WITHOUT the package added.** Every MLX type sits behind `#if canImport(MLXLLM) && canImport(MLXLMCommon)`; the actor compiles to a stub that always reports `.unavailable("MLX-Swift package not added…")`. So this commit is safe to merge today; the user runs `File → Add Package Dependencies → https://github.com/ml-explore/mlx-swift-examples` once in Xcode, rebuilds, and the same source file lights up. No second-pass code edits.

**Result:** Build + full test suite green; relaunched. Settings → Salehman engine now shows the standalone row with "Add package" hint (because the package hasn't been added yet). Once added, the row reveals the Download Model button + progress bar.

**Setup step (for the user, one time):**
1. Open the project in Xcode.
2. File → Add Package Dependencies… → paste `https://github.com/ml-explore/mlx-swift-examples`
3. Add the **MLXLLM** and **MLXLMCommon** library products to the "Salehman AI" target.
4. Build. Then in Settings → Salehman engine, tap **Download Model**.

---

## 2026-06-05 · 🔔 Markets Alerts (wired to StockSageMonitor) — Markets tab now complete
**Files:** `Views/MarketsView.swift`
**What & why:** Owner: "continue" — the last Markets section. Wired the existing `StockSageMonitor` (cancellable loop + `UNUserNotificationCenter` strong-signal alerts) into a real Alerts UI: a **monitoring toggle** (`start(interval:)`/`stop()`, surfaces the throw as a warning line if notification auth/setup fails), a **"Check now"** button (`runCycle(notify:false)` → shows the strong signals found without firing a notification), and a results list of strong Buy/Sell signals (reuses `recColor`). No new store — it drives the already-built monitor. Also **removed the now-dead `comingSoon`** view (all 6 sections are live, so the `content` switch is exhaustive — dropped the `default`).
**Result:** Build + full suite green; relaunched. **The Markets tab is now fully built** — Watchlist/All (AI signals), Heatmap, Portfolio (persisted, live P&L), Alerts (monitor + notifications), Briefing (AI) — all driven by the StockSage subsystem, all honest about sample-vs-live data. Entirely in the MarketsView I own → zero collision with the active session.

---

## 2026-06-05 · ℹ️ About Salehman AI sheet — capability overview, native About slot
**Files:** `Views/AboutView.swift` (new), `App/AppState.swift` (+1 flag), `App/Salehman_AIApp.swift` (`.appInfo` CommandGroup + sheet), `Views/CommandPalette.swift` (+2 entries: About, Keyboard Shortcuts)
**What & why:** With the Markets tab fully built and the parallel session shipping the **standalone MLX Salehman engine** (#51–54 — truly on-device inference, no Ollama required), the app's capability surface has outgrown what menus can communicate. Added a polished "About Salehman AI" sheet that surfaces five anchor capabilities (private/on-device, many-brains-with-rotation, real tools with approval, Markets, ⌘K everywhere) plus app version pulled live from `Info.plist` (`CFBundleShortVersionString` + `CFBundleVersion`) so future Xcode bumps update the display with no source change. Used `CommandGroup(replacing: .appInfo)` — the macOS-canonical slot — so "About Salehman AI" lands in the app menu top-left exactly like Safari/Mail/Xcode. Also surfaced **Keyboard Shortcuts** and **About** in the ⌘K command palette so discoverability features are themselves discoverable.
**Result:** Build + full suite green; relaunched. The root window now has 4 self-contained sheets (Onboarding · ⌘K Palette · ⌘/ Shortcuts · About) — all driven by `AppState` edge-trigger flags, each ~50 lines of presentation code. New file + 1 append-only `AppState` flag + 1 `CommandGroup` + 1 `.sheet` + 2 palette entries — fully collision-free with the active session's deep MLX/LocalLLM/Settings work.

---

## 2026-06-05 · 🎙️ Hands-Free Voice Mode ("Talk to Salehman") — new module
**Files:** `Voice/VoiceTurn.swift` (new), `Voice/VoiceSession.swift` (new), `Views/VoiceModeView.swift` (new); hooks: `App/AppState.swift`, `App/Salehman_AIApp.swift`, `Views/CommandPalette.swift`
**What & why:** Owner: "start a brand-new feature module." Chose it via a **design workflow** (8 agents: explore extension-points/gaps/services → 4 diverse candidate blueprints → adversarial decide). Winner: **Hands-Free Voice Mode** — the lowest-collision, highest-UX candidate (turns Salehman into an eyes-free voice assistant). A continuous **listen → think → speak → re-listen** loop, ⌘J. `VoiceSession` (@MainActor state machine) consumes the EXISTING singletons only: `SpeechIn` (on-device dictation) via a Combine sink with a 1.2s silence-debounce to detect end-of-utterance, `Orchestrator.runAndReturnResult(mission:)` (the SAME brain/memory/tools path as typed chat — destructured `.output`, the workflow caught the candidate's tuple-vs-String error), and `SpeechOut` (AVSpeech TTS) with re-arm gated on `speakingID == nil` + a 400ms settle so the spoken reply doesn't bleed into the mic. Defensive against `SpeechIn`'s own `isFinal` auto-stop + barge-in (`interrupt()`). `VoiceModeView` is pure DS.* chrome: a phase-colored pulsing orb (accent listening / amber thinking / success speaking), live caption, 3-turn scrollback, `CircleIconButton` controls. Private by default (on-device speech; generation honors the pinned brain / Offline mode like everything else).
**Result:** Build + full suite green **first try**; relaunched (⌘J, Command Palette "Hands-Free Voice", or Conversation menu). **Collision-free by design:** 3 new files (auto-compile via the synchronized group) + 3 append-only hooks (one `AppState` flag, one root `.sheet` + one ⌘J menu item, one CommandPalette entry) — all appended at the end of their lists beside the other session's About-sheet additions, no existing line modified. No tests added: the loop is audio/singleton-integration (no meaningful hardware-free unit test); `VoiceTurn` is a pure model. Mic/Speech entitlements already present (LiveTranscription uses `SpeechIn`).

---

## 2026-06-05 · 🐛 Bug fix — chat bubbles showing wrong recovery instructions
**Files:** `Views/ContentView.swift` (MessageBubble: +`displayedText` computed, MarkdownText/a11y label use it, comment block rewritten)
**What & why:** Owner screenshot: Salehman pinned but unavailable → header correctly says "Salehman selected · turn on Apple Intelligence or pull 'salehman'" (the context-aware `unavailableMessage`), but the chat bubbles show the generic `offMessage` sentinel telling the user to pull `qwen2.5-coder` — a brain they never picked. Root cause: a previous author had *deliberately* removed the sentinel→friendly substitution from `MessageBubble` (kept it in `StreamingBubble`) to avoid stale wording on old replies after a fix; but the comment in `StreamingBubble` still claims "Same substitution as MessageBubble." That trade-off optimized the wrong axis — the failure mode it avoided is rare and mild, the failure mode it created (every reply in the *active* failure state confuses the user) is the bug just observed. Re-introduced the swap as `private var displayedText` (mirroring `StreamingBubble.displayedText` exactly), wired into both the rendered `MarkdownText` and the assistant a11y label, and rewrote the explanatory comment block to record the v1→v2→v3 decision history so the next reader sees the reasoning, not just the policy. Persisted `message.text` stays unmodified — `ChatStore` and `synthesize()`'s `==` check both keep working.
**Result:** Build + full suite green; relaunched. Salehman-pinned failure replies now say *"Salehman needs an on-device engine to run…"* with the user's actual configured model name interpolated, matching the header. **Convergence noted:** parallel session shipped a **⌘J Hands-Free Voice Mode** using the same `AppState` edge-trigger flag + root sheet + Command Palette entry + Conversation-menu shortcut patterns I established for Onboarding/Palette/Shortcuts/About — discoverable abstractions paying off.

---

## 2026-06-05 · 📝 Scratchpad — AI-native Notes & Tasks (new tab + chat tools)
**Files:** `Persistence/ScratchpadStore.swift` (new), `Tools/ScratchpadTool.swift` (new), `Views/ScratchpadView.swift` (new); hooks: `App/AppState.swift` (AppTab `.scratchpad`), `Views/RootView.swift` (lazy branch), `App/Salehman_AIApp.swift` (⌘4), `Tools/ToolPolicy.swift` (4 tools), `Views/CommandPalette.swift` + `Views/ShortcutsView.swift`
**What & why:** Owner: "continue" → the design workflow's **runner-up** module (already blueprinted, no re-run). A **Notes tab (⌘4)** the agents can drive from chat. `ScratchpadStore` (@MainActor ObservableObject, `Note`/`TaskItem` Codable, JSON in Application Support — the MemoryStore pattern) is the single source for BOTH the UI and four Foundation Models tools: `capture_note`, `add_task`, `complete_task`, `list_scratchpad` (modeled on the existing always-on-core tools, registered in `ToolPolicy.activeTools()`). So "add buy milk to my tasks" or "summarize my notes" in chat now actually mutates/reads the Scratchpad — the model reasons over `list_scratchpad`, no new brain path. `ScratchpadView` is DS-tokenized: Tasks/Notes segmented switcher, inline add, checkboxes/strikethrough, delete, and a one-tap **Organize/Summarize** button (`LocalLLM.generate` over the store text, shown inline). Tab slots in via the established `AppTab` + RootView lazy-visit pattern (TabSwitcherBar auto-includes it via `allCases`).
**Result:** Build + full suite green (fixed one `.secondary`/`.white` ternary type mismatch — the recurring `HierarchicalShapeStyle` vs `Color` gotcha); relaunched (⌘4 / Command Palette "Go to Notes"). **Convergence:** the other session completed the `instructionsToolMenu()` descriptions for my 4 tools while I added them to `activeTools()` — verified consistent. Hooks were append-only across the shared files (AppTab case, RootView branch, ToolPolicy appends, menu/palette entries); flagged in COORDINATION.md. No store test added (singleton writes to the real Application Support file → an isolated test would need path injection; same posture as MemoryStore).

---

## 2026-06-05 · 📝 Scratchpad — AI-native Notes & Tasks (new tab, agent-callable)
**Files:** `Persistence/ScratchpadStore.swift` (new), `Tools/ScratchpadTool.swift` (new), `Views/ScratchpadView.swift` (new); hooks: `Tools/ToolPolicy.swift` (activeTools + instructionsToolMenu append), `App/AppState.swift` (+`AppTab.scratchpad`), `Views/RootView.swift` (lazy branch + `visitedScratchpad`), `App/Salehman_AIApp.swift` (⌘4 menu), `Views/CommandPalette.swift` ("Go to Notes"), `Views/ShortcutsView.swift` (⌘4 entry).
**What & why:** The audit workflow's runner-up — Notes + Tasks the **agents can read and update from chat** via Foundation Models tools. `ScratchpadStore` (`@MainActor ObservableObject`, JSON in Application Support — same lifecycle as `MemoryStore`) holds `Note` and `TaskItem` Codable structs and exposes `addNote/addTask/toggleTask/completeTask(matching:)/summaryText()`. Four `Tool` conformances wrap it: `capture_note`, `add_task`, `complete_task` (fuzzy match by title words), `list_scratchpad` (returns the text dump the model summarizes over). Registered as **always-on local core** in `ToolPolicy.activeTools()` AND advertised in `instructionsToolMenu()` so the model knows they exist (forgetting the menu append is the classic silent-failure where the schema has the tool but the brain never calls it). The UI is a Notes tab (`AppTab.scratchpad`, ⌘4): segmented Tasks/Notes picker, inline add bar, check-off + delete, and a context-aware **Organize / Summarize** button that calls `LocalLLM.generate` over the current scratchpad text and shows the AI result inline.
**Result:** Build + full suite green; relaunched. Try `add buy groceries to my tasks` in chat — the agent calls `add_task` → `ScratchpadStore.shared.addTask` → the Notes tab updates live. **Convergence note:** the other session (now shipping `MLXSalehmanEngine` for standalone-Salehman) had already added `AppTab.scratchpad`, the `RootView` branch, the menu/palette/shortcuts entries, and the full `ScratchpadView` UI in parallel — I just filled the last gap (`instructionsToolMenu` lines), so the project went from temporarily build-broken (RootView referenced a not-yet-existing view) to green in one append.
**Note on Unsloth (correcting earlier guidance):** Unsloth Studio added an **MLX backend** that runs on Apple Silicon — the owner has it running locally at `127.0.0.1:8888`. Earlier "Unsloth is CUDA-only" was outdated; the Mac is a first-class fine-tuning target now.

---

## 2026-06-05 · 📚 Knowledge Vault — private on-device document Q&A (new tab)
**Files:** `Knowledge/KnowledgeStore.swift` (new), `Knowledge/SearchDocumentsTool.swift` (new), `Views/KnowledgeView.swift` (new); hooks: `App/AppState.swift` (AppTab `.knowledge`), `Views/RootView.swift` (lazy branch), `App/Salehman_AIApp.swift` (⌘5), `Tools/ToolPolicy.swift` (tool + menu), `Views/CommandPalette.swift` + `Views/ShortcutsView.swift`
**What & why:** Owner: "continue" → the workflow's flagship remaining candidate, scoped for a clean green landing. A **Knowledge tab (⌘5)**: add files (`AttachmentLoader.pickFile` + `.load` extracts text on-device via PDFKit/OCR/utf8), ask a question → a **grounded** answer (LocalLLM over retrieved passages, "cite [n] / say if not present") with tappable sources. `KnowledgeStore` (`@unchecked Sendable` NSLock singleton, MemoryStore pattern) chunks text into ~800-char overlapping passages and ranks with **keyword overlap as the primary signal + an `NLEmbedding` cosine boost when available** (de-risked: works even when sentence embeddings return nil). Embedding + search run **off the main actor** (`Task.detached`) so the UI never blocks. Same vault is reachable from chat via the always-on `search_documents` tool, so the brain can pull cited passages mid-conversation. Fully private — nothing leaves the Mac unless a cloud brain is pinned for the final generation.
**Result:** Build + full suite green **first try**; relaunched (⌘5 / Command Palette "Go to Knowledge"). Deliberately scoped vs the blueprint: keyword-primary retrieval (not embedding-dependent), button-import (drag-drop deferred), embeddings persisted in the JSON. Append-only hooks across the shared files (AppTab, RootView, ToolPolicy, menus); flagged in COORDINATION.md. **Three new modules this run** — Voice Mode (⌘J), Scratchpad (⌘4), Knowledge (⌘5) — all workflow-designed, all green. The app now has 5 tabs + voice + palette + onboarding.

---

## 2026-06-05 · 📎 Knowledge Vault flesh-out — drag-and-drop + paste-text
**Files:** `Views/KnowledgeView.swift` (only — my own module file)
**What & why:** Owner: "continue." Filled the two import gaps the Knowledge blueprint deferred. **Drag-and-drop:** `.onDrop(of: [.fileURL])` with a dashed accent drop-target overlay → `handleDrop` loads each dropped file's URL (`loadDataRepresentation` for `UTType.fileURL`) and routes through the refactored `ingest(_ url:)` (extracted from `addFile`, so button + drop share one path). **Paste text:** a header clipboard button opens a sheet (title + `TextEditor`) → `addPastedText` adds it as a "Text" document. Both ingest off the main actor (`Task.detached`) like the file path.
**Result:** Build + full suite green; relaunched. Single-file change in my own `KnowledgeView` — zero collision. Drop a PDF/txt onto the Knowledge tab or paste notes; both become searchable + answerable.

---

## 2026-06-05 · 📋 Knowledge — `list_documents` rounds out the FM tool trio
**Files:** `Knowledge/ListDocumentsTool.swift` (new, mine), `Tools/ToolPolicy.swift` (registered + menu line — shared lane, append-only).
**What & why:** Final piece of the Knowledge tool surface: `list_documents` enumerates every vault doc with kind + passage count, taking empty `Arguments` (the `@Generable struct Arguments {}` pattern proven by `ListScratchpadTool`). Lets chat answer "what's in my Knowledge?" cheaply and gives the brain a way to **discover** what's available before calling `search_documents` or `get_document` — closes the discoverability gap (no more hallucinating filenames; if it's not in the list it's not there). Honest empty-state ("vault is empty — the user hasn't added any documents yet") instead of returning an empty list.
**Result:** Build + full suite green; relaunched. Knowledge tool trio is now complete:
  • `list_documents` — *what's there*
  • `search_documents` — *relevant passages across the vault*
  • `get_document` — *one whole document by name*

---

## 2026-06-05 · 🔧 Knowledge — `get_document` tool + scoped per-doc Q&A verified
**Files:** `Knowledge/GetDocumentTool.swift` (new, mine), `Tools/ToolPolicy.swift` (registered + menu line — shared lane, append-only); also verified the externally-merged `DocDetailSheet` scoped Q&A (uses the `inDocument:` param I added to `KnowledgeStore.search`) builds + full-suite green.
**What & why:** Added `get_document` as the natural peer of `search_documents` — search returns *passages*, get returns *one whole document* end-to-end, so a chat agent can do "summarize my paper.pdf" or "translate my Q3 notes" without leaving the conversation. Lookup is **case-insensitive substring** (the brain's transcription of a filename doesn't need to be perfect) and **prefers the shortest matching name** (so `"notes"` doesn't lose to `"long-prefix-notes.pdf"` when both contain it). On a miss it returns the **list of available document names** so the brain can self-correct in its next call instead of hallucinating a doc. Capped at 6 000 chars via the same `KnowledgeStore.text(forDocument:)` used by the summary path — no context-window surprises. Always-on local core (no setting flag).
**Result:** Build + full suite green; relaunched. The Knowledge tool surface is now complete: `search_documents` for RAG-style Q&A across the vault, `get_document` for whole-doc operations. Combined with the in-app `DocDetailSheet` (auto-summary + scoped "ask about this doc" Q&A — externally merged, verified by me), the same vault is reachable three ways: chat tools, the global Ask card, and per-doc deep-dive.

---

## 2026-06-05 · 🧾 Knowledge — tap a document for an on-device summary
**Files:** `Knowledge/KnowledgeStore.swift` (+`text(forDocument:maxChars:)`), `Views/KnowledgeView.swift` (doc rows now tappable → `DocDetailSheet`). Both my own module files — zero collision.
**What & why:** Deepened the Knowledge vault instead of widening the app. Tapping a document opens a detail sheet that generates a **faithful 4–6 sentence summary on-device** (`LocalLLM.generate` over the doc's concatenated passages, capped at 6k chars, prompt explicitly forbids inventing details). `KnowledgeStore.text(forDocument:)` reassembles a doc's chunks in ordinal order under the existing NSLock; both the text reassembly and the generation run via `Task.detached` so the sheet stays responsive while the local model works. Row now shows a `sparkles` affordance + "Open & summarize" tooltip; trash button kept separate so deleting doesn't open the sheet.
**Result:** Build + full suite green; relaunched. "Summarize my PDF" now works fully offline. Honest: if a doc had no extractable text, the sheet says so rather than fabricating a summary.

**Follow-up (same sheet):** added **scoped per-document Q&A** — the detail sheet now has an "Ask about this document…" field that retrieves only from this doc (`KnowledgeStore.search` gained a backward-compatible `inDocument: UUID?` filter — existing callers `SearchDocumentsTool`/main Ask card unaffected) and answers grounded in those passages, refusing if the answer isn't present. Distinct from the all-docs Ask card on the main view. Sheet grew 460→540pt; summary + answer share a scroll area. Build + suite green; relaunched.

---

## 2026-06-05 · 🏠 Today — a glanceable home surface tying the app together (⌘6)
**Files:** `Views/TodayView.swift` (new); hooks: `App/AppState.swift` (AppTab `.today` appended → ⌘6, **Chat stays the default landing**), `Views/RootView.swift` (lazy branch + `refresh()` on entry), `App/Salehman_AIApp.swift` (⌘6), `Views/CommandPalette.swift` + `Views/ShortcutsView.swift`.
**What & why:** Owner chose "keep going autonomously." With 5 surfaces now, the app lacked a connective overview. **Today** is a read-only dashboard: a **time-of-day greeting** (morning/afternoon/evening/working-late via `Calendar` hour), a **Quick Actions** grid (New Chat, Hands-Free Voice, Add to Knowledge, New Note — each flips the *same* `AppState` edge-trigger flags the menu bar/palette use, so behaviour is identical everywhere), and **At a Glance** stat cards reading the **real** on-device stores: notes count + open-task count (`ScratchpadStore`), knowledge document count (`KnowledgeStore`), and market session (`MarketStore` — honestly shows the Phase-1 placeholder's "Closed"). Live stores are `@ObservedObject`; `KnowledgeStore` (not observable) is cached in `@State` and refreshed on tab entry (cheap, no timer). Tiles (`ActionTile`/`StatTile`) own their own hover state and lift/scale on hover via `DS.Motion.press`. Adaptive `LazyVGrid` so it reflows on narrow windows.
**Why a 6th tab was safe now:** the responsive `TabSwitcherBar` (prior entry) auto-raised its collapse threshold for the 6th tab — at the 980pt default the labels still fit (~885pt content), and it collapses to icons *before* clipping as the window narrows. Appended (not prepended) so ⌘1–5 + the default landing don't reshuffle.
**Result:** Build + full suite green **first try**; relaunched. Honest data only — no fabricated metrics; the market card reflects the actual placeholder store until Phase-2 polling ships.

---

## 2026-06-05 · 📐 Responsive TabSwitcherBar — 5+ tabs never clip
**Files:** `Views/TabSwitcherBar.swift` (contended — parallel session's sliding pill; reconciled, not overwritten)
**What & why:** With the tab count now at **5** (Chat/Agents/Markets/Notes/Knowledge), the icon+label pills clipped against the brand + market/settings clusters once the window shrank toward its 720pt `minWidth`. Made the pill row **responsive**: measure the bar's own width via a `GeometryReader` background (window-driven, so it can't feed back into the labels it controls — no layout loop), and when it's below `labelThreshold` collapse unselected pills to **icon-only**, keeping the **selected** pill's label as a persistent "you are here." The threshold **scales with `AppTab.allCases.count`**, so a future 6th/7th tab raises the collapse point automatically instead of silently re-introducing the clip. Labels fade/scale in step with the existing `withAnimation` (selection + resize both animate). Added `.help(tab.title)` so the icon-only state still names each tab on hover; VoiceOver already had `.accessibilityLabel`.
**Protected:** Did **not** touch the `matchedGeometryEffect(id:"tabHighlight")` sliding pill — deliberately avoided `ViewThatFits` (it instantiates both layout branches to measure → two live views fighting over one geometry id). Only the label's presence is conditional; the highlight Capsule structure is byte-unchanged.
**Result:** Build + full suite green; relaunched. Resize narrow → pills collapse to icons with the selected label retained; widen → labels return. Closes the "tab bar gets tight" standing note.

---

## 2026-06-05 · 🖥️ Mac fine-tuning kit — train Salehman on Apple Silicon
**Files (new):** `salehman-training/mac/{README.md, 00_setup.sh, 01_prepare_data.py, 02_train.sh, 03_fuse.sh, 04_to_gguf.sh, 05_import_ollama.sh}`
**What & why:** Owner: "yes add and tell me exactly the steps." Earlier guidance said Unsloth was CUDA-only on Mac, but the canonical Apple-Silicon path is **MLX-LM** (Apple's official package) for LoRA fine-tuning, then fuse + de-quantize → llama.cpp `convert_hf_to_gguf.py` → `ollama create`. The kit is six idempotent scripts plus a numbered README; the dataset (already chat-format, 289 examples) is consumed directly by `mlx_lm.lora --train` once split 90/10 into `data/{train,valid}.jsonl`. Defaults to a 4-bit Llama-3.2-3B base (fits 8 GB RAM, 30–90 min training on M-series); `export MODEL=mlx-community/Qwen2.5-7B-Instruct-4bit` swaps to the bigger base with no other changes. `05_import_ollama.sh` writes a Modelfile mirroring `SalehmanPersona.systemPrompt` and runs `ollama create salehman`, so the app's existing `.salehman` brain (already routed through OllamaClient with the user's custom model name) lights up the moment Settings → custom model name is set to `salehman`. LoRA chosen over full fine-tune because 289 examples × full fine-tune = catastrophic overfit; LoRA's low-rank adapter is the right tool for persona/style at this scale.
**Result:** Files only — no build impact. Standalone pipeline the owner runs from a terminal. Documented pitfalls inline (older mlx-lm `--de-quantize`, non-Llama chat templates, OOM knobs).

---

## 2026-06-05 · 🛡️ Ultracode pass — adversarial self-review → fixes + Home-first + bottom bar
**Mode:** ultracode / XHIGH. Ran a multi-agent **adversarial review workflow** (5 dimensions × independent skeptic verifiers) over the session's new code, then applied the confirmed fixes plus the owner's two new asks in one batch, then ran a second **verification workflow** over the batch.

**Review result:** 7 raw findings → **5 confirmed** after adversarial verification (2 false positives dropped). Fixes applied:
- **🔴 HIGH — privacy/honesty leak (the important one).** `KnowledgeView`'s summary + both Q&A paths called `LocalLLM.generate`, which routes to **paid cloud brains** when one is pinned (or ensemble/freeAuto) — so private document text was POSTed off-device while the UI promised "private, on this Mac" / "ON-DEVICE SUMMARY" / "Nothing leaves the Mac." Violated CLAUDE.md ("no fake on-device features"). **Fix:** added `LocalLLM.generateOnDevice(_:maxTokens:) -> String?` (LLM/LocalLLM.swift) that runs ONLY the local tier (Apple Intelligence → Ollama) and returns nil if no on-device model; all three Knowledge generation sites now use it with an honest `onDeviceUnavailableMessage` fallback instead of silently going to the cloud. The vault's privacy promise is now literally true. (The chat-side `search_documents` tool still feeds passages to whatever brain runs the chat — but that path isn't labeled on-device and follows the user's explicit chat-brain choice, so it's consistent.)
- **🟠 MED — multi-file drop state bug.** `KnowledgeView` used one `@State ingesting: Bool`; dropping N files spawned N ingest Tasks and the first to finish flipped it false (spinner/buttons cleared while others still embedding). **Fix:** `inFlight: Int` counter + computed `ingesting { inFlight > 0 }`; increments/decrements balanced.
- **🟠 MED — accessibility.** Three icon-only buttons (Paste / main Ask / per-doc Ask) had only `.help` (macOS tooltip ≠ VoiceOver name). Added `.accessibilityLabel` to each, matching the file's own convention.

**Owner asks (same batch):**
- **🏠 Home first.** Reordered `AppTab` so **Today is the leftmost tab and ⌘1** (Chat→⌘2 … Knowledge→⌘6); default landing changed to `.today`; Shortcuts sheet + Command Palette reordered (removed a duplicate "Go to Today"). *Files:* `App/AppState.swift`, `App/Salehman_AIApp.swift`, `Views/ShortcutsView.swift`, `Views/CommandPalette.swift`.
- **⌨️ Bottom shortcut bar.** New `Views/BottomShortcutBar.swift` — a slim frosted footer of clickable shortcut hints (⌘K Palette · ⌘N New Chat · ⌘J Voice · ⌘/ Shortcuts · ⌘, Settings), pinned to the bottom of `RootView`'s VStack. Flips the same `AppState` flags as the menu bar.
- **🎙 Voice → Save to Notes.** `VoiceModeView.saveToNotes()` writes `session.turns` to `ScratchpadStore.shared.addNote` with a transient ✓; disabled when there are no turns.

**Result:** Build + full suite green; relaunched. A second adversarial **verification workflow** (5 focus areas × independent skeptic verifiers — the same rig that surfaced 5 real issues on the first pass) ran over the whole batch and returned **0 findings / 0 confirmed — verified clean**: the privacy fix never reaches a cloud client, all three Knowledge sites use `generateOnDevice`, the `inFlight` counter balances (no underflow/stuck state), the AppTab reorder left every switch exhaustive with no stale ⌘ mapping or assumed-default, and the new bottom bar + Voice save-to-Notes introduced no regressions. Default landing is now Today — flagged to the owner in case they prefer launching on Chat.

---

## 2026-06-05 · 🔐 Secret-leak audit (repo clean) + Unsloth Mac BETA correction (training kit + dataset)
**Files:** `salehman-training/mac/README.md`, `salehman-training/dataset_saleh_style.jsonl` (3 chat examples updated). No app code changed.

**Security audit (no code change):** an exposed `sk-proj-` OpenAI key was surfaced via IDE selection from the owner's global `~/.continue/config.yaml` (NOT in this repo). Audited the repo for any matching `sk-(proj|ant|or)-` patterns: 3 files matched — `DEVELOPMENT_LOG.md`, `SOURCE_BUNDLE.md`, `Views/SettingsView.swift`. Verified each match is exactly 12 chars (`sk-ant-api03`) — i.e. the *family prefix only*, used in legitimate non-secret contexts: a `SecureField` placeholder ("sk-ant-…"), the `raw.hasPrefix("sk-ant-")` family-detection check, and doc comments describing the prefix-display UX. **No real secret in the repo.** Owner was advised to rotate the Continue key and replace it with an env-var reference (`apiKey: ${OPENAI_API_KEY}`) so it lives off-disk.

**Unsloth Mac BETA correction (factual integrity):** Unsloth's own docs now state "MacOS: Training, MLX and GGUF inference all work inside of Unsloth." This contradicts what I told the owner earlier this session ("Unsloth is CUDA-only — use Colab/MLX-LM"). That earlier framing leaked into both the kit's README and **the fine-tuning dataset itself** — meaning if we ran training on the unfixed dataset, Salehman would be taught to repeat stale claims like "Unsloth needs an NVIDIA GPU, won't run on Mac." Fixes:
- `mac/README.md`: replaced the "Unsloth Mac is a wrapper around MLX-LM" claim (which I can't substantiate from current docs) with a balanced comparison — Unsloth Studio (BETA, web UI, no-code dataset builder) vs. this kit (CLI, scriptable). Both end at GGUF→Ollama; same final integration point in `Salehman AI`.
- `dataset_saleh_style.jsonl` (3 lines): line 79 ("can i use unsloth") now says Unsloth Studio Mac BETA works, no NVIDIA needed; line 237 ("can i fine tune you") lists three real paths; line 243 ("unsloth wont open") disambiguates Studio vs. Colab in the first response. Validated all 289 lines still parse as chat-format JSONL.

**Result:** Repo is clean of real secrets; training kit + dataset no longer encode the stale "Unsloth = CUDA-only" claim. No app rebuild needed (docs/data only). The Continue config key remains an action item for the owner outside this repo.

---

## 2026-06-06 · 🧠 `.unslothStudio` brain — local OpenAI-compat server as a first-class pin
**Files (~6 + 1 helper):** `LLM/OpenAICompatibleClient.swift` (generalize), `LLM/UnslothStudio.swift` (new namespace), `App/AppSettings.swift` (case + endpoint/model + nonisolated accessors), `LLM/LocalLLM.swift` (gate + 3 dispatcher branches + `generateOnDevice` loopback case + label/availability), `LLM/BrainStatus.swift` (dot color), `Agents/AgentPipeline.swift` (serial cap), `Views/SettingsView.swift` (section + 3 rows + brainReady case).
**What & why:** Owner wants to train Salehman in Unsloth Studio (which serves an OpenAI-compatible API on `localhost:8000/v1`) and chat with it directly — no Ollama detour. Added a `.unslothStudio` BrainPreference case that routes through the existing `OpenAICompatibleClient`, which I **generalized** with `requiresKey: Bool = true` + optional `keychainAccount` so the same client now drives BOTH cloud brains AND unauthenticated local servers (Studio, `mlx_lm.server`, LM Studio, llama.cpp's server — anything OpenAI-compat). Linter caught a Swift trap mid-flight: `let property = default` is **excluded** from the synthesized memberwise init, so `requiresKey` had to be `var` to allow `requiresKey: false` at call time. `UnslothStudio.swift` is a thin nonisolated namespace that builds the client fresh from current settings each call (so edits in Settings take effect instantly, no observer wiring).
**Privacy guard:** A user-typed endpoint URL could accidentally point at a public server, breaking the on-device promise. So `UnslothStudio.isLocalLoopback` only returns true for `localhost`/`127.0.0.1`/`::1`, and `LocalLLM.generateOnDevice` (the Knowledge-vault path) ONLY routes through Studio when that's true. A non-loopback Studio endpoint is still pinnable as a regular brain — it just doesn't qualify for the on-device-only privacy path. The Settings header label also splits "Local · Unsloth Studio" vs "Custom server · Unsloth Studio" based on this.
**Settings UI:** new "Unsloth Studio (local server)" section with an endpoint URL field (+ a `Use :8000` quick-fill button), a model-name field (blank → `"local"` sentinel; most single-model servers ignore it), and a Test button using the file's existing `nil/""/error` status convention.
**Result:** Build + full test suite green; relaunched. Workflow for owner: train in Studio (M4 supports it now per the in-repo training-kit update) → start Studio's server → paste `http://localhost:8000/v1` in Settings → tap "Unsloth Studio" in the Brain grid. Knowledge vault automatically uses Studio for summaries/Q&A when its endpoint is loopback. Pre-existing audit workflow over the previous batch is unchanged and remains in the background queue; this feature is orthogonal.

---

## 2026-06-06 · 🔍 Ultracode app-wide audit → my-lane fixes applied (verification BLOCKED on other session)
**Mode:** ultracode / XHIGH. Ran an app-wide adversarial audit workflow (5 risk dimensions × independent skeptic verifiers): **19 raw → 18 confirmed**, synthesized to 6 prioritized actions and split by lane.
**Fixes I applied (my lane, Chat B):**
- **a11y (×8):** added `.accessibilityLabel` to icon-only controls VoiceOver couldn't name (`.help` is tooltip-only on macOS): ContentView (export/attach/prompt-library Menus, search-clear, attachment-remove), SettingsView (close, test-brain), MemoryView (close), ScratchpadView (Add).
- **P5 (secrets, low):** `SettingsView.anthropicSubtitle` now only echoes the key prefix when it actually starts with `sk-ant-`; a misfiled wrong-service key shows `sk-…` (never its secret bytes).
- **P6 (concurrency, low):** `SettingsView.testActiveBrain()` — the KnowledgeView reentrant-flag bug class. Now captures the pinned brain before the `await` and only the run still matching the current pin publishes its verdict + clears the flag, so a superseded run (user switched mid-ping) can't clear the spinner early or write a stale brain's result.
- **Build unblock:** `OpenAICompatibleClient.requiresKey` was `let … = true` (excluded from the memberwise init → `requiresKey: false` didn't compile, contradicting its own doc comment). Changed to `var`.
**Cross-lane (Chat A) — FLAGGED in COORDINATION with exact fixes, NOT edited:** 🔴 StockSage briefing leaks tracked-symbol facts to the pinned cloud brain while claiming "on-device" (same class as the Knowledge bug → use `generateOnDevice`); 🔴 LiveTranscription footer hard-codes "On-device" but routes `ar-SA` audio to Apple's servers; 🟠 Markets "AI buy/hold/sell signals" + "% conf" is a deterministic threshold, not AI; 🟢 SpeechIn on-device comment/flag mismatch; plus a11y on MarketsView/LiveTranscriptionView.
**Status — NOT green:** the shared tree is currently red from the other session's **in-progress Unsloth Studio** refactor (`SettingsView` non-exhaustive `brainReady` switch missing `.unslothStudio`, a Keychain-optional unwrap, cascading "rows not in scope"). These are NOT my edits. Per owner decision (2026-06-06), the other session owns Unsloth Studio and will finish it; **my fixes above are applied but UNVERIFIED until their work lands green.** Will build/test/relaunch + adversarial-verify the moment the tree compiles.

---

## 2026-06-06 · 🤝 Added GROK_SESSION_PROMPT.md — onboarding for a 3rd (Grok) build session
**Files:** `GROK_SESSION_PROMPT.md` (new doc). No code/build impact.
**What & why:** Owner is adding a **third** parallel build session (Grok) alongside the two Claude Code sessions. Wrote a self-contained operating prompt that transfers: the 6 docs to read first, the non-negotiable rules (log every change, leave it green, Keychain-only secrets, `.auto` local-first, no fabricated AI, keep KB current), the canonical build/test commands, the now-**three**-session coordination model + a proposed Grok lane (tests + new modules + docs, claim in COORDINATION), the working discipline (read-before-edit, verify-don't-claim, adversarial self-review, small green increments), Swift 6 `-default-isolation=MainActor` gotchas, and the hard-won domain landmines (the `generateOnDevice` on-device-only rule, honest UI copy, the shared-flag concurrency bug class, `.help` ≠ VoiceOver label). Satisfies CLAUDE.md's "before handing the app to an external AI" directive.
**Result:** Doc only. (Build remains red from the other session's in-progress Unsloth Studio — unchanged by this; see entry above.)

---

## 2026-06-06 · 🛡️ Cross-lane audit fixes landed (Unsloth Studio refactor green'd the tree) + adversarial re-verification
**Context:** the prior entry left my audit fixes "applied but unverified" because the tree was red from the other session's in-progress Unsloth Studio refactor. That work landed (brainReady is now exhaustive incl. `.salehman`/`.unslothStudio`, unslothStudio rows in scope, the two `.keychainAccount` access sites are correctly `guard let`-unwrapped), and the tree returned to green. Owner: "go" — single-session for the remaining cross-lane fixes.

**Cross-lane batch applied (the audit's HIGH+MED items):**
- **🔴 HIGH — StockSage briefing → on-device only.** `StockSage/StockSageBriefingService.swift::generateBriefing` was calling `LocalLLM.generate` while the tool description + header advertised "on-device / computed locally." Fixed: route through `LocalLLM.generateOnDevice` (Apple Intelligence → Ollama only); deterministic `facts` as the nil fallback. Dropped the `currentBrain() == .none` pre-gate (nil handling supersedes it) and the `offMessage` post-check.
- **🔴 HIGH — Live transcription honest "On-device" label.** Added `@Published var isFullyOnDevice: Bool = true` to `Media/LiveTranscriber.swift`, set to `recs.allSatisfy { $0.recognizer.supportsOnDeviceRecognition }` inside the post-`startCapture` `MainActor.run` block. `Views/LiveTranscriptionView.swift` footer now switches between "On-device • system audio" and "Cloud transcription • system audio (no on-device model for this language)" based on that Bool. Same view: `.accessibilityLabel("Close")` (line 54) + `.accessibilityLabel("Clear search")` (line 119).
- **🟠 MED — MarketsView honesty.** Header "AI buy / hold / sell signals" → "Rule-based momentum signals" (line 43); "% conf" badge → "strength X%" (line 356) since `StockSageSignalEngine` is a deterministic `|Δ%|` threshold; Add-holding `.accessibilityLabel` added (line 232).
- **🟢 LOW — SpeechIn on-device guard.** `Media/SpeechIn.swift::begin` now sets `request.requiresOnDeviceRecognition = true` when `recognizer.supportsOnDeviceRecognition`; comment softened from "(free, on-device)" to a locale-conditional phrasing.

**Adversarial re-verification → 4 confirmed + 2 adjacent, all fixed in a second pass:**
- **`Views/AboutView.swift:31`** still said *"AI buy/hold/sell signals"* in the user-facing capability card → relabelled to match MarketsView.
- **`Views/MarketsView.swift:4`** doc comment still said *"AI signals / AI daily briefing"* → updated to "rule-based momentum signals" + "on-device daily briefing."
- **`Views/SettingsView.swift::testActiveBrain` (real bug in MY prior fix).** The previous capture-and-bail design didn't reset `activeBrainTesting` on the bail path, banking on a successor run to clear it — but `.onChange` only auto-tests *local* brains, so a local→cloud switch leaves a superseded local run that bails and strands the spinner forever. Rewrote to the **in-flight counter pattern** (same shape as the KnowledgeView fix): `@State var activeBrainInFlight: Int = 0`, increment at entry, `defer { -=1; if 0 { testing = false } }`. Spinner now derived from "any run live"; bailing runs decrement; no stuck-on and no premature-clear.
- **MarketsView strength badge for `.hold`.** `SignalEngine` hardcodes `confidence = 0.65` for hold, which would read as "65% strength of doing nothing." Now only render the strength text when `signal.recommendation != .hold`.
- **Adjacent: `StockSage/StockSageScreenAnalysis.swift:70`** also called `LocalLLM.generate` while its doc + status strings claim "on-device" four times (qwen2.5vl vision, "on-device analysis", etc.). Fixed: `generateOnDevice` + honest "isn't available right now" fallback.
- **Adjacent: `Tools/StockSageMini.swift:61`** chat-tool output said *"Verdict: X. Confidence Y%"* for a deterministic heuristic. Relabelled to "Signal strength Y%" for parity with MarketsView.

**Generalized lesson (saved as the "on-device-only generation" memory):** Any feature whose UI promises "on-device / private / local" must call `LocalLLM.generateOnDevice` — not `LocalLLM.generate` (the general dispatcher that routes to whichever brain the user pinned, including paid cloud). The bug we caught in Knowledge appeared in StockSage briefing, StockSage ScreenAnalysis, and (via a different mechanism) the transcription label. The audit's app-wide sweep turned one finding into a closed bug class.

**Result:** Build + full test suite green; relaunched. All 18 audit findings now closed; the second adversarial pass over the cross-lane batch surfaced 4 more (incl. one real bug in my prior reentrancy fix), all now also fixed.

---

## 2026-06-06 · ⌨️ Settings: "Use this model with Claude Code too" disclosure under Unsloth Studio
**Files:** `Views/SettingsView.swift` (+ `claudeCodeUsageRow` + one-line section hook).
**What & why:** Owner shared https://unsloth.ai/docs/basics/claude-code — Unsloth Studio also exposes an **Anthropic-compatible** endpoint (default `:8888`) alongside the OpenAI-compatible one (`:8000/v1`) this app uses. So the same running Studio process can back BOTH this app's chat AND Claude Code (the terminal coding agent). Added a collapsed `DisclosureGroup` inside the existing Unsloth Studio section: explains the dual-endpoint setup, shows the three env-vars (`ANTHROPIC_BASE_URL` / `ANTHROPIC_AUTH_TOKEN` / `ANTHROPIC_MODEL`) with the user's saved `unslothStudioModel` substituted, includes a copy-to-clipboard button (`NSPasteboard`), and surfaces the KV-cache mitigation tip (`"CLAUDE_CODE_ATTRIBUTION_HEADER": "0"` in `~/.claude/settings.json` → ~90% faster local inference). Closes the loop on the owner's "run my own model everywhere" goal — the app *and* the dev tool that builds it can now both run on their local Unsloth-served model.
**Result:** Build + suite green; relaunched. The new row is collapsed by default so it doesn't dominate the panel.

---

## 2026-06-06 · 🔑 Settings: Unsloth API key field (Keychain-backed, optional) + Claude-Code snippet auto-fill
**Files:** `LLM/KeychainStore.swift` (+ `.unslothStudioAPIKey` case), `Views/SettingsView.swift` (+ `unslothStudioKeyRow`, hooked into the Unsloth Studio section between the Test row and the Claude-Code disclosure; `claudeCodeUsageRow` updated to substitute the saved key into the *clipboard* payload at copy time while the visible Text stays at the placeholder).
**What & why:** Owner wanted a place to save the Unsloth API key. Added a standard Keychain-backed row mirroring the other cloud-key rows (`grokKeyRow` pattern: `SecureField` + Save / Clear, `@State unslothStudioKeySaved`, draft wiped on save). The key is **optional** — not required by the app's `.unslothStudio` chat brain (local OpenAI-compat server with `requiresKey: false`) — its purpose is to auto-fill the `ANTHROPIC_AUTH_TOKEN` in the "Use this model with Claude Code too" snippet so the copy-to-clipboard payload pastes the real token instead of the placeholder. Added a small indicator under the snippet showing whether the saved key will be substituted on copy.
**Security:** Per CLAUDE.md and the earlier audit's lesson on the Anthropic-prefix row — the visible Text always renders the placeholder `sk-unsloth-xxxxxxxxxxxx`; the real key is only read from Keychain at the moment the Copy button fires and is built into the clipboard string in that scope. No secret bytes are ever painted on screen, and the in-memory draft is wiped on Save.
**Result:** Build + full suite green; relaunched. Settings → Brain → Unsloth Studio section now has the key row above the Claude-Code disclosure.

---

## 2026-06-06 · 🔬 Whole-codebase review (perf + correctness + arch docs + plans) → `CODEBASE_REVIEW.md`
**Files:** `CODEBASE_REVIEW.md` (new, ~56 KB); findings flagged in `COORDINATION.md`. No source modified.
**What & why:** Owner asked for a comprehensive ALL-SOURCE review (performance, security, implementation review, explanation, docs, refactor, tests). Ran a multi-agent workflow (11 subsystems · 47 agents · ~2M tokens; perf/correctness/refactor/test-gap/explanation per subsystem → adversarial verify of high/med → synthesis). **11 confirmed findings** (distinct from the earlier privacy/a11y audit). Wrote everything to `CODEBASE_REVIEW.md`: exec summary, ranked perf optimizations, confirmed correctness/security, refactor plan, test plan, and a plain-English architecture explanation of every subsystem (the "explain + document" deliverables).
**Highlights:** 🔴 `LiveTranscriber` stops permanently after the first finalized segment (commit→teardown→`capturing=false`); 🔴 FM web tools ignore Offline mode; 🔴 SelfImprove backup overwrites its own original; ⚡ per-token Markdown re-parse is O(n²) on main thread during streaming; ⚡ `brainReady()` fires ~25 sync Keychain syscalls per Settings body pass. Dominant theme: duplication-driven drift (brain-routing ladder ×3, web-gate ×3) → root cause of several bugs; refactor plan targets it.
**Status:** Tree is now GREEN (build + suite) — the other session landed Unsloth Studio and my earlier audit fixes (a11y ×8, key-prefix gate, testActiveBrain reentrancy) are integrated & verified; `testActiveBrain` ended up a clean merge of both sessions' approaches (in-flight counter + pin-capture/bail). Review findings are **not yet applied** (avoiding more shared-file churn while both sessions are active); owner to direct who fixes what. The review read a pre-green snapshot, so a few findings may already be addressed — re-check against current.

---

## 2026-06-06 · 🛠️ Applied 3 HIGH bugs + streaming perf from the review (owner: finish + push)
**Files:** `Media/LiveTranscriber.swift`, `Tools/WebTools.swift`, `Agents/SelfImprove.swift`, `Agents/AgentPipeline.swift`. Owner directed "finish this then push" (no new tests; Grok session deferred).
- **🔴 LiveTranscriber stopped after one segment** — `commit()` called `teardownTasks()` which sets `capturing=false` AND empties `recs`, so `startTasks()` then iterated an empty list and every later audio buffer was dropped. **Fix:** `commit()` now recycles each recognizer's request/task in place (no teardown), advances `segment` once, resets the throttle gate, and keeps `capturing`. Live transcription now continues across segments.
- **🔴 FM web tools ignored Offline mode** — `WebSearchTool`/`FetchURLTool` gated only on `webAccess`. **Fix:** both now use `ToolPolicy.isExternalAllowed` (the Offline-aware gate the Ollama path already uses) with an offline-specific message.
- **🔴 SelfImprove backup overwrote its own original** — process-static timestamp + filename-keyed dest meant re-patching a file in one run clobbered the pre-edit copy. **Fix:** never overwrite an existing backup (the first copy is the true original).
- **⚡ Streaming Markdown re-parse (O(n²) main thread)** — `MissionProgress.stream` published `streamingAnswer` every token. **Fix:** throttle the @Published write to ~16 Hz (60 ms) via a monotonic clock; each write still carries the full cumulative text, `finish()` resets the gate. Removes the single biggest streaming-jank source on long replies.
- **Deferred (documented in CODEBASE_REVIEW.md):** `brainReady()` Keychain caching — doing it safely needs refresh-wiring for 5 providers whose cached flags aren't updated on save/clear (groq/mistral/cerebras/openAI/openRouter), else stale readiness dots. Too risky to rush pre-push. Also the remaining MED findings + the big routing-ladder refactor + the 8 test suites stay as follow-ups.
**Result:** Build + full suite green. Committing + pushing per owner request.

---

## 2026-06-06 · 🔧 Applied 4 confirmed review fixes + 1 user-reported 401 (pre-push batch)
**Files:** `Media/LiveTranscriber.swift`, `Tools/WebTools.swift`, `Agents/SelfImprove.swift`, `Agents/AgentPipeline.swift` (`MissionProgress`), `LLM/UnslothStudio.swift`.
**What & why:** Owner: "finish this then push." Applied the highest-value fixes from the `CODEBASE_REVIEW.md` workflow + the 401 they screenshotted.
- **🔴 HIGH — LiveTranscriber recycle.** `commit()` was calling `teardownTasks()` which not only flips `capturing=false` but also empties `recs=[]`. After the first finalized segment, `startTasks()` iterated an empty list and capture was permanently dead. Fix: recycle each `LangRec`'s request/task **in place** (endAudio + cancel + clear partial + `startTask(rec)`), advance the segment once (no longer double-incremented via teardown), reset the throttle gate. Keeps `capturing`/`recs` intact; real `stop()` paths still hit `teardownTasks` directly so they stay stopped.
- **🔴 HIGH — FM web tools honor Offline mode.** `WebSearchTool.call` and `FetchURLTool.call` gated only on `webAccess`, ignoring `isOfflineOnly`. A session built while online kept the tools in its schema → silent network leak after the user toggled Offline. Both now gate on `ToolPolicy.isExternalAllowed` (the same gate the Ollama tool path uses, which is offline-aware), with a brain-aware refusal string.
- **🔴 HIGH — SelfImprove backup overwrite.** The process-static `backupTimestamp` + `lastPathComponent`-keyed `dest` meant patching the same file twice in one run clobbered its own pre-edit backup → original lost. Fix: `guard !FileManager.default.fileExists(atPath: dest.path) else { return }` — the first backup IS the true original; never overwrite.
- **⚡ PERF — streaming Markdown jank.** `MissionProgress.stream(_:)` wrote `@Published streamingAnswer` on every token; `MarkdownText` then re-parsed the whole cumulative string each time (O(n²) on the main thread, the dominant jank source on long replies). Throttled the publish to ~16 Hz via `DispatchTime.now().uptimeNanoseconds` (no QuartzCore dep; allocation-free; monotonic-safe with `&-`). Correct without a flush queue because each call carries the *cumulative* text — a skipped publish just means the next one catches up — and `finish()` clears the live bubble once the committed message shows the full answer.
- **🔴 HIGH (user-reported) — Unsloth Studio HTTP 401.** Screenshot showed `[Unsloth Studio request failed (HTTP 401). Check the key + your network.]` even though the other session had added an optional `unslothStudioKeyRow` + a `KeychainStore.unslothStudioAPIKey` account. Root cause: `UnslothStudio.client()` still hardcoded `keychainAccount: nil` + `requiresKey: false`, so the saved key was a no-op. Fix: read the Keychain at builder time; if a key is saved, pass `keychainAccount: .unslothStudioAPIKey` + `requiresKey: true` (Bearer auth on every call), else stay unauthenticated. Preserves both deployment modes — `mlx_lm.server`/vanilla LM Studio works keyless, Unsloth's `:8888` Anthropic-compat (and any auth-fronted server) now sends the key.
- **Deferred (documented):** P2 `brainReady()` Keychain caching. Cached `@State` flags only refresh on some Save/Clear paths (not Groq/Mistral/Cerebras/OpenRouter) — switching `brainReady` to them would trade syscalls for stale readiness dots. Needs missing refresh sites first. Tracked in `CODEBASE_REVIEW.md` §1 P2.
**Result:** Build green. Tests skipped per owner. Committing + pushing.

---

## 2026-06-06 · 🤝 Onboarded a 3rd build session (Grok) — lane = Tests + docs
**Files:** `CLAUDE.md` (Two-session → Three-session coordination + Grok lane), `COORDINATION.md` (header + a formal Grok ownership section), `GROK_SESSION_PROMPT.md` (lane finalized from "proposed" to assigned). Doc-only; no build impact.
**What & why:** Owner adding Grok as a third parallel session. Assigned Grok the **Tests** lane — lowest collision with the two Claude feature lanes, and it picks up exactly the work the owner didn't want me to do: the **8 missing test suites from `CODEBASE_REVIEW.md` §4** (each with concrete case names; reproduce confirmed bugs as failing tests first). Also owns doc accuracy + new self-contained modules. The onboarding prompt (`GROK_SESSION_PROMPT.md`) transfers all the rules/discipline; owner pastes it into the Grok session to start it.
**Result:** Repo is three-session-ready. Owner launches Grok by pasting the prompt; its lane is pre-claimed so the Claude sessions stay out of `Salehman AITests/`.

---

## Standing notes / known issues
- **Disk:** the volume is at/near 100%. `ollama rm qwen2.5-coder:32b` reclaims
  ~19 GB if the heavy model isn't needed.
- **Gemini free tier:** user's Google account returns `limit: 0` (429) — account
  state, not an app bug.
- **Anthropic key:** still in UserDefaults (Chat A's lane); Keychain migration
  recommended for parity with the other 6 cloud brains.
- **Two-session coordination** lives in `COORDINATION.md` — read it before editing
  a file the other session owns.
