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

    @Test(.disabled("TODO: §3 refactor (JSONFileStore injectable base dir) required — see CODEBASE_REVIEW §4 and Tab B"))
    func memoryStoreRememberDedupesCaseInsensitiveAndNoOpsOnBlank() {
    }

    @Test(.disabled("TODO: §3 refactor (JSONFileStore injectable base dir) required — see CODEBASE_REVIEW §4 and Tab B"))
    func memoryStoreRecallFallsBackToKeywordAndCapsAtKOnEmptyEmbeddings() {
    }

    @Test(.disabled("TODO: §3 refactor (JSONFileStore injectable base dir) required — see CODEBASE_REVIEW §4 and Tab B"))
    func scratchpadCompleteTaskMatchesFirstOpenBySubstringAndIdempotent() {
    }

    @Test(.disabled("TODO: §3 refactor (JSONFileStore injectable base dir) required — see CODEBASE_REVIEW §4 and Tab B"))
    func scratchpadSnapshotRoundTripsOrderAndIDs() {
    }

    @Test(.disabled("TODO: §3 refactor (JSONFileStore injectable base dir) required — see CODEBASE_REVIEW §4 and Tab B"))
    func stockSagePortfolioAddValidatesAndNormalizesAndRoundTrips() {
    }
}
