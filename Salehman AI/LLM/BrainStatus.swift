import SwiftUI
import Combine

/// Live, MainActor-observable reading of which brain (Apple Intelligence / Ollama
/// qwen-coder / none) is currently answering. The header subtitle and any other
/// UI that wants to show "where is the response coming from" reads from this
/// singleton instead of guessing from a static setting.
///
/// Refresh strategy:
/// * Polled every `pollInterval` seconds (cheap — `OllamaClient` already
///   memoizes reachability for 30s, so the call is mostly a Swift task hop).
/// * Refreshed immediately whenever the user flips Apple Intelligence in
///   Settings (`AppSettings.useAppleIntelligence`).
/// * Refreshable on demand via `refresh()` (call after a model send fails).
@MainActor
final class BrainStatus: ObservableObject {
    static let shared = BrainStatus()

    @Published private(set) var brain: LocalLLM.Brain = .none
    @Published private(set) var label: String = "Checking…"
    /// `true` iff the Ollama server is reachable AND `qwen2.5vl` is pulled.
    /// Lets the UI show a passive "vision ready" affordance without each call
    /// site having to re-probe Ollama.
    @Published private(set) var hasVision: Bool = false
    /// `true` iff the user has stored an xAI Grok API key in the Keychain.
    /// Cheap to read (Keychain lookup, no network), so we publish it for the
    /// Settings UI's live "Ready" indicator without needing a probe round-trip.
    @Published private(set) var hasGrokKey: Bool = false

    private var timer: Timer?
    private var cancellables: Set<AnyCancellable> = []
    private let pollInterval: TimeInterval = 10

    private init() {
        startPolling()
        observeSettings()
        Task { await refresh() }
    }

    /// Re-read the brain state right now. Cheap — `OllamaClient`'s 30s cache
    /// means at most one HTTP round-trip every half-minute. We probe the three
    /// independent signals in parallel via `async let` so the vision probe
    /// doesn't serialize behind the brain probe.
    func refresh() async {
        async let nextBrain = LocalLLM.currentBrain()
        async let nextLabel = LocalLLM.currentBrainLabel()
        async let nextVision = Self.probeVision()
        let (b, l, v) = await (nextBrain, nextLabel, nextVision)
        // `hasGrokKey` is a sync Keychain lookup — no need to schedule it
        // alongside the async probes.
        let g = GrokClient.hasKey()
        if b != brain { brain = b }
        if l != label { label = l }
        if v != hasVision { hasVision = v }
        if g != hasGrokKey { hasGrokKey = g }
    }

    /// Whether the local vision model is reachable. Two-step probe (server up,
    /// then model pulled) wrapped in its own function because the `&&` operator
    /// can't auto-thread `await` between two async expressions.
    nonisolated private static func probeVision() async -> Bool {
        guard await OllamaClient.isUp() else { return false }
        return await OllamaClient.hasModel(OllamaClient.visionModel)
    }

    /// Color hint for the status dot. Green when Apple Intelligence is driving,
    /// blue when the Ollama fallback is, orange when nothing's reachable.
    var dotColor: Color {
        switch brain {
        case .appleIntelligence: return .green
        case .ollamaCoder:       return Color(red: 0.4,  green: 0.7,  blue: 1.0)
        case .salehman:          return DS.Palette.accent                          // the brand's own model
        case .unslothStudio:     return Color(red: 0.45, green: 0.85, blue: 0.55)  // Studio green — local + your weights

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
        case .none:              return .orange
        }
    }

    /// Foreground color for the subtitle — secondary except when nothing's
    /// reachable, where we soften the warning instead of shouting it.
    var labelColor: Color {
        brain == .none ? Color.orange.opacity(0.9) : .secondary
    }

    private func startPolling() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: pollInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in await self?.refresh() }
        }
    }

    private func observeSettings() {
        // Refresh immediately when either of the two switches that affect
        // brain selection moves — without these, the header label sits stale
        // until the next 10s poll tick.
        AppSettings.shared.$useAppleIntelligence
            .removeDuplicates()
            .sink { [weak self] _ in Task { await self?.refresh() } }
            .store(in: &cancellables)
        AppSettings.shared.$brainPreference
            .removeDuplicates()
            .sink { [weak self] _ in Task { await self?.refresh() } }
            .store(in: &cancellables)
        AppSettings.shared.$grokModel
            .removeDuplicates()
            .sink { [weak self] _ in Task { await self?.refresh() } }
            .store(in: &cancellables)
    }

    deinit {
        timer?.invalidate()
    }
}
