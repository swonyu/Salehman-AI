import Testing
import Foundation
@testable import Salehman_AI

// MARK: - Persistence round-trips (MemoryStore, ScratchpadStore, StockSagePortfolio, ...)
//
// These require the injectable JSONFileStore + base-dir seam from §3 refactor (R4).
// The stores hard-code their Application Support path and are singletons with
// private fileURL, so no way to point them at a temp dir for hermetic tests.
// All cases here are disabled until the refactor provides a testable constructor
// or base-dir override. Then the round-trip + dedup + snapshot cases become
// straightforward.

struct PersistenceRoundTripTests {

    @Test func memoryStoreRememberDedupesCaseInsensitiveAndNoOpsOnBlank() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let store = MemoryStore(baseDirectory: dir)
        store.remember("Saleh loves Swift")
        store.remember("SALEH LOVES SWIFT")  // case-insensitive duplicate — must be dropped
        store.remember("")                    // blank — no-op
        store.remember("   ")                 // whitespace-only — no-op

        #expect(store.allFacts().count == 1)
        #expect(store.allFacts().first == "Saleh loves Swift")
    }

    @Test func memoryStoreRecallFallsBackToKeywordAndCapsAtKOnEmptyEmbeddings() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let store = MemoryStore(baseDirectory: dir)
        store.remember("User loves coffee")
        store.remember("User hates rain")
        store.remember("User builds iOS apps")
        store.remember("User is a developer")

        let results = store.recall("coffee drinks", k: 2)
        // Keyword fallback: "coffee" matches "User loves coffee"; k=2 caps the result
        #expect(results.contains("User loves coffee"))
        #expect(results.count <= 2)
    }

    @Test @MainActor func scratchpadCompleteTaskMatchesFirstOpenBySubstringAndIdempotent() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let store = ScratchpadStore(testingBaseDirectory: dir)
        store.addTask("Buy groceries")
        store.addTask("Buy milk")

        #expect(store.completeTask(matching: "milk") == true)
        #expect(store.tasks.first(where: { $0.title == "Buy milk" })?.done == true)
        #expect(store.tasks.first(where: { $0.title == "Buy groceries" })?.done == false)
        #expect(store.completeTask(matching: "milk") == false)
    }

    @Test @MainActor func scratchpadSnapshotRoundTripsOrderAndIDs() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let store = ScratchpadStore(testingBaseDirectory: dir)
        store.addNote("Note A")
        store.addNote("Note B")
        store.addTask("Task X")

        let store2 = ScratchpadStore(testingBaseDirectory: dir)
        #expect(store2.notes.count == 2)
        #expect(store2.tasks.count == 1)
        #expect(store2.notes.map { $0.text } == store.notes.map { $0.text })
        #expect(store2.tasks.first?.title == "Task X")
    }

    @Test(.disabled("TODO: §3 refactor (JSONFileStore injectable base dir) required — see CODEBASE_REVIEW §4 and Tab B"))
    func stockSagePortfolioAddValidatesAndNormalizesAndRoundTrips() {
    }
}
