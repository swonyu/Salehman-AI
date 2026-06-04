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
                    Text(MarkdownText.inlineMarkdown(body))
                        .font(.system(size: 14))
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
}

struct CodeBlock: View {
    let language: String
    let code: String
    @State private var copied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(language.isEmpty ? "code" : language)
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    copyToClipboard(code)
                    copied = true
                    Task { try? await Task.sleep(nanoseconds: 1_200_000_000); copied = false }
                } label: {
                    Label(copied ? "Copied" : "Copy", systemImage: copied ? "checkmark" : "doc.on.doc")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(copied ? .green : .secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12).padding(.vertical, 7)
            .background(Color.white.opacity(0.05))

            ScrollView(.horizontal, showsIndicators: false) {
                Text(code)
                    .font(.system(size: 12.5, design: .monospaced))
                    .foregroundStyle(Color.green.opacity(0.92))
                    .textSelection(.enabled)
                    .padding(12)
            }
        }
        .background(Color.black.opacity(0.45))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(Color.white.opacity(0.1), lineWidth: 1))
    }

    private func copyToClipboard(_ s: String) {
        #if canImport(AppKit)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(s, forType: .string)
        #endif
    }
}
