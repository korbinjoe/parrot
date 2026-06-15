import AppKit
import ApplicationServices

/// Captures the currently selected text from the frontmost app.
/// Strategy: Accessibility API first; fall back to synthesizing ⌘C and reading the pasteboard.
enum SelectionCapture {

    static func selectedText() -> String? {
        let ax = selectedTextViaAccessibility()
        DebugLog.log("  AX path -> \(ax.map { "len=\($0.count)" } ?? "nil")")
        if let ax, !ax.isEmpty {
            return ax
        }
        let copy = selectedTextViaCopy()
        DebugLog.log("  Copy path -> \(copy.map { "len=\($0.count)" } ?? "nil")")
        return copy
    }

    /// Read the focused UI element's selected text through the Accessibility API.
    /// Skips elements owned by our own process (e.g. the floating result panel), whose
    /// selection would otherwise shadow the real frontmost app on repeat invocations.
    private static func selectedTextViaAccessibility() -> String? {
        let system = AXUIElementCreateSystemWide()
        var focused: AnyObject?
        guard AXUIElementCopyAttributeValue(system, kAXFocusedUIElementAttribute as CFString, &focused) == .success,
              let element = focused else { return nil }

        let axElement = element as! AXUIElement

        // Ignore focus that belongs to Parrot itself.
        var pid: pid_t = 0
        if AXUIElementGetPid(axElement, &pid) == .success, pid == getpid() {
            return nil
        }

        var value: AnyObject?
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

        // Give the frontmost app a moment to populate the pasteboard. Detect a copy by
        // changeCount bumping OR the string differing from what we saved (some apps don't
        // bump changeCount when copying identical-looking content).
        let deadline = Date().addingTimeInterval(0.6)
        var copied: String?
        while Date() < deadline {
            if pasteboard.changeCount != savedChangeCount {
                let current = pasteboard.string(forType: .string)
                if let current, !current.isEmpty {
                    copied = current
                    break
                }
            }
            RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.02))
        }

        // Restore the previous pasteboard contents.
        pasteboard.clearContents()
        if let saved {
            pasteboard.setString(saved, forType: .string)
        }
        return copied
    }

    /// Synthesize ⌘C. Uses a private event source so the user's currently-held hotkey
    /// modifiers (e.g. the ⌥ in ⌥D) are NOT merged into the event — otherwise the OS would
    /// emit ⌘⌥C instead of ⌘C and the copy would silently fail on repeat triggers.
    private static func sendCommandC() {
        let source = CGEventSource(stateID: .privateState)
        source?.setLocalEventsFilterDuringSuppressionState([], state: .eventSuppressionStateSuppressionInterval)

        let cKey: CGKeyCode = 8 // 'c'
        let down = CGEvent(keyboardEventSource: source, virtualKey: cKey, keyDown: true)
        let up = CGEvent(keyboardEventSource: source, virtualKey: cKey, keyDown: false)
        down?.flags = .maskCommand
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
