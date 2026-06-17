import AppKit
import ApplicationServices
import CoreGraphics

struct PermissionSnapshot: Equatable {
    let accessibilityGranted: Bool
    let screenRecordingGranted: Bool

    var hasBlockingIssue: Bool {
        !accessibilityGranted || !screenRecordingGranted
    }

    var summary: String {
        switch (accessibilityGranted, screenRecordingGranted) {
        case (true, true): return L("权限正常")
        case (false, true): return L("辅助功能未开启")
        case (true, false): return L("屏幕录制未开启")
        case (false, false): return L("辅助功能和屏幕录制未开启")
        }
    }
}

enum AppPermissions {
    static func snapshot(promptAccessibility: Bool = false, promptScreenRecording: Bool = false) -> PermissionSnapshot {
        PermissionSnapshot(
            accessibilityGranted: accessibility(prompt: promptAccessibility),
            screenRecordingGranted: screenRecording(prompt: promptScreenRecording)
        )
    }

    static func accessibility(prompt: Bool) -> Bool {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let options = [key: prompt] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    static func screenRecording(prompt: Bool) -> Bool {
        if prompt {
            return CGRequestScreenCaptureAccess()
        }
        return CGPreflightScreenCaptureAccess()
    }

    static func openAccessibilitySettings() {
        openSettings("x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
    }

    static func openScreenRecordingSettings() {
        openSettings("x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")
    }

    private static func openSettings(_ rawURL: String) {
        guard let url = URL(string: rawURL) else { return }
        NSWorkspace.shared.open(url)
    }
}
