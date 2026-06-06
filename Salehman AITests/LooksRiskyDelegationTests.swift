import Testing
import Foundation
@testable import Salehman_AI

// MARK: - looksRisky: determinism + actor-safety contract
//
// `ToolPolicy.CommandRisk.looksRisky` is the SINGLE source of the risk-vocab.
// (`Shell.isBlocked` and `CommandApprovalCenter`'s session-bypass gate both call
// it directly — there is no second-layer alias to drift against.) These tests
// pin two structural contracts on the predicate:
//   1. Determinism — pure function, no hidden state, same input → same output.
//   2. Nonisolated-callability — must remain safe to call synchronously from any
//      context (including non-main background paths). The TRUE compile-time
//      guarantee for #2 lives in `_looksRiskyCompileTimeContract` below.

// COMPILE-TIME tripwire for the nonisolated contract. This function is itself
// explicitly `nonisolated` and synchronous; the call to `looksRisky` inside it is
// also synchronous. If anyone ever annotates `ToolPolicy.CommandRisk.looksRisky`
// with `@MainActor`, moves it onto an actor, or otherwise makes it isolated,
// THIS FILE STOPS COMPILING — no `await` is possible from a sync nonisolated
// context. We never need to call this at runtime; the compile is the test.
nonisolated private func _looksRiskyCompileTimeContract() {
    _ = ToolPolicy.CommandRisk.looksRisky("compile-time-only")
}

struct LooksRiskyDelegationTests {

    @Test
    func commandRiskLooksRiskyIsDeterministicAndNonisolated() async {
        // (1) Determinism: identical input → identical output, repeatedly. Any
        // hidden state or mutable cache behind the predicate would fail one of
        // these 64 repeats.
        for c in ["sudo rm -rf /tmp/x", "ls -la", "git push origin main", "echo hi"] {
            let first = ToolPolicy.CommandRisk.looksRisky(c)
            for _ in 0..<64 { #expect(ToolPolicy.CommandRisk.looksRisky(c) == first) }
        }

        // (2) Runtime sanity (NOT the actor-safety guard — that's the file-scope
        // `_looksRiskyCompileTimeContract` above). A fan-out via `withTaskGroup`
        // verifies the predicate produces consistent verdicts under concurrent
        // calls. We deliberately do not rely on `addTask` closures being
        // "detached enough" to enforce nonisolation — that's why the real
        // compile-time check lives at file scope.
        let risky = "sudo rm -rf /"
        let results = await withTaskGroup(of: Bool.self) { group in
            for _ in 0..<32 { group.addTask { ToolPolicy.CommandRisk.looksRisky(risky) } }
            var out: [Bool] = []
            for await r in group { out.append(r) }
            return out
        }
        #expect(results.count == 32)
        #expect(results.allSatisfy { $0 == true })
    }
}
