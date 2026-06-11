import Foundation
import SwiftUI
import Combine

/// One agent in the team. `nonisolated` + `Sendable` (all stored properties are
/// Sendable value types) so a spec can be captured by the concurrent task-group
/// closures in `run` and read off the main actor — a Swift 6 language-mode error
/// otherwise, since MainActor-default isolation would pin its members to the main actor.
nonisolated struct AgentSpec: Identifiable, Sendable {
    let id = UUID()
    let name: String
    let icon: String
    let role: String       // what this agent is told to do
    var usesTools: Bool = false   // true only for the agent that may run terminal commands
    var full: Bool = false        // true for agents that write a complete answer (not a terse note)
    var isFinal: Bool = false     // the agent whose output is shown to the user
    var phase: Int = 0            // agents in the same phase run concurrently
}

/// Live progress so the UI can show every agent working.
@MainActor
final class MissionProgress: ObservableObject {
    static let shared = MissionProgress()

    enum Status { case pending, running, done }
    struct Step: Identifiable {
        let id = UUID()
        let name: String
        let icon: String
        var status: Status
        var adapted: String? = nil   // task-specific title, filled in per message
    }

    @Published var steps: [Step] = []
    @Published var running = false
    @Published var streamingAnswer = ""   // live final answer as it streams

    /// Monotonic timestamp of the last `streamingAnswer` publish, for throttling.
    private var lastStreamPushNs: UInt64 = 0

    private init() {}

    func begin(_ specs: [AgentSpec]) {
        steps = specs.map { Step(name: $0.name, icon: $0.icon, status: .pending) }
        streamingAnswer = ""
        running = true
    }

    /// Apply task-adapted titles (name → adapted title).
    func applyAdapted(_ map: [String: String]) {
        for i in steps.indices {
            if let t = map[steps[i].name], !t.isEmpty { steps[i].adapted = t }
        }
    }
    func setRunning(_ i: Int) { if steps.indices.contains(i) { steps[i].status = .running } }
    func setDone(_ i: Int)    { if steps.indices.contains(i) { steps[i].status = .done } }

    /// Surface tool-loop progress on the RUNNING step's title ("… · tool round
    /// 3/8"). On the 9 GB 14B a single tool round can take 30–90 s, so an
    /// 8-round chain is minutes of otherwise-silent work — this reuses the
    /// existing adapted-title channel (zero new UI) to show life. Idempotent:
    /// re-noting replaces the previous round suffix instead of stacking. No-ops
    /// when no team mission is running (e.g. the trivial fast-path).
    func noteToolRound(_ round: Int, of cap: Int) {
        guard let i = steps.firstIndex(where: { $0.status == .running }) else { return }
        let current = steps[i].adapted ?? steps[i].name
        let base = current.components(separatedBy: " · tool round").first ?? current
        steps[i].adapted = "\(base) · tool round \(round)/\(cap)"
    }
    /// `text` is the FULL cumulative answer so far. Publishing it on every token
    /// re-runs Markdown parsing over the whole string each time (O(n²) on the main
    /// thread → visible jank on long replies). Throttle the @Published write to
    /// ~16 Hz; each write still carries the complete text, and `finish()` clears
    /// the live bubble once the committed message shows the full answer, so a
    /// skipped final fraction is never user-visible.
    func stream(_ text: String) {
        let now = DispatchTime.now().uptimeNanoseconds
        guard now &- lastStreamPushNs >= 60_000_000 else { return }   // 60 ms
        lastStreamPushNs = now
        streamingAnswer = text
    }
    func finish() { running = false; streamingAnswer = ""; lastStreamPushNs = 0 }
    func clear()  { steps = []; running = false; streamingAnswer = "" }
}

/// Named tuning thresholds for the pipeline — were inline magic numbers scattered
/// across the transcript store, the agent runner, and the triviality/length
/// heuristics. Collected here so they're discoverable and tunable in one place.
private nonisolated enum Thresholds {
    static let maxTurnLength = 4_000      // chars: cap one stored transcript turn
    static let turnHistorySize = 8        // rolling transcript turns kept
    static let fullTokens = 700           // max tokens for a "full" agent reply
    static let shortTokens = 110          // max tokens for a terse agent note
    static let trivialLength = 40         // chars: a mission this short may be trivial
    static let longMessageLength = 200    // chars → treat as a "long" message
    static let wordCountThreshold = 30    // words → treat as a "long" message
    static let rawPromptTokens = 300      // max tokens for the raw-prompt path
}

/// Streaming-render tuning shared by the chat views (Code tab + main chat), so both
/// gate live Markdown the same way. Public (module-internal) on purpose.
nonisolated enum StreamRender {
    /// Above this many characters, a STILL-STREAMING reply renders as plain text
    /// instead of re-parsing Markdown on every throttle tick. That O(n)-per-tick
    /// parse is what lags a fast local model (the 32B) — bounding it here keeps the
    /// UI smooth. The committed message always renders full Markdown, so this only
    /// defers rich formatting of long replies until the moment streaming ends.
    static let liveMarkdownLimit = 1200
}

/// Keeps a short rolling transcript so non-chat agents have conversation context.
/// **Self-persisting** (JSON in Application Support) so conversation CONTEXT survives
/// an app restart: the displayed chat already persisted, but this in-memory store used
/// to start empty on every launch — so the AI "forgot" the conversation after a
/// relaunch even though the chat still showed the messages. New Chat clears it.
actor ConversationStore {
    static let shared = ConversationStore()

    /// Codable mirror of a turn (tuples aren't Codable).
    private struct Turn: Codable { var role: String; var text: String }
    private var turns: [Turn] = []

    // Inline the disk read so the actor's `init` doesn't call an actor-isolated
    // method (a Swift-6 isolation error). `fileURL` is pure path logic — no actor
    // state — so it's `nonisolated` and usable from both `init` and `save`.
    init() {
        if let data = try? Data(contentsOf: Self.fileURL),
           let saved = try? JSONDecoder().decode([Turn].self, from: data) {
            turns = saved
        }
    }

    private nonisolated static var fileURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let dir = base.appendingPathComponent("SalehmanAI", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("conversation.json")
    }

    private func save() {
        if let data = try? JSONEncoder().encode(turns) { try? data.write(to: Self.fileURL, options: .atomic) }
    }

    func add(role: String, text: String) {
        // Cap each stored turn so a single huge paste can't bloat memory or the
        // prompt context that every later agent inherits.
        let capped = text.count > Thresholds.maxTurnLength
            ? String(text.prefix(Thresholds.maxTurnLength)) + "…" : text
        turns.append(Turn(role: role, text: capped))
        if turns.count > Thresholds.turnHistorySize {
            turns.removeFirst(turns.count - Thresholds.turnHistorySize)
        }
        save()
    }
    func transcript() -> String {
        turns.map { "\($0.role): \($0.text)" }.joined(separator: "\n")
    }
    func reset() { turns.removeAll(); save() }
}

/// Runs the full multi-agent pipeline for one user message.
enum AgentPipeline {
    static func run(mission: String) async -> String {
        // Every user-facing reply funnels through here, so this is the one place
        // Salehman gets the last word: produce the draft via the normal brain
        // pipeline, then (when Salehman Leader is ON) finalize it through Salehman.
        //
        // Read the PAST transcript up front (before this turn is recorded) so EVERY
        // mode can see the conversation — including the short-circuit ensemble /
        // free-auto / coding paths that bypass the multi-agent team. Without this, a
        // reply like "yes" / "continue" reached the brain with zero context. (A one-shot
        // that must NOT inherit context — e.g. the Code-tab Review — calls
        // `ConversationStore.reset()` first instead, then this records cleanly.)
        let priorHistory = await ConversationStore.shared.transcript()

        // FAST PATH — a bare greeting / chit-chat ("hi", "thanks", "how are you") gets
        // ONE direct Salehman reply: no multi-agent team, no leader/critique finalize,
        // no tools. Even the lightest team path is a tool-agent call PLUS a
        // `refineOwnDraft` self-critique pass — several sequential calls on a local
        // model, which is why a plain "hi" felt like it took forever. History is
        // still recorded. If the engine errors, fall through to the normal pipeline.
        if isTrivialMission(mission) {
            let prompt = withConversationContext(mission, history: priorHistory)
            // Hit the WARM LOCAL model directly (≈2s) for greetings — the cloud-first
            // SalehmanEngine iterates the whole cloud chain before the local floor, so
            // a slow/rate-limited key adds seconds of round-trips to a throwaway "hi".
            // Cloud engine is the fallback only when Ollama is unreachable. (Also makes
            // greetings honor Offline-Only for free.)
            // Cap the reply length: greetings never need >384 tokens, and on a
            // ~25 tok/s local model an unbounded ramble is the difference between
            // 3 s and 30 s. Persona training keeps these short anyway; the cap is
            // the seatbelt.
            var reply = await OllamaClient.chat(
                prompt: prompt, system: SalehmanPersona.activeSystemPrompt,
                gen: .init(keepAlive: "5m", numCtx: 2048, numPredict: 384)) ?? ""
            if reply.isEmpty {   // Ollama unreachable → fall back to the full cloud engine
                reply = await SalehmanEngine.generate(prompt: prompt, userPrompt: mission) ?? ""
            }
            if !isErrorReply(reply) {
                await ConversationStore.shared.add(role: "User", text: mission)
                await ConversationStore.shared.add(role: "Salehman AI", text: reply)
                return reply
            }
        }

        var draft = await runDraft(mission: mission, priorHistory: priorHistory)

        // UNIVERSAL SAFETY NET — the chat must NEVER surface a raw provider error.
        // If the selected brain failed (e.g. cloudCoding with every coder
        // rate-limited, or a cloud brain whose key is missing/exhausted), rescue it
        // with the cloud-first Salehman engine, which cascades the free providers
        // and ULTIMATELY the local Ollama model — so the user gets a real answer
        // instead of "[Provider error 429]". Only fires on a genuine error sentinel,
        // so normal replies pay nothing. The rescue gets the conversation context too.
        if isErrorReply(draft) {
            let rescuePrompt = withConversationContext(mission, history: priorHistory)
            if let rescue = await SalehmanEngine.generate(prompt: rescuePrompt, userPrompt: mission),
               !isErrorReply(rescue) {
                draft = rescue
            }
        }

        let finalAnswer = await SalehmanLeader.finalize(userPrompt: mission, draft: draft)

        // Record the turn HERE — the single chokepoint every mode funnels through —
        // so the short-circuit modes (which `return` before the multi-agent team's
        // old recording site) ALSO persist history. Skip recording an error/off reply
        // so a failed turn can't poison the next turn's context.
        if !isErrorReply(finalAnswer) {
            await ConversationStore.shared.add(role: "User", text: mission)
            await ConversationStore.shared.add(role: "Salehman AI", text: finalAnswer)
        }
        return finalAnswer
    }

    /// True when a draft is an error/off sentinel rather than a real answer, so
    /// `run` can rescue it with a working brain. CONSERVATIVE: only the off-message,
    /// an empty string, or the bracketed `[<provider> error <status>: …]` /
    /// "request failed (HTTP …)" diagnostic shapes count — a normal answer that
    /// merely mentions the word "error" is never mistaken for one. Pure +
    /// nonisolated → unit-testable.
    nonisolated static func isErrorReply(_ text: String) -> Bool {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.isEmpty || t == LocalLLM.offMessage { return true }
        guard t.hasPrefix("[") else { return false }
        let lower = t.lowercased()
        return lower.contains("request failed (http")
            || (lower.contains(" error ") && t.contains(where: \.isNumber))
    }

    /// Folds the recent conversation transcript into a single prompt for the
    /// short-circuit modes (ensemble / free-auto / free-coding / cloud-coding),
    /// which bypass the multi-agent team's own history handling. Without it, a reply
    /// like "yes" / "continue" reaches the brain with no idea what came before.
    /// No-op when there's no history yet (first turn). The transcript is already
    /// length-capped by `ConversationStore`, so this can't bloat the prompt.
    /// Char budget for folded history when the LOCAL floor serves. The 14B runs at
    /// num_ctx 4096 (≈16k chars TOTAL for persona + history + mission + reply); an
    /// oversized prompt is truncated server-side from the TOP — which silently eats
    /// the persona and these very instructions. ~9k chars of history leaves room.
    nonisolated static let localHistoryCharBudget = 9_000

    /// Drop OLDEST lines (the transcript is "Role: text" lines, oldest first) until
    /// `history` fits `budget`. Pure + nonisolated → unit-testable.
    nonisolated static func trimmedForLocalWindow(_ history: String, budget: Int) -> String {
        guard history.count > budget else { return history }
        var lines = history.components(separatedBy: "\n")
        var trimmed = history
        while trimmed.count > budget, lines.count > 2 {
            lines.removeFirst()
            trimmed = lines.joined(separator: "\n")
        }
        return "(earlier context trimmed)\n" + trimmed
    }

    nonisolated static func withConversationContext(_ mission: String, history: String) -> String {
        var h = history.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !h.isEmpty else { return mission }
        // Only the local floor needs the diet — cloud windows are 32k+.
        if !SalehmanEngine.hasAnyCloud {
            h = trimmedForLocalWindow(h, budget: localHistoryCharBudget)
        }
        return """
        Conversation so far (most recent last) — use it to interpret the new message \
        (e.g. a short "yes" / "no" / "continue" refers to what was just discussed):
        \(h)

        New message from the user:
        \(mission)
        """
    }

    /// Heuristic: does this reply look like the assistant STOPPED mid-task and would
    /// continue if nudged? Drives the optional auto-continue loop (claude-autocontinue
    /// style). CONSERVATIVE — only fires on clear "to be continued" signals: the
    /// tool-loop round-cap fallback, an unterminated ``` code block, or the model
    /// explicitly offering to go on. Never fires on a normal complete answer. Pure +
    /// nonisolated → unit-testable.
    nonisolated static func looksIncomplete(_ reply: String) -> Bool {
        let t = reply.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty, !isErrorReply(t) else { return false }
        let lower = t.lowercased()
        if lower.contains("reached the tool-call limit") || lower.contains("say \"continue\"") {
            return true
        }
        // Unterminated code fence ⇒ the answer was cut off mid-block.
        if (t.components(separatedBy: "```").count - 1) % 2 == 1 { return true }
        // The model explicitly offering to go on — check only the tail so the word
        // "continue" appearing mid-answer doesn't trigger a false continuation.
        let tail = String(lower.suffix(140))
        let offers = ["shall i continue", "should i continue", "want me to continue",
                      "like me to continue", "continue?", "to be continued", "(continued)"]
        return offers.contains { tail.contains($0) }
    }

    private static func runDraft(mission: String, priorHistory: String) async -> String {
        // Don't gate the pipeline on a single brain — when one's off, the
        // LocalLLM layer transparently falls back to Ollama qwen-coder so the
        // agents keep working with the local brain. We only bail out when
        // neither brain is reachable.
        let brain = await LocalLLM.currentBrain()
        if brain == .none { return LocalLLM.offMessage }

        // The short-circuit modes below bypass the multi-agent team (and the history
        // handling further down), so fold the recent transcript into the prompt here
        // so they remember the conversation. No-op on the first turn (empty history).
        let contextualMission = withConversationContext(mission, history: priorHistory)

        // "All Brains at Once" bypasses the multi-agent team entirely: ensemble
        // means "ask every reachable brain the raw prompt, show all answers",
        // not "run the 15-agent pipeline on one brain". The complexity/spec
        // logic below doesn't apply.
        if LocalLLM.isEnsembleMode {
            return await LocalLLM.generateEnsemble(contextualMission)
        }

        // "Free · Auto" likewise bypasses the multi-agent team: it races the
        // free brains in parallel for one fast answer (local backstop), not a
        // 15-agent pipeline. Same short-circuit shape as ensemble above.
        //
        // Unrestricted Mode upgrades Free·Auto to a TOOL-capable single brain so
        // it can actually run terminal commands / search the web (the owner asked
        // Free·Auto to "do all commands"). With Unrestricted off it stays the fast
        // no-tool race.
        if LocalLLM.isFreeAutoMode {
            if AppSettings.unrestrictedToolsEnabled {
                return await LocalLLM.freeAutoReplyWithTools(contextualMission)
            }
            return await LocalLLM.generateFreeAuto(contextualMission)
        }

        // FreeCoding: a coding-focused loop over the free coders + DeepSeek. Always
        // tool-capable (coding wants to build/run/test), so it bypasses the
        // multi-agent team too and routes straight to `freeCodingReply`.
        if LocalLLM.isFreeCodingMode {
            return await LocalLLM.freeCodingReply(contextualMission)
        }

        // Cloud Coding: cloud-only "best coders" loop — same tool-capable bypass,
        // no local model (zero RAM / no lag).
        if LocalLLM.isCloudCodingMode {
            return await LocalLLM.cloudCodingReply(contextualMission)
        }

        // How many agents run is a function of BOTH the user's response-mode
        // ceiling AND the message's actual complexity. The response mode is a
        // *ceiling*, not a fixed count: the full 15-agent team only ever runs
        // when the task is genuinely hard AND the user is in Maximum. A
        // greeting or a short question ("who are u") never spins up 15 agents,
        // no matter the mode — that was pure latency + cost.
        //
        // (Ollama-on-32B concurrency RAM risk is handled downstream by
        // `MemoryManager.concurrencyLimit()` + the per-phase batch cap, not here.)
        let mode = await MainActor.run { AppSettings.shared.responseMode }
        let all = AgentDefinitions.pipeline
        let oneAgent = all.filter { $0.usesTools }                 // Reasoning Strategist (tools)
        let twoAgents = all.filter { $0.usesTools || $0.isFinal }  // reason + streamed final

        let specs: [AgentSpec]
        switch (complexity(of: mission), mode) {
        case (.simple, _):           specs = oneAgent              // greetings, short questions
        case (.moderate, .fast):     specs = oneAgent
        case (.moderate, _):         specs = twoAgents             // normal one-line requests
        case (.hard, .fast):         specs = oneAgent
        case (.hard, .balanced):     specs = twoAgents
        case (.hard, .full):         specs = all                   // the ONLY path to all 15
        }
        await MainActor.run { MissionProgress.shared.begin(specs) }

        // Adapt the visible role titles to THIS request (non-blocking — titles
        // morph in shortly after the team starts, without slowing the reply).
        // ⚠️ Skip on single-instance local brains: the detached task is
        // non-blocking from the orchestrator's perspective, but on Ollama / MLX
        // Salehman / Unsloth Studio the model server is serial, so this extra
        // generate() ends up QUEUED ahead of the user's first real agent call
        // and directly delays the answer. Shares `isSerialLocalBrain` with
        // `effectiveCap` + the context diet so a new serial brain updates all.
        let isSerialLocal = Self.isSerialLocalBrain(brain)
        if specs.count > 1 && !isSerialLocal {
            Task.detached(priority: .utility) {
                let map = await adaptTitles(mission: mission, names: specs.map { $0.name })
                if !map.isEmpty { await MainActor.run { MissionProgress.shared.applyAdapted(map) } }
            }
        }

        // `let` (not `var`): an immutable `history` can be captured by the phase's
        // concurrent task-group closures. A mutable `var` stays "accessible to
        // main-actor code", so sending such a closure is a Swift 6 data-race error.
        let baseTranscript = await ConversationStore.shared.transcript()
        let memories = MemoryStore.shared.recall(mission)
        let history = memories.isEmpty
            ? baseTranscript
            : "Known about the user (from long-term memory):\n" + memories.map { "• \(String($0.prefix(280)))" }.joined(separator: "\n") + "\n\n" + baseTranscript
        // Structured backbone: a MissionPlan + MissionMemory accumulate the run,
        // and the per-agent handlers are looked up from AgentRegistry.
        let plan = MissionPlan(mission: mission,
                               successCriteria: ["Directly answers the user", "Factually correct", "Clear and complete"],
                               keyRisks: ["Hallucination", "Stale info without web access", "Over-coding a non-code request"])
        var memory = MissionMemory(missionPlan: plan)
        AgentRegistry.registerDefaultsOnce()

        var reasoning = ""
        var finalAnswer = ""

        // Group agents by phase; phases run in order, agents within a phase run
        // concurrently for speed.
        let phases = Dictionary(grouping: specs.indices, by: { specs[$0].phase })
            .sorted { $0.key < $1.key }

        for (_, indices) in phases {
            // Immutable context snapshot for this phase (shared by its concurrent agents).
            let phaseContext = memory.buildContext(for: "")

            // RAM-aware concurrency cap. `MemoryManager` reads two cheap
            // kernel-pushed signals (memory pressure + thermal state) and
            // returns a recommended in-flight task count for *right now* —
            // re-read per phase so a long pipeline tracks current reality.
            //
            // **Ollama override**: when the brain is local Ollama, we
            // *force* concurrency to 1 regardless of what MemoryManager
            // says. Ollama's server serializes calls against a single
            // loaded model anyway, so >1 in-flight just makes N
            // simultaneous HTTP requests pile up while the user's Mac
            // thrashes through inference (and on Apple-Silicon Macs with
            // shared RAM/VRAM, can push the system into OOM territory —
            // observed crashing macOS's WindowServer when 15 agents fan
            // out against a 9 GB-resident 14B model). The spec count from
            // `responseMode` is preserved, so the UI still shows all 15
            // agent steps and they execute *sequentially* on Ollama —
            // multi-agent quality without the fan-out RAM spike.
            let baseCap = await MemoryManager.shared.concurrencyLimit()
            let cap = Self.effectiveCap(brain: brain, baseCap: baseCap)
            let batches = stride(from: 0, to: indices.count, by: cap).map { start -> [Int] in
                Array(indices[start..<min(start + cap, indices.count)])
            }

            var phaseResults: [(Int, String)] = []
            for batch in batches {
            let results = await withTaskGroup(of: (Int, String).self) { group in
                for i in batch {
                    let spec = specs[i]
                    // Non-final agents get a no-op sink. `if/else` (not a ternary):
                    // Swift's type-checker ICEs ("failed to produce diagnostic")
                    // unifying a `@Sendable` closure literal across branches inside
                    // `withTaskGroup`; pulling the assignment apart sidesteps it.
                    let stream: @Sendable (String) -> Void
                    if spec.isFinal {
                        stream = { (partial: String) in
                            Task { @MainActor in
                                MissionProgress.shared.stream(partial)
                            }
                        }
                    } else {
                        stream = { _ in }
                    }
                    let input = AgentInput(
                        mission: mission, history: history, context: phaseContext,
                        brain: brain, onStream: stream)
                    group.addTask {
                        await MainActor.run { MissionProgress.shared.setRunning(i) }
                        // `??` uses an autoclosure that can't contain `await`,
                        // so branch explicitly between the registered handler
                        // and the LocalLLM fallback.
                        let output: String
                        if let handler = AgentRegistry.handler(for: spec.name) {
                            output = await handler(input)
                        } else {
                            let prompt = buildPrompt(spec: spec, mission: mission, history: history, context: phaseContext)
                            let adapter = BrainAdapterFactory.adapter(for: brain)
                            output = (try? await adapter.complete(messages: [LLMMessage(role: .user, content: prompt)]))
                                ?? LocalLLM.offMessage
                        }
                        await MainActor.run { MissionProgress.shared.setDone(i) }
                        return (i, output)
                    }
                }
                var collected: [(Int, String)] = []
                for await r in group { collected.append(r) }
                return collected
            }
                phaseResults.append(contentsOf: results)
            }
            let results = phaseResults

            // Fold this phase's outputs into MissionMemory (in spec order).
            for (i, output) in results.sorted(by: { $0.0 < $1.0 }) {
                let spec = specs[i]
                memory.recordAgentOutput(name: spec.name, output: output)
                if spec.usesTools {
                    reasoning = output
                    memory.recordToolResult(tool: "reasoning_strategist", summary: String(output.prefix(800)))
                }
                if spec.isFinal { finalAnswer = output }
            }
        }

        await MainActor.run { MissionProgress.shared.finish() }

        if finalAnswer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            finalAnswer = reasoning.isEmpty ? (memory.agentOutputs.last?.output ?? "…") : reasoning
        }

        // Record the outcome so MissionMemory/Outcome aren't dead — Orchestrator reads it.
        let rating: Double = (LocalLLM.isAvailable && !finalAnswer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) ? 1.0 : 0.0
        memory.recordOutcome(Outcome(successRating: rating))
        lastOutcome = memory.outcome

        // (Conversation recording moved to `run()` so ALL modes — not just this
        // multi-agent path — persist history. See the chokepoint note there.)
        return finalAnswer
    }

    /// The most recent run's recorded outcome (read by `Orchestrator` for
    /// successRating). Lock-guarded so the write in `run()` and the read in
    /// `Orchestrator` can't data-race (it was `nonisolated(unsafe)` with NO
    /// synchronization → torn reads / UB under concurrent missions). The call
    /// sites are unchanged — `lastOutcome` is still a plain get/set.
    ///
    /// NOTE: this remains a single global slot, so two *genuinely concurrent*
    /// missions would still overwrite each other's outcome. That's fine for this
    /// app (the chat send-path serializes missions); if concurrent missions ever
    /// become real, return the outcome from `run()` instead of stashing it here.
    private nonisolated(unsafe) static var _lastOutcome: Outcome?
    private nonisolated static let lastOutcomeLock = NSLock()
    nonisolated static var lastOutcome: Outcome? {
        get { lastOutcomeLock.lock(); defer { lastOutcomeLock.unlock() }; return _lastOutcome }
        set { lastOutcomeLock.lock(); defer { lastOutcomeLock.unlock() }; _lastOutcome = newValue }
    }

    /// True when the message is casual chat that doesn't warrant the multi-agent
    /// team (greetings, acknowledgements, 1–2-word small talk). Deliberately
    /// CONSERVATIVE — it must never mis-classify a real task as trivial, so any
    /// of these disqualify it: a `?` (it's a question), multiple lines or >40
    /// chars (likely a paste/real ask), digits or code punctuation (likely a
    /// task), or >2 words that aren't a known greeting phrase. When in doubt it
    /// returns false (full pipeline). Pure + nonisolated → unit-testable.
    /// Single-instance local servers (Ollama qwen-coder, the user's own
    /// `.salehman` model, and the OpenAI-compatible Unsloth-Studio / vLLM
    /// servers) all run serially on the same shared-RAM box — N parallel
    /// requests would queue or OOM. The ONE predicate behind `effectiveCap`,
    /// the adaptTitles skip, and the local context diet, so a new serial brain
    /// added here updates all three behaviors in lockstep.
    nonisolated static func isSerialLocalBrain(_ brain: LocalLLM.Brain) -> Bool {
        brain == .ollamaCoder || brain == .salehman || brain == .unslothStudio || brain == .vllm
    }

    /// Per-phase agent concurrency cap. On the local Ollama coder we force SERIAL
    /// execution (cap 1) regardless of the memory-based `baseCap` — fanning many
    /// simultaneous inference requests at a multi-GB-resident model can push an
    /// Apple-Silicon Mac (shared RAM/VRAM) into OOM and crash WindowServer.
    /// Other brains use the memory-derived cap (floored at 1). Pure + nonisolated
    /// so the OOM-prevention guarantee is unit-testable and won't silently regress.
    nonisolated static func effectiveCap(brain: LocalLLM.Brain, baseCap: Int) -> Int {
        isSerialLocalBrain(brain) ? 1 : max(1, baseCap)
    }

    // MARK: - Local context diet (num_ctx 4096)
    //
    // The rolling transcript caps each TURN at 4,000 chars × 8 turns — worst
    // case 32k chars ≈ 8k tokens, double a local model's num_ctx 4096. Ollama
    // drops the OLDEST tokens on overflow, which silently evicts the system
    // prompt/persona first. So when the brain is a serial LOCAL model, the
    // 2-agent path trims its inputs to these budgets BEFORE the prompt is
    // built (cloud brains keep the full history — they have the context for it).

    /// Char budget for conversation history on a local 4096-ctx brain
    /// (~1.5k tokens), leaving room for persona + tool specs + answer.
    nonisolated static let localHistoryBudget = 6_000
    /// Char budget for phase context on a local 4096-ctx brain.
    nonisolated static let localContextBudget = 1_500

    /// Most-recent suffix of a transcript within `maxChars`, cut at a line
    /// boundary (turns are "Role: text" lines) so no turn is sliced mid-thought.
    /// A single over-budget line falls back to a raw char cut — never empty.
    nonisolated static func recentTail(_ text: String, maxChars: Int) -> String {
        guard text.count > maxChars else { return text }
        let tail = String(text.suffix(maxChars))
        guard let nl = tail.firstIndex(of: "\n") else { return tail }
        let cut = String(tail[tail.index(after: nl)...])
        return cut.isEmpty ? tail : cut
    }

    nonisolated static func isTrivialMission(_ mission: String) -> Bool {
        let trimmed = mission.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !trimmed.contains("\n"), trimmed.count <= Thresholds.trivialLength else { return false }
        if trimmed.contains("?") { return false }

        let normalized = trimmed.lowercased()
            .trimmingCharacters(in: CharacterSet(charactersIn: ".!,…"))

        // Curated chit-chat phrases that are trivial even at >2 words.
        let greetings: Set<String> = [
            "hi", "hello", "hey", "yo", "sup", "hiya", "gm", "good morning",
            "good evening", "good afternoon", "good night", "salam", "salaam",
            "hola", "thanks", "thank you", "thx", "ty", "ok", "okay", "k",
            "cool", "nice", "great", "good", "got it", "gotcha", "perfect",
            "awesome", "test", "ping", "hello there", "how are you",
            "how's it going", "whats up", "what's up", "wassup",
        ]
        if greetings.contains(normalized) { return true }

        // Otherwise: only treat as trivial if it's 1–2 words with no digits and
        // no code-ish characters (so "fix the bug" — 3 words — and "ls -la" —
        // has a dash/flag shape — still get the full pipeline).
        let words = normalized.split(separator: " ")
        guard words.count <= 2 else { return false }
        if normalized.contains(where: { $0.isNumber }) { return false }
        if normalized.contains(where: { "{}()[]<>/\\=;`".contains($0) }) { return false }
        return true
    }

    /// Task-complexity tiers that decide how many agents run. `nonisolated` so
    /// its (implicit) `Equatable` conformance is usable from nonisolated contexts
    /// — e.g. `#expect(complexity == .hard)` in the test target, which would be a
    /// hard error under the Swift 6 language mode otherwise.
    nonisolated enum MissionComplexity { case simple, moderate, hard }

    /// Classify a message's complexity from cheap text heuristics (no model
    /// call — zero added latency). Only `.hard` can unlock the full 15-agent
    /// team (and only in Maximum mode). Tuned so the *expensive* mistake —
    /// treating a hard task as simple — is unlikely: any strong "this is real
    /// work" signal escalates to `.hard`, and the middle defaults to
    /// `.moderate` (a safe reason+final pair), never `.simple`.
    nonisolated static func complexity(of mission: String) -> MissionComplexity {
        // Judge the ACTUAL ask, not wrapper boilerplate. The Code tab wraps a fixed
        // multi-line >200-char coding preamble around "Task: <ask>"; judging the whole
        // string rated EVERY message .hard (multi-line + long + multi-sentence), so a
        // 6-word question like "who are you" spun up the full 15-agent team. Extract
        // the text after the last "Task:" marker when present. (The main chat sends raw
        // messages with no marker, so it's unaffected.)
        let raw = mission.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmed: String = {
            guard let r = raw.range(of: "Task:", options: .backwards) else { return raw }
            let t = raw[r.upperBound...].trimmingCharacters(in: .whitespacesAndNewlines)
            // Drop an appended "Attached file …" block so a pasted file doesn't inflate it.
            let ask = t.range(of: "\n\nAttached file").map { String(t[..<$0.lowerBound]) } ?? t
            return ask.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? raw : ask.trimmingCharacters(in: .whitespacesAndNewlines)
        }()
        guard !trimmed.isEmpty else { return .simple }
        let lower = trimmed.lowercased()
        let wordCount = trimmed.split { $0 == " " || $0 == "\n" }.count

        // HARD — genuine multi-step / engineering work. Any single signal wins.
        let hardPhrases = [
            "build", "implement", "refactor", "debug", "analyze", "analyse",
            "architect", "optimize", "optimise", "design", "integrate", "migrate",
            "rewrite", "audit", "compare", "evaluate", "step by step",
            "write a", "write me", "write the", "create a", "generate a",
            "fix the", "make me a", "walk me through", "explain how", "review the",
        ]
        let hasHardPhrase   = hardPhrases.contains { lower.contains($0) }
        let multiLine       = trimmed.contains("\n")
        let looksLikeCode   = trimmed.contains("```") || trimmed.contains("{") || trimmed.contains(";")
        let long            = trimmed.count > Thresholds.longMessageLength || wordCount > Thresholds.wordCountThreshold
        let multiSentence   = trimmed.filter { ".!?".contains($0) }.count >= 2
        if hasHardPhrase || multiLine || looksLikeCode || long || multiSentence {
            return .hard
        }

        // SIMPLE — greetings, acknowledgements, and short single-clause
        // questions ("who are u", "what's the weather"). One agent is plenty.
        if isTrivialMission(trimmed) { return .simple }
        if wordCount <= 6 { return .simple }

        // MODERATE — a normal one-line request (7–30 words, single sentence,
        // no hard signal). Reason + final is the right weight.
        return .moderate
    }

    /// Ask the model for a short task-specific title for each agent.
    private static func adaptTitles(mission: String, names: [String]) async -> [String: String] {
        let list = names.joined(separator: "\n")
        let prompt = """
        A user sent this request: "\(mission)"

        For each team role below, give a SHORT (2–4 word) specialist title tailored
        to THIS request. Keep one line per role in the exact format:
        OriginalName => Adapted Title

        Roles:
        \(list)
        """
        let raw = await LocalLLM.generate(prompt, maxTokens: Thresholds.rawPromptTokens)
        var map: [String: String] = [:]
        for line in raw.components(separatedBy: "\n") {
            guard let r = line.range(of: "=>") else { continue }
            let original = String(line[..<r.lowerBound]).trimmingCharacters(in: .whitespaces)
            var title = String(line[r.upperBound...]).trimmingCharacters(in: .whitespaces)
            title = title.replacingOccurrences(of: "\"", with: "")
            // Match against a known name (model may tweak spacing).
            if let match = names.first(where: { $0.caseInsensitiveCompare(original) == .orderedSame }) {
                map[match] = title
            }
        }
        return map
    }

    // `nonisolated` because the AgentRegistry's handlers (concurrent task
    // group) need to build prompts off the main actor. Pure string work.
    nonisolated static func buildPrompt(spec: AgentSpec, mission: String, history: String, context: String) -> String {
        var ctx = ""
        if !history.isEmpty { ctx += "Recent conversation:\n\(history)\n\n" }
        if !context.isEmpty { ctx += context + "\n\n" }

        let lengthRule = spec.full
            ? "Write a complete, well-structured response."
            : "Be concise: at most 1–3 short sentences focused only on your specialty. If your specialty does not apply to this request, say so in a few words."

        return """
        You are the "\(spec.name)" agent on Salehman AI's multi-agent team.
        Your job: \(spec.role)

        ADAPT to THIS request: apply your specialty to whatever the user actually
        asked about — it may not be about software. If your specialty doesn't
        directly fit, contribute the most useful related insight you can.

        DO NOT write code unless the user EXPLICITLY asked for code. For factual
        or system questions, rely on the real answer/results already gathered —
        never substitute code for an actual answer. If (and only if) the user
        explicitly asked for code, be rigorous: correct, idiomatic, complete,
        modern Swift/SwiftUI where relevant, with edge cases handled and no TODOs.

        LANGUAGE: reply in the SAME language as the user's request below — never switch on your own, and never default to Arabic unless the user actually wrote in Arabic.

        \(lengthRule)

        User request: \(mission)

        \(ctx)Respond now as the \(spec.name). Do not mention other agents by name in a user-facing way unless you are summarizing.
        """
    }
}
