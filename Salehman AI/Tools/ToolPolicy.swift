import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

/// Single source of truth for which tools the chat agent gets in a given
/// session. Reads only `nonisolated` settings so the actor-isolated ChatSession
/// can call it without hopping to the main actor.
///
/// External tools (web, paid/network APIs) are gated behind user settings;
/// local-only tools (terminal, memory, on-device image, self-improve) are
/// always available.
enum ToolPolicy {

    // MARK: - Active tool list

    #if canImport(FoundationModels)
    /// The tools to hand to a fresh `LanguageModelSession`. Settings changes
    /// take effect on the next session — call `ChatSession.reset()` (or start a
    /// new chat) for the new policy to apply mid-conversation.
    static func activeTools() -> [any Tool] {
        var tools: [any Tool] = []

        // Always-on, local-only.
        tools.append(RunTerminalCommandTool())   // gated separately by CommandApprovalCenter
        tools.append(RememberFactTool())
        tools.append(TranslateTool())
        tools.append(ControlMacTool())
        tools.append(GenerateImageTool())        // on-device Image Playground
        tools.append(SelfImproveTool())          // edits THIS project's source

        // External web access — only when the user enables it in Settings.
        if isWebAccessEnabled {
            tools.append(WebSearchTool())
            tools.append(FetchURLTool())
        }

        // Heavyweight local coding model (Ollama qwen-coder). Off by default on
        // smaller Macs; the tool itself also short-circuits, but excluding it
        // from the schema keeps the model from advertising a capability it
        // doesn't actually have.
        if isCodeModelEnabled {
            tools.append(WriteCodeTool())
        }

        return tools
    }
    #endif

    // MARK: - Instructions hint

    /// Short, human-readable summary of the *currently enabled* tools. Inject
    /// into the chat instructions so the model doesn't promise web access (or
    /// any other gated tool) when the user has it turned off.
    static func instructionsToolMenu() -> String {
        var lines: [String] = []
        lines.append("• run_terminal_command — run a macOS shell command (asks the user before risky ones).")
        lines.append("• remember_fact — save durable facts about the user.")
        lines.append("• translate — translate text between languages.")
        lines.append("• control_mac — move/click the mouse, type, or press keys (Accessibility permission).")
        lines.append("• generate_image — on-device Image Playground.")
        lines.append("• self_improve — build THIS app's Xcode project and try to auto-fix compiler errors.")
        if isWebAccessEnabled {
            lines.append("• web_search — search the web (DuckDuckGo).")
            lines.append("• fetch_url — read a specific web page.")
        } else {
            lines.append("• Web access is DISABLED in Settings — do not promise to search or fetch URLs.")
        }
        if isCodeModelEnabled {
            lines.append("• write_code — delegate hard coding work to the local qwen2.5-coder model.")
        }
        return lines.joined(separator: "\n")
    }

    // MARK: - Setting accessors (nonisolated, actor-safe)

    nonisolated static var isWebAccessEnabled: Bool {
        AppSettings.boolDefaultTrue(AppSettings.Keys.webAccess)
    }

    nonisolated static var isCodeModelEnabled: Bool {
        AppSettings.boolDefaultTrue(AppSettings.Keys.codeModel)
    }
}
