import SwiftUI
import AppKit

/// Lightweight markdown renderer: handles fenced ``` code blocks (styled, with a
/// copy button) and renders the rest with inline markdown (bold, italic, links,
/// inline code). No third-party dependencies.
struct MarkdownText: View {
    let text: String
    /// Find-in-conversation term to highlight (case-insensitive). Empty = no
    /// highlight, the common path. Threaded down to every rendered run so a
    /// match lights up wherever it lands — prose, list item, table cell, code.
    var highlight: String = ""

    var body: some View {
        let parsed = MarkdownText.segments(for: text)
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(parsed.enumerated()), id: \.offset) { _, segment in
                switch segment {
                case .code(let language, let code):
                    CodeBlock(language: language, code: code, highlight: highlight)
                case .text(let body):
                    // Render block-by-block so `##` headings, `- `/`1.` lists, and
                    // `| a | b |` tables read as real structure instead of literal text.
                    VStack(alignment: .leading, spacing: 5) {
                        ForEach(Array(MarkdownText.blocks(for: body).enumerated()), id: \.offset) { _, block in
                            switch block {
                            case .table(let header, let rows):
                                MarkdownText.tableView(header: header, rows: rows, highlight: highlight)
                            case .lines(let chunk):
                                VStack(alignment: .leading, spacing: 5) {
                                    ForEach(Array(chunk.components(separatedBy: "\n").enumerated()), id: \.offset) { _, raw in
                                        MarkdownText.lineView(raw, highlight: highlight)
                                    }
                                }
                            }
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
    nonisolated private static let cacheLock = NSLock()
    nonisolated(unsafe) private static var segmentCache: [String: [Segment]] = [:]
    nonisolated(unsafe) private static var attributedCache: [String: AttributedString] = [:]
    nonisolated private static let maxCacheEntries = 200

    nonisolated static func segments(for text: String) -> [Segment] {
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

    nonisolated private static func parseSegments(_ text: String) -> [Segment] {
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

    nonisolated static func inlineMarkdown(_ s: String) -> AttributedString {
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

    /// Amber wash painted behind find-in-conversation matches. Deliberately NOT
    /// the red brand accent — red reads as "error/active brain" in this UI and
    /// would muddy the meaning of a match. Amber is the universal "found it" cue.
    nonisolated private static let highlightWash = Color(red: 1.0, green: 0.80, blue: 0.30).opacity(0.32)

    /// Overlay a search highlight on an already-rendered (and cached) attributed
    /// string. Applied AFTER the markdown cache so the parse cache stays
    /// query-independent — only this cheap O(text) attribute pass re-runs as the
    /// query changes. Highlights EVERY case-insensitive occurrence, not just the
    /// first. Returns `base` untouched when `query` is blank (the hot path).
    nonisolated static func highlighted(_ base: AttributedString, query: String) -> AttributedString {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return base }
        var out = base
        var cursor = out.startIndex
        // Setting color attributes never changes the character count, so indices
        // stay valid across iterations — we just walk forward past each hit.
        while cursor < out.endIndex,
              let hit = out[cursor..<out.endIndex].range(of: q, options: .caseInsensitive) {
            out[hit].backgroundColor = highlightWash
            out[hit].foregroundColor = .white   // matches pop a touch over the 0.92 body
            cursor = hit.upperBound
        }
        return out
    }

    /// Render one source line with block-level styling (headings, bullets,
    /// numbered items) on top of the inline markdown. LLM replies lean on `##`
    /// headings and `- ` lists that the old single-`Text` renderer showed as
    /// literal "##" / "-" — this makes them read as real document structure.
    @ViewBuilder
    static func lineView(_ raw: String, highlight: String = "") -> some View {
        let trimmed = raw.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty {
            Color.clear.frame(height: 3)
        } else if let h = heading(trimmed) {
            Text(highlighted(inlineMarkdown(h.text), query: highlight))
                .font(.system(size: h.level == 1 ? 19 : (h.level == 2 ? 16 : 14.5),
                              weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .padding(.top, 3)
        } else if let item = bullet(trimmed) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("•").font(.system(size: 14, weight: .bold)).foregroundStyle(DS.Palette.accent)
                Text(highlighted(inlineMarkdown(item), query: highlight)).font(.system(size: 14))
            }
            .padding(.leading, 2)
        } else if let num = numbered(trimmed) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(num.marker).font(.system(size: 13.5, weight: .semibold)).foregroundStyle(DS.Palette.accent)
                Text(highlighted(inlineMarkdown(num.text), query: highlight)).font(.system(size: 14))
            }
            .padding(.leading, 2)
        } else if trimmed == "---" || trimmed == "***" || trimmed == "___" {
            Rectangle()
                .fill(DS.Palette.surfaceStroke)
                .frame(height: 1)
                .padding(.vertical, 4)
        } else if let quote = blockquote(trimmed) {
            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                    .fill(DS.Palette.accent.opacity(0.7))
                    .frame(width: 3)
                Text(highlighted(inlineMarkdown(quote), query: highlight))
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
            }
            .fixedSize(horizontal: false, vertical: true)
        } else {
            Text(highlighted(inlineMarkdown(raw), query: highlight)).font(.system(size: 14))
        }
    }

    /// `#`/`##`/`###` heading → (level, text).
    nonisolated private static func heading(_ s: String) -> (level: Int, text: String)? {
        for level in [3, 2, 1] {
            let hashes = String(repeating: "#", count: level) + " "
            if s.hasPrefix(hashes) { return (level, String(s.dropFirst(hashes.count))) }
        }
        return nil
    }
    /// `- ` / `* ` / `• ` bullet → item text.
    nonisolated private static func bullet(_ s: String) -> String? {
        for p in ["- ", "* ", "• "] where s.hasPrefix(p) { return String(s.dropFirst(p.count)) }
        return nil
    }
    /// `> ` blockquote → quoted text (`>` alone → empty quoted line).
    nonisolated private static func blockquote(_ s: String) -> String? {
        if s == ">" { return "" }
        if s.hasPrefix("> ") { return String(s.dropFirst(2)) }
        return nil
    }
    /// `12. ` numbered → (marker "12.", text). Won't match decimals like "3.14".
    nonisolated private static func numbered(_ s: String) -> (marker: String, text: String)? {
        guard let dot = s.firstIndex(of: ".") else { return nil }
        let numPart = s[s.startIndex..<dot]
        let afterDot = s.index(after: dot)
        guard !numPart.isEmpty, numPart.allSatisfy(\.isNumber),
              afterDot < s.endIndex, s[afterDot] == " " else { return nil }
        return (String(numPart) + ".", String(s[s.index(after: afterDot)...]))
    }

    // MARK: Tables

    /// A parsed block within a text segment: a GFM table, or a run of plain lines
    /// (rendered line-by-line by `lineView`, preserving all existing behaviour).
    enum Block {
        case table(header: [String], rows: [[String]])
        case lines(String)
    }

    /// Split a text body into table blocks + plain-line runs. A table is a `|…|`
    /// row immediately followed by a `|---|` separator, then zero+ `|…|` rows.
    nonisolated static func blocks(for body: String) -> [Block] {
        let lines = body.components(separatedBy: "\n")
        var blocks: [Block] = []
        var lineBuf: [String] = []
        func flush() {
            if !lineBuf.isEmpty { blocks.append(.lines(lineBuf.joined(separator: "\n"))); lineBuf.removeAll() }
        }
        var i = 0
        while i < lines.count {
            if isTableRow(lines[i]), i + 1 < lines.count, isTableSeparator(lines[i + 1]) {
                flush()
                let header = tableCells(lines[i])
                var rows: [[String]] = []
                i += 2
                while i < lines.count, isTableRow(lines[i]) { rows.append(tableCells(lines[i])); i += 1 }
                blocks.append(.table(header: header, rows: rows))
            } else {
                lineBuf.append(lines[i]); i += 1
            }
        }
        flush()
        return blocks
    }

    nonisolated private static func isTableRow(_ s: String) -> Bool {
        let t = s.trimmingCharacters(in: .whitespaces)
        return t.hasPrefix("|") && t.dropFirst().contains("|")
    }
    /// A `|---|:--:|` separator line: every cell is only dashes/colons.
    nonisolated private static func isTableSeparator(_ s: String) -> Bool {
        let cells = tableCells(s)
        guard !cells.isEmpty else { return false }
        return cells.allSatisfy { cell in
            let c = cell.trimmingCharacters(in: .whitespaces)
            return !c.isEmpty && c.allSatisfy { $0 == "-" || $0 == ":" }
        }
    }
    nonisolated private static func tableCells(_ s: String) -> [String] {
        var t = s.trimmingCharacters(in: .whitespaces)
        if t.hasPrefix("|") { t.removeFirst() }
        if t.hasSuffix("|") { t.removeLast() }
        return t.components(separatedBy: "|").map { $0.trimmingCharacters(in: .whitespaces) }
    }

    /// Render a parsed table as an aligned grid with a bold header row.
    /// Cells CAP at 300pt and WRAP — a Grid otherwise sizes columns to each cell's
    /// ideal (single-line) width, so long cells overflowed the message column and
    /// were clipped mid-word (owner hit this). Wide tables h-scroll as the escape.
    @ViewBuilder
    static func tableView(header: [String], rows: [[String]], highlight: String = "") -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            Grid(alignment: .topLeading, horizontalSpacing: 16, verticalSpacing: 6) {
                GridRow {
                    ForEach(Array(header.enumerated()), id: \.offset) { _, cell in
                        Text(highlighted(inlineMarkdown(cell), query: highlight))
                            .font(.system(size: 13.5, weight: .bold)).foregroundStyle(.white)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: 300, alignment: .leading)
                    }
                }
                Divider().overlay(DS.Palette.surfaceStroke).gridCellColumns(max(1, header.count))
                ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                    GridRow {
                        ForEach(Array(row.enumerated()), id: \.offset) { _, cell in
                            Text(highlighted(inlineMarkdown(cell), query: highlight)).font(.system(size: 13.5))
                                .fixedSize(horizontal: false, vertical: true)
                                .frame(maxWidth: 300, alignment: .leading)
                        }
                    }
                }
            }
            .padding(10)
        }
        .background(Color.white.opacity(0.03), in: RoundedRectangle(cornerRadius: DS.Radius.small, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: DS.Radius.small, style: .continuous).stroke(DS.Palette.surfaceStroke, lineWidth: 1))
    }
}

struct CodeBlock: View {
    let language: String
    let code: String
    /// Find-in-conversation term, painted over the syntax colors. Empty = none.
    var highlight: String = ""
    @State private var copied = false

    /// Map a fenced-block language label → an extension `CodeSyntax` understands
    /// (it only uses `ext` to pick the comment token, `#` vs `//`).
    private var ext: String {
        switch language.lowercased() {
        case "python", "py":                                  return "py"
        case "bash", "sh", "shell", "zsh", "console", "terminal": return "sh"
        case "ruby", "rb":                                    return "rb"
        case "yaml", "yml":                                   return "yml"
        case "toml":                                          return "toml"
        default:                                              return language.lowercased()
        }
    }

    /// Whole-block syntax highlighting as a single `AttributedString`, so the block
    /// stays one selectable run (per-line `Text` would break multi-line selection).
    /// Very large blocks fall back to plain text — highlighting re-runs on every
    /// redraw (incl. token-by-token while streaming), which is O(n²) on size.
    private var highlightedCode: AttributedString {
        let base: AttributedString
        if code.count < 6000 {
            let lines = code.components(separatedBy: "\n")
            var result = AttributedString()
            for (i, line) in lines.enumerated() {
                result.append(CodeSyntax.highlight(line, ext: ext))
                if i < lines.count - 1 { result.append(AttributedString("\n")) }
            }
            base = result
        } else {
            // Big block: skip syntax highlighting (O(n²) on every redraw).
            var a = AttributedString(code); a.foregroundColor = CodeSyntax.base; base = a
        }
        // Search highlight is a cheap attribute pass, applied even on the big-block
        // fallback so a match in a long block still lights up.
        return MarkdownText.highlighted(base, query: highlight)
    }

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
                        .contentTransition(.symbolEffect(.replace))
                        .animation(DS.Motion.smooth, value: copied)
                        // Comfortable hit target: the tight 10pt label is hard
                        // to land on with assistive pointers / Voice Control.
                        // `.contentShape` over a minimum frame keeps the visual
                        // tight while making the WHOLE padded zone clickable.
                        .frame(minWidth: 56, minHeight: 24, alignment: .trailing)
                        .contentShape(Rectangle())
                }
                .buttonStyle(LuxPressStyle())
                .help("Copy code to clipboard")
                .accessibilityLabel(copied ? "Copied" : "Copy code to clipboard")
            }
            .padding(.horizontal, 12).padding(.vertical, 7)
            .background(Color.white.opacity(0.04))

            ScrollView(.horizontal, showsIndicators: false) {
                // Syntax-highlighted (keywords/types/strings/numbers/comments) via
                // the same CodeSyntax engine the file/diff viewers use — one
                // AttributedString so the whole block stays selectable.
                Text(highlightedCode)
                    .font(.system(size: 12.5, design: .monospaced))
                    .lineSpacing(3)
                    .textSelection(.enabled)
                    .padding(12)
            }
        }
        .frame(maxWidth: 520, alignment: .leading)
        .background(Color.black.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous).stroke(DS.Palette.surfaceStroke, lineWidth: 1))
    }

    private func copyToClipboard(_ s: String) {
        #if canImport(AppKit)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(s, forType: .string)
        #endif
    }
}
