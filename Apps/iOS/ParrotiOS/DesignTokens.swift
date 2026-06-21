import SwiftUI
import UIKit

enum IOSTheme {
    static let ink = dynamic(light: ui(0.063, 0.071, 0.078), dark: ui(0.934, 0.956, 0.919))
    static let muted = dynamic(light: ui(0.384, 0.408, 0.376), dark: ui(0.715, 0.752, 0.686))
    static let soft = dynamic(light: ui(0.549, 0.576, 0.537), dark: ui(0.575, 0.624, 0.548))
    static let paper = dynamic(light: ui(0.957, 0.965, 0.937), dark: ui(0.068, 0.086, 0.063))
    static let surface = dynamic(light: ui(1.0, 0.996, 0.976), dark: ui(0.115, 0.137, 0.105))
    static let surface2 = dynamic(light: ui(0.973, 0.98, 0.949), dark: ui(0.149, 0.176, 0.133))
    static let green = Color(red: 0.157, green: 0.788, blue: 0.435)
    static let cyan = Color(red: 0.165, green: 0.655, blue: 1.0)
    static let coral = Color(red: 1.0, green: 0.42, blue: 0.341)
    static let amber = Color(red: 0.925, green: 0.667, blue: 0.153)
    static let line = dynamic(light: UIColor.black.withAlphaComponent(0.08), dark: UIColor.white.withAlphaComponent(0.12))
    static let subtleFill = dynamic(light: UIColor.black.withAlphaComponent(0.06), dark: UIColor.white.withAlphaComponent(0.09))
    static let meaningTint = dynamic(light: ui(0.875, 0.973, 0.91), dark: ui(0.086, 0.251, 0.151))

    static let radius: CGFloat = 22

    private static func ui(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat) -> UIColor {
        UIColor(red: red, green: green, blue: blue, alpha: 1)
    }

    private static func dynamic(light: UIColor, dark: UIColor) -> Color {
        Color(UIColor { traits in
            traits.userInterfaceStyle == .dark ? dark : light
        })
    }
}

struct CardBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(IOSTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: IOSTheme.radius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: IOSTheme.radius, style: .continuous)
                    .stroke(IOSTheme.line, lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.08), radius: 16, y: 8)
    }
}

extension View {
    func parrotCard() -> some View { modifier(CardBackground()) }
}
