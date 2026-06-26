import Testing
import Foundation
@testable import Salehman_AI

// Correlation-aware portfolio heat: a cluster of mutually-correlated names is ~1 bet, so each
// member's weight is divided by the cluster size; uncorrelated names are untouched.
struct StockSageCorrelationHeatTests {
    typealias C = StockSageCorrelationCluster

    @Test func clusterMembersAreScaledByCountUncorrelatedUntouched() {
        let up: [Double]   = [0.01, 0.02, -0.01, 0.03, 0.01, -0.02, 0.02, 0.015]
        let down: [Double] = up.map { -$0 }   // perfectly ANTI-correlated → never in the cluster
        // A, B, C share identical returns (ρ = 1) → a 3-name cluster; D is anti-correlated → out.
        let symbols = ["A", "B", "C", "D"]
        let returns = [up, up, up, down]
        let weights = [0.06, 0.06, 0.06, 0.06]
        let adj = C.correlationAdjustedWeights(symbols: symbols, weights: weights, returns: returns)
        #expect(abs(adj[0] - 0.02) < 1e-9)   // 0.06 / 3
        #expect(abs(adj[1] - 0.02) < 1e-9)
        #expect(abs(adj[2] - 0.02) < 1e-9)
        #expect(abs(adj[3] - 0.06) < 1e-9)   // D unchanged
        // The cluster's COMBINED weight is now one position's worth, not three.
        #expect(abs((adj[0] + adj[1] + adj[2]) - 0.06) < 1e-9)
    }

    @Test func noClusterLeavesWeightsUnchanged() {
        // Three mutually low-correlation series → no ≥0.70 clique → identity.
        let a: [Double] = [0.01, -0.02, 0.03, -0.01, 0.02, -0.03, 0.01]
        let b: [Double] = [-0.02, 0.03, -0.01, 0.02, -0.03, 0.01, 0.0]
        let c: [Double] = [0.03, -0.01, -0.02, 0.0, 0.02, -0.01, 0.015]
        let w = [0.05, 0.05, 0.05]
        let adj = C.correlationAdjustedWeights(symbols: ["A", "B", "C"], weights: w, returns: [a, b, c])
        #expect(adj == w)
    }

    @Test func fewerThanThreeIsIdentity() {
        let w = [0.05, 0.05]
        #expect(C.correlationAdjustedWeights(symbols: ["A", "B"], weights: w, returns: [[0.01, 0.02], [0.01, 0.02]]) == w)
    }
}
