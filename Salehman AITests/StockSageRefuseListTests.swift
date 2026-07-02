import Testing
import Foundation   // CharacterSet.decimalDigits / rangeOfCharacter(from:) — disclosed deviation: plan's file omitted this import (its Step-12d sibling includes it)
@testable import Salehman_AI

// MARK: - Refuse-list policy (Item A, week-horizon research roadmap #1)
//
// Expected values transcribed from RESEARCH_2026-07-02_week_horizon_velocity.md (the captured,
// adversarially-verified spec) — never from the code under test (spec-fidelity/F40).

struct StockSageRefuseListTests {

    @Test func policyEncodesAllSevenVerifiedRefusals() {
        // Research refuse-list has exactly 7 numbered items.
        #expect(StockSageRefuseList.all.count == 7)
        #expect(Set(StockSageRefuseList.all.map(\.id)).count == 7)   // ids unique
        // Every entry carries load-bearing EVIDENCE (a number), not a bare opinion.
        for setup in StockSageRefuseList.all {
            #expect(!setup.title.isEmpty)
            #expect(setup.evidence.rangeOfCharacter(from: .decimalDigits) != nil)
        }
        // The single most load-bearing verified number: reversal flips to −1.28%/mo NET.
        guard let reversal = StockSageRefuseList.all.first(where: { $0.id == "naive-reversal" }) else {
            Issue.record("naive-reversal entry missing"); return
        }
        #expect(reversal.evidence.contains("−1.28"))
    }

    @Test func publishedEffectHaircutMatchesMcLeanPontiff() {
        // Research: predictors decay 26% out-of-sample / 58% post-publication (verified 3-0 ×3).
        #expect(StockSageRefuseList.outOfSampleDecay == 0.26)
        #expect(StockSageRefuseList.postPublicationDecay == 0.58)
    }

    @Test func policySurfacesStayHonest() {
        let note = StockSageRefuseList.policyNote.lowercased()
        let caveat = StockSageRefuseList.caveat.lowercased()
        #expect(note.contains("refused"))
        #expect(caveat.contains("not alpha") && caveat.contains("never a promise"))
        // Honesty floor: no promise language anywhere in the policy surfaces.
        for banned in ["guarantee", "sure thing", "free money", "risk-free"] {
            #expect(!note.contains(banned))
        }
    }
}
