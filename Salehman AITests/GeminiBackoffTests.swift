import Testing
import Foundation
@testable import Salehman_AI

// MARK: - GeminiClient retry/backoff policy (hermetic — no network)
//
// GeminiClient.chat() retries transient 429/503 responses with exponential
// backoff. The retry LOOP needs a live URLSession, but the two decisions that
// drive it are pure functions — so we pin those: which statuses retry, and how
// the delay grows/caps. No keychain, no network, fully deterministic.

struct GeminiBackoffTests {

    @Test func onlyRateLimitAndUnavailableRetry() {
        #expect(GeminiClient.isRetryableStatus(429))   // rate-limited / RESOURCE_EXHAUSTED
        #expect(GeminiClient.isRetryableStatus(503))   // service unavailable
        // Everything else surfaces immediately — no pointless retries.
        #expect(GeminiClient.isRetryableStatus(200) == false)
        #expect(GeminiClient.isRetryableStatus(400) == false)
        #expect(GeminiClient.isRetryableStatus(401) == false)
        #expect(GeminiClient.isRetryableStatus(404) == false)
        #expect(GeminiClient.isRetryableStatus(500) == false)
    }

    @Test func backoffIsExponential() {
        // base 0.5 · 2^attempt → 0.5, 1, 2, 4 …
        #expect(GeminiClient.backoffDelay(attempt: 0) == 0.5)
        #expect(GeminiClient.backoffDelay(attempt: 1) == 1.0)
        #expect(GeminiClient.backoffDelay(attempt: 2) == 2.0)
        #expect(GeminiClient.backoffDelay(attempt: 3) == 4.0)
        // strictly increasing across the retry budget
        for a in 0..<GeminiClient.maxRetries {
            #expect(GeminiClient.backoffDelay(attempt: a) < GeminiClient.backoffDelay(attempt: a + 1))
        }
    }

    @Test func backoffIsCappedAndNonNegative() {
        // Far-out attempts saturate at the cap rather than growing unbounded.
        #expect(GeminiClient.backoffDelay(attempt: 100) == 8.0)
        #expect(GeminiClient.backoffDelay(attempt: 4, cap: 8.0) == 8.0)   // 0.5·2^4 = 8 (==cap)
        // Defensive: a negative attempt clamps to attempt 0, never a negative delay.
        #expect(GeminiClient.backoffDelay(attempt: -5) == 0.5)
    }

    @Test func retryBudgetIsBounded() {
        // The policy retries a finite number of times (so a stuck 503 can't loop forever).
        #expect(GeminiClient.maxRetries >= 1)
        #expect(GeminiClient.maxRetries <= 10)
    }
}
