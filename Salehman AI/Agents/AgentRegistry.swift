import Foundation

/// Per-agent execution input. Immutable + Sendable so handlers can run inside the
/// pipeline's concurrent task group without sharing mutable state.
struct AgentInput: Sendable {
    let mission: String
    let history: String
    let context: String     // built from MissionMemory.buildContext(...)
    let onStream: (@Sendable (String) -> Void)?
}

/// Registry of agent handlers. Each handler turns an `AgentInput` into that
/// agent's output. Registered once from `AgentDefinitions.pipeline`; the pipeline
/// looks handlers up by name and runs them concurrently. Recording into
/// `MissionMemory` is done by the pipeline coordinator (never inside a handler),
/// so there is no shared mutable state across the concurrent tasks.
struct AgentRegistry {

    typealias AgentHandler = @Sendable (_ input: AgentInput) async -> String

    // Registration happens once, before any concurrent reads — safe to mark unsafe.
    nonisolated(unsafe) private static var handlers: [String: AgentHandler] = [:]
    nonisolated(unsafe) private static var didRegister = false

    static func register(name: String, handler: @escaping AgentHandler) {
        guard handlers[name] == nil else { return }
        handlers[name] = handler
    }

    static func handler(for name: String) -> AgentHandler? { handlers[name] }

    static func isRegistered(_ name: String) -> Bool { handlers[name] != nil }

    static func registeredAgents() -> [String] { handlers.keys.sorted() }

    /// Register a handler for every agent in the team. Each handler captures its
    /// spec and picks the right LocalLLM call (tools / streamed final / terse note).
    static func registerDefaultsOnce() {
        guard !didRegister else { return }
        didRegister = true
        for spec in AgentDefinitions.pipeline {
            register(name: spec.name) { input in
                if spec.usesTools {
                    return await LocalLLM.chat(input.mission)
                }
                let prompt = AgentPipeline.buildPrompt(spec: spec, mission: input.mission,
                                                       history: input.history, context: input.context)
                if spec.isFinal {
                    return await LocalLLM.generateStreaming(prompt, maxTokens: 700) { partial in
                        input.onStream?(partial)
                    }
                }
                return await LocalLLM.generate(prompt, maxTokens: spec.full ? 700 : 110)
            }
        }
    }
}
