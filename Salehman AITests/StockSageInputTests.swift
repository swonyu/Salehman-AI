import Testing
import Foundation
@testable import Salehman_AI

// MARK: - Numeric input validation (pure)

struct StockSageInputTests {
    typealias I = StockSageInput

    @Test func positiveAmountAcceptsGoodRejectsBad() {
        #expect(I.positiveAmount("10000") == 10000)
        #expect(I.positiveAmount("10,000") == 10000)        // thousands separator
        #expect(I.positiveAmount("  1.5 ") == 1.5)          // whitespace + decimal
        #expect(I.positiveAmount("0") == nil)               // not > 0
        #expect(I.positiveAmount("-5") == nil)              // negative
        #expect(I.positiveAmount("abc") == nil)             // non-numeric
        #expect(I.positiveAmount("1.2.3") == nil)           // malformed
        #expect(I.positiveAmount("") == nil)
    }

    @Test func percentBoundedZeroToMax() {
        #expect(I.percent("1") == 1)
        #expect(I.percent("2.5") == 2.5)
        #expect(I.percent("100") == 100)                    // inclusive max
        #expect(I.percent("0") == nil)                      // not > 0
        #expect(I.percent("150") == nil)                    // over default max
        #expect(I.percent("100.1") == nil)
        #expect(I.percent("25", max: 20) == nil)            // custom cap
        #expect(I.percent("nope") == nil)
    }

    @Test func percentStripsThousandsSeparatorSameAsPositiveAmount() {
        // F04: percent shares `clean()` with positiveAmount — same thousands-separator
        // stripping, not a separate/divergent parse. "1,000" (default max 100) is comma-stripped
        // to 1000, which THEN correctly fails the max-100 bound (proves stripping happened,
        // not that the comma caused the parse to fail some other way).
        #expect(I.percent("1,000") == nil)
        #expect(I.percent("1,000", max: 2000) == 1000)      // raised cap: comma-stripped value is accepted
    }

    @Test func nonNegativeAmountAcceptsTypedZeroButNeverDefaultsOne() {
        // Cost basis: 0 is legal (gifted/granted shares) but must be TYPED — blank/unparseable
        // must be nil, never silently 0 (which fabricates a 100%-profit position).
        #expect(I.nonNegativeAmount("0") == 0)
        #expect(I.nonNegativeAmount("184.50") == 184.50)
        #expect(I.nonNegativeAmount("1,234.56") == 1234.56)   // broker-pasted thousands separator
        #expect(I.nonNegativeAmount("") == nil)               // blank ≠ free shares
        #expect(I.nonNegativeAmount("abc") == nil)
        #expect(I.nonNegativeAmount("-5") == nil)
        #expect(I.nonNegativeAmount("inf") == nil)            // Double("inf") parses — must be rejected
        #expect(I.nonNegativeAmount("nan") == nil)
    }

    @Test func positiveIntRejectsDecimalsAndNonPositive() {
        #expect(I.positiveInt("5000000") == 5_000_000)
        #expect(I.positiveInt("1,000") == 1000)
        #expect(I.positiveInt("0") == nil)
        #expect(I.positiveInt("-3") == nil)
        #expect(I.positiveInt("3.5") == nil)                // Int() rejects decimals
        #expect(I.positiveInt("ten") == nil)
    }

    // MARK: - F10: grouping-aware comma policy (Saudi decimal-comma vs US thousands)
    // Truth table hand-derived in /tmp/derive_f10_clean.swift. The load-bearing fix: the Saudi
    // decimal "2,5" (meaning 2.5%) used to be read as 25 — a silent 10× risk error that passed
    // the percent 100-cap. Now grouping-aware: valid 3-digit groups → thousands; a lone comma
    // with 1–2 trailing digits and no period → decimal; anything else → nil (reject, never guess).
    @Test func commaPolicyReadsSaudiDecimalNotTenTimesTheRisk() {
        // THE BUG, pinned: 2,5 is 2.5% — NOT 25% (which the old blind-strip produced and the cap passed).
        #expect(I.percent("2,5") == 2.5)
        #expect(I.percent("2,5") != 25)
        #expect(I.percent("12,34") == 12.34)
        #expect(I.percent("2,50") == 2.5)                   // trailing zero: 2.50 == 2.5
        #expect(I.positiveAmount("2,5") == 2.5)
        #expect(I.nonNegativeAmount("0,5") == 0.5)
    }

    @Test func commaPolicyPreservesThousandsGrouping() {
        // US/broker thousands separators must still work exactly as before.
        #expect(I.positiveAmount("10,000") == 10000)
        #expect(I.positiveAmount("1,234,567") == 1234567)
        #expect(I.nonNegativeAmount("1,234.56") == 1234.56)  // grouping + period decimal
        #expect(I.positiveInt("1,000") == 1000)
    }

    @Test func commaPolicyRejectsAmbiguousRatherThanFabricate() {
        #expect(I.positiveAmount("2,5000") == nil)           // 4-digit group: neither thousands nor decimal
        #expect(I.positiveAmount("1.000,50") == nil)         // EU full format (period thousands, comma decimal)
        #expect(I.positiveAmount("1,23,45") == nil)          // malformed grouping
        #expect(I.positiveAmount("1,2345") == nil)           // 4 trailing digits
        #expect(I.percent("2,5", max: 3) == 2.5)             // and it still respects the cap (2.5 ≤ 3)
        #expect(I.percent("2,5", max: 2) == nil)             // 2.5 > 2 → rejected (proves it's read as 2.5)
    }
}
