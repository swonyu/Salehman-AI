//  BrainAdapter.swift
//  Salehman AI

import Foundation

/// Minimal typed message for BrainAdapter. Mirrors the role/content shape the existing
/// cloud clients build as [String: Any] dicts, but gives call sites a type-safe handle.
struct LLMMessage: Sendable {
    enum Role: String, Sendable { case system, user, assistant }
    let role: Role
    let content: String
}

/// Abstraction over any LLM backend — local (MLX, Ollama) or remote (cloud keys).
/// No existing code is required to conform yet; defined here for staged adoption.
protocol BrainAdapter: Sendable {
    var id: BrainPreference { get }
    var isConfigured: Bool { get }
    func complete(messages: [LLMMessage]) async throws -> String
    func stream(messages: [LLMMessage]) -> AsyncThrowingStream<String, Error>
}

enum BrainError: Error {
    case unavailable
}

/// Extracts the optional system prompt and flattens remaining turns into a single
/// prompt string compatible with single-turn completion APIs (OllamaClient, AnthropicClient).
func brainAdapterPrompt(from messages: [LLMMessage]) -> (system: String?, prompt: String) {
    let system = messages.first(where: { $0.role == .system })?.content
    let body = messages.filter { $0.role != .system }
    let prompt = body.count == 1
        ? body[0].content
        : body.map { "\($0.role.rawValue.capitalized): \($0.content)" }.joined(separator: "\n")
    return (system, prompt)
}

/// Maps a `LocalLLM.Brain` to the right `BrainAdapter`. Returns a dedicated adapter
/// for Ollama and Anthropic; all other brains get `LocalLLMFallbackAdapter`, which
/// delegates to `LocalLLM.generate()`. Adding a new brain never requires touching
/// AgentPipeline — only a new adapter struct and a case here.
enum BrainAdapterFactory {
    nonisolated static func adapter(for brain: LocalLLM.Brain) -> any BrainAdapter {
        switch brain {
        case .ollamaCoder:  return OllamaBrainAdapter()
        case .claudeHaiku:  return AnthropicBrainAdapter()
        default:
            return LocalLLMFallbackAdapter(id: AppSettings.brainPreferenceCurrent)
        }
    }
}

/// Catch-all adapter: delegates to `LocalLLM.generate()` for every brain type that
/// doesn't have a dedicated adapter yet. Keeps AgentPipeline free of direct
/// `LocalLLM.generate()` calls while staged adoption continues.
private struct LocalLLMFallbackAdapter: BrainAdapter {
    let id: BrainPreference
    var isConfigured: Bool { LocalLLM.isAvailable }

    func complete(messages: [LLMMessage]) async throws -> String {
        let (_, prompt) = brainAdapterPrompt(from: messages)
        let reply = await LocalLLM.generate(prompt)
        if reply == LocalLLM.offMessage { throw BrainError.unavailable }
        return reply
    }

    func stream(messages: [LLMMessage]) -> AsyncThrowingStream<String, Error> {
        let (_, prompt) = brainAdapterPrompt(from: messages)
        return AsyncThrowingStream { continuation in
            Task {
                let reply = await LocalLLM.generate(prompt)
                if reply == LocalLLM.offMessage {
                    continuation.finish(throwing: BrainError.unavailable)
                } else {
                    continuation.yield(reply)
                    continuation.finish()
                }
            }
        }
    }
}
