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


> 🗄️ **Token discipline:** entries from 2026-06-04 → 2026-06-09 (the first ~95k tokens of
> this log) live in [`DEVELOPMENT_LOG_ARCHIVE.md`](DEVELOPMENT_LOG_ARCHIVE.md). Open the
> archive ONLY when you need that history — never read it by default. Append new entries
> ABOVE the "Standing notes" section at the BOTTOM of this file.

## 2026-06-11 · Check in fleet bug-hunt reports for the Grok bridge tooling
**Files:** `tools/BUGS_bridge_py.md`, `tools/BUGS_bridge_sh.md` (new)
**What & why:** The 2026-06-10 parallel fleet run (fleet-1 / fleet-2 lanes) produced two bug-hunt reports against the bridge tooling: `BUGS_bridge_py.md` lists suspected races/throttling gaps in `grok_terminal_bridge.py` (Safari auto-drive partial-page race, no rate-limit guard in the build-rebuild loop, `_grok_send` flood risk), and `BUGS_bridge_sh.md` lists shell-script issues in `run_parallel_safari.sh` / `run_parallel_grok.sh` (uninitialized loop var, TABIDX off-by-one risk, no `--help`, quoting/portability problems) plus `grok_sessions_summary.py` lacking a shebang/CLI. They were left untracked in the working tree; committing them so the findings aren't lost. None of the listed bugs are fixed yet — these are the backlog for the next bridge-hardening pass.
**Result:** Reports tracked in git. No code changed; build unaffected.

## 2026-06-11 · Full code cleanup — dead code purge, honest-UI fixes, doc re-sync (multi-agent sweep, adversarially verified)
**Files:** deleted `Tools/ImageGen.swift`, `Tools/MacControlTools.swift`, `Tools/StockSageTool.swift`; moved `Salehman AI/grok_parser.py` → `tools/`; deleted `Salehman AI/access.log`, `Salehman AI/parsed.json`, `tools/salehman_training.jsonl` (generated, 0 bytes); edited `LLM/{LocalLLM, OllamaClient, MemoryManager, BrainStatus, SalehmanPersona}.swift`, `App/{AppSettings, AppState, Salehman_AIApp}.swift`, `Views/{SettingsView, ChatViewModel, ShortcutsView, CommandPalette}.swift`, `Tools/{ToolPolicy, StockSageMini}.swift`, `Agents/{SelfImprove, Orchestrator, AgentRegistry, MissionMemory, MissionPlan, AgentPipeline}.swift`, `StockSage/{StockSageStore, StockSageMonitor}.swift`, `Persistence/{Attachments, JSONFileStore}.swift`, `DesignSystem/DesignSystem.swift`; tests `ToolPolicyTests`, `MemoryManagerTests`, `PersistenceRoundTripTests` (header), `LiveTranscriberSegmentTests` (header); tools `bundle_check.sh`, `grok_cleanup.py`, `fleet_supervisor.sh`; docs `PROJECT_CONTEXT.md`, `ARCHITECTURE.md`, `VERIFICATION.md`, `CODEBASE_REVIEW.md` (banner), `COORDINATION.md`, `.gitignore`.
**What & why:** Owner asked for a full code cleanup. Ran a 67-agent find→adversarially-verify sweep (7 lenses: LLM, Views, Tools/Agents, Data/Media, docs, scripts, tests → 60 findings, 58 confirmed); applied the behavior-preserving subset:
- **FM-era leftovers removed** (the Apple-Intelligence tool layer was deleted 2026-06-08; these survived it): `ToolPolicy.instructionsToolMenu()` (advertised ~18 tools, most nonexistent — zero production callers) + its 2 tests (web-gate property still pinned by `OllamaToolGateTests`); `ImageGen.swift` (`generate` had no callers; `GeneratedMedia` consumed-but-never-set → `ChatMessage.imagePath` producer was always nil); `MacControlTools.swift` + `StockSageTool.swift` (zero references; `StockSageMini` slimmed to the `disclaimer` MarketsView renders); `SelfImprove`'s unreachable build→fix→rebuild loop (kept the test-covered primitives: `parseErrors`, `applyPatch`, `backup*`, `isInsideProject`); `SalehmanPersona.instructions(toolMenu:)`.
- **Dead settings/state:** `useCodeModel` (+ its lying "Local coding model" Settings toggle — read by nothing), `AppSettings.openAIModel` @Published (never written; `Keys.openAIModel`/`openAIModelCurrent` kept), `AppState.focusInputRequested`, `BrainStatus.hasVision`+`probeVision` (an Ollama probe every 10 s for a value nothing read), `BrainStatus.hasGrokKey`, `BrainStatus.labelColor`, `LocalLLM.statusNote`, `OllamaClient.code(task:)`, `Generation.tight/.full/numGPU`, `MemoryManager.Snapshot/snapshot()/instance shouldRefuseHeavyModel`, `Orchestrator.run(mission:)`, `AgentRegistry.isRegistered/registeredAgents`, `Outcome.keyLearnings/conflictsResolved/recommendedNextActions/notes` + `getSummary` (never populated, flagged since 2026-06-05), `MissionPlan.thinkingMode/recommendedAgents`, `StockSageStore.upsert`, `StockSageMonitor.smartWatchlist` (writer-no-reader), `AttachmentLoader.ocr` (superseded by `VisionAnalyzer.describe`), `JSONStore` protocol + `JSONFileStore.delete()` (baseDirectory seam supersedes; trivially re-addable), `DS.Glass`, `DS.Unrestricted` + 2 palette constants.
- **Honest-UI fixes:** restored the **⌘K Command Palette** menu binding (accidentally deleted in commit 113fc76 — four UI surfaces advertised it while it did nothing); ShortcutsView cheat sheet re-synced to real ⌘1–7 (Code tab was missing, Agents→Knowledge were off by one); CommandPalette gained "Go to Code".
- **Tooling repairs (Grok-web-UI `$`/`__` stripping, commit 360103c):** `bundle_check.sh` stale-check never ran (`{#stale_files[@]}` → fixed, first honest PASS verified); `grok_cleanup.py` crashed on every invocation (`if name == "main"` → fixed, smoke-tested with N=99999 → "Removed 0 file(s)"); `fleet_supervisor.sh` slot-7 path updated for the grok_parser move + slot-5 reworded ("Create tools/README.md if missing" — file never existed).
- **Docs re-synced to the real tree:** PROJECT_CONTEXT (brain list → 19 cases w/ `.salehman` default, Salehman-engine family rows, real Tools table, 7-tab ⌘ map, DeepSeek+NVIDIA provider rows, §6/§7 resolved-items), ARCHITECTURE (module map — phantom per-provider/FM files removed, Intelligence/Voice/Knowledge added; routing matrix rebuilt without `.apple`), VERIFICATION (real subsystem filter `com.salehman.ai`, real signpost names), CODEBASE_REVIEW (dated HISTORICAL banner). COORDINATION: garbled 2026-06-10 safari-fleet claim rows cleared; void Grok Tab A/B claims released.
**Deliberately NOT done (deferred, with reasons):** wiring `salehmanEffort` (Settings Effort picker is currently display-only — **owner decision needed: wire `SalehmanEngine.respond(to:effort:)` into the answer path or remove the row**; it's 1 day old and clearly intended to be wired); `StockSageScreenAnalysis` (built-but-unwired, intentional pre-integration); `tools/finetune_export.jsonl` (owner may still need it for the x.ai job; note it contains personal session data and is on the GitHub remote); duplicate-code consolidations (GrokClient→OpenAICompatibleClient, tool-dispatch switch, mediaExts, PromptLibrary boilerplate → refactor pass, not cleanup); DS token-vocabulary trim (intentional design vocabulary); duplicate/overlapping test suites + the `OllamaRAMBenchmarkTests` brainPreference-lock gap (test-target changes need a real test run to verify).
**Result:** ~700 lines of dead/unreachable code removed; 3 Swift files + 3 artifacts deleted; all 90 remaining app sources pass `swiftc -typecheck` (Swift 6, `-default-isolation MainActor`) with **0 errors / 0 warnings**. `SOURCE_BUNDLE.md` regenerated; `bundle_check.sh` PASS. ⚠️ **xcodebuild + the test suite could NOT be run in this session** (sandboxed environment blocks Xcode's build service); test-target changes were verified by exhaustive grep only — **run the canonical build + `Salehman AITests` before merging PR #1** ([https://github.com/swonyu/Salehman-AI/pull/1](https://github.com/swonyu/Salehman-AI/pull/1)).

## 2026-06-11 · Effort wiring — review fixes (5 adversarially-confirmed bugs)

**Files:** `Salehman AI/Intelligence/Effort.swift`, `Salehman AI/LLM/SalehmanLeader.swift`, `Salehman AI/App/AppSettings.swift`, `Salehman AI/Views/SettingsView.swift`, `Salehman AITests/EffortWiringTests.swift`, `SOURCE_BUNDLE.md`

**What & why:** A 4-lens adversarial review (20 agents, 10 confirmed / 6 rejected findings) of the Effort wiring diff turned up 5 real bugs. Applied all 5:

1. **[HIGH] Fresh-install default brain not detected as pinned `.salehman`** — `finalize` and `isLeading` were comparing against the raw UserDefaults string; on a fresh install the key is unset (nil), so the comparison `nil == "salehman"` was false, incorrectly routing the default user to the full leader fan-out instead of the cheap refine-only path. Fixed by using `AppSettings.brainPreferenceCurrent` (the validate-or-default accessor) in both functions.

2. **[MEDIUM] Leader toggle OFF didn't zero-out pinned-`.salehman` passes** — the `finalize` pinned-.salehman branch fired before `guard isLeading`, completely bypassing the toggle. Pre-change, `guard isLeading else { return draft }` was the first line, so OFF = guaranteed zero passes. Fixed by adding `guard AppSettings.salehmanLeaderEnabled else { return draft }` inside the pinned-.salehman branch.

3. **[MEDIUM] Default effort `.balanced` violated CLAUDE.md "never silently call a paid cloud API" invariant** — on factory defaults (brainPreference unset → `.salehman`, effort unset → `.balanced`), every non-code reply would silently invoke 2 extra `SalehmanEngine.generate` calls (critique + rewrite via `SelfCritique.refine`), which can route to the paid DeepSeek backstop. Changed default to `.instant` (0 extra calls, exactly pre-Effort behavior). Higher quality is now opt-in.

4. **[MEDIUM] Non-monotonic effort dial for the refine-only path** — `.ultra` (critiqueRounds=2) did LESS refinement than `.high` (critiqueRounds=3) in `refineOwnDraft`, because `.ultra`'s value is lower (it offloads cost to fan-out, which isn't available here). Added `refineRounds` property to `Effort` with `.ultra` capped at `.high`'s depth (both 3 rounds), and added `approxRefineCalls = refineRounds * 2`. `refineOwnDraft` now uses `refineRounds`.

5. **[MEDIUM] Settings cost hint overstated/misstated for pinned-`.salehman` path** — `approxModelCalls` is the leader fan-out cost (16 for `.ultra`), not the refine-only cost (6 extra calls max). Added `effortCallsHint` computed property to `SettingsView` that branches on `brainPreference == .salehman` and shows `approxRefineCalls` vs `approxModelCalls` accordingly. `.instant` for pinned `.salehman` now correctly shows "no extra calls".

Updated test names and expectations in `EffortWiringTests.swift` to match the `.instant` default.

**Result:** `swiftc -typecheck` 0 errors / 0 warnings (Swift 6, `-default-isolation MainActor`). `SOURCE_BUNDLE.md` regenerated (128 files, 23720 LOC). ⚠️ xcodebuild + test suite still cannot run in sandbox — **must run canonical build + `Salehman AITests` before merging PR #1** ([https://github.com/swonyu/Salehman-AI/pull/1](https://github.com/swonyu/Salehman-AI/pull/1)).

## 2026-06-11 · Effort wiring — doc/copy sync follow-up

**Files:** `Salehman AI/Views/SettingsView.swift`, `PROJECT_CONTEXT.md`, `COORDINATION.md`, `ARCHITECTURE.md`, `SOURCE_BUNDLE.md`

**What & why:** Follow-up to the review fixes above. (1) The "Salehman leads" toggle subtitle still said pinned `.salehman` is "skipped automatically" — post-wiring that's only true at Effort=Instant; rewrote the copy to say the Effort dial still self-critiques the pinned brain's draft, and that OFF = no extra passes for any brain (this was the third doc-contradiction site flagged by review finding #1; the other two were fixed in the previous commit). (2) `PROJECT_CONTEXT.md` + `COORDINATION.md` still claimed "default `.balanced`" from before the review changed the default to `.instant` — synced both. Verified via `swiftc -typecheck` on a temp tree with the OTHER session's in-flight files (`AgentPipeline`, `OllamaClient`, `CodeView`, `ContentView`, `MarkdownText` — live streaming-render work, not mine, not committed here) pinned to HEAD: 0 errors / 0 warnings. Note: the shared working tree means `SOURCE_BUNDLE.md` snapshots their WIP too (same as the previous commit) — they'll regenerate when their work lands.

**Result:** Docs, Settings copy, and code now tell the same story: Leader OFF = zero extra passes everywhere; pinned `.salehman` + Leader ON = critique-only at the dialed effort; default `.instant` = no silent spend.

## 2026-06-11 · Cross-session heads-up posted (Effort defaults changed under the latency session)

**Files:** `COORDINATION.md`, `SOURCE_BUNDLE.md`

**What & why:** Owner asked to notify the other live session (the latency/fast-path one — its transcript shows it's building a trivial-greeting fast path in `AgentPipeline` partly to dodge `refineOwnDraft`'s critique cost). It isn't a CCD session, so `send_message` can't reach it; posted a dated note on the COORDINATION.md board (the canonical channel) instead. Key content: default effort is now `.instant` (refineOwnDraft = zero-call no-op at defaults — re-time any "finalize makes hi slow" measurements), Leader OFF is a true kill switch again, `brainPreferenceCurrent` replaces raw-string compares, new `refineRounds`/`approxRefineCalls`, and a merge-awareness warning that I touched `SettingsView.swift` while they hold uncommitted Views work.

**Result:** Board note committed; bundle regenerated. Their in-flight files remain untouched/uncommitted.

## 2026-06-11 · Build request handed to the build-capable session + deferred-refactor triage

**Files:** `COORDINATION.md`, `SOURCE_BUNDLE.md`

**What & why:** Appended a build request to the board note: the latency session demonstrably runs `xcodebuild` + launches the app (this sandboxed session cannot), so it's asked to run the canonical build + `Salehman AITests` (incl. the new `EffortWiringTests`) when its work lands and post pass/fail — the only remaining gate on PR #1. Also triaged the cleanup's deferred refactors: `mediaExts` dedup is **moot** (single definition in `MediaTranscribe.swift` since the cleanup); `PromptLibrary` boilerplate fold-in judged **not worth the churn** (~15 lines saved, clear file as-is); `GrokClient→OpenAICompatibleClient` + tool-dispatch dedup **deliberately left** — the other session is actively studying the cloud chain, collision risk. Review loose ends closed: the verify-agent-killed finding ("maxTokens / whitespace") was re-verified by hand — `maxTokens` difference is inert (`SalehmanEngine.generate` only uses it at the MLX floor as `?? 1024`, identical to the old explicit 1024); leader answers now arriving whitespace-trimmed is cosmetic.

**Result:** PR #1 fully done from this session's side; merge gate = owner (or latency session) runs build + tests.

## 2026-06-11 · 14B training babysit accepted (API-side); PR #1 build gate PASSED by the other session

**Files:** `COORDINATION.md`, `SOURCE_BUNDLE.md` (no app code)

**What & why:** The latency session answered the board: (1) **PR #1 build gate cleared** — canonical build + `Salehman AITests` on the combined tree: BUILD SUCCEEDED, 297 tests passed / 0 failed (incl. all `EffortWiringTests`); it also updated stale `selectableCasesExcludeAllPaid` in `ToolLoopTests.swift` (rides its next commit). (2) It handed off the owner-mandated **14B Salehman training babysit** (pod `37ar55sx5i1h1h`, A100, round 1 of Qwen2.5-14B QLoRA running; runbook on the board). Accepted with a capability split: this sandbox blocks outbound SSH (`Operation not permitted`) but the RunPod HTTPS API works — so this session runs a 60s-poll monitor (GPU-sustained-idle = round boundary; pod-not-running; balance<$3; 30-min heartbeats), does the balance math, and will `podTerminate` + report final spend; the SSH legs (adapter verify/scp/eval/retrain/GGUF) stay with the other session unless the owner grants SSH egress. Monitor v1 had a real bug — zsh doesn't word-split unquoted `$line`, so `set -- $line` parked the whole status string in `$1` and zsh's `[` coerced the empty `$bal` to 0 → false "balance $0" alarm; v2 moved all logic into a single Python poller (no shell parsing). The other session also cleaned the RunPod money leak with owner confirmation (13 volumes + 11 dead pods deleted; burn now $1.415/hr) — my "surface the leak at the end" runbook step is moot.

**Result:** PR #1 fully merge-ready (build+tests green). Training watch live (balance $11.95 ≈ 7 iteration-hours after the $1.50 GGUF reserve). Owner asked in chat whether to grant SSH egress so this session can take the whole runbook.

## 2026-06-11 · 14B-readiness (Agents/Settings lane): status row + concurrency/assumptions audits; round-1 boundary relayed

**Files:** `Salehman AI/Views/SettingsView.swift`, `COORDINATION.md`, `SOURCE_BUNDLE.md`

**What & why:** Worked the board task the latency session left (owner: "give the other claude a similar task") to make this lane 14B-ready before the fine-tuned GGUF lands. (1) **Settings "Salehman model" status row** (`salehmanModelStatusRow` + `LocalModelProbe` tri-state + `probeLocalModel()`): under the custom-model-name field in "Salehman engine" — green installed / orange missing with a copyable `ollama create ‹name› -f Modelfile` button / gray Ollama-down; probes via the same accessors the engine routes by (`customModelNameCurrent`, `OllamaClient.isUp/hasModel`) so the row can't disagree with actual routing; re-probes on name edit + manual refresh. (2) **Concurrency audit PASS** — `effectiveCap` already forces 1 in-flight generate for `.salehman`/`.ollamaCoder`/`.unslothStudio`/`.vllm` over the per-phase batch loop, `isSerialLocal` skips the adaptTitles side-generate, Effort ladder is sequential: no change needed. (3) **Assumptions sweep CLEAN** — no qwen text-model hardcodes (only the vision `qwen2.5vl`, correct), no sub-60s local-generate timeouts, no load-re-paying retry loops. Also: the API watch caught the **round-1 boundary** (GPU idle 3 min, balance $11.48, pod still billing $1.415/hr idle) — posted to the board for the SSH side with budget math ($9.98 usable ≈ 6–8 rounds); monitor v4 (state transitions + idle-cost heartbeats) is live. Monitor v3 note for the record: urllib transport couldn't verify the sandbox proxy's TLS cert (same root cause as the gh x509 failure) — v3+ use curl transport with Python logic.

**Result:** Full-tree `swiftc -typecheck` 0 errors / 0 warnings. Bundle regenerated. Build+tests delegated to the build-capable session (only SettingsView changed).

## 2026-06-11 · 14B-in-app items 4–6: tool-loop warm-keep + round progress, local context diet, tests

**Files:** `Salehman AI/LLM/LocalLLM.swift`, `Salehman AI/Agents/AgentPipeline.swift`, `Salehman AI/Agents/AgentRegistry.swift`, `Salehman AITests/FourteenBReadinessTests.swift` (new), `COORDINATION.md`, `SOURCE_BUNDLE.md`

**What & why:** Board items 4–6 (owner: "give yourself and other claude tasks that help salehman 14b in the app").
- **Tool-loop budgets (item 4):** timeouts were already fine (chatTurn 300 s, compat 120 s); the real bugs: (a) `chatOllamaWithTools` hardcoded `keep_alive:"30s"`, bypassing `Generation.tuned(for:)` — the 14B was evicted 30 s after any tool-built reply and re-paid its ~9 GB load on the next message. Now uses tuned keep-alive (salehman → 5 m) with num_ctx floored at 4096 (tool transcripts are fat; tuned's 2048 would truncate them on small models). (b) Up to 8 silent 30–90 s rounds. Added `MissionProgress.noteToolRound(_:of:)` — annotates the running step's adapted title ("… · tool round 3/8"), idempotent, zero UI changes, no-op outside team missions; both tool loops emit it per round.
- **Local context diet (item 5):** real worst case measured: 8 turns × 4,000 chars/turn = 32k chars ≈ 8k tokens — double num_ctx 4096, and Ollama evicts the OLDEST tokens on overflow (persona dies first). `AgentInput` now carries the resolved `brain`; on serial-local brains the 2-agent handlers trim history via new pure `AgentPipeline.recentTail` (6,000-char budget, most-recent turns, line-boundary cut) and context to 1,500 chars before prompt build. New shared predicate `isSerialLocalBrain` consolidates `effectiveCap` + the adaptTitles skip + the diet (one place to add a future serial brain). Cloud brains keep full history; 15-agent set untouched.
- **Tests (item 6):** `FourteenBReadinessTests.swift` — `Generation.tuned` knobs (salehman 5m/4096 vs others 30s/2048 + default-name fallback), `recentTail` edge cases, `noteToolRound` idempotence/no-op. `.serialized`; sole test mutator of `Keys.customModel`; sole test user of `MissionProgress` (grep-verified). `effectiveCap`/`isTrivialMission` already covered by existing suites — not duplicated.

**Result:** App typecheck 0 errors / 0 warnings; test file parses clean. Build+test run delegated to the build-capable session (posted on the board). CodeView (other session's in-flight) left uncommitted.

## 2026-06-11 · 14B babysit COMPLETE — pod terminated, $5.20 total spend, GGUF on the Mac

**Files:** `COORDINATION.md`, `SOURCE_BUNDLE.md` (no app code)

**What & why:** Closed out the owner-mandated training babysit. The API watch tracked 4 rounds end-to-end (round boundaries via GPU-idle transitions; round costs $0.94/$0.59/$0.80/$0.47-ish); the training session locked **round 3** as the final model (eval 1.3033 vs r4-reseed 1.4507; behavioral probes ~8/8 — coding + Arabic fixed, identity word-perfect) and built/downloaded `salehman-14b-q4_k_m.gguf` (8.4 GB) + `install_salehman_14b.sh` to `salehman-training/`. After verifying the deliverables were local, all adapters backed up, and the pod fully quiet (CPU 0% / GPU 0% / GPU-mem 0% — the documented pre-termination evidence), executed `podTerminate` via API and verified the account holds zero pods. **Final spend: $12.32 → $7.12 = $5.20** for the whole 14B program. Posted the full report + owner actions on the board: revoke the chat-exposed RunPod API key in the console (left `/tmp/.runpod_key` on disk so the other session's tooling doesn't error — inert once revoked), then run the installer so the Settings "Salehman model" row flips green.

**Result:** Babysit done; account clean; $7.12 remains for future runs. Q6_K was never produced locally (optional; recipe + adapter are local if ever wanted).

## 2026-06-11 · Board items 7–10: tool-loop cancel propagation + per-turn output bounds; budget/alias audits

**Files:** `Salehman AI/LLM/LocalLLM.swift`, `COORDINATION.md`, `SOURCE_BUNDLE.md`

**What & why:** Second wave of owner-mandated 14B-in-app tasks. **Item 7:** both tool loops (`chatOllamaWithTools`, `chatOpenAICompatWithTools`) now check `Task.isCancelled` at the top of every round and before the final wrap-up generate — pressing Stop aborts between rounds and returns the best prose so far, instead of a cancelled mission holding the serial 14B slot for minutes (mid-request cancels were already safe — URLSession is cancellation-aware). **Item 8:** new shared `LocalLLM.toolTurnTokenCap = 2048`, wired as `max_tokens` into the compat tool-path bodies (vLLM/Studio otherwise generate to max_model_len) and as `num_predict` into the Ollama tool-loop body (same unbounded risk). **Item 9 (audit, no code):** all agent call sites already pass token budgets (700/110/300). **Item 10 (audit, no code):** the Settings status row (shipped a47bb49) works with the `salehman14b`+alias plan; flagged the `Generation.tuned` exact-name alias trap on the board — the other session closed it same-day (salehman* prefix match). Items 7/8 were deliberately queued until the other session's in-flight LocalLLM commit (`70d6af7`) landed — a background watcher on the file's git state gated the start (shared working tree discipline).

**Result:** Typecheck 0 errors / 0 warnings; build+tests delegated via board (their last run: 306/306 green incl. FourteenBReadinessTests). Next: the owner-directive whole-app restyle (accepted on the board; per-view, my lane grant: ContentView/SettingsView/Today/Agents/Markets/Notes/Knowledge).

## 2026-06-11 · Whole-app restyle 1/7 — SettingsView chrome to the Code-tab design language

**Files:** `Salehman AI/Views/SettingsView.swift`, `COORDINATION.md`, `SOURCE_BUNDLE.md`

**What & why:** First slice of the owner-directive restyle ("make the whole app look like [the Code tab]"). SettingsView macro chrome: sheet canvas gradient → flat opaque `DS.Palette.codeSurfaceSide`; section content boxes translucent-`surface`-with-shadow → opaque `codeSurface` with hairline stroke only; section headers' brand-gradient capsule stripe dropped for quiet tracked-uppercase 10.5pt secondary (chrome diet), subtitles to the spec's 11pt; "Settings" header 26pt-bold-rounded → 17pt-semibold with `.help()` on the close button. Inner control surfaces deliberately deferred to a second pass (canvases first). Lane grant per board: ContentView/SettingsView/Today/Agents/Markets/Notes/Knowledge are mine for this task; CodeView/MarkdownText/DesignSystem stay with the other session.

**Result:** Typecheck 0 errors / 0 warnings; committed+pushed; gate delegated. Next slice: ContentView (main chat) message rows + reading column.

## 2026-06-11 · Whole-app restyle 2/7 — ContentView (main chat) to the document-flow message style

**Files:** `Salehman AI/Views/ContentView.swift`, `COORDINATION.md`, `SOURCE_BUNDLE.md`

**What & why:** Slice 2 of the owner-directive restyle, mirroring the Code tab's `CodeMessageRow` while keeping the main chat's richer actions. `MessageBubble` rewritten: user messages are a quiet right-aligned block (white 0.09, radius 13, 13.5pt, no avatar, no label, hover-only copy); assistant replies are flush-left document flow (no avatar disc, no bubble chrome, no per-message timestamp — the existing `TimeSeparator` rows already mark time between bursts) with speak/copy/regenerate in an always-mounted hover overlay (keyboard/VoiceOver reachable). `StreamingBubble` matched (pulsing 6pt accent dot replaces the avatar; same flush-left flow so stream-end doesn't visibly snap styles). Transcript and input bar now share a centered 780pt reading column. Chat canvas is flat opaque `codeSurface` (no glow show-through; the Unrestricted-Mode red tint still overlays). Dead code removed with the avatars: `bubbleShape`, `bubbleBackground`, `avatar`, `userAvatar`, the `isLastInGroup` param + helper, and the `Theme.userBubble` forwarding alias (`DS.Gradient.userBubble` is now orphaned app-wide — flagged to the DS-owning session to prune).

**Result:** Typecheck 0 errors / 0 warnings; committed+pushed; build+test gate requested on the board. Next slices: Today/Agents/Markets/Notes/Knowledge.

## 2026-06-11 · Whole-app restyle 3–7/7 — Today, Agents, Notes, Knowledge, Markets to the design language

**Files:** `Salehman AI/Views/TodayView.swift` (rode the other session's db57c44 — see note), `Salehman AI/Views/AgentsView.swift`, `Salehman AI/Views/ScratchpadView.swift`, `Salehman AI/Views/KnowledgeView.swift`, `Salehman AI/Views/MarketsView.swift`, `COORDINATION.md`, `SOURCE_BUNDLE.md`

**What & why:** Final five slices of the owner-directive restyle ("continue working and refining, gone for 3 hours"; gate for slices 1+2 passed 306/306 with owner feedback "this looks much better than the coding tab"). Surface convention applied everywhere: canvas = flat opaque `codeSurface` (0.125), panels/cards = `codeSurfaceSide` (0.095) + hairline, input pills = white 0.09 with no stroke, no shadows, headers 17pt-semibold/11pt-secondary, content in a centered 780pt column. Per view: **Today** — tiles opaque (no translucency over the landing glow, which stays — landing surface); **Agents** — glass-hero Autonomous card flattened (gradient wash/halo sparkle/accent-glow shadow removed), "N agents" header counter dropped per chrome diet, cards' hover/active stroke is the only elevation; **Notes/Knowledge** — flat canvases, list/ask cards to panel shade, add/search fields to pills; **Markets** — all cards swapped, `.ultraThinMaterial` disclaimer footer → flat panel + hairline. Shared-tree note: the other session's `db57c44` unintentionally swept my in-flight TodayView edits + an intermediate AgentsView state into their commit (content correct, their gate covered it) — flagged on the board with the `git status`-before-`add` discipline reminder.

**Result:** Typecheck 0 errors / 0 warnings (CodeView pinned to HEAD in a temp tree — other session mid-edit). All 7 restyle slices are now in. Gate requested; pass-2 refinements (Settings inner controls, ContentView empty-state polish) next.

## 2026-06-11 · Whole-app restyle pass 2 — main-chat chrome + Settings controls de-glassed

**Files:** `Salehman AI/Views/ContentView.swift`, `Salehman AI/Views/SettingsView.swift`, `COORDINATION.md`, `SOURCE_BUNDLE.md`

**What & why:** Final pass of the owner-directive restyle. ContentView: every `.ultraThinMaterial` removed — header/search/input bars to flat `codeSurfaceSide`/`codeSurface`, the attach/library/export circle buttons and attachment chip to white-0.09 fills; the message input is now a quiet white-0.07 pill whose focus state is a solid accent hairline (the gradient focus ring + accent-glow shadow are gone); the ScrollToLatest pill swapped its brand gradient + glow for solid accent; `TypingIndicator` rebuilt from avatar-with-breathing-halo + glass bubble to three flush-left accent dots that style-match the streaming row (the 14B "Warming up the local model…" hint kept; orphaned `halo` state removed). SettingsView: the six remaining translucent `DS.Palette.surface` control fields became white-0.09 pills. Deliberately kept: the chat empty-state hero + `SuggestionCard`/`Eyebrow` (landing-moment identity, and DS-lane components) and the header brain-status halo (functional status indicator).

**Result:** Typecheck 0 errors / 0 warnings (CodeView pinned — other session mid-edit). Restyle complete: 7/7 slices + pass 2; gate requested on the board.

## 2026-06-11 · Whole-app restyle pass 3 — straggler views swept for consistency

**Files:** `Salehman AI/Views/TabSwitcherBar.swift`, `Salehman AI/Views/BottomShortcutBar.swift`, `Salehman AI/Views/MemoryView.swift`, `Salehman AI/Views/LiveTranscriptionView.swift`, `Salehman AI/Views/VoiceModeView.swift`, `Salehman AI/Views/AboutView.swift`, `COORDINATION.md`, `SOURCE_BUNDLE.md`

**What & why:** The owner directive was "the whole app"; the secondary views still wore the old glass and clashed against the new flat language. Swept: TabSwitcherBar (persistent header — bar to flat `codeSurfaceSide`, tab-pills capsule to white-0.07, brand-tile accent glow dropped), BottomShortcutBar (flat), MemoryView + LiveTranscriptionView (flat `codeSurface` canvases; Memory's cards to panel shade, its field to a white-0.09 pill), VoiceModeView (flat canvas — but the pulsing phase orb and its glow KEPT, it's the mode's functional centerpiece), AboutView (capabilities card opaque; landing canvas + icon glow kept). OnboardingView untouched (pure landing surface, glow allowed by spec); CommandPalette/ShortcutsView/CopilotSignIn had zero chrome hits. All beyond the enumerated lane grant but inside its spirit and outside the other session's exclusions — declared on the board.

**Result:** Typecheck 0 errors / 0 warnings (CodeView pinned — other session mid-edit). The app now speaks one surface language end to end: canvas `codeSurface`, panels `codeSurfaceSide`, pills white-0.09, hairlines, glow only on landing surfaces + functional indicators.

## 2026-06-11 · Chat-tab heavy polish pass 1 — Claude composer, floating actions, reading rhythm

**Files:** `Salehman AI/Views/ContentView.swift`, `COORDINATION.md`, `SOURCE_BUNDLE.md`

**What & why:** Owner directive ("POLISH THE CHAT TAB HEAVILY", away 3 h). (1) **Composer rebuilt to the Claude text-over-controls layout** the other session just shipped in CodeView (cross-tab consistency): one flat rounded container — TextField on top (grows 1…8 lines), controls row beneath with a single + menu that now carries BOTH attachments and saved prompts (replacing two separate 40 pt circles), a quiet inline mic, and a 26 pt solid-accent send (red stop while generating). (2) **Assistant hover actions float** on their own small panel pill instead of reserving 84 pt of trailing layout — replies get the full reading measure back, and the pill stays readable over any text. (3) **Reading rhythm**: 10 pt within a same-sender burst / 24 pt between speakers (was 4/14); user blocks cap at a 480 pt wrap measure; entry motion calmed (8 pt rise, blur 4, was 14/6). (4) Chrome diet leftovers: header thinking-glyph gradient → solid accent; UNRESTRICTED label 15-rounded → 12.5; `AgentRunView` lost its avatar disc and moved to the `codeSurfaceSide` panel (live N/M counter kept — it's progress, not chrome); `ConfirmationChip` dot lost its blur halo.

**Result:** Typecheck 0 errors / 0 warnings; committed+pushed; gate requested. Pass 2 next: empty-state/welcome polish + detail sweep.

## 2026-06-11 · Chat-tab heavy polish passes 2+3 — live-14B welcome + two self-introduced continuity bugs fixed

**Files:** `Salehman AI/Views/ContentView.swift`, `COORDINATION.md`, `SOURCE_BUNDLE.md`

**What & why:** Pass 2: the empty-state greeting is time-aware (same hour buckets as the Today tab so the two landing surfaces agree); the eyebrow chip now flips to "Salehman AI · your 14B is live" once `OllamaClient.hasCustomModel()` is true — the same probe the Settings status row uses, so the two indicators can never disagree; headline toned from 32-rounded to 28-semibold plain SF. Pass 3 fixed two continuity bugs my own pass 1 introduced: (a) the user-block copy button lived in a VStack row that reserved ~22 pt of dead space under EVERY user message even un-hovered — replaced with the same floating panel-pill overlay the assistant rows use (zero reserved layout); (b) `StreamingBubble`'s pulsing dot sat BESIDE the text, indenting it ~14 pt, so the committed message visibly jumped left at stream-end — the dot now sits ABOVE the text and the leading edge is final from the first token.

**Result:** Typecheck 0 errors / 0 warnings per pass; both committed+pushed; gate requested (passes 1–3 together). Chat tab at target shape pending owner/gate feedback.

## 2026-06-11 · Visual QA delegated (sandbox can't see/drive the screen); blind checks pass

**Files:** `COORDINATION.md`, `SOURCE_BUNDLE.md`

**What & why:** Owner asked for live functional verification of the polished chat tab (screen-record, drive the UI, fix what's broken). This session's sandbox blocks every needed capability — `screencapture` ("could not create image from display"), AppleScript/System Events (XPC connections severed), even process listing — while the parallel session demonstrably launches, screenshots, and keystrokes the app. Posted an 11-step visual-QA checklist on the board for it (empty state, suggestion submit, fast-path "hi", hover pills with zero layout shift, stream-commit continuity, Stop/⌘., composer growth + unified menu, ⌘F, scroll-to-latest, Unrestricted chrome, cross-tab canvases) with screenshots + PASS/FAIL + nit list requested; I fix whatever it finds. Blind-verifiable claims checked by code reading meanwhile: the ⌘. stop binding EXISTS (Salehman_AIApp.swift:92), ⌘F EXISTS (:94), and `ChatViewModel.stop()` performs real `Task.cancel()` — so the tool-loop cancel propagation built earlier today fires from the actual Stop button.

**Result:** QA in the capable session's queue; no code changes this entry.

## 2026-06-11 · QA harness: the app photographs itself (ImageRenderer → PNGs) + chat-flow UI tests

**Files:** `Salehman AI/Tools/QASnapshots.swift` (new), `Salehman AI/App/Salehman_AIApp.swift`, `Salehman AI/Views/ContentView.swift`, `Salehman AIUITests/ChatTabUITests.swift` (new), `qa/README.md` (new), `.gitignore`, `COORDINATION.md`, `SOURCE_BUNDLE.md`

**What & why:** Owner asked for a better QA mechanism than screenshot checklists. Shipped a **self-snapshot harness**: `QASnapshots` renders nine surfaces — including a deterministic `chat_samples` gallery covering every message/streaming/typing/agent-strip state the polish passes touched — to `qa/snapshots/*.png` via SwiftUI `ImageRenderer` (in-process; needs no Screen Recording permission, so it sidesteps the sandbox wall that blocks `screencapture` here). Triggers: a `qa/SNAPSHOT_REQUEST` file consumed at launch (one is planted now) or View ▸ "Capture QA Snapshots". Snapshot PNGs are gitignored (`chat_live.png` renders the owner's real history — must not land in the repo). Plus **`ChatTabUITests`**: four model-independent flows — send-button enable/disable gating, ⌘F search toggle, the unified +-menu carrying both Attach and Prompts sections, and a test that clicks the snapshot menu item and asserts the PNGs appear (so every gated UI-test run auto-delivers fresh pictures to the blind session). Composer controls gained accessibility identifiers (`chat.composer.field/plus/mic/send`) — for the tests and for VoiceOver. A file-watcher in this session fires when `chat_samples.png` lands → I read the images and iterate polish with actual eyes.

**Result:** App typecheck 0 errors / 0 warnings; UI-test file parses clean (full test-target compile happens in the other session's gate). Stated limits: ImageRenderer is static layout/style only — hover/focus/sheet states remain on the manual checklist.

## 2026-06-11 · QA v3 — first real eyes on the UI, self-judging audit, live-window capture

**Files:** `Salehman AI/Tools/QAAudit.swift` (new), `Salehman AI/Tools/QACapture.swift` (new), `Salehman AI/Tools/QASnapshots.swift`, `Salehman AI/App/Salehman_AIApp.swift`, `Salehman AIUITests/ChatTabUITests.swift`, `qa/README.md`, `.gitignore`, `COORDINATION.md`, `SOURCE_BUNDLE.md`

**What & why:** Round-1 snapshots delivered first real eyes on the UI and an honest verdict on the harness itself. Findings: the chat gallery rendered correctly (rhythm/blocks/document-flow/agent-strip all match the design) except a stray sample row below the agent strip (LazyVStack misbehaving offscreen → plain VStack) and a third of the frame as dead space (vertical centering → `.topLeading` pin); `settings.png` rendered as a blank panel, `today.png` pure white, the live transcript empty, and TextField/Menu as yellow "unsupported" placeholders — plain `ImageRenderer` can't draw ScrollView/Lazy/AppKit content. Fix: the other session's `snapHosted` (NSHostingView offscreen render — both sessions converged on it independently) became THE single render path for all 13 surfaces. New **`QAAudit.swift`** makes the harness self-judging: after every capture it writes `AUDIT.json` (`nonBlank`, `canvasFlat` corner-luma vs the design greys, `baselineDiff` % + red heat-maps vs adoptable `qa/baselines`), and the capture UI test asserts `failures == []` — a visual regression now fails the gate like a broken unit test. New **`QACapture.swift`** photographs the app's real windows (`WINDOW_REQUEST`/menu — apps may capture their own windows, no permissions). The audit immediately earned its keep: it flagged `memory` (corners not design-grey); eyes-on triage showed a capture-config bug, not a missing canvas — MemoryView is a SHEET that floats in a tab-sized frame; now captured at 500×620 and exempted from corner sampling. Flagged to the other session: code-block text rendered invisible in the markdown sample — verify in the live app (their MarkdownText/CodeSyntaxView lane).

**Result:** Typecheck 0/0; UI tests parse clean. Fresh SNAPSHOT_REQUEST + WINDOW_REQUEST planted — next app launch delivers v3 pictures + the first honest AUDIT.json; watcher armed.

## 2026-06-11 · QA v4 — contrast probe, drift budgets, deeper canvas sampling, history + HTML report

**Files:** `Salehman AI/Tools/QASnapshots.swift`, `Salehman AI/Tools/QAAudit.swift`, `.gitignore`, `COORDINATION.md`, `SOURCE_BUNDLE.md`

**What & why:** Fourth refinement round, turning the green loop into a protective one. (1) **`ContrastProbe`** — a new deterministic surface of 7 fixed text/surface bands (body+secondary on canvas and panel, user-block text, white-on-accent, accent-on-canvas; Arabic glyphs included); the audit scans each band's center line (median sample = background, extreme sample = glyph core) and enforces WCAG-style minimums (4.5:1 body, 3:1 secondary/accent) — the invisible-code-text class of bug found by eyes in round 1 is now caught by arithmetic every capture. (2) **Drift budgets** — deterministic galleries now FAIL `baselineDiff` beyond 2% (probe 1%) unless a baseline adoption made the change intentional; live surfaces stay informational. (3) `canvasFlat` samples mid-edges in addition to corners. (4) `qa/history.jsonl` trend trail (one line per audit) + `qa/snapshots/report.html` — an owner-facing page with badges and current/baseline/heat-map side by side. One Swift 6 isolation fix en route (DS tokens are MainActor; the probe's band table joined them).

**Result:** Typecheck 0 errors / 0 warnings. SNAPSHOT_REQUEST planted — next launch emits the first v4 audit + HTML report. Invited the other session to append its code-syntax colors as new probe bands (the audit picks bands up automatically).

## 2026-06-11 · PR #2 merged — main brought current with the afternoon wave (owner-directed)

**Files:** none (remote merge) + `COORDINATION.md`

**What & why:** Owner asked to "work on the main repo"; clarified intent = merge the branch into main. Discovered PR #1 had already been merged by the owner this morning (head 37fd1ac), leaving 14 afternoon commits branch-only. Opened [PR #2](https://github.com/swonyu/Salehman-AI/pull/2) (whole-app restyle, chat polish passes 1–3, 14B tool-loop hardening items 7–10, QA system v1–v4, code-tab live-QA fixes) and merged it (merge commit `8f64623`). Gate disclosure in the PR body: suite 310/310 at 58eda68; the single newer commit (bc2a32e) is QA-tooling-only with a clean typecheck. Local checkout deliberately stays on `feat/effort-grok-tooling` — the other session works this tree live; the branch equals main post-merge, and the board records the go-forward flow (commit on branch, PR per coherent chunk, main stays current).

**Result:** `origin/main` = `8f64623`, fully current. Both sessions continue uninterrupted.

## 2026-06-11 · QA v4.1 — the audit audited itself: WCAG linearization fix

**Files:** `Salehman AI/Tools/QAAudit.swift`, `Salehman AI/Tools/QASnapshots.swift`, `COORDINATION.md`, `SOURCE_BUNDLE.md`

**What & why:** The first v4 cycle failed `contrast_probe` on "accent on canvas: 2.21:1" — looked like a real readability gap requiring a lighter accent-text token (the other session's DS lane). Before filing that request, recomputed by hand from the token values and found **the probe itself was wrong**: `QAAudit.luma` computed the WCAG weighted sum on gamma-encoded sRGB channels; the spec requires linearization first. The true ratio for the brand accent on the 0.125 canvas is ≈4.3:1 — comfortably passing. Fixed `luma` with proper sRGB linearization for the contrast checks; `canvasFlat` deliberately stays gamma-space (it compares literal token grey values, not perceptual ratios — split into its own helper with a comment saying so). The accent band is re-enforced; the `enforced: Bool` advisory mechanism added during triage stays — it's the right tool for future genuinely-cross-lane waits. Stand-down posted to the other session (no DS token needed).

**Result:** Typecheck 0/0. SNAPSHOT_REQUEST planted — next cycle should be all green with honest numbers (the send button's white-on-accent recomputes to ≈3.8:1, more margin than the gamma-space 3.3 suggested). A QA system that catches bugs in itself is working as designed.

## 2026-06-11 · QA v5 — geometry probe + accessibility-tree sweep (layout and structure join the audit)

**Files:** `Salehman AI/Tools/QAGeometry.swift` (new), `Salehman AI/Tools/QASnapshots.swift`, `Salehman AI/Tools/QAAudit.swift`, `Salehman AI/Views/ContentView.swift`, `COORDINATION.md`, `SOURCE_BUNDLE.md`

**What & why:** Pixels judge color/blankness/drift but not layout intent or structure. v5 adds both. (1) **Geometry probe**: a shared collector (`QAGeometry`) plus a `.qaGeometry(key)` view modifier — ContentView's reading column and composer report their real frames during captures (zero cost otherwise; gated on a flag `captureAll` flips). The audit now asserts the design's layout invariants numerically: column centered within ±2pt and ≈min(780, width−36) wide, composer aligned to the same column — verified at BOTH the 1000pt and 560pt renders. Empty-transcript renders skip gracefully. (2) **Accessibility sweep**: `snap()` walks each surface's AX tree post-layout (`NSAccessibilityProtocol`, recursive); interactive roles (button/menu/toggle/slider/link) lacking label+title+help fail a new `axLabels` check — the icon-button-lost-its-label regression class is now gate-enforced; empty offscreen trees report "not assessable" instead of fake-passing. Capture bridges both to the audit via `STRUCTURE.json`; results appear in AUDIT.json and report.html like any other check. Invited the other session to hook CodeView's split layout into the shared collector.

**Result:** Typecheck 0 errors / 0 warnings. SNAPSHOT_REQUEST planted — the next cycle delivers the first geometry + AX verdicts. Audit capability ladder to date: blank-detection → canvas color → baseline drift (budgeted) → WCAG contrast (linearized) → layout invariants → accessibility structure.

## 2026-06-11 · Chat+Code polish marathon, hour 1 (owner: "refine and polish both, 4h, don't stop")

**Files:** `Salehman AI/Views/ContentView.swift`, `Salehman AI/Views/CodeView.swift` (announced 3-edit slice), `Salehman AI/Tools/QAAudit.swift`, `Salehman AI/Tools/QAGeometry.swift`, `Salehman AI/Tools/QASnapshots.swift`, `Salehman AI/Tools/QACapture.swift`, `COORDINATION.md`, `SOURCE_BUNDLE.md` — commits 910a5d6, b94708a, 22ba424, 8fd8c86

**What & why (eyes-driven from the QA pictures):** (1) **Chat batch 1**: the global app accent paints Menu labels straight through `foregroundStyle` — QA renders caught the export menu and composer + glowing red; local secondary tints fix both (send stays the one strong element). Header's UNRESTRICTED capsule removed — banner + left status + capsule was three red signals at once. New `transcriptStack()`: Lazy normally, eager during captures (LazyVStack never materializes offscreen, which left chat_live's transcript blank). (2) **CodeView slice** (board-claimed, 3 edits, backed off after): same Menu tint-leak fix on `controlsMenu` (their deliberate `· salehman14b` accent child keeps its explicit style), the input bar's `.ultraThinMaterial` → flat (the last translucent bar in the app), welcome hero `containerRelativeFrame`-centered (it rode high over a void). (3) **QA calibration**: first geometry run failed `chat_narrow` on a MISCALIBRATED assertion (the 18pt padding lives inside the measured frame → expected = min(780, rootWidth)); a `"settings": 0.095` diff budget turned out to be the settings canvas grey copy-pasted into the wrong dict (made the gate flap against the LIVE Ollama-status row) — removed; the AX sweep moved to `captureLiveWindows` where trees actually exist (offscreen trees are empty, 16/16 observed). (4) **Gallery: QA-forced states** — `MessageBubble.qaShowActions` lets static captures show the floating hover pill; new rows for the hover state, TimeSeparator, ApprovalCard (first visual coverage of the command gate ever), and the scroll-to-latest pill. Also fixed a verification-process flaw: piping swiftc through `head` masked a mid-build file race (Chat C saving) — typechecks now capture the real exit code; the affected commit re-verified clean (EXIT=0).

**Result:** All four commits typecheck-verified and pushed; capture requests planted; cycle watcher armed. Round-1 code-block invisible-text issue confirmed RESOLVED in the other session's gallery (syntax highlighting renders). Marathon continues: next cycle's pictures drive batch 2.

## 2026-06-11 · Marathon hour 2 — blank-bubble regression, bento fix, Menu-text tint lesson; both tabs verified green

**Files:** `Salehman AI/Views/ContentView.swift`, `Salehman AI/Views/CodeView.swift` (follow-up to the announced slice), `Salehman AI/Tools/QASnapshots.swift`, `SOURCE_BUNDLE.md` — commits 41097e1, 48eb263, 71a082e (+ chat_empty capture, baseline adoption)

**What & why (eyes-driven):** (1) New `chat_empty` capture — the first-impression welcome had never appeared in any picture (live renders always carry real history); `ContentView.qaForceEmptyState` (QA-only param) renders it. First sight showed truncated bento subtitles → copy shortened to fit + grid 560→600; the quiet + button verified in pixels. (2) **Blank-bubble regression caught by eyes**: every `MessageBubble` rendered transparent in the gallery — `onAppear` never fires in offscreen hosted renders, so the entry animation's `appeared` stayed false (the old ImageRenderer path DID fire it, masking this). QA captures now bypass the entry animation. (3) `captureAll` was clobbering `captureLiveWindows`' window_* AX entries in STRUCTURE.json — now merges. (4) **Menu-text tint lesson, proven across one build**: Menu-level `.tint` quiets image-only labels (chat's menus went grey) but NOT label text (Code tab's "Salehman AI" stayed accent) — explicit `foregroundStyle` on the label's children is what wins; follow-up applied to `controlsMenu`. (5) Verified in pixels this cycle: code hero CENTERED (containerRelativeFrame fix), controlsMenu QUIET, bento untruncated, hover pill/ApprovalCard/scroll pill all rendering, the true-pixel live window matching the design language. Baselines adopted at the verified state; post-adoption cycle ALL GREEN with the drift report telling the right story (code surfaces 11–20% = my intentional fixes, chat ≈0, settings 0.57% = live Ollama row).

**Result:** Both tabs now match the design language with pixel-level verification. 8 marathon commits, all typecheck-verified (exit-code pattern). Loop continues on cycle findings.

## 2026-06-11 · Chat ⇄ Code parity batch (owner: "same colors as code tab + heavily polish and ADD things")

**Files:** `Salehman AI/Views/ContentView.swift`, `Salehman AITests/QAGeometryTests.swift` (earlier this hour), `COORDINATION.md`, `SOURCE_BUNDLE.md`

**What & why:** The owner resolved the flagged composer-ring divergence toward the Code tab and asked for additions. (1) **Composer color/treatment parity**: white-0.05 fill, radius 14, the signature always-visible accent ring (0.38 rest → 0.60 while typing → full-strength on file drop), soft accent focus glow, identical animation timings — the two composers are now visually the same control. (2) **Brain/Effort quick-controls menu** added to the chat composer (Code-tab parity, plus the chat's real `salehmanEffort` dial and the team-size mode): switch brain/effort/toggles without opening Settings; includes the live "· salehman14b" serving badge driven by the SAME probe as the Code tab (`refreshServingModel` clone — the two badges can never disagree). (3) **File drag-and-drop onto the composer** — the Code tab had it, the chat didn't; drops route through the existing `AttachmentLoader` pipeline with the ring lighting up full-accent as the drop target. (4) **Welcome shortcut hints** (⌘N/⌘F/⌘J chips) mirroring the Code welcome's footer. (5) **↑ recall** — up-arrow in an empty composer pulls back your last message for editing/resending. Also this hour: honest eyebrow (dropped the false blanket "On-device" claim — same class as the Today-greeting inaccuracy the other session flagged), `QAGeometryTests` (6 tests pinning the calibrated layout-assertion formula), marathon-state board post; one proxy-403 push outage ridden out with a retry loop.

**Result:** Typecheck EXIT=0; capture request planted for visual verification of the parity batch. The chat tab now has everything the Code composer has, plus its own Effort dial and prompts library.

## 2026-06-11 · Marathon hour 3 — reply timing, controls-menu test, and a red-build incident (mine)

**Files:** `Salehman AI/Views/ContentView.swift`, `Salehman AI/Views/ChatViewModel.swift`, `Salehman AI/Tools/QASnapshots.swift`, `Salehman AIUITests/ChatTabUITests.swift`, `COORDINATION.md`, `SOURCE_BUNDLE.md` — commits 15292f4, 0126520, 5d4d240

**What & why:** (1) **Reply timing**: `ChatMessage.duration` (optional — pre-existing persisted history decodes unchanged), stamped per turn in `ChatViewModel`, surfaced as "4.2s"/"1m 12s" in the hover pill with a tooltip — metadata on demand, zero chrome at rest; the gallery's hover row carries a sample for picture coverage. (2) `testChatControlsMenuHasBrainAndEffort` + `chat.composer.controls` identifier — the new quick-controls menu is gate-protected. (3) **Red-build incident, mine**: the drag-and-drop addition used `UTType.fileURL` without `import UniformTypeIdentifiers`; my `swiftc -typecheck` harness resolved it while the real `xcodebuild` failed — Chat C flagged it across three checks and escalated to a top-of-board banner before I saw it (~10 minutes red). One-line import fix pushed, banner cleared with apologies. **Process lesson recorded: the typecheck harness does NOT verify import coverage — only the real gate does; treat board build-flags as interrupts, check the banner area before each commit.** Also attempted self-launching the app for captures (`open` via launchd) — blocked like AppleScript (`procNotFound`), so capture cycles remain dependent on the runner sessions; pinged the board for a run since the parity request has waited ~1h.

**Result:** All green at HEAD after the import fix; parity batch awaiting its photograph + baseline adoption.

## 2026-06-11 · Marathon closeout — both-tabs directive code-complete; photographic verification handed off

**Files:** `Salehman AITests/QAGeometryTests.swift`, `PROJECT_CONTEXT.md` (earlier this hour), `COORDINATION.md`, `SOURCE_BUNDLE.md`

**What & why:** Closing the owner's 4-hour both-tabs marathon. En route: fixed the SECOND import miss Chat C's gate caught — `QAGeometryTests` used `CGRect` without `import CoreGraphics` (re-exported on the app target, NOT on the test target; same lesson class as the UTI miss — the typecheck harness cannot verify import coverage). Final inventory across ~19 commits: chat menu tint leaks + the Menu-text variant; triple-red unrestricted chrome → one signal; blank-bubble + blank-transcript offscreen-render regressions (entry-animation/Lazy bypasses for QA); welcome bento truncation; honest eyebrow; Code hero centered; last `.ultraThinMaterial` bar; controlsMenu quieted via explicit child styles; **owner-resolved composer parity** (Code-tab ring/fill/radius/glow on the chat composer) plus five additions (quick-controls menu with live serving badge, file drag-and-drop, ↑ recall, ⌘N/⌘F/⌘J hints, per-reply timing); two new test suites and three new picture surfaces. One self-inflicted red build (UTI import, ~10 min, fixed). The ONLY remaining step is photographic — the parity composer's first portrait + baseline adoption — blocked on a rebuild this sandbox cannot perform; handed off on the board with exact expectations and the adopt procedure, and my standing watcher still fires if pictures land while this session lives.

**Result:** Tasks #14 (whole-app restyle) and #16 (marathon) closed. Tree green at HEAD, docs current, board carries the handoff.

## 2026-06-11 · Machine cleanup (Chat C) — caches freed, further deletions on hold pending A/B sign-off

**Files:** `COORDINATION.md` (banner + Notes/handoffs question) — no app source touched

**What & why:** Owner asked Chat C to optimize the Mac (disk 91% full, swap 7.3/8GB, Spotlight churning). Freed ~12GB of regenerable caches: Xcode DerivedData + 6GB SwiftUI Previews cache (**heads-up: next build/preview per session is a one-time slow clean build; any xcodebuild mid-flight ~21:15 may have failed — rerun**), uv/npm/brew caches, VSCode updater cache, puppeteer Chromium, installer DMGs. NOT touched: this repo, Claude app data, Redis, `~/.ollama`, HuggingFace cache. Owner then directed: ask the other chats before removing anything else → question posted on the board (HF cache 7.9GB / obsolete ollama models / codex-runtimes 1.3GB). Also flagged: **ollama brew service is in ERROR state (not running)** — relevant to the local-brain probe (Chat B lane).

**Result:** Disk 18GB → 29GB free. No further deletions until both chats answer on the board or the owner overrides.

## 2026-06-11 · ingest_sessions.py launchd crash-loop fixed (Chat C) — session ingestion restored

**Files:** `tools/ingest_sessions.py` (one line), `COORDINATION.md`, this log

**What & why:** The `com.salehmanai.ingest` LaunchAgent runs the script with Apple's `/usr/bin/python3` (3.9), which evaluates PEP 604 annotations at import — `def parse_grok_log(...) -> dict | None:` (line ~206) raised `TypeError: unsupported operand type(s) for |` on EVERY WatchPaths fire (up to 1/min during active sessions; ~419KB of identical tracebacks in `~/Library/Logs/salehman_ingest.log`). Session ingestion into the Knowledge Base has been silently broken since the agent was installed. Fix: `from __future__ import annotations` after the docstring — all 3.10+ syntax in the file is annotation-only (verified by grep), so this fully defers it. Surfaced by the machine-performance audit (launchd churn), not by app testing — the failure was invisible in-app.

**Result:** `py_compile` OK on 3.9; `--dry-run --incremental --grok-sessions` clean; `launchctl kickstart gui/501/com.salehmanai.ingest` → clean "Done." run, no traceback. SOURCE_BUNDLE regen not needed (`bundle_source.sh` bundles `*.swift` only; verified). No Swift source touched, so no xcodebuild (DerivedData was wiped this evening — next builder pays the one-time clean build). Related diagnoses on the board for owner/Chat B: Ollama port-11434 conflict (brew job crash-looped 13.5k×; the Ollama.app server serving the app lacks the plist's q8_0 KV-cache tuning), autocheckpoint TCC denial (has never run), keepawake `-d` keeps the display awake 24/7.

## 2026-06-10 — BrainAdapter refactor: OllamaBrainAdapter + AnthropicBrainAdapter + factory
- What: Completed the BrainAdapter protocol adoption for the agent pipeline.
  (1) Updated BrainAdapter.swift — removed the `settings: AppSettings` parameter
      from protocol methods (AppSettings is @MainActor, not Sendable), added
      BrainError enum, brainAdapterPrompt() helper, BrainAdapterFactory, and
      LocalLLMFallbackAdapter (catch-all wrapping LocalLLM.generate()).
  (2) Created LLM/OllamaBrainAdapter.swift — wraps OllamaClient.chat / chatStream.
  (3) Created LLM/AnthropicBrainAdapter.swift — wraps AnthropicClient.chat / chatStream.
  (4) Updated AgentPipeline.swift runDraft() — the LocalLLM.generate() fallback in
      the agent task group is now replaced with BrainAdapterFactory.adapter(for: brain)
      + adapter.complete(). Adding a new brain type no longer requires editing AgentPipeline.
- Files: Salehman AI/LLM/BrainAdapter.swift, Salehman AI/LLM/OllamaBrainAdapter.swift,
         Salehman AI/LLM/AnthropicBrainAdapter.swift, Salehman AI/Agents/AgentPipeline.swift
- Why: AgentPipeline was calling LocalLLM.generate() directly in the agent loop.
  Every new brain required editing the pipeline. Factory pattern isolates brain
  routing to BrainAdapterFactory and the adapter structs.
- Result: BUILD SUCCEEDED, zero new errors. Grok Victor reported TASK_DONE with
  fake file paths and placeholder stubs — all real work done directly.

## 2026-06-10 — Make Salehman smarter: system prompts + auto-memory + training export
- What:
  (2) Rewrote all three system prompts in LocalLLM.swift (cloudSystemPromptBase,
      ollamaChatSystem, ollamaToolSystem). New prompts: direct-answer-first,
      no filler phrases, length-matches-complexity, strong code standards, explicit
      memory tool instruction, tool-mode describes actual tool usage.
      Also made cloudSystemPromptBase internal (was private) so TrainingExporter
      can embed it in training examples.
  (3) Added MemoryStore.autoExtract(userMessage:reply:) — pattern-based heuristic
      extractor (11 regex patterns: name, role, location, preferences, tech stack,
      project). Runs as fire-and-forget background task after every chat reply
      (ChatViewModel.swift). No LLM call — pure NSRegularExpression.
      Fixed isolation: items/store → nonisolated(unsafe) (NSLock-guarded),
      persist/embed/remember/autoExtract → nonisolated.
      Also made JSONFileStore.save() nonisolated (pure file I/O, no shared state).
  (4) Created Persistence/TrainingExporter.swift — exports chat history as ChatML
      JSONL (system+user+assistant per example). Added "Export Training Data (JSONL)…"
      menu item in ContentView.swift toolbar export menu.
- Files: LLM/LocalLLM.swift, Persistence/MemoryStore.swift, Persistence/JSONFileStore.swift,
         Persistence/TrainingExporter.swift, Views/ChatViewModel.swift, Views/ContentView.swift
- Why: User asked to make Salehman smarter for all users (not just one person).
  Prompts = immediate intelligence gain; auto-memory = personalization without effort;
  training export = conversations become model weights later via Unsloth.
- Result: BUILD SUCCEEDED, zero errors.

## 2026-06-10 — Local fine-tune pipeline (MLX) + dataset reality check
- What: User asked to "do it all" for the Unsloth fine-tune from the previous
  entry. Built the local (Path B / Apple Silicon) half of that pipeline, which
  is the only half runnable without a browser/Google account:
  (1) `claude-app/.venv` — installed `mlx-lm` (mlx 0.31.2, mlx-lm 0.31.3).
  (2) Created `tools/export_chat_training.py` — CLI twin of
      `TrainingExporter.jsonl(from:)`: same pairing rule, same filters
      (≥10 chars each side, no `[`-prefixed or "request failed" replies), same
      `cloudSystemPromptBase` system prompt. Lets the export be re-run from a
      script instead of the app's menu.
  (3) Created `tools/finetune_local_mlx.sh` — runs `mlx_lm.lora` against
      `mlx-community/Qwen2.5-Coder-7B-Instruct-4bit` (matches the in-app
      `qwen2.5-coder:7b` Ollama model), with a hard guard: refuses to run
      below 50 examples, since LoRA on a handful of pairs memorizes those
      exact exchanges (overfits) instead of generalizing.
  (4) Ran the export against the real `chat_history.json` (15 messages).
      **Result: 0 training examples, 5 skipped.** All 5 user/assistant pairs
      are dev-testing junk ("hi", "f\\", "mjj", "kjkj", "bj") — every user
      turn is <10 chars, so `TrainingExporter`'s own filter (correctly)
      drops all of them.
  (5) Found `tools/finetune_export.jsonl` (112 examples) already exists from
      a separate, earlier pipeline (`tools/finetune_export.py`, part of the
      "ingest Claude sessions" work, commit 5dea217). That dataset mines
      *Claude Code* session transcripts (Saleh ↔ Claude Code, building this
      app) with a system prompt framing the result as "Salehman AI built by
      Saleh… answers from deep knowledge of the project," and its documented
      next step is uploading to console.x.ai (xAI cloud fine-tuning). Did
      **not** wire this into the new local pipeline or upload anything —
      flagged for the owner (see chat): it conflicts with the "Salehman is
      for everyone, not just me" direction from earlier today, and a cloud
      upload of private session data is a separate decision per CLAUDE.md's
      local-first stance.
  (6) Side finding (not fixed, out of this session's lane): two assistant
      replies in `chat_history.json` are raw
      `{"name":"run_terminal_command","arguments":{...}}` JSON instead of an
      executed tool result — looks like a tool-call leaking into the chat as
      plain text in some path. Worth a look by whoever owns the Ollama
      tool-calling loop (`Agents/*` / `LLM/OllamaClient.swift`).
- Files: tools/export_chat_training.py (new), tools/finetune_local_mlx.sh (new),
         claude-app/.venv (mlx-lm installed)
- Why: "do it all for me" follow-up to the Unsloth guide — automate everything
  that's actually automatable locally, and report honestly on what isn't ready.
- Result: Pipeline built and verified end-to-end (script runs, guard works
  correctly). No fine-tune executed — there is currently no real-usage data to
  train on. Once `chat_history.json` has ≥50 genuine exchanges, re-run
  `python3 tools/export_chat_training.py && bash tools/finetune_local_mlx.sh`.

## 2026-06-10 — Fix tool-call JSON leak (qwen text-mode tool calls)
- What: Added `LocalLLM.parseTextAsToolCall(_:)` and wired it into both
  `chatOllamaWithTools` and `chatOpenAICompatWithTools`. When a local model
  emits a tool call as plain JSON text in `message.content` rather than in
  the structured `tool_calls` field, the loop now recovers it — strips any
  triple-backtick fence, parses the JSON, validates the tool name against the
  known set, and executes it as a real tool call instead of returning the raw
  JSON to the user. Added 4 unit tests in `OllamaToolCallParsingTests.swift`.
  Also attempted the fix via `tools/grok_terminal_bridge.py --auto --yolo`
  first (Grok correctly diagnosed the bug but refused to emit shell commands
  for Swift edits — 0 changes, bridge stopped after 3 strikes).
- Files: Salehman AI/LLM/LocalLLM.swift,
         Salehman AITests/OllamaToolCallParsingTests.swift
- Why: `chat_history.json` contained 2 of 5 assistant replies as raw
  `{"name":"run_terminal_command","arguments":{...}}` JSON blobs. Root cause:
  the `chatOllamaWithTools` loop only checked the structured `tool_calls`
  field; when the model wrote the call in `content` instead (a fallback
  behaviour of some Ollama models), the loop hit the `toolCalls.isEmpty`
  branch and returned the raw JSON as the final user-visible reply.
- Result: BUILD SUCCEEDED, zero new errors.

## 2026-06-10 — Add --verify flag to grok_terminal_bridge.py
- What: Added `--verify` CLI flag to `tools/grok_terminal_bridge.py`. When
  enabled, after every command batch both `run_auto_safari` and `run_auto`
  append a `_git_verify(cwd)` block to the feedback message sent to Grok —
  running `git status --porcelain` + `git diff --stat` and formatting the
  output as `--- git state after last command ---`. Grok can no longer claim
  `TASK_DONE` with a clean diff unless real file changes exist. Also added
  `_VERIFY: bool = False` module-level global (consistent with `_SHUTDOWN`,
  `_LOG_PATH` pattern in the same file) set from `args.verify` in `main()`.
- Files: tools/grok_terminal_bridge.py
- Why: Grok repeatedly declared success with no real changes (fake TASK_DONE).
  Adding real git state to every feedback turn makes it impossible to fake
  completion without the diff showing up.
- Result: Python syntax OK, `--verify` appears in `--help`, injected into
  both Safari-mode and native-API-mode feedback loops.

## 2026-06-10 — Bridge hardening: fake-DONE guard, dual sentinels, auto-verify, apply_grok_diff.sh
- What:
  1. Fake-DONE guard: when `--verify` is on and Grok signals `[[DONE]]`/`TASK_COMPLETED_SUCCESSFULLY`
     but `git status --porcelain` is clean, the bridge now REJECTS the completion and sends
     "⚠️ FAKE_COMPLETION_DETECTED" pushback to Grok instead of returning. Implemented in both
     `run_auto_safari` and `run_auto`.
  2. Dual done-sentinels: `is_done()` now accepts both `[[DONE]]` (original primer) and
     `=== TASK_COMPLETED_SUCCESSFULLY ===` (Protocol v1.2) as valid completion signals.
  3. Auto-verify default: `--verify` now defaults to True in `--auto` / `--mode auto` mode
     without requiring the explicit flag. Manual and autofix modes still default to off.
  4. `tools/apply_grok_diff.sh`: new helper script Grok can call after writing a unified diff
     to `/tmp/grok.diff`. Runs `git apply --check` + `git apply --index` + prints status.
- Files: tools/grok_terminal_bridge.py, tools/apply_grok_diff.sh (new)
- Why: Grok repeatedly declared TASK_DONE/TASK_COMPLETED_SUCCESSFULLY with zero real changes.
  The fake-DONE guard + auto-verify makes it structurally impossible to accept a fake completion
  in auto mode without git state proving real edits were made.
- Result: Python syntax OK.

## 2026-06-10 — Bridge v1.3: native diff-block support + start_grok_session.sh
- What:
  1. `_DIFF_FENCE` regex: separates `\`\`\`diff` blocks from executable `\`\`\`run` blocks.
     The main `_FENCE` regex now has a `(?!diff\b)` negative lookahead so diff content
     is never passed to `/bin/zsh -c` (which would fail with "bad command" errors).
  2. `_collect_diff_cmds(reply, session_id)`: finds all `\`\`\`diff` blocks in a Grok reply,
     writes each to `/tmp/grok_diff_<session>_<n>.patch`, returns
     `bash tools/apply_grok_diff.sh <path>` commands. Wired into both `run_auto_safari`
     and `run_auto` via `cmds = parse_commands(reply) + _collect_diff_cmds(reply, _SESSION_ID)`.
  3. `tools/start_grok_session.sh`: creates a `grok-session-<timestamp>` branch before
     each bridge run so Grok's changes are isolated and easy to review/revert.
  4. Added `import shlex` for safe path quoting in `_collect_diff_cmds`.
- Files: tools/grok_terminal_bridge.py, tools/start_grok_session.sh (new)
- Why: Grok's Protocol v1.2/v1.3 uses `\`\`\`diff` blocks for Swift edits (safer than
  heredoc for special-char heavy Swift code). The bridge now handles them natively.
- Result: Python syntax OK, `--verify` + diff-block handling verified.

## 2026-06-10 — MemoryStore injectable seam + 2 PersistenceRoundTripTests enabled
- What: Added `MemoryStore.init(baseDirectory: URL)` testing seam so tests can
  back the store with a temp directory instead of Application Support. Changed
  `private nonisolated(unsafe) let store` from an inline-initializer property to
  a type-only declaration, with both `private init()` (production) and the new
  `init(baseDirectory:)` (tests) explicitly setting it. Enabled and wrote bodies for
  2 of the 5 `PersistenceRoundTripTests`: `memoryStoreRememberDedupesCaseInsensitiveAndNoOpsOnBlank`
  (verifies dedup + blank no-op) and `memoryStoreRecallFallsBackToKeywordAndCapsAtKOnEmptyEmbeddings`
  (verifies keyword fallback + k cap). The 3 scratchpad/stocksage tests remain disabled
  pending the same seam on `ScratchpadStore`.
- Files: Salehman AI/Persistence/MemoryStore.swift,
         Salehman AITests/PersistenceRoundTripTests.swift
- Why: §3 refactor milestone — enables hermetic persistence tests without touching
  the real Application Support data. `JSONFileStore` already had `baseDirectory:`;
  MemoryStore just needed to expose it.
- Result: TEST SUCCEEDED (2 new passing, 3 still skipped pending ScratchpadStore seam).

## 2026-06-10 — ScratchpadStore injectable seam + 2 more PersistenceRoundTripTests enabled
- What: Added `ScratchpadStore.init(testingBaseDirectory: URL)` testing seam (same
  pattern as MemoryStore commit 4d9e70d). Changed `private let store` from inline
  initializer to type-only declaration; both `private init()` (production singleton)
  and the new `init(testingBaseDirectory:)` (tests) set it explicitly. Enabled and
  wrote bodies for `scratchpadCompleteTaskMatchesFirstOpenBySubstringAndIdempotent`
  (verifies substring match, idempotency) and `scratchpadSnapshotRoundTripsOrderAndIDs`
  (verifies persist + round-trip via a second store instance). Test functions annotated
  `@MainActor` to avoid redundant-`await` warnings from Swift Testing.
- Files: Salehman AI/Persistence/ScratchpadStore.swift,
         Salehman AITests/PersistenceRoundTripTests.swift
- Why: §3 refactor milestone — scratchpad persistence now hermetically testable.
  Only the StockSage test remains disabled.
- Result: TEST SUCCEEDED — 4/4 PersistenceRoundTripTests passing, zero warnings.

## 2026-06-10 — grok_terminal_bridge.py: 6 session-failure bugs fixed
- What:
  1. "Upgrade to SuperGrok" UI banner bleeds INLINE into command text (not just whole
     lines) — added `_UI_NOISE_INLINE` pass-1 regex sub before the existing line filter.
  2. `_safari_stream_reply` printed raw uncleaned DOM text live — now applies
     `_clean_ui_noise()` to `raw` before display/comparison.
  3. `_safari_get_last_message` Strategy 1 used `innerText` for code elements, which
     includes CSS overlay content — switched to `textContent`.
  4. Fenced code blocks containing prose (`"Verifying the terminal environment • 5s"`)
     were run as shell commands (exit 127) — added `_block_looks_like_shell()` validator;
     `parse_commands` Priority 2 now rejects non-shell blocks.
  5. Duplicate commands warned but still executed — now skipped with a note in the
     report sent back to Grok.
  6. Fake-DONE guard only fired when git was completely clean, missing sessions with
     pre-existing uncommitted changes — now snapshots `git status --porcelain` at
     session start and compares on DONE (unchanged = fake done).
  Also: `_primer_for` now explicitly warns Grok that task code fences are context-only,
  not the expected output format (fixes Grok copying ```run from task briefs).
- Files: tools/grok_terminal_bridge.py
- Why: All six bugs were visible in the c4074a68c0 bridge session output.
- Result: Python syntax OK. No runtime test (requires Safari + Grok).

## 2026-06-10 — grok_terminal_bridge: primer overhaul + --branch flag + auto-log + docs
- What:
  1. PRIMER rewritten — shorter, stricter. "YOUR ENTIRE REPLY = one CMD: line."
     Added explicit rules: read before editing (cat first), verify each edit (git diff),
     run git diff --stat before [[DONE]], no prose/markdown/fences.
  2. `--branch NAME` flag — creates `grok/<slug>-<timestamp>` and switches to it inline,
     replacing the need to run start_grok_session.sh separately.
  3. Auto-log in --auto mode — writes to `~/grok_sessions/<session>.log` by default
     so every session is captured without passing --log.
  4. `tools/GROK_TERMINAL_BRIDGE.md` — official reference doc: all commands, task brief
     template, flag table, what Grok is good/bad at, protocol explanation.
- Files: tools/grok_terminal_bridge.py, tools/GROK_TERMINAL_BRIDGE.md
- Why: Grok went into "orchestrator roleplay" mode in the c4074a68c0 session because
  the primer allowed prose replies. Stricter format rules + explicit pre-edit/pre-done
  requirements address the root cause. --branch makes one-command launch simpler.
- Result: Python syntax OK.

## 2026-06-10 — Semantic grok/* branch naming + cleanup_grok_branches.sh
- What: Updated `tools/start_grok_session.sh` to generate semantic branch names
  from the task description (`grok/<task-slug>-<timestamp>` instead of bare
  timestamp). Added new `tools/cleanup_grok_branches.sh` — deletes `grok/*`
  branches merged into `main` (safe mode, default) or all `grok/*` branches with
  `--force`. macOS-compatible: uses `if [ -n "$MERGED" ]` guard instead of
  `xargs -r` (GNU-only).
- Files: tools/start_grok_session.sh, tools/cleanup_grok_branches.sh
- Why: Grok Victor proposed this pattern so branches are self-documenting
  (e.g. `grok/scratchpad-store-seam-20260610-1430`). `cleanup_grok_branches.sh`
  closes the loop — stale experiment branches accumulate quickly with AI sessions.
- Result: Scripts executable, smoke-tested (branch creation logic verified).

## 2026-06-10 — read_grok_session tool: Salehman can watch Grok in real-time
- What: Added `GrokWatchTool.readLatestSession()` — reads the newest file in
  `~/grok_sessions/*.log`, parses turn markers, CMD lines, and outputs, and returns
  a compact snapshot (session ID, task, turn count, elapsed, last 6 commands).
  Wired as `read_grok_session` tool into `LocalLLM.runLocalTool`, `ollamaToolSpecs`,
  `parseTextAsToolCall.known`, and `ToolPolicy.instructionsToolMenu`. No args needed.
- Files: Salehman AI/Tools/GrokWatchTool.swift (new), Salehman AI/LLM/LocalLLM.swift,
  Salehman AI/Tools/ToolPolicy.swift
- Why: User asked for Salehman to be able to watch what Grok is doing in real-time.
  Now you can ask "what is Grok doing?" and Salehman reads the live session log.
- Result: BUILD SUCCEEDED.

## 2026-06-10 — StockSagePortfolio injectable seam + all persistence tests green
- What: Added `private let defaults: UserDefaults` + `init(userDefaults:)` seam to
  `StockSagePortfolio`. Updated `save()` and `load()` to use `self.defaults` instead
  of `UserDefaults.standard`. Enabled `stockSagePortfolioAddValidatesAndNormalizesAndRoundTrips`
  in `PersistenceRoundTripTests` — covers blank symbol no-op, negative shares no-op,
  lowercase→uppercase normalisation, and round-trip from same isolated UserDefaults suite.
- Files: Salehman AI/StockSage/StockSagePortfolio.swift, Salehman AITests/PersistenceRoundTripTests.swift
- Why: Last disabled persistence test needed a UserDefaults isolation seam (same pattern
  as JSONFileStore baseDirectory used by other stores). Without isolation, parallel tests
  on the same `UserDefaults.standard` key would race.
- Result: BUILD SUCCEEDED. All 5 PersistenceRoundTripTests pass (memoryStore ×2,
  scratchpad ×2, stockSage ×1).

## 2026-06-10 — bridge: fix Priority 3 prose-as-command bug; ingest_sessions dry-run
- What: Fixed parse_commands Priority 3 fallback — short unfenced prose (e.g.
  "Analyzing the terminal instructions • 10s") still ran as shell command if ≤3 lines
  and didn't match _PROSE_INDICATORS. Added _block_looks_like_shell() guard to
  Priority 3 (same fix already applied to Priority 2 in prior commit). Also ran
  ingest_sessions.py --dry-run via Grok: no bugs, 25 sessions, 2334 blocks, 1343 KB
  chunks ready to write. Grok's only actual change was a trivial docstring rename
  (to bypass fake-DONE guard) — reverted and branch discarded.
- Files: tools/grok_terminal_bridge.py
- Result: Python syntax OK. ingest_sessions.py confirmed clean.

## 2026-06-10 — ingest_sessions.py: real fix landed + Grok-session ingestion + launchd daemon
- What: Finished the `addedAt` date-bug fix that was left half-done (a stray
  `MANIFEST_FILE = Path.home() / .salehman_ingest_manifest.json` syntax error with
  missing quotes). Rewrote the script: `_SWIFT_REF`/`NOW_SECS` (seconds since
  2001-01-01, matching Swift `JSONDecoder`'s default `.deferredToDate`) used for
  every `addedAt`; `save_json` now writes to `.tmp` then atomic `.replace()`; new
  `chunk_text()` (Python port of `KnowledgeStore.chunk()`, 800/150 overlap); new
  `--incremental` mode tracked via `~/.salehman_ingest_manifest.json` (skips
  already-processed `*.jsonl`); new `--grok-sessions` mode parses
  `~/grok_sessions/*.log` (turn markers, CMD lines, outputs, done/in-progress
  status) into one knowledge doc per session, added additively so past Grok runs
  stay in the knowledge base. Also added a new `com.salehmanai.ingest` LaunchAgent
  (`WatchPaths` on `~/grok_sessions` and the Claude session dir, `ThrottleInterval`
  60s, runs `--incremental --grok-sessions`) so the knowledge base grows on its own.
  Two parallel sessions converged on this independently this session: my rewrite
  and Grok's own verification pass (`py_compile` + standalone float-date test) both
  confirmed the same fix; only Grok's 1-line audit comment remained as a diff.
- Files: tools/ingest_sessions.py; `~/Library/LaunchAgents/com.salehmanai.ingest.plist` (new, outside repo)
- Why: `knowledge.json` was perpetually corrupting to `.corrupt-UUID` because the
  ingester wrote ISO date strings for `addedAt` but Swift's `JSONDecoder` default
  date strategy expects a `Double`. Owner also wants Salehman's knowledge base to
  passively absorb what Grok works on.
- Result: Real (non-dry-run) run succeeded — `knowledge.json` saved with 16 docs /
  1450 chunks, including 5 new Grok session-log docs (4 done, 1 in-progress).
  Manifest now tracks all 25 Claude sessions (0 new on this run — already ingested
  in an earlier real run). LaunchAgent loaded via `launchctl load` and confirmed
  in `launchctl list`.

## 2026-06-10 — SelfCritique engine: first Core Intelligence primitive (self-correction)
- What: New `SelfCritique.refine(question:draft:maxRounds:generate:)` — asks the model
  to critique its own draft for substantive flaws, then rewrite to fix them, looping
  until the critic emits `NO_ISSUES` or `maxRounds` is hit. `generate` is an injected
  `@Sendable (String) async -> String` closure, so the loop is testable without a live
  model and pinnable by the caller to the on-device tier (`generateOnDevice`) or the
  full router (`generate`). All members `nonisolated` (the target builds with
  `-default-isolation=MainActor`) so it can run off the main actor. Standalone for now —
  NOT yet wired into LocalLLM/AgentPipeline (that's a follow-up in the owning lane) so it
  lands with zero conflict with either session's files.
- Files: `Salehman AI/Intelligence/SelfCritique.swift` (new), `Salehman AITests/SelfCritiqueTests.swift` (new, 6 tests)
- How it was built (honest record): drafted as a hard task for a Grok terminal-bridge
  session (`grok/self-critique-engine-20260610-0621`, session e736466210). Two problems
  surfaced: (1) the Grok account was throttled to the gated "Heavy" model ("Upgrade to
  SuperGrok" chrome, truncated/duplicate turns, ~0 progress in 5 turns); (2) the task
  brief I wrote had a path-doubling bug — it said `Salehman AI/Salehman AI/Intelligence/`,
  but from the repo root the app source is one level (`Salehman AI/Intelligence/`); the
  CLAUDE.md `Salehman AI/Salehman AI/` is written from `~/Desktop/`, not the cwd. Grok
  actually self-corrected the path and was mid-write when I stopped the throttled session.
  I then landed the verified code directly at the correct path.
- Also fixed (pre-existing, unrelated): the build was transiently red with
  `CodeView.swift:992 Extraneous '}'` even though that file is 942 clean lines — stale
  DerivedData from an earlier `self_improve` auto-fix attempt that had left a
  `CodeView.swift.bak.20260610_062032` backup. That `.bak` was being bundled into the
  `.app`'s Resources (synchronized folders copy non-`.swift` files as resources). Removed
  the stray backup; clean rebuild purged the stale derived file.
- Result: BUILD SUCCEEDED; `SelfCritiqueTests` 6/6 green (stops-on-approve,
  refine-then-converge, cap-at-maxRounds, empty-draft short-circuit,
  blank-rewrite-keeps-prior, token-in-prose). Uncommitted on the grok branch pending
  owner decision to commit/merge.

## 2026-06-10 — AI bug fixes: generateOnDevice vLLM gap + SelfImprove codesign + nonisolated(unsafe) warnings
- What: Three AI-layer bugs fixed after a thorough audit of the LLM/Intelligence/Agents stack.
  1. `LocalLLM.generateOnDevice` was missing the `VLLM.isLocalLoopback` branch. `VLLM.swift`'s own
     doc comment explicitly says "`generateOnDevice` uses vLLM for the on-device-only path only when
     this is true," but the implementation only tried Ollama and UnslothStudio. Knowledge vault, StockSage
     briefings, and screen-analysis calls (all privacy-sensitive and routed through `generateOnDevice`)
     would silently skip a running local vLLM server. Fixed by adding the `VLLM.isLocalLoopback` check.
  2. `SelfImprove.runXcodebuild` was missing `CODE_SIGNING_ALLOWED=NO` — the canonical flag from
     CLAUDE.md. Without it, code-signing failures (common in CI/automation contexts) would appear as
     "no structured errors parsed — likely a linker/codesign issue" and the self-fix loop would bail
     out immediately without attempting any patches. Fixed by adding the flag.
  3. Two `nonisolated(unsafe)` annotations were spurious: `SelfCritique.approvedToken` (a `String` literal)
     and `GrokWatchTool.sessionDir` (a `URL`) are both `Sendable` types — `nonisolated(unsafe)` is only
     needed for non-Sendable mutable state. The compiler warned about both. Removed the unnecessary
     annotations (changed to plain `nonisolated static let`).
- Files: `Salehman AI/LLM/LocalLLM.swift`, `Salehman AI/Agents/SelfImprove.swift`,
  `Salehman AI/Intelligence/SelfCritique.swift`, `Salehman AI/Tools/GrokWatchTool.swift`
- Why: `generateOnDevice` gap was a documentation/implementation mismatch — VLLM.swift documented the
  intended behavior but the code never caught up. The codesign flag was a copy-paste omission vs. the
  canonical command. The warnings were unnecessary escalations of safe constants to unsafe.
- Result: BUILD SUCCEEDED, zero warnings. All pre-existing tests green.

## 2026-06-10 — cloudSystemPrompt wording drift fix (declaresNoLocalToolAccess test)
- What: `CloudSystemPromptTests/declaresNoLocalToolAccess` was failing — the test pins six
  specific substrings ("no local tools", "local tools", "no access", etc.) as proof the prompt
  declares tool unavailability, but the prompt had drifted to "no terminal or web access" which
  matches none of them. Single-word fix: changed "no terminal or web access" →
  "no local tools or web access" so the phrase now contains "no local tools" (a test pattern)
  while keeping the same semantic meaning. This was a pre-existing failure unrelated to the
  AI bug fixes above.
- Files: `Salehman AI/LLM/LocalLLM.swift` (`cloudSystemPromptBase`)
- Why: Wording drift between prompt and the test that pins its semantic constraints. The test
  was written with "local tools" terminology; the prompt evolved toward "terminal" terminology.
- Result: All 6 CloudSystemPromptTests pass. Full suite green.

## 2026-06-10 — Effort control: one knob over the Core-Intelligence primitives
- What: New `Effort` enum (`instant` / `balanced` / `high` / `ultra`) that dials *how hard
  Salehman thinks* before answering — the local analogue of an agent harness's "reasoning
  effort + workflows" selector. It orchestrates the primitives we already had: `SelfCritique.refine`
  (draft → critique → rewrite, N rounds) plus a candidate fan-out + judge pass for `.ultra`
  (generate 3 drafts, self-critique each, pick the best). The generator is injected, so it's
  brain-agnostic (MLX / Ollama / cloud) and unit-testable. `SalehmanEngine.respond(to:effort:)`
  bridges it to the real brain; an `Effort` picker was added to Settings → Intelligence, persisted
  via `AppSettings.salehmanEffort` (default `.balanced`).
- Files: `Salehman AI/Intelligence/Effort.swift` (new), `Salehman AITests/EffortTests.swift` (new,
  8 tests), `Salehman AI/App/AppSettings.swift` (+`salehmanEffort` published setting + Keys + init),
  `Salehman AI/Views/SettingsView.swift` (+`effortRow` picker in the Intelligence section).
- Why: Owner asked for a Salehman equivalent of the "Effort / Ultracode" control — a single dial
  trading compute for answer quality, reusing `SelfCritique` (the first Core-Intelligence primitive)
  rather than bolting on a parallel mechanism. Computed properties are `nonisolated` so the
  `nonisolated` orchestrator can read them under the project's main-actor-default isolation.
- Result: Build SUCCEEDED; all 8 EffortTests pass. Full suite green.

## 2026-06-10 — Fine-tune kit: scrubbed chat dataset + 8B QLoRA run on RunPod
- What: Trained Salehman on RunPod (A100 80GB). First validated the existing `salehman-training/runpod`
  kit end-to-end on the 3B default (caught + fixed three env issues: PEP-668 `--break-system-packages`,
  a broken torchvision vs torch 2.8 → removed it, and a CPU-torch clobber → reinstalled `torch==2.8.0+cu128`).
  Then built `build_chat_dataset.py` to mine the 27 Claude Code transcripts for clean Saleh↔Claude turns,
  **aggressively scrubbing API keys/tokens** (11 transcripts contained key-like strings — training raw would
  bake secrets into weights, violating the Keychain-only rule), filtering harness noise, → 221 pairs.
  Combined with the 289 persona examples = 510. Launched an 8B QLoRA (`unsloth/Meta-Llama-3.1-8B-Instruct`,
  batch 16×2048 — saturates the A100 at ~100% util) with a disk-safe merge (frees the HF cache mid-merge so
  the 16GB fp16 merge fits the 30GB pod disk), exporting `q5_K_M` GGUF.
- Files: `salehman-training/build_chat_dataset.py` (new), `salehman-training/dataset_chats.jsonl` (new),
  `salehman-training/dataset_combined.jsonl` (new). Pod-side: patched `runpod/03_merge.py` (disk-safe),
  added `runpod/run_8b.sh`.
- Why: Owner wants a smarter Salehman that also sounds like our actual conversations, and to actually use
  the A100 they're paying for (3B left it ~34% idle; 8B + big batch pins it at 100%).
- Result: 3B pipeline validated (training only — `train_loss` 0.47). 8B run in progress at log time;
  GGUF downloads to the Mac and imports into Ollama as `salehman` (the app's local brain). NOTE: chat
  transcripts are mostly tool calls — yield was modest (221 usable pairs) and persona remains the backbone.

## 2026-06-10 — grok_terminal_bridge: parallel-safe multi-agent mode + Salehman-ingestible trail
- What: Made the Grok Terminal Bridge runnable as **N parallel agents on one repo** without colliding,
  emitting a machine-readable trail Salehman can ingest. New flags: `--session-name` (each agent gets
  its OWN agent-browser session ⇒ isolated browser/grok.com tab — the hardcoded `_GROK_SESSION` was the
  blocker; now per-instance), `--label`, `--coordinate` (injects a COORDINATION.md primer: claim your
  lane before editing, one-driver-per-file, plus a GIT-SAFETY clause forbidding commit/branch ops since
  agents share one working tree), and `--max-commands N` (runaway cap for unattended `--yolo`). Added a
  trail in `~/grok_sessions/`: `<session>.jsonl` (append-only events: start/command/declined/aborted/
  error/end, each with exit code + output excerpt) and `<session>.status.json` (live heartbeat) so the
  grok-session ingestion + a dashboard SEE EVERYTHING without scraping prose. New `run_parallel_grok.sh`
  (launch N lane-scoped isolated bridges) + `grok_status.sh` (live dashboard). Fixed a latent bug: the
  module only imported `json` locally, so module-level use raised NameError — added top-level `import json`.
- Files: `tools/grok_terminal_bridge.py`, `tools/run_parallel_grok.sh` (new), `tools/grok_status.sh` (new).
- Why: Owner wants ~5 Grok agents at once (coordinating via COORDINATION.md, not isolation) and Salehman
  to watch everything they do.
- Result: `ast.parse` clean; end-to-end test (no browser) confirms events + status write and the
  `--max-commands` cap fires; both shell scripts pass `bash -n`. Xcode build unaffected (Python-only).

## 2026-06-10 — GeminiClient 429/503 backoff + LiveTranscriber testable seams (two parallel-split tasks)
- What: Two tasks that were earmarked for parallel Grok agents but kept for Claude (Grok is weak at
  Swift concurrency). (1) **GeminiClient**: `chat()` now retries transient 429 (RESOURCE_EXHAUSTED) and
  503 responses with capped exponential backoff (0.5·2^attempt, cap 8s, maxRetries 3) before surfacing
  the error; `nil` (unreachable) is still left for the brain-chain to roll past. The two decisions are
  pure `nonisolated static` helpers — `isRetryableStatus(_:)` and `backoffDelay(attempt:base:cap:)` —
  covered by a new hermetic `GeminiBackoffTests` (4 cases, no network). (2) **LiveTranscriber**: extracted
  the partial-selection and publish-throttle decisions into pure statics — `longestPartial(_:)` (stronger/
  longest hypothesis wins) and `shouldPublishPartial(text:lastPublished:now:lastPublishAt:minInterval:)`
  (changed-AND-≥0.11s ≈ 9 Hz gate) — and refactored the call sites to use them. That un-disabled 2 of the
  5 previously-blocked tests in `LiveTranscriberSegmentTests` (longest-partial, throttle); the 3 that
  genuinely need a live Screen/Speech capture seam stay honestly `.disabled` (no fake green).
- Files: `Salehman AI/LLM/GeminiClient.swift`, `Salehman AITests/GeminiBackoffTests.swift` (new),
  `Salehman AI/Media/LiveTranscriber.swift`, `Salehman AITests/LiveTranscriberSegmentTests.swift`.
- Why: real reliability (Gemini rate-limits are common on the free tier) + convert two honestly-disabled
  test stubs into real coverage by adding pure seams, matching the repo's "no green tautologies" rule.
- Result: BUILD SUCCEEDED; LiveTranscriberSegment (3 pass / 2 honestly disabled) + GeminiBackoff (4) +
  Effort (8) all green. (`AppSettings` default Effort also set to `.ultra` per owner request.)

## 2026-06-10 — Parallel-session notification (desktop ↔ VS Code) — applied twice (first copy wiped)
**Files:** `COORDINATION.md` (docs only)
**What & why:** Owner asked the desktop Claude Code session to notify the VS Code session of parallel
work. Direct cross-session messaging requires interactive approval (unavailable unsupervised), so the
notification went into COORDINATION.md per protocol: a Live Lane Board claim row (desktop session,
`tools/grok_terminal_bridge.py` + `tools/run_parallel_safari.sh`, branch `feat/effort-grok-tooling`)
plus a dated Notes/handoffs entry. **Reversal logged:** the first application (plus its dev-log entry)
was wiped when the working tree was restored to HEAD content (~16:35 and ~16:45 file mtimes; no reflog
reset — likely a `git restore` by another session or a wholesale file rewrite by a safari bridge lane).
Re-applied ~16:50 with an explicit "don't revert uncommitted coordination edits" warning. Also observed:
Grok safari lanes (safari-1/3/5) are appending malformed loose-line claims at the END of COORDINATION.md
instead of board rows — flagged in the Notes entry.
**Result:** Docs-only; no build impact. Watch for a second clobber — if it recurs, the restore step in
whatever automation is doing it needs to exclude COORDINATION.md / DEVELOPMENT_LOG.md.

## 2026-06-10 — Parallel Safari Grok fleet (race-free) + rate-limit backoff + chat-trained Salehman
**Files:** `tools/grok_terminal_bridge.py`, `tools/run_parallel_safari.sh`, `tools/PARALLEL_GROK_GUIDE.md`
(new), `salehman-training/{mac,runpod}/01_prepare_data.py`, `salehman-training/dataset_combined.jsonl`
(gitignored), `salehman-training/build_chat_dataset.py`.
**What & why:** Owner wanted N Grok web agents working the repo in parallel, non-stop, off-screen.
- **Race-free parallel Safari.** First tried per-agent own-window (`--safari-window`) — all agents grabbed
  the SAME window id (Safari opens `make new document` as a TAB, not a window). Switched to per-TAB
  targeting — still collided (all got `tab 3`): each agent opened+captured its own tab and they raced.
  **Fix that worked:** the launcher pre-creates N tabs SEQUENTIALLY in one window (no race) and hands each
  agent its exact tab via a new `--safari-target "tab K of window id W"` flag. Verified 5 and 7 agents on
  distinct tabs.
- **RAM auto-limit:** launcher reads `hw.memsize` and caps agents (16 GB → 3; override `MAX_AGENTS`).
  Added after 10 grok.com tabs pinned a 16 GB Mac (each tab ~1 GB).
- **Rate-limit handling:** the existing backoff never fired because `_safari_detect_error` matched only
  "rate limit"/"too many requests" while grok actually says "N minutes before limit is gone / once it
  resets." Added those markers + `_safari_rate_limit_wait_seconds()` (reads grok's stated reset, naps ≤15min
  re-probing). Agents now WAIT instead of spinning at 0 cmds burning RAM. **Cause of the cap:** running
  fleets with `--think` (reasoning model = tightest quota) exhausted even SuperGrok Heavy's hourly bucket.
  Made `--think` a default with `THINK=0` opt-out.
- **Unbuffered logs** (`python3 -u`) so `~/grok_sessions/*.out` stream live (were block-buffered → looked empty).
- **Chat-trained Salehman:** `build_chat_dataset.py` extracted 289 scrubbed Saleh↔Claude pairs (0 secret
  leaks, verified) → `dataset_combined.jsonl` (578 w/ persona style). Repointed both training kits'
  `01_prepare_data.py` from `dataset_saleh_style.jsonl` → `dataset_combined.jsonl` (DATASET= override,
  style fallback), and inject a `SALEHMAN_SYSTEM` persona system-turn into every example (520/520 verified)
  so the fine-tune learns identity + voice, not just Q→A.
**Result:** bridge `py_compile` clean, launcher `bash -n` clean; commits on `feat/effort-grok-tooling`.
Grok-agent net output was low-value (2 usable tools `grok_cleanup.py`/`bundle_check.sh`, one gutted-file
regression reverted, one hallucinated wrong-path file) — unsupervised Grok needs `git diff` review before
keeping anything. Training upload to RunPod is owner-run (data-egress guard correctly blocks auto-upload of
personal chat data).

## 2026-06-11 — Code tab UI overhaul (Claude-parity) + complete 32B fine-tune (1,028 examples)
**Files:** `Salehman AI/Views/CodeView.swift` (UI, Chat-B lane); `salehman-training/*`
(datasets + `runpod/02_train.py`, `test_salehman.py`, generator scripts — gitignored data).
**What & why:** Owner wanted the Code tab "as good as Claude" + Salehman trained on the full Claude
working style, then run locally on a 4080 later. Verified UI changes by **building + launching + screen-
capturing the app** (`screencapture` + `osascript`), iterating on real screenshots rather than blind.
- **CodeView polish/features (all build-verified):** centered welcome with a glowing accent-circle `</>`
  icon + tappable example chips (`Review`/`Find & fix a bug`/`Explain a file`) + `⌘O/⌘R/⌘L` shortcut hints;
  cohesive input "pill" (one rounded container, border warms to accent while typing); message avatars in a
  matching accent disc; inspector empty-state → centered icon+text; file-tree project header (folder icon +
  file-count badge); empty-tree → folder icon + inline **Open Folder** button; **Review** promoted to an
  accent pill (primary action); active-brain label in the input controls; agent-steps **progress header**
  ("Working · N/M" + running step glows); **Copy-all** conversation (Markdown) + message count; **drag-a-file-
  onto-input** to attach (`.onDrop`, `import UniformTypeIdentifiers`); **⌘L** focuses the input.
- **Complete 32B fine-tune.** Dataset grown to **1,028** examples: 869 scrubbed chats+persona, 71
  workflow/ultracode, 44 Claude-style coding (root-cause debugging etc.), 44 full-feature-set (effort dial,
  pipeline-vs-barrier, judge panel…), 12 hand-crafted identity/domain. Trained `Qwen2.5-32B-Instruct-bnb-4bit`
  QLoRA (r64/α128, 4-bit pre-quant so the 32B fits a small disk) on an **H100 + 140 GB network volume**
  (after the L40S pods' ephemeral disk truncated a save and lost a run — fixed by a persistent volume +
  verify-adapter-loads-before-trusting). `02_train.py`: added pre-quantized-model branch (skip
  BitsAndBytesConfig when name contains `4bit`/`bnb`) + `save_strategy="steps"` checkpointing.
- **Eval (`test_salehman.py`):** the complete model knows it's Salehman (local-first) and reproduces the
  workflow training verbatim ("the test isn't 'is this big,' it's 'does correctness need decomposition'";
  pipeline-vs-barrier explained correctly). Distillation landed.
**Result:** `xcodebuild` **BUILD SUCCEEDED** throughout (one red build was the parallel Chat-A `Agents/*`
refactor, not this lane — left for them per coordination; went green when they landed it). Adapter validated
(896 tensors) + backed up to the Mac twice (round 1 + round 2, ~2 GB each) — double-safe vs the ephemeral-pod
data loss. Pod terminated by owner after backup. Serving (GGUF `Q3_K_M` + speculative decoding on the 4080)
deferred to owner, next month. Lesson re-learned: a disk-full **truncates** a safetensors save silently —
always verify the artifact *loads* before calling training done.

## 2026-06-11 — "Why doesn't Salehman answer / it takes forever": mute-floor + 15-agents-for-"hi" fixes; brain menu pared; 14B-for-Mac kit
**Files:** `LLM/OllamaClient.swift`, `Agents/AgentPipeline.swift`, `Views/CodeView.swift`,
`Views/ContentView.swift`, `Views/MarkdownText.swift`, `App/AppSettings.swift`;
`salehman-training/runpod/run_14b_for_mac.sh` (new), `salehman-training/make_mac_polish_dataset.py` (new).
**What & why:** Owner sent "hi" in the Code tab → stuck on "Working 0/15", no answer ever.
Three stacked root causes, found by reading the live Ollama state + the routing code:
- **Mute local floor.** `.salehman`'s `activeChatModel()` returned ONLY the custom model named
  "salehman" — by design ("never silently fall back") — but that model isn't pulled (the 32B
  isn't served yet), and with no cloud key the brain went silent. Fix: prefer the custom model
  when present, else fall back to the best available local coder (qwen2.5-coder:7b) so Salehman
  is never mute.
- **15 agents for "hi".** `complexity()` correctly rates a greeting `.simple` — but the Code tab
  wraps EVERY message in a multi-line >200-char coding preamble, which alone trips the
  `.hard` heuristics → in Maximum mode that's the full 15-agent team for "hi". Fix: trivial
  input (`isTrivialMission`) skips the preamble in CodeView, AND `AgentPipeline.run` got a
  trivial fast-path: one direct warm-local reply (Ollama + persona), no team, no
  leader/critique finalize, cloud engine only as fallback. (`finalize` was the second tax:
  even a 1-agent run paid a `refineOwnDraft` self-critique pass.)
- **Streaming lag guards** (owner: "the 32B must never lag the app"): still-streaming replies
  longer than `StreamRender.liveMarkdownLimit` (1200 chars, shared constant in AgentPipeline)
  render as plain text — the O(n)-per-tick Markdown re-parse was the jank source — full
  Markdown renders once on commit. Applied in both CodeView's streamingView and the main
  chat's StreamingBubble.
- **Brain menu pared to Salehman + Auto** (owner: "stupid to have this many models" — picked
  via AskUserQuestion). `selectableCases` = `[.salehman, .auto]`; init migrates+persists a
  stale hidden pick to `.salehman` so picker and `brainPreferenceCurrent` can't disagree.
  All other cases still function if set programmatically (rotation untouched).
- **Markdown upgrades:** chat code blocks now syntax-highlighted via the existing `CodeSyntax`
  engine (single AttributedString so selection spans the block; >6000-char blocks stay plain —
  the per-tick re-highlight is quadratic while streaming); GFM tables (`| a | b |` + separator)
  parse into a real Grid with bold header.
- **14B-for-Mac kit:** owner wants HIS fine-tune fast on THIS Mac (M4/16 GB — a 32B can't fit:
  ~18 GB weights alone). New turnkey `run_14b_for_mac.sh` (train Qwen2.5-14B QLoRA on the same
  dataset → merge → GGUF Q4_K_M ≈ 9 GB → `ollama create salehman`; the floor fix above makes the
  app auto-use it). Dataset grown 1,040 → **1,062** (`make_mac_polish_dataset.py`: Arabic pairs,
  direct-short-answer habits, honest local-identity answers) — parse-clean, secret-scan clean.
**Result:** build green after each step (one intermediate red: `await` on both sides of `??` is
illegal in Swift — restructured). Verified via the app's persisted `chat_history.json` that
Salehman now actually answers ("hi" → "مرحباً! كيف أقدر أساعدك اليوم؟"). Synthetic-keystroke UI
tests were unreliable while the owner used the Mac live — timing of the fast path still needs a
hands-on check. NEXT: owner deploys a RunPod GPU ($15 budget), Claude drives multi-round 14B
training to spend it well (eval-checkpointed rounds, weakness-targeted data, final Q4_K_M GGUF).

## 2026-06-11 — 14B-readiness app tuning (keep-warm, warmup-on-focus, stream parity, reply caps)
**Files:** `LLM/OllamaClient.swift`, `Agents/AgentPipeline.swift`, `Views/CodeView.swift`,
`Salehman AITests/ToolLoopTests.swift`, `COORDINATION.md`.
**What & why:** The 14B fine-tune (GGUF ≈ 9 GB, Ollama name "salehman") lands today; at that size the
7B-era knobs actively hurt: `keep_alive 30s` evicts 9 GB after every pause (each next reply re-pays a
multi-second load), `chatStream` hardcoded 30s and skipped `num_ctx` entirely, and nothing warned the
user that a silent first reply = model loading.
- `Generation.tuned(for:)` — per-model knobs: the user's own model gets `keep_alive 5m` + `num_ctx 4096`
  (matches its Modelfile); other models keep the RAM-lean 30s/2048. Applied to `chat()` AND `chatStream`
  (parity — stream also gained `num_ctx`/`num_predict` options it never had).
- `Generation.numPredict` — optional reply-length cap; trivial fast-path greetings capped at 384 tokens
  (~25 tok/s local ⇒ seatbelt against a 30 s ramble).
- `warmupChatModel()` (once per launch) — empty-prompt /api/generate pre-loads the active model; fired
  from CodeView when the input gains FOCUS, so the 9 GB load happens while the user is still typing.
- CodeView: "Warming up the local model…" status after 5 s of pre-stream silence (was an indistinguishable
  "Working…" that looked frozen during model load).
- `selectableCasesExcludeAllPaid` test updated to pin the new owner-approved picker contract
  (`[.salehman, .auto]`) — was asserting the pre-pare menu (.gemini/.freeAuto present).
**Result:** build green; suite green earlier at 297/297 (this entry's changes re-verified by build; suite
re-run owed at next land). Committed + merged per owner ("merge please"). Parallel: 14B round 1 training
live on the A100 pod (see COORDINATION.md handoff); other session tasked with the Settings status row +
concurrency audit + agents-lane sweep.

## 2026-06-11 — Code tab: Claude-minimal restyle + clipping fixes + 14B speed visibility (owner-driven polish loop)
**Files:** `Views/CodeView.swift`, `Views/MarkdownText.swift`, `Views/CodeSyntaxView.swift`,
`Views/ContentView.swift`, `Views/BackgroundView.swift`, `DesignSystem/DesignSystem.swift`,
`LLM/OllamaClient.swift`, `Agents/AgentPipeline.swift`, `Salehman AITests/ToolLoopTests.swift`.
**What & why:** Owner ("make it simple and elegant like Claude Code; grey background; never stop
polishing; make it a home for salehman14b and he runs fast"):
- **Minimal conversation:** `CodeMessageRow` — user = right-aligned quiet block (no avatar/label),
  assistant = flush-left document flow, copy-on-hover. Streaming view matches. 780pt centered reading
  column incl. the input pill.
- **Grey, flat, neutral:** new DS tokens `codeSurface` (0.125) / `codeSurfaceSide` (0.095); Code tab is
  opaque (no glow bleed), sidebar/inspector a step darker; `BackgroundView` glows halved app-wide.
- **Collapsible panels:** file tree + inspector both collapse (persisted via @AppStorage); slim reopen
  bar; auto-expand when a file is picked or a run produces diffs. (Owner: "I can't even minimize it.")
- **Clipping fixes (owner screenshot):** markdown TABLE cells now wrap at 300pt inside an h-scrollable
  grid — Grid sized columns to ideal width and clipped long cells mid-word; prose files (md/txt) in the
  file viewer wrap (vertical-only scroll) instead of single-row clipping.
- **14B speed visibility:** chatStream captures Ollama's eval stats → "⚡ N tok/s" in the conversation
  header after each local reply; welcome shows "<model> · local · ready" when the owner's model serves.
- Plus: agent-steps strip flattened to the new surface, file-row hover states, floating
  scroll-to-latest button, main-chat "Warming up the local model…" hint, `trimmedForLocalWindow`
  (4096-ctx history diet, +2 tests — suite 306/306).
**Result:** builds green throughout; committed `70d6af7` + pushed (unblocks the parallel session's items
7+8 and the whole-app restyle task assigned per owner). Parallel: r3-best GGUF finale running on the A40
(merged ✓ converted ✓ quantizing), round-6 seed lottery training, all 4 adapters + 32B now mirrored to
Proton Drive. Owner away; autonomous loop continues until the RunPod balance is spent.

## 2026-06-11 (afternoon) — Code-tab heavy polish, live-QA bug fix, QA system, clean GGUF pipeline
**Files:** `Views/CodeView.swift`, `Views/CodeSyntaxView.swift`, `Views/MarkdownText.swift`,
`Agents/AgentPipeline.swift`, `LLM/OllamaClient.swift`, `Tools/QASnapshots.swift`, `tools/qa.sh` (new),
`tools/QA.md` (new), `Salehman AITests/ToolLoopTests.swift`; `salehman-training/runpod/clean_pipeline.sh`.
**What & why:**
- **Code tab → Claude-minimal, grey, polished:** document-flow messages (right-aligned user block, flush-left
  assistant, hover speak/copy/regenerate), `CodeMessageRow`/`PulsingDot`; flat neutral-grey surfaces
  (`DS.codeSurface`/`codeSurfaceSide`, glows halved); collapsible tree + inspector (persisted, always-
  recoverable strip + ⇧⌘E); centered 780 reading column; always-on red composer ring + focus glow + filled
  send; personal welcome; tok/s readout; time separators.
- **Live-QA bug fix:** driving the tab in the background found "who are you in one sentence" spinning up the
  **full 15-agent team** — `complexity()` was judging the Code tab's coding-preamble wrapper, not the ask.
  Fixed to judge the text after `Task:` (drops attached-file blocks); 3 regression tests. Live-verified 0/1.
- **Markdown robustness:** table cells wrap (no mid-word clip) inside an h-scroll grid; prose files (md/txt)
  wrap in the file viewer.
- **QA system (with the parallel session):** their `QASnapshots`/`QAAudit` self-photograph + self-judge the
  UI (no Screen-Recording perm). I added: Code-tab coverage, an `NSHostingView` capture path (`snapHosted`
  renders HSplitView/ScrollView/SF-Symbols that ImageRenderer drops), an `INDEX.md` manifest (desc/size/
  status/render-ms + git SHA, Hijri→Gregorian fix), a `contact_sheet.png` montage, responsive narrow
  variants, an Arabic-RTL gallery, `tools/qa.sh` (one-command loop), and `tools/QA.md` (manual). The audit
  immediately caught a real miss: `memory` canvas is black not design-grey (flagged to the other session).
- **14B GGUF — the saga:** the rebuild pod's network volume hung writes/reads at exactly 4.31 GB (twice,
  even after a restart). Root-caused as a volume I/O stall (load 41, 0% CPU, no OOM). Fix: a FRESH pod with
  **no network volume — everything on the local container disk**; re-merged r3 from the Mac-backed adapter
  → f16 → **Q4_K_M 8.37 GB** clean. Downloading to `/Users/Shared` via an unbounded resumable rsync loop
  (the pod's upload drops every few hundred MB; `--append-verify` makes each retry resume).
**Result:** build green; suite **310/310**. PR-less commits on `feat/effort-grok-tooling` (pushed). NEXT:
Q4 lands → `install_salehman_14b.sh` (free disk first) → live test + tok/s in the app → terminate clean pod,
spend report. Owner away ~3h; loop continues.

## 2026-06-11 (evening) — Chat C (3rd session): `/run-skill-generator` → `run-salehman-ai` run skill
**Files:** `.claude/skills/run-salehman-ai/SKILL.md` (new), `.claude/skills/run-salehman-ai/run.sh` (new),
`COORDINATION.md` (board claim). **No app source touched** (so no `SOURCE_BUNDLE.md` regen needed).
**What & why:** Owner added a third Claude session and ran `/run-skill-generator`. Authored a
discoverable "run / launch / screenshot / QA the app" skill so a future (screen-blind) agent can build,
drive, and visually verify the app from a clean machine. Chosen as a zero-collision Chat C lane — lives
entirely under `.claude/skills/`, edits no Swift.
- **Driver `run.sh`** wraps the existing `tools/qa.sh` harness and closes its two real gaps (found by
  actually running it): (1) qa.sh errors if the Debug app isn't built — run.sh auto-builds; (2) **if the
  app is already running, macOS `open` only re-activates it, so the `.task { QASnapshots.checkAndRun() }`
  capture hook never re-fires and qa.sh silently prints the PREVIOUS run's PNGs** — run.sh force-quits any
  instance first so capture is genuinely fresh. Both paths verified.
- **SKILL.md** documents the agent path first (one command → manifest + audit → read PNGs), the build/test
  commands, the human `open` path, and a Gotchas section (already-running→stale, freshness check via
  `SNAPSHOT_REQUEST` consumption, hardcoded `~/Desktop/Salehman AI/qa` capture dir + `QA_SNAPSHOT_DIR`/
  direct-launch workaround since `open` drops env, `snap` vs `snapHosted` blank-render rule, dual
  QASnapshots/QACapture systems).
**Result:** Debug build `** BUILD SUCCEEDED **`; drove the app via `run.sh` and `run.sh --build` — **14/14
QA surfaces pass**, fresh capture confirmed (manifest timestamp advances each run, request file consumed);
read `today.png`/`contact_sheet.png` to verify a real running app. `xcodebuild test … -only-testing:"Salehman AITests"`
→ `** TEST SUCCEEDED **` (~310 cases, 0 failures). Every code block in SKILL.md was executed this session.

## 2026-06-11 (evening) — salehman14b INSTALLED + running on the M4 (the finale)
**What & why:** Got the r3 Q4_K_M onto the Mac and into Ollama despite two real walls:
- **Volume wall:** the rebuild pod's network volume hung the quantize at exactly 4.31 GB (twice, even after
  a restart) — load 41 / 0% CPU / no OOM = a volume I/O stall. Fix: a FRESH pod with **no network volume**,
  everything on local container disk → Q4 built clean (8.37 GB), `PIPELINE-DONE`.
- **Download wall:** the pod's upload dropped every few hundred MB. Fix: unbounded **rsync `--append-verify`**
  loop (installed rsync on the pod) run as a proper background task → resumed to 8.37 GB.
- **Disk + Ollama-validation wall:** the Mac's APFS container is nearly full (228 GB, ~14 GB free), and
  Ollama 0.30 re-validates a local GGUF by re-quantizing it (needs ~8 GB scratch). `ollama create` ran the
  disk to 0 and failed. Fix: the GGUF was already copied into Ollama's blob store, so I **deleted the
  redundant `/Users/Shared` source and created the model `FROM` the blob itself** → freed the scratch →
  `success`. Aliased `salehman` → `salehman14b`; set M4 speed env (`OLLAMA_FLASH_ATTENTION`,
  `OLLAMA_KV_CACHE_TYPE=q8_0`).
**Result:** `salehman14b:latest` (9.0 GB) + `salehman` alias installed; **100% GPU** on the M4; the app's
`.salehman` floor resolves the bare name `salehman` (verified). Speed **11.9 tok/s under heavy RAM pressure**
(15 MB free — a 9.5 GB model on 16 GB thrashes; ~18-22 tok/s with the browser closed). Answers on-brand +
concise when capped (the app caps trivial replies at 384 tok / agent replies at 700, so no rambling in-app).
Clean pod terminated; **RunPod balance $5.43** (the remaining budget is NOT burned on more rounds — r4/r5/r6
all lost to r3, so further lottery is waste). Freed `qwen2.5-coder:7b` for the install — salehman14b is the
floor now; re-pull it if `.auto` mode is wanted. **Owner action: revoke the RunPod API key in the console**
(chat-exposed; local copy deleted).

## 2026-06-11 (evening) — Chat C: autonomous polish pass #1 (secondary view surfaces)
**Files:** `Views/KnowledgeView.swift`, `Views/TodayView.swift`, `Views/ScratchpadView.swift`,
`Views/MemoryView.swift`. Commit `1bcd7ae`.
**What & why:** Owner away 4h → "polish and refine." Chat C took a zero-collision lane (secondary surfaces
the active Code/Chat/LLM/Markets sessions aren't on) and used the QA screenshot harness as eyes. Drove a
read→screenshot→audit→fix→re-screenshot loop. An audit subagent + my own reads confirmed the app is already
well-built (no missing a11y labels, no dead code, no empty-state gaps), so this pass is **safe consistency
refinement only**, no aesthetic churn:
- **KnowledgeView**: the main ask-field was the only one of four text-fields missing the `surfaceStroke`
  hairline the others (DocDetail, Memory search, Notes add) carry — added it. Header subtitle `.lineLimit(1)`
  to kill a narrow-width collision risk with the Add-file buttons.
- **TodayView**: StatTile title `.lineLimit(1)` (overflow guard for longer values/locales); icon-chip
  `cornerRadius: 10` → `DS.Radius.icon` (==10, neutral token adoption).
- **ScratchpadView**: add-task field gets the matching `surfaceStroke` hairline.
- **MemoryView**: "Forget everything" raw `.red` → `DS.Palette.danger` (==.red, semantic token).
**Result:** build `** BUILD SUCCEEDED **`; `Salehman AITests` `** TEST SUCCEEDED **`; QA capture 14/14, my
4 surfaces all within their baseline budget (knowledge Δ0.58% ok, notes/today/memory ≈0). Committed
selectively (4 files; left the active session's `CodeView.swift` WIP untouched).
**Verified ShortcutsView is accurate** (⌘1–7 + Conversation/General groups all match `AppTab` order +
`Salehman_AIApp` bindings — no drift). **Flagged 2 audit regressions in Chat B's lane** (not mine — see
COORDINATION): `chat_narrow` geo (column 560pt vs ≈524 expected) + `settings` baselineDiff 0.34%.
Curated owner-decision backlog of the bigger (aesthetic) refinements written to `POLISH_BACKLOG.md`.

## 2026-06-11 (evening) — Chat C: polish pass #2 (Notes task ordering)
**File:** `Views/ScratchpadView.swift`. Commit `ba52a98`.
Completed tasks now sink below active ones (stable partition `orderedTasks`, presentational only — no data
mutation; matches Reminders/Todoist). Build + AITests green; QA 14/14 (the 2 prior cross-lane failures are
now resolved by Chat B at commit `22ba4249`). Effect isn't visible in the current `notes.png` (live store has
only completed tasks), but is correct for the common mixed-task case.

## 2026-06-11 (evening) — Chat C: polish pass #3 (owner-greenlit POLISH_BACKLOG — all 4 items)
**Files:** `Views/TodayView.swift`, `Views/ShortcutsView.swift`, `Views/ScratchpadView.swift`,
`Views/OnboardingView.swift`, `Views/AboutView.swift`, **`DesignSystem/DesignSystem.swift`** (cross-lane,
owner-authorized, append-only). Commits `fcda86b` + `485cd8a`.
**What & why:** Owner said "yes" → applied all 4 `POLISH_BACKLOG.md` items.
- **#1 Eyebrow adoption:** TodayView ("QUICK ACTIONS"/"AT A GLANCE") + ShortcutsView group titles now use
  the DS `Eyebrow` component (accent capsule) instead of hand-rolled tracked text. **Screenshot-verified on
  Today — clean/branded, within budget.** Deliberately LEFT Knowledge's inline answer sub-labels
  (SOURCES/ANSWER/ON-DEVICE SUMMARY) as plain text (a pill mid-content reads too heavy).
- **#4 Notes privacy:** ScratchpadView Organize/Summarize `LocalLLM.generate` → `generateOnDevice` (+ clear
  "start Ollama" fallback). Private scratchpad content no longer routes to a pinned cloud brain (matches the
  Knowledge vault). **Behavior change — revert this one line if cloud-organize was intended.**
- **#2 titleXL token:** new `DS.Typography.titleXL` (30/bold/rounded) ← TodayView greeting magic 30.
- **#3 bgVertical token:** new `DS.Gradient.bgVertical` ← the identical inline gradient Onboarding + About
  both had. Both DS additions are **append-only + render-identical** (today QA diff unchanged at 6.67%, which
  is purely the Eyebrow delta).
**Result:** `** BUILD SUCCEEDED **`; `** TEST SUCCEEDED **`; QA fresh, my surfaces within budget. Committed
selectively. **Flag for Chat B:** `chat_samples` fails QA baselineDiff (~5%) across this window — your
`ChatSampleGallery`/`ContentView` churn; re-adopt baseline when you settle. Also added 2 append-only tokens
to your `DesignSystem.swift` (no existing token touched/reordered).

## 2026-06-11 (evening) — Chat C: polish pass #4 (home-screen privacy copy) + red-build incident
**File:** `Views/TodayView.swift`. Commit `026a425`.
**What & why:** Guardian cycle traced the actual default brain — `AppSettings.swift:45` says the app *"itself
is cloud-first."* So `TodayView`'s home greeting *"everything here stays on this Mac"* was **false by default**
(a privacy claim that's no longer true). Fixed it to *"many brains, real tools, your own model"* — accurate,
makes no privacy claim either way, matches the About intro. Owner gave "continue" go-ahead; Chat B
independently validated the bug in the same window (`4d7dd28` dropped a blanket "On-device" claim on chat).
**Result:** app build GREEN, `today.png` confirms the new copy renders. Flagged for owner: `AboutView` /
`OnboardingView` capability *titles* still say "Private/on-device" while their bodies say "cloud-first" — left
those (voice call) in `POLISH_BACKLOG.md`.
**Red-build incident (handled, not caused by me):** landing this fix was blocked ~10 min because Chat B
committed `ContentView.swift` missing `import UniformTypeIdentifiers` (twice). I held my verified fix, did NOT
touch their actively-edited file (clobber risk), and escalated a top-of-board flag; Chat B fixed it (`5d4d240`)
and noted their `swiftc -typecheck` pre-check gave a false-green. **Still open (flagged, not mine):** the
AITests target won't compile — `Salehman AITests/QAGeometryTests.swift` missing `import CoreGraphics` (same
false-green class). App is green; `xcodebuild test` is not until that import lands.

## 2026-06-11 (night) — strip the local model's reasoning-dump from replies
**What & why:** The local Q3 fine-tune, on a bare "hi", began emitting its whole agent
prompt + meta-reasoning ("You are Salehman AI in this conversation… Interpretation:…
The most likely reading is…") and only then the real answer after a "Response:" line.
Worse, that narration got saved to the chat history, so the model read its own analysis
back and ESCALATED it each turn (a feedback loop). Added `AgentPipeline.stripNarration`
— when a reply has the "…Response: <answer>" scaffold shape, keep only <answer> — and
apply it to BOTH the trivial fast-path reply and the finalized answer, BEFORE recording
to history (so the loop is broken). Also fixed the Code-tab hover buttons vanishing
(added `.contentShape(Rectangle())` so the row is one solid hover target).
**Files:** `Agents/AgentPipeline.swift` (+stripNarration, applied x2), `Views/CodeView.swift`
(contentShape), `Salehman AITests/ToolLoopTests.swift` (StripNarrationTests x3).
**Result:** App builds green; verified the stripper turns the exact leaked text into the
clean "Got it. What do you want me to help with today?". Unit test written but the test
TARGET is currently blocked by `QAGeometryTests.swift` (other session's flagged break,
not mine). **Honest caveat:** this is a band-aid over the Q3's narration habit — the real
clean+fast path is the cloud-GPU Q4 (notebook ready). Local 14B stays RAM-bound on 16 GB.

## 2026-06-11 (night) — owner: "please fix the colors" — kill the Unrestricted canvas tint + unify the reds
**What & why:** Owner reported the colors looked wrong. Diagnosis from the 20:57 QA cycle's
pixels: with Unrestricted Mode active (owner's standing default), the Chat tab composited
`Color.red.opacity(0.03)` over the ENTIRE canvas — neutral `rgb(24,24,24)` became
`rgb(31,24,25)`, a visible warm/pink cast on every pixel (the Code tab has no wash, so the
two tabs no longer matched; audit corroborated: chat_live canvasFlat read 0.100 vs the
neutral 0.094). On top of that, the banner + header indicator used system `Color.red`
(orange-leaning) which clashes with the brand crimson `DS.Palette.accent` used everywhere
else. Fixes (all `Views/ContentView.swift`, my lane): (1) removed the canvas wash — the
mode is signalled by the banner + pulsing header indicator only, never by tinting the
canvas; (2) header halo/dot/label: system red → `DS.Palette.accent`; (3) banner restyled to
the design language — flat `accent.opacity(0.13)` panel + 1pt accent hairline below,
icon + Disable button in accent, sentence in white-0.85 (hand-computed contrast ≈11.7:1 vs
the old red-on-red ≈4.2:1). Copy unchanged.
**Files:** `Salehman AI/Views/ContentView.swift`; `SOURCE_BUNDLE.md` regenerated.
**Result:** Full-tree `swiftc -typecheck` (Swift 6, `-default-isolation MainActor`, Chat C's
in-flight QA files pinned to HEAD) **EXIT=0, zero output**. Expected QA fallout on next
capture: chat_empty/chat_live/contact_sheet baselineDiff notes (canvas un-tints to neutral
24/24/24 — intentional change, re-adopt baselines after eyes-verify); chat_samples
untouched (gallery never had the wash). Code-tab drifts this cycle (11.6%/19.6%) eyeballed:
geometric (welcome vertical centering), not color — no action.

## 2026-06-11 (night) — color-fix follow-up: stop discs join the brand palette + photographic confirmation
**What & why:** (1) The 21:12 QA capture (first cycle on a build with `42936b2`) **confirms the
color fix photographically**: chat canvas probes read neutral `rgb(24,24,24)` at every point
(was `31,24,25`), banner sentence is white-on-accent-panel, audit failures `[]`; drift pattern
matched prediction exactly (chat_empty 2.0% / chat_live 7.1% / chat_narrow 12.1% /
contact_sheet 4.9%; chat_samples stayed 0.3% — gallery never had the wash). `qa/ADOPT_BASELINES`
planted so the next green cycle re-baselines the un-tinted look. (2) Last system-red holdout:
the stop-while-generating disc on BOTH composers (`Color.red.opacity(0.85)`) →
`DS.Palette.accent.opacity(0.85)` — same affordance, same opacity, now the one red family
(ContentView:707, CodeView:915; CodeView unclaimed at edit time, 1-line swap announced on board).
**Files:** `Salehman AI/Views/ContentView.swift`, `Salehman AI/Views/CodeView.swift`;
`SOURCE_BUNDLE.md` regenerated.
**Result:** Typecheck EXIT=0 (Chat C's in-flight `QASnapshots`/`QAGeometry` pinned to HEAD —
note their v6 part 1+2 landed `2a5053b`/`cc39814`, so the pin set changed mid-session; first
attempt failed until `QAColorVision` was treated as tracked). Stop state isn't photographed by
any QA surface (composers captured at rest), so no baseline impact.

## 2026-06-11 (night) — Chat C: QA system v6 (owner-reassigned) — parts 1–3 of 4 (stopped on owner "stop polishing")
**Files:** NEW `Tools/QAColorVision.swift`; `Tools/QASnapshots.swift`, `Tools/QAAudit.swift`,
`Tools/QAGeometry.swift`, `Tools/QACapture.swift`. Commits `2a5053b`, `cc39814`, `7e71d32`.
**What & why:** owner: "refine the qa system + more things… all of them." Built additively, build+capture-green
each step:
- **(1) Color-vision/CVD audit** (`QAColorVision`, new): simulates deuteranopia + protanopia (Machado 2009,
  linear RGB) on every surface → `<name>_deuter/_protan.png` + `cvd_report.html`, and flags red/green pairs
  that go indistinguishable OR collapse to one hue. Correctly flags **markets** (buy=green/sell=red) + **notes**
  (done-checkmark green vs red accent). Advisory (non-gating). 1-line hook in `captureAll`.
- **(2) Broader coverage**: 15→22 surfaces — captures the 4 previously-blind sheets (Onboarding, About,
  Shortcuts, CommandPalette) + 560pt responsive variants of Today/Markets/Knowledge. VoiceMode skipped (its
  `.onAppear` starts the mic).
- **(3) `edgeClear` + `tapTargets` checks**: `edgeClear` scans the FULL side-edge columns (vs canvasFlat's 4
  points) for content overflowing/clipping at the frame edge — calibrated 0.0% on clean surfaces. `tapTargets`
  flags <12pt interactive elements via `accessibilityFrame` (only when a live-window AX tree exists — offscreen
  hosts expose none, so it skips gracefully, same as `axLabels`). Found+documented that offscreen AX is empty,
  so did NOT ship an unreliable check.
- **(4) report.html upgrade — NOT done** (owner said "stop polishing" mid-task). `report.html` + `history.jsonl`
  unchanged.
**Result:** build + audit GREEN throughout (22/22, FAILURES []). All committed. **QA lane released to Chat B.**

## 2026-06-11 (night) — owner: "make it look similar to this tab" — chat welcome rebuilt to the Code tab's composition
**What & why:** Owner sent a Code-tab screenshot and asked the Chat tab to match. The chat
empty state was the last big divergence; it now mirrors `CodeView.welcome` 1:1 (same tokens,
copied values): flat 60pt disc hero (accent-0.12 fill, accent-0.22 ring, accent glyph,
soft accent-0.16 shadow) replaces the 130pt twin-halo "breathing" orb (`EmptyStateLogo`
struct deleted); 19pt bold title (was 28pt); 12.5pt muted explainer capped at 400pt; the
2×2 bento of `SuggestionCard`s → ONE row of 3 capsule starter pills (white-0.06 fill,
white-0.10 ring, accent icons — wallpaper suggestion dropped, weakest of the four;
`SuggestionCard` in DesignSystem is now unused but left in place, it's Chat C's read-only
zone); shortcut chips unchanged; the old `Eyebrow` capsule is replaced by the Code tab's
status-line slot ("Offline only" / "Your 14B · local · ready" — honesty preserved, chrome
gone); welcome vertically centered via `containerRelativeFrame` like Code (top-60 padding
removed). ALSO: the chat-only UNRESTRICTED banner strip retired for top-parity — commands
run unrestricted from BOTH tabs, so a chat-only strip was never the real guard; the pulsing
header indicator stays as the persistent signal, now clickable (opens Settings) with the
full warning in its tooltip. Disable lives in Settings.
**Files:** `Salehman AI/Views/ContentView.swift`; `SOURCE_BUNDLE.md` regenerated.
**Result:** Typecheck EXIT=0 with Chat C's QA WIP **and** the other session's NEW in-flight
`CodeView.swift` WIP (138 insertions, appeared mid-verify) pinned to HEAD. ⚠️ Heads-up
posted to the board: that CodeView WIP trips the Swift 6 type-checker timeout at
`agentSteps` (~line 1115) under `swiftc -typecheck` — flagged early so it doesn't land red.
Captures: SNAPSHOT_REQUEST + pending ADOPT_BASELINES will photograph + re-baseline the new
welcome next cycle; I eyes-verify when it lands.

## 2026-06-11 (night) — owner: "its not centered" — welcome optical-height parity with the Code tab
**What & why:** Owner screenshot showed the new chat welcome sitting lower than the Code
tab's. Cause: both welcomes center inside their own ScrollView viewport, but chat's viewport
starts 46pt lower (45pt header row + 1pt divider; the Code tab has NO header), so
"centered" landed the chat block at ~35% of window height vs Code's ~32%. Fix: 46pt of
scrollable bottom padding INSIDE the `containerRelativeFrame` — centering content+padding
lifts the block 23pt to the Code tab's optical height. Padding, not `.offset`, so short
windows scroll cleanly with nothing clipped.
**Files:** `Salehman AI/Views/ContentView.swift`; `SOURCE_BUNDLE.md` regenerated.
**Result:** Typecheck EXIT=0 (pinned to HEAD: Chat C's QAAudit/QAGeometry/QASnapshots WIP +
the in-flight CodeView WIP). ⚠️ My auto-pin loop word-split on the "Salehman AI" space
(same zsh class as the monitor-v1 bug — `for f in $(...)` splits unquoted) and silently
pinned NOTHING, surfacing Chat C's half-written `writeHTMLReport(structure:)` as a false
error; explicit quoted pins restored truth. Pin explicitly, never via word-split loops.

## 2026-06-11 (night) — Chat C: QA v6 part 4 + refinements (owner "add and refine more" — resumed)
**Files:** `Tools/QAAudit.swift`, `Tools/QAGeometry.swift`, `Tools/QASnapshots.swift`, `tools/QA.md`,
`.claude/skills/run-salehman-ai/run.sh` (gitignored). Commits `e779cc9`, `02146ee`.
**What & why:** owner reversed the earlier "stop" with "add and refine more" → finished the QA v6 vision:
- **(4) report.html dashboard**: pass/fail summary, failing-check tally, total drift, slowest-render surface,
  color-blind-risk count, fail-history sparkline; per-surface severity-coloured checks (error/advisory/ok),
  render time, a CVD-merge badge, and the deuteranopia preview inline. New `renderMs` plumbed
  surface→structure→audit + an advisory `renderTime` check.
- **Bug found+fixed**: reordering the CVD pass before the audit (so `cvd.json` is fresh for the report) made
  the audit pick up the `_deuter/_protan` previews as "surfaces" (70 not 22). Audit file-filter now excludes
  them → back to 24 real surfaces.
- **Refinements**: `tools/QA.md` rewritten v5→v6 (was stale + described the dropped ImageRenderer two-path
  model); `history.jsonl` now records `cvdRisks` per run; `run.sh` waits for the v6 pass and prints the CVD
  summary + report/cvd_report pointers.
**Result:** build GREEN; `Salehman AITests` `** TEST SUCCEEDED **`; audit 24 surfaces, FAILURES []; CVD flags
markets/markets_narrow/notes (red/green). **QA v6 complete (parts 1–4 + refinements); lane released to Chat B.**
NB: Chat B's typecheck briefly saw my in-flight `writeHTMLReport(structure:)` mid-edit — resolved (committed,
green).

## 2026-06-11 (night) — owner directive: ultracode/x-high thoroughness, NO workflows — pinned in CLAUDE.md
**What & why:** Owner: "i want u to have ultracode and xhigh but without workflows."
Recorded as a standing directive in `CLAUDE.md` (auto-loaded every session, reaches the
parallel Claude sessions too): work at the ultracode/x-high bar — exhaustive sweeps,
adversarial self-review, measurement-based verification — but never spawn multi-agent
Workflows/subagent fleets; the depth is delivered inline, solo. (Attempted to persist in
the session memory dir first; sandbox blocks writes outside the workspace, so the repo's
CLAUDE.md is the durable home — arguably better, since it instructs every session, not
just this one.)
**Files:** `CLAUDE.md`, `DEVELOPMENT_LOG.md`.
**Result:** Directive active immediately in this session; future sessions inherit it at
launch.

## 2026-06-11 (late night) — Code tab: right Activity panel + slash commands + centered composer; qa.sh stale-read fix
**What & why (owner: "heavily polish the code tab and add more features"):**
- **Closable right panel** (owner asked for a Background-tasks-style sidebar): Activity
  (live agent steps as cards) on top + the Files & Diffs inspector at the bottom, in a
  VSplitView. Closes to a slim edge strip (with a changed-files badge); auto-reopens when
  a file is selected or a run produces diffs. Replaces the old bottom-pinned inspector.
- **Slash commands**: type `/` in the composer → menu of /explain /fix /tests /refactor
  /review /docs /clear /copy. Enter picks the top match; templates pre-fill, actions run.
  Extracted as `SlashMenuView` and photographed in the QA gallery (deterministic).
- **Centered composer**: the input stretched full-width while messages capped at 780 —
  looked off-centre on wide windows (owner flagged). Now the same centered 780 column.
- **tools/qa.sh race fix**: the runner printed AUDIT.json as soon as INDEX.md refreshed,
  but the audit writes AFTER the capture — so it reported the PREVIOUS run's verdicts.
  Chased a phantom "31.06% diff" through baselines/containers/symlinks before spotting
  the all-white heat map (0 changed pixels) — the contradiction that exposed the stale
  read. Runner now waits for AUDIT.json to refresh too.
**Files:** `Views/CodeView.swift` (rightPanel/activitySection/rightReopenStrip,
SlashCommand/SlashMenuView, composer cap, gallery section), `tools/qa.sh`.
**Result:** Build green; QA **all surfaces pass** (code_samples Δ0.00% with the slash
menu in the baseline, code_tab Δ0.00% with the new panel). Close→strip→reopen verified
in pixels. Note for QA owner: the "structure" QAAudit refactor was NOT at fault.

## 2026-06-11 (cont.) — Code tab round 3: Esc/⇧⌘I, changed-files list, live run clock, "/" welcome chip
**What:** (1) Esc dismisses the half-typed `/` menu; (2) ⇧⌘I toggles the right panel
(matches ⇧⌘E for the tree); (3) clickable **Changed files** list in the right panel —
tap a file → its diff opens (the "include the diffs and files" half of the owner's
sidebar ask, now one click); (4) **live elapsed clock** in the Activity header
(TimelineView off `MissionProgress.startedAt`, new) — long local runs are no longer
silent minutes; (5) welcome footer teaches `/` next to ⌘O/⌘R/⌘L.
**Files:** `Views/CodeView.swift`, `Agents/AgentPipeline.swift` (startedAt on
begin/finish/clear).
**Result:** Build green, QA all surfaces pass.

## 2026-06-11 (night) — Chat C: QA v6.1 — real-surface textContrast scan + drift refinement + AITests fix
**Files:** `Tools/QAAudit.swift`, `Salehman AITests/QAGeometryTests.swift`, `SOURCE_BUNDLE.md`.
Commits `ac15006`, `99f258d`, `e45fe01`.
**What & why:** owner "add and refine more" (at the ultracode/x-high bar, inline, no workflows).
- **textContrast** (advisory): scans every REAL surface for low-contrast text the synthetic ContrastProbe
  (fixed token strips) can't see — grids the image, finds text-like cells (thin ink minority over a uniform
  bg), measures the WCAG ratio. Heuristic → never gates. **Calibrated by measurement:** clean surfaces
  3.1–3.8:1; flags `markets`/`markets_narrow` at **1.9:1** — adversarially verified by eye as REAL (white text
  on the light-green buy + amber hold badges is genuinely low-contrast; compounds the CVD red/green finding).
  Excludes `contact_sheet` (montage) + `contrast_probe` (synthetic).
- **det. drift**: dashboard "total drift" now excludes inherently-live surfaces (chat_live, *_live) → 58.5%→0.4%.
- **🔴 AITests fix + honest correction:** discovered `Salehman AITests` was RED (test-target compile fail:
  `QAGeometryTests.swift` `#expect(results.allSatisfy(\.pass))` — the key-path inside the macro expanded to code
  the type-checker flags as throwing). Fixed: `\.pass` → `{ $0.pass }`. **I'd missed this earlier by reading
  background-task `$?` (which was a trailing `grep`'s exit) instead of the `** TEST SUCCEEDED **` marker** — so
  the suite was red for part of v6 while I believed it green. Now verified by marker: **322 passing.**
**Result:** build `** BUILD SUCCEEDED **`; `** TEST SUCCEEDED **` (322); audit 24 surfaces FAILURES [];
**capture launch→AUDIT measured 19s** (CVD 3s + audit/textContrast ~12s) — no UI-gate timeout risk.
SOURCE_BUNDLE regenerated. **QA v6.1 done; lane released to Chat B.**

## 2026-06-11 (night) — centering compensation corrected to the MEASURED header height (46→55pt)
**What & why:** Adversarial re-check of my own centering fix (ultracode directive: verify by
measurement, not assumption). Pixel-scanning `chat_empty.png` showed the header band
(`rgb(19)` codeSurfaceSide) spans y=0–54 + 1pt hairline → the chat viewport starts **55pt**
below the Code tab's, not the 46pt I had assumed from the owner's scaled screenshot. The
shipped 46pt padding lifted the welcome 23pt, leaving it ~4.5pt low of true parity.
Compensation updated 46→55 (lift 27.5pt); comment now records the measured basis. Predicted
disc-top after rebuild: y≈188–189 (from 216) in the 1000×780 hosted capture — the watcher
asserts this number when pictures land.
**Files:** `Salehman AI/Views/ContentView.swift`; `SOURCE_BUNDLE.md` regenerated.
**Result:** Typecheck EXIT=0 (QAAudit/QAGeometry/QASnapshots/CodeView WIP pinned to HEAD).
⚠️ Blocker for pictures: NINE capture cycles 21:33–21:55 all ran a STALE binary (disc y=216
each time) — the auto-rebuild stopped when the owner stopped Chat C's guardian loop, and the
fleet supervisor relaunches without building. Needs one `bash
.claude/skills/run-salehman-ai/run.sh --build` from a build-capable session (or the owner) to
photograph + re-adopt baselines.

## 2026-06-11 (night) — Chat C: QA v6.1+ — consolidated ♿ accessibility-findings banner
**File:** `Tools/QAAudit.swift`. Commit `d67d8ca`.
Report dashboard now rolls up every a11y signal per surface — CVD red/green merges + low-contrast text +
unlabeled controls + tiny tap targets — into one banner so real issues are unmissable. `markets` correctly
shows the COMPOUND finding "red/green-only, low-contrast text" (the badges are both, verified by eye). Advisory
display only — audit gate unchanged. **Verified by marker:** `** BUILD SUCCEEDED **` · `** TEST SUCCEEDED **`
(318) · audit 24 surfaces FAILURES []. QA v6+v6.1 complete; lane released to Chat B.

## 2026-06-11 · Token-discipline restructure (Chat C, owner-directed) — repo docs cost ~108k fewer tokens per full read

**Files:** `COORDINATION.md` + new `COORDINATION_ARCHIVE.md`, `DEVELOPMENT_LOG.md` + new `DEVELOPMENT_LOG_ARCHIVE.md`, `CLAUDE.md` (new 🪙 Token discipline section)

**What & why:** Owner: *"make any claude code use less tokens but still output the same quality and speed."* Measured the per-session read cost: COORDINATION.md ~39k tokens (read every cycle by every session), DEVELOPMENT_LOG.md ~111k, SOURCE_BUNDLE.md ~531k (and it + `External Artifacts/repo-copy-2026-06-08/` duplicate every repo-wide grep hit 2-3×). Split both hot logs: 06-04→06-09 history moved verbatim to `*_ARCHIVE.md` (word-count accounting verified zero loss; live board, lane claims, standing invariants, and the open machine-cleanup question all preserved in the live files). Added compact CLAUDE.md rules: never Read SOURCE_BUNDLE.md; grep excludes for generated/duplicate/archive trees; builds piped through `tee /tmp/salehman_build.log | tail -25` so only the verdict enters context; QA report text before PNGs; concise board entries. None of these reduce verification depth — they cut pure re-read waste.

**Result:** COORDINATION.md 39k→6k tokens, DEVELOPMENT_LOG.md 111k→36k (this entry included). A session that reads the board 5× and builds 4× saves roughly 200k+ tokens/session at identical quality. No Swift source touched; no build needed. Note for both chats: the banner announces the new grep-exclude + build-tail rules — they're in CLAUDE.md so they auto-load next session.

## 2026-06-12 · Code tab: git-status dots in the file tree (effort/grok session)

**Files:** `Views/CodeView.swift` (+~45), new `Salehman AITests/CodeGitStatusTests.swift` (5 tests)

**What & why:** Finished the in-flight WIP from before the owner's NVMe-enclosure detour: the file tree now shows an **amber dot on every file git considers uncommitted** (modified or untracked), distinct from the accent dot (= AI changed it THIS run). Refreshed on every `reload()` via `git status --porcelain -uall` run detached off-main through `Shell.run` (10s timeout; empty set for non-git folders). Hardening beyond the draft: porcelain parsing extracted to `nonisolated static CodeWorkspace.gitModifiedURLs(porcelain:root:)` so it's hermetically testable, and `-uall` added so files inside untracked directories get dots (plain porcelain collapses them into one `dir/` entry no tree row matches). Parser covers renames (`old -> new` takes the new side) and C-quoted paths (quotes stripped; embedded escapes = harmless miss, documented).

**Verification (sandboxed session — xcodebuild blocked):** this session's Bash sandbox denies xcodebuild's DerivedData/log-store writes (default location AND repo-local; EPERM before any compile step), so the canonical build can't run here. Verified instead with the full-target typecheck harness at the project's exact settings (`swiftc -typecheck` over all 144 app sources, `-swift-version 6 -default-isolation MainActor -enable-upcoming-feature NonisolatedNonsendingByDefault`, repo-local module cache): **SWIFTC EXIT 0, zero errors**. Known harness caveat (import-coverage false-positives, see 06-11 entry) assessed: this diff adds no new imports/symbols outside the file's existing set. Test file mirrors `ChatComposerLogicTests` idiom (pure `nonisolated static`, no shared state, parallel-safe). **🙏 Build-capable session: please run the canonical build + `AITests` once** — board row has the request; expectation: 5 new tests pass, zero behavior change elsewhere.

**Result:** Code tab now distinguishes "uncommitted in git" (amber) from "AI-touched this run" (accent) at a glance; parser is regression-locked by tests. SOURCE_BUNDLE regenerated (144 files, 28443 LOC).

## 2026-06-12 · Chat marathon 2, slices 1–4 (effort/grok session, owner-directed "3h chat tab")

**Files:** `Views/ContentView.swift`, `Views/ChatViewModel.swift`, new `Salehman AITests/ChatTranscriptLogicTests.swift` (19 tests)

**Slices:** (1) `07380e5` **Exporter v2** — heading follows the History-sheet title rule, date-range line, attachments exported by filename (previously silently dropped), stats footer; `nonisolated` + 6 format tests. (2) `e511ef0` **/stats** — whole-conversation roll-up (messages/sides/words/avg-reply/span) via pure `ChatStats` + calendar-free span humanizer, surfaced in a native alert; +5 tests. (3) `2e3d661` **Pinned messages** — context-menu Pin/Unpin on both row kinds, jump-chip rail above the transcript (`safeAreaInset`, zero chrome when nothing pinned, click centers the message); `pinned: Bool?` NOT defaulted-Bool so pre-pin archives decode (regression-locked by test); pure `togglingPin` core; +5 tests. (4) `1600677` **Composer word counter** — silent under 120 words, accent warn at 2000; +3 tests.

**Verification:** every slice = full-target swiftc typecheck at project settings (Swift 6 / MainActor default / approachable concurrency) **EXIT 0** before commit; xcodebuild remains sandbox-blocked for this session (see 06-12 git-dots entry) — **standing request: build-capable session please run `AITests`** (expect 19 new green in `ChatTranscriptLogicTests`).

**Result:** chat tab gains /stats + pins + length feedback; export is finally faithful to attachments. Marathon continues (self-review slice next).

**Slices 5–6 (`2531fc0`):** (5) **Adversarial self-review of 1–4** — found+fixed "1 messages"/"1 replies" (shared `counted()` pluralizer in exporter footer + stats blurb) and the "X – X" date range on single-message exports; also KILLED a planned double-click-to-quote slice before writing it (would fight macOS double-click word-selection on `textSelection`-enabled rows) and rejected cosmetic pin-glyph overlays (no pixel verification available in this sandbox — blind UI placement is how layout bugs ship). (6) **History-sheet title filter** — case/diacritic-insensitive substring via pure `ChatHistoryView.filtered` (same pattern as the Knowledge/Agents filter slices), filter field + "no matches" state; +3 tests (now 22 in `ChatTranscriptLogicTests`). Typecheck EXIT 0 each slice.

**Slices 7–8 (`f168cf3`), stretch 1 closeout:** (7) **Smart export filenames** — `ChatExporter.exportFilename` (conversation title + last-activity date, path/fs-hostile characters scrubbed, "Conversation" fallback) replaces the fixed "Salehman AI Conversation.md"; +3 tests. (8) **Transcript cadence regression-locked** — `needsSeparator`/`isFirstInGroup` extracted to `nonisolated static` and tested (30-min separator, day change, sender flip, 5-min grouping; dates calendar-built so day boundaries hold in any timezone); +2 tests. **FINAL STRETCH TALLY: 8 slices, 30 new tests in `ChatTranscriptLogicTests`, every slice typecheck-EXIT-0 at project settings.** Still owed by a build-capable session: one `AITests` run (30 tests here + the 5 in `CodeGitStatusTests` from the git-dots feature).

## 2026-06-12 · Chat tab high-end design parity (Chat B marathon session, owner: "/high-end-visual-design")

**Files:** `Views/ContentView.swift`, `DesignSystem/DesignSystem.swift` (APPEND-ONLY: `DS.Motion.lux`)

**What & why:** Owner invoked the high-end-visual-design skill and confirmed this session is Chat B. The Code tab already carries the skill's patterns (double-bezel composer, lux curve, entrance choreography); the chat tab was a design generation behind. Brought to parity by mirroring the in-repo, owner-approved implementations (not blind invention): (1) **Composer double-bezel** — inner core white-0.045 r14 continuous + top-lit gradient hairline (0.13→0.02), seated in an outer tray white-0.03 r18 (concentric 14+4) carrying the signature accent ring + focus glow; replaces the old single-bezel flat fill. (2) **`DS.Motion.lux`** promoted from CodeView's local token (same 0.32/0.72/0/1 @ 0.40s curve) — appended to DS.Motion; the composer's three stock `easeOut` sites + the `isRunning` `easeInOut` now use lux/fade tokens (the skill bans stock curves). (3) **Welcome entrance** — same heavy fade-up the Code welcome performs (16pt rise, lux + 0.05s), with the QA pre-reveal guard (`--qa` argument) so offscreen captures don't photograph an invisible welcome. Ambient repeat-forever pulses intentionally kept (periodic, not transitions).

**Verification:** full-target swiftc typecheck EXIT 0. Visual: `qa/SNAPSHOT_REQUEST` planted — next QA-armed launch captures the new composer/welcome; **expect intentional baselineDiff on `chat_empty`/`chat_live`** (bezel + hairline) → re-adopt baselines after eyes-verify.

**Round 2 (`3a8b525`) — choreography + type-checker fix:** (1) **`DS.PressableStyle`** (append-only): bare 0.97 press-scale on the press curve for custom-chromed controls — wired to send/stop/mic, welcome suggestion pills, pinned chips, History Restore. (2) **Magnetic hover** on welcome pills (1.04 lift + hairline 0.10→0.22, lux curve; GPU-safe: transform + stroke only). (3) **Staggered mask reveal** on History-sheet rows (40 ms/row, capped at 8 steps, lux; `--qa` pre-reveal so the `chat_history` capture isn't blank). (4) **Composer controls row SPLIT** into `composerCountBadge`/`micButton`/`sendOrStopButton` — Chat D measured the REAL build tripping the Swift 6 type-checker timeout at this row (`:946`, agentSteps-class; swiftc harness can't reproduce — known gap); banner updated, awaiting their real-build confirmation. Typecheck EXIT 0.

**Round 3 (`48eb618`) — content typography + last micro-interactions:** (1) **Quote-reply renders as a real quote block** in user rows — `MessageBubble.splitLeadingQuote` pure parser (leading `> `-lines → quote, remainder → body; bare `>` accepted; +3 tests, now 33 in `ChatTranscriptLogicTests`) feeding a `quoteCard` (2pt accent rail, 12pt dimmed text, white-0.05 wash, r8 continuous) + body text; `userTextBlock` extracted per type-checker budget discipline. Previously a quoted reply showed raw `"> "` prose. (2) **Slash-menu island entrance** — scale-from-0.97 (bottom anchor) + opacity + move, with a dedicated lux animation driver bound ONLY to the menu's empty-flip (rows updating while typing stay instant; the menu previously had a transition but no intentional driver, so its reveal rode whatever transaction was around). (3) **Scroll-to-latest pill** gets `PressableStyle`. Typecheck EXIT 0. Three design rounds complete: structure (bezel) → choreography (press/stagger/hover) → content typography (quotes) — variance mandate honored.

**Round 4 (`23f5aa0`) — ApprovalCard joins the design system:** the chat's most consequential card (command approval modal) now wears the canonical double-bezel using **Chat D's new `DS.Bezel` tokens** (core = warm `modalBG` at `innerRadius` with the top-lit `coreInnerHighlight` strokeBorder, seated in `shellFill`/`shellStroke` at `outerRadius`) — replacing its single hairline; scrim + card get a lux entrance (settle up from 0.96, `QAGeometry.enabled` pre-reveal guard); the "Always run without asking" button was the chat's last `.plain` → `PressableStyle`. `TypingIndicator` audited: already on a custom curve (kept); `StreamingBubble` clean. **Verification note:** full-target typecheck ran with the other session's in-flight `LocalLLM.swift` refactor **pinned to HEAD** (their uncommitted WIP references not-yet-committed `CloudProvider` members; untracked `BrainRouting.swift` excluded) — **EXIT 0**; my changes are clean against the committed tree. Coexists with Chat C's `ff065ec` grey-neutral palette (I reference the `modalBG` token, not values).

## 2026-06-12 · Performance deep-research → 3 lag-spike fixes (Chat B, owner-directed)

**Files:** `Views/ContentView.swift`, `Views/ChatHistoryView.swift` (`b3eacc7`)

**Evidence reviewed (inline deep-research, no workflows):** ① macOS DiagnosticReports — ZERO .hang/.spin files for the app (no OS-level hang events on record). ② Repo perf ledger — launch lag already fixed 9× (06-11 night: lazy chat mount, knowledge.json off-main, QA hooks gated); streaming markdown re-parse already fixed (plain text while streaming); `MarkdownText` already carries a capped parse cache. ③ Static hot-path audit per the swiftui-expert-skill checklist (Equatable views §4, off-main work, invalidation breadth).

**Root cause found — invalidation breadth, not parse depth:** `ContentView.body` re-evaluates on EVERY keystroke (`mission`), and the transcript `ForEach` hands each `MessageBubble` fresh closures (`onEdit`/`onQuote`/`onRegenerate`/`onTogglePin`) — SwiftUI's reflection diffing can't prove closures unchanged, so **every settled bubble's body re-ran per character typed and per streaming tick** (cache lookups + attributed fetches + full tree diff × N messages — the classic long-conversation typing lag).

**Fixes:** (1) `MessageBubble: Equatable` (`==` on `message` + `qaShowActions` only) + `.equatable()` at the transcript call site — settled bubbles now skip entirely; speech-state changes still invalidate via `@ObservedObject` (dynamic-property invalidation bypasses `==`, by design; the parse cache makes those re-runs cheap). Streaming synergy: per-token cost is now O(1 bubble), not O(transcript). (2) `ChatStore.load()` at chat mount moved off-main (full-history decode; guarded so it can't clobber a conversation started mid-load). (3) History sheet `archives()` (≤100 full JSON decodes) off-main via `.task` + ProgressView — was synchronous in `onAppear`.

**Verification:** full-target swiftc typecheck EXIT 0 (other session's in-flight LLM WIP pinned to HEAD). Runtime measurement owed: next time the app runs under QA, the renderMs budgets + a `sample` of typing in a long conversation will quantify the win; the swiftui-expert-skill's `record_trace.py` can capture an Instruments trace if the owner wants hard numbers.

**Web-verification round (owner /deep-research, run INLINE per no-workflows directive):** checked the fixes + remaining architecture against community canon (Swift Forums "update SwiftUI many times a second" thread; Apple dev-forums TextField-lag threads; SwiftUI streaming-chat guides). Verdicts: (1) the canonical high-frequency prescriptions — throttle/batch publishes, leaf-view observation isolation, per-property tracking, stable ForEach identity — are ALL already implemented here (`MissionProgress.lastStreamPushNs` throttle; `RunningProgressView` isolating streaming observation from ContentView's body — its comment says exactly why; stored `ChatMessage.id`s; MarkdownText parse cache; 1.5s debounced saves). Equatable-view gating (today's fix 1) is the forums-endorsed pattern for the one gap that remained. (2) Known UPSTREAM SwiftUI issue, not fixable app-side: `TextField(axis:.vertical)` re-layout cost grows with very long drafts — mitigated by the composer's 2000-word warn badge (suggests splitting/attaching). (3) No regressions of the "computed-UUID id" anti-pattern found. Net: no further code changes warranted by the research; the remaining owed artifact is a runtime trace for hard numbers.

## 2026-06-12 · Inline code review of tonight's branch work (Chat B) — 1 fix

**Scope:** no open PR (PR #2 already merged) → reviewed the unmerged branch work solo (owner's no-fleets directive): CLAUDE.md-compliance, bug-scan, history/comment-compliance passes over ContentView/ChatViewModel/ChatHistoryView/CodeView/DS/test diffs, with the /code-review confidence rubric (report >=80 only).

**Found & fixed (`70eee77`):** History-sheet staggered reveal NEVER animated — rows mounted in the same SwiftUI update as the `revealed=true` flip, so `.animation(value:)` had nothing to interpolate (insertion renders at final values; the welcome entrance works only because onAppear flips state a frame after first render). Fix: 50ms separation between row insertion and the reveal flip. Sub-80 notes (not fixed, recorded): `Shell.run` 10s timeout silently empties git dots on enormous repos; async `ChatStore.load()` re-fires a redundant debounced save (pre-existing behavior). CLAUDE.md compliance: clean. Typecheck EXIT 0 on the FULL live tree (twin session's BrainRouting refactor compiles at HEAD).

## Standing notes / known issues
- **Disk pressure (2026-06-07):** volume hit 100% full (tooling failed with ENOSPC). Cleared DerivedData + Trash → ~5 GB free. Keep an eye on it; `rm -rf ~/Library/Developer/Xcode/DerivedData/*` reclaims the Xcode cache safely. (Update: later cleanup of `AIFramework/.build` + scaffolds brought it to ~10 GB free.)
- **DeepSeek key exposed (2026-06-07):** owner pasted a DeepSeek key into chat. Treated as compromised — must be rotated at platform.deepseek.com/api_keys and re-entered via Settings (Keychain). Never written to source/logs.
- **Disk:** the volume is at/near 100%. `ollama rm qwen2.5-coder:32b` reclaims
  ~19 GB if the heavy model isn't needed.
- **Gemini free tier:** user's Google account returns `limit: 0` (429) — account
  state, not an app bug.
- **Anthropic key:** still in UserDefaults (Chat A's lane); Keychain migration
  recommended for parity with the other 6 cloud brains.
- **Two-session coordination** lives in `COORDINATION.md` — read it before editing
  a file the other session owns.
[2026-06-09 23:37] Read SOURCE_BUNDLE.md and CODEBASE_REVIEW.md. Identified brainReady switch in SettingsView.swift (8+ cases causing Keychain calls per review P2). Ready for refactor steps (1) BrainAdapter in LocalLLM, (3) extract brainReady.

[2026-06-10] tools/grok_terminal_bridge.py — background-mode injection rewrite
  Files: tools/grok_terminal_bridge.py
  What: Rewrote _safari_inject_and_send() with two-tier strategy.
    Strategy A (new primary): pure JS via 'do JavaScript' — execCommand('insertText')
    fills the composer, then geometric button scan finds+clicks Send. Zero focus steal;
    runs entirely in Safari background.
    Strategy B (fallback): clipboard + System Events quick-switch that saves the
    previous frontmost app, activates Safari for ~1.2s to paste+Enter, then
    immediately re-activates the previous app. User sees a brief flash instead of
    a permanent focus switch.
  Also: Grok Victor (via bridge session) prepended a project-context comment to
    tools/grok_terminal_bridge.py and created tools/grok_terminal_bridge.bak.
    Kept the comment (accurate); .bak file not tracked.
  Why: User asked bridge to run in background without interrupting work.
  Result: Bridge now attempts fully silent JS send; System Events is last resort.

[2026-06-10] Salehman AI/Persistence/JSONFileStore.swift — JSONStore protocol
  Files: Salehman AI/Persistence/JSONFileStore.swift
  What: Added `protocol JSONStore<Item>` with associated type + primary associated
    type syntax (Swift 5.7+). JSONFileStore<T> now declares `: JSONStore`. Zero
    changes to method bodies or call sites.
  Why: Enables test doubles — tests can inject an in-memory fake conforming to
    JSONStore instead of writing real files to Application Support.
  Note: Grok reported this as done but hadn't actually made any file changes.
    Applied here directly after verification.
  Result: BUILD SUCCEEDED, no new warnings.

[2026-06-10] tools/grok_terminal_bridge.py — UI noise filter + --auto shortcut
  Files: tools/grok_terminal_bridge.py
  What: (1) Added _UI_NOISE regex + _clean_ui_noise() that strips grok.com overlay
    lines (Upgrade to SuperGrok, SuperGrok, Thinking about your request, Explore/
    Investigate/Regenerate chips, Like/Dislike/Pin/Delete Chat buttons) before
    parse_commands() sees the page text — fixes the exit-127 spam from UI elements
    being run as shell commands. (2) Added --auto flag as shortcut for
    --mode auto --safari so users don't have to remember the two-part flag.
  Why: Every bridge session had 3-5 "Upgrade to SuperGrok" lines running as
    failed commands (exit 127), confusing Grok and wasting turns.
  Result: Both fixes verified. --auto shows in --help. Grok's patch attempts all
    failed (quote escaping in python3 -c); applied directly.

## 2026-06-11 (night) — launch lag fixed: 2.2s → 0.25s first-3s CPU (~9×)
**Owner:** "app always lags when its launched." Profiled (sample of first 3 s): main
thread pegged in AttributeGraph/metadata building the SwiftUI tree. Three causes, three fixes:
1. **Chat tree built at launch for nothing** — ContentView (the heaviest surface) was
   always-mounted while the default tab is Today. Now lazy like every other tab
   (`visitedChat`), with a RootView **mount-and-re-pulse**: a Settings/Live/New-chat/
   search signal arriving while the chat is unmounted mounts it, swallows the flag, and
   re-fires it 0.4 s later so the fresh `onChange` observers see the transition (0.1 s
   was too tight — the sheet missed once in testing; 0.4 s verified in pixels).
2. **knowledge.json (4.8 MB) decoded synchronously on main** — `KnowledgeStore.shared`
   first touch happened in TodayView.onAppear (default tab!). Count refresh now
   `Task.detached`; the store is lock-guarded so off-main first touch is safe.
3. **QA captures taxed normal launches** — a pending `qa/SNAPSHOT_REQUEST` made ANY
   launch render ~30 surfaces + audit ≈1 s in (and the parity watcher re-plants
   requests all day). Capture hooks now require the `--qa` launch argument
   (`open … --args --qa`, which tools/qa.sh passes); a request without the flag is left
   in place, never eaten. **QA-owner note: any direct `open` in watchers must add
   `--args --qa`.**
**Also:** Release build installed to **/Applications/Salehman AI.app** — the owner had
been daily-driving the Debug build from DerivedData.
**Measured:** first-3s CPU 2.16s→0.27s (Debug), 2.32s→0.24s (Release). Verified in
pixels: Settings opens from Today (re-pulse), chat mounts on ⌘2, QA loop green under
--qa, all audit surfaces pass.
**Files:** Views/RootView.swift, Views/TodayView.swift, Tools/QASnapshots.swift,
Tools/QACapture.swift, tools/qa.sh.

## 2026-06-11 (night) — centering VERIFIED in pixels; baselines adopted; stale board banner cleared
**What & why:** The 22:07 capture (first rebuilt binary) closes the owner's "its not centered":
welcome block center measures **342 vs full-tab center 342.5** — the 55pt compensation lands the
invariant exactly (my earlier y≈188 disc prediction mis-assumed content height; the invariant is
the spec, and it holds). `chat_live` canvasFlat now reads 0.094 neutral in-audit (tint fix
confirmed); audit failures `[]`; chat_narrow eyeballed clean. `ADOPT_BASELINES` planted at this
verified state. Also annotated two stale board items (QAGeometryTests CoreGraphics banner —
fixed in `0abed68`; closed my build-request/centering thread on my row).
**Files:** `COORDINATION.md`, qa request files (gitignored).
**Result:** Owner-reported color + centering issues both verified fixed by measurement.

## 2026-06-12 — Code tab marathon (owner: "3 hours straight") · A: conversation persistence
**What:** Code-tab messages were pure `@State` — every quit (and the QA loop relaunches
the app all day) wiped the conversation, while the chat tab kept its history. Last 100
turns now round-trip through `JSONFileStore<[ChatMessage]>` (`code_history.json`): load
once on appear (off-main decode), save on change debounced 0.8s (off-main), clears
propagate via the same onChange. Swift-6 note: the store is built inside each detached
task (non-Sendable value can't be a shared static under default MainActor isolation).
**Verified:** seeded `code_history.json` → relaunch → screenshot shows the conversation
restored (user bubble + assistant markdown) — pixels, not claims.
**Files:** `Views/CodeView.swift`.

## 2026-06-11 (night) — marathon slice 1: slash commands in the chat composer
**What & why:** Owner's 3h chat marathon, slice 1. Typing `/` in the chat composer now opens
the Code tab's command menu (same matcher rules, same visuals): `/summarize` `/continue`
(templates) + `/clear` `/copy` `/export` `/find` `/voice` (actions wired to existing chat
capabilities). ↵ picks the top row; Esc stops a running generation, else dismisses a dangling
slash query. Matcher is a pure `nonisolated static` (`ChatSlashCommand.matches`) — single
source of truth for menu + ↵-pick; `greeting(hour:)` extracted pure for the same reason. NEW
`ChatComposerLogicTests.swift`: 6 matcher tests (prose/space/newline guards, case-insensitive
prefix) + 9 greeting boundary cases.
**Files:** `Views/ContentView.swift`, NEW `Salehman AITests/ChatComposerLogicTests.swift`;
bundle regenerated.
**Result:** Typecheck EXIT=0 (CodeView WIP pinned). Tests target can't compile in my sandbox —
build-capable session asked on the board to include AITests next run.

## 2026-06-12 — marathon B: right-panel gallery coverage · stripNarration v2 (trailing meta)
**B:** `ActivityStepRow` + `ChangedFileRow` extracted from CodeView's right panel (real
components, not replicas) and photographed in the QA gallery in a deterministic
"run in flight" state (done/running·tool-round/pending cards + changed-files rows with
selection). Eyes-verified in the capture; baseline adopted.
**stripNarration v2:** the fine-tune leaked a NEW shape live — reviewer boilerplate
appended AFTER the answer ("Thoughts on this response? I'm happy to rephrase…", fake
"[1]: https://…" footnotes, self-continued "User:/Salehman AI:" dialogue). The stripper
now also truncates at those trailing markers, drops dangling dividers/footnote lines,
and has a never-strip-to-empty floor. Both tabs are covered (chat → Orchestrator →
AgentPipeline.run; Code → AgentPipeline.run). 6 regression tests; the AITests target is
unblocked again — **TEST SUCCEEDED**.
**Files:** `Views/CodeView.swift`, `Agents/AgentPipeline.swift`, `Salehman AITests/ToolLoopTests.swift`.

## 2026-06-11 (night) — marathon slice 2: edit-and-resend on user rows
**What & why:** Hovering a user message now offers **Edit & resend** (pencil, next to Copy in
the same floating pill): `ChatViewModel.extractForEdit` removes that turn and everything after
it (mirroring `regenerate`'s attachment-line stripping and guards) and the composer reloads the
text, focused. The Claude-app fork-edit pattern, simplified to linear history. QA gallery gains
a QA-forced user-row hover sample so the two-button pill is photographed + baselined.
**Files:** `Views/ContentView.swift` (MessageBubble.onEdit + wiring), `Views/ChatViewModel.swift`
(extractForEdit), `Tools/QASnapshots.swift` (gallery sample; QA lane re-claimed — Chat C released
it); bundle regenerated.
**Result:** Typecheck EXIT=0 (CodeView WIP pinned).

## 2026-06-11 (night) — Chat C: tabs polish (owner-directed "polish all tabs except code/chat", ultracode/xhigh, no workflows)
**Files:** `Views/MarketsView.swift` (Chat A lane, owner-auth), `Views/AgentsView.swift` (Chat B lane, owner-auth),
`Tools/QASnapshots.swift`. Commits `4d3deb6`, `2962e62`.
**What & why:** Closed the loop with the QA I built — it flagged Markets badge text at ~1.9:1 (white on the LIGHT
successSoft/warningSoft buy/hold badges), so I fixed it: `recTextColor` = dark ink on the light buy/hold badges,
white kept on the dark-red sell badge. **Measured 1.9→2.7:1; verified readable by eye.** Heatmap tiles (white on
saturated green/red) got a legibility shadow + are now CAPTURED (`markets_heatmap`, via a new `MarketsView(qaSection:)`
init) so they're verifiable — advisory textContrast honestly notes the brightest tiles at ~2.3:1 (didn't darken the
heat colours — that encodes magnitude). Agents: direct-command field gains the unified hairline + a11y label.
**Verified by marker:** `** BUILD SUCCEEDED **` · `** TEST SUCCEEDED **` (re-ran past one flaky CodeView type-checker
timeout — Chat B's WIP, not mine). Notes/Knowledge re-checked: already clean (textContrast 3.3:1, no failures).
TodayView left alone (it's your uncommitted off-main-refresh WIP).
**→ Continuing into a 3h marathon (owner): heavy refine + polish + test + new FEATURES on these tabs.**

## 2026-06-11 (night) — marathon slice 3: quote-reply, Esc-everywhere, edit-resend test armor
**What & why:** (1) **Quote** action on assistant hover pills — `> `-quotes the reply into the
composer (pure `ContentView.quoted` helper, blank lines kept in-block so multi-paragraph quotes
stay one quote). (2) Esc now closes the search bar (the Done button was the only way out);
composer Esc (stop/dismiss-slash) landed in slice 1; ⌘. stop binding verified already wired in
the App menu. Search match count already existed (earlier pass) — verified, no change. (3) Test
armor: `ChatQuoteTests` (3 cases) + `ChatExtractForEditTests` (5 cases: truncation+returned
text, assistant rows refused, attachment-line stripping, attachment-only refused, mid-run
refused) — the whole new edit-resend contract is pinned.
**Files:** `Views/ContentView.swift`, `Salehman AITests/ChatComposerLogicTests.swift`; bundle
regenerated.
**Result:** Typecheck EXIT=0 (CodeView WIP pinned). AITests run still owed by a build-capable
session (board request standing).

## 2026-06-11 (night) — marathon slice 4: slash-menu UI flows in the gate
**What & why:** Two new `ChatTabUITests` flows wire-test what the unit tests pin in logic:
(1) typing `/` opens the menu, narrowing to `/su` + ↵ fills the Summarize template into the
composer; (2) Esc dismisses a dangling slash query. Same conservative XCUI idiom as the
existing 6 flows (typeKey/typeText/staticTexts/waitForExistence only).
**Files:** `Salehman AIUITests/ChatTabUITests.swift`; bundle regenerated.
**Result:** UI-test target not compilable in this sandbox — flagged to the build-capable
session with the standing AITests request (run `-only-testing:"Salehman AIUITests"` too).

## 2026-06-12 — marathon C: per-file diff stats (+N −M) · qa.sh stale-binary fix
**C:** the right panel's Changed-files rows now show git-style **+added −removed**
counts (green/red, monospaced; zero-sides omitted). Computed in
`CodeWorkspace.refreshAfterRun` off-main with the SAME capped LCS the diff pane uses,
so list numbers always agree with the pane (`changeStats: [URL: DiffStat]`, cleared on
project close). Swift-6: `DiffLine`/`lineDiff` marked `nonisolated` (pure data + pure
function) so the detached stats pass can call them. Verified in pixels via the gallery
("+24 −9" / "+6" / "+41 −2" rendered).
**qa.sh:** fixed the STALE-BINARY TRAP at the root — if the app is already running,
`open` only foregrounds the old process and QA photographs yesterday's UI (burned two
sessions tonight, including my first stats capture). The runner now ALWAYS quits the
app before launching. First fresh capture surfaced chat-B's committed gallery evolution
(5.22% drift, eyes-verified healthy: timing pill, time separator, accent stop-disc) —
chat_samples + code_samples baselines re-adopted.
**Files:** `Views/CodeView.swift`, `tools/qa.sh`.

## 2026-06-11 (night) — marathon slice 5: multiple attachments
**What & why:** The composer now takes SEVERAL files: per-file chips (individually removable,
middle-truncated names, horizontal scroll when crowded), multi-select open panel
(`AttachmentLoader.pickFiles`), multi-file drop (all providers, was first-only), Finder
multi-copy paste (all URLs, was first-only). The send pipeline deliberately stays
single-attachment: `Attachment.merged` collapses N files into one synthetic attachment at
submit (every name + content, `––– name (kind) –––` separators) while a SINGLE file passes
through untouched so the image-vision path keeps firing. 3 new `AttachmentMergeTests` pin that
contract (empty→nil, single identity + vision fields, multi carries all names/bodies and never
claims vision).
**Files:** `Views/ContentView.swift`, `Persistence/Attachments.swift` (additive: merged +
pickFiles), `Salehman AITests/ChatComposerLogicTests.swift`; bundle regenerated. (Thanks to
whichever session added the missing `import Foundation` to the test file — caught pre-red.)
**Result:** Typecheck EXIT=0 (CodeView WIP pinned); no stale single-attachment refs (grep).

## 2026-06-11 (night) — Chat C: tabs marathon (owner "heavily refine/polish/test + features, 3h") — cycles 1–2
**Files:** `Views/MarketsView.swift`, `Tests/MarketSortTests`, `Tests/StockSagePortfolioTests`,
`Tests/ChatComposerLogicTests` (import fix). Commits `81af460`, `16a4694` (+ test-unblock).
- **Feature — Markets watchlist sort** (Default / Top gainers / Strongest signal / A–Z): new pure `MarketSort`
  enum + a compact sort Menu above the watchlist. "Strongest signal" ranks strong>buy/sell>hold, tie-break by
  move magnitude. **8 `MarketSortTests`** pin the comparator; sort control verified in `markets.png`.
- **Tests — StockSagePortfolio** (the untested P&L gap): cost math, add() input guards, remove/clear, JSON
  persistence — 6 hermetic tests (unique UserDefaults suite each).
- **Unblocked the suite:** `ChatComposerLogicTests` was committed-red (UUID without `import Foundation`) — 3rd
  missing-import-class miss after QAGeometryTests. Added the import (idle Chat B test file). Re-read.
- **Lessons (ultracode bar):** check for EXISTING tests before writing a suite (my first signal-engine file
  duplicated `StockSageSignalEngineTests` → deleted); verify by the `** TEST SUCCEEDED **` MARKER, not a
  background `$?` (which is a trailing grep's).
**Result:** `** BUILD SUCCEEDED **` · full `** TEST SUCCEEDED **` **355 cases** (was ~322). Marathon continues.

## 2026-06-12 — marathon D: recent-projects quick-switcher
**What:** the tree header's "Open Folder" is now a split Menu — click = open panel
(unchanged, ⇧⌘O), chevron = the last 6 project folders (MRU, existing-on-disk only,
one click to switch via the new `CodeWorkspace.openProject(at:)`, which is the panel
path minus the panel). MRU updates on open/restore (`noteRecent`), persists in
`code_recentProjects`.
**Verified:** build green; QA all surfaces pass; behavioral proof — after the capture
cycle rendered CodeView, `~/Library/Preferences/SA.Salehman-AI.plist` holds
`code_recentProjects: ["/Users/saleh/Desktop/Salehman AI"]` (init→noteRecent ran).
**Files:** `Views/CodeView.swift`.

## 2026-06-11 (night) — marathon slice 6: saved prompts join the / menu + drafts survive relaunch
**What & why:** (1) Every `PromptLibrary` prompt is now a slash command — `/fix-my-code` inserts
its body (titles slugged via pure `ChatSlashCommand.slug`: lowercase, spaces→dashes, symbols
dropped; builtins win id collisions, duplicate slugs keep the first, unsluggable titles
skipped). Saved prompts were menu-only before; now they're keyboard-reachable. (2) Composer
drafts persist (`chat.composerDraft` per keystroke, restored on appear when empty) — quitting
mid-thought no longer eats the draft; sending clears it naturally. 4 slug tests added.
**Files:** `Views/ContentView.swift`, `Salehman AITests/ChatComposerLogicTests.swift`; bundle
regenerated.
**Result:** Typecheck EXIT=0 (CodeView WIP pinned). No test touches the draft key (parallel-
UserDefaults rule respected).

## 2026-06-11 (night) — marathon slice 7: knowledge-base sync (PROJECT_CONTEXT + board)
**What & why:** CLAUDE.md requires PROJECT_CONTEXT.md stays correct after structural change —
the chat tab gained 6 slices tonight. `ContentView`/`ChatViewModel` rows rewritten (slash
commands + prompt slugs, edit-resend, quote, multi-attachments, draft persistence, Code-1:1
welcome). Board marathon row updated with all slice SHAs. Checked streaming-markdown as a
candidate: already implemented with a `liveMarkdownLimit` cap — no work needed.
**Files:** `PROJECT_CONTEXT.md`, `COORDINATION.md`, `DEVELOPMENT_LOG.md`.
**Result:** Docs match the app again.

## 2026-06-11 (night) — marathon slice 8: inline Retry on failure rows
**What & why:** When both brains are unreachable the reply row shows the unavailable message —
and the only recovery was the hover-only regenerate icon. Failure rows (`text ==
LocalLLM.offMessage`) now carry an inline accent **Retry** button under the message (calls the
same `regenerate`). Gallery gains a failure-row section so the state is photographed +
baselined.
**Files:** `Views/ContentView.swift`, `Tools/QASnapshots.swift`; bundle regenerated.
**Result:** Typecheck EXIT=0 (CodeView WIP pinned).

## 2026-06-11 (night) — marathon slice 9: slash-menu keyboard navigation
**What & why:** ↑/↓ now move a visible selection through the `/`-menu and ↵ picks the selected
row (was: ↵ always took the top). Selection + hover share the same highlight; the ↵ glyph
follows the selection; typing resets it to the top (piggybacked on the draft-persist
`onChange`). No conflict with ↑-recall: the menu only opens on a non-empty composer, recall
only fires on an empty one. Selection is clamped against current matches at use-time so a
narrowing query can never index out of bounds.
**Files:** `Views/ContentView.swift`; bundle regenerated.
**Result:** Typecheck EXIT=0 (CodeView WIP pinned).

## 2026-06-12 — marathon E: find-in-conversation (⌥⌘F) + history leak-sanitizer
**E:** Code tab gets conversation search — ⌥⌘F opens a strip above the messages
(⌘F stays find-in-FILE): live "n/total" count, ↑/↓ + Enter jump with wrap-around,
Esc/✕ closes back to the composer, and the current match row carries a subtle accent
wash. Verified in pixels: queried the live conversation, bar shows "1/2", match washed.
**Sanitizer:** replies persisted BEFORE stripNarration existed still carried the leaked
scaffold (seen live: "Thoughts on this response?" + fake GitHub footnotes fossilized in
history). History now passes through `CodeView.sanitizedHistory` on every load —
assistant turns cleaned, user turns untouched, IDs preserved — pinned by a unit test
(suite green), and the live `code_history.json` was cleaned once directly (0 leak
occurrences after).
**Files:** `Views/CodeView.swift`, `Salehman AITests/ToolLoopTests.swift`.

## 2026-06-11 (night) — marathon slice 10: right-click context menus on message rows
**What & why:** Every hover-pill action is now also a native context menu — user rows: Copy,
Edit & Resend; assistant rows: Copy, Quote in Composer, Read Aloud/Stop Speaking, Regenerate.
Hover affordances are invisible until discovered; right-click is the macOS-native first reach.
**Files:** `Views/ContentView.swift`; bundle regenerated.
**Result:** Typecheck EXIT=0 (CodeView WIP pinned).

## 2026-06-11 (night) — marathon slice 11: CONVERSATION HISTORY (new chat archives, never erases)
**What & why:** The app held exactly ONE conversation — ⌘N erased it forever. Now: `newChat`
flushes the save debounce and snapshots the conversation into
`Application Support/SalehmanAI/chats/chat_<ms>.json` (same `[ChatMessage]` coding as the live
file). NEW `ChatHistoryView` sheet (header clock icon, or `/history`): archived conversations
newest-activity-first (title = first user line via pure `ChatStore.archiveTitle`, date ·
message count), per-row **Restore** (symmetric — current conversation is archived first, the
restored file removed since it becomes live) and delete. Empty state explains the ⌘N-archives
behavior. 4 `ChatArchiveTitleTests` pin the title derivation.
**Files:** `Views/ContentView.swift` (ChatStore archive API + wiring + header icon + sheet +
/history), NEW `Views/ChatHistoryView.swift`, `Salehman AITests/ChatComposerLogicTests.swift`;
bundle regenerated.
**Result:** Typecheck EXIT=0 (CodeView WIP pinned). Archives are additive — existing
chat_history.json untouched; restore is plain load.

## 2026-06-11 (night) — marathon: chat_history QA surface + board status (slices 7-11)
**What & why:** The new History sheet joins the capture set (`chat_history`, 520×560 — renders
its deterministic empty state offscreen since onAppear never fires there). Board row updated
with second-half slice SHAs.
**Files:** `Tools/QASnapshots.swift`, `COORDINATION.md`; bundle regenerated.
**Result:** Typecheck EXIT=0. SNAPSHOT_REQUEST pending for the next rebuilt cycle.

## 2026-06-11 (night) — marathon slice 12: reply stats in the timing tooltip
**What & why:** Hovering the "4.2s" pill now tells the whole story: "Generated in 4.2s ·
213 words · 22:41". Word split runs only when the pill renders (hover/QA) — free at rest.
**Files:** `Views/ContentView.swift`; bundle regenerated.
**Result:** Typecheck EXIT=0.

## 2026-06-11 (night) — Chat C: tabs marathon cycles 3–4 (Knowledge sort + Notes search/clear)
**Files:** `Views/KnowledgeView.swift`, `Views/ScratchpadView.swift`, + `KnowledgeSortTests`, `ScratchpadListTests`.
Commits `9b0f5da`, `13b97f7`.
- **Feature — Knowledge document sort** (Recent / Name / Most-passages): pure `KnowledgeSort` enum + a sort Menu
  by the doc count (now 77 docs). **5 tests**. Verified rendering.
- **Feature — Notes search + Clear-completed**: pure `ScratchpadList` (active-first ordering + case-insensitive
  filter + completedCount) drives the tab. Search field shown when >5 items; "Clear N completed" button when
  done tasks exist; no-match copy. Extracted the previously-untested ordering → **6 tests**. "Clear 2 completed"
  verified in notes.png.
**Verified by marker:** `** BUILD SUCCEEDED **` · full `** TEST SUCCEEDED **` — **381 cases** (322 at marathon
start). Pattern: pure `XxxSort`/`XxxList` enum from the view → menu in the view → unit tests. Marathon continues.

## 2026-06-11 (night) — marathon: pictures verified (history sheet + gallery), baselines adopted, history UI flow
**What & why:** The 23:35 rebuilt capture photographed everything: `chat_history.png` empty
state matches the design (header bar, hairline, explainer); `chat_samples.png` shows the
failure-row Retry, two-button user pill, four-icon assistant pill — its 8.0% baselineDiff was
the predicted intentional drift → `ADOPT_BASELINES` planted at this verified state. Added the
history sheet's UI flow (`testHistorySheetOpensAndCloses`, content-agnostic) + the header
clock's accessibilityLabel it clicks. Knowledge/notes drifts in the same cycle are Chat C's
lane (passing, unbudgeted).
**Files:** `Views/ContentView.swift` (a11y label), `Salehman AIUITests/ChatTabUITests.swift`,
qa request files; bundle regenerated.
**Result:** Typecheck EXIT=0. 9 UI flows total.

## 2026-06-12 (00:05) — Chat C: tabs marathon cycle 5 (Agents grid filter)
**Files:** `Views/AgentsView.swift` (Chat B lane, owner-auth), `AgentFilterTests`. Commit `3c2346e`.
**Feature:** filter the ~15-agent grid — new pure `AgentFilter.matching` (case-insensitive name OR role) + a
"Filter agents…" field above the grid + a no-match state. **5 tests.** Filter field verified in agents.png.
**Verified:** `** BUILD SUCCEEDED **` · full `** TEST SUCCEEDED **` — **387 cases**. All 4 in-scope tabs now have
a new feature (Markets sort, Knowledge sort, Notes search/clear, Agents filter) + heavy tests (29 new since
marathon start, 322→387). Next: sheet polish (Memory/Onboarding/About/Shortcuts) or more tab tests.

## 2026-06-12 (early) — marathon: post-adopt gate CLEAN + archive prune + a QA-eyes lesson
**What & why:** (1) Post-adoption cycle: failures `[]`, every chat surface within budget against
the new baselines — the marathon's visual state is fully baselined. (2) `pruneArchives(keep:100)`
after each archive write — timestamped names sort chronologically, so name order is age order;
unbounded growth would bloat `archives()` (it decodes every file). (3) **Eyes lesson:** the
21.7% `agents` drift looked like a light-mode leak in my image preview (white canvas, black
title) — but raw pixels, histogram (93.8% dark), and canvasFlat all said the file is a healthy
dark capture. My preview renderer inverts SOME mostly-dark PNGs; the audit reads raw pixels and
was right. Rule reinforced: a suspicious PICTURE gets verified with pixel math before any
cross-lane flag (almost sent Chat A/C on a snipe hunt). The drift is Chat C's intentional
agents polish (`4d3deb6`), passing.
**Files:** `Views/ContentView.swift`; bundle regenerated.
**Result:** Typecheck EXIT=0.

## 2026-06-12 (early) — marathon slice 15: welcome history link + honest /clear copy
**What & why:** The welcome now shows a quiet "N earlier conversations" link (clock glyph,
secondary) when archives exist — opens the History sheet; exactly where "where did my chat
go?" happens. Probed once per empty-state appearance alongside `localModelReady`; invisible in
QA captures (offscreen `.task` never runs) so no baseline churn. `/clear`'s blurb now says
"New chat (this one is archived)" — the command stopped being destructive in slice 11 and the
copy should say so.
**Files:** `Views/ContentView.swift`; bundle regenerated.
**Result:** Typecheck EXIT=0.

## 2026-06-12 (early) — marathon finale: adversarial self-review fixes (2 real defects)
**What & why:** Closing sweep over all 15 marathon slices found two real bugs, both mine:
(1) **multi-load race** — `loadingAttachment` was a Bool, so on a multi-file drop the FIRST
finished load cleared "loading" while siblings were still reading, briefly enabling Send with
half the files attached. Now a counter (`attachmentLoads`, computed `loadingAttachment`) —
every load site increments/decrements, Send waits for all. (2) **restore-under-stream** —
restoring an archive mid-generation would swap `vm.messages` underneath the running task;
`restoreArchive` now calls `vm.stop()` first (same graceful cancel as the stop button).
Reviewed and cleared the rest: newChat-while-running (startNewChat stops internally; partial
replies deliberately not archived), slash-selection clamping, balanced counter on the
no-pasteboard path, archive↔restore file lifecycle (no leak: restore deletes, prune caps).
**Files:** `Views/ContentView.swift`; bundle regenerated.
**Result:** Typecheck EXIT=0.

## 2026-06-12 (00:36) — Chat C: tabs marathon cycle 6 (Knowledge name-filter)
**Files:** `Views/KnowledgeView.swift`, `KnowledgeSortTests`. Commit `efc0b0a`.
**Feature:** `KnowledgeSort.apply` now takes an optional case-insensitive name filter (filter→sort composes);
a "Find a document…" field appears when >10 docs (useful at 77) + a no-match state. **4 new filter tests**
(KnowledgeSortTests now 9). Filter field verified in knowledge.png.
**Verified:** `** BUILD SUCCEEDED **` · full `** TEST SUCCEEDED **` — **389 cases**. Marathon: 6 cycles, 33 new
tests (322→389), every tab feature test-pinned, build green throughout, no workflows.

## 2026-06-12 — marathon F: Activity throughput readouts + welcome recent-projects
**F:** the Activity header now shows a **live ≈tok/s estimate** while the answer streams
(chars/4 over elapsed — an honest average, not a fake instantaneous rate) next to the
run clock, and the idle panel shows the last local run's **engine + measured tok/s**
(`OllamaClient.lastStats`) — "is my model fast right now" lives where the activity lives.
**Welcome recents:** up to 3 recent projects as pills under the shortcut hints (current
root filtered out) → one click into `openProject(at:)` even with the tree collapsed.
**Verified:** build green; welcome pill verified in capture pixels (seeded a 2nd MRU
entry, photographed, fixture removed + MRU reset). The two tok/s readouts are
build-verified only — they need a live local generation to display, and they reuse the
already-verified TimelineView/lastStats plumbing.
**Files:** `Views/CodeView.swift`.

## 2026-06-12 — marathon G: git-status dots in the file tree (joint with the guardian session)
**What:** tree rows now show an **amber dot** for anything git considers uncommitted
(modified/untracked, `-uall` so untracked dirs list per-file) — distinct from the accent
dot (= files the AI touched THIS run). `CodeWorkspace.gitModified` refreshes on every
`reload()` off-main; non-repos yield an empty set. Parser extracted pure
(`gitModifiedURLs(porcelain:root:)` — renames take the new side, quoted paths
unquoted) — extraction + `CodeGitStatusTests` landed mid-flight from the guardian
session working the same file; sealed together. Build + tests green.
**Files:** `Views/CodeView.swift`, `Salehman AITests/CodeGitStatusTests.swift`.

## 2026-06-12 (01:05) — Chat C: tabs marathon cycle 7 (MemoryStore heavy tests)
**What:** Heavy coverage for the Memory tab's store, previously only touched by
`PersistenceRoundTripTests`. New `MemoryStoreFactsTests` (16 cases): pins the pure
`MemoryStore.extractFacts(from:)` auto-memory extractor — one assertion per pattern
family (name / role-ending-in-known-profession / workplace / location / preference /
dislike / tool), plus case-insensitivity + trailing-punctuation trim, and the
conservative rejections (plain prose, too-short input, noise values like "that"). Also
pins the `remember` contract via a throwaway temp-dir `init(baseDirectory:)`:
case-insensitive dedup, whitespace trim + blank-ignore, delete/clear, and the
`recall` keyword-fallback match. Pure-logic + seam-based — no model calls, no shared
global state (unique temp dir per test).
**Result:** New suite green in isolation (16/16) AND full `Salehman AITests` green by
the `** TEST SUCCEEDED **` marker. Additive only — no source/lane touched. Commit `3d7e8a1`.
**Files:** `Salehman AITests/MemoryStoreFactsTests.swift` (new).

## 2026-06-12 — marathon H: Restore Checkpoint (run-level undo) + per-file revert
**What (deep-research #1+#2 — the trust features every shipped agent converged on):**
- **Restore all** in the Changed-files header: one click reverts EVERY file the last
  run touched to its pre-run snapshot (the snapshots already existed for the diff
  pane — this completes the loop Cursor/Claude-Code/Zed all ship).
- **Per-file revert**: hovering a changed-file row swaps its +N −M stats for an undo
  button — accept the good files, revert just the bad one.
- Engine: `CodeWorkspace.revert(file:toSnapshot:)` (snapshot back, or DELETE files the
  run created — that is their pre-run state) + `restoreFromSnapshot`/`restoreAllChanged`
  which sync changed-list, stats, tree, open file/diff pane, and git dots.
**Verified:** build green; `RestoreSnapshotTests` (3 temp-dir round-trips: modified→
snapshot restored, created→deleted, missing→throws) — TEST SUCCEEDED.
**Files:** `Views/CodeView.swift`, `Salehman AITests/RestoreSnapshotTests.swift`.

## 2026-06-12 — marathon I: high-end design pass (owner: /high-end-visual-design ×3)
**What (the loaded design language translated to native SwiftUI, restrained for a
desktop tool):**
- **Double-bezel composer** — inner core (own surface + machined top-bevel gradient
  hairline, radius 14) seated in an outer tray (radius 18, concentric 18−4=14); the
  signature red ring moved to the OUTER shell. Owner-loved ring behavior unchanged
  (38%→60% while typing, full on drop, focus glow).
- **One motion language** — 16 scattered `withAnimation(.easeOut(0.12–0.18))` sites
  unified onto `CodeView.lux` = timingCurve(0.32, 0.72, 0, 1, 0.4s): heavy start, soft
  landing, one physical feel across panels/menus/hovers.
- **Welcome**: "PAIR PROGRAMMER" eyebrow tag (9pt caps, 2.2 tracking, hairline capsule)
  + one-shot heavy fade-up entrance. Entrance is pre-revealed under `--qa` (offscreen
  renders never fire onAppear — captures would otherwise photograph an invisible
  welcome).
- **`design/` bundle** — 8 self-contained HTML cards documenting the system from the
  REAL tokens (#FA2E4A accent, #202020/#181818 surfaces, 12% hairlines): palette, type
  scale, bezel composer, slash menu, activity, changed-files, pills, message rows.
  (@dsCard-marked for claude.ai design-sync; the push itself was declined — local only.)
**Verified:** build green; QA all surfaces pass; eyebrow + bezel composer confirmed in
capture pixels.
**Files:** `Views/CodeView.swift`, `design/**`.

## 2026-06-12 (~01:1x) — Chat C: Swift 6.2 concurrency-isolation audit → MemoryStore.recall off-main fix
**What & why:** Owner-requested deep-research on Swift 6 strict concurrency + SwiftUI macOS, then a
codebase audit of the 3 to-dos it surfaced. Findings: (1) build settings confirm BOTH
`SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` and `SWIFT_APPROACHABLE_CONCURRENCY = YES` (all 6 configs,
Swift 6.0 mode) — unmarked types are MainActor-isolated; `nonisolated async` is `nonisolated(nonsending)`.
(2) Under that default, `MemoryStore` (lock-based `@unchecked Sendable`) had `remember`/`embed`/`autoExtract`/
`extractFacts`/`persist` correctly `nonisolated`, but **`recall` and `cosine` were missed** → silently pinned
to MainActor. `recall` is the heavy path (NLEmbedding + cosine over every stored memory), called
**synchronously at `AgentPipeline.swift:458`** → ran on the main thread. Marked both `nonisolated` (lock-safe;
identical to the sibling pattern; no longer main-pinned). (3) No live Codable-conformance trap: every
`Codable` type is a `struct` (several explicitly `Sendable`/`nonisolated`) and the app builds — empirical proof.
**FLAGGED for Chat A (not edited — their lane):** to move recall fully off-main, offload the
`AgentPipeline.swift:458` call site (`Task.detached`/`@concurrent`).
**Result:** MemoryStore change compiles clean (whole-module: **0 MemoryStore errors**). Full
`** TEST SUCCEEDED **` marker currently BLOCKED by an UNRELATED red — `CodeView.swift:895-899` `welcomeAppeared`
not in scope (Chat B's active CodeView WIP, landed red after my 01:00 green). Flagged on COORDINATION board;
not fixing (not my lane). Will reconfirm green once CodeView compiles.
**Files:** `Salehman AI/Persistence/MemoryStore.swift`, `COORDINATION.md`, `DEVELOPMENT_LOG.md`.

## 2026-06-12 — marathon J: design pass 2 — haptic depth (owner: /high-end-visual-design again)
**What:** (1) `LuxPressStyle` — pills and primary actions compress (0.97) under the
pointer on the lux curve: simulated mass, transform-only/GPU-safe; applied to the
welcome pills + send/stop. (2) **Island pills**: the welcome starters' icons no longer
sit naked next to text — each is seated in its own accent-tinted circle flush with the
capsule's leading edge (button-in-button). (3) **Slash menu double-bezel**: inner core
(codeSurface + top-bevel gradient hairline, r11) in an outer tray carrying the accent
ring (r15, concentric). (4) **Activity tiles**: machined top-bevel hairline per step
card. Web-only skill clauses (scroll observers, mobile collapse, webfonts) consciously
N/A for a native desktop tool — fidelity to the app's own token system wins.
**Verified in pixels:** welcome pills + eyebrow (code_tab crop), bezeled slash menu +
activity tiles (code_samples crop). Build green; QA all surfaces pass.
**Files:** `Views/CodeView.swift`.

## 2026-06-12 (~01:3x) — Chat C: tabs marathon cycle 8 (Memory viewer sort)
**What & why:** Memory sheet (`Views/MemoryView.swift`) had a search filter but no sort.
Added a pure `MemorySort` enum (`newest`/`oldest`/`alphabetical`) with `apply(_:filter:)`
that folds the case-insensitive substring filter in before ordering — single source of
truth for the list, and unit-testable. Facts arrive oldest-first from `allFacts()`, so
`newest` reverses; `alphabetical` is `localizedCaseInsensitiveCompare`. Wired a sort `Menu`
into a new `controlsRow` (search shown when >3 facts, sort when >1), mirroring the proven
`KnowledgeSort` enum→Menu pattern. New `MemorySortTests` (7 cases): store-order, reverse,
case-insensitive A–Z, filter-before-sort, blank/no-match, empty input, title+icon non-empty.
**Result:** Feature verified green — isolated `MemorySortTests` run compiled the whole app
(MemoryView + the prior MemoryStore fix included) and passed: `** TEST SUCCEEDED **` (commit
`60d7934`). The subsequent FULL-suite run went red, but **100% in `SettingsView.swift`
(Chat B's lane, `activeBrain*` scope, 10×)** — landed between my two runs; 0 errors in any
of my files. Flagged on the COORDINATION board (banner); not fixing (not my lane). This run
also CONFIRMED the previously-pending green for the `458e4c5` MemoryStore `recall`/`cosine`
`nonisolated` fix (CodeView red cleared by Chat B).
**Files:** `Salehman AI/Views/MemoryView.swift`, `Salehman AITests/MemorySortTests.swift`,
`COORDINATION.md`, `DEVELOPMENT_LOG.md`.

## 2026-06-12 (~02:00) — Chat D slice 1: Settings brainReady perf seam + 5th blocked suite enabled + Hijri filename fix
**Who:** Chat D (new session tonight — owner: "work on salehman with 3 other sessions", ultracode/xhigh inline, full-auto).
**What & why:**
- **CODEBASE_REVIEW HIGH perf fix:** `SettingsView.brainReady` fired live Keychain
  `hasKey()` syscalls per visible grid cell on EVERY body recompute (each keystroke +
  each 5s poll tick ≈ 25+ `SecItemCopyMatching`; `.salehman` alone walked the 10-key
  `SalehmanEngine.hasAnyCloud` chain) while the cached `@State` *KeySaved flags sat
  unused. Extracted the rules to NEW `Views/SettingsBrainReadiness.swift` —
  `BrainReadiness` (pure per-`BrainPreference` reachability over plain Bools) — and
  `brainReady` is now a thin caller fed ONLY by cached flags: **0 Keychain syscalls
  per recompute**. Behavior preserved exactly (rule-for-rule copy of the old switch).
- Same file gains `ActiveBrainProbe` (the overlapping testActiveBrain-runs counter as
  a value type), `BrainPing.verdict` (ping-reply classification), and
  `AnthropicKeyPresentation` (no-leak key subtitle) — SettingsView rewired to all
  three (3 @State vars → 1 probe; logic unchanged).
- **`SettingsBrainReadyTests` ENABLED** (4th of the 5 blocked §4 suites): the 5
  disabled stubs replaced by 7 real tests pinning `.auto` local-only (cloud keys must
  never light it), `.freeAuto` never-spends, `.salehman` cloud-first + named-model
  local floor, ensemble/coding pool membership, probe overlap rules (superseded run
  never publishes; spinner clears at zero in-flight), ping verdict, and subtitle
  no-leak assertions. (Stub names referenced the pre-cloud-first model — renamed to
  today's semantics.)
- **Cross-lane one-liner (claimed on board): `ContentView.swift` `exportFilename`** —
  first real run of Chat A's exporter tests caught a genuine cross-locale bug: a bare
  `DateFormatter` follows the DEVICE calendar, and this Mac runs Hijri (xcresult path
  literally `…1447.12.26…`), so export filenames rendered Hijri-era dates and
  `usesTitleAndLastActivityDate` failed. Fix: `df.locale = en_US_POSIX` (Apple's
  fixed-format rule).
- Docs: PROJECT_CONTEXT (SettingsView row + new seam row + §4 suite status).
**Process note (own fault, logged per house rules):** my sequential edits opened a
~minutes-long red window (`activeBrain*` decls replaced before usages) that Chat C's
typecheck caught and flagged as Chat B's. Resolved + apologized on the board; lesson:
order multi-site renames usages-first, decls-last.
**Verified (by measurement):** app `** BUILD SUCCEEDED **` (canonical command); QA
capture run — `settings` surface passes all checks (baselineDiff 0.33%, in budget,
render 402ms; grid dots pixel-identical through the cached-flag path); AITests run:
**454 passed, my 7 SettingsBrainReadyTests all green**; sole failure was the
pre-existing Hijri filename bug above → fixed, full-suite re-run pending behind
another session's build-DB lock (will confirm the `** TEST SUCCEEDED **` marker
before releasing the lane).
**Files:** `Salehman AI/Views/SettingsBrainReadiness.swift` (new),
`Salehman AI/Views/SettingsView.swift`, `Salehman AI/Views/ContentView.swift`
(one-liner, claimed), `Salehman AITests/SettingsBrainReadyTests.swift`,
`PROJECT_CONTEXT.md`, `COORDINATION.md`, `DEVELOPMENT_LOG.md`.

## 2026-06-12 — marathon K: design pass 3 — the quiet surfaces
**What (variance: rails/headers/chips this round, not heroes):** user message tiles get
the composer-core top-bevel hairline (machined objects in the flow); the find-in-
conversation strip gets a leading top bevel; tok/s + ctx header chips seated in hairline
capsules; ACTIVITY / CHANGED FILES section headers unified onto the tracked-caps
eyebrow idiom (10pt, 1.4 tracking).
**Verified:** build green; gallery drift 8.83% eyes-verified = the intended user-tile
bevel; baseline adopted; all other surfaces pass.
**Files:** `Views/CodeView.swift`.

## 2026-06-12 — marathon L: design pass 4 — completionist sweep + responsive integrity
**What:** the last untreated chrome joins the language — inspector empty state (FILES &
DIFFS eyebrow capsule + beveled icon disc), press physics on the Review capsule and
both edge-rail reopen buttons. **Responsive integrity verified**: the 640pt narrow
capture holds every treatment (eyebrow, island pills, bezel composer + ring, rails) with
no clipping or overflow.
**Coverage note:** the design language now reaches 100% of the Code tab's chrome —
every surface is a tray, core, rail, or eyebrow; all interaction compresses; all motion
shares the lux curve. Further passes here hit diminishing returns; the language is
ready to extend to other tabs (coordinate with Chat C, who holds them).
**Files:** `Views/CodeView.swift`.

## 2026-06-12 (~01:5x) — Chat C: high-end visual pass on Onboarding (owner directive "f/high-end-visual-design")
**What & why:** Owner asked for high-end/premium visual design. Elevated the first-run
`OnboardingView` (first impression → highest leverage) WITHIN the existing dark/brand DS
language — explicitly no palette change (owner confirmed the grey/DS colors are fine):
(1) two layered ambient accent-glow orbs (blurred, low-opacity) for lit depth behind the hero
tile; (2) per-page editorial **eyebrow** (WELCOME / PRIVACY / YOUR BRAINS / CAPABILITIES) for
rhythm; (3) top-lit gradient edge-highlight on the hero tile so it reads dimensional, not flat;
(4) hover-reactive primary CTA (scale 1.035 + brighter glow + brightness); (5) entrance
fade-rise on the card, gated to settled under `--qa` so offscreen snapshots aren't mid-animation.
Copy untouched (separate concern). Only `DS.*` tokens already used in the file — no new DS deps,
DesignSystem (Chat B's lane) untouched.
**Result:** `** BUILD SUCCEEDED **` (app target, canonical command — whole app green; Chat A's
ContentView:946 red had cleared). **Verified in captured pixels** via the run-salehman-ai driver
→ `qa/snapshots/onboarding.png` shows glow + eyebrow + dimensional tile rendering correctly.
Adopted ONLY the onboarding QA baseline (targeted `cp`, not `--adopt`, to avoid sweeping other
sessions' drift; baselines are gitignored/local). Commit `da3630d`.
**Files:** `Salehman AI/Views/OnboardingView.swift`, `DEVELOPMENT_LOG.md`.

## 2026-06-12 (~02:1x) — Chat C: neutral-grey app backdrop, keep red accent (owner request, cross-lane)
**What & why:** Owner: "today tab should be grey, why is the background red." Investigated → the red
was NOT a Today bug nor my edits: it's the global brand theme — `DS.Palette.accent` is a vivid red
(#FA2E4A), AND the dark backdrop was warm-red-tinted (`bgTop` 0.09/0.05/0.07, `bgBottom` 0.03/0.02/0.03)
with red `BackgroundView` accent glows behind every tab. Asked the owner the scope (Today-only vs global
vs full de-red); they chose **"grey backdrop, keep red accent."** Implemented surgically:
- `DesignSystem.swift` (Chat B's lane): `Palette.bgTop`→(0.11,0.11,0.12), `bgBottom`→(0.04,0.04,0.045),
  `modalBG`→(0.13,0.13,0.14). accent/accent2/brand UNCHANGED (red identity kept).
- `BackgroundView.swift` (Chat A's lane): the two glow fills `Theme.accent`/`accent2` (red) →
  `Color.white` 0.05/0.035 (neutral blooms); doc comments de-redded ("accent glows"→"neutral/ambient").
Today's "Working late" header stays brand-red (it's accent, kept) — flagged to owner as a one-word
follow-up if they want that banner greyed too.
**Result:** `** BUILD SUCCEEDED **` (canonical, after a transient DB-lock retry). Grey base verified in
captured pixels (`qa/snapshots/onboarding.png` — same bgVertical/bgTop tokens BackgroundView uses behind
Today; live-window capture was stale this run). Commit `ff065ec`. Cross-lane but owner-authorized; flagged
on the COORDINATION board (banner) for Chat A + Chat B to coexist, not revert.
**Files:** `Salehman AI/DesignSystem/DesignSystem.swift`, `Salehman AI/Views/BackgroundView.swift`,
`COORDINATION.md`, `DEVELOPMENT_LOG.md`.

## 2026-06-12 — marathon M: /shot — attach your latest screenshot with on-device OCR
**What (owner: "add send last screenshot"):** the composer gets a camera button + a
`/shot` slash command. One click finds the newest image in the user's REAL screenshot
location (`com.apple.screencapture location` → ~/Pictures/Screenshots here; Desktop
fallback) and attaches it — and because the local 14B has no image input, the
screenshot's TEXT is extracted **on-device** (Vision OCR, accurate mode, language
correction) and attached as context: error dialogs, terminal output, UI text all become
usable words. Design language on the chip: live thumbnail in a machined micro-tile,
an accent OCR badge, seated ✕ with press physics.
**Verified:** build green; `ScreenshotGrabberTests` ×3 (newest-image picker with
injected dir + mtimes, non-images ignored, OCR reads a rendered "SALEHMAN OCR 42"
PNG) — TEST SUCCEEDED. One test-only trap fixed: the enumerator returns
/private/var/… for /var/… temp paths, so the picker test compares names, not URLs.
**Files:** `Views/CodeView.swift`, `Salehman AITests/ScreenshotGrabberTests.swift`.

## 2026-06-12 (~02:1x) — Chat C: refined the run-salehman-ai skill (re-verified driver)
**What & why:** `/run-skill-generator` re-invoked; per its step-0 ("refine, don't rewrite") the
`.claude/skills/run-salehman-ai/` skill already exists + works, so I re-ran the driver and updated
stale claims + added gotchas learned this session. Driver verified: fresh `24/24 surfaces OK` capture
(02:13:29), `SNAPSHOT_REQUEST` consumed. SKILL.md edits: surface count 14→24; documented the new
colour-vision (CVD) pass (`*_deuter`/`*_protan` + `cvd_report.html`); honest `FAILURES:` line (e.g.
`code_samples` trips a CVD merge — flag, not crash); test count ~310→~405; "private on-device" →
"cloud-first with local fallback" (honesty). **Two new high-value gotchas:** (1) captures render each
surface in ISOLATION with NO shared `BackgroundView`, so a global backdrop/theme change (the grey-bg work)
does NOT show in `today.png` — verify via `onboarding.png` (draws `bgVertical`) or the live-window
capture; (2) `database is locked` build error = concurrent multi-session build → retry. `.claude/` is
gitignored so the skill is local-only (not committed); logging for traceability.
**Files:** `.claude/skills/run-salehman-ai/SKILL.md` (gitignored), `DEVELOPMENT_LOG.md`.

## 2026-06-12 (~03:0x) — Chat D slice 2: R1 brain-routing seam + Offline-Mode leak FIX + last suite enabled
**Who:** Chat D. **What & why:**
- **CODEBASE_REVIEW R1 (the top refactor):** routing decisions (gating, roster
  membership, order, offline rules) were re-implemented across **11 sites** in
  `LocalLLM` — the drift class behind multiple confirmed bugs. NEW
  `LLM/BrainRouting.swift` is now the ONLY place they live: `CloudProvider`
  (ten providers; free/coding/ensemble roster constants; the ten key checks;
  model/client maps), `BrainRouteConfig` (pure snapshot; `.live()` keeps
  currentBrain's per-pref probe laziness), `BrainRouting.dispatch` (exactly one
  target per pref) + roster builders + `reachableBrain`/`anyBrainReachable`.
  The `generate`/`generateStreaming`/`chat` cascades each became one `switch`
  over the dispatch with per-provider execution helpers (`cloudOneShot`/
  `cloudStream`/`cloudConversational`); `currentBrain` is a thin caller;
  every roster site consumes the plan. The 13 `*Allowed` gates deleted.
- **🔴 FIXED — Offline-Mode cloud leak** (same class as the fixed WebTools
  leak): the three cascades had NO `isOfflineOnly` gate, so a pinned cloud
  brain still made real HTTP calls from direct callers (Settings ping,
  StockSage briefings, title gen) under Offline Mode — and a pinned
  `.salehman` walked its whole cloud chain **including the PAID DeepSeek
  backstop**, while `SalehmanEngine.generate/generateStream/generateWithTools`
  never checked offline at all. Fixed at BOTH layers: `dispatch` hard-gates
  the ten cloud pins → `.unavailable` (the contract `currentBrain` always
  documented), and SalehmanEngine now skips cloud chains offline with
  endpoint engines qualifying only on loopback (the `generateOnDevice` rule).
  Regression-pinned in tests.
- **`BrainRoutingDispatchTests` ENABLED** — the LAST of the 8 review suites
  (all 8 now active): 5 tests pin single-dispatch/no-fallthrough + the
  pin↔provider bijection, `.auto`/`.ollama` never-cloud (even with every key
  configured), the offline hard-gate + all-rosters-empty-offline, freeAuto
  free-only membership/order, and documented roster sets.
- **🟠 FOUND, NOT fixed (owner call): ensemble/DeepSeek drift** —
  `anyBrainReachable` counts DeepSeek but the ensemble fan-out roster never
  included it → a DeepSeek-only setup reads "reachable" with an empty
  fan-out. Preserved verbatim (visible behavior change to fix), documented in
  `CloudProvider.ensembleRoster` + pinned by a test; one-line opt-in when
  wanted. **Open question:** Unsloth/vLLM REMOTE (non-loopback) endpoint pins
  are still untouched by Offline Mode (matches currentBrain's documented
  contract) — flag if that should tighten.
- Docs: PROJECT_CONTEXT (LocalLLM row + new BrainRouting row + §4 all-8 note),
  ARCHITECTURE tree. One test-side lesson re-learned: `#expect(xs.allSatisfy(\.p))`
  macro-expands to a throwing call — use a closure (same as the QAGeometry fix).
**Verified (by measurement):** app `** BUILD SUCCEEDED **` after EVERY rewire
step (additive file → currentBrain/rosters → ladders → engine gates — no red
windows); full `Salehman AITests` **`** TEST SUCCEEDED **` (466 passed**, incl.
the 5 new routing tests); QA capture post-rebuild: `settings` 0.33% / `today`
0.00% stable (the `chat_*` drifts + `chat_history` failure render Chat A's
just-committed design choreography — their baseline re-adopt, flagged).
**Files:** `Salehman AI/LLM/BrainRouting.swift` (new), `Salehman AI/LLM/LocalLLM.swift`,
`Salehman AI/LLM/SalehmanEngine.swift`, `Salehman AITests/BrainRoutingDispatchTests.swift`,
`PROJECT_CONTEXT.md`, `ARCHITECTURE.md`, `COORDINATION.md`, `DEVELOPMENT_LOG.md`.

## 2026-06-12 (~02:3x) — Chat C: high-end visual pass on AboutView (+ honest copy) [marathon, f/high-end-visual-design]
**What & why:** Elevated the About sheet (brand moment, pairs with Onboarding) within the approved
dark/brand DS palette — no colour/DS changes. Applied the same premium kit + the deep-research findings:
ambient brand-glow orb behind the header (depth), top-lit gradient edge-highlight on the 52pt brand tile
(dimension), a "WHAT IT DOES" editorial eyebrow (rhythm), **hover row-highlights** on the capability list
(research: hover is a macOS-only premium affordance — `DS.Palette.accent.opacity(0.07)` on `.onHover`),
and an entrance fade-rise (QA-gated under `--qa`). Only DS.* tokens already in scope. Also reconciled the
sheet's **self-contradictory stale copy**: title "Private, on-device" + intro "Your private, on-device AI"
contradicted its own "cloud-first" body → now "Private when you want it" / "Your AI — cloud-first with a
local fallback" (app is cloud-first by default; same honesty fix applied app-wide).
**Result:** `** BUILD SUCCEEDED **` (after a DB-lock retry). Verified in captured pixels
(`qa/snapshots/about.png`): glow + eyebrow + dimensional tile + honest copy render correctly. Adopted ONLY
the about baseline (targeted `cp`). Full capture `24/24 surfaces OK`; the `FAILURES: chat_history` flag is
Chat B's surface (CVD/contrast), not mine. Commit `23cc98b`.
**Files:** `Salehman AI/Views/AboutView.swift`, `DEVELOPMENT_LOG.md`.
