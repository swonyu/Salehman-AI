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

    /// Dangerous *operation / path* fragments — refused if they appear ANYWHERE
    /// in the command (so a chained `foo; rm -rf /` is still caught). All lower-
    /// case; `isBlocked` lowercases the input before comparing.
    ///
    /// NOTE on `/dev/disk` etc.: kept as a blunt substring on purpose. For a
    /// destructive-command gate, over-blocking a rare raw-disk *read* is the
    /// right trade vs. letting a disk-*wipe* (`dd of=/dev/diskN`, `> /dev/diskN`)
    /// slip through. Safety beats the theoretical false-positive.
    private static let blockedSubstrings: [String] = [
        "rm -rf /", "rm -rf /*", "rm -rf ~", "rm -rf ~/", "rm -fr /", "rm -rf .", "rm -rf *",
        ":(){", "fork()",
        "mkfs", "diskutil erasedisk", "diskutil erasevolume", "diskutil reformat",
        "diskutil partitiondisk", "dd if=", "of=/dev/",
        "/dev/disk", "/dev/rdisk", "/dev/sd", "> /dev/", ">/dev/",
        "> /etc/", ">/etc/", "csrutil disable", "spctl --master-disable", "nvram ",
        "chmod -r 000", "chmod 000", "chmod -r ", "chown -r", "chgrp -r",
    ]

    /// Destructive command *names*. Matched as the leading token of EACH
    /// `;`/`&&`/`||`/`|`/newline/backtick-separated segment, so neither chaining
    /// (`x && sudo rm`) nor a path prefix (`/sbin/reboot`) can sneak one past a
    /// substring check. `eval`/`exec`/`source` are blocked because they enable
    /// the variable-indirection bypass (`X="rm -rf /"; eval $X`).
    private static let blockedCommands: Set<String> = [
        "shutdown", "reboot", "halt", "poweroff",
        "sudo", "su", "doas",
        "killall", "mkfs", "fdisk", "newfs_apfs", "newfs_hfs", "diskutil",
        "eval", "exec", "source", "launchctl", "chgrp",
    ]

    struct Result {
        let exitCode: Int32
        let output: String
        let timedOut: Bool
    }

    /// Returns the matched pattern/command if `command` is refused, else `nil`.
    /// Two layers: dangerous substrings (operations/paths, anywhere) + dangerous
    /// command names (leading token of each chained segment).
    static func isBlocked(_ command: String) -> String? {
        let lower = command.lowercased()
        for pattern in blockedSubstrings where lower.contains(pattern) {
            return pattern
        }
        // Token-aware pass: inspect the leading command of every chained segment.
        let segments = lower.components(separatedBy: CharacterSet(charactersIn: ";|&\n\r`"))
        for raw in segments {
            let segment = raw.trimmingCharacters(in: .whitespaces)
            guard let firstToken = segment.split(separator: " ").first else { continue }
            // Strip any path prefix: `/sbin/reboot` → `reboot`.
            let name = firstToken.split(separator: "/").last.map(String.init) ?? String(firstToken)
            if blockedCommands.contains(name) { return name }
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
        let result = run(cmd)
        var report = "$ \(cmd)\n"
        if result.timedOut { report += "(timed out after 60s; process terminated)\n" }
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
        // Shared gated executor — identical safety path to the Ollama tool loop.
        await Shell.runApproved(arguments.command)
    }
}
#endif
