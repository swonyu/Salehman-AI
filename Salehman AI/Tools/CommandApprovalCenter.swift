import SwiftUI
import Combine

/// Bridges the (background) tool execution to the UI so the user can approve or
/// cancel a command before it runs. The tool awaits `requestApproval`, which
/// suspends until the user taps a button in ContentView.
///
/// By default EVERY command asks for confirmation. The user can switch to
/// "always allow" (no prompts) and turn confirmation back on at any time.
@MainActor
final class CommandApprovalCenter: ObservableObject {
    static let shared = CommandApprovalCenter()

    struct Pending: Identifiable {
        let id = UUID()
        let command: String
        let resume: (Bool) -> Void
    }

    @Published var pending: Pending?

    /// When true, every command must be approved. Persisted across launches.
    @Published var confirmationEnabled: Bool {
        didSet { UserDefaults.standard.set(confirmationEnabled, forKey: Self.key) }
    }

    private static let key = "confirmCommandsEnabled"

    private init() {
        // Default to ON (ask every time) the first time the app runs.
        if UserDefaults.standard.object(forKey: Self.key) == nil {
            self.confirmationEnabled = true
        } else {
            self.confirmationEnabled = UserDefaults.standard.bool(forKey: Self.key)
        }
    }

    /// Called from the tool. Suspends until the user decides (or returns
    /// immediately if confirmation is turned off).
    func requestApproval(_ command: String) async -> Bool {
        guard confirmationEnabled else { return true }
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

    /// User tapped "Always run" — approve this one and stop asking from now on.
    func alwaysAllow() {
        confirmationEnabled = false
        resolve(true)
    }
}
