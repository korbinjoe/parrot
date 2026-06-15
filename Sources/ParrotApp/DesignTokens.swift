import SwiftUI
import AppKit

/// Central design tokens for the redesigned UI.
/// Mirrors openspec/changes/redesign-app-ui/design.md §1. All colors map to macOS
/// semantic system colors so light/dark adapt automatically — no hardcoded hex.
enum Theme {
    enum Palette {
        /// Window base.
        static let bgWindow = Color(nsColor: .windowBackgroundColor)
        /// Content/card surface (engine cards).
        static let bgContent = Color(nsColor: .textBackgroundColor)
        /// Secondary surface (source block) — soft gray that differs from cards by lightness.
        static let bgContent2 = Color(nsColor: .underPageBackgroundColor)
        /// Hairline separators / 0.5px strokes.
        static let separator = Color(nsColor: .separatorColor)

        static let label = Color.primary
        static let label2 = Color.secondary
        static let label3 = Color(nsColor: .tertiaryLabelColor)

        /// The single global accent (systemBlue), follows the system accent setting.
        static let accent = Color(nsColor: .controlAccentColor)
        static let accentSoft = Color(nsColor: .controlAccentColor).opacity(0.12)

        static let success = Color(nsColor: .systemGreen)
        static let warning = Color(nsColor: .systemOrange)
        static let danger = Color(nsColor: .systemRed)
        static let star = Color(nsColor: .systemYellow)
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
    }

    enum Radius {
        static let window: CGFloat = 12
        static let card: CGFloat = 10
        static let control: CGFloat = 6
    }
}
