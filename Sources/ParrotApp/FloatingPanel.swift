import AppKit
import SwiftUI

/// Shared presentation state for the floating result panel.
/// Tracks workspace-level chrome that lives outside translation state.
final class FloatingPanelPresentation: ObservableObject {
    @Published var isPinned = false
}

private final class WorkspacePanel: NSPanel {
    var onCloseRequest: (() -> Void)?

    override func performClose(_ sender: Any?) {
        if let onCloseRequest {
            onCloseRequest()
        } else {
            super.performClose(sender)
        }
    }

    override func close() {
        if let onCloseRequest {
            onCloseRequest()
        } else {
            super.close()
        }
    }
}

/// Non-activating floating panel that shows translation results near the cursor and
/// behaves as a small translation workspace once it has draft text or results.
@MainActor
final class FloatingPanel {
    private enum Metrics {
        static let defaultContentSize = NSSize(width: 520, height: 640)
        static let minContentSize = NSSize(width: 520, height: 320)
    }

    private var panel: NSPanel?
    private var hosting: NSHostingController<ResultView>?
    private let state: AppState
    private let onConfigureProvider: (String?) -> Void
    private let onVocabulary: () -> Void
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
    private var suppressFocusLossHideUntil: Date?

    init(
        state: AppState,
        onConfigureProvider: @escaping (String?) -> Void = { _ in },
        onVocabulary: @escaping () -> Void = {},
        onWorkspaceNoticeAction: @escaping (WorkspaceNotice.Action) -> Void = { _ in }
    ) {
        self.state = state
        self.onConfigureProvider = onConfigureProvider
        self.onVocabulary = onVocabulary
        self.onWorkspaceNoticeAction = onWorkspaceNoticeAction
    }

    func show(focusComposer: Bool = false) {
        if panel == nil { build() }
        panel?.level = .floating
        if focusComposer {
            NSApp.activate(ignoringOtherApps: true)
            suppressFocusLossHideUntil = Date().addingTimeInterval(0.8)
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
        // Use-and-dismiss entrance: fade in only. Size is user-adjustable, so avoid height animation.
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
        panel?.contentMinSize = Metrics.minContentSize
        panel?.orderOut(nil)
        panel?.alphaValue = 1
        isHiding = false
        suppressFocusLossHideUntil = nil
        userPositionedPanel = false
        lastStableFrame = nil
    }

    /// Before capturing selected text, hide only transient panels. A pinned panel should keep
    /// its place and simply update with the next translation result.
    func prepareForExternalCapture() {
        if presentation.isPinned {
            panel?.orderFrontRegardless()
        } else {
            hide(force: true)
        }
    }

    func refreshTitle() {
        panel?.title = L("Parrot 翻译")
        panel?.setAccessibilityTitle(L("Parrot 翻译"))
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
            onVocabulary: onVocabulary,
            onWorkspaceNoticeAction: onWorkspaceNoticeAction,
            onClose: { [weak self] in self?.hide(force: true) }
        ))
        hosting.sizingOptions = []
        self.hosting = hosting
        let p = WorkspacePanel(contentViewController: hosting)
        p.styleMask = [.titled, .closable, .resizable, .fullSizeContentView]
        let title = L("Parrot 翻译")
        p.title = title
        p.setAccessibilityTitle(title)
        p.titleVisibility = .hidden
        p.titlebarAppearsTransparent = true
        p.contentMinSize = Metrics.minContentSize
        p.setContentSize(Metrics.defaultContentSize)
        p.isReleasedWhenClosed = false
        p.isFloatingPanel = true
        p.level = .floating
        p.hidesOnDeactivate = false
        p.isMovableByWindowBackground = true
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        p.backgroundColor = .clear
        p.isOpaque = false
        p.hasShadow = true

        p.onCloseRequest = { [weak self] in self?.hide(force: true) }
        p.standardWindowButton(.closeButton)?.isHidden = true
        p.standardWindowButton(.miniaturizeButton)?.isHidden = true
        p.standardWindowButton(.zoomButton)?.isHidden = true

        self.panel = p

        resizeObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didResizeNotification, object: p, queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in self?.preservePlacementAfterResize() }
        }

        screenObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didChangeScreenNotification, object: p, queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in self?.keepCurrentPlacement() }
        }

        moveObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didMoveNotification, object: p, queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
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
            Task { @MainActor [weak self] in
                self?.hideTransientPanelIfNeeded()
            }
        }

        installOutsideClickMonitors()
    }

    private func togglePinned() {
        presentation.isPinned.toggle()
        if presentation.isPinned {
            panel?.level = .floating
            panel?.orderFrontRegardless()
        } else {
            panel?.level = .normal
        }
    }

    private func installOutsideClickMonitors() {
        let mask: NSEvent.EventTypeMask = [.leftMouseDown, .rightMouseDown, .otherMouseDown]
        if globalMouseDownMonitor == nil {
            globalMouseDownMonitor = NSEvent.addGlobalMonitorForEvents(matching: mask) { [weak self] event in
                let point = Self.screenPoint(for: event)
                Task { @MainActor [weak self] in self?.hideAfterOutsideClickIfNeeded(at: point) }
            }
        }
        if localMouseDownMonitor == nil {
            localMouseDownMonitor = NSEvent.addLocalMonitorForEvents(matching: mask) { [weak self] event in
                let point = Self.screenPoint(for: event)
                Task { @MainActor [weak self] in self?.hideAfterOutsideClickIfNeeded(at: point) }
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

    private func hideTransientPanelIfNeeded(respectingActiveWorkspace: Bool = true) {
        guard !presentation.isPinned else { return }
        guard let panel, panel.isVisible else { return }
        if respectingActiveWorkspace {
            if let suppressFocusLossHideUntil, Date() < suppressFocusLossHideUntil { return }
            guard !state.shouldKeepWorkspaceVisible else {
                lowerUnpinnedWorkspace()
                return
            }
        }
        guard !isHiding else { return }
        isHiding = true
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.12
            ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
            panel.animator().alphaValue = 0
        } completionHandler: { [weak self, weak panel] in
            Task { @MainActor [weak self, weak panel] in
                panel?.orderOut(nil)
                panel?.alphaValue = 1
                self?.isHiding = false
            }
        }
    }

    private func lowerUnpinnedWorkspace() {
        guard !presentation.isPinned else { return }
        panel?.level = .normal
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
        guard !isProgrammaticMove else { return }

        let clamped = WindowPlacement.clampedFrame(panel.frame)
        guard !NSEqualRects(panel.frame, clamped) else {
            userPositionedPanel = true
            lastStableFrame = panel.frame
            return
        }

        moveProgrammatically {
            panel.setFrame(clamped, display: true)
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
