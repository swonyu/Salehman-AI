import Testing
import Foundation
@testable import Salehman_AI

// MARK: - Sparkline series helpers (pure)

struct SparkSeriesTests {

    @Test func normalizeMapsToUnitRange() {
        #expect(SparkSeries.normalize([1, 2, 3]) == [0, 0.5, 1])
        #expect(SparkSeries.normalize([10, 0]) == [1, 0])
    }

    @Test func normalizeFlatSeriesIsMidline() {
        #expect(SparkSeries.normalize([5, 5, 5]) == [0.5, 0.5, 0.5])
        #expect(SparkSeries.normalize([]).isEmpty)
    }

    @Test func downsampleKeepsEndsAndCount() {
        let s = SparkSeries.downsample((1...100).map(Double.init), maxPoints: 10)
        #expect(s.count == 10)
        #expect(s.first == 1)
        #expect(s.last == 100)
    }

    @Test func downsampleLeavesShortSeriesUntouched() {
        let short = [1.0, 2.0, 3.0]
        #expect(SparkSeries.downsample(short, maxPoints: 32) == short)
    }

    // MARK: - domain/fraction (OSS-borrow B2: trade-plan overlay y-domain mapping)
    // Hand-derived in /tmp/derive_b2.py — never from calling domain()/fraction() themselves.

    @Test func domainExtendsToOutOfRangeExtras() {
        // series [10,12,11,13] extended with stop=8, target=15 -> domain widens to [8,15],
        // NOT clamped to the series' own [10,13].
        let d = SparkSeries.domain([10, 12, 11, 13], extending: [8, 15])
        #expect(d?.lo == 8)
        #expect(d?.hi == 15)
        #expect(SparkSeries.fraction(8, in: d!) == 0.0)
        #expect(SparkSeries.fraction(15, in: d!) == 1.0)
        #expect(SparkSeries.fraction(11.5, in: d!) == 0.5)
    }

    @Test func domainUnchangedWhenExtrasAlreadyInRange() {
        // extra=15 sits inside [10,20] -> domain stays the series' own range.
        let d = SparkSeries.domain([10, 20], extending: [15])
        #expect(d?.lo == 10)
        #expect(d?.hi == 20)
    }

    @Test func domainNilForDegenerateSeries() {
        // Flat series, no extras -> no meaningful range -> nil (never a fabricated 0.5 line).
        #expect(SparkSeries.domain([5, 5, 5]) == nil)
    }

    @Test func domainFromExtrasAloneWhenSeriesEmpty() {
        let d = SparkSeries.domain([], extending: [3, 9])
        #expect(d?.lo == 3)
        #expect(d?.hi == 9)
    }

    @Test func domainNilWhenSeriesEmptyAndSingleExtra() {
        // One point can't form a range.
        #expect(SparkSeries.domain([], extending: [7]) == nil)
    }
}
