import Foundation
import SwiftUI
import Combine

/// One agent in the team.
struct AgentSpec: Identifiable {
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
private enum Thresholds {
    static let maxTurnLength = 4_000      // chars: cap one stored transcript turn
    static let turnHistorySize = 8        // rolling transcript turns kept
    static let fullTokens = 700           // max tokens for a "full" agent reply
    static let shortTokens = 110          // max tokens for a terse agent note
    static let trivialLength = 40         // chars: a mission this short may be trivial
    static let longMessageLength = 200    // chars → treat as a "long" message
    static let wordCountThreshold = 30    // words → treat as a "long" message
    static let rawPromptTokens = 300      // max tokens for the raw-prompt path
}

/// Keeps a short rolling transcript so non-chat agents have conversation context.
actor ConversationStore {
    static let shared = ConversationStore()
    private var turns: [(role: String, text: String)] = []

    func add(role: String, text: String) {
        // Cap each stored turn so a single huge paste can't bloat memory or the
        // prompt context that every later agent inherits.
        let capped = text.count > Thresholds.maxTurnLength
            ? String(text.prefix(Thresholds.maxTurnLength)) + "…" : text
        turns.append((role, capped))
        if turns.count > Thresholds.turnHistorySize {
            turns.removeFirst(turns.count - Thresholds.turnHistorySize)
        }
    }
    func transcript() -> String {
        turns.map { "\($0.role): \($0.text)" }.joined(separator: "\n")
    }
    func reset() { turns.removeAll() }
}

/// Runs the full multi-agent pipeline for one user message.
enum AgentPipeline {
    static func run(mission: String) async -> String {
        // Don't gate the pipeline on Apple Intelligence — when it's off, the
        // LocalLLM layer transparently falls back to Ollama qwen-coder so the
        // agents keep working with the local brain. We only bail out when
        // neither brain is reachable.
        let brain = await LocalLLM.currentBrain()
        if brain == .none { return LocalLLM.offMessage }

        // "All Brains at Once" bypasses the multi-agent team entirely: ensemble
        // means "ask every reachable brain the raw prompt, show all answers",
        // not "run the 15-agent pipeline on one brain". The complexity/spec
        // logic below doesn't apply.
        if LocalLLM.isEnsembleMode {
            return await LocalLLM.generateEnsemble(mission)
        }

        // "Free · Auto" likewise bypasses the multi-agent team: it races the
        // free brains in parallel for one fast answer (local backstop), not a
        // 15-agent pipeline. Same short-circuit shape as ensemble above.
        if LocalLLM.isFreeAutoMode {
            return await LocalLLM.generateFreeAuto(mission)
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
        // and directly delays the answer. Same predicate as `effectiveCap`'s
        // serial-brain branch so they stay in lockstep when a new serial brain
        // is added.
        let isSerialLocal = (brain == .ollamaCoder || brain == .salehman || brain == .unslothStudio)
        if specs.count > 1 && !isSerialLocal {
            Task.detached(priority: .utility) {
                let map = await adaptTitles(mission: mission, names: specs.map { $0.name })
                if !map.isEmpty { await MainActor.run { MissionProgress.shared.applyAdapted(map) } }
            }
        }

        var history = await ConversationStore.shared.transcript()
        let memories = MemoryStore.shared.recall(mission)
        if !memories.isEmpty {
            history = "Known about the user (from long-term memory):\n" + memories.map { "• \(String($0.prefix(280)))" }.joined(separator: "\n") + "\n\n" + history
        }
        // Structured backbone: a MissionPlan + MissionMemory accumulate the run,
        // and the per-agent handlers are looked up from AgentRegistry.
        let plan = MissionPlan(mission: mission,
                               successCriteria: ["Directly answers the user", "Factually correct", "Clear and complete"],
                               keyRisks: ["Hallucination", "Stale info without web access", "Over-coding a non-code request"],
                               recommendedAgents: specs.map { $0.name })
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
                        onStream: stream)
                    group.addTask {
                        await MainActor.run { MissionProgress.shared.setRunning(i) }
                        // `??` uses an autoclosure that can't contain `await`,
                        // so branch explicitly between the registered handler
                        // and the LocalLLM fallback.
                        let output: String
                        if let handler = AgentRegistry.handler(for: spec.name) {
                            output = await handler(input)
                        } else {
                            output = await LocalLLM.generate(
                                buildPrompt(spec: spec, mission: mission, history: history, context: phaseContext),
                                maxTokens: spec.full ? Thresholds.fullTokens : Thresholds.shortTokens)
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
        memory.recordOutcome(Outcome(successRating: rating, notes: memory.getSummary()))
        lastOutcome = memory.outcome

        await ConversationStore.shared.add(role: "User", text: mission)
        await ConversationStore.shared.add(role: "Salehman AI", text: finalAnswer)
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
    private static let lastOutcomeLock = NSLock()
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
    /// Per-phase agent concurrency cap. On the local Ollama coder we force SERIAL
    /// execution (cap 1) regardless of the memory-based `baseCap` — fanning many
    /// simultaneous inference requests at a multi-GB-resident model can push an
    /// Apple-Silicon Mac (shared RAM/VRAM) into OOM and crash WindowServer.
    /// Other brains use the memory-derived cap (floored at 1). Pure + nonisolated
    /// so the OOM-prevention guarantee is unit-testable and won't silently regress.
    nonisolated static func effectiveCap(brain: LocalLLM.Brain, baseCap: Int) -> Int {
        // Single-instance local servers (Ollama qwen-coder, the user's own
        // `.salehman` model, and the OpenAI-compatible `.unslothStudio`
        // server) all run serially — N parallel requests would queue or OOM
        // on the same shared-RAM box.
        (brain == .ollamaCoder || brain == .salehman || brain == .unslothStudio) ? 1 : max(1, baseCap)
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

    /// Task-complexity tiers that decide how many agents run.
    enum MissionComplexity { case simple, moderate, hard }

    /// Classify a message's complexity from cheap text heuristics (no model
    /// call — zero added latency). Only `.hard` can unlock the full 15-agent
    /// team (and only in Maximum mode). Tuned so the *expensive* mistake —
    /// treating a hard task as simple — is unlikely: any strong "this is real
    /// work" signal escalates to `.hard`, and the middle defaults to
    /// `.moderate` (a safe reason+final pair), never `.simple`.
    nonisolated static func complexity(of mission: String) -> MissionComplexity {
        let trimmed = mission.trimmingCharacters(in: .whitespacesAndNewlines)
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
        if isTrivialMission(mission) { return .simple }
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
