import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

/// On-device generation via Apple Intelligence (Foundation Models). Falls back
/// gracefully when Apple Intelligence isn't available.
enum LocalLLM {
    // All of these are `nonisolated` so actor-isolated callers (ChatSession,
    // AgentPipeline tasks, the Ollama-fallback path) can probe brain
    // availability without hopping to the main actor. The underlying APIs are
    // thread-safe — there's no shared mutable state behind any of them.
    nonisolated static var isAvailable: Bool {
        #if canImport(FoundationModels)
        if case .available = SystemLanguageModel.default.availability { return true }
        #endif
        return false
    }

    /// User's master switch from Settings (distinct from hardware availability).
    nonisolated static var isEnabledByUser: Bool { AppSettings.appleIntelligenceEnabled }

    /// Truly usable right now: the hardware supports it AND the user left it on.
    nonisolated static var isActive: Bool { isEnabledByUser && isAvailable }

    /// Shown when neither brain is reachable (Apple Intelligence off **and**
    /// Ollama unreachable). The pipeline now transparently falls back to
    /// Ollama qwen-coder when Apple Intelligence is off, so this only fires
    /// when there's no local model at all.
    nonisolated static let offMessage =
        "No model is reachable right now. Turn Apple Intelligence back on in Settings, or start the Ollama server (`ollama serve`) with qwen2.5-coder pulled."

    // `nonisolated` because actor-isolated callers (e.g. `ChatSession`) read
    // this for error messages. The underlying availability check is itself
    // thread-safe, so there's no shared state to guard.
    nonisolated static var statusNote: String {
        #if canImport(FoundationModels)
        switch SystemLanguageModel.default.availability {
        case .available: return "Apple Intelligence (on-device)"
        case .unavailable(let reason): return "fallback (Apple Intelligence unavailable: \(reason))"
        }
        #else
        return "fallback (Foundation Models SDK not present)"
        #endif
    }

    /// Identifies which brain handled (or would handle) a request. Used by the
    /// UI to label the current state honestly.
    enum Brain: Equatable { case appleIntelligence, ollamaCoder, none }

    /// Best brain available right now. Apple Intelligence wins when both
    /// enabled and hardware-available; otherwise we fall back to Ollama
    /// qwen-coder if the local server is up.
    static func currentBrain() async -> Brain {
        if isActive { return .appleIntelligence }
        if await OllamaClient.isUp(), await OllamaClient.hasModel(OllamaClient.codeModel) {
            return .ollamaCoder
        }
        return .none
    }

    /// Short label for the current brain, shown in the header subtitle.
    static func currentBrainLabel() async -> String {
        switch await currentBrain() {
        case .appleIntelligence: return "On-device · Apple Intelligence"
        case .ollamaCoder:       return "Local · Ollama qwen-coder"
        case .none:              return "No brain available"
        }
    }

    /// One-shot generation (no memory between calls). `maxTokens` caps the
    /// response length to keep terse agents fast.
    ///
    /// Fallback chain: Apple Intelligence (if enabled + available) → Ollama
    /// qwen-coder (if the local server is up) → off-message. The Ollama path
    /// ignores `maxTokens` since `/api/generate` doesn't expose a clean cap.
    static func generate(_ prompt: String, maxTokens: Int? = nil) async -> String {
        #if canImport(FoundationModels)
        if isActive {
            let session = LanguageModelSession()
            let options = GenerationOptions(maximumResponseTokens: maxTokens)
            if let response = try? await session.respond(to: prompt, options: options) {
                return response.content
            }
        }
        #endif
        if let reply = await OllamaClient.chat(prompt: prompt) { return reply }
        return offMessage
    }

    /// Streaming one-shot generation. Same Apple → Ollama → off fallback as
    /// `generate`, with `onUpdate` invoked for every cumulative chunk.
    static func generateStreaming(_ prompt: String, maxTokens: Int? = nil,
                                  onUpdate: @escaping (String) -> Void) async -> String {
        #if canImport(FoundationModels)
        if isActive {
            let session = LanguageModelSession()
            let options = GenerationOptions(maximumResponseTokens: maxTokens)
            var last = ""
            do {
                let stream = session.streamResponse(to: prompt, options: options)
                for try await snapshot in stream {
                    last = snapshot.content
                    onUpdate(last)
                }
                return last
            } catch {
                if !last.isEmpty { return last }
                // Fall through to Ollama on a clean failure (don't trap the user).
            }
        }
        #endif
        if let reply = await OllamaClient.chatStream(prompt: prompt, onUpdate: onUpdate) {
            return reply
        }
        let msg = offMessage
        onUpdate(msg)
        return msg
    }

    /// Multi-turn chat that remembers prior messages. Routes through the
    /// tool-enabled `ChatSession` when Apple Intelligence is active; otherwise
    /// falls back to Ollama qwen-coder *without* tools (the model can answer
    /// from knowledge, but can't run terminal commands or self-improve until
    /// you re-enable Apple Intelligence).
    static func chat(_ message: String) async -> String {
        if isActive {
            return await ChatSession.shared.respond(to: message)
        }
        let system = """
        You are Salehman AI, a helpful, concise, friendly assistant created by Saleh. \
        Apple Intelligence is off, so you cannot call tools (no terminal, no web \
        search, no self-improve) right now — just answer from your knowledge as \
        clearly and briefly as you can. If the user writes in Arabic, reply in \
        Arabic; otherwise reply in English. If a question really requires running \
        a command on this Mac, say so plainly and suggest the command as text.
        """
        if let reply = await OllamaClient.chat(prompt: message, system: system) {
            return reply
        }
        return offMessage
    }


    /// Start a fresh conversation (clears memory).
    static func resetChat() async {
        await ChatSession.shared.reset()
    }

    /// Result Synthesis Lead — a second pass that turns a working draft into a
    /// clear, friendly final answer. Preserves all facts and results.
    static func synthesize(userMessage: String, draft: String) async -> String {
        guard isAvailable else { return draft }
        let prompt = """
        You are the Result Synthesis Lead for Salehman AI. Rewrite the DRAFT
        answer so it responds to the user clearly, directly, and in a warm,
        concise tone. Keep ALL factual details, numbers, file paths, and command
        results from the draft. Do not invent anything new. If the draft already
        reads well, just lightly polish it. Reply in the user's language. Output
        ONLY the final answer, with no preamble.

        USER MESSAGE:
        \(userMessage)

        DRAFT:
        \(draft)

        FINAL ANSWER:
        """
        let refined = await generate(prompt)
        // If synthesis somehow failed (both brains unreachable), keep the draft.
        return refined == offMessage ? draft : refined
    }
}

/// Holds a persistent Foundation Models session so the assistant remembers
/// the conversation across turns. Isolated in an actor for safe concurrent use.
actor ChatSession {
    static let shared = ChatSession()

    /// Persona + behaviour rules. The live tool menu is appended at session-
    /// build time (see `currentInstructions()`) so disabled tools — e.g. web
    /// access switched off in Settings — are never advertised to the model.
    private static let baseInstructions = """
    You are Salehman AI, a helpful, concise, and friendly assistant created by Saleh.
    Answer the user's questions directly and clearly. Keep replies natural and to the point.
    If the user writes in Arabic, reply in Arabic; otherwise reply in English.

    IMPORTANT — answering vs. coding:
    • For ANY question about this Mac or its current state (macOS version, files,
      disk space, settings, running apps, etc.), you MUST call the
      run_terminal_command tool to get the REAL answer, then report it in plain
      words. Do NOT write code for the user to run, and do NOT guess.
    • Only write code when the user EXPLICITLY asks you to write or fix code.
    When you do write code: make it correct, complete, idiomatic, and modern
    (Swift/SwiftUI where relevant); handle errors and edge cases; add brief usage
    notes; never leave TODO placeholders; and show it in fenced code blocks.

    You can control the user's Mac terminal using the run_terminal_command tool.
    The computer runs macOS (Apple Silicon) with the zsh shell — NOT Linux.
    Always use macOS-native commands. Do NOT use Linux-only tools like systemctl,
    apt, gsettings, or xdg-open. Useful macOS equivalents:
      • Change wallpaper: osascript -e 'tell application "System Events" to set picture of every desktop to "/full/path/to/image.jpg"'
      • Open an app: open -a "Safari"   • Open a file/URL: open <path-or-url>
      • Read a setting: defaults read <domain> <key>
      • System info: sw_vers, system_profiler SPHardwareDataType
      • Notifications: osascript -e 'display notification "text" with title "Salehman AI"'
      • Volume: osascript -e 'set volume output volume 50'

    When the user asks you to do something on their computer, call
    run_terminal_command with the correct macOS command, then explain the result
    in plain language. If a command fails because it doesn't exist, figure out the
    correct macOS equivalent and try again instead of giving up. Never run
    destructive commands. After running a command, briefly summarize what happened.
    To run tests, use run_terminal_command with `xcodebuild test -scheme <name>`.
    """

    /// Persona + the live tool menu derived from `ToolPolicy`. Rebuilt every
    /// time a session is created so toggling web access (or any other gated
    /// tool) only requires starting a new chat.
    private static func currentInstructions() -> String {
        baseInstructions + "\n\nTools available to you right now:\n" + ToolPolicy.instructionsToolMenu()
    }

    #if canImport(FoundationModels)
    private var session: LanguageModelSession?
    #endif

    func reset() {
        #if canImport(FoundationModels)
        session = nil
        #endif
    }

    func respond(to message: String) async -> String {
        guard LocalLLM.isEnabledByUser else { return LocalLLM.offMessage }
        #if canImport(FoundationModels)
        guard case .available = SystemLanguageModel.default.availability else {
            return "[Apple Intelligence is not available — \(LocalLLM.statusNote). Enable it in System Settings → Apple Intelligence & Siri.]"
        }
        if session == nil {
            session = LanguageModelSession(tools: ToolPolicy.activeTools(),
                                           instructions: Self.currentInstructions())
        }
        guard let session else { return "[Could not start a chat session.]" }
        do {
            let response = try await session.respond(to: message)
            return response.content
        } catch {
            // A fresh session can recover from context/length errors.
            self.session = LanguageModelSession(tools: ToolPolicy.activeTools(),
                                                instructions: Self.currentInstructions())
            if let retry = try? await self.session?.respond(to: message) {
                return retry.content
            }
            return "[The on-device model couldn't complete that request: \(error.localizedDescription)]"
        }
        #else
        return "[Foundation Models SDK not present on this system.]"
        #endif
    }
}
