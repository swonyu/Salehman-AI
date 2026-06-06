import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

/// Free web access — DuckDuckGo search + page fetching. No API key required.
enum Web {
    private static let ua = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15"

    /// Search the web via DuckDuckGo's HTML endpoint. Returns formatted results.
    static func search(_ query: String) async -> String {
        guard let q = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://html.duckduckgo.com/html/?q=\(q)") else {
            return "Invalid search query."
        }
        var req = URLRequest(url: url)
        req.setValue(ua, forHTTPHeaderField: "User-Agent")
        req.timeoutInterval = 20

        guard let (data, _) = try? await URLSession.shared.data(for: req),
              let html = String(data: data, encoding: .utf8) else {
            return "Web search failed (no network or blocked)."
        }

        // Extract result titles, snippets, and links.
        let titles = matches(in: html, pattern: "result__a[^>]*>(.*?)</a>")
        let snippets = matches(in: html, pattern: "result__snippet[^>]*>(.*?)</a>")
        let links = matches(in: html, pattern: "result__a[^>]+href=\"(.*?)\"")

        if titles.isEmpty { return "No results found for \"\(query)\"." }

        var out = "Web results for \"\(query)\":\n"
        for i in 0..<min(6, titles.count) {
            let title = clean(titles[i])
            let snippet = i < snippets.count ? clean(snippets[i]) : ""
            let link = i < links.count ? decodeDDG(links[i]) : ""
            out += "\n\(i + 1). \(title)\n   \(snippet)\n   \(link)\n"
        }
        return out
    }

    /// Fetch a URL and return its readable text (HTML stripped).
    static func fetch(_ urlString: String) async -> String {
        var s = urlString.trimmingCharacters(in: .whitespaces)
        let lower = s.lowercased()
        if lower.hasPrefix("http://") || lower.hasPrefix("https://") {
            // keep as-is
        } else if lower.range(of: "^[a-z][a-z0-9+.-]*://", options: .regularExpression) != nil {
            // An explicit NON-web scheme (file:, ftp:, data:, …). Reject outright —
            // never coerce it to https. (The host-based guard below only sees the
            // scheme AFTER coercion, so file:// must be stopped right here.)
            return "Refused: only http/https URLs can be fetched."
        } else {
            s = "https://" + s   // bare host or host:port → default to https
        }
        guard let url = URL(string: s) else { return "Invalid URL." }
        // SSRF guard: an LLM (or a crafted prompt) can ask the app to fetch ANY
        // URL. Block non-web schemes and private/loopback/link-local hosts so a
        // tool call can't reach localhost services (e.g. the Ollama API on
        // 127.0.0.1:11434), the cloud metadata endpoint (169.254.169.254), or
        // the user's LAN. This is a conservative denylist, not a sandbox —
        // DNS-rebinding and redirect-to-internal are not covered here.
        if let reason = ssrfRejectionReason(url) { return reason }
        var req = URLRequest(url: url)
        req.setValue(ua, forHTTPHeaderField: "User-Agent")
        req.timeoutInterval = 25

        // Re-validate every redirect target (a public host must not be able to
        // 30x us to localhost / the cloud metadata endpoint), then re-check the
        // final resolved URL after any redirects we DID follow.
        let session = URLSession(configuration: .ephemeral, delegate: RedirectGuard(), delegateQueue: nil)
        defer { session.finishTasksAndInvalidate() }
        guard let (data, response) = try? await session.data(for: req),
              let html = String(data: data, encoding: .utf8) else {
            return "Could not fetch \(s)."
        }
        if let finalURL = response.url, let reason = ssrfRejectionReason(finalURL) { return reason }
        let text = stripHTML(html)
        return text.isEmpty ? "(No readable text at \(s).)" : String(text.prefix(8000))
    }

    // MARK: - Helpers

    /// Returns a user-facing rejection string if `url` targets a non-web scheme
    /// or a private/internal host (SSRF), else nil. `internal` (not `private`) so
    /// the redirect guard and the security tests can reach it. IPv6 literal checks
    /// are gated on `host.contains(":")` so real domains (e.g. `fc…​.com`) aren't
    /// falsely blocked by the `fc/fd` unique-local prefix.
    static func ssrfRejectionReason(_ url: URL) -> String? {
        guard let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https" else {
            return "Refused: only http/https URLs can be fetched."
        }
        // Reject embedded credentials (userinfo). A fetch tool should never carry
        // them, and `user:pass@host` is a classic SSRF-confusion vector when a
        // downstream parser splits on `@` differently than Foundation's URL does.
        if url.user != nil || url.password != nil {
            return "Refused: URLs with embedded credentials (user:password@) are not allowed."
        }
        guard var host = url.host?.lowercased(), !host.isEmpty else {
            return "Refused: URL has no host."
        }
        host = host.trimmingCharacters(in: CharacterSet(charactersIn: "[]"))   // strip IPv6 brackets

        if host == "localhost" || host.hasSuffix(".local") || host.hasSuffix(".internal") {
            return "Refused: \"\(host)\" is a local/internal host."
        }
        if host.contains(":") {   // IPv6 literal
            if host == "::1" || host == "::" || host.hasPrefix("fc") || host.hasPrefix("fd") || host.hasPrefix("fe80") {
                return "Refused: \"\(host)\" is a private IPv6 address."
            }
            // IPv4-mapped/compatible (e.g. ::ffff:127.0.0.1, ::127.0.0.1):
            // loopback wearing an IPv6 costume — validate the embedded v4.
            if let lastColon = host.lastIndex(of: ":") {
                let tail = String(host[host.index(after: lastColon)...])
                if tail.contains("."), isPrivateIPv4(tail) {
                    return "Refused: \"\(host)\" maps to a private or loopback address."
                }
            }
            return nil
        }
        // Numeric IP obfuscations that bypass the dotted-quad check below:
        //   • bare hex host      0x7f000001
        //   • bare decimal int   2130706433  (== 127.0.0.1)
        //   • octal dotted-quad  0177.0.0.1  (a leading-zero octet)
        // No legitimate DNS hostname is purely numeric, so refusing these is safe.
        if host.hasPrefix("0x") || host.allSatisfy(\.isNumber) {
            return "Refused: \"\(host)\" is a numeric/obfuscated address."
        }
        let octets = host.split(separator: ".")
        if octets.count == 4, octets.allSatisfy({ $0.allSatisfy(\.isNumber) }),
           octets.contains(where: { $0.count > 1 && $0.hasPrefix("0") }) {
            return "Refused: \"\(host)\" uses an ambiguous (octal) address form."
        }
        if isPrivateIPv4(host) {
            return "Refused: \"\(host)\" is a private or loopback address."
        }
        return nil
    }

    /// True if `host` is a dotted-quad IPv4 in a loopback / private / link-local /
    /// unspecified range. Non-IPv4 strings return false.
    static func isPrivateIPv4(_ host: String) -> Bool {
        let parts = host.split(separator: ".")
        guard parts.count == 4, let a = Int(parts[0]), let b = Int(parts[1]),
              Int(parts[2]) != nil, Int(parts[3]) != nil else { return false }
        return a == 0 || a == 127 || a == 10
            || (a == 192 && b == 168)
            || (a == 169 && b == 254)
            || (a == 172 && (16...31).contains(b))
    }

    private static func matches(in text: String, pattern: String) -> [String] {
        guard let re = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators, .caseInsensitive]) else { return [] }
        let range = NSRange(text.startIndex..., in: text)
        return re.matches(in: text, range: range).compactMap {
            guard $0.numberOfRanges > 1, let r = Range($0.range(at: 1), in: text) else { return nil }
            return String(text[r])
        }
    }

    // internal (not private) so WebToolsOfflineGateTests can pin stripHTML + decodeDDG behavior exactly.
    // No logic change; was only called internally before.
    static func stripHTML(_ html: String) -> String {
        var s = html
        // Remove script/style blocks.
        for tag in ["script", "style", "head", "nav", "footer"] {
            s = s.replacingOccurrences(of: "<\(tag)[^>]*>.*?</\(tag)>", with: " ",
                                       options: [.regularExpression, .caseInsensitive])
        }
        s = s.replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
        s = decodeEntities(s)
        s = s.replacingOccurrences(of: "[ \\t]+", with: " ", options: .regularExpression)
        s = s.replacingOccurrences(of: "(\\s*\\n\\s*){2,}", with: "\n\n", options: .regularExpression)
        return s.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func clean(_ s: String) -> String {
        decodeEntities(s.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression))
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func decodeEntities(_ s: String) -> String {
        var r = s
        let map = ["&amp;": "&", "&lt;": "<", "&gt;": ">", "&quot;": "\"", "&#39;": "'", "&#x27;": "'", "&nbsp;": " "]
        for (k, v) in map { r = r.replacingOccurrences(of: k, with: v) }
        return r
    }

    /// DuckDuckGo wraps links like //duckduckgo.com/l/?uddg=ENCODED
    // internal (not private) so WebToolsOfflineGateTests can pin decodeDDG exactly.
    static func decodeDDG(_ link: String) -> String {
        guard let range = link.range(of: "uddg=") else {
            return link.hasPrefix("//") ? "https:" + link : link
        }
        let encoded = String(link[range.upperBound...]).components(separatedBy: "&").first ?? ""
        return encoded.removingPercentEncoding ?? link
    }
}

/// URLSession delegate that re-runs the SSRF denylist on every redirect target,
/// so a public host cannot 30x the fetch to an internal address (localhost, the
/// Ollama API, the cloud metadata endpoint, the LAN). Stateless → `@unchecked
/// Sendable` is honest. Returning `nil` from the callback cancels the redirect
/// (the 3xx response is delivered as-is).
private final class RedirectGuard: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    func urlSession(_ session: URLSession, task: URLSessionTask,
                    willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest,
                    completionHandler: @escaping (URLRequest?) -> Void) {
        if let url = request.url, Web.ssrfRejectionReason(url) != nil {
            completionHandler(nil)   // refuse the redirect to an internal host
        } else {
            completionHandler(request)
        }
    }
}

#if canImport(FoundationModels)
struct WebSearchTool: Tool {
    let name = "web_search"
    let description = "Search the web (DuckDuckGo) for current information. Use for anything recent, factual, or beyond your training knowledge."

    @Generable
    struct Arguments {
        @Guide(description: "The search query.")
        var query: String
    }

    func call(arguments: Arguments) async throws -> String {
        // Use the SAME gate as the Ollama tool path (ToolPolicy.isExternalAllowed),
        // which is Offline-Mode-aware — a session built while online otherwise kept
        // these tools live and leaked to the network after the user went offline.
        guard ToolPolicy.isExternalAllowed else {
            return ToolPolicy.webToolsDisabledReason() ?? "Web access is disabled."
        }
        return await Web.search(arguments.query)
    }
}

struct FetchURLTool: Tool {
    let name = "fetch_url"
    let description = "Fetch a web page (or public social-media page) and return its readable text. Use to read an article or page the user mentions or that web_search returned."

    @Generable
    struct Arguments {
        @Guide(description: "The full URL to fetch.")
        var url: String
    }

    func call(arguments: Arguments) async throws -> String {
        guard ToolPolicy.isExternalAllowed else {
            return ToolPolicy.webToolsDisabledReason() ?? "Web access is disabled."
        }
        return await Web.fetch(arguments.url)
    }
}
#endif
