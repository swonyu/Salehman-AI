import Foundation

/// The "stock analysis" tool Salehman agents can call.
enum StockSageTool {

    static func detectTicker(in mission: String) -> String {
        let m = mission.lowercased()
        if m.contains("aramco") || m.contains("2222") { return "2222.SR" }
        if m.contains("rajhi")  || m.contains("1120") { return "1120.SR" }
        if m.contains("alinma") || m.contains("1150") { return "1150.SR" }
        if let range = mission.range(of: #"\d{4}\.SR"#, options: [.regularExpression, .caseInsensitive]) {
            return mission[range].uppercased()
        }
        return "2222.SR"
    }

    static func deepAnalysis(ticker: String) -> String {
        let macroNote = StockSageMini.saudiMacroNote()
        let visionScore = StockSageMini.visionImpactScore(ticker: ticker)
        let observations = """
        Saudi macro snapshot: \(macroNote)
        Vision 2030 impact score for \(ticker): \(String(format: "%.2f", visionScore)) / 10.
        """
        return StockSageMini.deepReasoningReport(ticker: ticker, observations: observations)
    }
}
