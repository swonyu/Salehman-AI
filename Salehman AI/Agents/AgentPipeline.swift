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
    func stream(_ text: String) { streamingAnswer = text }
    func finish() { running = false; streamingAnswer = "" }
    func clear()  { steps = []; running = false; streamingAnswer = "" }
}

/// Keeps a short rolling transcript so non-chat agents have conversation context.
actor ConversationStore {
    static let shared = ConversationStore()
    private var turns: [(role: String, text: String)] = []

    func add(role: String, text: String) {
        // Cap each stored turn so a single huge paste can't bloat memory or the
        // prompt context that every later agent inherits.
        let capped = text.count > 4_000 ? String(text.prefix(4_000)) + "…" : text
        turns.append((role, capped))
        if turns.count > 8 { turns.removeFirst(turns.count - 8) }
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

        // Speed mode controls how many agents run.
        let mode = await MainActor.run { AppSettings.shared.responseMode }
        let all = AgentDefinitions.pipeline
        let specs: [AgentSpec]
        if brain == .ollamaCoder {
            // SAFETY: the Ollama fallback brain is qwen2.5-coder:32b — each agent
            // is a full ~20 GB 32B inference, and agents in a phase run
            // CONCURRENTLY. Running the multi-agent team on Ollama can exhaust RAM
            // and freeze the whole Mac. So when we're on the heavy local brain we
            // ALWAYS run a single agent (one sequential inference), regardless of
            // the user's response-mode setting. Apple Intelligence is lightweight
            // and OS-managed, so it still honors fast/balanced/full below.
            specs = all.filter { $0.usesTools }
        } else {
            switch mode {
            case .fast:     specs = all.filter { $0.usesTools }                    // just Reasoning Strategist
            case .balanced: specs = all.filter { $0.usesTools || $0.isFinal }      // reason + final (streamed)
            case .full:     specs = all                                            // all 15
            }
        }
        await MainActor.run { MissionProgress.shared.begin(specs) }

        // Adapt the visible role titles to THIS request (non-blocking — titles
        // morph in shortly after the team starts, without slowing the reply).
        if specs.count > 1 {
            Task.detached(priority: .utility) {
                let map = await adaptTitles(mission: mission, names: specs.map { $0.name })
                if !map.isEmpty { await MainActor.run { MissionProgress.shared.applyAdapted(map) } }
            }
        }

        var history = await ConversationStore.shared.transcript()
        let memories = MemoryStore.shared.recall(mission)
        if !memories.isEmpty {
            history = "Known about the user (from long-term memory):\n" + memories.map { "• \($0)" }.joined(separator: "\n") + "\n\n" + history
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

            let results = await withTaskGroup(of: (Int, String).self) { group in
                for i in indices {
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
                                maxTokens: spec.full ? 700 : 110)
                        }
                        await MainActor.run { MissionProgress.shared.setDone(i) }
                        return (i, output)
                    }
                }
                var collected: [(Int, String)] = []
                for await r in group { collected.append(r) }
                return collected
            }

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

    /// The most recent run's recorded outcome (read by Orchestrator for successRating).
    nonisolated(unsafe) static var lastOutcome: Outcome?

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
        let raw = await LocalLLM.generate(prompt, maxTokens: 300)
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

        \(lengthRule)

        User request: \(mission)

        \(ctx)Respond now as the \(spec.name). Do not mention other agents by name in a user-facing way unless you are summarizing.
        """
    }
}
