import Foundation

/// Runs shell commands on the user's Mac. Exposed to the on-device model as a
/// callable tool so the assistant can "control the terminal".
///
/// Safety: obviously destructive commands are refused, and every command runs
/// with a timeout so a hung process can't freeze the app.
enum Shell {

    // Command-risk lists + logic live in ToolPolicy.CommandRisk (single source for
    // Shell + CommandApprovalCenter + tests). `isBlocked` below just delegates;
    // the old per-type deprecated aliases were removed after confirming nothing
    // referenced them.

    struct Result {
        let exitCode: Int32
        let output: String
        let timedOut: Bool
    }

    /// Optional working-directory override. The **Code tab** sets this to the
    /// chosen project root so terminal commands + file edits run INSIDE the
    /// project instead of `$HOME`. `nil` → home directory (unchanged behavior for
    /// every other caller). Lock-guarded because `run` executes off the main
    /// actor while the Code tab sets this from `@MainActor`.
    private nonisolated(unsafe) static var _workingDirectory: URL?
    private static let wdLock = NSLock()
    nonisolated static var workingDirectory: URL? {
        get { wdLock.lock(); defer { wdLock.unlock() }; return _workingDirectory }
        set { wdLock.lock(); defer { wdLock.unlock() }; _workingDirectory = newValue }
    }

    /// Returns the matched pattern/command if `command` is refused, else `nil`.
    /// Two layers: dangerous substrings (operations/paths, anywhere) + dangerous
    /// command names (leading token of each chained segment).
    static func isBlocked(_ command: String) -> String? {
        // Delegate to the single source (ToolPolicy.CommandRisk). The old private
        // lets are now thin deprecated forwards for any other references.
        return ToolPolicy.CommandRisk.isBlocked(command)
    }

    /// Run a command with `/bin/zsh -c`. Blocks the calling (background) task
    /// until completion or timeout. Uses a DispatchSource timer + waitUntilExit
    /// instead of a busy-polling `usleep` loop.
    static func run(_ command: String, timeout: TimeInterval = 60) -> Result {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-c", command]
        process.currentDirectoryURL = workingDirectory ?? FileManager.default.homeDirectoryForCurrentUser

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
        } catch {
            return Result(exitCode: -1,
                          output: "Failed to start command: \(error.localizedDescription)",
                          timedOut: false)
        }

        // Drain the pipe concurrently as the child writes. If we instead read
        // only after exit, a command that prints more than the 64 KB pipe buffer
        // blocks waiting for us — and waitUntilExit() would hang forever.
        let collector = OutputCollector()
        let handle = pipe.fileHandleForReading
        handle.readabilityHandler = { fh in
            let chunk = fh.availableData
            if chunk.isEmpty { fh.readabilityHandler = nil }   // EOF
            else { collector.append(chunk) }
        }

        // Schedule a one-shot timer to terminate the process if the deadline passes.
        let timeoutFlag = AtomicBool()
        let timer = DispatchSource.makeTimerSource(queue: DispatchQueue.global(qos: .utility))
        timer.schedule(deadline: .now() + timeout)
        timer.setEventHandler { [weak process] in
            guard let process, process.isRunning else { return }
            timeoutFlag.set(true)
            process.terminate()
        }
        timer.resume()

        // Block this (background) task thread until the process exits — no CPU spin.
        process.waitUntilExit()
        timer.cancel()

        // Pull anything still buffered, then release the descriptor.
        handle.readabilityHandler = nil
        let remaining = handle.readDataToEndOfFile()
        if !remaining.isEmpty { collector.append(remaining) }
        try? handle.close()

        var output = String(data: collector.data, encoding: .utf8) ?? ""
        if output.count > 8000 {
            output = String(output.prefix(8000)) + "\n…(output truncated at 8KB)"
        }
        let timedOut = timeoutFlag.value
        if output.isEmpty { output = timedOut ? "(no output before timeout)" : "(no output)" }

        return Result(exitCode: process.terminationStatus,
                      output: output,
                      timedOut: timedOut)
    }

    /// Approval-gated async execution, shared by the Foundation Models tool AND
    /// the Ollama tool-calling loop so BOTH brains run commands through the exact
    /// same safety path: refuse-if-blocked → ask the user (CommandApprovalCenter)
    /// → run → formatted report. Returns a model-readable string in every case.
    nonisolated static func runApproved(_ command: String) async -> String {
        let cmd = command.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cmd.isEmpty else { return "No command provided." }
        if let blocked = isBlocked(cmd) {
            return "REFUSED: this command was blocked for safety (matched \"\(blocked)\"). It was NOT run — tell the user."
        }
        let approved = await CommandApprovalCenter.shared.requestApproval(cmd)
        guard approved else {
            return "The user CANCELLED this command. It was NOT run. Acknowledge that and ask what they'd like instead."
        }
        let timeout: TimeInterval = 60
        let result = run(cmd, timeout: timeout)
        var report = "$ \(cmd)\n"
        if result.timedOut { report += "(timed out after \(Int(timeout))s; process terminated)\n" }
        report += "exit code: \(result.exitCode)\n---\n\(result.output)"
        return report
    }
}

/// Thread-safe accumulator for pipe output read on a background readability handler.
private final class OutputCollector: @unchecked Sendable {
    private let lock = NSLock()
    private var _data = Data()
    func append(_ chunk: Data) {
        lock.lock(); _data.append(chunk); lock.unlock()
    }
    var data: Data {
        lock.lock(); defer { lock.unlock() }
        return _data
    }
}

/// Tiny lock-protected boolean shared between the timer handler and the caller.
private final class AtomicBool: @unchecked Sendable {
    private let lock = NSLock()
    private var _value = false
    var value: Bool {
        lock.lock(); defer { lock.unlock() }
        return _value
    }
    func set(_ newValue: Bool) {
        lock.lock(); defer { lock.unlock() }
        _value = newValue
    }
}

