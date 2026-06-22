import Testing
import Foundation
@testable import Salehman_AI

// MARK: - Glossary & asset-class risk notes (pure)

struct StockSageGlossaryTests {

    @Test func assetClassRiskNotesMatchClass() {
        #expect(StockSageGlossary.assetClassRiskNote(for: "BTC-USD")?.contains("24/7") == true)
        #expect(StockSageGlossary.assetClassRiskNote(for: "EURUSD=X")?.contains("notional") == true)
        #expect(StockSageGlossary.assetClassRiskNote(for: "^GSPC")?.contains("index") == true)
        // A plain equity has no special note.
        #expect(StockSageGlossary.assetClassRiskNote(for: "AAPL") == nil)
        #expect(StockSageGlossary.assetClassRiskNote(for: "2222.SR") == nil)
    }

    @Test func everyCardHelpIsNonEmptyAndHonest() {
        let helps = [
            StockSageGlossary.analyticsHelp, StockSageGlossary.regimeHelp,
            StockSageGlossary.kellyHelp, StockSageGlossary.heatmapHelp,
            StockSageGlossary.strategyHelp, StockSageGlossary.journalHelp,
        ]
        for h in helps { #expect(h.count > 40) }
        // The honesty thread: backward-looking / not-a-forecast language somewhere.
        let joined = helps.joined(separator: " ").lowercased()
        #expect(joined.contains("backward-looking") || joined.contains("not a") || joined.contains("doesn't"))
    }

    @Test func diversificationHelpMatchesRendered0to100Scale() {
        // UI renders "%.0f / 100"; the tooltip must not claim a 0–1 scale.
        #expect(StockSageGlossary.analyticsHelp.contains("0–100"))
    }
}
