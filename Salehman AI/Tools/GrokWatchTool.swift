import Foundation

/// Reads the latest Grok terminal-bridge session log from ~/grok_sessions/ and
/// returns a compact summary — session ID, task, turn count, elapsed time, and
/// the most recent CMD+output pairs — so Salehman can observe what Grok is doing.
enum GrokWatchTool {

    private nonisolated static let sessionDir = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("grok_sessions")

    /// Find the newest .log file and return a readable snapshot.
    nonisolated static func readLatestSession() -> String {
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(
            at: sessionDir,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: .skipsHiddenFiles
        ).filter({ $0.pathExtension == "log" }),
              !files.isEmpty else {
            return "No Grok session logs found in ~/grok_sessions/ — start a session first with:\n  cd \"/Users/saleh/Desktop/Salehman AI\" && python3 tools/grok_terminal_bridge.py --auto --yolo --cwd \"$PWD\" \"<task>\""
        }

        let sorted = files.sorted {
            let a = (try? $0.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            let b = (try? $1.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            return a > b
        }

        guard let latest = sorted.first,
              let content = try? String(contentsOf: latest, encoding: .utf8) else {
            return "Could not read the latest Grok session log."
        }

        return parse(content, filename: latest.lastPathComponent)
    }

    nonisolated static func parse(_ content: String, filename: String) -> String {
        let lines = content.components(separatedBy: "\n")
        let sessionID = (filename as NSString).deletingPathExtension

        // Extract task from the "→ session XXXX  task: '...'" line
        var task = ""
        for line in lines.prefix(5) {
            if let r = line.range(of: "task: '") {
                var raw = String(line[r.upperBound...])
                raw = raw.replacingOccurrences(of: "\\n", with: " ")
                    .replacingOccurrences(of: "\\'", with: "'")
                    .trimmingCharacters(in: CharacterSet(charactersIn: "'"))
                task = raw.count > 180 ? String(raw.prefix(180)) + "…" : raw
                break
            }
        }

        var turnCount = 0
        var currentTurn = 0
        var currentCMD = ""
        var outputBuf: [String] = []
        var collecting = false
        var isDone = false
        var elapsed = ""
        var recentPairs: [(turn: Int, cmd: String, out: String)] = []

        func flush() {
            guard collecting, !currentCMD.isEmpty else { return }
            let out = outputBuf.joined(separator: "\n")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let outShort = out.count > 120 ? String(out.prefix(120)) + "…" : out
            recentPairs.append((currentTurn, currentCMD, outShort))
            if recentPairs.count > 6 { recentPairs.removeFirst() }
            outputBuf = []
            collecting = false
            currentCMD = ""
        }

        for line in lines {
            // Turn header: "[HH:MM:SS|XmYYs] → ── turn N ──"
            if line.contains("── turn") && line.contains("──") {
                flush()
                turnCount += 1
                currentTurn = turnCount
                // Extract elapsed e.g. "5m04s" from "[04:43:46|5m04s]"
                if let pipeRange = line.range(of: "|"),
                   let closeRange = line.range(of: "]") {
                    let s = line[pipeRange.upperBound..<closeRange.lowerBound]
                    if !s.isEmpty { elapsed = String(s) }
                }
                continue
            }

            // CMD line (no timestamp prefix — raw bridge output)
            if line.hasPrefix("CMD: ") {
                flush()
                currentCMD = String(line.dropFirst(5))
                collecting = true
                continue
            }

            // Done signals
            if line.contains("[[DONE]]") || line.contains("TASK_COMPLETED_SUCCESSFULLY") {
                isDone = true
            }

            // Collect output: skip bridge log lines (start with "[" or "→" or "✓")
            if collecting {
                let t = line.trimmingCharacters(in: .whitespaces)
                guard !t.isEmpty else { continue }
                let isBridgeLine = t.hasPrefix("[") || t.hasPrefix("→") || t.hasPrefix("✓")
                    || t.contains("sending output back") || t.contains("── turn")
                if !isBridgeLine { outputBuf.append(t) }
            }
        }
        flush()

        // Build output
        var out = "Grok session \(sessionID)"
        if isDone { out += " ✓ DONE" }
        else if turnCount > 0 { out += " — turn \(turnCount), elapsed \(elapsed)" }
        out += "\n"
        if !task.isEmpty { out += "Task: \(task)\n" }
        out += "Turns so far: \(turnCount)\n"

        if recentPairs.isEmpty {
            out += "\nNo commands run yet (session just started)."
        } else {
            out += "\nLast \(recentPairs.count) command(s):\n"
            for p in recentPairs {
                let cmdShort = p.cmd.count > 90 ? String(p.cmd.prefix(90)) + "…" : p.cmd
                out += "  [\(p.turn)] \(cmdShort)\n"
                if !p.out.isEmpty { out += "      → \(p.out)\n" }
            }
        }

        if !isDone {
            out += "\n(Session is still running.)"
        }

        return out
    }
}
