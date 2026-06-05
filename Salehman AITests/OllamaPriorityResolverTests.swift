import Testing
import Foundation
@testable import Salehman_AI

// MARK: - OllamaClient.preferredCodeModels priority ordering
//
// `OllamaClient.activeCodeModel()` walks the `preferredCodeModels` list in
// declared order and returns the first one that's actually pulled on disk.
// The ordering of that list is load-bearing: if someone reorders it so 32B
// appears before 7B, a user with both pulled would get the 19 GB resident
// model by default — silently re-introducing the OOM-on-Ollama failure that
// the priority list exists to prevent.
//
// These tests pin the *shape* of the list (lightest first, the sweet-spot
// `codeModel` is the first entry, heavy variants come last). They don't
// drive `activeCodeModel()` directly because that would require mocking the
// `Reachability` actor's `hasModel` cache — out of scope for pure-logic
// unit tests. The agent-test runtime exercises that path live.

struct OllamaPreferredModelsTests {

    @Test func sweetSpotIsFirst() {
        // The first entry MUST be the documented sweet-spot default
        // (`codeModel`). Otherwise `activeCodeModel()` would silently prefer
        // a heavier model on machines that happen to have both pulled.
        #expect(OllamaClient.preferredCodeModels.first == OllamaClient.codeModel,
                "preferredCodeModels[0] must be `codeModel` so the sweet-spot wins when both are pulled")
    }

    @Test func heavyIsLast() {
        // The 32B (heavy) variant must come last so it's only picked when
        // *nothing* lighter is present. Putting it earlier would re-create
        // the OOM-on-Ollama failure we fixed by switching the default from
        // 32B → 7B in the 2026-06-04 RAM overhaul.
        #expect(OllamaClient.preferredCodeModels.last == OllamaClient.heavyCodeModel,
                "heavyCodeModel must be the LAST resort — anywhere else and we re-introduce the 19 GB RAM blow-up")
    }

    @Test func containsExpectedThreeVariants() {
        // Sanity: the list should have exactly the three variants we
        // documented. Adding a new size is a deliberate change and should
        // bump this expectation explicitly.
        let models = OllamaClient.preferredCodeModels
        #expect(models.count == 3,
                "preferredCodeModels has \(models.count) entries; expected 3 (7B, 14B, 32B)")
        #expect(models.contains("qwen2.5-coder:7b"))
        #expect(models.contains("qwen2.5-coder:14b"))
        #expect(models.contains("qwen2.5-coder:32b"))
    }

    @Test func entriesAreSortedAscendingBySize() {
        // Pin the *order* explicitly. If someone shuffles entries (even
        // accidentally during a refactor), this trips. The semantic
        // requirement is "lightest first, heaviest last" — encoded
        // here as the exact expected sequence.
        #expect(OllamaClient.preferredCodeModels == [
            "qwen2.5-coder:7b",
            "qwen2.5-coder:14b",
            "qwen2.5-coder:32b",
        ])
    }

    @Test func everyEntryFollowsTheCanonicalNameShape() {
        // Ollama uses `family:variant` IDs. A typo (e.g. `qwen2.5_coder:7b`,
        // `qwen-2.5-coder:7b`, or `qwen2.5-coder-7b`) would silently 404
        // because `hasModel`'s fuzzy match still requires the canonical
        // family name. Cheap belt-and-suspenders against rename mistakes.
        for model in OllamaClient.preferredCodeModels {
            #expect(model.hasPrefix("qwen2.5-coder:"),
                    "Every preferred coder model must start with `qwen2.5-coder:`, got \(model)")
            #expect(model == model.lowercased(),
                    "Ollama model IDs must be lowercase, got \(model)")
            #expect(!model.contains(" "),
                    "Ollama model IDs must not contain spaces, got \(model)")
        }
    }

    // MARK: - Constant cross-reference

    @Test func codeModelMatchesFirstPreferred() {
        // `codeModel` and `preferredCodeModels[0]` MUST agree — they're two
        // sources of truth for the same concept and we want exactly one.
        // If a future rename touches one without the other, this catches it.
        #expect(OllamaClient.codeModel == OllamaClient.preferredCodeModels[0])
    }

    @Test func heavyCodeModelMatchesLastPreferred() {
        // Same invariant for the heavy escape hatch.
        #expect(OllamaClient.heavyCodeModel == OllamaClient.preferredCodeModels.last)
    }
}
