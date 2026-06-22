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
}
