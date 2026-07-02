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
        .frame(height: 24)
        .padding(.horizontal, 10)
        .background(Theme.Palette.bgControl)
        .clipShape(Capsule())
        .overlay(Capsule().strokeBorder(Theme.Palette.separator, lineWidth: 0.5))
    }

    static func label(_ lang: Language, auto: String) -> String {
        switch lang {
        case .auto: return L(auto)
        case .zh: return L("中")
        case .ja: return L("日")
        case .ko: return "한"
        default: return (lang.code ?? auto).uppercased()
        }
    }
}

/// Thin inline status strip for global conditions (e.g. no network). Warning-toned, full width.
struct WarningBar: View {
    let text: String
    let systemImage: String

    init(_ text: String, systemImage: String = "wifi.slash") {
        self.text = text
        self.systemImage = systemImage
    }

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage).font(.system(size: 11))
            Text(L(text)).font(Theme.Font.caption)
            Spacer(minLength: 0)
        }
        .foregroundStyle(Theme.Palette.warning)
        .padding(.horizontal, Theme.Spacing.s12)
        .padding(.vertical, 5)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.Palette.warning.opacity(0.12))
    }
}

/// Borderless icon button with a consistent 24×24 hit area.
struct IconButton: View {
    let name: String
    let help: String
    let size: CGFloat
    let foreground: Color?
    let activeBackground: Bool
    let isEnabled: Bool
    let action: () -> Void

    @State private var hovering = false
    @State private var showTip = false

    init(
        _ name: String,
        help: String,
        size: CGFloat = 13,
        foreground: Color? = nil,
        activeBackground: Bool = false,
        isEnabled: Bool = true,
        action: @escaping () -> Void
    ) {
        self.name = name
        self.help = help
        self.size = size
        self.foreground = foreground
        self.activeBackground = activeBackground
        self.isEnabled = isEnabled
        self.action = action
    }

    var body: some View {
        Button {
            guard isEnabled else { return }
            action()
        } label: {
            Image(systemName: name)
                .font(.system(size: size))
                .foregroundStyle(foreground ?? Theme.Palette.label2)
                .frame(width: 26, height: 26)
        }
        .buttonStyle(.borderless)
        .opacity(isEnabled ? 1 : 0.42)
        .background(activeBackground ? Theme.Palette.bgSelection : (hovering ? Theme.Palette.bgControl : Color.clear))
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.control))
        .contentShape(RoundedRectangle(cornerRadius: Theme.Radius.control))
        .overlay(alignment: .bottom) {
            if showTip {
                Text(L(help))
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Palette.label)
                    .lineLimit(1)
                    .padding(.horizontal, 8)
                    .frame(height: 22)
                    .background(Theme.Palette.bgPanel)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.control))
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.Radius.control)
                            .strokeBorder(Theme.Palette.separator, lineWidth: 0.5)
                    )
                    .shadow(color: Color.black.opacity(0.14), radius: 5, y: 2)
                    .fixedSize()
                    .offset(y: 28)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
                    .transition(.opacity)
            }
        }
        .zIndex(showTip ? 10 : 0)
        .onHover { inside in
            hovering = inside
            if inside {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                    guard hovering else { return }
                    withAnimation(.easeOut(duration: 0.08)) {
                        showTip = true
                    }
                }
            } else {
                withAnimation(.easeOut(duration: 0.06)) {
                    showTip = false
                }
            }
        }
        .help(L(help))
        .accessibilityLabel(L(help))
    }
}

struct PrimaryActionButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.Font.body)
            .foregroundStyle(Theme.Palette.accentInk)
            .padding(.horizontal, 12)
            .frame(minHeight: 28)
            .background(isEnabled ? (configuration.isPressed ? Theme.Palette.accent.opacity(0.82) : Theme.Palette.accent) : Theme.Palette.bgControl)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.control))
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .opacity(isEnabled ? 1 : 0.55)
    }
}

struct SecondaryActionButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.Font.body)
            .foregroundStyle(isEnabled ? Theme.Palette.label : Theme.Palette.label3)
            .padding(.horizontal, 12)
            .frame(minHeight: 28)
            .background(
                isEnabled
                    ? (configuration.isPressed ? Theme.Palette.bgSelection : Theme.Palette.bgControl)
                    : Theme.Palette.bgControl.opacity(0.6)
            )
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.control))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.control)
                    .strokeBorder(Theme.Palette.separator, lineWidth: 0.5)
            )
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .opacity(isEnabled ? 1 : 0.55)
    }
}
