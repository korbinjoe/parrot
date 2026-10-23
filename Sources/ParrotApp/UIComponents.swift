import SwiftUI
import AppKit
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
            Image(systemName: "arrow.right").font(.system(size: 10))
                .foregroundStyle(Theme.Palette.label3)
            Text(Self.label(to, auto: "中"))
        }
        .font(.system(size: 12, weight: .medium))
        .foregroundStyle(Theme.Palette.label2)
        .frame(height: 26)
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

/// Borderless icon button with a consistent 32×32 hit area.
struct IconButton: View {
    let name: String
    let help: String
    let size: CGFloat
    let foreground: Color?
    let activeBackground: Bool
    let isEnabled: Bool
    let action: () -> Void

    @State private var hovering = false

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
                .frame(width: 32, height: 32)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.42)
        .background(activeBackground ? Theme.Palette.bgSelection : (hovering ? Theme.Palette.bgControl : Color.clear))
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.control))
        .onHover { hovering = $0 }
        .help(L(help))
        .accessibilityLabel(L(help))
    }
}

struct PrimaryActionButtonStyle: ButtonStyle {
    var isProminent = true
    @Environment(\.isEnabled) private var isEnabled

    init(isProminent: Bool = true) {
        self.isProminent = isProminent
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.Font.body.weight(.medium))
            .foregroundStyle(isEnabled ? (isProminent ? Theme.Palette.accentInk : Theme.Palette.label) : Theme.Palette.label3)
            .padding(.horizontal, 12)
            .frame(minHeight: 30)
            .background(isEnabled && isProminent ? (configuration.isPressed ? Theme.Palette.accent.opacity(0.82) : Theme.Palette.accent) : Theme.Palette.bgControl)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.control))
            .contentShape(Rectangle())
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
            .frame(minHeight: 30)
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
            .contentShape(Rectangle())
            .opacity(isEnabled ? 1 : 0.55)
    }
}

/// System-rendered material that follows appearance and accessibility transparency settings.
struct MacMaterialBackground: NSViewRepresentable {
    var material: NSVisualEffectView.Material = .sidebar

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = .withinWindow
        view.state = .active
        return view
    }

    func updateNSView(_ view: NSVisualEffectView, context: Context) {
        view.material = material
    }
}
