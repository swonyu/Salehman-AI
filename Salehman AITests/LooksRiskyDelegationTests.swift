import Testing
import Foundation
@testable import Salehman_AI

// MARK: - looksRisky: delegation parity + determinism/actor-safety
//
// `CommandApprovalCenter.looksRisky` (the session-bypass re-confirm gate) now
// FORWARDS to `ToolPolicy.CommandRisk.looksRisky` (the single risk-vocabulary
// source). These tests lock that the delegation changed no re-confirm UX, and
// that the canonical predicate stays deterministic + actor-safe (nonisolated).
// Kept in its own file (not ShellSecurityTests) to avoid colliding with the
// other session's edits to that suite.

struct LooksRiskyDelegationTests {

    @Test
    func looksRiskyDelegatesFaithfullyToSingleSource() {
        // CommandApprovalCenter.looksRisky must forward EXACTLY to
        // ToolPolicy.CommandRisk.looksRisky — pins that centralizing the risk
        // vocabulary changed NO session-bypass re-confirm behaviour. Any drift
        // between the two layers fails here.
        let cases = ["rm foo", "git push", "sudo apt", "kill 123", "git reset --hard",
                     "git clean -fd", "chmod 700 x", "chown root x", "mv a b", "rmdir d",
                     "trash x", "truncate -s0 f", "format", "delete x",
                     "echo a >> b", "echo a > b",
                     "ls", "cat file", "pwd", "echo hi", "sw_vers"]
        for c in cases {
            #expect(CommandApprovalCenter.looksRisky(c) == ToolPolicy.CommandRisk.looksRisky(c),
                    "looksRisky drifted between the two layers for \"\(c)\"")
        }
    }

    @Test
    func commandRiskLooksRiskyIsDeterministicAndNonisolated() async {
        // Determinism: identical input → identical output, repeatedly (no hidden
        // or mutable state behind the predicate).
        for c in ["sudo rm -rf /tmp/x", "ls -la", "git push origin main", "echo hi"] {
            let first = ToolPolicy.CommandRisk.looksRisky(c)
            for _ in 0..<64 { #expect(ToolPolicy.CommandRisk.looksRisky(c) == first) }
        }
        // Actor-safety tripwire: looksRisky is invoked here from DETACHED, non-main
        // child tasks. If it ever becomes actor-isolated (e.g. `@MainActor`) or
        // starts reading mutable shared state, THIS BLOCK STOPS COMPILING — which
        // is the point: it blocks future actor-unsafe changes at build time.
        let results = await withTaskGroup(of: Bool.self) { group in
            for _ in 0..<32 { group.addTask { ToolPolicy.CommandRisk.looksRisky("sudo rm -rf /") } }
            var out: [Bool] = []
            for await r in group { out.append(r) }
            return out
        }
        #expect(results.count == 32 && results.allSatisfy { $0 })   // consistent across concurrency
    }
}
