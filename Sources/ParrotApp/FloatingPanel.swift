import AppKit
import SwiftUI

/// Shared presentation state for the floating result panel.
/// Default is transient: it hides on focus loss. Pinning makes the same panel stay visible.
final class FloatingPanelPresentation: ObservableObject {
    @Published var isPinned = false
}

/// Non-activating floating panel that shows translation results near the cursor and
/// auto-hides when it loses focus. Implements an "即用即走" (use-and-dismiss) behavior.
@MainActor
final class FloatingPanel {
    private var panel: NSPanel?
    private var hosting: NSHostingController<ResultView>?
    private let state: AppState
    private let onConfigureProvider: () -> Void
    private let presentation = FloatingPanelPresentation()
    private var anchorPoint: NSPoint?
    private var resizeObserver: NSObjectProtocol?
    private var screenObserver: NSObjectProtocol?
    private var resignObserver: NSObjectProtocol?
    private var globalMouseDownMonitor: Any?
    private var localMouseDownMonitor: Any?
    private var isHiding = false

    init(state: AppState, onConfigureProvider: @escaping () -> Void = {}) {
        self.state = state
        self.onConfigureProvider = onConfigureProvider
    }

    func show() {
        if panel == nil { build() }
        let wasVisible = panel?.isVisible == true
        if !presentation.isPinned || !wasVisible {
            anchorPoint = NSEvent.mouseLocation
        }
        // Force a layout pass so the window adopts the current content size before positioning.
        panel?.layoutIfNeeded()
        if !presentation.isPinned || !wasVisible {
            positionNearAnchor()
        }
        if presentation.isPinned && wasVisible {
            panel?.orderFrontRegardless()
            return
        }
        isHiding = false
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
        panel?.alphaValue = 1
        isHiding = false
    }

    /// Before capturing selected text, hide only transient panels. A pinned panel should keep
    /// its place and simply update with the next translation result.
    func prepareForExternalCapture() {
        if !presentation.isPinned {
            hide()
        }
    }

    private func build() {
        let hosting = NSHostingController(rootView: ResultView(
            state: state,
            panelPresentation: presentation,
            onTogglePinned: { [weak self] in self?.togglePinned() },
            onConfigureProvider: onConfigureProvider
        ))
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
        // Clear base so the SwiftUI rounded solid panel defines the visible shape.
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
        resignObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didResignKeyNotification, object: p, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.hideTransientPanelIfNeeded()
            }
        }

        installOutsideClickMonitors()
    }

    private func togglePinned() {
        presentation.isPinned.toggle()
        if presentation.isPinned {
            panel?.orderFrontRegardless()
        }
    }

    private func installOutsideClickMonitors() {
        let mask: NSEvent.EventTypeMask = [.leftMouseDown, .rightMouseDown, .otherMouseDown]
        if globalMouseDownMonitor == nil {
            globalMouseDownMonitor = NSEvent.addGlobalMonitorForEvents(matching: mask) { [weak self] event in
                let point = Self.screenPoint(for: event)
                Task { @MainActor in self?.hideAfterOutsideClickIfNeeded(at: point) }
            }
        }
        if localMouseDownMonitor == nil {
            localMouseDownMonitor = NSEvent.addLocalMonitorForEvents(matching: mask) { [weak self] event in
                let point = Self.screenPoint(for: event)
                Task { @MainActor in self?.hideAfterOutsideClickIfNeeded(at: point) }
                return event
            }
        }
    }

    private static func screenPoint(for event: NSEvent) -> NSPoint {
        if let window = event.window {
            return window.convertPoint(toScreen: event.locationInWindow)
        }
        return event.locationInWindow
    }

    private func hideAfterOutsideClickIfNeeded(at point: NSPoint) {
        guard let panel, panel.isVisible else { return }
        guard !panel.frame.insetBy(dx: -6, dy: -6).contains(point) else { return }
        hideTransientPanelIfNeeded()
    }

    private func hideTransientPanelIfNeeded() {
        guard !presentation.isPinned else { return }
        guard let panel, panel.isVisible else { return }
        guard !isHiding else { return }
        isHiding = true
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.12
            ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
            panel.animator().alphaValue = 0
        } completionHandler: {
            Task { @MainActor in
                panel.orderOut(nil)
                panel.alphaValue = 1
                self.isHiding = false
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
        if let resignObserver { NotificationCenter.default.removeObserver(resignObserver) }
        if let globalMouseDownMonitor { NSEvent.removeMonitor(globalMouseDownMonitor) }
        if let localMouseDownMonitor { NSEvent.removeMonitor(localMouseDownMonitor) }
    }
}
