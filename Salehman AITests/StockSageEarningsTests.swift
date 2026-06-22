import Testing
import Foundation
@testable import Salehman_AI

// MARK: - Earnings proximity (pure)

struct StockSageEarningsTests {

    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    @Test func severityBands() {
        #expect(StockSageEarnings.severity(daysUntil: 0) == .imminent)
        #expect(StockSageEarnings.severity(daysUntil: 3) == .imminent)
        #expect(StockSageEarnings.severity(daysUntil: 4) == .soon)
        #expect(StockSageEarnings.severity(daysUntil: 10) == .soon)
        #expect(StockSageEarnings.severity(daysUntil: 11) == .clear)
    }

    @Test func proximityCountsDaysAndFloorsThePast() {
        let inTwo = now.addingTimeInterval(2 * 86_400)
        let p = StockSageEarnings.proximity(now: now, earnings: inTwo)
        #expect(p.daysUntil == 2)
        #expect(p.severity == .imminent)
        #expect(p.isWarning)

        #expect(StockSageEarnings.proximity(now: now, earnings: now.addingTimeInterval(7 * 86_400)).severity == .soon)
        #expect(StockSageEarnings.proximity(now: now, earnings: now.addingTimeInterval(30 * 86_400)).severity == .clear)

        // A just-passed date floors to 0 (not negative).
        let past = StockSageEarnings.proximity(now: now, earnings: now.addingTimeInterval(-5 * 86_400))
        #expect(past.daysUntil == 0)
    }

    @Test func parsesSoonestEarningsEpoch() {
        let soon = 1_700_500_000.0, later = 1_700_900_000.0
        let json = """
        {"quoteSummary":{"result":[{"calendarEvents":{"earnings":{"earningsDate":[
          {"raw":\(later),"fmt":"later"},{"raw":\(soon),"fmt":"soon"}]}}}],"error":null}}
        """
        let date = StockSageEarnings.parseEarningsDate(Data(json.utf8))
        #expect(date == Date(timeIntervalSince1970: soon))
    }

    @Test func malformedOrEmptyBodyParsesToNil() {
        #expect(StockSageEarnings.parseEarningsDate(Data("{}".utf8)) == nil)
        #expect(StockSageEarnings.parseEarningsDate(Data("not json".utf8)) == nil)
        let noDates = """
        {"quoteSummary":{"result":[{"calendarEvents":{"earnings":{"earningsDate":[]}}}]}}
        """
        #expect(StockSageEarnings.parseEarningsDate(Data(noDates.utf8)) == nil)
    }
}
