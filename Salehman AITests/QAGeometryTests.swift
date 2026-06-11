import Testing
import Foundation
@testable import Salehman_AI

// MARK: - QAGeometry.chatAssertions — the layout-invariant verdicts
//
// The geometry probe's first live run failed `chat_narrow` because the
// expected-width formula was miscalibrated (the transcript's 18pt padding
// lives INSIDE the measured frame, so the column is min(780, rootWidth), not
// rootWidth−36). These tests pin the calibrated formula and the verdict logic
// so a future "obvious cleanup" can't silently re-break the audit.
//
// `@MainActor` + `.serialized`: the suite drives the shared frame collector
// (`QAGeometry.frames` via `record`), which is MainActor state. This file is
// the sole test mutator of it.

@MainActor
@Suite(.serialized)
struct QAGeometryTests {

    private func withCleanCollector(_ body: () -> Void) {
        QAGeometry.enabled = true
        QAGeometry.reset()
        defer { QAGeometry.enabled = false; QAGeometry.reset() }
        body()
    }

    @Test func wideLayoutPassesWithCappedCenteredColumn() {
        withCleanCollector {
            // 1000pt root: column capped at 780, centered; composer aligned.
            QAGeometry.record("chat.column", CGRect(x: 110, y: 0, width: 780, height: 600))
            QAGeometry.record("chat.input",  CGRect(x: 110, y: 610, width: 780, height: 80))
            let results = QAGeometry.chatAssertions(rootWidth: 1000)
            #expect(results.allSatisfy(\.pass), "\(results)")
        }
    }

    @Test func narrowLayoutPassesAtFullWidth() {
        withCleanCollector {
            // 560pt root: the column IS the root width (padding lives inside).
            QAGeometry.record("chat.column", CGRect(x: 0, y: 0, width: 560, height: 600))
            QAGeometry.record("chat.input",  CGRect(x: 0, y: 610, width: 560, height: 80))
            let results = QAGeometry.chatAssertions(rootWidth: 560)
            #expect(results.allSatisfy(\.pass), "\(results)")
        }
    }

    @Test func offCenterColumnFails() {
        withCleanCollector {
            // Same width, shifted 20pt right — centering must fail.
            QAGeometry.record("chat.column", CGRect(x: 130, y: 0, width: 780, height: 600))
            QAGeometry.record("chat.input",  CGRect(x: 110, y: 610, width: 780, height: 80))
            let results = QAGeometry.chatAssertions(rootWidth: 1000)
            #expect(results.contains { $0.name == "geo:column centered" && !$0.pass })
        }
    }

    @Test func wrongWidthFails() {
        withCleanCollector {
            // Centered but 700pt wide at a 1000pt root (cap is 780) — width fails.
            QAGeometry.record("chat.column", CGRect(x: 150, y: 0, width: 700, height: 600))
            QAGeometry.record("chat.input",  CGRect(x: 110, y: 610, width: 780, height: 80))
            let results = QAGeometry.chatAssertions(rootWidth: 1000)
            #expect(results.contains { $0.name == "geo:column width" && !$0.pass })
        }
    }

    @Test func missingColumnSkipsGracefullyButMissingInputFails() {
        withCleanCollector {
            // Empty transcript: no column frame is LEGITIMATE (the welcome has
            // its own layout) — but the composer always exists, so its absence
            // is a real failure.
            let results = QAGeometry.chatAssertions(rootWidth: 1000)
            #expect(results.first { $0.name == "geo:column centered" }?.pass == true)
            #expect(results.first { $0.name == "geo:input in column" }?.pass == false)
        }
    }

    @Test func recordIsANoOpWhenDisabled() {
        QAGeometry.enabled = false
        QAGeometry.reset()
        QAGeometry.record("chat.column", CGRect(x: 0, y: 0, width: 780, height: 600))
        #expect(QAGeometry.frames.isEmpty, "record must be free when no capture is running")
    }
}
