import Foundation
import CoreGraphics

/// Natural document height and the layout width that produced it. Viewport width
/// is measured separately so a non-overlay scrollbar cannot stall width fitting.
struct FloatingPanelContentMetrics: Equatable {
    var contentSize: CGSize
    var chromeHeight: CGFloat
    var preferredWidth: CGFloat
    var sessionID: String
}

/// Pure sizing policy. AppKit owns when to apply it and whether the user has resized.
enum FloatingPanelSizing {
    static let minimumContentSize = CGSize(width: 520, height: 320)
    static let initialContentSize = CGSize(width: 560, height: 360)
    static let screenInset: CGFloat = 8

    static func preferredWidth(longestTextCount: Int, providerCount: Int) -> CGFloat {
        if longestTextCount > 1200 { return 840 }
        if longestTextCount > 450 || providerCount >= 3 { return 760 }
        if longestTextCount > 180 || providerCount >= 2 { return 660 }
        return initialContentSize.width
    }

    static func frame(
        current: CGRect,
        desiredContentSize: CGSize,
        frameChrome: CGSize,
        visibleFrame: CGRect,
        allowShrink: Bool,
        preservePosition: Bool,
        userResized: Bool = false
    ) -> CGRect {
        guard !userResized else { return current }
        let visible = visibleFrame.insetBy(dx: screenInset, dy: screenInset)
        guard visible.width > 0, visible.height > 0 else { return current }

        // Grow toward the right and down from the current upper-left corner.
        let currentWidth = min(current.width, visible.width)
        let currentHeight = min(current.height, visible.height)
        let left = min(max(current.minX, visible.minX), visible.maxX - currentWidth)
        let top = min(max(current.maxY, visible.minY + currentHeight), visible.maxY)
        let maximumWidth = preservePosition ? visible.maxX - left : visible.width
        let maximumHeight = preservePosition ? top - visible.minY : visible.height
        let comfortableWidth = min(840 + frameChrome.width, visible.width * 0.8)
        let minimumWidth = min(minimumContentSize.width + frameChrome.width, maximumWidth)
        let minimumHeight = min(minimumContentSize.height + frameChrome.height, maximumHeight)
        var width = min(max(desiredContentSize.width + frameChrome.width, minimumWidth),
                        max(minimumWidth, comfortableWidth))
        var height = max(desiredContentSize.height + frameChrome.height, minimumHeight)
        if !allowShrink {
            width = max(width, current.width)
            height = max(height, current.height)
        }
        width = min(width, maximumWidth)
        height = min(height, maximumHeight)
        var origin = CGPoint(x: left, y: top - height)
        if !preservePosition {
            origin.x = min(max(origin.x, visible.minX), visible.maxX - width)
            origin.y = min(max(origin.y, visible.minY), visible.maxY - height)
        }
        return CGRect(x: origin.x, y: origin.y, width: width, height: height)
    }
}
