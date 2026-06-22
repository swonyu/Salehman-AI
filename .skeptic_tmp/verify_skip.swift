import Foundation

struct AllInCost: Sendable, Equatable {
    let spreadCost: Double
    let slippageCost: Double
    let commissionCost: Double
    let financingCost: Double
    let takerFeeCost: Double
    nonisolated var total: Double { spreadCost + slippageCost + commissionCost + financingCost + takerFeeCost }
    nonisolated var dominantLeg: String {
        let legs: [(String, Double)] = [("spread", spreadCost), ("slippage", slippageCost),
                                        ("commission", commissionCost), ("financing", financingCost),
                                        ("takerFee", takerFeeCost)]
        return legs.max { $0.1 < $1.1 }?.0 ?? "spread"
    }
}

enum StockSageNetEdge {
    nonisolated static func skipForCostDominance(entry: Double, stop: Double, target: Double,
                                                 cost: AllInCost, winProb: Double = 1.0,
                                                 maxDominantLegPct: Double = 0.10)
        -> (skip: Bool, dominantLeg: String, legPctOfExpectedReward: Double)? {
        let grossReward = abs(target - entry)
        guard grossReward > 0, winProb > 0 else { return nil }
        let leg = cost.dominantLeg
        let legCost: Double
        switch leg {
        case "spread":     legCost = cost.spreadCost
        case "slippage":   legCost = cost.slippageCost
        case "commission": legCost = cost.commissionCost
        case "financing":  legCost = cost.financingCost
        case "takerFee":   legCost = cost.takerFeeCost
        default:           legCost = cost.spreadCost
        }
        let expectedReward = winProb * grossReward
        let pct = legCost / expectedReward
        return (pct > maxDominantLegPct, leg, pct)
    }
}

let c = AllInCost(spreadCost: 100*30/10000, slippageCost: 100*20/10000,
                  commissionCost: 0, financingCost: 0, takerFeeCost: 0)
let s = StockSageNetEdge.skipForCostDominance(entry: 100, stop: 99, target: 101, cost: c, winProb: 0.4)
print(s!.skip, s!.dominantLeg, s!.legPctOfExpectedReward)
assert(s!.skip && s!.dominantLeg == "spread" && abs(s!.legPctOfExpectedReward - 0.75) < 1e-9)

let s3 = StockSageNetEdge.skipForCostDominance(entry: 100, stop: 95, target: 110, cost: c, winProb: 0.4)
assert(!s3!.skip && abs(s3!.legPctOfExpectedReward - 0.075) < 1e-9)

let s4 = StockSageNetEdge.skipForCostDominance(entry: 100, stop: 95, target: 110, cost: c)
assert(!s4!.skip && abs(s4!.legPctOfExpectedReward - 0.03) < 1e-9)

let c2 = AllInCost(spreadCost: 50000*2/10000, slippageCost: 0, commissionCost: 0,
                   financingCost: 0, takerFeeCost: 50000*2*15/10000)
let s2 = StockSageNetEdge.skipForCostDominance(entry: 50000, stop: 49800, target: 50200, cost: c2)
print(s2!.skip, s2!.dominantLeg, s2!.legPctOfExpectedReward)
assert(s2!.skip && s2!.dominantLeg == "takerFee" && abs(s2!.legPctOfExpectedReward - 0.75) < 1e-9)

assert(StockSageNetEdge.skipForCostDominance(entry: 100, stop: 95, target: 100, cost: c) == nil)
print("SWIFT skipForCostDominance OK")
