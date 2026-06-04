import Foundation

/// Transcribes media the user pastes into the chat:
/// - YouTube links → fetches the video's caption track directly over HTTP
///   (no yt-dlp / ffmpeg needed). Works whenever the video has captions or
///   auto-captions.
/// - Local audio/video file paths → on-device Speech (via `Transcriber`).
/// - Direct audio/video URLs (…/clip.mp3) → downloaded, then transcribed.
enum MediaTranscribe {

    static let mediaExts: Set<String> = [
        "m4a", "mp3", "wav", "aiff", "aif", "caf", "aac", "flac",
        "mp4", "mov", "m4v", "avi", "mkv"
    ]

    enum Source {
        case youtube(String)
        case remoteMedia(URL)
        case localFile(URL)
    }

    /// Decide whether a pasted string is transcribable media. Returns nil for
    /// ordinary chat messages so the normal flow is untouched.
    static func detect(_ raw: String) -> Source? {
        let t = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty, !t.contains(" "), t.count < 2048 else { return nil }
        let lower = t.lowercased()

        if lower.contains("youtube.com/watch") || lower.contains("youtu.be/")
            || lower.contains("youtube.com/shorts") || lower.contains("m.youtube.com/watch") {
            return .youtube(t)
        }

        // Local file path.
        if t.hasPrefix("/") || t.hasPrefix("~") || t.hasPrefix("file://") {
            let path: String
            if t.hasPrefix("file://") { path = URL(string: t)?.path ?? t }
            else { path = (t as NSString).expandingTildeInPath }
            let url = URL(fileURLWithPath: path)
            if mediaExts.contains(url.pathExtension.lowercased()),
               FileManager.default.fileExists(atPath: url.path) {
                return .localFile(url)
            }
        }

        // Direct media URL.
        if let url = URL(string: t), let scheme = url.scheme, scheme.hasPrefix("http"),
           mediaExts.contains(url.pathExtension.lowercased()) {
            return .remoteMedia(url)
        }
        return nil
    }

    static func transcribe(_ source: Source) async -> String {
        switch source {
        case .youtube(let s):
            return await youTube(s)
        case .localFile(let url):
            return await Transcriber.transcribe(url)
        case .remoteMedia(let url):
            guard let local = await download(url) else { return "Couldn't download that media URL." }
            return await Transcriber.transcribe(local)
        }
    }

    private static func download(_ url: URL) async -> URL? {
        guard let (data, _) = try? await URLSession.shared.data(from: url) else { return nil }
        let ext = url.pathExtension.isEmpty ? "m4a" : url.pathExtension
        let out = FileManager.default.temporaryDirectory
            .appendingPathComponent("salehman_media_\(UUID().uuidString).\(ext)")
        return ((try? data.write(to: out)) != nil) ? out : nil
    }

    // MARK: - YouTube captions (dependency-free)

    private static let ua = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15"

    static func youTube(_ urlString: String) async -> String {
        guard let watchURL = normalizedWatchURL(urlString) else { return "That doesn't look like a valid YouTube link." }

        var req = URLRequest(url: watchURL)
        req.setValue(ua, forHTTPHeaderField: "User-Agent")
        req.setValue("en-US,en;q=0.9,ar;q=0.8", forHTTPHeaderField: "Accept-Language")
        req.timeoutInterval = 25

        guard let (data, _) = try? await URLSession.shared.data(for: req),
              let html = String(data: data, encoding: .utf8) else {
            return "Couldn't load the YouTube page (no network, or YouTube blocked the request)."
        }

        guard let tracksJSON = firstGroup(in: html, pattern: "\"captionTracks\":(\\[.*?\\])") else {
            return "This video has no captions available to transcribe. (Captions/auto-captions may be turned off for it.)"
        }

        let baseUrls = groups(in: tracksJSON, pattern: "\"baseUrl\":\"(.*?)\"")
        let langs = groups(in: tracksJSON, pattern: "\"languageCode\":\"(.*?)\"")
        guard !baseUrls.isEmpty else { return "No caption tracks were found for this video." }

        // Prefer English, then Arabic, else the first track.
        var idx = 0
        if let i = langs.firstIndex(where: { $0.hasPrefix("en") }) { idx = i }
        else if let i = langs.firstIndex(where: { $0.hasPrefix("ar") }) { idx = i }
        let base = jsonUnescape(baseUrls[min(idx, baseUrls.count - 1)])

        guard let capURL = URL(string: base) else { return "Couldn't read the caption track URL." }
        var capReq = URLRequest(url: capURL)
        capReq.setValue(ua, forHTTPHeaderField: "User-Agent")
        guard let (cdata, _) = try? await URLSession.shared.data(for: capReq),
              let xml = String(data: cdata, encoding: .utf8) else {
            return "Couldn't download the captions."
        }

        let parts = groups(in: xml, pattern: "<text[^>]*>(.*?)</text>")
            .map { decodeEntities(decodeEntities($0)).replacingOccurrences(of: "\n", with: " ") }
        let transcript = parts.joined(separator: " ")
            .replacingOccurrences(of: "  ", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return transcript.isEmpty ? "The captions came back empty." : transcript
    }

    private static func normalizedWatchURL(_ s: String) -> URL? {
        if let id = videoID(from: s) {
            return URL(string: "https://www.youtube.com/watch?v=\(id)")
        }
        return URL(string: s)
    }

    private static func videoID(from s: String) -> String? {
        func after(_ marker: String) -> String? {
            guard let r = s.range(of: marker) else { return nil }
            let rest = String(s[r.upperBound...])
            let id = rest.components(separatedBy: CharacterSet(charactersIn: "&?/#")).first ?? ""
            return id.isEmpty ? nil : id
        }
        return after("v=") ?? after("youtu.be/") ?? after("shorts/")
    }

    // MARK: - Tiny regex + decoding helpers

    private static func firstGroup(in text: String, pattern: String) -> String? {
        groups(in: text, pattern: pattern).first
    }

    private static func groups(in text: String, pattern: String) -> [String] {
        guard let re = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) else { return [] }
        let range = NSRange(text.startIndex..., in: text)
        return re.matches(in: text, range: range).compactMap {
            guard $0.numberOfRanges > 1, let r = Range($0.range(at: 1), in: text) else { return nil }
            return String(text[r])
        }
    }

    private static func jsonUnescape(_ s: String) -> String {
        s.replacingOccurrences(of: "\\u0026", with: "&")
            .replacingOccurrences(of: "\\/", with: "/")
            .replacingOccurrences(of: "\\\"", with: "\"")
    }

    private static func decodeEntities(_ s: String) -> String {
        var r = s
        let map = ["&amp;": "&", "&lt;": "<", "&gt;": ">", "&quot;": "\"",
                   "&#39;": "'", "&#x27;": "'", "&nbsp;": " ", "&apos;": "'"]
        for (k, v) in map { r = r.replacingOccurrences(of: k, with: v) }
        return r
    }
}
