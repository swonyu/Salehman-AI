import Testing
import Foundation
@testable import Salehman_AI

// MARK: - Shell + CommandApprovalCenter security surface
//
// isBlocked + looksRisky are the two layers that keep the assistant from
// destroying the user's Mac or escalating. run() must honor timeout/output cap.
// Suite is not serialized (pure funcs + safe commands only), but we still
// avoid any global mutation.

struct ShellSecurityTests {

    // MARK: isBlocked (two-layer: substrings anywhere + token-per-segment)

    @Test
    func isBlockedRefusesDestructiveAndChainedAndEval() {
        #expect(Shell.isBlocked("rm -rf /") != nil)
        #expect(Shell.isBlocked("echo hi; rm -rf /") != nil)
        #expect(Shell.isBlocked("/sbin/reboot") != nil) // path prefix stripped to "reboot"
        #expect(Shell.isBlocked("X=\"rm -rf /\"; eval $X") != nil)
        #expect(Shell.isBlocked("ls -la") == nil)
        #expect(Shell.isBlocked("sw_vers") == nil)
    }

    // MARK: run (real execution of safe commands; timeout path)

    @Test
    func runLargeOutputIsTruncatedWithMarker() {
        // Produce >8KB; the impl caps at 8000 + marker.
        let cmd = "printf 'x%.0s' {1..20000}"
        let res = Shell.run(cmd)
        #expect(res.output.contains("truncated at 8KB"))
        #expect(res.timedOut == false)
        #expect(res.exitCode == 0)
    }

    @Test
    func runTimeoutTerminatesAndFlags() {
        let res = Shell.run("sleep 5", timeout: 0.2)
        #expect(res.timedOut == true)
        #expect(res.exitCode != 0) // terminated
    }

    @Test
    func runTrueSucceedsWithZeroExit() {
        let res = Shell.run("true")
        #expect(res.exitCode == 0)
        #expect(!res.timedOut)
    }

    // MARK: looksRisky — re-confirm vocabulary (single source: ToolPolicy.CommandRisk)
    //
    // The `CommandApprovalCenter.looksRisky` thin alias was removed; every caller
    // (Shell, the approval center's session-bypass gate, and these tests) reaches
    // `ToolPolicy.CommandRisk.looksRisky` directly. The determinism + nonisolated
    // contracts on the predicate live in `LooksRiskyDelegationTests.swift` — kept
    // out of this suite to avoid drift between two parallel copies.

    @Test
    func looksRiskyCoversDestructiveAndEscalation() {
        #expect(ToolPolicy.CommandRisk.looksRisky("rm foo"))
        #expect(ToolPolicy.CommandRisk.looksRisky("git push"))
        #expect(ToolPolicy.CommandRisk.looksRisky("sudo x"))
        #expect(ToolPolicy.CommandRisk.looksRisky("kill 123"))
        #expect(ToolPolicy.CommandRisk.looksRisky("git reset --hard"))
        #expect(!ToolPolicy.CommandRisk.looksRisky("ls"))
        #expect(!ToolPolicy.CommandRisk.looksRisky("cat file"))
    }

    @Test
    func looksRiskyDocumentsCurrentWhitespaceAndRedirectLimits() {
        // Current impl uses " > " (with spaces) so bare >file is NOT caught.
        // This test pins the *current* (pre-normalization) behaviour until a
        // follow-up tightens it. If normalization lands, update this case.
        #expect(!ToolPolicy.CommandRisk.looksRisky("echo x>file"))
        #expect(!ToolPolicy.CommandRisk.looksRisky("echo x >file"))
    }
}
