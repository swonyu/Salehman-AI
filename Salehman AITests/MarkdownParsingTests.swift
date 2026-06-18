import Testing
import Foundation
@testable import Salehman_AI

// MARK: - MarkdownText parsing — segments (fenced code) + blocks (tables)
//
// MarkdownText renders EVERY chat/code reply, yet its two pure parsers had no
// coverage. These exercise the real contracts: code fences split correctly and
// preserve whitespace (code must not be trimmed), prose is trimmed, and GFM
// tables are recognised only when a `|---|` separator follows the header row.
// Added EOCO (2026-06-14) during the measurement-driven bug-hunt.

private func textOf(_ s: MarkdownText.Segment) -> String? {
    if case .text(let t) = s { return t }
    return nil
}
private func codeOf(_ s: MarkdownText.Segment) -> (lang: String, code: String)? {
    if case .code(let l, let c) = s { return (l, c) }
    return nil
}

struct MarkdownSegmentTests {

    @Test func plainTextIsOneTextSegment() {
        let segs = MarkdownText.segments(for: "Just plain prose.")
        #expect(segs.count == 1)
        #expect(textOf(segs[0]) == "Just plain prose.")
    }

    @Test func emptyStringYieldsNoSegments() {
        #expect(MarkdownText.segments(for: "").isEmpty)
    }

    @Test func fencedCodeExtractsLanguageAndBody() {
        let segs = MarkdownText.segments(for: "```swift\nlet x = 1\n```")
        #expect(segs.count == 1)
        #expect(codeOf(segs[0])?.lang == "swift")
        #expect(codeOf(segs[0])?.code == "let x = 1")
    }

    @Test func textCodeTextKeepsOrder() {
        let segs = MarkdownText.segments(for: "before\n```\ncode\n```\nafter")
        #expect(segs.count == 3)
        #expect(textOf(segs[0]) == "before")
        #expect(codeOf(segs[1])?.code == "code")
        #expect(textOf(segs[2]) == "after")
    }

    @Test func codePreservesIndentationButProseIsTrimmed() {
        // Code whitespace is significant → must NOT be trimmed.
        let code = MarkdownText.segments(for: "```\n    indented\n```")
        #expect(codeOf(code[0])?.code == "    indented")
        // Surrounding blank lines around prose ARE trimmed.
        let prose = MarkdownText.segments(for: "\n\nhello\n\n")
        #expect(prose.count == 1)
        #expect(textOf(prose[0]) == "hello")
    }

    @Test func unclosedFenceStillBecomesCode() {
        // Model cut off mid-block: the remainder is treated as a code segment.
        let segs = MarkdownText.segments(for: "```\nunfinished code")
        #expect(segs.count == 1)
        #expect(codeOf(segs[0])?.code == "unfinished code")
    }

    @Test func tripleBacktickMidLineIsNotAFence() {
        // A line must START with ``` (after trimming) to toggle a fence.
        let segs = MarkdownText.segments(for: "use ``` carefully in prose")
        #expect(segs.count == 1)
        #expect(textOf(segs[0]) == "use ``` carefully in prose")
    }
}

struct MarkdownBlockTests {

    @Test func plainLinesAreOneLinesBlock() {
        let blocks = MarkdownText.blocks(for: "line one\nline two")
        #expect(blocks.count == 1)
        if case .lines(let s) = blocks[0] { #expect(s == "line one\nline two") }
        else { Issue.record("expected .lines") }
    }

    @Test func validTableParsesHeaderAndRows() {
        let blocks = MarkdownText.blocks(for: "| A | B |\n|---|---|\n| 1 | 2 |\n| 3 | 4 |")
        #expect(blocks.count == 1)
        guard case .table(let header, let rows) = blocks[0] else {
            Issue.record("expected .table"); return
        }
        #expect(header == ["A", "B"])
        #expect(rows.count == 2)
        #expect(rows[0] == ["1", "2"])
        #expect(rows[1] == ["3", "4"])
    }

    @Test func pipeRowWithoutSeparatorIsNotATable() {
        // A `|…|` row is only a table when a `|---|` separator follows it.
        let blocks = MarkdownText.blocks(for: "| A | B |\nnot a separator line")
        #expect(blocks.count == 1)
        if case .lines = blocks[0] {} else { Issue.record("expected .lines, not a table") }
    }

    @Test func tableIsBracketedByProse() {
        let body = "intro paragraph\n| H |\n|---|\n| v |\noutro paragraph"
        let blocks = MarkdownText.blocks(for: body)
        #expect(blocks.count == 3)
        if case .lines(let a) = blocks[0] { #expect(a == "intro paragraph") } else { Issue.record("0=.lines") }
        if case .table(let h, let r) = blocks[1] { #expect(h == ["H"]); #expect(r == [["v"]]) } else { Issue.record("1=.table") }
        if case .lines(let z) = blocks[2] { #expect(z == "outro paragraph") } else { Issue.record("2=.lines") }
    }

    @Test func alignmentSeparatorWithColonsIsRecognised() {
        // GFM alignment markers (:--, :-:, --:) are valid separators.
        let blocks = MarkdownText.blocks(for: "| L | C | R |\n| :-- | :-: | --: |\n| a | b | c |")
        guard case .table(let header, let rows) = blocks[0] else {
            Issue.record("expected .table with colon-alignment separator"); return
        }
        #expect(header == ["L", "C", "R"])
        #expect(rows[0] == ["a", "b", "c"])
    }

    @Test func raggedRowWithFewerCellsIsKeptAsIs() {
        // Lenient by design: a short row renders fewer cells (the Grid renderer
        // iterates each row's own cells, so this never indexes out of range).
        let blocks = MarkdownText.blocks(for: "| A | B |\n|---|---|\n| 1 |")
        guard case .table(let header, let rows) = blocks[0] else {
            Issue.record("expected .table"); return
        }
        #expect(header.count == 2)
        #expect(rows[0] == ["1"])   // one cell, not padded to header width
    }
}
