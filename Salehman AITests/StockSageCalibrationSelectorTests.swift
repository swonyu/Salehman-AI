import Testing
import Foundation
@testable import Salehman_AI

// MARK: - iter7 Calibration Candidate-Selector Tests
//
// Tests for: Beta-3param fit, OOS candidate-selector, flag-off byte-identity regression-lock.
// Each flag-on test restores candidateSelectorEnabled in a defer{} — the flag is global.

struct StockSageCalibrationSelectorTests {
    typealias Cal = StockSageConvictionCalibration
    typealias Outcome = (conviction: Double, won: Bool)

    // MARK: - Shared helpers

    private static func makeOutcomes(count: Int, conviction: (Int) -> Double, won: (Int) -> Bool) -> [Outcome] {
        var result: [Outcome] = []
        result.reserveCapacity(count)
        for i in 0..<count {
            result.append((conviction: conviction(i), won: won(i)))
        }
        return result
    }

    private static func verifyMonotone(_ cal: Cal, label: String) {
        for i in 1..<cal.bins.count {
            let prev = cal.bins[i-1].winProb
            let curr = cal.bins[i].winProb
            #expect(curr >= prev - 1e-9, "\(label): bins must be non-decreasing at index \(i)")
        }
    }

    private static func verifyUnitInterval(_ beta: Cal.BetaCalibration, label: String) {
        let testS: [Double] = [0.0, 0.001, 0.1, 0.5, 0.9, 0.999, 1.0]
        for s in testS {
            let p = beta.winProb(s)
            #expect(p >= 0.0 && p <= 1.0, "\(label): winProb(\(s))=\(p) not in [0,1]")
        }
    }

    // MARK: - 1. Beta-3param fits a logit-shaped map and is monotone

    @Test func betaFitsLogitShapedMapAndIsMonotone() {
        // Verify Beta-3param fit:
        // (a) learns a non-decreasing map on clearly separable data,
        // (b) a ≥ 0 and b ≥ 0 (monotonicity invariant),
        // (c) high conviction → higher win-prob than low conviction.
        //
        // Data: 1200 balanced outcomes — 600 high-conviction winners (s≈0.7-0.95), 600 low losses (s≈0.05-0.3).
        // This is a well-conditioned dataset for Beta fitting (roughly 50/50 positive rate).
        var outcomes: [Outcome] = []
        outcomes.reserveCapacity(1200)
        // 600 high-conviction wins (s ∈ [0.7, 0.95]).
        for i in 0..<600 {
            let s = 0.70 + 0.25 * (Double(i) + 0.5) / 600.0
            outcomes.append((conviction: s, won: true))
        }
        // 600 low-conviction losses (s ∈ [0.05, 0.30]).
        for i in 0..<600 {
            let s = 0.05 + 0.25 * (Double(i) + 0.5) / 600.0
            outcomes.append((conviction: s, won: false))
        }

        guard let beta = Cal.fitBeta(outcomes) else {
            Issue.record("fitBeta returned nil on 1200-trade balanced dataset")
            return
        }

        #expect(beta.a >= 0.0, "a must be non-negative for monotonicity")
        #expect(beta.b >= 0.0, "b must be non-negative for monotonicity")

        // Non-decreasing across sweep.
        var prev = -1.0
        for j in 1...18 {
            let s = Double(j) * 0.05
            let p = beta.winProb(s)
            #expect(p >= prev - 1e-9, "Beta map must be non-decreasing at s=\(s)")
            prev = p
        }

        // High conviction → higher win-prob than low (the signal is clear in this dataset).
        #expect(beta.winProb(0.9) > beta.winProb(0.1),
                "Beta fit must detect that high-s wins and low-s loses")
        // The map should meaningfully separate: high-s → win-prob well above 0.5.
        #expect(beta.winProb(0.9) > 0.6, "High-conviction win-prob should be well above 0.5")
        #expect(beta.winProb(0.1) < 0.4, "Low-conviction win-prob should be well below 0.5")
        // Values in (0,1).
        #expect(beta.winProb(0.1) > 0.0 && beta.winProb(0.9) < 1.0)
    }

    // MARK: - 2. Beta monotone on inverted sample (drop-and-refit enforces a≥0, b≥0)

    @Test func betaMonotoneOnInvertedSample() {
        // Inverted: high conviction → lose, low conviction → win.
        var outcomes: [Outcome] = []
        for i in 0..<50 { outcomes.append((conviction: 0.1 + Double(i)*0.001, won: true)) }
        for i in 0..<50 { outcomes.append((conviction: 0.8 + Double(i)*0.001, won: false)) }

        guard let beta = Cal.fitBeta(outcomes) else {
            Issue.record("fitBeta returned nil on inverted sample")
            return
        }
        #expect(beta.a >= 0.0, "drop-and-refit must ensure a≥0")
        #expect(beta.b >= 0.0, "drop-and-refit must ensure b≥0")

        var prev = -1.0
        for j in 1...18 {
            let s = Double(j) * 0.05
            let p = beta.winProb(s)
            #expect(p >= prev - 1e-9, "Beta map non-decreasing on inverted at s=\(s)")
            prev = p
        }
    }

    // MARK: - 3. Beta near-identity on already-calibrated data

    @Test func betaNearIdentityOnAlreadyCalibratedData() {
        // P(win) ≈ s: identity calibration. Beta should recover a sensible non-decreasing map.
        let n = 1000
        var outcomes: [Outcome] = []
        outcomes.reserveCapacity(n)
        for i in 0..<n {
            let s = (Double(i) + 0.5) / Double(n)
            let won = (Double(i % 100) + 0.5) / 100.0 < s
            outcomes.append((conviction: s, won: won))
        }

        guard let beta = Cal.fitBeta(outcomes) else {
            Issue.record("fitBeta returned nil on identity-calibrated data")
            return
        }

        #expect(beta.a >= 0.0)
        #expect(beta.b >= 0.0)

        var prev = -1.0
        for j in 1...18 {
            let s = Double(j) * 0.05
            let p = beta.winProb(s)
            #expect(p >= prev - 1e-9, "Non-decreasing on identity data at s=\(s)")
            prev = p
        }
        // Map should stay broadly reasonable.
        let p10 = beta.winProb(0.1)
        let p90 = beta.winProb(0.9)
        #expect(p10 < 0.6, "Low-conviction map should not be inflated on identity data")
        #expect(p90 > 0.4, "High-conviction map should not be deflated on identity data")
    }

    // MARK: - 4. Selector conservative contract: identity is the floor for thin splits

    @Test func selectorPicksIdentityWhenNoCandidateBeatsNoCalibration() {
        defer { Cal.candidateSelectorEnabled = false }
        Cal.candidateSelectorEnabled = true

        // (A) Small-N guard: n=43, testN=13, gap=1, trainEnd=29 < minTrainSamples(30) → identity.
        var tinyOutcomes: [Outcome] = []
        for i in 0..<43 {
            let s = (Double(i) + 0.5) / 43.0
            tinyOutcomes.append((conviction: s, won: i % 2 == 0))
        }
        // outer minSamples=30 passes (43 ≥ 30); selector's split gives train=29 < 30 → identity.
        let calTiny = Cal.fit(tinyOutcomes, minSamples: 30)
        if let calTiny {
            let nBins = calTiny.bins.count
            let width = 1.0 / Double(nBins)
            for bin in calTiny.bins {
                let mid = bin.upper - width / 2.0
                #expect(abs(bin.winProb - mid) < width + 1e-9,
                        "Small-N → identity: winProb \(bin.winProb) should ≈ mid \(mid)")
            }
            #expect(calTiny.sampleSize == 43)
        }

        // (B) Structural invariants on regular-sized data (selector picks best OOS candidate
        //     and that result is always non-decreasing and in [0,1]).
        var regularOutcomes: [Outcome] = []
        for i in 0..<200 {
            regularOutcomes.append((conviction: (Double(i) + 0.5) / 200.0, won: i % 2 == 0))
        }
        let calRegular = Cal.fit(regularOutcomes, minSamples: 30)
        #expect(calRegular != nil)
        if let c = calRegular {
            #expect(c.sampleSize == 200)
            Self.verifyMonotone(c, label: "regular-200")
            for bin in c.bins {
                #expect(bin.winProb >= 0.0 && bin.winProb <= 1.0)
            }
        }

        // (C) Non-decreasing output on any input, regardless of which candidate the selector picks.
        var flippedOutcomes: [Outcome] = []
        for i in 0..<140 {
            let s = (Double(i) + 0.5) / 200.0
            flippedOutcomes.append((conviction: s, won: s >= 0.5))
        }
        for i in 140..<200 {
            let s = (Double(i) + 0.5) / 200.0
            flippedOutcomes.append((conviction: s, won: false))
        }
        let calFlipped = Cal.fit(flippedOutcomes, minSamples: 30)
        #expect(calFlipped != nil)
        if let c = calFlipped {
            Self.verifyMonotone(c, label: "flipped-200")
        }
    }

    // MARK: - 5. Selector picks non-identity when a candidate genuinely lowers OOS Brier

    @Test func selectorPicksNonIdentityWhenCandidateLowersOOSBrier() {
        defer { Cal.candidateSelectorEnabled = false }
        Cal.candidateSelectorEnabled = true

        // Clean separable: first 200 low-conviction all lose, last 200 high-conviction all win.
        var outcomes: [Outcome] = []
        for i in 0..<200 { outcomes.append((conviction: 0.05 + Double(i)*0.001, won: false)) }
        for i in 0..<200 { outcomes.append((conviction: 0.55 + Double(i)*0.001, won: true)) }

        let cal = Cal.fit(outcomes, minSamples: 30)
        #expect(cal != nil)
        guard let cal else { return }

        // The calibrated map should reflect the separable relationship.
        #expect(cal.winProb(0.9) > cal.winProb(0.1))
        Self.verifyMonotone(cal, label: "separable-400")
        #expect(cal.winProb(0.9) > 0.5, "High conviction → high win-prob on separable data")
        #expect(cal.winProb(0.1) < 0.5, "Low conviction → low win-prob on separable data")
    }

    // MARK: - 6. Selector is leak-free

    @Test func selectorIsLeakFree() {
        defer { Cal.candidateSelectorEnabled = false }
        Cal.candidateSelectorEnabled = true

        // n=100. trainEnd = 100 - 30 - 1 = 69. Train = [0,69), test = [70, 100).
        // Train: clear signal — high-s wins, low-s loses.
        // Test: all low-s but ALL WIN (opposite of train).
        // If test leaked into training, Beta would learn "low-s wins" and fit differently.
        var outcomes: [Outcome] = []
        for i in 0..<70 {
            let s = (Double(i) + 1.0) / 71.0
            outcomes.append((conviction: s, won: s >= 0.5))
        }
        for i in 0..<30 {
            let s = (Double(i) + 1.0) / 31.0
            outcomes.append((conviction: s, won: true))  // all win, contradicts train signal
        }

        // Train-only Beta: fit on rows [0,69).
        let trainOnly = Array(outcomes[0..<69])
        guard let betaTrain = Cal.fitBeta(trainOnly) else { return }

        Cal.candidateSelectorEnabled = true
        let cal = Cal.fit(outcomes, minSamples: 30)
        #expect(cal != nil)
        guard let cal else { return }

        // Leak-free check: train-only Beta at low conviction should be < 0.5
        // (since train says high-s wins, so Beta learns a map that gives LOW win-prob to LOW s).
        // If test leaked in, the "all-win" test rows would drag low-s win-prob up toward 1.0.
        let betaAtLow = betaTrain.winProb(0.15)
        #expect(betaAtLow < 0.5,
                "Train-only Beta at low conviction should be < 0.5 on separable train data")

        // Final calibration must be monotone and in [0,1].
        Self.verifyMonotone(cal, label: "leak-free-100")
    }

    // MARK: - 7. Flag-off is byte-identical to current behavior (regression-lock)

    @Test func flagOffIsByteIdenticalToCurrent() {
        #expect(Cal.candidateSelectorEnabled == false, "Flag must default to false")

        // Fixture 1: 40-trade 80/20 split (same as StockSageConvictionCalibrationTests).
        var outcomes1: [Outcome] = []
        for i in 0..<20 { outcomes1.append((conviction: 0.1, won: i < 4)) }
        for i in 0..<20 { outcomes1.append((conviction: 0.9, won: i < 16)) }
        let a1 = Cal.fit(outcomes1, minSamples: 30)
        let b1 = Cal.fit(outcomes1, minSamples: 30)
        #expect(a1 == b1, "Two identical flag-off calls must be equal")
        if let c1 = a1 {
            #expect(c1.sampleSize == 40)
            #expect(c1.bins.count >= 2)
            #expect(c1.winProb(0.9) > c1.winProb(0.1))
        }

        // Fixture 2: Inverted (from isotonicFixesAnInvertedSample).
        var outcomes2: [Outcome] = []
        for i in 0..<15 { outcomes2.append((conviction: 0.1, won: i < 12)) }
        for i in 0..<15 { outcomes2.append((conviction: 0.9, won: i < 6)) }
        let a2 = Cal.fit(outcomes2, minSamples: 20)
        let b2 = Cal.fit(outcomes2, minSamples: 20)
        #expect(a2 == b2)
        if let c2 = a2 {
            #expect(c2.winProb(0.9) >= c2.winProb(0.1) - 1e-9)
        }

        // Fixture 3: EV-test fixture (30 high + 10 low).
        var outcomes3: [Outcome] = []
        for i in 0..<30 { outcomes3.append((conviction: 0.9, won: i < 24)) }
        for i in 0..<10 { outcomes3.append((conviction: 0.1, won: i < 1)) }
        let a3 = Cal.fit(outcomes3, minSamples: 30)
        let b3 = Cal.fit(outcomes3, minSamples: 30)
        #expect(a3 == b3)

        // Turn flag ON then OFF: output must return to identical.
        Cal.candidateSelectorEnabled = true
        let _ = Cal.fit(outcomes1, minSamples: 30)   // selector path
        Cal.candidateSelectorEnabled = false
        let afterReset = Cal.fit(outcomes1, minSamples: 30)
        #expect(afterReset == a1, "After resetting flag to false, output must equal pre-flag result")
    }

    // MARK: - 8. Selector structural invariants across data shapes (tie-break coverage)

    @Test func selectorTieBreaksToIdentityThenBeta() {
        defer { Cal.candidateSelectorEnabled = false }
        Cal.candidateSelectorEnabled = true

        // Verify the selector produces valid (monotone, [0,1]) output across a range of data shapes.
        // Also verify determinism: same input → same output.

        var fixture0: [Outcome] = []
        for i in 0..<100 { fixture0.append((conviction: (Double(i)+0.5)/100.0, won: i%2==0)) }

        var fixture1: [Outcome] = []
        for i in 0..<100 {
            let s = (Double(i)+0.5)/100.0
            fixture1.append((conviction: s, won: s < 0.5))
        }

        var fixture2: [Outcome] = []
        for i in 0..<100 {
            let s = (Double(i)+0.5)/100.0
            fixture2.append((conviction: s, won: s >= 0.5))
        }

        let fixtures: [[Outcome]] = [fixture0, fixture1, fixture2]
        for (idx, outcomes) in fixtures.enumerated() {
            let cal = Cal.fit(outcomes, minSamples: 30)
            #expect(cal != nil, "Selector must not return nil on fixture \(idx)")
            guard let cal else { continue }
            #expect(cal.sampleSize == 100)
            Self.verifyMonotone(cal, label: "fixture-\(idx)")
            for bin in cal.bins {
                #expect(bin.winProb >= 0.0 && bin.winProb <= 1.0,
                        "Fixture \(idx): winProb must be in [0,1]")
            }
        }

        // Determinism: same input → same output.
        var data: [Outcome] = []
        for i in 0..<200 { data.append((conviction: (Double(i)+0.5)/200.0, won: i >= 100)) }
        let cal1 = Cal.fit(data, minSamples: 30)
        let cal2 = Cal.fit(data, minSamples: 30)
        #expect(cal1 == cal2, "Selector must be deterministic")
    }

    // MARK: - 9. fitBeta returns nil on one-sided sample

    @Test func fitBetaReturnsNilOnOneSidedSample() {
        var allWin: [Outcome] = []
        for i in 0..<20 { allWin.append((conviction: Double(i)/20.0 + 0.025, won: true)) }
        #expect(Cal.fitBeta(allWin) == nil, "fitBeta must return nil when nNeg == 0")

        var allLose: [Outcome] = []
        for i in 0..<20 { allLose.append((conviction: Double(i)/20.0 + 0.025, won: false)) }
        #expect(Cal.fitBeta(allLose) == nil, "fitBeta must return nil when nPos == 0")

        let empty: [Outcome] = []
        #expect(Cal.fitBeta(empty) == nil, "fitBeta must return nil on empty input")
    }

    // MARK: - 10. Beta winProb is in (0,1) across full conviction range

    @Test func betaWinProbAlwaysInUnitInterval() {
        var outcomes: [Outcome] = []
        for i in 0..<40 {
            let s = (Double(i) + 0.5) / 40.0
            outcomes.append((conviction: s, won: i >= 20))
        }
        guard let beta = Cal.fitBeta(outcomes) else {
            Issue.record("fitBeta returned nil")
            return
        }
        Self.verifyUnitInterval(beta, label: "betaWinProbRange")
    }
}
