import Testing
import Foundation
@testable import Salehman_AI

// MARK: - Correlation clusters (pure)

struct StockSageCorrelationClusterTests {

    typealias CC = StockSageCorrelationCluster

    @Test func findsTheMutuallyCorrelatedBlock() {
        // A,B,C all 0.8; D ~0.1 to everyone → cluster {AAA,BBB,CCC}.
        let m = CorrelationMatrix(symbols: ["AAA", "BBB", "CCC", "DDD"], matrix: [
            [1.0, 0.8, 0.8, 0.1],
            [0.8, 1.0, 0.8, 0.1],
            [0.8, 0.8, 1.0, 0.1],
            [0.1, 0.1, 0.1, 1.0],
        ])
        let c = CC.largest(m)!
        #expect(c.symbols == ["AAA", "BBB", "CCC"])
        #expect(abs(c.minPairwise - 0.8) < 1e-9)
        #expect(c.note.contains("~1 bet"))
    }

    @Test func uncorrelatedBookHasNoCluster() {
        let m = CorrelationMatrix(symbols: ["A", "B", "C"], matrix: [
            [1.0, 0.3, 0.2],
            [0.3, 1.0, 0.25],
            [0.2, 0.25, 1.0],
        ])
        #expect(CC.largest(m) == nil)
    }

    @Test func pairIsNotACluster() {
        // Only two names ≥0.7 → not a cluster (needs ≥3).
        let m = CorrelationMatrix(symbols: ["A", "B", "C"], matrix: [
            [1.0, 0.9, 0.1],
            [0.9, 1.0, 0.1],
            [0.1, 0.1, 1.0],
        ])
        #expect(CC.largest(m) == nil)
    }

    @Test func growsToTheFullCliqueWhenAllCorrelated() {
        let m = CorrelationMatrix(symbols: ["W", "X", "Y", "Z"], matrix: [
            [1.0, 0.9, 0.9, 0.9],
            [0.9, 1.0, 0.9, 0.9],
            [0.9, 0.9, 1.0, 0.9],
            [0.9, 0.9, 0.9, 1.0],
        ])
        let c = CC.largest(m)!
        #expect(c.symbols.count == 4)
        #expect(abs(c.minPairwise - 0.9) < 1e-9)
    }

    @Test func tooFewSymbolsIsNil() {
        let m = CorrelationMatrix(symbols: ["A", "B"], matrix: [[1.0, 0.9], [0.9, 1.0]])
        #expect(CC.largest(m) == nil)
    }
}
