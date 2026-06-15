import SwiftUI
import ParrotCore

/// Menu-bar dropdown content (260pt): four primary actions, recent history, engine quick toggles,
/// then settings/quit. Replaces the bare `NSMenu` so it can share the app's design tokens.
struct MenuBarPopoverView: View {
    @ObservedObject var state: AppState
    @ObservedObject var settings: AppSettings

    let onSelection: () -> Void
    let onLookup: () -> Void
    let onScreenshot: () -> Void
    let onInput: () -> Void
    let onSettings: () -> Void
    let onHistory: () -> Void
    let onRetranslate: (String) -> Void
    let onQuit: () -> Void

    @State private var recents: [TranslationRecord] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            actionRow("character.cursor.ibeam", "划词翻译", "⌥D", action: onSelection)
            actionRow("text.magnifyingglass", "查词", "⌥E", action: onLookup)
            actionRow("camera.viewfinder", "截图翻译", "⌥S", action: onScreenshot)
            actionRow("keyboard", "输入翻译", "⌥A", action: onInput)

            sectionDivider

            sectionLabel("最近")
            if recents.isEmpty {
                Text("暂无翻译记录")
                    .font(Theme.Font.caption).foregroundStyle(Theme.Palette.label3)
                    .padding(.horizontal, 10).padding(.vertical, 5)
            } else {
                ForEach(recents) { rec in
                    recentRow(rec)
                }
            }
            plainRow("查看全部历史", icon: "clock.arrow.circlepath", action: onHistory)

            sectionDivider

            sectionLabel("引擎")
            engineToggle("Google", isOn: $settings.googleEnabled, hasKey: true)
            engineToggle("DeepL", isOn: $settings.deepLEnabled, hasKey: settings.hasDeepLKey)
            engineToggle("OpenAI", isOn: $settings.openAIEnabled, hasKey: settings.hasOpenAIKey)

            sectionDivider

            actionRow("gearshape", "设置…", "⌘,", action: onSettings)
            actionRow("power", "退出 Parrot", "⌘Q", action: onQuit)
        }
        .padding(Theme.Spacing.s8)
        .frame(width: 260)
        .onAppear(perform: loadRecents)
    }

    // MARK: - Rows

    private func actionRow(_ icon: String, _ title: String, _ shortcut: String, action: @escaping () -> Void) -> some View {
        HoverRow(action: action) {
            HStack(spacing: 9) {
                Image(systemName: icon).frame(width: 16).foregroundStyle(Theme.Palette.label2)
                Text(title).font(Theme.Font.body).foregroundStyle(Theme.Palette.label)
                Spacer(minLength: 0)
                Text(shortcut).font(Theme.Font.caption).foregroundStyle(Theme.Palette.label3)
            }
        }
    }

    private func plainRow(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        HoverRow(action: action) {
            HStack(spacing: 9) {
                Image(systemName: icon).frame(width: 16).foregroundStyle(Theme.Palette.label2)
                Text(title).font(Theme.Font.body).foregroundStyle(Theme.Palette.accent)
                Spacer(minLength: 0)
            }
        }
    }

    private func recentRow(_ rec: TranslationRecord) -> some View {
        HoverRow(action: { onRetranslate(rec.sourceText) }) {
            VStack(alignment: .leading, spacing: 1) {
                Text(rec.sourceText).font(Theme.Font.body)
                    .foregroundStyle(Theme.Palette.label).lineLimit(1)
                Text(rec.translated).font(Theme.Font.caption)
                    .foregroundStyle(Theme.Palette.label2).lineLimit(1)
            }
        }
    }

    private func engineToggle(_ name: String, isOn: Binding<Bool>, hasKey: Bool) -> some View {
        HStack(spacing: Theme.Spacing.s8) {
            Text(name).font(Theme.Font.body).foregroundStyle(Theme.Palette.label)
            if !hasKey {
                Text("未配置 Key").font(Theme.Font.caption).foregroundStyle(Theme.Palette.label3)
            }
            Spacer(minLength: 0)
            Toggle("", isOn: isOn).labelsHidden().toggleStyle(.switch).controlSize(.mini)
                .disabled(!hasKey)
                .onChange(of: isOn.wrappedValue) { _ in state.applySettings() }
        }
        .padding(.horizontal, 10).padding(.vertical, 4)
    }

    // MARK: - Chrome

    private func sectionLabel(_ t: String) -> some View {
        Text(t).font(Theme.Font.caption).foregroundStyle(Theme.Palette.label3)
            .padding(.horizontal, 10).padding(.top, 4).padding(.bottom, 2)
    }

    private var sectionDivider: some View {
        Divider().padding(.vertical, 4)
    }

    private func loadRecents() {
        Task {
            let all = await state.history.all()
            recents = Array(all.prefix(3))
        }
    }
}

/// A full-width row that highlights with accent-soft on hover. Used for menu items.
private struct HoverRow<Content: View>: View {
    let action: () -> Void
    @ViewBuilder let content: () -> Content
    @State private var hovering = false

    var body: some View {
        content()
            .padding(.horizontal, 10).padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(hovering ? Theme.Palette.accentSoft : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .contentShape(Rectangle())
            .onHover { hovering = $0 }
            .onTapGesture(perform: action)
    }
}
