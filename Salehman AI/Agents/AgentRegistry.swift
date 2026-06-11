import Foundation

/// Per-agent execution input. Immutable + Sendable so handlers can run inside the
/// pipeline's concurrent task group without sharing mutable state.
struct AgentInput: Sendable {
    let mission: String
    let history: String
    let context: String     // built from MissionMemory.buildContext(...)
    let onStream: @Sendable (String) -> Void   // no-op for non-final agents
}

/// Registry of agent handlers. Each handler turns an `AgentInput` into that
/// agent's output. Registered once from `AgentDefinitions.pipeline`; the pipeline
/// looks handlers up by name and runs them concurrently. Recording into
/// `MissionMemory` is done by the pipeline coordinator (never inside a handler),
/// so there is no shared mutable state across the concurrent tasks.
struct AgentRegistry {

    typealias AgentHandler = @Sendable (_ input: AgentInput) async -> String

    // `handlers` is mutated ONLY inside `registerToken`'s initializer (below),
    // which Swift runs exactly once and thread-safely. After that one-time
    // population the dict is read-only, so the concurrent task-group lookups are
    // safe — that's what makes `nonisolated(unsafe)` honest here.
    nonisolated(unsafe) private static var handlers: [String: AgentHandler] = [:]

    // All accessors are `nonisolated` so the pipeline's concurrent task group
    // can look up handlers without hopping to the main actor. The dictionary
    // is mutated exactly once during `registerDefaultsOnce()` (before any
    // pipeline runs), which is why the `nonisolated(unsafe)` annotation above
    // is honest rather than dangerous.
    nonisolated static func register(name: String, handler: @escaping AgentHandler) {
        guard handlers[name] == nil else { return }
        handlers[name] = handler
    }

    nonisolated static func handler(for name: String) -> AgentHandler? { handlers[name] }

    /// Register a handler for every agent in the team. Each handler captures its
    /// spec and picks the right LocalLLM call (tools / streamed final / terse note).
    ///
    /// Thread-safe once-init: the old `guard !didRegister { didRegister = true }`
    /// was a TOCTOU race — two concurrent `run()` calls could both pass the guard
    /// and register into `handlers` simultaneously. A lazy `static let`
    /// initializer is run EXACTLY ONCE by the Swift runtime (dispatch_once under
    /// the hood), so triggering it from here is race-free.
    nonisolated static func registerDefaultsOnce() { _ = registerToken }

    private nonisolated static let registerToken: Void = {
        for spec in AgentDefinitions.pipeline {
            register(name: spec.name) { input in
                if spec.usesTools {
                    // Tool-calling path: `LocalLLM.chat` deliberately takes the
                    // bare message so the model can decide to invoke tools. But
                    // the bare mission alone strips conversation history + phase
                    // context — so follow-ups like "now do the same for the
                    // other folder" lose their antecedent on the one agent that
                    // actually runs terminal commands. Prepend both as a
                    // preamble; the model still sees a clear "Request:" line.
                    let h = input.history, c = input.context
                    let m: String
                    if h.isEmpty && c.isEmpty {
                        m = input.mission
                    } else {
                        var preamble = ""
                        if !h.isEmpty { preamble += "Prior conversation:\n\(h)\n\n" }
                        if !c.isEmpty { preamble += "Phase context:\n\(c)\n\n" }
                        m = preamble + "Request: \(input.mission)"
                    }
                    return await LocalLLM.chat(m)
                }
                if spec.isFinal {
                    // Stream the final answer. Build its prompt WITHOUT history and
                    // pass the (stable) conversation history as `cachePrefix` so it's
                    // cached — Anthropic as a cache_control block, Grok/OpenAI via
                    // server-side prefix caching, folded in for the rest — instead of
                    // re-sending the whole history inline on every turn.
                    let body = AgentPipeline.buildPrompt(spec: spec, mission: input.mission,
                                                         history: "", context: input.context)
                    return await LocalLLM.generateStreaming(body, maxTokens: 700,
                                                            cachePrefix: input.history) { partial in
                        input.onStream(partial)
                    }
                }
                let prompt = AgentPipeline.buildPrompt(spec: spec, mission: input.mission,
                                                       history: input.history, context: input.context)
                return await LocalLLM.generate(prompt, maxTokens: spec.full ? 700 : 110)
            }
        }
        return ()
    }()
}
