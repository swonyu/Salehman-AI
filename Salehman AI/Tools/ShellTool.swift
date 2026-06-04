import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

/// Runs shell commands on the user's Mac. Exposed to the on-device model as a
/// callable tool so the assistant can "control the terminal".
///
/// Safety: obviously destructive commands are refused, and every command runs
/// with a timeout so a hung process can't freeze the app.
enum Shell {

    /// Patterns that are refused outright. Conservative on purpose.
    private static let blockedPatterns: [String] = [
        "rm -rf /", "rm -rf /*", "rm -rf ~", "rm -rf ~/", "rm -fr /",
        ":(){", "fork()", "mkfs", "diskutil eraseDisk", "diskutil erasevolume",
        "dd if=", "/dev/disk", "/dev/sd", "> /dev/",
        "shutdown", "reboot", "halt", "killall -9",
        "sudo ", "chmod -R 000", "chown -R", "> /etc/", "csrutil disable"
    ]

    struct Result {
        let exitCode: Int32
        let output: String
        let timedOut: Bool
    }

    static func isBlocked(_ command: String) -> String? {
        let lower = command.lowercased()
        for pattern in blockedPatterns where lower.contains(pattern.lowercased()) {
            return pattern
        }
        return nil
    }

    /// Run a command with `/bin/zsh -c`. Blocks the calling (background) task
    /// until completion or timeout. Uses a DispatchSource timer + waitUntilExit
    /// instead of a busy-polling `usleep` loop.
    static func run(_ command: String, timeout: TimeInterval = 60) -> Result {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-c", command]
        process.currentDirectoryURL = FileManager.default.homeDirectoryForCurrentUser

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

#if canImport(FoundationModels)
/// The Foundation Models tool the assistant can call to run a command.
struct RunTerminalCommandTool: Tool {
    let name = "run_terminal_command"
    let description = """
    Run a shell command on the user's Mac (zsh) and return its combined \
    stdout/stderr. Use this to inspect files, run scripts, check system state, \
    or perform tasks the user asks for. Prefer safe, read-only commands unless \
    the user clearly asked to modify something.
    """

    @Generable
    struct Arguments {
        @Guide(description: "The exact shell command to run, e.g. 'ls -la ~/Downloads' or 'sw_vers'.")
        var command: String
    }

    func call(arguments: Arguments) async throws -> String {
        let command = arguments.command.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !command.isEmpty else { return "No command provided." }

        if let blocked = Shell.isBlocked(command) {
            return "REFUSED: this command was blocked for safety (matched \"\(blocked)\"). Tell the user it was not run."
        }

        // Ask the user for approval (unless they turned confirmation off).
        let approved = await CommandApprovalCenter.shared.requestApproval(command)
        guard approved else {
            return "The user CANCELLED this command. It was NOT run. Acknowledge that and ask what they'd like to do instead."
        }

        let result = Shell.run(command)
        var report = "$ \(command)\n"
        if result.timedOut { report += "(timed out after 60s; process terminated)\n" }
        report += "exit code: \(result.exitCode)\n---\n\(result.output)"
        return report
    }
}
#endif
