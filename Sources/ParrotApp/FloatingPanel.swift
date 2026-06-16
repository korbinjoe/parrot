import AppKit
import SwiftUI

/// Non-activating floating panel that shows translation results near the cursor and
/// auto-hides when it loses focus. Implements an "即用即走" (use-and-dismiss) behavior.
@MainActor
final class FloatingPanel {
    private var panel: NSPanel?
    private var hosting: NSHostingController<ResultView>?
    private let state: AppState
    private let onConfigureProvider: () -> Void
    private var anchorPoint: NSPoint?
    private var resizeObserver: NSObjectProtocol?
    private var screenObserver: NSObjectProtocol?

    init(state: AppState, onConfigureProvider: @escaping () -> Void = {}) {
        self.state = state
        self.onConfigureProvider = onConfigureProvider
    }

    func show() {
        if panel == nil { build() }
        anchorPoint = NSEvent.mouseLocation
        // Force a layout pass so the window adopts the current content size before positioning.
        panel?.layoutIfNeeded()
        positionNearAnchor()
        // Use-and-dismiss entrance: fade in. Height is driven by SwiftUI's preferredContentSize,
        // so we animate opacity only (no height补间) to avoid NSPanel jitter — see design.md Decision 4.
        panel?.alphaValue = 0
        panel?.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.18
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel?.animator().alphaValue = 1
        }
    }

    func hide() {
        panel?.orderOut(nil)
    }

    private func build() {
        let hosting = NSHostingController(rootView: ResultView(state: state, onConfigureProvider: onConfigureProvider))
        // Let the window track the SwiftUI content's ideal size automatically — including when
        // translations arrive asynchronously and the content grows/shrinks.
        hosting.sizingOptions = [.preferredContentSize]
        self.hosting = hosting
        let p = NSPanel(contentViewController: hosting)
        p.styleMask = [.titled, .closable, .nonactivatingPanel, .fullSizeContentView]
        p.titleVisibility = .hidden
        p.titlebarAppearsTransparent = true
        p.isFloatingPanel = true
        p.level = .floating
        p.hidesOnDeactivate = false
        p.isMovableByWindowBackground = true
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        // Clear base so the SwiftUI .regularMaterial + rounded corners define the visible shape.
        p.backgroundColor = .clear
        p.isOpaque = false
        p.hasShadow = true

        // Hide the traffic-light buttons — a lightweight "即用即走" panel shouldn't show window chrome.
        p.standardWindowButton(.closeButton)?.isHidden = true
        p.standardWindowButton(.miniaturizeButton)?.isHidden = true
        p.standardWindowButton(.zoomButton)?.isHidden = true

        self.panel = p

        resizeObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didResizeNotification, object: p, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.positionNearAnchor() }
        }

        screenObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didChangeScreenNotification, object: p, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.positionNearAnchor() }
        }

        // Auto-hide when the panel resigns key.
        NotificationCenter.default.addObserver(
            forName: NSWindow.didResignKeyNotification, object: p, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.panel?.orderOut(nil)
            }
        }
    }

    private func positionNearAnchor() {
        guard let panel else { return }
        let mouse = anchorPoint ?? NSEvent.mouseLocation
        let size = panel.frame.size
        var origin = NSPoint(x: mouse.x + 12, y: mouse.y - size.height - 12)
        if let screen = NSScreen.screens.first(where: { $0.frame.contains(mouse) }) ?? NSScreen.main {
            let visible = screen.visibleFrame.insetBy(dx: 8, dy: 8)
            origin.x = Self.clamp(origin.x, min: visible.minX, max: visible.maxX - size.width)
            origin.y = Self.clamp(origin.y, min: visible.minY, max: visible.maxY - size.height)
        }
        panel.setFrameOrigin(origin)
    }

    private static func clamp(_ value: CGFloat, min minValue: CGFloat, max maxValue: CGFloat) -> CGFloat {
        guard maxValue >= minValue else { return minValue }
        return Swift.min(Swift.max(value, minValue), maxValue)
    }

    deinit {
        if let resizeObserver { NotificationCenter.default.removeObserver(resizeObserver) }
        if let screenObserver { NotificationCenter.default.removeObserver(screenObserver) }
    }
}
