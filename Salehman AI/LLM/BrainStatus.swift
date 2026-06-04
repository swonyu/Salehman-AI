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

    private var timer: Timer?
    private var cancellables: Set<AnyCancellable> = []
    private let pollInterval: TimeInterval = 10

    private init() {
        startPolling()
        observeSettings()
        Task { await refresh() }
    }

    /// Re-read the brain state right now. Cheap — `OllamaClient`'s 30s cache
    /// means at most one HTTP round-trip every half-minute.
    func refresh() async {
        let next = await LocalLLM.currentBrain()
        let nextLabel = await LocalLLM.currentBrainLabel()
        if next != brain { brain = next }
        if nextLabel != label { label = nextLabel }
    }

    /// Color hint for the status dot. Green when Apple Intelligence is driving,
    /// blue when the Ollama fallback is, orange when nothing's reachable.
    var dotColor: Color {
        switch brain {
        case .appleIntelligence: return .green
        case .ollamaCoder:       return Color(red: 0.4, green: 0.7, blue: 1.0)
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
        AppSettings.shared.$useAppleIntelligence
            .removeDuplicates()
            .sink { [weak self] _ in Task { await self?.refresh() } }
            .store(in: &cancellables)
    }

    deinit {
        timer?.invalidate()
    }
}
