import Foundation

/// GitHub Copilot authentication. Copilot has no plain API key — editors sign in
/// with GitHub's **OAuth device flow**, then exchange the GitHub token for a
/// short-lived Copilot token. We do the same:
///   1. `requestDeviceCode()` → show the user a code + open github.com/login/device
///   2. `pollForToken(...)`   → on approval, store the GitHub token in Keychain
///   3. `copilotToken()`      → exchange/refresh the short-lived Copilot token
///
/// NOTE: this uses GitHub's editor OAuth client id and the `copilot_internal`
/// token endpoint — the same surface editor plugins use. It's undocumented and
/// requires the user's **own active Copilot subscription**; treat it as such.
actor CopilotAuth {
    static let shared = CopilotAuth()

    /// GitHub's public editor OAuth client id (used by VS Code & community tools).
    private static let clientID = "Iv1.b507a08c87ecfe98"

    private var cachedToken: String?
    private var expiry: Date = .distantPast

    /// Signed in iff a GitHub token is stored. Sync (Keychain only, no HTTP).
    nonisolated static func isAuthed() -> Bool { KeychainStore.has(.copilotGitHubToken) }

    /// Forget the GitHub token. The in-memory Copilot token is invalidated lazily
    /// (the next `copilotToken()` sees no GitHub token and returns nil).
    nonisolated static func signOut() { KeychainStore.delete(.copilotGitHubToken) }

    /// A valid short-lived Copilot bearer token, exchanging/refreshing as needed.
    func copilotToken() async -> String? {
        // Re-check Keychain first so a sign-out takes effect immediately even if
        // a previously-cached token hasn't expired yet.
        guard let gh = KeychainStore.read(.copilotGitHubToken) else {
            cachedToken = nil
            return nil
        }
        if let t = cachedToken, Date() < expiry { return t }

        guard let url = URL(string: "https://api.github.com/copilot_internal/v2/token") else { return nil }
        var req = URLRequest(url: url)
        req.setValue("token \(gh)", forHTTPHeaderField: "Authorization")
        req.setValue("SalehmanAI/1.0", forHTTPHeaderField: "Editor-Version")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        guard let (data, resp) = try? await URLSession.shared.data(for: req),
              (resp as? HTTPURLResponse)?.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let token = json["token"] as? String else { return nil }
        cachedToken = token
        let exp = (json["expires_at"] as? Double) ?? (Date().timeIntervalSince1970 + 1500)
        expiry = Date(timeIntervalSince1970: exp - 60)   // refresh a minute early
        return token
    }

    struct DeviceCode: Sendable {
        let userCode: String
        let deviceCode: String
        let verificationURI: String
        let interval: Int
    }

    /// Step 1 — request a device code. The user types `userCode` at `verificationURI`.
    func requestDeviceCode() async -> DeviceCode? {
        guard let url = URL(string: "https://github.com/login/device/code") else { return nil }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONSerialization.data(withJSONObject: ["client_id": Self.clientID, "scope": "read:user"])
        guard let (data, resp) = try? await URLSession.shared.data(for: req),
              (resp as? HTTPURLResponse)?.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let userCode = json["user_code"] as? String,
              let deviceCode = json["device_code"] as? String,
              let verify = json["verification_uri"] as? String else { return nil }
        return DeviceCode(userCode: userCode, deviceCode: deviceCode,
                          verificationURI: verify, interval: (json["interval"] as? Int) ?? 5)
    }

    /// Step 2 — poll until the user authorizes (or it times out). On success the
    /// GitHub token is written to Keychain and `true` is returned.
    func pollForToken(deviceCode: String, interval: Int) async -> Bool {
        guard let url = URL(string: "https://github.com/login/oauth/access_token") else { return false }
        let deadline = Date().addingTimeInterval(900)   // 15-minute cap
        var wait = max(interval, 5)
        while Date() < deadline {
            try? await Task.sleep(nanoseconds: UInt64(wait) * 1_000_000_000)
            if Task.isCancelled { return false }
            var req = URLRequest(url: url)
            req.httpMethod = "POST"
            req.setValue("application/json", forHTTPHeaderField: "Accept")
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = try? JSONSerialization.data(withJSONObject: [
                "client_id": Self.clientID, "device_code": deviceCode,
                "grant_type": "urn:ietf:params:oauth:grant-type:device_code"])
            guard let (data, _) = try? await URLSession.shared.data(for: req),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { continue }
            if let token = json["access_token"] as? String {
                KeychainStore.write(token, to: .copilotGitHubToken)
                cachedToken = nil; expiry = .distantPast
                return true
            }
            switch json["error"] as? String {
            case "authorization_pending": continue
            case "slow_down":             wait += 5
            default:                      return false   // access_denied / expired_token
            }
        }
        return false
    }
}

/// The "Copilot" brain → GitHub Copilot chat (cloud). OpenAI-compatible wire
/// format, but authenticated with the device-flow token from `CopilotAuth` plus
/// the Copilot integration headers — which is why it doesn't reuse
/// `OpenAICompatibleClient` (that models a static Keychain key, not a refreshing
/// token + custom headers). Requires an active Copilot subscription.
enum CopilotClient {
    static let endpoint = "https://api.githubcopilot.com/chat/completions"
    static let model = "gpt-4o"
    private static let headers = [
        "Editor-Version": "SalehmanAI/1.0",
        "Editor-Plugin-Version": "SalehmanAI/1.0",
        "Copilot-Integration-Id": "vscode-chat",
    ]

    nonisolated static func isAuthed() -> Bool { CopilotAuth.isAuthed() }

    static func chat(prompt: String, system: String? = nil) async -> String? {
        guard let token = await CopilotAuth.shared.copilotToken() else { return nil }
        return await request(token: token, prompt: prompt, system: system, stream: false, onUpdate: nil)
    }

    static func chatStream(prompt: String, system: String? = nil,
                           onUpdate: @escaping (String) -> Void) async -> String? {
        guard let token = await CopilotAuth.shared.copilotToken() else { return nil }
        return await request(token: token, prompt: prompt, system: system, stream: true, onUpdate: onUpdate)
    }

    private static func request(token: String, prompt: String, system: String?,
                                stream: Bool, onUpdate: ((String) -> Void)?) async -> String? {
        guard let url = URL(string: endpoint) else { return nil }
        var messages: [[String: String]] = []
        if let system, !system.isEmpty { messages.append(["role": "system", "content": system]) }
        messages.append(["role": "user", "content": prompt])
        let body: [String: Any] = ["model": model, "messages": messages, "stream": stream]
        guard let payload = try? JSONSerialization.data(withJSONObject: body) else { return nil }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        for (k, v) in headers { req.setValue(v, forHTTPHeaderField: k) }
        req.httpBody = payload
        req.timeoutInterval = stream ? 600 : 120

        if stream, let onUpdate {
            guard let (bytes, resp) = try? await URLSession.shared.bytes(for: req),
                  (resp as? HTTPURLResponse)?.statusCode == 200 else { return nil }
            var acc = ""
            do {
                for try await line in bytes.lines {
                    guard line.hasPrefix("data:") else { continue }
                    let p = line.dropFirst("data:".count).trimmingCharacters(in: .whitespaces)
                    if p == "[DONE]" { break }
                    if let d = p.data(using: .utf8),
                       let j = try? JSONSerialization.jsonObject(with: d) as? [String: Any],
                       let choices = j["choices"] as? [[String: Any]],
                       let delta = choices.first?["delta"] as? [String: Any],
                       let chunk = delta["content"] as? String, !chunk.isEmpty {
                        acc += chunk
                        onUpdate(acc)
                    }
                }
            } catch { /* keep what we have */ }
            let t = acc.trimmingCharacters(in: .whitespacesAndNewlines)
            return t.isEmpty ? nil : t
        }

        guard let (data, resp) = try? await URLSession.shared.data(for: req),
              (resp as? HTTPURLResponse)?.statusCode == 200,
              let j = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = j["choices"] as? [[String: Any]],
              let msg = choices.first?["message"] as? [String: Any],
              let content = msg["content"] as? String else { return nil }
        let t = content.trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? nil : t
    }
}
