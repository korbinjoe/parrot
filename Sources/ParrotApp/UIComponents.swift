import SwiftUI
import ParrotCore

/// Shared UI primitives used across the floating panel, input bar and (later) history window.
/// Styling comes from `Theme` (see DesignTokens.swift) so light/dark adapt automatically.

/// Language direction pill: source → target. Shows a fallback ("自动"/"中") until resolved.
struct LangPill: View {
    let from: Language
    let to: Language

    var body: some View {
        HStack(spacing: 6) {
            Text(Self.label(from, auto: "自动"))
            Image(systemName: "arrow.left.arrow.right").font(.system(size: 9))
                .foregroundStyle(Theme.Palette.accent)
            Text(Self.label(to, auto: "中"))
        }
        .font(.system(size: 11, weight: .semibold))
        .foregroundStyle(Theme.Palette.label2)
        .padding(.horizontal, 9)
        .padding(.vertical, 3)
        .background(Theme.Palette.bgContent2)
        .clipShape(Capsule())
        .overlay(Capsule().strokeBorder(Theme.Palette.separator, lineWidth: 0.5))
    }

    static func label(_ lang: Language, auto: String) -> String {
        switch lang {
        case .auto: return auto
        case .zh: return "中"
        case .ja: return "日"
        case .ko: return "한"
        default: return (lang.code ?? auto).uppercased()
        }
    }
}

/// Borderless icon button with a consistent 24×24 hit area.
struct IconButton: View {
    let name: String
    let help: String
    let size: CGFloat
    let action: () -> Void

    init(_ name: String, help: String, size: CGFloat = 13, action: @escaping () -> Void) {
        self.name = name
        self.help = help
        self.size = size
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Image(systemName: name)
                .font(.system(size: size))
                .foregroundStyle(Theme.Palette.label2)
                .frame(width: 24, height: 24)
        }
        .buttonStyle(.borderless)
        .help(help)
    }
}
