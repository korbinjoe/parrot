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

trap cleanup EXIT

APP="$ROOT/build/Parrot.app"
DEBUG_LOG="/tmp/parrot-debug.log"

info "running swift test"
swift test

info "building release app"
bash scripts/build-app.sh release
test -d "$APP" || fail "missing built app at $APP"

info "launching built app"
cleanup
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
import Foundation

let root = CommandLine.arguments[1]
let pid = pid_t(Int(CommandLine.arguments[2])!)
let appURL = URL(fileURLWithPath: root).appendingPathComponent("build/Parrot.app")

func fail(_ message: String) -> Never {
    fputs("FAIL: \(message)\n", stderr)
    exit(1)
}

func attr(_ element: AXUIElement, _ name: String) -> CFTypeRef? {
    var value: CFTypeRef?
    guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else { return nil }
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
    let titles = windowTitles(in: app)
    guard titles.contains(expected) else {
        fail("expected window '\(expected)' but saw \(titles)")
    }
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

func sendCommandReturn() {
    let returnKey: CGKeyCode = 36
    let down = CGEvent(keyboardEventSource: nil, virtualKey: returnKey, keyDown: true)!
    down.flags = .maskCommand
    down.post(tap: .cghidEventTap)
    let up = CGEvent(keyboardEventSource: nil, virtualKey: returnKey, keyDown: false)!
    up.flags = .maskCommand
    up.post(tap: .cghidEventTap)
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

func appWindows() -> [[String: Any]] {
    let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
    return list.filter { ($0[kCGWindowOwnerPID as String] as? Int32) == pid }
}

guard AXIsProcessTrusted() else {
    fail("test runner lacks Accessibility access; grant the terminal/agent host Accessibility permission and rerun")
}

let app = AXUIElementCreateApplication(pid)
let requiredMenuItems = ["输入翻译", "查看历史", "设置…", "退出 Parrot"]
for name in requiredMenuItems {
    guard menuItem(named: name, in: app) != nil else {
        fail("missing App menu fallback item: \(name)")
    }
}
print("INFO: menu fallback entries found")

if let settings = menuItem(named: "设置…", in: app) {
    press(settings, name: "设置…")
    usleep(800_000)
    assertWindowTitle("Parrot 设置", in: app)
}

if let history = menuItem(named: "查看历史", in: app) {
    press(history, name: "查看历史")
    usleep(800_000)
    assertWindowTitle("Parrot 历史", in: app)
}

if let input = menuItem(named: "输入翻译", in: app) {
    press(input, name: "输入翻译")
    usleep(800_000)
    guard let workspace = window(named: "Parrot 翻译", in: app) else {
        fail("translation workspace did not appear; windows=\(windowTitles(in: app))")
    }
    assertEditableComposer(in: workspace)
}

openURL("parrot://ocr-fixture?text=OCR%20fixture%20line%201%0AOCR%20fixture%20line%202&confidence=0.62&provider=Fixture%20OCR", appURL: appURL)
usleep(1_500_000)
if let workspace = window(named: "Parrot 翻译", in: app),
   let composer = editableComposer(in: workspace) {
    let composerValue = value(composer)
    guard composerValue.contains("OCR fixture line 1") && composerValue.contains("OCR fixture line 2") else {
        fail("OCR fixture did not populate editable composer; value=\(composerValue)")
    }
    guard let originalPosition = pointValue(workspace, kAXPositionAttribute as String) else {
        fail("could not read workspace position")
    }
    let movedPosition = CGPoint(x: originalPosition.x + 64, y: originalPosition.y + 42)
    setPosition(workspace, movedPosition)
    usleep(250_000)
    guard let sizeBeforeResize = sizeValue(workspace, kAXSizeAttribute as String) else {
        fail("could not read workspace size")
    }
    let targetSize = CGSize(width: sizeBeforeResize.width + 80, height: sizeBeforeResize.height + 80)
    setSize(workspace, targetSize)
    usleep(350_000)
    guard let sizeAfterManualResize = sizeValue(workspace, kAXSizeAttribute as String) else {
        fail("could not read manually resized workspace size")
    }
    guard sizeAfterManualResize.width >= sizeBeforeResize.width + 32,
          sizeAfterManualResize.height >= sizeBeforeResize.height + 32 else {
        fail("workspace did not accept manual resize; before=\(sizeBeforeResize) after=\(sizeAfterManualResize)")
    }
    guard let positionBeforeTranslate = pointValue(workspace, kAXPositionAttribute as String) else {
        fail("could not read moved workspace position")
    }
    AXUIElementSetAttributeValue(composer, kAXFocusedAttribute as CFString, kCFBooleanTrue)
    sendCommandReturn()
    usleep(1_500_000)
    guard let translatedWorkspace = window(named: "Parrot 翻译", in: app),
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
usleep(1_200_000)
let hasResultPanel = appWindows().contains { window in
    guard let layer = window[kCGWindowLayer as String] as? Int,
          let bounds = window[kCGWindowBounds as String] as? [String: Any],
          let width = bounds["Width"] as? Double,
          let height = bounds["Height"] as? Double else { return false }
    return layer == 3 && width >= 300 && height >= 120
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
