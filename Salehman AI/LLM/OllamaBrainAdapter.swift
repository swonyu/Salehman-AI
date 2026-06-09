//  OllamaBrainAdapter.swift
//  Salehman AI

import Foundation

/// BrainAdapter that routes completions through the local Ollama server.
/// `isConfigured` is always true — dynamic reachability is the server being up,
/// not a static API-key flag; `OllamaClient.chat` returns nil when the server
/// is unreachable, which `complete` converts to `BrainError.unavailable`.
struct OllamaBrainAdapter: BrainAdapter {
    var id: BrainPreference { .ollama }
    var isConfigured: Bool { true }

    func complete(messages: [LLMMessage]) async throws -> String {
        let (system, prompt) = brainAdapterPrompt(from: messages)
        guard let reply = await OllamaClient.chat(prompt: prompt, system: system) else {
            throw BrainError.unavailable
        }
        return reply
    }

    func stream(messages: [LLMMessage]) -> AsyncThrowingStream<String, Error> {
        let (system, prompt) = brainAdapterPrompt(from: messages)
        return AsyncThrowingStream { continuation in
            Task {
                let result = await OllamaClient.chatStream(prompt: prompt, system: system) { partial in
                    continuation.yield(partial)
                }
                if result == nil {
                    continuation.finish(throwing: BrainError.unavailable)
                } else {
                    continuation.finish()
                }
            }
        }
    }
}
