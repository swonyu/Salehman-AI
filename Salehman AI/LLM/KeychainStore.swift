import Foundation
import Security

/// macOS Keychain storage for sensitive credentials. The app is local-only,
/// so the surviving entries are local/endpoint credentials (a self-hosted
/// vLLM bearer token, an Unsloth Studio token used only for a Settings
/// copy-snippet, a Hugging Face token used by the external cloud-GPU notebook,
/// and the NVIDIA NIM key for the free DeepSeek route). Source files in this
/// project must NEVER contain key material — the only place the actual
/// characters of a key live is
///   (1) the `Data` parameter handed to `SecItemAdd` when the user types it
///       into the Settings panel, and
///   (2) the `Authorization: Bearer …` HTTP header the matching client builds
///       at request time.
///
/// The Keychain entry is service-scoped to this app's bundle identifier and
/// account-scoped per credential — so each credential just picks a different
/// account name without colliding.
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
        // Cloud-provider API-key entries (grok, gemini, groq, mistral, cerebras,
        // anthropic, openAI, openRouter, copilot-github) were removed when the
        // app went local-only — those providers no longer exist in the app.
        // ("deepseek-api-key" was removed earlier, 2026-06-12.)
        /// NVIDIA NIM (integrate.api.nvidia.com) — hosts REAL DeepSeek (V4) on a
        /// free tier, OpenAI-compatible. This is the app's "DeepSeek for free"
        /// route since DeepSeek's own API + OpenRouter are paid-only.
        case nvidiaAPIKey   = "nvidia-api-key"
        /// Unsloth API token. NOT required for the app's `.unslothStudio` chat
        /// brain (that talks to a local OpenAI-compatible server with no auth) —
        /// stored only so the "Use this model with Claude Code too" snippet in
        /// Settings can substitute the real `ANTHROPIC_AUTH_TOKEN` into the
        /// copy-to-clipboard payload (see Unsloth's Claude-Code guide).
        case unslothStudioAPIKey = "unsloth-studio-api-key"
        /// Hugging Face token (read scope). Used OUTSIDE the app: the free
        /// cloud-GPU notebook (salehman_cloud_gpu.ipynb) needs it to download
        /// the private salehman GGUF — Settings keeps it in the Keychain with
        /// a Copy button so it's pasted into Colab, never retyped or stored
        /// in a notebook/file.
        case hfToken = "hf-token"
        /// Optional bearer token for a self-hosted vLLM server started with
        /// `--api-key`. Needed when you host the vLLM brain on a PUBLIC cloud GPU
        /// (so the endpoint isn't open to the world); a localhost `vllm serve`
        /// stays keyless. Lives ONLY in Keychain.
        case vllmAPIKey = "vllm-api-key"
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
