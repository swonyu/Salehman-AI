import Foundation
#if canImport(FoundationModels)
import FoundationModels

/// Lets the assistant delegate coding to the local qwen2.5-coder:32b model
/// (much stronger at code than the on-device Apple model). Falls back to the
/// caller's own answer if Ollama/the model isn't available.
struct WriteCodeTool: Tool {
    let name = "write_code"
    let description = """
    Generate or fix code using the specialized local coding model. Call this ONLY \
    when the user EXPLICITLY asks you to write, fix, refactor, or explain code. \
    Do NOT call this to answer questions about this Mac or its current state \
    (e.g. "what macOS version am I running?", "how much disk space", "what files \
    are here") — those are answered by running run_terminal_command and reporting \
    the real result in plain words, NOT by writing code. Pass a clear, \
    self-contained description of exactly what code is needed.
    """

    @Generable
    struct Arguments {
        @Guide(description: "A clear, complete description of the coding task, including language, requirements, and any relevant context or existing code.")
        var task: String
    }

    func call(arguments: Arguments) async throws -> String {
        let task = arguments.task.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !task.isEmpty else { return "No coding task provided." }
        guard AppSettings.boolDefaultTrue(AppSettings.Keys.codeModel) else {
            return "The local coding model is turned off in Settings. Write the best code you can yourself."
        }

        if let code = await OllamaClient.code(task: task) {
            return "Here is the code produced by the specialized coding model. Present it to the user clearly:\n\n\(code)"
        }
        return "The local coding model isn't available right now. Write the best code you can yourself, carefully and completely."
    }
}
#endif
