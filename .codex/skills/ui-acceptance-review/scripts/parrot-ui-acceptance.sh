#!/usr/bin/env bash
set -euo pipefail

ROOT="${1:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
cd "$ROOT"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

info() {
  echo "INFO: $*"
}

cleanup() {
  pkill -x Parrot >/dev/null 2>&1 || true
}

APP="$ROOT/build/Parrot.app"
DEBUG_LOG="/tmp/parrot-debug.log"
BUNDLE_ID="${PARROT_BUNDLE_ID:-com.parrot.app}"
ORIGINAL_LANGUAGE="$(defaults read "$BUNDLE_ID" app.languageCode 2>/dev/null || true)"

finish() {
  cleanup
  if [[ -n "$ORIGINAL_LANGUAGE" ]]; then
    defaults write "$BUNDLE_ID" app.languageCode "$ORIGINAL_LANGUAGE" >/dev/null 2>&1 || true
  else
    defaults delete "$BUNDLE_ID" app.languageCode >/dev/null 2>&1 || true
  fi
}

trap finish EXIT

if [[ "${PARROT_UI_REUSE_BUILD:-0}" != "1" ]]; then
  info "running swift test"
  swift test --jobs "${PARROT_BUILD_JOBS:-4}"

  info "building release app"
  bash scripts/build-app.sh release
else
  info "reusing the tested release app for GUI checks"
fi
test -d "$APP" || fail "missing built app at $APP"

info "launching built app"
cleanup
defaults write "$BUNDLE_ID" app.languageCode en >/dev/null 2>&1 || true
sleep 0.5
open -na "$APP"
sleep 1.5

PID="$(pgrep -x Parrot | head -1 || true)"
test -n "$PID" || fail "Parrot process did not start"

COMMAND="$(ps -p "$PID" -o command= || true)"
case "$COMMAND" in
  "$APP"/Contents/MacOS/Parrot*) ;;
  *) fail "running Parrot is not the built app: $COMMAND" ;;
esac

info "running AX and URL smoke checks for pid $PID"
swift - "$ROOT" "$PID" <<'SWIFT'
import AppKit
import ApplicationServices
import CoreGraphics
import Darwin
import Foundation

let root = CommandLine.arguments[1]
let pid = pid_t(Int(CommandLine.arguments[2])!)
let appURL = URL(fileURLWithPath: root).appendingPathComponent("build/Parrot.app")
var axReadErrorCounts: [String: Int] = [:]
var axWindowReadFailures = 0
var axEmptyWindowReads = 0
var axLastWindowReadCode: Int32?

func fail(_ message: String) -> Never {
    fputs("FAIL: \(message)\n", stderr)
    exit(1)
}

func attr(_ element: AXUIElement, _ name: String) -> CFTypeRef? {
    var value: CFTypeRef?
    let error = AXUIElementCopyAttributeValue(element, name as CFString, &value)
    if name == kAXWindowsAttribute as String {
        axLastWindowReadCode = error.rawValue
        if error != .success { axWindowReadFailures += 1 }
    }
    guard error == .success else {
        axReadErrorCounts["\(name):\(error.rawValue)", default: 0] += 1
        return nil
    }
    if name == kAXWindowsAttribute as String,
       let windows = value as? [AXUIElement], windows.isEmpty {
        axEmptyWindowReads += 1
    }
    return value
}

func role(_ element: AXUIElement) -> String {
    (attr(element, kAXRoleAttribute) as? String) ?? ""
}

func title(_ element: AXUIElement) -> String {
    (attr(element, kAXTitleAttribute) as? String) ?? ""
}

func value(_ element: AXUIElement) -> String {
    (attr(element, kAXValueAttribute) as? String) ?? ""
}

func description(_ element: AXUIElement) -> String {
    (attr(element, kAXDescriptionAttribute) as? String) ?? ""
}

func help(_ element: AXUIElement) -> String {
    (attr(element, kAXHelpAttribute) as? String) ?? ""
}

func accessibleNames(_ element: AXUIElement) -> [String] {
    [title(element), value(element), description(element), help(element)].filter { !$0.isEmpty }
}

func pointValue(_ element: AXUIElement, _ name: String) -> CGPoint? {
    guard let value = attr(element, name) else { return nil }
    var point = CGPoint.zero
    guard AXValueGetValue(value as! AXValue, .cgPoint, &point) else { return nil }
    return point
}

func sizeValue(_ element: AXUIElement, _ name: String) -> CGSize? {
    guard let value = attr(element, name) else { return nil }
    var size = CGSize.zero
    guard AXValueGetValue(value as! AXValue, .cgSize, &size) else { return nil }
    return size
}

func setPosition(_ element: AXUIElement, _ point: CGPoint) {
    var mutable = point
    guard let axValue = AXValueCreate(.cgPoint, &mutable) else {
        fail("could not create AX point value")
    }
    let error = AXUIElementSetAttributeValue(element, kAXPositionAttribute as CFString, axValue)
    guard error == .success else {
        fail("could not move window through AX: \(error.rawValue)")
    }
}

func setSize(_ element: AXUIElement, _ size: CGSize) {
    var mutable = size
    guard let axValue = AXValueCreate(.cgSize, &mutable) else {
        fail("could not create AX size value")
    }
    let error = AXUIElementSetAttributeValue(element, kAXSizeAttribute as CFString, axValue)
    guard error == .success else {
        fail("could not resize window through AX: \(error.rawValue)")
    }
}

func walk(_ element: AXUIElement, visit: (AXUIElement) -> Bool) -> AXUIElement? {
    if visit(element) { return element }
    if let children = attr(element, kAXChildrenAttribute) as? [AXUIElement] {
        for child in children {
            if let hit = walk(child, visit: visit) { return hit }
        }
    }
    return nil
}

func menuItem(named name: String, in app: AXUIElement) -> AXUIElement? {
    walk(app) { role($0) == "AXMenuItem" && title($0) == name }
}

func button(named name: String, in root: AXUIElement) -> AXUIElement? {
    walk(root) { element in
        role(element) == "AXButton" && accessibleNames(element).contains(name)
    }
}

func disclosure(named name: String, in root: AXUIElement) -> AXUIElement? {
    walk(root) { element in
        ["AXDisclosureTriangle", "AXButton"].contains(role(element)) && accessibleNames(element).contains(name)
    }
}

func disclosureIsExpanded(_ element: AXUIElement) -> Bool? {
    if let expanded = attr(element, kAXExpandedAttribute as String) as? Bool { return expanded }
    if let expanded = attr(element, kAXValueAttribute as String) as? NSNumber { return expanded.boolValue }
    switch value(element) {
    case "Expanded": return true
    case "Collapsed": return false
    default: return nil
    }
}

func revealDisclosure(_ element: AXUIElement) {
    var ancestor = attr(element, kAXParentAttribute as String) as! AXUIElement?
    while let current = ancestor {
        if role(current) == "AXScrollArea",
           let position = pointValue(current, kAXPositionAttribute as String),
           let size = sizeValue(current, kAXSizeAttribute as String),
           let heading = pointValue(element, kAXPositionAttribute as String) {
            let targetY = min(max(heading.y, position.y + 8), position.y + size.height - 40)
            let delta = Int32((targetY - heading.y).rounded())
            if delta != 0 {
                let event = CGEvent(scrollWheelEvent2Source: nil, units: .pixel, wheelCount: 1, wheel1: delta, wheel2: 0, wheel3: 0)!
                event.location = CGPoint(x: position.x + size.width / 2, y: position.y + size.height / 2)
                event.post(tap: .cghidEventTap)
                usleep(400_000)
            }
            return
        }
        ancestor = attr(current, kAXParentAttribute as String) as! AXUIElement?
    }
}

func windowTitles(in app: AXUIElement) -> [String] {
    guard let windows = attr(app, kAXWindowsAttribute) as? [AXUIElement] else { return [] }
    return windows.map(title)
}

func windows(in app: AXUIElement) -> [AXUIElement] {
    (attr(app, kAXWindowsAttribute) as? [AXUIElement]) ?? []
}

func window(named expected: String, in app: AXUIElement) -> AXUIElement? {
    windows(in: app).first { title($0) == expected }
}

func assertWindowTitle(_ expected: String, in app: AXUIElement) {
    guard waitForWindow(named: expected, in: app) != nil else {
        fail("expected window '\(expected)' but saw \(windowTitles(in: app))")
    }
}

func waitForWindow(
    named expected: String,
    in app: AXUIElement,
    ready: (AXUIElement) -> Bool = { _ in true }
) -> AXUIElement? {
    let deadline = Date().addingTimeInterval(5)
    let failuresBefore = axWindowReadFailures
    let emptyBefore = axEmptyWindowReads
    var attempts = 0
    var titles: [String] = []
    repeat {
        attempts += 1
        let current = windows(in: app)
        titles = current.map(title)
        if let match = current.first(where: { title($0) == expected }), ready(match) {
            if attempts > 1 {
                print("INFO: window '\(expected)' ready after \(attempts) polls; AXWindows failed=\(axWindowReadFailures - failuresBefore) empty=\(axEmptyWindowReads - emptyBefore)")
            }
            return match
        }
        if Date() >= deadline { break }
        usleep(100_000)
    } while true

    let running = NSRunningApplication(processIdentifier: pid)
    let front = NSWorkspace.shared.frontmostApplication
    let errors = axReadErrorCounts.sorted { $0.key < $1.key }.map { "\($0.key)=\($0.value)" }
    print("DIAGNOSTIC: timeout waiting for '\(expected)' and required controls after \(attempts) polls; titles=\(titles)")
    print("DIAGNOSTIC: AXWindows lastCode=\(axLastWindowReadCode.map { String($0) } ?? "unread") failed=\(axWindowReadFailures - failuresBefore) empty=\(axEmptyWindowReads - emptyBefore); AX read errors=\(errors)")
    print("DIAGNOSTIC: pid=\(pid) alive=\(kill(pid, 0) == 0) terminated=\(running?.isTerminated ?? true) active=\(running?.isActive ?? false) frontPID=\(front?.processIdentifier ?? 0) frontBundle=\(front?.bundleIdentifier ?? "nil")")
    print("DIAGNOSTIC: CG app windows=\(appWindows(onScreenOnly: false))")
    return nil
}

func editableComposer(in workspace: AXUIElement) -> AXUIElement? {
    walk(workspace) { element in
        let r = role(element)
        return r == "AXTextArea" || r == "AXTextField"
    }
}

func assertEditableComposer(in workspace: AXUIElement) {
    let editable = editableComposer(in: workspace)
    guard editable != nil else {
        fail("workspace opened without an editable source composer")
    }
}

func openURL(_ raw: String, appURL: URL) {
    let url = URL(string: raw)!
    let config = NSWorkspace.OpenConfiguration()
    config.activates = true
    let semaphore = DispatchSemaphore(value: 0)
    var openError: Error?
    var openedPath: String?
    NSWorkspace.shared.open([url], withApplicationAt: appURL, configuration: config) { runningApp, error in
        openedPath = runningApp?.bundleURL?.path
        openError = error
        semaphore.signal()
    }
    semaphore.wait()
    if let openError {
        fail("URL Scheme open failed: \(openError.localizedDescription)")
    }
    guard openedPath == appURL.path else {
        fail("URL Scheme routed to \(openedPath ?? "nil"), expected \(appURL.path)")
    }
}

func sendReturn() {
    let returnKey: CGKeyCode = 36
    let down = CGEvent(keyboardEventSource: nil, virtualKey: returnKey, keyDown: true)!
    down.post(tap: .cghidEventTap)
    let up = CGEvent(keyboardEventSource: nil, virtualKey: returnKey, keyDown: false)!
    up.post(tap: .cghidEventTap)
}

func clickTrailingSpace(of element: AXUIElement, name: String) {
    guard let position = pointValue(element, kAXPositionAttribute as String),
          let size = sizeValue(element, kAXSizeAttribute as String),
          size.width >= 120, size.height >= 28 else {
        fail("\(name) must expose a full row hit target")
    }
    let point = CGPoint(x: position.x + size.width - 10, y: position.y + min(size.height, 34) / 2)
    print("INFO: clicking \(name) at \(point); frame=\(position) \(size), active=\(NSRunningApplication(processIdentifier: pid)?.isActive ?? false), postEventAccess=\(CGPreflightPostEventAccess())")
    let down = CGEvent(mouseEventSource: nil, mouseType: .leftMouseDown, mouseCursorPosition: point, mouseButton: .left)!
    let up = CGEvent(mouseEventSource: nil, mouseType: .leftMouseUp, mouseCursorPosition: point, mouseButton: .left)!
    down.post(tap: .cghidEventTap)
    up.post(tap: .cghidEventTap)
    usleep(600_000)
}

func assertStablePosition(_ before: CGPoint, _ after: CGPoint, context: String) {
    let dx = abs(before.x - after.x)
    let dy = abs(before.y - after.y)
    guard dx <= 3 && dy <= 3 else {
        fail("\(context) moved unexpectedly; before=\(before) after=\(after)")
    }
}

func assertStableSize(_ before: CGSize, _ after: CGSize, context: String) {
    let dw = abs(before.width - after.width)
    let dh = abs(before.height - after.height)
    guard dw <= 8 && dh <= 8 else {
        fail("\(context) resized unexpectedly; before=\(before) after=\(after)")
    }
}

func press(_ item: AXUIElement, name: String) {
    let error = AXUIElementPerformAction(item, kAXPressAction as CFString)
    guard error == .success else {
        fail("AXPress failed for \(name): \(error.rawValue)")
    }
}

func appWindows(onScreenOnly: Bool = true) -> [[String: Any]] {
    let options: CGWindowListOption = onScreenOnly ? [.optionOnScreenOnly, .excludeDesktopElements] : [.excludeDesktopElements]
    let list = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] ?? []
    return list.filter { ($0[kCGWindowOwnerPID as String] as? Int32) == pid }
}

guard AXIsProcessTrusted() else {
    fail("test runner lacks Accessibility access; grant the terminal/agent host Accessibility permission and rerun")
}

let app = AXUIElementCreateApplication(pid)
let requiredMenuItems = ["Input Translation", "View History", "Settings...", "Quit Parrot"]
for name in requiredMenuItems {
    guard menuItem(named: name, in: app) != nil else {
        fail("missing App menu fallback item: \(name)")
    }
}
print("INFO: menu fallback entries found")

if let settings = menuItem(named: "Settings...", in: app) {
    press(settings, name: "Settings...")
    assertWindowTitle("Parrot Settings", in: app)

    guard let settingsWindow = window(named: "Parrot Settings", in: app),
          let translationPane = button(named: "Translate", in: settingsWindow) else {
        fail("settings sidebar missing translation pane")
    }
    clickTrailingSpace(of: translationPane, name: "settings sidebar")
    guard let initialCatalog = disclosure(named: "Add Translation Engine", in: settingsWindow) else {
        _ = walk(settingsWindow) { element in
            if ["AXButton", "AXDisclosureTriangle", "AXStaticText"].contains(role(element)) {
                print("DIAGNOSTIC: \(role(element)) names=\(accessibleNames(element))")
            }
            return false
        }
        fail("clicking sidebar trailing space did not open translation settings")
    }
    revealDisclosure(initialCatalog)
    guard let catalog = disclosure(named: "Add Translation Engine", in: settingsWindow) else {
        fail("engine catalog disclosure disappeared after scrolling")
    }
    clickTrailingSpace(of: catalog, name: "engine catalog disclosure")
    guard let expandedCatalog = disclosure(named: "Add Translation Engine", in: settingsWindow),
          disclosureIsExpanded(expandedCatalog) == true else {
        fail("clicking disclosure trailing space did not expand the catalog; value=\(value(catalog))")
    }
    revealDisclosure(expandedCatalog)
    guard let visibleCatalog = disclosure(named: "Add Translation Engine", in: settingsWindow) else {
        fail("expanded engine catalog disappeared after scrolling")
    }
    clickTrailingSpace(of: visibleCatalog, name: "engine catalog disclosure")
    guard let collapsedCatalog = disclosure(named: "Add Translation Engine", in: settingsWindow),
          disclosureIsExpanded(collapsedCatalog) == false else {
        fail("clicking disclosure trailing space did not collapse the catalog; value=\(value(visibleCatalog))")
    }
    print("INFO: sidebar and disclosure trailing-space mouse clicks passed")
}

if let history = menuItem(named: "View History", in: app) {
    press(history, name: "View History")
    assertWindowTitle("Parrot History", in: app)
}

if let input = menuItem(named: "Input Translation", in: app) {
    press(input, name: "Input Translation")
    guard let workspace = waitForWindow(named: "Parrot Translation", in: app, ready: {
        editableComposer(in: $0) != nil && button(named: "Open Settings", in: $0) != nil
    }) else {
        fail("translation workspace did not appear; windows=\(windowTitles(in: app))")
    }
    assertEditableComposer(in: workspace)
    guard let settingsButton = button(named: "Open Settings", in: workspace) else {
        fail("translation workspace missing settings button in window controls")
    }
    press(settingsButton, name: "Open Settings")
    assertWindowTitle("Parrot Settings", in: app)
}

openURL("parrot://ocr-fixture?text=OCR%20fixture%20line%201%0AOCR%20fixture%20line%202&confidence=0.62&provider=Fixture%20OCR", appURL: appURL)
if let workspace = waitForWindow(named: "Parrot Translation", in: app, ready: { workspace in
    guard let composer = editableComposer(in: workspace) else { return false }
    let text = value(composer)
    return text.contains("OCR fixture line 1") && text.contains("OCR fixture line 2")
}),
   let composer = editableComposer(in: workspace) {
    let composerValue = value(composer)
    guard composerValue.contains("OCR fixture line 1") && composerValue.contains("OCR fixture line 2") else {
        fail("OCR fixture did not populate editable composer; value=\(composerValue)")
    }
    guard let originalPosition = pointValue(workspace, kAXPositionAttribute as String) else {
        fail("could not read workspace position")
    }
    guard let sizeBeforeResize = sizeValue(workspace, kAXSizeAttribute as String) else {
        fail("could not read workspace size")
    }
    let targetSize = CGSize(
        width: sizeBeforeResize.width + 80,
        height: max(sizeBeforeResize.height - 72, 360)
    )
    guard let primaryScreen = NSScreen.screens.first else {
        fail("could not read screen geometry for manual resize")
    }
    // AX uses top-left coordinates; AppKit's global coordinates start at the
    // primary screen's bottom-left. Leave room for both frames so AX/AppKit
    // cannot clip the requested width before the app handles the resize.
    let originalCenter = NSPoint(
        x: originalPosition.x + sizeBeforeResize.width / 2,
        y: primaryScreen.frame.maxY - originalPosition.y - sizeBeforeResize.height / 2
    )
    let screen = NSScreen.screens.first(where: { $0.frame.contains(originalCenter) }) ?? primaryScreen
    let visible = screen.visibleFrame
    let margin: CGFloat = 32
    let safeAXFrame = CGRect(
        x: visible.minX + margin,
        y: primaryScreen.frame.maxY - visible.maxY + margin,
        width: visible.width - margin * 2,
        height: visible.height - margin * 2
    )
    let resizeEnvelope = CGSize(
        width: max(sizeBeforeResize.width, targetSize.width),
        height: max(sizeBeforeResize.height, targetSize.height)
    )
    guard safeAXFrame.width >= resizeEnvelope.width,
          safeAXFrame.height >= resizeEnvelope.height else {
        fail("screen has insufficient space for manual resize; safe=\(safeAXFrame) before=\(sizeBeforeResize) target=\(targetSize)")
    }
    let desiredPosition = CGPoint(x: originalPosition.x + 64, y: originalPosition.y + 42)
    let movedPosition = CGPoint(
        x: min(max(desiredPosition.x, safeAXFrame.minX), safeAXFrame.maxX - resizeEnvelope.width),
        y: min(max(desiredPosition.y, safeAXFrame.minY), safeAXFrame.maxY - resizeEnvelope.height)
    )
    setPosition(workspace, movedPosition)
    usleep(250_000)
    guard let actualMovedPosition = pointValue(workspace, kAXPositionAttribute as String) else {
        fail("could not read workspace position before manual resize")
    }
    print("INFO: workspace resize preparation screen=\(screen.localizedName) visible=\(visible) original=\(originalPosition) desired=\(desiredPosition) requested=\(movedPosition) actual=\(actualMovedPosition) before=\(sizeBeforeResize) target=\(targetSize)")
    setSize(workspace, targetSize)
    usleep(350_000)
    guard let sizeAfterManualResize = sizeValue(workspace, kAXSizeAttribute as String) else {
        fail("could not read manually resized workspace size")
    }
    guard sizeAfterManualResize.width >= sizeBeforeResize.width + 32,
          abs(sizeAfterManualResize.height - sizeBeforeResize.height) >= 32 else {
        fail("workspace did not accept manual resize; before=\(sizeBeforeResize) after=\(sizeAfterManualResize)")
    }
    guard let positionBeforeTranslate = pointValue(workspace, kAXPositionAttribute as String) else {
        fail("could not read moved workspace position")
    }
    AXUIElementSetAttributeValue(composer, kAXFocusedAttribute as CFString, kCFBooleanTrue)
    sendReturn()
    usleep(1_500_000)
    guard let translatedWorkspace = waitForWindow(named: "Parrot Translation", in: app),
          let positionAfterTranslate = pointValue(translatedWorkspace, kAXPositionAttribute as String) else {
        fail("workspace disappeared after translating OCR fixture")
    }
    assertStablePosition(positionBeforeTranslate, positionAfterTranslate, context: "workspace position after in-place translation")
    guard let sizeAfterTranslate = sizeValue(translatedWorkspace, kAXSizeAttribute as String) else {
        fail("could not read workspace size after translation")
    }
    assertStableSize(sizeAfterManualResize, sizeAfterTranslate, context: "workspace size after in-place translation")
} else {
    fail("OCR fixture did not open editable translation workspace; windows=\(windowTitles(in: app))")
}

openURL("parrot://translate?text=UI%20acceptance%20smoke%20test", appURL: appURL)
let routedText = "UI acceptance smoke test"
guard let routedWorkspace = waitForWindow(named: "Parrot Translation", in: app, ready: { workspace in
    walk(workspace) { element in
        accessibleNames(element).contains { $0.contains(routedText) }
    } != nil
}) else {
    fail("URL translation did not open a translation workspace; windows=\(windowTitles(in: app))")
}
let hasRoutedSource = walk(routedWorkspace) { element in
    accessibleNames(element).contains { $0.contains(routedText) }
} != nil
guard hasRoutedSource else {
    fail("URL translation workspace did not expose routed source text '\(routedText)'")
}
let hasResultPanel = appWindows().contains { window in
    guard let layer = window[kCGWindowLayer as String] as? Int,
          let bounds = window[kCGWindowBounds as String] as? [String: Any],
          let width = bounds["Width"] as? Double,
          let height = bounds["Height"] as? Double else { return false }
    return (layer == 3 || layer == 0) && width >= 300 && height >= 120
}
guard hasResultPanel else {
    fail("result panel window did not appear; app windows=\(appWindows())")
}

print("INFO: UI acceptance smoke checks passed")
SWIFT

if ! tail -80 "$DEBUG_LOG" 2>/dev/null | grep -q "url: action=translate"; then
  fail "debug log does not show URL translation routing"
fi

info "Parrot UI acceptance passed"
