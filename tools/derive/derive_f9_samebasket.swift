// derive_f9_samebasket.swift — standalone re-derivation of the F9 same-basket fixture numbers
// cited (as a comment, previously dangling — no such file existed) in
// `Salehman AITests/StockSageExpectedValueTests.swift`'s
// `summaryWeeklyRGrossSameBasketMatchesNetBasketNotUnawareLane` test.
//
// Run: swift tools/derive/derive_f9_samebasket.swift
//
// Repo convention (skills/testing-discipline/SKILL.md): every asserted numeric literal in a
// test is HAND-DERIVED via a standalone script that replicates the engine's DOCUMENTED formulas
// — never by calling the code under test. This script imports NOTHING from the app; it
// reimplements only the formulas the test comment already cites:
//   winProbEstimate(conviction c)      = 0.35 + 0.23·c                     (StockSageExpectedValue, linear prior)
//   ev.evR                             = p·rewardR − (1−p)                (StockSageExpectedValue.ev)
//   NetEdge.netExpectancyR             = evR − cost/grossRisk             (StockSageNetEdge.evaluate; the
//                                         p·cost and −p·cost cross-terms cancel algebraically for any
//                                         entry/stop/target — see the derivation note below)
//   velocity(for:)                     = evR / expectedHoldDays
//   netVelocity(for:)                  = netEVR / expectedHoldDays
//   expectedWeeklyR(lane:...)          = Σ(top-N velocities) · tradingDays · concentrationFactor
//   netExpectedWeeklyR(lane:...)       = Σ(top-N netVelocities) · tradingDays · concentrationFactor
//
// Algebraic identity used above (netExpectancyR simplifies to evR − cost/grossRisk):
//   grossReward = target−entry = 30, grossRisk = entry−stop = 10 (fixture: entry 100/stop 90/target 130)
//   cappedGrossReward = min(grossRR,50)·grossRisk = grossReward (uncapped here, grossRR=3 < 50)
//   netReward = cappedGrossReward − cost,  netRisk = grossRisk + cost
//   netExpectancyR = (p·netReward − (1−p)·netRisk) / grossRisk
//                  = (p·(30−cost) − (1−p)·(10+cost)) / 10
//                  = (30p − p·cost − 10 + 10p − cost + p·cost) / 10     [the ±p·cost terms cancel]
//                  = (40p − 10 − cost) / 10
//                  = 4p − 1 − cost/10
//                  = evR − cost/10                                      (since evR = 4p−1 at rewardR=3)
// This identity is EXACT for this fixture's entry/stop/target, independent of the cost magnitude
// (so it applies unchanged to any asset class's cost table).

import Foundation

func winProb(_ c: Double) -> Double { 0.35 + 0.23 * c }
func evR(_ p: Double, rewardR: Double = 3.0) -> Double { p * rewardR - (1 - p) }
// US large-cap cost (StockSageNetEdge.defaultCosts, no suffix): spread 8 + slippage 5 + taker 0 = 13bps.
let usCostPerR = (8.0 + 5.0) / 10_000 * 100 / 10   // = 0.013
func netEVR(_ evRVal: Double) -> Double { evRVal - usCostPerR }

let convictions: [(name: String, c: Double)] = [
    ("A", 0.8), ("B", 0.7), ("C", 0.6), ("D", 0.5)
]

print("F9 same-basket fixture — entry 100 / stop 90 / target 130 (rewardR 3.0), Equity hold 12")
print(String(format: "US cost/R = %.6f", usCostPerR))
var vel: [String: Double] = [:]
var netVel: [String: Double] = [:]
for (name, c) in convictions {
    let p = winProb(c)
    let e = evR(p)
    let ne = netEVR(e)
    let v = e / 12
    let nv = ne / 12
    vel[name] = v
    netVel[name] = nv
    print(String(format: "%@: p=%.3f evR=%.3f netEVR=%.3f vel=%.10f netVel=%.10f", name, p, e, ne, v, nv))
}

// Unaware fastLane top-3 (no earnings/liquidity penalty) = {A,B,C}; D is 4th (strict conviction order).
let oldWeeklyR = (vel["A"]! + vel["B"]! + vel["C"]!) * 5 * 0.70
// C gets an earnings-imminent flag (-2000 rank-key penalty) → AWARE fastLane top-3 = {A,B,D}.
let weeklyRNet = (netVel["A"]! + netVel["B"]! + netVel["D"]!) * 5 * 0.70
let weeklyRGrossSameBasket = (vel["A"]! + vel["B"]! + vel["D"]!) * 5 * 0.70

print(String(format: "old weeklyR (basket ABC, unaware)          = %.10f", oldWeeklyR))
print(String(format: "weeklyRNet (basket ABD, aware)              = %.10f", weeklyRNet))
print(String(format: "weeklyRGrossSameBasket (basket ABD, aware)  = %.10f", weeklyRGrossSameBasket))
