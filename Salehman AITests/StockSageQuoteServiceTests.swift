import Testing
import Foundation
@testable import Salehman_AI

// MARK: - Quote feed parsing — only-real-data validity guards

struct StockSageQuoteServiceTests {

    @Test func parseHistoryRejectsNonPositiveBars() {
        // 4 bars: bar 2 has a 0 close, bar 4 has a negative low — both must be dropped so a
        // garbage price can never become latestClose → price×shares / EV / sizing.
        let json = """
        {"chart":{"result":[{"timestamp":[1,2,3,4],
          "indicators":{"quote":[{
            "open":[10,11,12,13],
            "high":[11,12,13,14],
            "low":[9,10,11,-1],
            "close":[10,0,12,13],
            "volume":[100,100,100,100]}]}}]}}
        """
        let h = StockSageQuoteService.parseHistory(Data(json.utf8), symbol: "TEST")
        #expect(h != nil)
        if let h {
            #expect(h.closes.count == 2)               // bars 1 and 3 only
            #expect(h.closes.allSatisfy { $0 > 0 })
            #expect(h.closes == [10, 12])
        }
        // All-bad input → fewer than 2 valid bars → nil (existing guard).
        let bad = """
        {"chart":{"result":[{"timestamp":[1,2],
          "indicators":{"quote":[{"open":[1,1],"high":[1,1],"low":[1,1],"close":[0,-5],"volume":[0,0]}]}}]}}
        """
        #expect(StockSageQuoteService.parseHistory(Data(bad.utf8), symbol: "X") == nil)
    }
}
