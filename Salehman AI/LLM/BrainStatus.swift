import SwiftUI
import Combine

/// Live, MainActor-observable reading of which brain (Salehman cloud / Ollama
/// qwen-coder / a cloud brain / none) is currently answering. The header subtitle
/// and any other UI that wants to show "where is the response coming from" reads
/// from this singleton instead of guessing from a static setting.
///
/// Refresh strategy:
/// * Polled every `pollInterval` seconds (cheap — `OllamaClient` already
///   memoizes reachability for 30s, so the call is mostly a Swift task hop).
/// * Refreshed immediately whenever the user changes the brain preference.
/// * Refreshable on demand via `refresh()` (call after a model send fails).
@MainActor
final class BrainStatus: ObservableObject {
    static let shared = BrainStatus()

    @Published private(set) var brain: LocalLLM.Brain = .none
    @Published private(set) var label: String = "Checking…"

    private var timer: Timer?
    private var cancellables: Set<AnyCancellable> = []
    private let pollInterval: TimeInterval = 10

    private init() {
        startPolling()
        observeSettings()
        Task { await refresh() }
    }

    /// Re-read the brain state right now. Cheap — `OllamaClient`'s 30s cache
    /// means at most one HTTP round-trip every half-minute. The two signals are
    /// probed in parallel via `async let`.
    func refresh() async {
        async let nextBrain = LocalLLM.currentBrain()
        async let nextLabel = LocalLLM.currentBrainLabel()
        let (b, l) = await (nextBrain, nextLabel)
        if b != brain { brain = b }
        if l != label { label = l }
    }

    /// Color hint for the status dot. Blue when the Ollama brain is driving,
    /// brand accent for Salehman, orange when nothing's reachable.
    var dotColor: Color {
        switch brain {
        case .ollamaCoder:       return Color(red: 0.4,  green: 0.7,  blue: 1.0)
        case .salehman:          return DS.Palette.accent                          // the brand's own model
        case .unslothStudio:     return Color(red: 0.45, green: 0.85, blue: 0.55)  // Studio green — local + your weights
        case .vllm:              return Color(red: 0.20, green: 0.78, blue: 0.90)  // vLLM cyan — local high-throughput
        case .uncensored:        return Color(red: 0.90, green: 0.30, blue: 0.45)  // uncensored crimson — unfiltered local

        case .claudeHaiku:       return Color(red: 0.82, green: 0.55, blue: 0.42)  // Claude terracotta
        case .grok:              return Color(red: 0.55, green: 0.45, blue: 0.95)  // xAI violet
        case .gemini:            return Color(red: 0.30, green: 0.66, blue: 0.99)  // Google blue
        case .groq:              return Color(red: 0.95, green: 0.42, blue: 0.25)  // Groq orange
        case .mistral:           return Color(red: 1.00, green: 0.55, blue: 0.10)  // Mistral amber
        case .cerebras:          return Color(red: 0.75, green: 0.30, blue: 0.95)  // Cerebras magenta
        case .codex:             return Color(red: 0.10, green: 0.74, blue: 0.59)  // OpenAI teal
        case .copilot:           return Color(red: 0.42, green: 0.42, blue: 0.42)  // GitHub neutral
        case .openRouter:        return Color(red: 0.36, green: 0.52, blue: 0.96)  // OpenRouter indigo
        case .ensemble:          return Color(red: 0.55, green: 0.85, blue: 0.40)  // multi-brain lime
        case .freeAuto:          return Color(red: 0.20, green: 0.85, blue: 0.65)  // free-auto mint (unlimited)
        case .freeCoding:        return Color(red: 0.62, green: 0.40, blue: 0.95)  // FreeCoding violet
        case .cloudCoding:       return Color(red: 0.40, green: 0.62, blue: 1.00)  // Cloud Coding sky-blue
        case .none:              return .orange
        }
    }

    /// SF Symbol identifying the active brain — lets the header show *which*
    /// brain is driving as a glyph instead of a text label.
    var symbol: String {
        switch brain {
        case .ollamaCoder:       return "chevron.left.forwardslash.chevron.right"
        case .salehman:          return "crown.fill"
        case .unslothStudio:     return "cpu"
        case .vllm:              return "bolt.horizontal.fill"
        case .uncensored:        return "eye.trianglebadge.exclamationmark.fill"
        case .claudeHaiku:       return "a.square.fill"
        case .grok:              return "bolt.fill"
        case .gemini:            return "sparkle"
        case .groq:              return "hare.fill"
        case .mistral:           return "wind"
        case .cerebras:          return "cpu.fill"
        case .codex:             return "terminal.fill"
        case .copilot:           return "person.2.fill"
        case .openRouter:        return "arrow.triangle.branch"
        case .ensemble:          return "circle.grid.2x2.fill"
        case .freeAuto:          return "infinity"
        case .freeCoding:        return "curlybraces"
        case .cloudCoding:       return "cloud.fill"
        case .none:              return "exclamationmark.triangle.fill"
        }
    }

    private func startPolling() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: pollInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in await self?.refresh() }
        }
    }

    private func observeSettings() {
        // Refresh immediately when the brain preference moves — without this, the
        // header label sits stale until the next 10s poll tick.
        AppSettings.shared.$brainPreference
            .removeDuplicates()
            .sink { [weak self] _ in Task { await self?.refresh() } }
            .store(in: &cancellables)
        AppSettings.shared.$grokModel
            .removeDuplicates()
            .sink { [weak self] _ in Task { await self?.refresh() } }
            .store(in: &cancellables)
    }

    // `isolated deinit` (SE-0371) so teardown runs on the MainActor and may touch
    // the non-Sendable `Timer?`. A nonisolated deinit can't under Swift 6.
    isolated deinit {
        timer?.invalidate()
    }
}
