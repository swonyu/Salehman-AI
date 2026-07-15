import Testing
import Foundation
@testable import Salehman_AI

// First-real-trade review (2026-07-16): Tadawul tick-size placeability. Expected values are
// HAND-DERIVED from the SOURCED band table (Saudi Exchange amended regime effective 2025-06-29;
// two agreeing sources: Argaam #1823880 + Sahm Capital support — never read off the code):
//   < 25.00 → 0.01 · 25.00–49.98 → 0.02 · 50.00–99.95 → 0.05 · 100.00–249.90 → 0.10 ·
//   250.00–499.80 → 0.20 · ≥ 500.00 → 0.50
@MainActor
struct StockSageTickSizeTests {
    typealias T = StockSageTickSize

    // Every band boundary STRADDLED: the last price of one band and the first of the next.
    @Test func tickBandsMatchTheSourcedTableAtEveryBoundary() {
        #expect(T.tadawulTick(forPrice: 24.99) == 0.01)
        #expect(T.tadawulTick(forPrice: 25.00) == 0.02)
        #expect(T.tadawulTick(forPrice: 49.98) == 0.02)
        #expect(T.tadawulTick(forPrice: 50.00) == 0.05)
        #expect(T.tadawulTick(forPrice: 99.95) == 0.05)
        #expect(T.tadawulTick(forPrice: 100.00) == 0.10)
        #expect(T.tadawulTick(forPrice: 249.90) == 0.10)
        #expect(T.tadawulTick(forPrice: 250.00) == 0.20)
        #expect(T.tadawulTick(forPrice: 499.80) == 0.20)
        #expect(T.tadawulTick(forPrice: 500.00) == 0.50)
    }

    // Hand-derived roundings: 28.63 in the 0.02 band → 28.63/0.02 = 1431.5 → nearest even
    // consideration irrelevant (rounded() = 1432) → 28.64. 101.37 in the 0.10 band → 101.4.
    @Test func roundsToTheNearestPlaceableTick() {
        #expect(abs(T.tadawulRounded(28.63) - 28.64) < 1e-9)
        #expect(abs(T.tadawulRounded(101.37) - 101.4) < 1e-9)
        #expect(abs(T.tadawulRounded(9.876) - 9.88) < 1e-9)     // 0.01 band
        #expect(T.tadawulAligned(28.64))
        #expect(!T.tadawulAligned(28.63))
        #expect(T.tadawulAligned(101.4))
    }

    // The advisory fires ONLY for .SR AND only when a leg is off-grid; the engine's own
    // numbers are quoted, the placeable equivalents suggested, drift disclosed.
    @Test func placeabilityNoteFiresOnlyForMisalignedTadawulLegs() {
        // Non-.SR: always nil (US ticks at $0.01 — any 2-dp price places).
        #expect(T.placeabilityNote(symbol: "AAPL", entry: 187.334, stop: 180.111, target: 200.999) == nil)
        // .SR, all legs aligned: nil (no noise on a clean plan).
        #expect(T.placeabilityNote(symbol: "2222.SR", entry: 28.64, stop: 27.50, target: 31.20) == nil)
        // .SR with a misaligned stop: fires, names the leg, suggests 28.64.
        let note = T.placeabilityNote(symbol: "2222.SR", entry: 29.00, stop: 28.63, target: 31.20)
        #expect(note != nil)
        #expect(note!.contains("28.63"))
        #expect(note!.contains("28.64"))
        #expect(note!.contains("stop"))
        #expect(!note!.contains("target 31.20 →"))     // aligned legs are not listed
    }

    // The .SR session line in the execution-timing advisory (static exchange schedule,
    // sourced 2026-07-16): fires for a trending .SR buy, absent for US names (which get the
    // measured US numbers instead) and for range regimes.
    @Test func tadawulSessionLineAppearsForTrendingSRNames() {
        let sr = StockSageExecutionTiming.sessionNote(action: .buy, regime: .bullTrend, symbol: "2222.SR")
        #expect(sr != nil)
        #expect(sr!.contains("Sun–Thu"))
        #expect(sr!.contains("10:00–15:00"))
        let us = StockSageExecutionTiming.sessionNote(action: .buy, regime: .bullTrend, symbol: "AAPL")
        #expect(us != nil && !us!.contains("Sun–Thu"))
        #expect(StockSageExecutionTiming.sessionNote(action: .buy, regime: .range, symbol: "2222.SR") == nil)
    }
}
