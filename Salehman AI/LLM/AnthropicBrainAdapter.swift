//  AnthropicBrainAdapter.swift
//  Salehman AI

import Foundation

/// BrainAdapter that routes completions through AnthropicClient (Claude Haiku).
struct AnthropicBrainAdapter: BrainAdapter {
    var id: BrainPreference { .claudeHaiku }
    var isConfigured: Bool { AnthropicClient.isConfigured }

    func complete(messages: [LLMMessage]) async throws -> String {
        let (system, prompt) = brainAdapterPrompt(from: messages)
        guard let reply = await AnthropicClient.chat(prompt: prompt, system: system) else {
            throw BrainError.unavailable
        }
        return reply
    }

    func stream(messages: [LLMMessage]) -> AsyncThrowingStream<String, Error> {
        let (system, prompt) = brainAdapterPrompt(from: messages)
        return AsyncThrowingStream { continuation in
            Task {
                let result = await AnthropicClient.chatStream(prompt: prompt, system: system) { partial in
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
