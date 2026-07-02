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
}
