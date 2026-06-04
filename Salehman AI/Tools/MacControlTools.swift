import Foundation
import CoreGraphics
import AppKit
#if canImport(FoundationModels)
import FoundationModels
#endif

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

#if canImport(FoundationModels)
struct ControlMacTool: Tool {
    let name = "control_mac"
    let description = "Control the mouse and keyboard: click at coordinates, type text, or press Return/Tab/Escape. Use to automate the UI or test apps. Needs Accessibility permission."

    @Generable
    struct Arguments {
        @Guide(description: "Action: 'click', 'doubleclick', 'type', or 'key'.")
        var action: String
        @Guide(description: "For click/doubleclick: the X screen coordinate.")
        var x: Double?
        @Guide(description: "For click/doubleclick: the Y screen coordinate.")
        var y: Double?
        @Guide(description: "For 'type': the text to type. For 'key': one of return, tab, escape, space, delete.")
        var text: String?
    }

    func call(arguments: Arguments) async throws -> String {
        guard MacControl.accessibilityGranted() else {
            await MainActor.run { MacControl.promptAccessibility() }
            return "Accessibility permission is required. I've opened the prompt — enable Salehman AI in System Settings → Privacy & Security → Accessibility, then try again."
        }
        switch arguments.action.lowercased() {
        case "click":
            guard let x = arguments.x, let y = arguments.y else { return "click needs x and y." }
            MacControl.click(x: x, y: y); return "Clicked at (\(Int(x)), \(Int(y)))."
        case "doubleclick":
            guard let x = arguments.x, let y = arguments.y else { return "doubleclick needs x and y." }
            MacControl.click(x: x, y: y, double: true); return "Double-clicked at (\(Int(x)), \(Int(y)))."
        case "type":
            guard let t = arguments.text else { return "type needs text." }
            MacControl.type(t); return "Typed: \(t)"
        case "key":
            let map: [String: CGKeyCode] = ["return": 36, "tab": 48, "space": 49, "delete": 51, "escape": 53]
            guard let name = arguments.text?.lowercased(), let code = map[name] else { return "Unknown key." }
            MacControl.keyPress(code); return "Pressed \(name)."
        default:
            return "Unknown action. Use click, doubleclick, type, or key."
        }
    }
}

struct TranslateTool: Tool {
    let name = "translate"
    let description = "Translate text into a target language accurately."

    @Generable
    struct Arguments {
        @Guide(description: "The text to translate.")
        var text: String
        @Guide(description: "The target language, e.g. 'Arabic', 'English', 'French'.")
        var targetLanguage: String
    }

    func call(arguments: Arguments) async throws -> String {
        let prompt = "Translate the following text into \(arguments.targetLanguage). Output only the translation, nothing else.\n\n\(arguments.text)"
        return await LocalLLM.generate(prompt, maxTokens: 500)
    }
}
#endif
