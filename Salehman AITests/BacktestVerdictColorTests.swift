import Testing
import SwiftUI
@testable import Salehman_AI

// MARK: - Significance-gated backtest verdict color (AUDIT_FINDINGS_2 #1)
//
// Truth table from the finding's own spec (python sketch in AUDIT_FINDINGS_2.md #1):
// color(pos, sig) = neutral if !sig else (green if pos else red). Token equality, not RGB.

struct BacktestVerdictColorTests {
    @Test func insignificantSamplesRenderNeutralRegardlessOfSign() {
        #expect(BacktestVerdict.metricColor(positive: true, significant: false) == DS.Palette.textSecondary)
        #expect(BacktestVerdict.metricColor(positive: false, significant: false) == DS.Palette.textSecondary)
        #expect(BacktestVerdict.metricColor(positive: true, significant: true) == DS.Palette.successSoft)
        #expect(BacktestVerdict.metricColor(positive: false, significant: true) == DS.Palette.danger)
        // The gate must actually distinguish: neutral ≠ either verdict token.
        #expect(DS.Palette.textSecondary != DS.Palette.successSoft)
        #expect(DS.Palette.textSecondary != DS.Palette.danger)
    }
}
