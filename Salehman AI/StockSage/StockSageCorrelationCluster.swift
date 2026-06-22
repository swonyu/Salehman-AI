import Foundation

// MARK: - Correlation clusters
//
// The heatmap SHOWS pairwise correlation; this NAMES the danger it implies. If
// three or more holdings all move together (every pair ≥ 0.70), they're not three
// positions — they're one bet wearing three tickers, and a drawdown hits all of
// them at once. This finds the largest such mutually-correlated group (a clique).
// Greedy, not optimal — good enough to surface the obvious hidden bet. Pure + tested.

struct CorrelationCluster: Sendable, Equatable {
    let symbols: [String]     // ≥3 names, every pair ≥ threshold
    let minPairwise: Double   // the weakest link inside the cluster (≥ threshold)

    nonisolated var note: String {
        "\(symbols.joined(separator: ", ")) move as one — \(symbols.count) names but ~1 bet (every pair ≥\(Int(minPairwise * 100))% correlated). Diversification here is an illusion; a drawdown hits them together."
    }
}

enum StockSageCorrelationCluster {
    nonisolated static let threshold = 0.70

    /// Largest set of names all MUTUALLY ≥ threshold correlated. Greedy: from each
    /// seed, repeatedly add the candidate with the highest MINIMUM correlation to
    /// every current member (so the clique property is preserved). nil if no group
    /// of ≥3 qualifies.
    nonisolated static func largest(_ m: CorrelationMatrix, threshold: Double = threshold) -> CorrelationCluster? {
        let n = m.symbols.count
        guard n >= 3, m.matrix.count == n, m.matrix.allSatisfy({ $0.count == n }) else { return nil }

        var best: [Int] = []
        for seed in 0..<n {
            var members = [seed]
            while true {
                var pick = -1
                var pickMin = threshold
                for c in 0..<n where !members.contains(c) {
                    let minToMembers = members.map { m.matrix[$0][c] }.min() ?? -1
                    if minToMembers >= threshold, pick == -1 || minToMembers > pickMin {
                        pick = c
                        pickMin = minToMembers
                    }
                }
                if pick == -1 { break }
                members.append(pick)
            }
            if members.count > best.count { best = members }
        }
        guard best.count >= 3 else { return nil }

        var minPair = 1.0
        for a in 0..<best.count {
            for b in (a + 1)..<best.count { minPair = Swift.min(minPair, m.matrix[best[a]][best[b]]) }
        }
        return CorrelationCluster(symbols: best.map { m.symbols[$0] }.sorted(), minPairwise: minPair)
    }
}
