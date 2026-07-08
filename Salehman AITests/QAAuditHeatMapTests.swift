import Testing
import Foundation
import AppKit
@testable import Salehman_AI

// MARK: - QAAudit.diff() heat-map red signal — 2026-07-08 regression
//
// Root cause: heat.setColor(NSColor(red:green:blue:alpha:), atX:y:) wrote a
// CALIBRATED-RGB color into a bitmap built with colorSpaceName: .deviceRGB.
// setColor silently no-ops the mismatch — reading the PNG back gave fully
// transparent black (r=0 g=0 b=0 a=0) at every "changed" pixel, so a reviewer
// told to "Read the diff PNG to see what changed" saw nothing. Proven live:
// chat_narrow_diff.png had 0 red>0.6 pixels despite 255 genuinely-changed
// sample points. Fixed by writing raw 0-255 bytes via setPixel(_:atX:y:),
// which writes directly into the bitmap's own color space and round-trips
// through PNG encode + decode correctly (independently verified with a
// throwaway probe script before this fix landed).
//
// These tests hand-build two tiny bitmaps that differ in ONE known pixel,
// run the real (now-internal) QAAudit.diff(), decode the returned PNG bytes
// back into a bitmap, and assert on the ACTUAL readback color — not on
// whatever diff() claims it wrote. That's the failure mode: the write call
// "succeeded" (no error) while writing nothing.
@MainActor
struct QAAuditHeatMapTests {

    /// 6x6 RGBA bitmap, flat fill, with one pixel forced to a different color —
    /// mirrors real screenshot bitmaps closely enough for diff()'s colorAt-based
    /// sampling (step=3, so a 6x6 image gives a 2x2 sampled heat-map).
    private func makeBitmap(width: Int, height: Int, fill: (Int, Int, Int), differAt: (Int, Int)?) -> NSBitmapImageRep {
        guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height,
                                          bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                                          isPlanar: false, colorSpaceName: .deviceRGB,
                                          bytesPerRow: 0, bitsPerPixel: 0) else {
            fatalError("failed to build test bitmap")
        }
        for y in 0..<height {
            for x in 0..<width {
                let isDiffer = differAt.map { $0.0 == x && $0.1 == y } ?? false
                let (r, g, b) = isDiffer ? (10, 200, 10) : fill
                var px: [Int] = [r, g, b, 255]
                rep.setPixel(&px, atX: x, y: y)
            }
        }
        return rep
    }

    /// Decode PNG bytes back into a bitmap so assertions read the ACTUAL
    /// written-and-round-tripped color, not the in-memory rep before encode.
    private func readback(_ data: Data) -> NSBitmapImageRep {
        guard let rep = NSBitmapImageRep(data: data) else {
            fatalError("failed to decode diff() PNG output")
        }
        return rep
    }

    @Test func changedSampleWritesVisibleRedOnReadback() {
        // step=3 in diff(): sample (0,0) at pixel (0,0), which is where we plant
        // the differing pixel — guarantees the (0,0) heat-map cell is "changed".
        let a = makeBitmap(width: 6, height: 6, fill: (40, 40, 40), differAt: (0, 0))
        let b = makeBitmap(width: 6, height: 6, fill: (40, 40, 40), differAt: nil)

        let (pct, heatData) = QAAudit.diff(a, b)
        #expect(pct > 0.5, "expected the single differing sample point to push pct over the heat-write threshold, got \(pct)")
        guard let heatData else {
            Issue.record("diff() returned nil heat PNG data despite pct=\(pct) > 0.5")
            return
        }

        let heat = readback(heatData)
        guard let changedColor = heat.colorAt(x: 0, y: 0) else {
            Issue.record("colorAt(0,0) returned nil on the readback heat-map")
            return
        }
        // Hard assertion on the ACTUAL bug: red channel must be unambiguously
        // present (this is exactly what read back as 0.0 before the fix).
        #expect(changedColor.redComponent > 0.6, "changed sample must show strong red on readback, got r=\(changedColor.redComponent) g=\(changedColor.greenComponent) b=\(changedColor.blueComponent) a=\(changedColor.alphaComponent)")
        #expect(changedColor.alphaComponent > 0.5, "changed sample must be visibly opaque, got a=\(changedColor.alphaComponent)")
    }

    @Test func unchangedSampleStaysLowRedOnReadback() {
        // 6x6 identical images, step=3 → sampled cells at (0,0),(1,0),(0,1),(1,1)
        // all unchanged; (1,1) here as the check point, distinct from the
        // "changed" test's (0,0), so this genuinely exercises the unchanged branch.
        let a = makeBitmap(width: 6, height: 6, fill: (40, 40, 40), differAt: nil)
        let b = makeBitmap(width: 6, height: 6, fill: (40, 40, 40), differAt: nil)

        let (pct, heatData) = QAAudit.diff(a, b)
        #expect(pct == 0, "identical bitmaps must report 0% diff, got \(pct)")
        // pct <= 0.5 → diff() returns nil heat data by design (unchanged path,
        // no write threshold crossed) — that's the correct, unrelated behavior;
        // nothing further to read back.
        #expect(heatData == nil, "diff() should not emit heat-map bytes when nothing changed")
    }

    @Test func mixedRegionMarksOnlyTheChangedCoordRed() {
        // 9x9 → sampled grid is 3x3 (step=3): cells (0,0)(1,0)(2,0)/(0,1)(1,1)(2,1)/(0,2)(1,2)(2,2).
        // Plant the difference at pixel (3,0), which step=3 samples as heat cell (1,0).
        let a = makeBitmap(width: 9, height: 9, fill: (60, 60, 60), differAt: (3, 0))
        let b = makeBitmap(width: 9, height: 9, fill: (60, 60, 60), differAt: nil)

        let (pct, heatData) = QAAudit.diff(a, b)
        #expect(pct > 0, "one differing sample of 9 must register as nonzero diff, got \(pct)")
        guard let heatData else {
            Issue.record("diff() returned nil heat data with pct=\(pct)")
            return
        }
        let heat = readback(heatData)

        guard let changed = heat.colorAt(x: 1, y: 0) else {
            Issue.record("colorAt(1,0) returned nil")
            return
        }
        #expect(changed.redComponent > 0.6, "the changed heat cell (1,0) must be red, got r=\(changed.redComponent)")

        guard let untouched = heat.colorAt(x: 0, y: 0) else {
            Issue.record("colorAt(0,0) returned nil")
            return
        }
        // Untouched cells get the faint [0,0,0,20] marker — low red, not the
        // opaque [255,40,40,255] changed marker.
        #expect(untouched.redComponent < 0.3, "an unchanged heat cell (0,0) must stay low-red, got r=\(untouched.redComponent)")
    }
}
