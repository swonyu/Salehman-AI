import Testing
import Foundation
@testable import Salehman_AI

// MARK: - RuneScape Grand Exchange feed (pure parsing — no network)
//
// `parseLatest` / `parseMapping` turn raw prices.runescape.wiki JSON into the
// models the RuneScape tab renders, so they carry the feed's correctness. These
// pin the happy path plus every malformed shape that must degrade to empty
// (never crash, never a bogus row).

struct RuneScapeParseTests {

    @Test func priceStalenessFlagsTheOlderLeg() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        // Buy leg 10 min old, sell leg 2 days old → oldest = 2 days → stale (the spread may not fill).
        let p = RuneScapePrice(high: 100, highTime: now.addingTimeInterval(-600),
                               low: 90, lowTime: now.addingTimeInterval(-2 * 86_400))
        #expect((p.oldestLegAge(asOf: now) ?? -1) == TimeInterval(2 * 86_400))
        #expect(p.isStale(asOf: now))                        // > 60-min default
        // Both legs fresh → not stale.
        let fresh = RuneScapePrice(high: 100, highTime: now.addingTimeInterval(-300),
                                   low: 90, lowTime: now.addingTimeInterval(-120))
        #expect(!fresh.isStale(asOf: now))
        // No feed timestamps at all → can't judge → nil age, not stale.
        let undated = RuneScapePrice(high: 100, highTime: nil, low: 90, lowTime: nil)
        #expect(undated.oldestLegAge(asOf: now) == nil && !undated.isStale(asOf: now))
        // Both legs PRICED but only one timestamped → unverifiable freshness → stale, and not ageable
        // (a half-undated spread must NOT render as a fresh flip — caught as a self-regression).
        let halfDated = RuneScapePrice(high: 100, highTime: now.addingTimeInterval(-60), low: 90, lowTime: nil)
        #expect(halfDated.isStale(asOf: now))
        #expect(halfDated.oldestLegAge(asOf: now) == nil)
    }

    @Test func parsesLatestPricesAndMargin() {
        let json = #"{"data":{"4151":{"high":2000000,"highTime":1700000000,"low":1950000,"lowTime":1700000100},"561":{"high":95,"low":92,"highTime":1,"lowTime":2}}}"#
        let prices = RuneScapeMarketService.parseLatest(Data(json.utf8))
        #expect(prices.count == 2)
        #expect(prices[4151]?.high == 2_000_000)
        #expect(prices[4151]?.low == 1_950_000)
        #expect(prices[4151]?.margin == 50_000)
        #expect(prices[561]?.high == 95)
    }

    @Test func latestTimestampsDecodeToDates() {
        let json = #"{"data":{"2":{"high":10,"highTime":1700000000,"low":9,"lowTime":1700000000}}}"#
        let p = RuneScapeMarketService.parseLatest(Data(json.utf8))[2]
        #expect(p?.highTime == Date(timeIntervalSince1970: 1_700_000_000))
    }

    @Test func malformedLatestYieldsEmpty() {
        #expect(RuneScapeMarketService.parseLatest(Data("not json".utf8)).isEmpty)
        #expect(RuneScapeMarketService.parseLatest(Data("{}".utf8)).isEmpty)
        // A non-numeric id key is skipped, not crashed on.
        #expect(RuneScapeMarketService.parseLatest(Data(#"{"data":{"abc":{"high":1}}}"#.utf8)).isEmpty)
    }

    @Test func parsesMappingAndDropsIncompleteRows() {
        let json = #"[{"id":4151,"name":"Abyssal whip","examine":"A weapon from the abyss.","members":true,"limit":70},{"name":"NoId"},{"id":2}]"#
        let items = RuneScapeMarketService.parseMapping(Data(json.utf8))
        #expect(items.count == 1)                       // the two id/name-incomplete rows are dropped
        #expect(items.first?.name == "Abyssal whip")
        #expect(items.first?.buyLimit == 70)
        #expect(items.first?.members == true)
    }

    @Test func itemIconURLIsWellFormed() {
        let item = RuneScapeItem(id: 4151, name: "Abyssal whip", examine: "", members: true, buyLimit: nil)
        #expect(item.iconURL?.absoluteString.contains("id=4151") == true)
    }

    @Test func featuredListIsNonEmptyAndUnique() {
        let ids = RuneScapeMarketService.featuredIDs
        #expect(ids.count >= 15)
        #expect(Set(ids).count == ids.count)            // no duplicate featured ids
    }
}

// MARK: - GP formatting

struct RuneScapeFormatTests {
    @Test func compactsLargeNumbers() {
        #expect(RSFormat.gp(2_000_000_000) == "2.00B")
        #expect(RSFormat.gp(1_500_000) == "1.50M")
        #expect(RSFormat.gp(250_000) == "250.0K")
    }
    @Test func smallNumbersStayWhole() {
        // Sub-thousand values keep full digits (single digit is locale-stable).
        #expect(RSFormat.gp(0) == "0")
        #expect(RSFormat.gp(5) == "5")
    }
    @Test func negativeMarginsKeepSign() {
        #expect(RSFormat.gp(-1_500_000) == "-1.50M")
    }
}
