import AppKit
import ApplicationServices

/// Captures the currently selected text from the frontmost app.
/// Strategy: Accessibility API first; fall back to synthesizing ⌘C and reading the pasteboard.
enum SelectionCapture {

    static func selectedText() -> String? {
        if let viaAX = selectedTextViaAccessibility(), !viaAX.isEmpty {
            return viaAX
        }
        return selectedTextViaCopy()
    }

    /// Read the focused UI element's selected text through the Accessibility API.
    private static func selectedTextViaAccessibility() -> String? {
        let system = AXUIElementCreateSystemWide()
        var focused: AnyObject?
        guard AXUIElementCopyAttributeValue(system, kAXFocusedUIElementAttribute as CFString, &focused) == .success,
              let element = focused else { return nil }

        var value: AnyObject?
        let axElement = element as! AXUIElement
        guard AXUIElementCopyAttributeValue(axElement, kAXSelectedTextAttribute as CFString, &value) == .success,
              let text = value as? String else { return nil }
        return text
    }

    /// Fallback: preserve the pasteboard, send ⌘C, read the copy, then restore.
    private static func selectedTextViaCopy() -> String? {
        let pasteboard = NSPasteboard.general
        let saved = pasteboard.string(forType: .string)
        let savedChangeCount = pasteboard.changeCount

        sendCommandC()

        // Give the frontmost app a moment to populate the pasteboard.
        let deadline = Date().addingTimeInterval(0.4)
        var copied: String?
        while Date() < deadline {
            if pasteboard.changeCount != savedChangeCount {
                copied = pasteboard.string(forType: .string)
                break
            }
            RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.02))
        }

        // Restore the previous pasteboard contents.
        if let saved {
            pasteboard.clearContents()
            pasteboard.setString(saved, forType: .string)
        }
        return copied
    }

    private static func sendCommandC() {
        let source = CGEventSource(stateID: .combinedSessionState)
        let cKey: CGKeyCode = 8 // 'c'
        let down = CGEvent(keyboardEventSource: source, virtualKey: cKey, keyDown: true)
        down?.flags = .maskCommand
        let up = CGEvent(keyboardEventSource: source, virtualKey: cKey, keyDown: false)
        up?.flags = .maskCommand
        down?.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)
    }

    /// Whether the app has Accessibility permission (needed for AX read & key synthesis).
    static func hasAccessibilityPermission(prompt: Bool) -> Bool {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let options = [key: prompt] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }
}
