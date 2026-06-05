import Foundation

/// Shared lock for any test that mutates the process-global
/// `AppSettings.Keys.brainPreference` UserDefaults key.
///
/// **Why this exists:** Swift Testing parallelizes tests across suites by
/// default. `@Suite(.serialized)` only serializes tests *within* one suite —
/// two serialized suites still run in parallel with each other. Multiple
/// suites currently exercise predicate logic that reads
/// `AppSettings.brainPreferenceCurrent` (which reads `UserDefaults.standard`
/// directly, with no injection seam), so they all need to mutate the same
/// global key. Without a shared lock, those suites race each other.
///
/// **Convention:** at the top of any test that writes `Keys.brainPreference`,
/// do **both** of these:
/// ```swift
/// BrainPreferenceTestLock.lock.lock()
/// defer { BrainPreferenceTestLock.lock.unlock() }
/// ```
/// Order matters — acquire the lock *before* declaring the defer. (If `defer`
/// came first, a test failing mid-acquisition would unlock a lock it never
/// took and trap.)
enum BrainPreferenceTestLock {
    nonisolated(unsafe) static let lock = NSLock()
}
