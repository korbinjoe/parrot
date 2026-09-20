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
        let frontmost = NSWorkspace.shared.frontmostApplication
        DebugLog.log("  focus: frontmost=\(frontmost?.bundleIdentifier ?? "?") pid=\(frontmost?.processIdentifier ?? -1) name=\(frontmost?.localizedName ?? "?")")

        let system = AXUIElementCreateSystemWide()
        var focused: AnyObject?
        let focusStatus = AXUIElementCopyAttributeValue(system, kAXFocusedUIElementAttribute as CFString, &focused)
        guard focusStatus == .success, let element = focused else {
            DebugLog.log("  focus: no system-wide focused element status=\(focusStatus.rawValue)")
            return nil
        }

        let axElement = element as! AXUIElement

        var pid: pid_t = 0
        _ = AXUIElementGetPid(axElement, &pid)

        var roleValue: AnyObject?
        let role = AXUIElementCopyAttributeValue(axElement, kAXRoleAttribute as CFString, &roleValue) == .success
            ? (roleValue as? String) ?? "?" : "?"
        var subroleValue: AnyObject?
        let subrole = AXUIElementCopyAttributeValue(axElement, kAXSubroleAttribute as CFString, &subroleValue) == .success
            ? (subroleValue as? String) ?? "" : ""
        DebugLog.log("  focus: axPid=\(pid) role=\(role) subrole=\(subrole) selfPid=\(getpid())")

        // Ignore focus that belongs to Parrot itself.
        if pid == getpid() {
            DebugLog.log("  focus: skipping (owned by Parrot)")
            return nil
        }

        var value: AnyObject?
        let attrStatus = AXUIElementCopyAttributeValue(axElement, kAXSelectedTextAttribute as CFString, &value)
        guard attrStatus == .success else {
            DebugLog.log("  AX kAXSelectedTextAttribute status=\(attrStatus.rawValue) (attributeUnsupported=-25205, noValue=-25212)")
            return nil
        }
        guard let text = value as? String else {
            DebugLog.log("  AX kAXSelectedTextAttribute non-string value=\(String(describing: value))")
            return nil
        }
        return text
    }

    /// Fallback: preserve the pasteboard, send ⌘C, read the copy, then restore.
    private static func selectedTextViaCopy() -> String? {
        let pasteboard = NSPasteboard.general
        let saved = pasteboard.string(forType: .string)
        let savedChangeCount = pasteboard.changeCount

        let liveFlags = NSEvent.modifierFlags
        DebugLog.log("  copy: preFlags=0x\(String(liveFlags.rawValue, radix: 16)) option=\(liveFlags.contains(.option)) command=\(liveFlags.contains(.command)) control=\(liveFlags.contains(.control)) shift=\(liveFlags.contains(.shift))")

        // Wait for the hotkey's own modifier keys (⌥ in ⌥D, ⌘ in ⌘⇧E, ...) to be physically
        // released before synthesizing ⌘C. On macOS 26/27, `CGEventSource(stateID: .privateState)`
        // no longer fully isolates modifier state — a still-held ⌥ leaks in and the OS sees
        // ⌥⌘C, which most apps ignore. Waiting for release fixes the "AX empty + Copy nil"
        // double failure most users see when they hold ⌥D longer than a beat.
        waitForHotkeyModifiersToClear()

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
        DebugLog.log("  copy: post ⌘C down.flags=0x\(String(down?.flags.rawValue ?? 0, radix: 16)) up.flags=0x\(String(up?.flags.rawValue ?? 0, radix: 16))")
        down?.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)
    }

    /// Whether the app has Accessibility permission (needed for AX read & key synthesis).
    static func hasAccessibilityPermission(prompt: Bool) -> Bool {
        AppPermissions.accessibility(prompt: prompt)
    }

    private static func waitForHotkeyModifiersToClear(timeout: TimeInterval = 0.25) {
        let watched: NSEvent.ModifierFlags = [.option, .control, .command, .shift]
        let start = Date()
        var waited: TimeInterval = 0
        while Date().timeIntervalSince(start) < timeout {
            if NSEvent.modifierFlags.intersection(watched).isEmpty {
                if waited > 0 {
                    DebugLog.log("  copy: waited \(Int(waited * 1000))ms for modifiers to clear")
                }
                return
            }
            RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.01))
            waited = Date().timeIntervalSince(start)
        }
        DebugLog.log("  copy: modifier release timed out after \(Int(waited * 1000))ms flags=0x\(String(NSEvent.modifierFlags.rawValue, radix: 16))")
    }
}
