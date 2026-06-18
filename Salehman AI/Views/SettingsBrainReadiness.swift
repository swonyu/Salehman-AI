import Foundation

// MARK: - Settings brain-readiness (pure seam)
//
// Extracted from `SettingsView.brainReady` (CODEBASE_REVIEW HIGH perf item):
// the old switch fired live engine probes per visible grid cell on EVERY
// Settings body recompute. The view already tracks every signal in cached
// @State flags (kept current by the Save / Clear bindings and the 5s poll);
// this file is the pure classification those flags feed. No syscalls, no UI.
//
// Local-only build (2026-06-18): all cloud providers + composite modes were
// removed, so this seam classifies just the six local brains.

/// One snapshot of every signal brain readiness depends on. Build it from
/// the view's cached flags (plain Bool copies), then ask `ready(_:)`.
struct BrainReadiness {
    // Local engine signals (polled by the Settings `.task`).
    var ollamaUp = false
    /// Any qwen2.5-coder pulled — the `.auto`/`.ollama` floor.
    var hasCoder = false
    /// `settings.customModelName` is non-blank — the `.salehman` local floor.
    var customModelNamed = false
    /// The abliterated ~3B uncensored model is pulled — the `.uncensored` floor.
    var hasUncensored = false

    // Endpoint-configured engines (UserDefaults-backed, no Keychain).
    var unslothConfigured = false
    var vllmConfigured = false

    /// Local default-brain floor: Ollama up AND serving a coder model.
    var localFloor: Bool { ollamaUp && hasCoder }

    /// Mirrors `SalehmanEngine.hasAnyCloud` (always false) — local endpoint
    /// engines only. Salehman is pure local-first; no cloud is ever contacted.
    var salehmanAnyCloud: Bool { vllmConfigured || unslothConfigured }

    /// Whether `pref` is reachable right now. Local-only: every brain resolves
    /// to a local engine. If reachability rules change, change them HERE (the
    /// view is a thin caller) and pin the new rule in `SettingsBrainReadyTests`.
    func ready(_ pref: BrainPreference) -> Bool {
        switch pref {
        case .auto:        return localFloor
        case .ollama:      return localFloor
        // Salehman is LOCAL-FIRST: vLLM or Unsloth endpoint configured, or
        // the user's own Ollama model (named + server up).
        case .salehman:    return salehmanAnyCloud || (ollamaUp && customModelNamed)
        case .unslothStudio: return unslothConfigured
        case .vllm:        return vllmConfigured
        // Uncensored is local-only: Ollama up AND the abliterated model pulled.
        case .uncensored:  return ollamaUp && hasUncensored
        }
    }
}

// MARK: - Active-brain probe (overlapping "is it working" runs)

/// Value model of the overlapping `testActiveBrain()` runs. Three triggers
/// (.task poll, brain-switch onChange, refresh button) can overlap at the
/// network await; the rules this type owns:
///   · the spinner (`testing`) is "any run live" — it clears only when the
///     LAST in-flight run exits (a superseded run's exit must not strand a
///     stuck-on spinner, nor clear it under a live successor);
///   · only a run whose brain pin still matches at the end publishes its
///     verdict — superseded runs exit silently (no stale brain's verdict).
struct ActiveBrainProbe {
    private(set) var inFlight = 0
    private(set) var working: Bool? = nil

    /// "Any run live" — drives the spinner + disables the refresh button.
    var testing: Bool { inFlight > 0 }

    /// A run enters: spinner on, stale verdict cleared.
    mutating func begin() {
        inFlight += 1
        working = nil
    }

    /// A run exits. Superseded runs (the user switched brains mid-await)
    /// decrement their flight without publishing the stale verdict.
    mutating func finish(verdict: Bool, superseded: Bool) {
        inFlight = max(0, inFlight - 1)
        if !superseded { working = verdict }
    }

    /// Brain switched without an auto-test: the shown verdict belongs to the
    /// previous brain — clear it.
    mutating func invalidate() { working = nil }
}

// MARK: - Ping-reply verdict

/// Classifies a one-token "ping" reply as working / not working. Pure so the
/// rule is testable without a brain: empty replies and the `offMessage`
/// sentinel both fail.
enum BrainPing {
    static func verdict(reply: String, offMessage: String) -> Bool {
        let trimmed = reply.trimmingCharacters(in: .whitespacesAndNewlines)
        return !(trimmed.isEmpty || reply == offMessage)
    }
}
