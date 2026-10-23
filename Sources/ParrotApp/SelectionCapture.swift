import AppKit
import ApplicationServices

/// Captures the currently selected text from the frontmost app.
/// Strategy: Accessibility API first; fall back to synthesizing ⌘C and reading the pasteboard.
enum SelectionCapture {

    @MainActor
    static func selectedText(from processIdentifier: pid_t? = nil) async -> String? {
        guard let targetPID = processIdentifier ?? NSWorkspace.shared.frontmostApplication?.processIdentifier,
              targetPID != getpid() else {
            DebugLog.log("selection-capture: skipped no external source")
            return nil
        }
        DebugLog.log("selection-capture: sourcePID=\(targetPID) foregroundPID=\(NSWorkspace.shared.frontmostApplication?.processIdentifier ?? 0)")
        // Accessibility calls are synchronous IPC. An unresponsive source app must
        // not freeze Parrot's main thread while the shortcut is being handled.
        let ax = await Task.detached(priority: .userInitiated) {
            selectedTextViaAccessibility(from: targetPID)
        }.value
        guard !Task.isCancelled else {
            DebugLog.log("selection-capture: cancelled after accessibility read")
            return nil
        }
        DebugLog.log("  AX path -> \(ax.map { "len=\($0.count)" } ?? "nil")")
        if let ax, !ax.isEmpty {
            return ax
        }
        let copy = await selectedTextViaCopy(from: targetPID)
        DebugLog.log("  Copy path -> \(copy.map { "len=\($0.count)" } ?? "nil")")
        return copy
    }

    /// Read the focused UI element's selected text through the Accessibility API.
    /// Skips elements owned by our own process (e.g. the floating result panel), whose
    /// selection would otherwise shadow the real frontmost app on repeat invocations.
    private static func selectedTextViaAccessibility(from targetPID: pid_t) -> String? {
        if let text = selectedText(
            in: AXUIElementCreateApplication(targetPID),
            expectedPID: targetPID,
            route: "application"
        ) { return text }

        // Some apps expose the focused element through the system-wide AX object
        // but not their application object. Never accept another app's selection.
        return selectedText(
            in: AXUIElementCreateSystemWide(),
            expectedPID: targetPID,
            route: "system"
        )
    }

    private static func selectedText(in root: AXUIElement, expectedPID: pid_t, route: String) -> String? {
        AXUIElementSetMessagingTimeout(root, 0.15)
        var focused: AnyObject?
        let focusStatus = AXUIElementCopyAttributeValue(root, kAXFocusedUIElementAttribute as CFString, &focused)
        guard focusStatus == .success, let element = focused else {
            DebugLog.log("selection-capture: AX \(route) focus unavailable status=\(focusStatus.rawValue)")
            return nil
        }

        let axElement = element as! AXUIElement
        AXUIElementSetMessagingTimeout(axElement, 0.15)

        // Reject Parrot and stale focus in any other process, including the fallback.
        var pid: pid_t = 0
        guard AXUIElementGetPid(axElement, &pid) == .success, pid == expectedPID, pid != getpid() else {
            DebugLog.log("selection-capture: AX \(route) ignored focusPID=\(pid) expectedPID=\(expectedPID)")
            return nil
        }

        var value: AnyObject?
        let selectionStatus = AXUIElementCopyAttributeValue(axElement, kAXSelectedTextAttribute as CFString, &value)
        guard selectionStatus == .success, let text = value as? String, !text.isEmpty else {
            DebugLog.log("selection-capture: AX \(route) no selected text status=\(selectionStatus.rawValue)")
            return nil
        }
        return text
    }

    /// Fallback: preserve the pasteboard, send ⌘C, read the copy, then restore.
    @MainActor
    private static func selectedTextViaCopy(from targetPID: pid_t?) async -> String? {
        guard !Task.isCancelled else {
            DebugLog.log("selection-capture: copy skipped cancelled")
            return nil
        }
        guard let targetPID, targetPID != getpid() else {
            DebugLog.log("selection-capture: copy skipped no external source")
            return nil
        }
        guard NSWorkspace.shared.frontmostApplication?.processIdentifier == targetPID else {
            DebugLog.log("selection-capture: copy skipped foreground changed")
            return nil
        }
        let liveFlags = NSEvent.modifierFlags
        DebugLog.log("  copy: preFlags=0x\(String(liveFlags.rawValue, radix: 16)) option=\(liveFlags.contains(.option)) command=\(liveFlags.contains(.command)) control=\(liveFlags.contains(.control)) shift=\(liveFlags.contains(.shift))")

        // On macOS 26/27 a held hotkey modifier can leak into the synthetic copy,
        // even with a private event source. Yield while waiting for its release.
        guard await waitForHotkeyModifiersToClear(from: targetPID),
              !Task.isCancelled,
              NSWorkspace.shared.frontmostApplication?.processIdentifier == targetPID else {
            DebugLog.log("selection-capture: copy skipped after modifier wait")
            return nil
        }

        let pasteboard = NSPasteboard.general
        let savedChangeCount = pasteboard.changeCount
        let savedItems: [NSPasteboardItem] = pasteboard.pasteboardItems?.map { item in
            let snapshot = NSPasteboardItem()
            for type in item.types {
                if let data = item.data(forType: type) {
                    snapshot.setData(data, forType: type)
                }
            }
            return snapshot
        } ?? []
        guard pasteboard.changeCount == savedChangeCount else {
            DebugLog.log("selection-capture: copy skipped clipboard changed during snapshot")
            return nil
        }

        sendCommandC()

        // Yield between checks instead of running a nested main RunLoop. This keeps
        // input and rendering responsive and avoids reentrant shortcut handling.
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: .milliseconds(600))
        while clock.now < deadline {
            guard !Task.isCancelled,
                  NSWorkspace.shared.frontmostApplication?.processIdentifier == targetPID else {
                DebugLog.log("selection-capture: copy abandoned cancelled or foreground changed")
                return nil
            }
            if pasteboard.changeCount != savedChangeCount {
                let copiedChangeCount = pasteboard.changeCount
                let current = pasteboard.string(forType: .string)
                // A user may switch apps or copy something else while capture waits.
                // Restore only the copy we observed, never a newer clipboard change.
                guard !Task.isCancelled,
                      NSWorkspace.shared.frontmostApplication?.processIdentifier == targetPID else { return nil }
                if pasteboard.changeCount == copiedChangeCount {
                    pasteboard.clearContents()
                    if !savedItems.isEmpty { pasteboard.writeObjects(savedItems) }
                }
                return current?.isEmpty == false ? current : nil
            }
            do { try await Task.sleep(for: .milliseconds(20)) }
            catch {
                DebugLog.log("selection-capture: copy wait cancelled")
                return nil
            }
        }
        // If no copy happened, the clipboard was never touched.
        DebugLog.log("selection-capture: copy timed out without clipboard change")
        return nil
    }

    /// Synthesize ⌘C using a private event source and explicit command flags.
    /// The modifier-release wait above also protects macOS versions that merge
    /// physically held hotkey modifiers into events from a private source.
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

    @MainActor
    private static func waitForHotkeyModifiersToClear(from targetPID: pid_t) async -> Bool {
        let watched: NSEvent.ModifierFlags = [.option, .control, .command, .shift]
        let clock = ContinuousClock()
        let start = clock.now
        let deadline = start.advanced(by: .milliseconds(250))
        while clock.now < deadline {
            guard !Task.isCancelled,
                  NSWorkspace.shared.frontmostApplication?.processIdentifier == targetPID else {
                return false
            }
            if NSEvent.modifierFlags.intersection(watched).isEmpty {
                let waited = start.duration(to: clock.now)
                DebugLog.log("  copy: modifiers cleared after \(waited)")
                return true
            }
            do { try await Task.sleep(for: .milliseconds(10)) }
            catch { return false }
        }
        DebugLog.log("  copy: modifier release timed out after 250ms flags=0x\(String(NSEvent.modifierFlags.rawValue, radix: 16))")
        return true
    }
}
