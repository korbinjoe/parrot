import SwiftUI
import AppKit

/// Native macOS surfaces, quiet typography and a single system-blue action color.
enum Theme {
    enum Palette {
        static let bgWindow = Color(nsColor: .windowBackgroundColor)
        static let bgCanvas = adaptive(
            light: NSColor(white: 0.965, alpha: 1),
            dark: NSColor(white: 0.115, alpha: 1)
        )
        static let bgPanel = adaptive(
            light: NSColor(white: 0.985, alpha: 1),
            dark: NSColor(white: 0.145, alpha: 1)
        )
        static let bgContent = adaptive(
            light: NSColor(white: 1, alpha: 1),
            dark: NSColor(white: 0.17, alpha: 1)
        )
        static let bgControl = adaptive(
            light: NSColor(white: 0.935, alpha: 1),
            dark: NSColor(white: 0.21, alpha: 1)
        )
        static let bgSidebar = adaptive(
            light: NSColor(white: 0.95, alpha: 1),
            dark: NSColor(white: 0.13, alpha: 1)
        )
        static let bgSelection = accent.opacity(0.11)
        static let bgSkeleton = Color(nsColor: .quaternaryLabelColor)
        static let separator = Color(nsColor: .separatorColor)
        static let hairline = separator.opacity(0.32)

        static let label = Color(nsColor: .labelColor)
        static let label2 = Color(nsColor: .secondaryLabelColor)
        static let label3 = Color(nsColor: .tertiaryLabelColor)
        static let accent = Color(nsColor: .systemBlue)
        static let accentInk = Color.white
        static let accentSoft = accent.opacity(0.09)
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
        static let result = SwiftUI.Font.system(size: 16, weight: .regular)
        static let body = SwiftUI.Font.system(size: 13)
        static let callout = SwiftUI.Font.system(size: 12)
        static let caption = SwiftUI.Font.system(size: 11)
        static let tag = SwiftUI.Font.system(size: 11, weight: .medium)
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
        static let window: CGFloat = 14
        static let input: CGFloat = 8
        static let card: CGFloat = 8
        static let group: CGFloat = 10
        static let control: CGFloat = 6
    }
}
