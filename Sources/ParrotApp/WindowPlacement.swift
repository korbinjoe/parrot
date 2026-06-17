import AppKit

enum WindowPlacement {
    static let screenInset: CGFloat = 8

    static func center(_ window: NSWindow, near anchor: NSPoint? = nil) {
        guard let screen = screen(containing: anchor ?? NSEvent.mouseLocation) else { return }
        let visible = screen.visibleFrame.insetBy(dx: screenInset, dy: screenInset)
        var frame = window.frame
        frame.origin.x = visible.midX - frame.width / 2
        frame.origin.y = visible.midY - frame.height / 2
        window.setFrame(clamped(frame, to: visible), display: true)
    }

    static func place(_ window: NSWindow, near anchor: NSPoint, xOffset: CGFloat = 12, yOffset: CGFloat = 12) {
        guard let screen = screen(containing: anchor) else { return }
        let visible = screen.visibleFrame.insetBy(dx: screenInset, dy: screenInset)
        let size = window.frame.size
        var frame = NSRect(
            x: anchor.x + xOffset,
            y: anchor.y - size.height - yOffset,
            width: size.width,
            height: size.height
        )
        frame = clamped(frame, to: visible)
        window.setFrame(frame, display: true)
    }

    static func clamp(_ window: NSWindow, near anchor: NSPoint? = nil) {
        guard let screen = screen(containing: anchor ?? window.frame.center) else { return }
        let visible = screen.visibleFrame.insetBy(dx: screenInset, dy: screenInset)
        window.setFrame(clamped(window.frame, to: visible), display: true)
    }

    static func clampedFrame(_ frame: NSRect, near anchor: NSPoint? = nil) -> NSRect {
        guard let screen = screen(containing: anchor ?? frame.center) else { return frame }
        let visible = screen.visibleFrame.insetBy(dx: screenInset, dy: screenInset)
        return clamped(frame, to: visible)
    }

    static func screen(containing point: NSPoint) -> NSScreen? {
        NSScreen.screens.first(where: { $0.frame.contains(point) }) ?? NSScreen.main ?? NSScreen.screens.first
    }

    private static func clamped(_ frame: NSRect, to visible: NSRect) -> NSRect {
        var frame = frame
        if frame.width > visible.width {
            frame.size.width = visible.width
        }
        if frame.height > visible.height {
            frame.size.height = visible.height
        }
        frame.origin.x = min(max(frame.origin.x, visible.minX), visible.maxX - frame.width)
        frame.origin.y = min(max(frame.origin.y, visible.minY), visible.maxY - frame.height)
        return frame
    }
}

private extension NSRect {
    var center: NSPoint {
        NSPoint(x: midX, y: midY)
    }
}
