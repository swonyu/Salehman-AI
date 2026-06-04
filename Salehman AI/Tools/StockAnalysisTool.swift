import Foundation
#if canImport(FoundationModels)
import FoundationModels

/// Lets the assistant pull a heuristic Saudi/TASI stock analysis on demand.
/// Wraps the local, offline `StockSageTool`/`StockSageMini` analyzer.
struct StockAnalysisTool: Tool {
    let name = "analyze_stock"
    let description = """
    Produce an educational Saudi/TASI (Tadawul) stock analysis for a company or \
    ticker the user mentions (e.g. Aramco/2222, Al Rajhi/1120, Alinma/1150). \
    Returns bull/base/bear scenarios, a Vision 2030 impact score, and risk \
    metrics. Heuristic and EDUCATIONAL ONLY — not financial advice.
    """

    @Generable
    struct Arguments {
        @Guide(description: "The company name or .SR ticker to analyze (e.g. 'Aramco' or '2222.SR').")
        var query: String
    }

    func call(arguments: Arguments) async throws -> String {
        let ticker = StockSageTool.detectTicker(in: arguments.query)
        return StockSageTool.deepAnalysis(ticker: ticker)
    }
}
#endif
