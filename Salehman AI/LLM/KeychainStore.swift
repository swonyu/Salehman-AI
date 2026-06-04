import Foundation
import Security

/// macOS Keychain storage for sensitive credentials (currently just the xAI
/// Grok API key). Source files in this project must NEVER contain key
/// material — the only place the actual characters of a key live is
///   (1) the `Data` parameter handed to `SecItemAdd` when the user types it
///       into the Settings panel, and
///   (2) the `Authorization: Bearer …` HTTP header that `GrokClient` builds
///       at request time.
///
/// The Keychain entry is service-scoped to this app's bundle identifier and
/// account-scoped per credential — so a future second key (OpenAI, Anthropic,
/// etc.) just picks a different account name without colliding.
///
/// Design notes:
/// * Synchronous because `SecItem*` calls are already cheap (encrypted at
///   rest, gated by the user's account, no network). Wrapping in `async`
///   would add ceremony without buying anything.
/// * `read()` returns `nil` for both "no entry" and "Keychain access denied"
///   — the call sites only care whether they have a usable key, not why.
/// * `delete()` swallows `errSecItemNotFound` so a user who has never set a
///   key can still tap "Forget key" without an error popup.
enum KeychainStore {

    /// Service identifier — falls back to a stable string if the bundle ID
    /// isn't readable (e.g. in unit-test contexts where the host bundle
    /// isn't yet set up).
    nonisolated private static let service: String =
        Bundle.main.bundleIdentifier ?? "com.salehman.ai"

    // MARK: - Account identifiers

    enum Account: String {
        case grokAPIKey     = "grok-api-key"
        case geminiAPIKey   = "gemini-api-key"
        case groqAPIKey     = "groq-api-key"
        case mistralAPIKey  = "mistral-api-key"
        case cerebrasAPIKey = "cerebras-api-key"
        case anthropicAPIKey = "anthropic-api-key"
        case openAIAPIKey   = "openai-api-key"
        /// GitHub OAuth access token for the Copilot brain (from the device flow).
        /// The short-lived Copilot token derived from it is cached in memory only.
        case copilotGitHubToken = "copilot-github-token"
    }

    // MARK: - CRUD

    /// Read the value at `account`. Returns nil if missing or unreadable.
    nonisolated static func read(_ account: Account) -> String? {
        let query: [String: Any] = [
            kSecClass as String:            kSecClassGenericPassword,
            kSecAttrService as String:      service,
            kSecAttrAccount as String:      account.rawValue,
            kSecReturnData as String:       true,
            kSecMatchLimit as String:       kSecMatchLimitOne,
        ]
        var item: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess,
              let data = item as? Data,
              let str  = String(data: data, encoding: .utf8) else { return nil }
        let trimmed = str.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    /// Write `value` at `account`, replacing any prior entry. Returns
    /// `true` on success — false means the Keychain refused the write
    /// (extremely rare; usually a permissions issue).
    @discardableResult
    nonisolated static func write(_ value: String, to account: Account) -> Bool {
        guard let data = value.data(using: .utf8) else { return false }

        // Try update-first, then add — atomicity isn't critical because the
        // only caller is a single user typing into a Settings field.
        let baseQuery: [String: Any] = [
            kSecClass as String:        kSecClassGenericPassword,
            kSecAttrService as String:  service,
            kSecAttrAccount as String:  account.rawValue,
        ]
        let attrs: [String: Any] = [kSecValueData as String: data]

        let updateStatus = SecItemUpdate(baseQuery as CFDictionary, attrs as CFDictionary)
        if updateStatus == errSecSuccess { return true }

        // No prior entry → add a new one.
        var addQuery = baseQuery
        addQuery[kSecValueData as String] = data
        // Items are device-scoped and require the user to be unlocked,
        // matching the security level of the rest of the user's secrets.
        addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
        return addStatus == errSecSuccess
    }

    /// Delete the entry at `account`. Idempotent — silently succeeds when
    /// there is nothing to delete.
    @discardableResult
    nonisolated static func delete(_ account: Account) -> Bool {
        let query: [String: Any] = [
            kSecClass as String:        kSecClassGenericPassword,
            kSecAttrService as String:  service,
            kSecAttrAccount as String:  account.rawValue,
        ]
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }

    /// Convenience: does an entry exist at all?
    nonisolated static func has(_ account: Account) -> Bool {
        read(account) != nil
    }
}
