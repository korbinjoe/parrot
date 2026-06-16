import SwiftUI
import AppKit

/// Central design tokens for the redesigned UI.
/// Mirrors openspec/changes/redesign-app-ui/design.md §1. System surfaces map to
/// macOS semantic colors; the brand accent is fixed for visual consistency.
enum Theme {
    enum Palette {
        /// Standard titled-window base.
        static let bgWindow = Color(nsColor: .windowBackgroundColor)
        /// App canvas behind grouped content.
        static let bgCanvas = adaptive(
            light: NSColor(calibratedRed: 0.957, green: 0.965, blue: 0.976, alpha: 1),
            dark: NSColor(calibratedRed: 0.098, green: 0.106, blue: 0.129, alpha: 1)
        )
        /// Floating panel base: solid enough to stay readable over any desktop/app.
        static let bgPanel = adaptive(
            light: NSColor(calibratedRed: 0.984, green: 0.988, blue: 0.996, alpha: 1),
            dark: NSColor(calibratedRed: 0.129, green: 0.137, blue: 0.169, alpha: 1)
        )
        /// Primary content/card surface.
        static let bgContent = adaptive(
            light: NSColor(calibratedRed: 1, green: 1, blue: 1, alpha: 1),
            dark: NSColor(calibratedRed: 0.169, green: 0.176, blue: 0.208, alpha: 1)
        )
        /// Native control fill used by pill controls, keycaps and small buttons.
        static let bgControl = adaptive(
            light: NSColor(calibratedRed: 0.925, green: 0.937, blue: 0.961, alpha: 1),
            dark: NSColor(calibratedRed: 0.196, green: 0.208, blue: 0.251, alpha: 1)
        )
        /// Solid sidebar/popover chrome.
        static let bgSidebar = adaptive(
            light: NSColor(calibratedRed: 0.941, green: 0.949, blue: 0.965, alpha: 1),
            dark: NSColor(calibratedRed: 0.118, green: 0.129, blue: 0.165, alpha: 1)
        )
        static let bgSelection = accent.opacity(0.14)
        static let bgSkeleton = adaptive(
            light: NSColor(calibratedRed: 0.902, green: 0.918, blue: 0.949, alpha: 1),
            dark: NSColor(calibratedRed: 0.231, green: 0.243, blue: 0.282, alpha: 1)
        )
        /// Hairline separators / 0.5px strokes.
        static let separator = Color(nsColor: .separatorColor)
        static let hairline = separator.opacity(0.55)

        static let label = Color.primary
        static let label2 = Color.secondary
        static let label3 = Color(nsColor: .tertiaryLabelColor)

        /// Single global accent: muted periwinkle, #6d85c9.
        static let accent = Color(nsColor: NSColor(calibratedRed: 0.427451, green: 0.521569, blue: 0.788235, alpha: 1))
        /// Text/icon color used on solid accent fills. White is too low contrast on this accent.
        static let accentInk = Color(nsColor: NSColor(calibratedRed: 0.031373, green: 0.043137, blue: 0.101961, alpha: 1))
        static let accentSoft = accent.opacity(0.16)

        static let success = Color(nsColor: .systemGreen)
        static let warning = Color(nsColor: .systemOrange)
        static let danger = Color(nsColor: .systemRed)
        static let star = Color(nsColor: .systemYellow)

        private static func adaptive(light: NSColor, dark: NSColor) -> Color {
            Color(nsColor: NSColor(name: nil) { appearance in
                let match = appearance.bestMatch(from: [.darkAqua, .vibrantDark, .aqua, .vibrantLight])
                return (match == .darkAqua || match == .vibrantDark) ? dark : light
            })
        }
    }

    enum Font {
        static let result = SwiftUI.Font.system(size: 15)
        static let body = SwiftUI.Font.system(size: 13)
        static let callout = SwiftUI.Font.system(size: 12)
        static let caption = SwiftUI.Font.system(size: 11)
        static let tag = SwiftUI.Font.system(size: 10, weight: .semibold)
    }

    /// 8pt spacing grid.
    enum Spacing {
        static let s4: CGFloat = 4
        static let s8: CGFloat = 8
        static let s12: CGFloat = 12
        static let s16: CGFloat = 16
        static let s20: CGFloat = 20
        static let s24: CGFloat = 24
    }

    enum Radius {
        static let window: CGFloat = 12
        static let input: CGFloat = 14
        static let card: CGFloat = 10
        static let group: CGFloat = 12
        static let control: CGFloat = 7
    }
}
