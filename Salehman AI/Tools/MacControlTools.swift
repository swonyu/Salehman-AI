import Foundation
import CoreGraphics
import AppKit

/// Mouse & keyboard control via CGEvent. Requires Accessibility permission
/// (System Settings → Privacy & Security → Accessibility).
///
/// All methods are `nonisolated`: CGEvent posting is thread-safe and these are
/// called from `ControlMacTool.call()` which runs off the main actor.
enum MacControl {
    nonisolated static func accessibilityGranted() -> Bool { AXIsProcessTrusted() }

    nonisolated static func promptAccessibility() {
        let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(opts)
    }

    nonisolated static func click(x: CGFloat, y: CGFloat, double: Bool = false) {
        let pos = CGPoint(x: x, y: y)
        move(to: pos)
        let src = CGEventSource(stateID: .combinedSessionState)
        for i in 0..<(double ? 2 : 1) {
            let down = CGEvent(mouseEventSource: src, mouseType: .leftMouseDown, mouseCursorPosition: pos, mouseButton: .left)
            let up = CGEvent(mouseEventSource: src, mouseType: .leftMouseUp, mouseCursorPosition: pos, mouseButton: .left)
            if double { down?.setIntegerValueField(.mouseEventClickState, value: Int64(i + 1)); up?.setIntegerValueField(.mouseEventClickState, value: Int64(i + 1)) }
            down?.post(tap: .cghidEventTap)
            up?.post(tap: .cghidEventTap)
        }
    }

    nonisolated static func move(to pos: CGPoint) {
        CGEvent(mouseEventSource: nil, mouseType: .mouseMoved, mouseCursorPosition: pos, mouseButton: .left)?
            .post(tap: .cghidEventTap)
    }

    nonisolated static func type(_ text: String) {
        let src = CGEventSource(stateID: .combinedSessionState)
        for scalar in text.unicodeScalars {
            var ch = UniChar(scalar.value > 0xFFFF ? 0x20 : UInt16(scalar.value))
            let down = CGEvent(keyboardEventSource: src, virtualKey: 0, keyDown: true)
            down?.keyboardSetUnicodeString(stringLength: 1, unicodeString: &ch)
            down?.post(tap: .cghidEventTap)
            let up = CGEvent(keyboardEventSource: src, virtualKey: 0, keyDown: false)
            up?.keyboardSetUnicodeString(stringLength: 1, unicodeString: &ch)
            up?.post(tap: .cghidEventTap)
        }
    }

    nonisolated static func keyPress(_ keyCode: CGKeyCode) {
        let src = CGEventSource(stateID: .combinedSessionState)
        CGEvent(keyboardEventSource: src, virtualKey: keyCode, keyDown: true)?.post(tap: .cghidEventTap)
        CGEvent(keyboardEventSource: src, virtualKey: keyCode, keyDown: false)?.post(tap: .cghidEventTap)
    }
}

