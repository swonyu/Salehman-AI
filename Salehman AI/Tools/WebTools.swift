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
        if !s.hasPrefix("http") { s = "https://" + s }
        guard let url = URL(string: s) else { return "Invalid URL." }
        var req = URLRequest(url: url)
        req.setValue(ua, forHTTPHeaderField: "User-Agent")
        req.timeoutInterval = 25

        guard let (data, _) = try? await URLSession.shared.data(for: req),
              let html = String(data: data, encoding: .utf8) else {
            return "Could not fetch \(s)."
        }
        let text = stripHTML(html)
        return text.isEmpty ? "(No readable text at \(s).)" : String(text.prefix(8000))
    }

    // MARK: - Helpers
    private static func matches(in text: String, pattern: String) -> [String] {
        guard let re = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators, .caseInsensitive]) else { return [] }
        let range = NSRange(text.startIndex..., in: text)
        return re.matches(in: text, range: range).compactMap {
            guard $0.numberOfRanges > 1, let r = Range($0.range(at: 1), in: text) else { return nil }
            return String(text[r])
        }
    }

    private static func stripHTML(_ html: String) -> String {
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
    private static func decodeDDG(_ link: String) -> String {
        guard let range = link.range(of: "uddg=") else {
            return link.hasPrefix("//") ? "https:" + link : link
        }
        let encoded = String(link[range.upperBound...]).components(separatedBy: "&").first ?? ""
        return encoded.removingPercentEncoding ?? link
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
        guard AppSettings.boolDefaultTrue(AppSettings.Keys.webAccess) else {
            return "Web access is turned off in Settings."
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
        guard AppSettings.boolDefaultTrue(AppSettings.Keys.webAccess) else {
            return "Web access is turned off in Settings."
        }
        return await Web.fetch(arguments.url)
    }
}
#endif
