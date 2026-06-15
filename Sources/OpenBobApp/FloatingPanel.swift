import AppKit
import SwiftUI

/// Non-activating floating panel that shows translation results near the cursor and
/// auto-hides when it loses focus. Mirrors Bob's "即用即走" behavior.
@MainActor
final class FloatingPanel {
    private var panel: NSPanel?
    private let state: AppState

    init(state: AppState) {
        self.state = state
    }

    func show() {
        if panel == nil { build() }
        positionNearCursor()
        panel?.orderFrontRegardless()
    }

    func hide() {
        panel?.orderOut(nil)
    }

    private func build() {
        let hosting = NSHostingController(rootView: ResultView(state: state))
        let p = NSPanel(contentViewController: hosting)
        p.styleMask = [.titled, .closable, .nonactivatingPanel, .fullSizeContentView]
        p.titleVisibility = .hidden
        p.titlebarAppearsTransparent = true
        p.isFloatingPanel = true
        p.level = .floating
        p.hidesOnDeactivate = false
        p.isMovableByWindowBackground = true
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        p.backgroundColor = .windowBackgroundColor
        self.panel = p

        // Auto-hide when the panel resigns key.
        NotificationCenter.default.addObserver(
            forName: NSWindow.didResignKeyNotification, object: p, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.panel?.orderOut(nil)
            }
        }
    }

    private func positionNearCursor() {
        guard let panel else { return }
        let mouse = NSEvent.mouseLocation
        let size = panel.frame.size
        var origin = NSPoint(x: mouse.x + 12, y: mouse.y - size.height - 12)
        if let screen = NSScreen.screens.first(where: { $0.frame.contains(mouse) }) ?? NSScreen.main {
            let visible = screen.visibleFrame
            origin.x = min(max(origin.x, visible.minX), visible.maxX - size.width)
            origin.y = min(max(origin.y, visible.minY), visible.maxY - size.height)
        }
        panel.setFrameOrigin(origin)
    }
}
