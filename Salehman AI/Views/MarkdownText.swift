import SwiftUI
import AppKit

/// Lightweight markdown renderer: handles fenced ``` code blocks (styled, with a
/// copy button) and renders the rest with inline markdown (bold, italic, links,
/// inline code). No third-party dependencies.
struct MarkdownText: View {
    let text: String

    var body: some View {
        let parsed = MarkdownText.segments(for: text)
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(parsed.enumerated()), id: \.offset) { _, segment in
                switch segment {
                case .code(let language, let code):
                    CodeBlock(language: language, code: code)
                case .text(let body):
                    // Render block-by-block so `##` headings and `- `/`1.` lists
                    // read as real structure instead of literal "##"/"-" text.
                    VStack(alignment: .leading, spacing: 5) {
                        ForEach(Array(body.components(separatedBy: "\n").enumerated()), id: \.offset) { _, raw in
                            MarkdownText.lineView(raw)
                        }
                    }
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    // MARK: Parsing
    enum Segment {
        case text(String)
        case code(language: String, code: String)
    }

    // Cache parsed segments + attributed strings so each MessageBubble redraw
    // doesn't re-parse the same body. Cap entries so the cache doesn't grow
    // without bound when the chat is long.
    private static let cacheLock = NSLock()
    nonisolated(unsafe) private static var segmentCache: [String: [Segment]] = [:]
    nonisolated(unsafe) private static var attributedCache: [String: AttributedString] = [:]
    private static let maxCacheEntries = 200

    static func segments(for text: String) -> [Segment] {
        cacheLock.lock()
        if let cached = segmentCache[text] {
            cacheLock.unlock()
            return cached
        }
        cacheLock.unlock()

        let parsed = parseSegments(text)

        cacheLock.lock()
        if segmentCache.count >= maxCacheEntries {
            segmentCache.removeAll(keepingCapacity: true)
        }
        segmentCache[text] = parsed
        cacheLock.unlock()
        return parsed
    }

    private static func parseSegments(_ text: String) -> [Segment] {
        var result: [Segment] = []
        let lines = text.components(separatedBy: "\n")
        var inCode = false
        var codeLang = ""
        var buffer: [String] = []

        func flushText() {
            let joined = buffer.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            if !joined.isEmpty { result.append(.text(joined)) }
            buffer.removeAll(keepingCapacity: true)
        }
        func flushCode() {
            result.append(.code(language: codeLang, code: buffer.joined(separator: "\n")))
            buffer.removeAll(keepingCapacity: true)
        }

        for line in lines {
            if line.trimmingCharacters(in: .whitespaces).hasPrefix("```") {
                if inCode {
                    flushCode(); inCode = false; codeLang = ""
                } else {
                    flushText(); inCode = true
                    codeLang = line.trimmingCharacters(in: .whitespaces)
                        .replacingOccurrences(of: "```", with: "")
                }
            } else {
                buffer.append(line)
            }
        }
        if inCode { flushCode() } else { flushText() }
        return result
    }

    static func inlineMarkdown(_ s: String) -> AttributedString {
        cacheLock.lock()
        if let hit = attributedCache[s] {
            cacheLock.unlock()
            return hit
        }
        cacheLock.unlock()

        let attr = (try? AttributedString(markdown: s, options: .init(
            interpretedSyntax: .inlineOnlyPreservingWhitespace))) ?? AttributedString(s)

        cacheLock.lock()
        if attributedCache.count >= maxCacheEntries {
            attributedCache.removeAll(keepingCapacity: true)
        }
        attributedCache[s] = attr
        cacheLock.unlock()
        return attr
    }

    /// Render one source line with block-level styling (headings, bullets,
    /// numbered items) on top of the inline markdown. LLM replies lean on `##`
    /// headings and `- ` lists that the old single-`Text` renderer showed as
    /// literal "##" / "-" — this makes them read as real document structure.
    @ViewBuilder
    static func lineView(_ raw: String) -> some View {
        let trimmed = raw.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty {
            Color.clear.frame(height: 3)
        } else if let h = heading(trimmed) {
            Text(inlineMarkdown(h.text))
                .font(.system(size: h.level == 1 ? 19 : (h.level == 2 ? 16 : 14.5),
                              weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .padding(.top, 3)
        } else if let item = bullet(trimmed) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("•").font(.system(size: 14, weight: .bold)).foregroundStyle(DS.Palette.accent)
                Text(inlineMarkdown(item)).font(.system(size: 14))
            }
            .padding(.leading, 2)
        } else if let num = numbered(trimmed) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(num.marker).font(.system(size: 13.5, weight: .semibold)).foregroundStyle(DS.Palette.accent)
                Text(inlineMarkdown(num.text)).font(.system(size: 14))
            }
            .padding(.leading, 2)
        } else if trimmed == "---" || trimmed == "***" || trimmed == "___" {
            Rectangle()
                .fill(DS.Palette.surfaceStroke)
                .frame(height: 1)
                .padding(.vertical, 4)
        } else if let quote = blockquote(trimmed) {
            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(DS.Palette.accent.opacity(0.7))
                    .frame(width: 3)
                Text(inlineMarkdown(quote))
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
            }
            .fixedSize(horizontal: false, vertical: true)
        } else {
            Text(inlineMarkdown(raw)).font(.system(size: 14))
        }
    }

    /// `#`/`##`/`###` heading → (level, text).
    private static func heading(_ s: String) -> (level: Int, text: String)? {
        for level in [3, 2, 1] {
            let hashes = String(repeating: "#", count: level) + " "
            if s.hasPrefix(hashes) { return (level, String(s.dropFirst(hashes.count))) }
        }
        return nil
    }
    /// `- ` / `* ` / `• ` bullet → item text.
    private static func bullet(_ s: String) -> String? {
        for p in ["- ", "* ", "• "] where s.hasPrefix(p) { return String(s.dropFirst(p.count)) }
        return nil
    }
    /// `> ` blockquote → quoted text (`>` alone → empty quoted line).
    private static func blockquote(_ s: String) -> String? {
        if s == ">" { return "" }
        if s.hasPrefix("> ") { return String(s.dropFirst(2)) }
        return nil
    }
    /// `12. ` numbered → (marker "12.", text). Won't match decimals like "3.14".
    private static func numbered(_ s: String) -> (marker: String, text: String)? {
        guard let dot = s.firstIndex(of: ".") else { return nil }
        let numPart = s[s.startIndex..<dot]
        let afterDot = s.index(after: dot)
        guard !numPart.isEmpty, numPart.allSatisfy(\.isNumber),
              afterDot < s.endIndex, s[afterDot] == " " else { return nil }
        return (String(numPart) + ".", String(s[s.index(after: afterDot)...]))
    }
}

struct CodeBlock: View {
    let language: String
    let code: String
    @State private var copied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                // Tinted uppercase language badge (was plain grey text).
                Text((language.isEmpty ? "code" : language).uppercased())
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .tracking(0.5)
                    .foregroundStyle(DS.Palette.accent)
                    .padding(.horizontal, 7).padding(.vertical, 3)
                    .background(DS.Palette.accent.opacity(0.14), in: Capsule())
                Spacer()
                Button {
                    copyToClipboard(code)
                    copied = true
                    Task { try? await Task.sleep(nanoseconds: 1_200_000_000); copied = false }
                } label: {
                    Label(copied ? "Copied" : "Copy", systemImage: copied ? "checkmark" : "doc.on.doc")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(copied ? DS.Palette.successSoft : .secondary)
                        // Comfortable hit target: the tight 10pt label is hard
                        // to land on with assistive pointers / Voice Control.
                        // `.contentShape` over a minimum frame keeps the visual
                        // tight while making the WHOLE padded zone clickable.
                        .frame(minWidth: 56, minHeight: 24, alignment: .trailing)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Copy code to clipboard")
                .accessibilityLabel(copied ? "Copied" : "Copy code to clipboard")
            }
            .padding(.horizontal, 12).padding(.vertical, 7)
            .background(Color.white.opacity(0.04))

            ScrollView(.horizontal, showsIndicators: false) {
                Text(code)
                    .font(.system(size: 12.5, design: .monospaced))
                    // Neutral off-white instead of harsh terminal-green — easier
                    // to read in a chat context; line-spacing for breathing room.
                    .foregroundStyle(Color.white.opacity(0.92))
                    .lineSpacing(3)
                    .textSelection(.enabled)
                    .padding(12)
            }
        }
        .frame(maxWidth: 520, alignment: .leading)
        .background(Color.black.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous).stroke(Color.white.opacity(0.1), lineWidth: 1))
    }

    private func copyToClipboard(_ s: String) {
        #if canImport(AppKit)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(s, forType: .string)
        #endif
    }
}
