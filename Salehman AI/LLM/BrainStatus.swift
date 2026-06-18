import SwiftUI
import Combine

/// Live, MainActor-observable reading of which local brain (Salehman / Ollama
/// qwen-coder / Unsloth Studio / vLLM / uncensored / none) is currently answering.
/// The header subtitle and any other UI that wants to show "where is the response
/// coming from" reads from this singleton instead of guessing from a static setting.
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
    /// brand accent for Salehman, and orange when nothing's reachable.
    var dotColor: Color {
        switch brain {
        case .ollamaCoder:       return Color(red: 0.4,  green: 0.7,  blue: 1.0)
        case .salehman:          return DS.Palette.accent                          // the brand's own model
        case .unslothStudio:     return Color(red: 0.45, green: 0.85, blue: 0.55)  // Studio green — local + your weights
        case .vllm:              return Color(red: 0.20, green: 0.78, blue: 0.90)  // vLLM cyan — local high-throughput
        case .uncensored:        return Color(red: 0.90, green: 0.30, blue: 0.45)  // uncensored crimson — unfiltered local
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
    }

    // `isolated deinit` (SE-0371) so teardown runs on the MainActor and may touch
    // the non-Sendable `Timer?`. A nonisolated deinit can't under Swift 6.
    isolated deinit {
        timer?.invalidate()
    }
}
