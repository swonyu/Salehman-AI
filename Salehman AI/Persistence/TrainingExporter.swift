//  TrainingExporter.swift
//  Salehman AI

import Foundation
import AppKit
import UniformTypeIdentifiers

/// Exports the chat history as a JSONL fine-tuning dataset in ChatML format,
/// compatible with Unsloth, axolotl, and most modern SFT trainers.
///
/// Each line is one training example:
///   {"messages": [{"role":"system","content":"…"},
///                 {"role":"user","content":"…"},
///                 {"role":"assistant","content":"…"}]}
///
/// Pair construction: every consecutive user→assistant exchange in the chat
/// history becomes one training example. The Salehman system prompt is
/// prepended to each example so the fine-tuned model inherits the persona.
enum TrainingExporter {

    struct Stats {
        let examples: Int
        let skipped: Int
        let bytes: Int
    }

    /// Build the JSONL string from a message list. Returns the content and stats.
    nonisolated static func jsonl(from messages: [ChatMessage]) -> (String, Stats) {
        let system = LocalLLM.cloudSystemPromptBase  // static, nonisolated
        var lines: [String] = []
        var skipped = 0
        var i = 0
        while i < messages.count - 1 {
            let a = messages[i]
            let b = messages[i + 1]
            guard a.isUser, !b.isUser else { i += 1; continue }
            let userText = a.text.trimmingCharacters(in: .whitespacesAndNewlines)
            let assistantText = b.text.trimmingCharacters(in: .whitespacesAndNewlines)
            // Skip very short or error-sentinel exchanges — they add noise.
            guard userText.count >= 10, assistantText.count >= 10,
                  !assistantText.hasPrefix("["),
                  !assistantText.contains("request failed") else {
                skipped += 1; i += 2; continue
            }
            let example: [String: Any] = [
                "messages": [
                    ["role": "system",    "content": system],
                    ["role": "user",      "content": userText],
                    ["role": "assistant", "content": assistantText],
                ]
            ]
            if let data = try? JSONSerialization.data(withJSONObject: example),
               let line = String(data: data, encoding: .utf8) {
                lines.append(line)
            }
            i += 2
        }
        let jsonl = lines.joined(separator: "\n")
        return (jsonl, Stats(examples: lines.count, skipped: skipped, bytes: jsonl.utf8.count))
    }

    /// Show a save-panel and write the JSONL file. Must be called on the main actor.
    @MainActor static func savePanel(messages: [ChatMessage]) {
        let (content, stats) = jsonl(from: messages)
        guard stats.examples > 0 else {
            let alert = NSAlert()
            alert.messageText = "No training examples"
            alert.informativeText = "The conversation doesn't have enough user/assistant pairs yet."
            alert.runModal()
            return
        }

        let panel = NSSavePanel()
        panel.title = "Export Training Data"
        panel.nameFieldStringValue = "salehman_training.jsonl"
        panel.allowedContentTypes = [.init(filenameExtension: "jsonl")!]
        panel.message = "\(stats.examples) examples · \(stats.skipped) skipped · \(stats.bytes / 1024) KB"

        guard panel.runModal() == .OK, let url = panel.url else { return }
        try? content.write(to: url, atomically: true, encoding: .utf8)
    }
}

// Allow constructing a UTType from a file extension without crashing when
// the extension isn't in the system's type database. The force-unwrap above
// is safe for "jsonl" on macOS 12+ which always resolves custom extensions.
