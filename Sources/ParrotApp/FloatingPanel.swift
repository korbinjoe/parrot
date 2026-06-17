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
    private let onWorkspaceNoticeAction: (WorkspaceNotice.Action) -> Void
    private let presentation = FloatingPanelPresentation()
    private var anchorPoint: NSPoint?
    private var resizeObserver: NSObjectProtocol?
    private var screenObserver: NSObjectProtocol?
    private var resignObserver: NSObjectProtocol?
    private var globalMouseDownMonitor: Any?
    private var localMouseDownMonitor: Any?
    private var moveObserver: NSObjectProtocol?
    private var isHiding = false
    private var isProgrammaticMove = false
    private var userPositionedPanel = false
    private var lastStableFrame: NSRect?

    init(
        state: AppState,
        onConfigureProvider: @escaping () -> Void = {},
        onWorkspaceNoticeAction: @escaping (WorkspaceNotice.Action) -> Void = { _ in }
    ) {
        self.state = state
        self.onConfigureProvider = onConfigureProvider
        self.onWorkspaceNoticeAction = onWorkspaceNoticeAction
    }

    func show(focusComposer: Bool = false) {
        if panel == nil { build() }
        if focusComposer {
            NSApp.activate(ignoringOtherApps: true)
        }
        let wasVisible = panel?.isVisible == true
        if !wasVisible {
            anchorPoint = NSEvent.mouseLocation
            userPositionedPanel = false
        }
        // Force a layout pass so the window adopts the current content size before positioning.
        panel?.layoutIfNeeded()
        if !wasVisible {
            placeNearAnchor()
        } else {
            keepCurrentPlacement()
        }
        if presentation.isPinned && wasVisible {
            if focusComposer {
                panel?.makeKeyAndOrderFront(nil)
                requestComposerFocusOnNextRunLoop()
            } else {
                panel?.orderFrontRegardless()
            }
            return
        }
        isHiding = false
        // Use-and-dismiss entrance: fade in. Height is driven by SwiftUI's preferredContentSize,
        // so we animate opacity only (no height补间) to avoid NSPanel jitter — see design.md Decision 4.
        panel?.alphaValue = 0
        if focusComposer {
            panel?.makeKeyAndOrderFront(nil)
            requestComposerFocusOnNextRunLoop()
        } else {
            panel?.orderFrontRegardless()
        }
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.18
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel?.animator().alphaValue = 1
        }
    }

    func hide(force: Bool = false) {
        guard force || !state.shouldKeepWorkspaceVisible else { return }
        panel?.orderOut(nil)
        panel?.alphaValue = 1
        isHiding = false
        userPositionedPanel = false
        lastStableFrame = nil
    }

    /// Before capturing selected text, hide only transient panels. A pinned panel should keep
    /// its place and simply update with the next translation result.
    func prepareForExternalCapture() {
        if !presentation.isPinned {
            hide(force: true)
        }
    }

    private func requestComposerFocusOnNextRunLoop() {
        DispatchQueue.main.async { [weak self] in
            self?.state.requestComposerFocus()
        }
    }

    private func build() {
        let hosting = NSHostingController(rootView: ResultView(
            state: state,
            panelPresentation: presentation,
            onTogglePinned: { [weak self] in self?.togglePinned() },
            onConfigureProvider: onConfigureProvider,
            onWorkspaceNoticeAction: onWorkspaceNoticeAction,
            onClose: { [weak self] in self?.hide(force: true) }
        ))
        // Let the window track the SwiftUI content's ideal size automatically — including when
        // translations arrive asynchronously and the content grows/shrinks.
        hosting.sizingOptions = [.preferredContentSize]
        self.hosting = hosting
        let p = NSPanel(contentViewController: hosting)
        p.styleMask = [.titled, .closable, .fullSizeContentView]
        p.title = "Parrot 翻译"
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
            Task { @MainActor in self?.preservePlacementAfterResize() }
        }

        screenObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didChangeScreenNotification, object: p, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.keepCurrentPlacement() }
        }

        moveObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didMoveNotification, object: p, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                if self.isProgrammaticMove {
                    return
                }
                self.userPositionedPanel = true
                self.lastStableFrame = self.panel?.frame
            }
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
        guard !state.shouldKeepWorkspaceVisible else { return }
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

    private func placeNearAnchor() {
        guard let panel else { return }
        moveProgrammatically {
            WindowPlacement.place(panel, near: anchorPoint ?? NSEvent.mouseLocation)
        }
    }

    private func keepCurrentPlacement() {
        guard let panel else { return }
        moveProgrammatically {
            WindowPlacement.clamp(panel)
        }
    }

    private func preservePlacementAfterResize() {
        guard let panel else { return }
        guard let previous = lastStableFrame else {
            keepCurrentPlacement()
            return
        }

        var frame = panel.frame
        frame.origin.x = previous.origin.x
        frame.origin.y = previous.maxY - frame.height
        moveProgrammatically {
            panel.setFrame(WindowPlacement.clampedFrame(frame), display: true)
        }
    }

    private func moveProgrammatically(_ action: () -> Void) {
        isProgrammaticMove = true
        action()
        lastStableFrame = panel?.frame
        DispatchQueue.main.async { [weak self] in
            self?.isProgrammaticMove = false
        }
    }

    deinit {
        if let resizeObserver { NotificationCenter.default.removeObserver(resizeObserver) }
        if let screenObserver { NotificationCenter.default.removeObserver(screenObserver) }
        if let resignObserver { NotificationCenter.default.removeObserver(resignObserver) }
        if let moveObserver { NotificationCenter.default.removeObserver(moveObserver) }
        if let globalMouseDownMonitor { NSEvent.removeMonitor(globalMouseDownMonitor) }
        if let localMouseDownMonitor { NSEvent.removeMonitor(localMouseDownMonitor) }
    }
}
