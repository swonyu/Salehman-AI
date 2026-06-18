import Foundation

/// One image or video result surfaced by a media search, rich enough for the
/// Chat tab to render it inline (thumbnail, dimensions, source page). Plain
/// Codable value type — same shape contract as `ChatMessage` so it persists with
/// the conversation and decodes unchanged in the nonisolated `ChatStore`.
struct MediaItem: Identifiable, Codable, Equatable, Hashable {
    enum Kind: String, Codable { case image, video }
    let id: UUID
    let kind: Kind
    /// Direct media URL — an image `src` for `.image`, or the watch/page URL (or a
    /// direct file URL when one is known) for `.video`.
    let url: String
    /// Preview image: a lower-res image thumbnail, or the poster frame for a video.
    var thumbnail: String?
    var title: String?
    /// The page/site the media came from — shown so the user can judge the source
    /// (e.g. authenticity) instead of trusting a tag blindly.
    var source: String?
    var width: Int?
    var height: Int?
    /// Human duration string for videos ("3:21"); nil for images.
    var duration: String?

    init(id: UUID = UUID(), kind: Kind, url: String, thumbnail: String? = nil,
         title: String? = nil, source: String? = nil,
         width: Int? = nil, height: Int? = nil, duration: String? = nil) {
        self.id = id; self.kind = kind; self.url = url; self.thumbnail = thumbnail
        self.title = title; self.source = source
        self.width = width; self.height = height; self.duration = duration
    }

    /// The best URL to actually display the pixels: thumbnail if present (smaller,
    /// loads faster, already CORS-friendly via DDG's proxy), else the full URL.
    var displayURL: String { thumbnail ?? url }

    /// True when `url` points at a directly-playable video file (vs a watch page).
    /// Drives whether the gallery embeds an AVKit player or a click-to-open card.
    var isDirectVideoFile: Bool {
        guard kind == .video else { return false }
        let lower = url.lowercased()
        return lower.hasSuffix(".mp4") || lower.hasSuffix(".m3u8")
            || lower.hasSuffix(".webm") || lower.hasSuffix(".mov")
    }
}

/// Side-channel that carries media from a search tool call back to the Chat tab.
/// The tool loop only returns *text* to the model; this buffer collects the
/// actual `MediaItem`s a media-search tool produced during one reply. The view
/// drains it right after the reply completes and attaches the media to the
/// assistant `ChatMessage`. `@MainActor` because the tool dispatch and the chat
/// view model both run on the main actor — no await hops, no cross-actor sends.
@MainActor
final class MediaCapture {
    static let shared = MediaCapture()
    private init() {}

    private(set) var pending: [MediaItem] = []

    /// Start of a new turn — discard anything a prior (cancelled) turn left behind.
    func reset() { pending.removeAll() }

    /// A media-search tool call appends its results here.
    func add(_ items: [MediaItem]) { pending.append(contentsOf: items) }

    /// Snapshot + clear. The view calls this once after each reply; whatever the
    /// turn's tool calls collected becomes that message's inline gallery.
    func drain() -> [MediaItem] {
        defer { pending.removeAll() }
        return pending
    }
}

/// Free, key-less image + video search via DuckDuckGo's JSON endpoints, with
/// SafeSearch OFF (`p=-1`) so results are unfiltered — the same standard
/// search-engine setting `Web.search` uses (`kp=-2`), not a content bypass.
/// Unofficial endpoints (the same ones every DDG-image library uses): they need
/// a `vqd` token scraped from the search page first, then `i.js` / `v.js` return
/// JSON. Best-effort — if DDG changes the shape, callers get an empty list + a
/// plain-text note, never a crash.
enum MediaSearch {
    private static let ua = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15"
    static let maxResults = 20

    /// Native-language terms for a handful of nationalities. Appending the native
    /// term to a query measurably improves *relevance/authenticity* — content
    /// genuinely from that region is tagged in its own language, while mis-tagged
    /// ("fake") results usually are not. General (works for any listed nationality),
    /// not tied to any one query. Extend freely.
    private nonisolated static let nativeTerm: [String: String] = [
        "saudi": "سعودية", "saudi arabian": "سعودية", "arab": "عربية",
        "egyptian": "مصرية", "emirati": "إماراتية", "kuwaiti": "كويتية",
        "qatari": "قطرية", "lebanese": "لبنانية", "moroccan": "مغربية",
        "korean": "한국", "japanese": "日本", "chinese": "中文",
        "russian": "русская", "turkish": "türk", "persian": "ایرانی",
    ]

    /// Bias a query toward authentic, region-native results: if it names a
    /// nationality we have a native term for, append that term once. Improves
    /// "real X, not fake X" relevance; no-op for queries without a known nationality.
    nonisolated static func authenticityBiased(_ query: String) -> String {
        let lower = query.lowercased()
        for (adj, native) in nativeTerm where lower.contains(adj) {
            if query.contains(native) { return query }   // already localized
            return query + " " + native
        }
        return query
    }

    // MARK: Public search

    /// Image search → (model-facing text summary, media items for the gallery).
    static func images(_ query: String) async -> (text: String, media: [MediaItem]) {
        let q = authenticityBiased(query)
        guard let vqd = await vqd(for: q) else {
            return ("Image search is temporarily unavailable (couldn't reach DuckDuckGo).", [])
        }
        guard let json = await fetchJSON(
            "https://duckduckgo.com/i.js?l=us-en&o=json&q=\(enc(q))&vqd=\(enc(vqd))&f=,,,,,&p=-1"),
            let results = json["results"] as? [[String: Any]], !results.isEmpty else {
            return ("No image results found for \"\(query)\".", [])
        }
        let items: [MediaItem] = results.prefix(maxResults).compactMap { r in
            guard let image = r["image"] as? String, !image.isEmpty else { return nil }
            return MediaItem(
                kind: .image, url: image,
                thumbnail: (r["thumbnail"] as? String) ?? image,
                title: r["title"] as? String,
                source: (r["url"] as? String) ?? (r["source"] as? String),
                width: r["width"] as? Int, height: r["height"] as? Int)
        }
        return (summaryText(kind: "image", query: query, items: items), items)
    }

    /// Video search → (text summary, media items). DDG video results are watch-page
    /// URLs (YouTube/host sites), each with a poster thumbnail + duration; the
    /// gallery opens the page (or plays inline when the URL is a direct file).
    static func videos(_ query: String) async -> (text: String, media: [MediaItem]) {
        let q = authenticityBiased(query)
        guard let vqd = await vqd(for: q) else {
            return ("Video search is temporarily unavailable (couldn't reach DuckDuckGo).", [])
        }
        guard let json = await fetchJSON(
            "https://duckduckgo.com/v.js?l=us-en&o=json&q=\(enc(q))&vqd=\(enc(vqd))&f=,,,,&p=-1"),
            let results = json["results"] as? [[String: Any]], !results.isEmpty else {
            return ("No video results found for \"\(query)\".", [])
        }
        let items: [MediaItem] = results.prefix(maxResults).compactMap { r in
            guard let content = r["content"] as? String, !content.isEmpty else { return nil }
            let images = r["images"] as? [String: Any]
            let thumb = (images?["medium"] as? String) ?? (images?["large"] as? String)
                ?? (images?["small"] as? String)
            return MediaItem(
                kind: .video, url: content, thumbnail: thumb,
                title: r["title"] as? String,
                source: (r["publisher"] as? String) ?? (r["uploader"] as? String),
                duration: r["duration"] as? String)
        }
        return (summaryText(kind: "video", query: query, items: items), items)
    }

    // MARK: Internals

    /// What the model sees — it doesn't render pixels, so it gets a count + titles
    /// and a reminder that the user already sees the gallery, so it shouldn't paste
    /// raw URLs back.
    private static func summaryText(kind: String, query: String, items: [MediaItem]) -> String {
        guard !items.isEmpty else { return "No \(kind) results found for \"\(query)\"." }
        var out = "Found \(items.count) \(kind) result(s) for \"\(query)\" — they're shown to the user as an inline gallery, so just say what you found (don't paste URLs):\n"
        for (i, it) in items.prefix(8).enumerated() {
            let title = it.title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "(untitled)"
            let dur = it.duration.map { " · \($0)" } ?? ""
            let src = it.source.map { " · \($0)" } ?? ""
            out += "\(i + 1). \(title)\(dur)\(src)\n"
        }
        return out
    }

    private nonisolated static func enc(_ s: String) -> String {
        s.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? s
    }

    /// Scrape the one-time `vqd` token DDG requires for its JSON media endpoints.
    private static func vqd(for query: String) async -> String? {
        guard let url = URL(string: "https://duckduckgo.com/?q=\(enc(query))&iax=images&ia=images") else { return nil }
        var req = URLRequest(url: url)
        req.setValue(ua, forHTTPHeaderField: "User-Agent")
        req.timeoutInterval = 15
        guard let (data, _) = try? await URLSession.shared.data(for: req),
              let html = String(data: data, encoding: .utf8) else { return nil }
        // DDG embeds the token a few ways: vqd="4-123…", vqd='4-123…', or vqd=4-123…&
        for pattern in ["vqd=\"([^\"]+)\"", "vqd='([^']+)'", "vqd=([0-9-]+)&"] {
            if let token = firstGroup(in: html, pattern: pattern), !token.isEmpty {
                return token
            }
        }
        return nil
    }

    private static func fetchJSON(_ urlString: String) async -> [String: Any]? {
        guard let url = URL(string: urlString) else { return nil }
        var req = URLRequest(url: url)
        req.setValue(ua, forHTTPHeaderField: "User-Agent")
        req.setValue("https://duckduckgo.com/", forHTTPHeaderField: "Referer")
        req.setValue("application/json, text/javascript, */*; q=0.01", forHTTPHeaderField: "Accept")
        req.timeoutInterval = 20
        guard let (data, _) = try? await URLSession.shared.data(for: req),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        return obj
    }

    private nonisolated static func firstGroup(in text: String, pattern: String) -> String? {
        guard let re = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        guard let m = re.firstMatch(in: text, range: range), m.numberOfRanges > 1,
              let r = Range(m.range(at: 1), in: text) else { return nil }
        return String(text[r])
    }
}
