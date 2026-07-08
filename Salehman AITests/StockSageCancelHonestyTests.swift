import Testing
@testable import Salehman_AI

// MARK: - cancelledScanCommit — the reduced, honest commit a cancelled scan runs when at least
// one chunk already published (post-ship critique fleet, orchestrator-confirmed cluster).
// Mirrors StockSageIdeasMissingTests' hand-derived-fixture idiom; this helper wraps
// missingAfterScan (already covered there) plus the nil-when-nothing-published / always-empty-
// deltas rules that are NEW behavior for this fix.

struct StockSageCancelHonestyTests {

    @Test func nothingPublishedIsATrueNoOp() {
        // Cancel landed before chunk 0 ever merged into the board (e.g. the pre-loop
        // `guard !Task.isCancelled` at the benchmark-fetch await) — publishedBoardSymbols is
        // empty. The caller must leave ideasMissing/scanDeltas exactly as they were; this helper
        // signals that with nil rather than returning an "everything is missing" commit that
        // would overwrite a perfectly good PRIOR board's honest state with a worse one.
        let commit = StockSageStore.cancelledScanCommit(
            universe: ["AAPL", "MSFT"],
            publishedBoardSymbols: [],
            stillTracked: ["AAPL", "MSFT"])
        #expect(commit == nil)
    }

    @Test func onePublishedChunkNamesTheUnscannedRemainder() {
        // By hand: universe has 4 attempted-this-scan symbols. Only AAPL made it onto the board
        // (chunk 0 published, chunk 1 never ran before cancel). MSFT and nvda (case-insensitive)
        // are tracked but unscanned → MISSING. ^GSPC is an index → never missing (mirrors
        // missingAfterScan's asset-class exclusion, StockSageIdeasMissingTests).
        let commit = StockSageStore.cancelledScanCommit(
            universe: ["AAPL", "MSFT", "^GSPC", "nvda"],
            publishedBoardSymbols: ["AAPL"],
            stillTracked: ["AAPL", "MSFT", "^GSPC", "NVDA"])
        #expect(commit != nil)
        #expect(commit?.ideasMissing == ["MSFT", "nvda"])
        // Deltas describe the OLD baseline against a board that just changed shape mid-scan —
        // an empty dict is the honest "nothing to compare" state, never a stale claim.
        #expect(commit?.scanDeltas.isEmpty == true)
    }

    @Test func symbolRemovedMidScanIsDroppedNotBannered() {
        // GONE was removed (removeSymbol) during the cancelled scan's own await — it is absent
        // from stillTracked, so it must NOT show up as "couldn't be fetched" (same stillTracked
        // reconcile rule the normal scan-end commit and missingAfterScan already apply).
        let commit = StockSageStore.cancelledScanCommit(
            universe: ["AAPL", "GONE"],
            publishedBoardSymbols: [],   // still triggers the has-published check via a second call below
            stillTracked: ["AAPL"])
        // publishedBoardSymbols empty here only to prove the nil-path is independent of stillTracked
        // filtering; the real "GONE dropped" assertion is the non-empty-publish variant below.
        #expect(commit == nil)

        let published = StockSageStore.cancelledScanCommit(
            universe: ["AAPL", "GONE"],
            publishedBoardSymbols: ["AAPL"],
            stillTracked: ["AAPL"])
        #expect(published?.ideasMissing == [])
        #expect(!(published?.ideasMissing.contains("GONE") ?? true))
    }

    @Test func everyAttemptedSymbolPublishedLeavesNothingMissing() {
        // Cancel landed exactly at chunk-boundary AFTER the last chunk merged (e.g. the watchdog
        // fired on trailing cleanup work) — every universe symbol is already on the board.
        // ideasMissing must come back empty, not a stale non-empty list.
        let commit = StockSageStore.cancelledScanCommit(
            universe: ["AAPL", "MSFT"],
            publishedBoardSymbols: ["AAPL", "MSFT"],
            stillTracked: ["AAPL", "MSFT"])
        #expect(commit?.ideasMissing == [])
        #expect(commit?.scanDeltas.isEmpty == true)
    }
}
