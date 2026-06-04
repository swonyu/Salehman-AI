import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

/// On-device generation via Apple Intelligence (Foundation Models). Falls back
/// gracefully when Apple Intelligence isn't available.
enum LocalLLM {
    static var isAvailable: Bool {
        #if canImport(FoundationModels)
        if case .available = SystemLanguageModel.default.availability { return true }
        #endif
        return false
    }

    /// User's master switch from Settings (distinct from hardware availability).
    /// `nonisolated` so the model layer can read it off the main actor.
    nonisolated static var isEnabledByUser: Bool { AppSettings.appleIntelligenceEnabled }

    /// Truly usable right now: the hardware supports it AND the user left it on.
    static var isActive: Bool { isEnabledByUser && isAvailable }

    /// Shown whenever the user has switched Apple Intelligence off.
    nonisolated static let offMessage =
        "Apple Intelligence is turned off in Settings. Turn it back on to get AI replies — vision, transcription and dictation still work while it's off."

    static var statusNote: String {
        #if canImport(FoundationModels)
        switch SystemLanguageModel.default.availability {
        case .available: return "Apple Intelligence (on-device)"
        case .unavailable(let reason): return "fallback (Apple Intelligence unavailable: \(reason))"
        }
        #else
        return "fallback (Foundation Models SDK not present)"
        #endif
    }

    /// One-shot generation (no memory between calls). `maxTokens` caps the
    /// response length to keep terse agents fast.
    static func generate(_ prompt: String, maxTokens: Int? = nil) async -> String {
        guard isEnabledByUser else { return offMessage }
        #if canImport(FoundationModels)
        if case .available = SystemLanguageModel.default.availability {
            let session = LanguageModelSession()
            let options = GenerationOptions(maximumResponseTokens: maxTokens)
            if let response = try? await session.respond(to: prompt, options: options) {
                return response.content
            }
        }
        #endif
        return "[no on-device model available — \(statusNote)]"
    }

    /// Streaming one-shot generation. Calls `onUpdate` with the cumulative text
    /// as it is produced, and returns the final text.
    static func generateStreaming(_ prompt: String, maxTokens: Int? = nil,
                                  onUpdate: @escaping (String) -> Void) async -> String {
        guard isEnabledByUser else { onUpdate(offMessage); return offMessage }
        #if canImport(FoundationModels)
        if case .available = SystemLanguageModel.default.availability {
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
                return last.isEmpty ? "[The model couldn't complete that: \(error.localizedDescription)]" : last
            }
        }
        #endif
        return "[no on-device model available — \(statusNote)]"
    }

    /// Multi-turn chat that remembers prior messages in the conversation.
    static func chat(_ message: String) async -> String {
        return await ChatSession.shared.respond(to: message)
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
        // If synthesis somehow failed, fall back to the draft.
        return refined.hasPrefix("[no on-device model") ? draft : refined
    }
}

/// Holds a persistent Foundation Models session so the assistant remembers
/// the conversation across turns. Isolated in an actor for safe concurrent use.
actor ChatSession {
    static let shared = ChatSession()

    private static let instructions = """
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

    You can also access the internet:
    • web_search — for current, recent, or factual info beyond your knowledge.
    • fetch_url — to read a specific web page or public social-media page.
    Use them whenever up-to-date information would help, then cite what you found.
    To open a social app or site for the user, use run_terminal_command with
    `open` (e.g. open -a "Safari" https://twitter.com, or open -a "Instagram").

    More tools you have:
    • generate_image — create a picture when the user asks you to draw/generate one.
    • remember_fact — save durable facts about the user (name, preferences,
      projects). Do this whenever you learn something worth remembering.
    • translate — translate text to another language accurately.
    • control_mac — move/click the mouse, type, or press keys to automate or test
      the UI (asks for Accessibility permission the first time).
    • self_improve — build THIS app's Xcode project, find compiler errors, and
      try to fix them automatically. Call this when the user asks you to test,
      build, fix, debug, or improve yourself. Reports back what changed.
    To run tests, use run_terminal_command with `xcodebuild test -scheme <name>`.
    """

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
            session = LanguageModelSession(tools: [RunTerminalCommandTool(), WriteCodeTool(), WebSearchTool(), FetchURLTool(), GenerateImageTool(), RememberFactTool(), ControlMacTool(), TranslateTool(), SelfImproveTool()], instructions: Self.instructions)
        }
        guard let session else { return "[Could not start a chat session.]" }
        do {
            let response = try await session.respond(to: message)
            return response.content
        } catch {
            // A fresh session can recover from context/length errors.
            self.session = LanguageModelSession(tools: [RunTerminalCommandTool(), WriteCodeTool(), WebSearchTool(), FetchURLTool(), GenerateImageTool(), RememberFactTool(), ControlMacTool(), TranslateTool(), SelfImproveTool()], instructions: Self.instructions)
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
