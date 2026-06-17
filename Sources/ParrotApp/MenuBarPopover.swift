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
            permissionStrip

            actionRow(
                "character.cursor.ibeam",
                "划词翻译",
                state.permissions.accessibilityGranted ? "⌥D" : "需辅助功能",
                disabled: !state.permissions.accessibilityGranted,
                action: onSelection
            )
            actionRow(
                "text.magnifyingglass",
                "查词",
                state.permissions.accessibilityGranted ? "⌥E" : "需辅助功能",
                disabled: !state.permissions.accessibilityGranted,
                action: onLookup
            )
            actionRow(
                "camera.viewfinder",
                "截图翻译",
                state.permissions.screenRecordingGranted ? "⌥S" : "需屏幕录制",
                disabled: !state.permissions.screenRecordingGranted,
                action: onScreenshot
            )
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
        .onAppear {
            state.refreshPermissions()
            loadRecents()
        }
    }

    // MARK: - Rows

    private func actionRow(
        _ icon: String,
        _ title: String,
        _ shortcut: String,
        disabled: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        HoverRow(action: action, disabled: disabled) {
            HStack(spacing: 9) {
                Image(systemName: icon).frame(width: 16).foregroundStyle(Theme.Palette.label2)
                Text(L(title)).font(Theme.Font.body).foregroundStyle(Theme.Palette.label)
                Spacer(minLength: 0)
                Text(L(shortcut)).font(Theme.Font.caption).foregroundStyle(Theme.Palette.label3)
            }
        }
        .accessibilityLabel(L(title))
        .accessibilityHint(L(shortcut))
    }

    private func plainRow(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        HoverRow(action: action) {
            HStack(spacing: 9) {
                Image(systemName: icon).frame(width: 16).foregroundStyle(Theme.Palette.label2)
                Text(L(title)).font(Theme.Font.body).foregroundStyle(Theme.Palette.accent)
                Spacer(minLength: 0)
            }
        }
    }

    @ViewBuilder
    private var permissionStrip: some View {
        if state.permissions.hasBlockingIssue {
            HStack(alignment: .top, spacing: Theme.Spacing.s8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.Palette.warning)
                    .frame(width: 16, height: 16)
                VStack(alignment: .leading, spacing: 2) {
                    Text(L(state.permissions.summary))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.Palette.label)
                    Text("部分快捷动作暂不可用")
                        .font(Theme.Font.caption)
                        .foregroundStyle(Theme.Palette.label3)
                }
                Spacer(minLength: 0)
                Button("设置") { onSettings() }
                    .buttonStyle(.borderless)
                    .font(Theme.Font.caption)
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 8)
            .background(Theme.Palette.bgControl)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .padding(.bottom, 5)
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
        Text(L(t)).font(Theme.Font.caption).foregroundStyle(Theme.Palette.label3)
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
    var disabled: Bool = false
    @ViewBuilder let content: () -> Content
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            content()
                .padding(.horizontal, 9)
                .frame(minHeight: 28)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .opacity(disabled ? 0.55 : 1)
        .background(!disabled && hovering ? Theme.Palette.bgSelection : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
    }
}
