import Testing
import Foundation
@testable import Salehman_AI

// MARK: - GrokWatchTool.parse — Grok session log parsing contract
//
// `parse` converts the raw text of a Grok terminal-bridge session log into a
// compact summary. It has five distinct extraction paths:
//
//   1. Task extraction: "task: '...'" in the first 5 lines → Task: line.
//   2. Turn counting + elapsed time: "── turn N ──" headers with "[HH:MM:SS|XmYYs]" prefix.
//   3. CMD/output pairs: "CMD: <command>" line → collect subsequent non-bridge lines as output.
//   4. DONE detection: "[[DONE]]" or "TASK_COMPLETED_SUCCESSFULLY" anywhere in log.
//   5. Recent-pair ring buffer: keeps the last 6 CMD/output pairs, oldest dropped first.
//
// `parse` was made `internal` (was `private`) so these tests can reach it
// without touching the filesystem.

struct GrokWatchToolParseTests {

    // MARK: - task extraction

    @Test func extractsTaskFromHeader() {
        let log = "→ session abc123  task: 'Add authentication middleware'\n\n"
        let out = GrokWatchTool.parse(log, filename: "abc123.log")
        #expect(out.contains("Add authentication middleware"),
                "task must be extracted from the 'task: ...' header line")
        #expect(out.contains("Task: Add authentication middleware"))
    }

    @Test func escapedQuoteInTaskIsUnescaped() {
        // Grok logs escape internal single quotes as "\'" — the parser should
        // convert them back to "'".
        let log = "→ session s1  task: 'Fix the can\\'t parse bug'\n"
        let out = GrokWatchTool.parse(log, filename: "s1.log")
        #expect(out.contains("Fix the can't parse bug"),
                "\\' must be unescaped to ' in the task string")
    }

    @Test func longTaskIsTruncatedAt180Chars() {
        let long = String(repeating: "x", count: 200)
        let log = "→ session s2  task: '\(long)'\n"
        let out = GrokWatchTool.parse(log, filename: "s2.log")
        // The task line must be present and truncated with "…"
        #expect(out.contains("Task:"), "task line must appear for a long task")
        let taskLine = out.components(separatedBy: "\n").first { $0.hasPrefix("Task: ") }
        guard let t = taskLine else { Issue.record("Task: line not found"); return }
        #expect(t.hasSuffix("…"), "long task must be truncated with …")
        // 180 chars + "…" = 181 chars after the "Task: " prefix
        let payload = String(t.dropFirst(6)) // drop "Task: "
        #expect(payload.count <= 181,
                "task payload must not exceed 181 chars (180 + ellipsis)")
    }

    @Test func noTaskLineWhenHeaderAbsent() {
        let log = "[00:00:01|0m01s] → ── turn 1 ──\nCMD: ls\nsome output\n"
        let out = GrokWatchTool.parse(log, filename: "notask.log")
        #expect(!out.contains("Task:"),
                "Task: line must be absent when no 'task: ...' header is present")
    }

    // MARK: - session ID and turn counting

    @Test func sessionIDComesFromFilenameWithoutExtension() {
        let log = ""
        let out = GrokWatchTool.parse(log, filename: "grok_2026_session_42.log")
        #expect(out.hasPrefix("Grok session grok_2026_session_42"),
                "session ID must be the filename without its .log extension")
    }

    @Test func turnCounterIncreasesOnEachTurnHeader() {
        let log = """
[00:00:01|0m01s] → ── turn 1 ──
CMD: echo hi
hi

[00:02:00|2m00s] → ── turn 2 ──
CMD: ls
file.txt

"""
        let out = GrokWatchTool.parse(log, filename: "s.log")
        #expect(out.contains("Turns so far: 2"),
                "turn count must equal the number of '── turn N ──' headers")
    }

    @Test func elapsedTimeExtractedFromTurnHeader() {
        let log = "[00:05:30|5m30s] → ── turn 3 ──\nCMD: git status\n\n"
        let out = GrokWatchTool.parse(log, filename: "s.log")
        #expect(out.contains("5m30s"),
                "elapsed time (pipe-to-bracket segment) must appear in the summary")
    }

    // MARK: - CMD / output pairs

    @Test func cmdLineAppearsInRecentPairs() {
        let log = "[00:00:01|0m01s] → ── turn 1 ──\nCMD: swift build\nbuild output here\n\n"
        let out = GrokWatchTool.parse(log, filename: "s.log")
        #expect(out.contains("swift build"),
                "CMD value must appear in the 'Last N command(s)' block")
        #expect(out.contains("build output here"),
                "output lines after CMD must appear in the summary")
    }

    @Test func bridgeLinesAreFilteredFromOutput() {
        // Lines starting with "[", "→", "✓", or containing "sending output back"
        // are bridge meta-lines and must be excluded from the collected output.
        let log = """
[00:00:01|0m01s] → ── turn 1 ──
CMD: ls
[bridge: sending output back to grok]
→ routing through channel
✓ confirmed
actual_file.txt

"""
        let out = GrokWatchTool.parse(log, filename: "s.log")
        #expect(out.contains("actual_file.txt"),
                "real output lines must pass through the filter")
        #expect(!out.contains("sending output back"),
                "bridge meta-lines must be filtered out")
        #expect(!out.contains("routing through channel"),
                "bridge → lines must be filtered out")
    }

    @Test func outputTruncatedAt120Chars() {
        let long = String(repeating: "z", count: 130)
        let log = "[00:00:01|0m01s] → ── turn 1 ──\nCMD: big-output-cmd\n\(long)\n\n"
        let out = GrokWatchTool.parse(log, filename: "s.log")
        // The output for the command must be truncated
        #expect(out.contains("→ "), "output arrow prefix must appear")
        #expect(out.contains("…"), "long output must end with …")
    }

    // MARK: - DONE detection

    @Test func doneSignalFromDONEToken() {
        let log = "[00:01:00|1m00s] → ── turn 1 ──\nCMD: final step\ndone\n[[DONE]]\n"
        let out = GrokWatchTool.parse(log, filename: "s.log")
        #expect(out.contains("✓ DONE"),
                "[[DONE]] in log must mark the session as ✓ DONE")
        #expect(!out.contains("Session is still running"),
                "a done session must not say 'still running'")
    }

    @Test func doneSignalFromTASK_COMPLETED() {
        let log = "TASK_COMPLETED_SUCCESSFULLY\n"
        let out = GrokWatchTool.parse(log, filename: "s.log")
        #expect(out.contains("✓ DONE"))
    }

    @Test func stillRunningMessageWhenNotDone() {
        let log = "[00:00:01|0m01s] → ── turn 1 ──\nCMD: something\noutput\n\n"
        let out = GrokWatchTool.parse(log, filename: "s.log")
        #expect(out.contains("Session is still running"),
                "an in-progress session must say 'still running'")
    }

    // MARK: - Empty / no-command session

    @Test func noCommandsYetMessageWhenNoCMDLines() {
        let log = "→ session empty  task: 'start something'\n"
        let out = GrokWatchTool.parse(log, filename: "empty.log")
        #expect(out.contains("No commands run yet"),
                "a session with no CMD lines must report 'No commands run yet'")
    }

    // MARK: - Ring buffer (last 6 pairs)

    @Test func ringBufferKeepsOnlyLast6Commands() {
        var log = ""
        for i in 1...8 {
            log += "[00:00:\(String(format: "%02d", i))|0m\(String(format: "%02d", i))s] → ── turn \(i) ──\n"
            log += "CMD: cmd_\(i)\noutput_\(i)\n\n"
        }
        let out = GrokWatchTool.parse(log, filename: "s.log")
        // The ring buffer holds 6; cmd_1 and cmd_2 must be dropped
        #expect(!out.contains("cmd_1"), "oldest commands (cmd_1) must be evicted from the 6-entry ring")
        #expect(!out.contains("cmd_2"), "oldest commands (cmd_2) must be evicted from the 6-entry ring")
        #expect(out.contains("cmd_3"), "cmd_3 (7th from the end) must appear in the last 6")
        #expect(out.contains("cmd_8"), "most recent command must always appear")
    }
}
