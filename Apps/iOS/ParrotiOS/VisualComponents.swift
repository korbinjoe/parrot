import SwiftUI

struct AppHeader<Trailing: View>: View {
    let leadingTitle: String?
    let leadingAction: (() -> Void)?
    let title: String
    @ViewBuilder let trailing: Trailing

    init(
        leadingTitle: String? = nil,
        leadingAction: (() -> Void)? = nil,
        title: String,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.leadingTitle = leadingTitle
        self.leadingAction = leadingAction
        self.title = title
        self.trailing = trailing()
    }

    var body: some View {
        HStack {
            if let leadingTitle {
                Button {
                    leadingAction?()
                } label: {
                    Text(leadingTitle)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(IOSTheme.cyan)
                        .frame(minWidth: 54, alignment: .leading)
                }
                .buttonStyle(.plain)
                .disabled(leadingAction == nil)
            } else {
                Color.clear.frame(width: 54, height: 1)
            }
            Spacer()
            Text(title)
                .font(.system(size: 14, weight: .heavy, design: .rounded))
                .foregroundStyle(IOSTheme.ink)
            Spacer()
            trailing.frame(minWidth: 54, alignment: .trailing)
        }
        .frame(height: 38)
        .padding(.horizontal, 16)
    }
}

struct EmptyTrailing: View {
    var body: some View { Color.clear.frame(width: 54, height: 1) }
}

struct StatusPill: View {
    let text: String
    var tone: Tone = .neutral

    enum Tone {
        case neutral, good, warn, blue
    }

    var body: some View {
        Text(text)
            .font(.system(size: 9.5, weight: .heavy, design: .rounded))
            .foregroundStyle(foreground)
            .lineLimit(1)
            .padding(.horizontal, 8)
            .frame(minHeight: 22)
            .background(background)
            .clipShape(Capsule())
    }

    private var foreground: Color {
        switch tone {
        case .neutral: return IOSTheme.muted
        case .good: return IOSTheme.greenDeep
        case .warn: return Color(red: 0.45, green: 0.29, blue: 0.02)
        case .blue: return Color(red: 0.09, green: 0.23, blue: 0.34)
        }
    }

    private var background: Color {
        switch tone {
        case .neutral: return IOSTheme.subtleFill
        case .good: return IOSTheme.green.opacity(0.15)
        case .warn: return IOSTheme.amber.opacity(0.17)
        case .blue: return IOSTheme.cyan.opacity(0.10)
        }
    }
}

struct IconTile: View {
    let systemName: String
    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: 14, weight: .bold))
            .foregroundStyle(IOSTheme.greenDeep)
            .frame(width: 30, height: 30)
            .background(Color.white.opacity(0.68))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

struct SectionTitle: View {
    let left: String
    var right: String?

    var body: some View {
        HStack {
            Text(left)
            Spacer(minLength: 8)
            if let right {
                Text(right)
            }
        }
        .font(.system(size: 10, weight: .heavy, design: .rounded))
        .foregroundStyle(IOSTheme.muted)
        .textCase(.uppercase)
    }
}

struct MiniIconButton: View {
    let systemName: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Color(red: 0.09, green: 0.23, blue: 0.34))
                .frame(width: 32, height: 32)
                .background(IOSTheme.subtleFill)
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

struct CompactButtonStyle: ButtonStyle {
    var tone: Tone = .blue

    enum Tone {
        case blue, green, muted
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 10, weight: .heavy, design: .rounded))
            .foregroundStyle(foreground)
            .frame(minHeight: 28)
            .padding(.horizontal, 9)
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: IOSTheme.controlRadius, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }

    private var foreground: Color {
        switch tone {
        case .blue: return Color(red: 0.09, green: 0.23, blue: 0.34)
        case .green: return Color(red: 0.02, green: 0.18, blue: 0.09)
        case .muted: return IOSTheme.muted
        }
    }

    private var background: Color {
        switch tone {
        case .blue: return IOSTheme.cyan.opacity(0.10)
        case .green: return IOSTheme.green
        case .muted: return IOSTheme.subtleFill
        }
    }
}

extension ButtonStyle where Self == CompactButtonStyle {
    static var compactBlue: CompactButtonStyle { CompactButtonStyle(tone: .blue) }
    static var compactGreen: CompactButtonStyle { CompactButtonStyle(tone: .green) }
    static var compactMuted: CompactButtonStyle { CompactButtonStyle(tone: .muted) }
}
