import SwiftUI
import ParrotCore

/// Menu-bar dropdown content: four primary actions, recent history,
/// then settings/quit. Replaces the bare `NSMenu` so it can share the app's design tokens.
struct MenuBarPopoverView: View {
    @ObservedObject var state: AppState

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

            actionRow("gearshape", "设置…", "⌘,", action: onSettings)
            actionRow("power", "退出 Parrot", "⌘Q", action: onQuit)
        }
        .padding(6)
        .frame(width: 248)
        .background(Theme.Palette.bgContent)
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
            HStack(spacing: Theme.Spacing.s8) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(rec.sourceText)
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.Palette.label)
                        .lineLimit(1)
                    Text(rec.translated)
                        .font(Theme.Font.caption)
                        .foregroundStyle(Theme.Palette.label3)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Theme.Palette.label3)
            }
        }
    }

    // MARK: - Chrome

    private func sectionLabel(_ t: String) -> some View {
        Text(t).font(Theme.Font.caption).foregroundStyle(Theme.Palette.label3)
            .fontWeight(.semibold)
            .padding(.horizontal, 9).padding(.top, 2).padding(.bottom, 4)
    }

    private var sectionDivider: some View {
        Divider().padding(.horizontal, 5).padding(.vertical, 5)
    }

    private func loadRecents() {
        Task {
            let all = await state.history.all()
            recents = Array(all.prefix(3))
        }
    }
}

/// A full-width row that highlights with the shared selection fill on hover.
private struct HoverRow<Content: View>: View {
    let action: () -> Void
    @ViewBuilder let content: () -> Content
    @State private var hovering = false

    var body: some View {
        content()
            .padding(.horizontal, 9)
            .frame(minHeight: 28)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(hovering ? Theme.Palette.bgSelection : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .contentShape(Rectangle())
            .onHover { hovering = $0 }
            .onTapGesture(perform: action)
    }
}
