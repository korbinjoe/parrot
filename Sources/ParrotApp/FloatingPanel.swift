import AppKit
import Combine
import SwiftUI

/// Shared presentation state for the floating result panel.
/// Tracks workspace-level chrome that lives outside translation state.
final class FloatingPanelPresentation: ObservableObject {
    @Published var isPinned = false
    @Published var isCapturingSelection = false
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
        static let initialContentSize = FloatingPanelSizing.initialContentSize
        static let minContentSize = FloatingPanelSizing.minimumContentSize
    }

    private var panel: NSPanel?
    private var hosting: NSHostingController<ResultView>?
    private let state: AppState
    private let onConfigureProvider: (String?) -> Void
    private let onVocabulary: () -> Void
    private let onContextMemory: () -> Void
    private let onReplaceInSourceApp: (String) -> Bool
    private let onReturnToSourceApp: () -> Void
    private let onWorkspaceNoticeAction: (WorkspaceNotice.Action) -> Void
    private let presentation = FloatingPanelPresentation()
    private var anchorPoint: NSPoint?
    private var resizeObserver: NSObjectProtocol?
    private var screenObserver: NSObjectProtocol?
    private var resignObserver: NSObjectProtocol?
    private var globalMouseDownMonitor: Any?
    private var localMouseDownMonitor: Any?
    private var moveObserver: NSObjectProtocol?
    private var isProgrammaticMove = false
    private var userPositionedPanel = false
    private var userResizedPanel = false
    private var lastProgrammaticFrame: NSRect?
    private var geometryRevision = 0
    private var latestContentMetrics: FloatingPanelContentMetrics?
    private var automaticResizeScheduled = false
    private var sizingSessionID: String?
    private var mayShrinkAutomaticSize = true
    private var suppressFocusLossHideUntil: Date?

    init(
        state: AppState,
        onConfigureProvider: @escaping (String?) -> Void = { _ in },
        onVocabulary: @escaping () -> Void = {},
        onContextMemory: @escaping () -> Void = {},
        onReplaceInSourceApp: @escaping (String) -> Bool = { _ in false },
        onReturnToSourceApp: @escaping () -> Void = {},
        onWorkspaceNoticeAction: @escaping (WorkspaceNotice.Action) -> Void = { _ in }
    ) {
        self.state = state
        self.onConfigureProvider = onConfigureProvider
        self.onVocabulary = onVocabulary
        self.onContextMemory = onContextMemory
        self.onReplaceInSourceApp = onReplaceInSourceApp
        self.onReturnToSourceApp = onReturnToSourceApp
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
        let shouldPlaceNearCursor = !wasVisible && !userPositionedPanel
            && !userResizedPanel && !presentation.isPinned
        if shouldPlaceNearCursor {
            anchorPoint = NSEvent.mouseLocation
        }
        // Force a layout pass so the window adopts the current content size before positioning.
        panel?.layoutIfNeeded()
        if shouldPlaceNearCursor {
            placeNearAnchor()
        } else {
            keepCurrentPlacement()
        }
        // Show immediately. Repeated requests update the same visible panel without
        // restarting a fade or racing a previous dismissal animation.
        panel?.alphaValue = 1
        if focusComposer {
            panel?.makeKeyAndOrderFront(nil)
            requestComposerFocusOnNextRunLoop()
        } else {
            panel?.orderFrontRegardless()
        }
        installOutsideClickMonitors()
        scheduleAutomaticResize()
    }

    func hide(force: Bool = false) {
        guard force || !state.shouldKeepWorkspaceVisible else { return }
        panel?.contentMinSize = Metrics.minContentSize
        panel?.orderOut(nil)
        panel?.alphaValue = 1
        removeOutsideClickMonitors()
        suppressFocusLossHideUntil = nil
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

    func beginSelectionCapture() {
        presentation.isCapturingSelection = true
        show()
    }

    func endSelectionCapture() {
        presentation.isCapturingSelection = false
    }

    func refreshTitle() {
        panel?.title = L("Parrot 翻译")
        panel?.setAccessibilityTitle(L("Parrot 翻译"))
    }

    private func requestComposerFocusOnNextRunLoop() {
        DispatchQueue.main.async { [weak self] in
            guard let self, !self.presentation.isCapturingSelection else { return }
            self.state.requestComposerFocus()
        }
    }

    private func build() {
        let hosting = NSHostingController(rootView: ResultView(
            state: state,
            panelPresentation: presentation,
            onTogglePinned: { [weak self] in self?.togglePinned() },
            onConfigureProvider: onConfigureProvider,
            onVocabulary: onVocabulary,
            onContextMemory: onContextMemory,
            onReplaceInSourceApp: onReplaceInSourceApp,
            onReturnToSourceApp: onReturnToSourceApp,
            onWorkspaceNoticeAction: onWorkspaceNoticeAction,
            onClose: { [weak self] in self?.requestClose() },
            onContentMetricsChange: { [weak self] metrics in
                self?.latestContentMetrics = metrics
                self?.scheduleAutomaticResize()
            }
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
        p.setContentSize(Metrics.initialContentSize)
        p.isReleasedWhenClosed = false
        p.isFloatingPanel = true
        p.level = .floating
        p.hidesOnDeactivate = false
        p.isMovableByWindowBackground = true
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        p.backgroundColor = .clear
        p.isOpaque = false
        p.hasShadow = true

        p.onCloseRequest = { [weak self] in self?.requestClose() }
        p.standardWindowButton(.closeButton)?.isHidden = true
        p.standardWindowButton(.miniaturizeButton)?.isHidden = true
        p.standardWindowButton(.zoomButton)?.isHidden = true

        self.panel = p

        resizeObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didResizeNotification, object: p, queue: .main
        ) { [weak self] _ in
            // Notifications arrive on the main queue: classify the geometry change
            // immediately, before the programmatic-change guard is cleared.
            MainActor.assumeIsolated { self?.preservePlacementAfterResize() }
        }

        screenObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didChangeScreenNotification, object: p, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.keepCurrentPlacement()
                self?.scheduleAutomaticResize()
            }
        }

        moveObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didMoveNotification, object: p, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, !self.isProgrammaticGeometryChange else { return }
                self.userPositionedPanel = true
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

    }

    private func scheduleAutomaticResize() {
        guard !automaticResizeScheduled else { return }
        automaticResizeScheduled = true
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.automaticResizeScheduled = false
            self.resizeToMeasuredContent()
        }
    }

    private func resizeToMeasuredContent() {
        guard let panel, panel.isVisible, !userResizedPanel,
              !panel.inLiveResize, let metrics = latestContentMetrics,
              let screen = panel.screen ?? WindowPlacement.screen(containing: panel.frame.origin) else { return }
        if sizingSessionID != metrics.sessionID {
            sizingSessionID = metrics.sessionID
            mayShrinkAutomaticSize = true
        }
        let currentFrame = panel.frame
        let hostingView = hosting?.view ?? panel.contentView
        let viewSize = hostingView?.bounds.size
            ?? panel.contentRect(forFrameRect: currentFrame).size
        let safeArea = hostingView?.safeAreaInsets ?? NSEdgeInsets()
        // A full-size content view includes the transparent title bar, while
        // SwiftUI lays out this document inside the hosting view's safe area.
        // Compare measured content with that usable area, reserving each inset
        // once instead of assuming the full NSView height can display results.
        let currentContentSize = CGSize(
            width: max(0, viewSize.width - safeArea.left - safeArea.right),
            height: max(0, viewSize.height - safeArea.top - safeArea.bottom)
        )
        let frameChrome = CGSize(
            width: max(0, currentFrame.width - currentContentSize.width),
            height: max(0, currentFrame.height - currentContentSize.height)
        )
        let preservePosition = userPositionedPanel || presentation.isPinned

        // Width affects text wrapping. Set it first, then use the fresh layout's
        // document height instead of fitting the stale, narrower measurement.
        let widthFrame = FloatingPanelSizing.frame(
            current: currentFrame,
            desiredContentSize: CGSize(width: metrics.preferredWidth, height: currentContentSize.height),
            frameChrome: frameChrome, visibleFrame: screen.visibleFrame,
            allowShrink: mayShrinkAutomaticSize, preservePosition: preservePosition
        )
        if abs(widthFrame.width - currentFrame.width) > 1 {
            moveProgrammatically { panel.setFrame(widthFrame, display: true) }
            return
        }
        guard abs(metrics.contentSize.width - currentContentSize.width) <= 1 else { return }
        let fitted = FloatingPanelSizing.frame(
            current: currentFrame,
            desiredContentSize: CGSize(width: metrics.preferredWidth,
                                       height: ceil(metrics.contentSize.height + metrics.chromeHeight)),
            frameChrome: frameChrome, visibleFrame: screen.visibleFrame,
            allowShrink: mayShrinkAutomaticSize, preservePosition: preservePosition
        )
        mayShrinkAutomaticSize = false
        guard abs(fitted.width - currentFrame.width) > 1
                || abs(fitted.height - currentFrame.height) > 1
                || abs(fitted.minX - currentFrame.minX) > 1
                || abs(fitted.minY - currentFrame.minY) > 1 else { return }
        moveProgrammatically { panel.setFrame(fitted, display: true) }
    }

    private func requestClose() {
        guard state.isSourceDirty, let panel else {
            hide(force: true)
            return
        }
        let alert = NSAlert()
        alert.messageText = L("源文还有未翻译的修改")
        alert.informativeText = L("关闭后会保留当前草稿，下次打开工作区可继续编辑。")
        alert.addButton(withTitle: L("保留草稿并关闭"))
        alert.addButton(withTitle: L("继续编辑"))
        alert.buttons.last?.keyEquivalent = "\u{1b}"
        alert.beginSheetModal(for: panel) { [weak self] response in
            if response == .alertFirstButtonReturn {
                self?.hide(force: true)
            }
        }
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

    private func removeOutsideClickMonitors() {
        if let globalMouseDownMonitor { NSEvent.removeMonitor(globalMouseDownMonitor) }
        if let localMouseDownMonitor { NSEvent.removeMonitor(localMouseDownMonitor) }
        globalMouseDownMonitor = nil
        localMouseDownMonitor = nil
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
        hide(force: true)
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
            let anchor = panel.screen.map { NSPoint(x: $0.frame.midX, y: $0.frame.midY) }
            WindowPlacement.clamp(panel, near: anchor)
        }
    }

    private func preservePlacementAfterResize() {
        guard let panel else { return }
        guard !isProgrammaticGeometryChange else { return }
        userResizedPanel = true
        userPositionedPanel = true

        let anchor = panel.screen.map { NSPoint(x: $0.frame.midX, y: $0.frame.midY) }
        let clamped = WindowPlacement.clampedFrame(panel.frame, near: anchor)
        guard !NSEqualRects(panel.frame, clamped) else { return }

        moveProgrammatically {
            panel.setFrame(clamped, display: true)
        }
    }

    private var isProgrammaticGeometryChange: Bool {
        isProgrammaticMove || (panel.map { current in
            lastProgrammaticFrame.map { NSEqualRects(current.frame, $0) } ?? false
        } ?? false)
    }

    private func moveProgrammatically(_ action: () -> Void) {
        geometryRevision += 1
        let revision = geometryRevision
        isProgrammaticMove = true
        action()
        lastProgrammaticFrame = panel?.frame
        DispatchQueue.main.async { [weak self] in
            guard let self, self.geometryRevision == revision else { return }
            self.isProgrammaticMove = false
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
