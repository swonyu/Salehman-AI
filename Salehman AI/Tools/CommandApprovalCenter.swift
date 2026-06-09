import SwiftUI
import Combine
import AppKit

/// Bridges the (background) tool execution to the UI so the user can approve or
/// cancel a command before it runs. The tool awaits `requestApproval`, which
/// suspends until the user taps a button in ContentView.
///
/// By default EVERY command asks for confirmation. There are two ways to skip a
/// prompt, and they are deliberately DIFFERENT consents:
///   • `confirmationEnabled` — the durable, user-facing preference (Settings
///     toggle + in-chat chip). If the user turns it off, that's their choice.
///   • `sessionBypass` — the approval card's "Always run", which now grants a
///     SESSION-ONLY fast path (reset on app-resign / restart, never applied to
///     risky commands). Previously "Always run" flipped the persisted preference
///     off forever — one tap permanently disabled the shell gate across launches.
@MainActor
final class CommandApprovalCenter: ObservableObject {
    static let shared = CommandApprovalCenter()

    struct Pending: Identifiable {
        let id = UUID()
        let command: String
        let resume: (Bool) -> Void
    }

    @Published var pending: Pending?

    /// Persisted user preference (Settings "Confirm terminal commands" + the
    /// in-chat `ConfirmationChip`). Default ON. NOT flipped by "Always run".
    @Published var confirmationEnabled: Bool {
        didSet { UserDefaults.standard.set(confirmationEnabled, forKey: Self.key) }
    }

    /// Session-only fast path set by the approval card's "Always run". In-memory
    /// (false at launch), reset whenever the app loses focus, and never applied
    /// to risky commands — so a single tap can't silently disable the gate.
    private var sessionBypass = false

    private static let key = "confirmCommandsEnabled"

    private init() {
        // Default to ON (ask every time) the first time the app runs.
        if UserDefaults.standard.object(forKey: Self.key) == nil {
            self.confirmationEnabled = true
        } else {
            self.confirmationEnabled = UserDefaults.standard.bool(forKey: Self.key)
        }
        // Re-arm: backgrounding the app clears any session bypass, so stepping
        // away resets to "ask again" even mid-session.
        NotificationCenter.default.addObserver(
            forName: NSApplication.didResignActiveNotification, object: nil, queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            // Bind a local constant so the concurrent Task captures an immutable
            // value (not the outer closure's captured `self`), satisfying Swift 6.
            Task { @MainActor in self.sessionBypass = false }
        }
    }

    /// Called from the tool. Suspends until the user decides — unless the user
    /// turned confirmations off in Settings, or a NON-risky command is covered by
    /// the current session bypass. Risky commands always re-confirm.
    func requestApproval(_ command: String) async -> Bool {
        // Unrestricted Mode: auto-approve without a prompt. The chat UI
        // hides the approval card in this mode, so we MUST resolve here or the tool
        // would hang forever. SAFETY FLOOR INTACT: `Shell.runApproved` runs
        // `Shell.isBlocked` BEFORE calling this, so outright-catastrophic commands
        // (rm -rf /, fork bombs, disk erase, sudo, …) are already refused — Unrestricted Mode
        // only skips the approval prompt for what passed that floor.
        if AppSettings.shared.unrestrictedTools { return true }
        // Deliberate, persisted opt-out (Settings/chip) fully bypasses.
        if !confirmationEnabled { return true }
        // Allowlist fast-path (additive): commands made up ENTIRELY of provably
        // read-only inspectors (ls/cat/grep/stat…) skip the prompt even with
        // confirmations ON. They cannot mutate, escalate, exec, or exfiltrate,
        // and `Shell.isBlocked` already ran — so this only trims approval fatigue
        // on the safe commands the model runs constantly, keeping the real
        // prompts meaningful. Anything outside the allowlist falls straight through.
        if ToolPolicy.CommandRisk.isDefinitelySafe(command) { return true }
        // "Always run" session bypass — but risky commands always re-confirm.
        // Go to `ToolPolicy.CommandRisk.looksRisky` directly (the single source of
        // the risk vocabulary). The old `Self.looksRisky` thin alias was removed —
        // a `nonisolated static` on a `@MainActor` class was a maintenance trap
        // (compiler couldn't prevent future drift into MainActor state).
        if sessionBypass && !ToolPolicy.CommandRisk.looksRisky(command) { return true }
        return await withCheckedContinuation { continuation in
            self.pending = Pending(command: command) { approved in
                continuation.resume(returning: approved)
            }
        }
    }

    /// User tapped Run (once) or Cancel.
    func resolve(_ approved: Bool) {
        let p = pending
        pending = nil
        p?.resume(approved)
    }

    /// User tapped "Always run" — approve this one and skip prompts for non-risky
    /// commands for the REST OF THIS SESSION only (until the app loses focus or
    /// restarts). No longer disables the persisted confirmation preference.
    func alwaysAllow() {
        sessionBypass = true
        resolve(true)
    }

    // Note: there is intentionally NO `CommandApprovalCenter.looksRisky` alias.
    // The risk vocabulary lives in ONE place — `ToolPolicy.CommandRisk.looksRisky`
    // — and every caller (this class above, `Shell.isBlocked`, the tests) reaches
    // it directly. A `nonisolated static` thin alias on this `@MainActor` class
    // was misleading: the annotation suggested an isolation guarantee that the
    // compiler couldn't actually defend across future edits.
}
