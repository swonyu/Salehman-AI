import SwiftUI

// MARK: - Lightweight syntax highlighter
//
// Per-line, regex-based coloring into a SwiftUI `AttributedString`. Deliberately
// simple (no full parser): good enough to make the Code-tab file viewer + diff
// read like code rather than a wall of monospace. Language-agnostic defaults with
// a `#`-vs-`//` comment token chosen by file extension. Applied in priority order
// so strings/comments override keyword/number coloring that falls inside them.
enum CodeSyntax {
    static let base    = Color.white.opacity(0.9)
    static let keyword = Color(red: 0.92, green: 0.46, blue: 0.70)   // pink
    static let string  = Color(red: 0.94, green: 0.62, blue: 0.42)   // salmon
    static let comment = Color(red: 0.42, green: 0.55, blue: 0.50)   // muted green
    static let number  = Color(red: 0.45, green: 0.78, blue: 0.95)   // cyan
    static let type    = Color(red: 0.40, green: 0.82, blue: 0.76)   // teal

    private static let keywords: Set<String> = [
        // Swift
        "func", "let", "var", "if", "else", "guard", "return", "for", "while", "in", "switch",
        "case", "default", "struct", "class", "enum", "protocol", "extension", "import", "init",
        "deinit", "self", "Self", "nil", "true", "false", "public", "private", "internal",
        "fileprivate", "static", "final", "lazy", "weak", "unowned", "async", "await", "throws",
        "throw", "try", "do", "catch", "defer", "where", "as", "is", "some", "any", "actor",
        "nonisolated", "override", "mutating", "convenience", "required", "associatedtype",
        "typealias", "subscript", "get", "set", "willSet", "didSet", "repeat", "break",
        "continue", "fallthrough", "inout", "operator",
        // common cross-language
        "def", "from", "function", "const", "new", "void", "int", "float", "double", "bool",
        "string", "null", "undefined", "print", "then", "end", "elif", "lambda", "yield",
        "with", "not", "and", "or", "None", "True", "False",
    ]

    private static let keywordRE: NSRegularExpression? = {
        let body = keywords.map(NSRegularExpression.escapedPattern(for:)).joined(separator: "|")
        return try? NSRegularExpression(pattern: "\\b(?:\(body))\\b")
    }()
    private static let numberRE = try? NSRegularExpression(pattern: #"\b\d[\d_]*(?:\.\d+)?\b"#)
    private static let typeRE   = try? NSRegularExpression(pattern: #"\b[A-Z][A-Za-z0-9_]*\b"#)
    private static let stringRE = try? NSRegularExpression(pattern: #""(?:[^"\\]|\\.)*"|'(?:[^'\\]|\\.)*'"#)
    private static let hashCommentExts: Set<String> = ["py", "rb", "sh", "zsh", "bash", "yml", "yaml", "toml", "r", "pl", "rake", "gemspec"]

    static func highlight(_ line: String, ext: String) -> AttributedString {
        var a = AttributedString(line)
        a.foregroundColor = base
        guard !line.isEmpty else { return a }
        apply(typeRE, &a, line, type)
        apply(numberRE, &a, line, number)
        apply(keywordRE, &a, line, keyword)
        apply(stringRE, &a, line, string)                 // override inside strings
        applyLineComment(&a, line, ext)                   // override to end of line
        return a
    }

    private static func apply(_ re: NSRegularExpression?, _ a: inout AttributedString, _ line: String, _ color: Color) {
        guard let re else { return }
        let ns = line as NSString
        for m in re.matches(in: line, range: NSRange(location: 0, length: ns.length)) {
            if let r = Range(m.range, in: line) {
                setColor(&a, line, r, color)
            }
        }
    }

    private static func applyLineComment(_ a: inout AttributedString, _ line: String, _ ext: String) {
        let token = hashCommentExts.contains(ext.lowercased()) ? "#" : "//"
        guard let r = line.range(of: token) else { return }
        setColor(&a, line, r.lowerBound..<line.endIndex, comment)
    }

    /// Apply `color` to the character range of `line` (mapped onto the AttributedString).
    private static func setColor(_ a: inout AttributedString, _ line: String, _ range: Range<String.Index>, _ color: Color) {
        let start = line.distance(from: line.startIndex, to: range.lowerBound)
        let len = line.distance(from: range.lowerBound, to: range.upperBound)
        guard len > 0 else { return }
        let chars = a.characters
        guard let lo = chars.index(chars.startIndex, offsetBy: start, limitedBy: chars.endIndex),
              let hi = chars.index(lo, offsetBy: len, limitedBy: chars.endIndex) else { return }
        a[lo..<hi].foregroundColor = color
    }
}

// MARK: - Line-numbered, syntax-highlighted read-only code viewer
//
// Pure SwiftUI: a LazyVStack of `lineNumber + highlighted line` rows inside a
// 2-axis ScrollView. Lazy → only visible lines are highlighted, so big files stay
// smooth; `.fixedSize(horizontal:)` keeps long lines from wrapping (horizontal
// scroll instead). Per-line text selection.
struct CodeTextView: View {
    let content: String
    let ext: String

    private var lines: [String] {
        content.isEmpty ? [] : content.components(separatedBy: "\n")
    }

    var body: some View {
        if lines.isEmpty {
            Text("‹empty file›")
                .font(.system(size: 11.5, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            let gutter = String(lines.count).count
            ScrollView([.vertical, .horizontal]) {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(lines.enumerated()), id: \.offset) { i, line in
                        HStack(alignment: .top, spacing: 12) {
                            Text(String(format: "%\(gutter)d", i + 1))
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.26))
                            Text(CodeSyntax.highlight(line, ext: ext))
                                .font(.system(size: 11.5, design: .monospaced))
                                .textSelection(.enabled)
                                .fixedSize(horizontal: true, vertical: false)
                        }
                        .padding(.horizontal, 10)
                    }
                }
                .padding(.vertical, 8)
            }
        }
    }
}
