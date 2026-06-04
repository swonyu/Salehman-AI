import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

/// Controls whether external/non-local tools are allowed.
/// Default = .localOnly to maintain the local-first philosophy.
///
/// `current` is derived from the user's Settings toggles (web access, code
/// model) on each read, so flipping a switch and starting a new chat is enough
/// to retire or surface tools. Set it explicitly to force a mode for testing.
enum ToolPolicy {
    case localOnly
    case allowExternalTools

    /// Mutable override. `nil` (the default) means "read from user settings".
    /// Set to a concrete case to force-pin the policy regardless of settings.
    nonisolated(unsafe) static var override: ToolPolicy? = nil

    /// The policy in effect right now. Computed from `override` if set,
    /// otherwise from the user's web-access toggle in Settings.
    static var current: ToolPolicy {
        if let override { return override }
        return isWebAccessEnabled ? .allowExternalTools : .localOnly
    }

    // MARK: - Tool list

    #if canImport(FoundationModels)
    /// Tools to hand to a fresh `LanguageModelSession`. Settings changes take
    /// effect on the next session — call `ChatSession.reset()` (or start a new
    /// chat) for a new policy to apply mid-conversation.
    static func activeTools() -> [any Tool] {
        var tools: [any Tool] = []

        // Always-on, local-only core.
        tools.append(RunTerminalCommandTool())   // gated separately by CommandApprovalCenter
        tools.append(RememberFactTool())
        tools.append(TranslateTool())
        tools.append(ControlMacTool())
        tools.append(GenerateImageTool())        // on-device Image Playground
        tools.append(SelfImproveTool())          // edits THIS project's source only
        tools.append(StockAnalysisTool())        // offline Saudi/TASI heuristic analysis
        tools.append(TranscribeMediaTool())      // on-device audio/video transcription

        // Image understanding — only when the vision capability is enabled.
        if isVisionEnabled {
            tools.append(AnalyzeImageTool())
        }

        // External web access — only when the policy says so.
        if current == .allowExternalTools {
            tools.append(WebSearchTool())
            tools.append(FetchURLTool())
        }

        // Heavyweight local coding model (Ollama qwen-coder). The tool itself
        // also short-circuits when off, but excluding it from the schema keeps
        // the model from advertising a capability it doesn't actually have.
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
        lines.append("• analyze_stock — educational Saudi/TASI stock analysis (heuristic, NOT financial advice).")
        lines.append("• transcribe_media — transcribe a local audio/video file on-device.")
        if isVisionEnabled {
            lines.append("• analyze_image — describe a local image (scene, text, barcodes) on-device.")
        }
        if current == .allowExternalTools {
            lines.append("• web_search — search the web (DuckDuckGo).")
            lines.append("• fetch_url — read a specific web page.")
        } else {
            lines.append("• Web access is DISABLED — do NOT promise to search or fetch URLs.")
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

    nonisolated static var isVisionEnabled: Bool {
        AppSettings.boolDefaultTrue(AppSettings.Keys.vision)
    }
}
