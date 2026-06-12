import Foundation

// MARK: - Settings brain-readiness (pure seam)
//
// Extracted from `SettingsView.brainReady` (CODEBASE_REVIEW HIGH perf item):
// the old switch fired live Keychain `hasKey()` syscalls per visible grid
// cell on EVERY Settings body recompute — each keystroke and each 5s poll
// tick paid ~25+ SecItemCopyMatching calls (`.salehman` alone walked the
// whole 10-key `SalehmanEngine.hasAnyCloud` chain). The view already tracks
// every key's presence in cached @State flags (kept current by the Save /
// Clear bindings and the Copilot sign-in callback); this file is the pure
// classification those flags feed. No syscalls, no UI — hermetically pinned
// by `SettingsBrainReadyTests`.

/// One snapshot of every signal brain readiness depends on. Build it from
/// the view's cached flags (plain Bool copies), then ask `ready(_:)`.
struct BrainReadiness {
    // Local engine signals (polled by the Settings `.task`).
    var ollamaUp = false
    /// Any qwen2.5-coder pulled — the `.auto`/`.ollama` floor.
    var hasCoder = false
    /// `settings.customModelName` is non-blank — the `.salehman` local floor.
    var customModelNamed = false

    // Endpoint-configured engines (UserDefaults-backed, no Keychain).
    var unslothConfigured = false
    var vllmConfigured = false

    // Cloud key presence (Keychain-backed — these MUST come from the view's
    // cached flags, never live `hasKey()` reads; that is the extraction).
    var anthropic = false
    var grok = false
    var gemini = false
    var groq = false
    var mistral = false
    var cerebras = false
    var openAI = false
    var copilot = false
    var openRouter = false
    var nvidia = false

    /// Local default-brain floor: Ollama up AND serving a coder model.
    var localFloor: Bool { ollamaUp && hasCoder }

    /// FREE cloud keys only — the set `.freeAuto` is allowed to race.
    var anyFreeCloud: Bool { groq || gemini || cerebras || mistral || openRouter }

    /// The cloud coder pool shared by `.freeCoding` and `.cloudCoding`.
    var anyCloudCoder: Bool { groq || cerebras || mistral || openRouter }

    /// Mirrors `SalehmanEngine.hasAnyCloud` — local endpoint engines only.
    /// Salehman is pure local-first; cloud API keys are NOT checked.
    var salehmanAnyCloud: Bool { vllmConfigured || unslothConfigured }

    /// Whether `pref` is reachable right now. Exact behavior copy of the old
    /// `SettingsView.brainReady` switch — if reachability rules change,
    /// change them HERE (the view is a thin caller) and pin the new rule in
    /// `SettingsBrainReadyTests`.
    func ready(_ pref: BrainPreference) -> Bool {
        switch pref {
        case .auto:        return localFloor
        case .ollama:      return localFloor
        case .claudeHaiku: return anthropic
        case .grok:        return grok
        case .gemini:      return gemini
        case .groq:        return groq
        case .mistral:     return mistral
        case .cerebras:    return cerebras
        case .codex:       return openAI
        case .copilot:     return copilot
        case .openRouter:  return openRouter
        // Ensemble is "ready" if ANY brain is reachable — a local one or any
        // keyed cloud one. (NVIDIA / endpoint engines were never counted
        // here — preserved as-is from the original switch.)
        case .ensemble:
            return localFloor || anthropic || grok || gemini || groq
                || mistral || cerebras || openAI || copilot || openRouter
        // Free · Auto never spends: the local floor or a FREE key only.
        case .freeAuto:    return localFloor || anyFreeCloud
        // FreeCoding mirrors Free·Auto's coder pool.
        case .freeCoding:  return localFloor || anyCloudCoder
        // Cloud Coding is cloud-ONLY — no local floor.
        case .cloudCoding: return anyCloudCoder
        // Salehman is LOCAL-FIRST: vLLM or Unsloth endpoint configured, or
        // the user's own Ollama model (named + server up). Cloud API keys do
        // NOT light this — Salehman never contacts third-party clouds.
        case .salehman:    return salehmanAnyCloud || (ollamaUp && customModelNamed)
        case .unslothStudio: return unslothConfigured
        case .vllm:        return vllmConfigured
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

    /// Brain switched without an auto-test (e.g. local→cloud): the shown
    /// verdict belongs to the previous brain — clear it.
    mutating func invalidate() { working = nil }
}

// MARK: - Ping-reply verdict

/// Classifies a one-token "ping" reply as working / not working. Pure so the
/// rule is testable without a brain: empty replies, the `offMessage`
/// sentinel, and Claude-Haiku error strings (`"[Claude Haiku …"`) all fail.
enum BrainPing {
    static func verdict(reply: String, offMessage: String) -> Bool {
        let trimmed = reply.trimmingCharacters(in: .whitespacesAndNewlines)
        return !(trimmed.isEmpty
                 || reply == offMessage
                 || trimmed.hasPrefix("[Claude Haiku"))
    }
}

// MARK: - Anthropic key-row subtitle (no-leak masking)

/// Subtitle presentation for the Anthropic key row. Shows enough of a saved
/// key to confirm the family (`sk-ant-api03` is 12 chars and uniquely
/// Anthropic) but NEVER echoes secret bytes: a misfiled wrong-service key —
/// whose first characters carry secret material — masks to `sk-…`.
enum AnthropicKeyPresentation {
    static let notConfigured =
        "Needed only for Claude Haiku. Get one at console.anthropic.com."

    static func subtitle(savedKey: String?) -> String {
        guard let raw = savedKey else { return notConfigured }
        let isAnthropic = raw.hasPrefix("sk-ant-")
        let prefix = isAnthropic ? String(raw.prefix(12)) : "sk-…"
        let family = isAnthropic
            ? "Looks like an Anthropic key"
            : "⚠️ Doesn't start with `sk-ant-` — may be from a different service"
        return "Saved: \(prefix)…  ·  \(family)"
    }

    /// True when a saved key does NOT look like an Anthropic key — drives
    /// the orange "saved the wrong key" warning tint.
    static func flagsWrongService(savedKey: String?) -> Bool {
        guard let raw = savedKey else { return false }
        return !raw.hasPrefix("sk-ant-")
    }
}
