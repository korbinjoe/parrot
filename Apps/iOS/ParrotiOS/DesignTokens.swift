import SwiftUI
import UIKit

enum IOSTheme {
    static let ink = dynamic(light: ui(0.063, 0.071, 0.078), dark: ui(0.934, 0.956, 0.919))
    static let muted = dynamic(light: ui(0.408, 0.443, 0.427), dark: ui(0.715, 0.752, 0.686))
    static let soft = dynamic(light: ui(0.572, 0.608, 0.588), dark: ui(0.575, 0.624, 0.548))
    static let paper = dynamic(light: ui(0.965, 0.973, 0.957), dark: ui(0.068, 0.086, 0.063))
    static let surface = dynamic(light: ui(1.0, 0.996, 0.976), dark: ui(0.115, 0.137, 0.105))
    static let surface2 = dynamic(light: ui(0.929, 0.957, 0.929), dark: ui(0.149, 0.176, 0.133))
    static let green = Color(red: 0.133, green: 0.780, blue: 0.404)
    static let greenDeep = dynamic(light: ui(0.031, 0.463, 0.259), dark: ui(0.553, 0.906, 0.651))
    static let cyan = Color(red: 0.090, green: 0.537, blue: 0.910)
    static let blueDeep = dynamic(light: ui(0.090, 0.230, 0.340), dark: ui(0.647, 0.839, 0.980))
    static let warnDeep = dynamic(light: ui(0.450, 0.290, 0.020), dark: ui(0.980, 0.753, 0.345))
    static let coral = Color(red: 0.941, green: 0.424, blue: 0.345)
    static let amber = Color(red: 0.839, green: 0.604, blue: 0.133)
    static let line = dynamic(light: UIColor.black.withAlphaComponent(0.10), dark: UIColor.white.withAlphaComponent(0.12))
    static let subtleFill = dynamic(light: UIColor.black.withAlphaComponent(0.055), dark: UIColor.white.withAlphaComponent(0.09))
    static let meaningTint = dynamic(light: ui(0.906, 0.976, 0.929), dark: ui(0.086, 0.251, 0.151))

    static let cardRadius: CGFloat = 8
    static let controlRadius: CGFloat = 10

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
            .clipShape(RoundedRectangle(cornerRadius: IOSTheme.cardRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: IOSTheme.cardRadius, style: .continuous)
                    .stroke(IOSTheme.line, lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.055), radius: 14, y: 7)
    }
}

extension View {
    func parrotCard() -> some View { modifier(CardBackground()) }

    func parrotControl() -> some View {
        clipShape(RoundedRectangle(cornerRadius: IOSTheme.controlRadius, style: .continuous))
    }
}
