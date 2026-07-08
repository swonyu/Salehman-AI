import Testing
import Foundation
@testable import Salehman_AI

// MARK: - QA directory resolution — the invariant that broke 2026-07-05 → 07-08
//
// QASnapshots, QAAudit, and QACapture each carried a self-contained copy of the
// qa/ directory resolution. The 2026-07-05 repo move (~/Desktop/Salehman AI →
// ~/Salehman-AI) repointed only QASnapshots' copy, so captures landed in the
// live repo while baseline adoption (QAAudit) wrote/read the dead Desktop copy —
// the pixel-diff tripwire compared against nothing ("no baseline adopted yet"
// on all 32 surfaces in qa/snapshots/AUDIT.json). All three now delegate to the
// shared `QADir.resolved`; this suite pins that they can never split again.
//
// `QASnapshots.qaDir` is private and stays private (nothing outside the file
// needs it) — it is `QADir.resolved` by construction (a one-line delegation),
// so pinning `QADir.resolved` covers it. `QAAudit.defaultQADir` and
// `QACapture.qaDir` are internal and pinned directly.
@MainActor
struct QADirResolutionTests {

    /// Every QA tool resolves the SAME directory — a re-forked copy in any one
    /// of them (the exact drift class of the 2026-07-05 incident) fails here.
    @Test func auditAndCaptureResolveTheSharedQADir() {
        let shared = QADir.resolved
        #expect(QAAudit.defaultQADir == shared)
        #expect(QACapture.qaDir == shared)
    }

    /// The shared resolution targets the LIVE repo (~/Salehman-AI/qa), not the
    /// dead pre-move ~/Desktop/Salehman AI copy. Pinned as the last two path
    /// components; the leading components are the machine-specific home dir.
    /// (If QA_SNAPSHOT_DIR is ever exported into a test run this fails loudly —
    /// correct: the invariant under test is the DEFAULT resolution.)
    @Test func sharedQADirTargetsLiveRepo() {
        #expect(Array(QADir.resolved.pathComponents.suffix(2)) == ["Salehman-AI", "qa"])
    }
}
