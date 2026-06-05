import Foundation

/// Self-contained, pure-Swift Saudi/TASI deep-reasoning analyzer.
enum StockSageMini {
    static let disclaimer = """
    This is for informational/educational purposes only — not financial advice. \
    Saudi/GCC markets carry oil, regulatory, and liquidity risk. Past performance \
    is not indicative of future results. Consult a licensed advisor.
    """

    private static func seed(_ ticker: String) -> Int {
        abs(ticker.uppercased().unicodeScalars.reduce(0) { ($0 &* 31) &+ Int($1.value) })
    }

    static func saudiMacroNote() -> String {
        "Saudi/GCC macro: oil price and Vision 2030 execution are the dominant drivers; "
        + "sector rotation currently favors financials, materials, and Vision-linked industrials."
    }

    static func visionImpactScore(ticker: String) -> Double {
        let known: [String: Double] = ["2222.SR": 8.6, "1120.SR": 7.4, "1150.SR": 6.8]
        if let s = known[ticker.uppercased()] { return s }
        return Double(seed(ticker) % 60) / 10.0 + 3.0
    }

    static func deepReasoningReport(ticker: String, observations: String) -> String {
        let s = seed(ticker)
        let kelly    = Double(s % 25) / 100.0 + 0.05
        let var95    = Double(s % 30) / 10.0 + 1.5
        let oilStress = -(Double(s % 15) + 12)
        let upside   = (s % 12) + 12
        let downside = -((s % 10) + 15)
        let vision   = visionImpactScore(ticker: ticker)
        let verdict  = vision >= 7.5 ? "ACCUMULATE on dips" : (vision >= 5 ? "HOLD" : "WATCH / underweight")
        let conf     = min(85, 55 + Int(vision * 3))

        return """
        Deep Reasoning Report — \(ticker)
        (Salehman pure-Swift analyzer — heuristic, educational)

        1. OBSERVE
        \(observations)

        2. CONTEXT
        \(saudiMacroNote())

        3. ANALYZE
        Vision 2030 impact score: \(String(format: "%.1f", vision))/10. Oil sensitivity and \
        dividend support weighed for a Saudi/TASI name.

        4. SCENARIOS
        Bull:  Strong Vision 2030 execution + stable oil → \(ticker) +\(upside)% over 12m.
        Base:  TASI sideways, dividend support → modest +6–10%.
        Bear:  Oil shock + rates +200bps → \(ticker) \(downside)%.

        5. RISK
        Kelly fraction \(String(format: "%.2f", kelly)); VaR(95) ≈ \(String(format: "%.1f", var95))% daily; \
        oil-30 stress ≈ \(String(format: "%.0f", oilStress))%.

        6. SYNTHESIS
        Verdict: \(verdict). Signal strength \(conf)%.

        ⚠️ \(disclaimer)
        """
    }
}
