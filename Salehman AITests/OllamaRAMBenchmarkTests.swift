import Testing
import Foundation
import Darwin
@testable import Salehman_AI

/// Faithful app-path RAM benchmark for the Ollama brain.
///
/// Drives `LocalLLM.chat()` (with the brain pinned to Ollama) for N turns and
/// samples two things each turn: the loaded model's resident size from
/// `ollama ps` (the model weights live in the `ollama serve` process, NOT this
/// app — so that's where the RAM is), and this process's own `phys_footprint`.
///
/// It SKIPS cleanly (passes as a no-op with a printed note) when Ollama isn't
/// running or the model isn't installed, so normal/CI test runs never fail.
/// Run it with the server up to get real numbers:
///   xcodebuild test -scheme "Salehman AI" -destination 'platform=macOS' \
///     -only-testing:"Salehman AITests/OllamaRAMBenchmarkTests" CODE_SIGNING_ALLOWED=NO
struct OllamaRAMBenchmarkTests {

    @Test func ollamaTenTurnRAMBenchmark() async throws {
        guard await OllamaClient.isUp() else {
            print("⏭️  SKIP: Ollama server not reachable — start `ollama serve` to benchmark.")
            return
        }
        let model = OllamaClient.codeModel
        guard await OllamaClient.hasModel(model) else {
            print("⏭️  SKIP: model \(model) not installed — `ollama pull \(model)` to benchmark.")
            return
        }

        // Pin the brain to Ollama so LocalLLM.chat() takes the real keep_alive
        // path, and restore the user's choice afterward.
        let original = await MainActor.run { AppSettings.shared.brainPreference }
        await MainActor.run { AppSettings.shared.brainPreference = .ollama }
        defer { Task { @MainActor in AppSettings.shared.brainPreference = original } }

        let turns = 10
        var peakModelSize = "—"
        var peakAppRSS: UInt64 = 0

        print("== Ollama RAM benchmark · \(model) · \(turns) turns ==")
        for i in 1...turns {
            let reply = await LocalLLM.chat("In one sentence, what is \(i)+\(i)?")
            let psRow = Self.ollamaPSRow()
            let rss = Self.appRSSBytes()
            if rss > peakAppRSS { peakAppRSS = rss }
            if let size = Self.parseSize(from: psRow) { peakModelSize = size }
            print(String(format: "turn %2d  app=%5.0f MB  loaded: %@  | %@",
                         i, Double(rss) / 1_048_576,
                         psRow.isEmpty ? "—" : psRow,
                         String(reply.prefix(40)).replacingOccurrences(of: "\n", with: " ")))
        }

        print("----")
        print("PEAK loaded model size (ollama ps): \(peakModelSize)")
        print(String(format: "PEAK app RSS (phys_footprint): %.0f MB", Double(peakAppRSS) / 1_048_576))
        print("(The model SIZE is the real RAM win — compare qwen2.5-coder:7b vs :32b.)")

        // Soft assertions only — no machine-specific RAM ceiling, to avoid flakiness.
        #expect(peakAppRSS > 0)
        #expect(peakModelSize != "—", "Expected `ollama ps` to report a loaded model during the run.")
    }

    // MARK: - Helpers

    /// The data row of `ollama ps` (NAME ID SIZE PROCESSOR UNTIL), or "" if none.
    /// App sandbox is OFF, so spawning a process from the test host is allowed.
    static func ollamaPSRow() -> String {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/bin/zsh")
        p.arguments = ["-lc", "ollama ps 2>/dev/null | tail -n +2 | head -1"]
        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError = Pipe()
        do { try p.run() } catch { return "" }
        p.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    /// Pull the "<n> GB" / "<n> MB" SIZE token out of an `ollama ps` row.
    static func parseSize(from row: String) -> String? {
        guard let r = row.range(of: #"\d+(\.\d+)?\s?(GB|MB)"#, options: .regularExpression) else { return nil }
        return String(row[r])
    }

    /// This process's physical-footprint RSS in bytes (Mach `task_vm_info`).
    static func appRSSBytes() -> UInt64 {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<integer_t>.size)
        let kr = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
            }
        }
        return kr == KERN_SUCCESS ? UInt64(info.phys_footprint) : 0
    }
}
