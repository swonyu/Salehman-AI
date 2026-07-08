import Testing
import Foundation
@testable import Salehman_AI

// MARK: - cardIsStale per-card staleness predicate (POST2420-COPY item 1, 2026-07-08)
//
// Pins MarketsView.cardIsStale(generatedAt:now:) = now.timeIntervalSince(generatedAt) > 4*3600.
// Same >4h threshold as StockSageStore.ideasIsStale, but keyed on the CARD's own generatedAt
// instead of the board-level ideasUpdated. Every value below was HAND-DERIVED in a standalone
// script (scratchpad derive_cardisstale.swift, run via `xcrun swift derive_cardisstale.swift`),
// not by calling this code — printed output pasted next to each assertion.

struct MarketsCardIsStaleTests {
    typealias M = MarketsView
    private static let now = Date(timeIntervalSince1970: 1_000_000)

    @Test func straddlesTheFourHourBoundary() {
        // 3h59m elapsed: 14340.0s < 14400s (4h) -> NOT stale
        let threeH59m = Self.now.addingTimeInterval(-(3 * 3600 + 59 * 60))
        #expect(M.cardIsStale(generatedAt: threeH59m, now: Self.now) == false)

        // exactly 4h elapsed: 14400.0s -> strict '>' means the boundary itself is NOT stale
        let exactly4h = Self.now.addingTimeInterval(-(4 * 3600))
        #expect(M.cardIsStale(generatedAt: exactly4h, now: Self.now) == false)

        // 4h01m elapsed: 14460.0s > 14400s -> stale
        let fourH01m = Self.now.addingTimeInterval(-(4 * 3600 + 1 * 60))
        #expect(M.cardIsStale(generatedAt: fourH01m, now: Self.now) == true)
    }

    @Test func nilGeneratedAtIsNeverStale() {
        // No generatedAt (older/test-built ideas) -> can't judge -> not stale, never a false badge.
        #expect(M.cardIsStale(generatedAt: nil, now: Self.now) == false)
    }

    @Test func veryOldAndVeryFreshAreUnambiguous() {
        // 1 minute old -> nowhere near stale.
        #expect(M.cardIsStale(generatedAt: Self.now.addingTimeInterval(-60), now: Self.now) == false)
        // 24h old -> well past the 4h bar.
        #expect(M.cardIsStale(generatedAt: Self.now.addingTimeInterval(-24 * 3600), now: Self.now) == true)
    }
}
