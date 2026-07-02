import AppKit
import SwiftUI
import ParrotCore

@MainActor
final class ContextMemoryWindow {
    private let state: AppState
    private var window: NSWindow?

    init(state: AppState) {
        self.state = state
    }

    func show() {
        state.refreshLearningHistory()
        if window == nil {
            let hosting = NSHostingController(rootView: ContextMemoryView(state: state))
            let win = NSWindow(contentViewController: hosting)
            configureTitle(for: win)
            win.styleMask = [.titled, .closable, .miniaturizable, .resizable]
            win.isReleasedWhenClosed = false
            win.setContentSize(NSSize(width: 860, height: 540))
            win.contentMinSize = NSSize(width: 720, height: 460)
            window = win
        }
        NSApp.activate(ignoringOtherApps: true)
        if let window {
            WindowPlacement.center(window)
        }
        window?.makeKeyAndOrderFront(nil)
    }

    func refreshTitle() {
        if let window {
            configureTitle(for: window)
        }
    }

    private func configureTitle(for window: NSWindow) {
        let title = L("规则记忆")
        window.title = title
        window.setAccessibilityTitle(title)
    }
}

private struct ContextMemoryView: View {
    @ObservedObject var state: AppState
    @ObservedObject var settings: AppSettings

    init(state: AppState) {
        self.state = state
        self.settings = state.settings
    }

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.s16) {
                    currentContextSection
                    ruleSection
                    memorySection
                }
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(Theme.Palette.bgCanvas)
        }
        .background(Theme.Palette.bgPanel)
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s12) {
            VStack(alignment: .leading, spacing: 5) {
                Text(L("规则记忆"))
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(Theme.Palette.label)
                Text(L("让不同来源自动进入合适的翻译方式。"))
                    .font(Theme.Font.callout)
                    .foregroundStyle(Theme.Palette.label2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            metrics
            Spacer(minLength: 0)
        }
        .padding(18)
        .frame(width: 260, alignment: .topLeading)
        .background(Theme.Palette.bgSidebar)
    }

    private var metrics: some View {
        VStack(spacing: Theme.Spacing.s8) {
            metricRow(value: "\(enabledRuleCount)/3", label: "已启用规则")
            metricRow(value: "\(settings.terminologyEntries.filter(\.enabled).count)", label: "可用术语")
            metricRow(value: "\(settings.learningVocabularyEntries.count)", label: "已沉淀表达")
        }
    }

    private var enabledRuleCount: Int {
        [settings.contextRuleDocumentEnabled, settings.contextRuleDeveloperEnabled, settings.contextRulePrivateEnabled]
            .filter { $0 }
            .count
    }

    private func metricRow(value: String, label: String) -> some View {
        HStack {
            Text(value)
                .font(.system(size: 18, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(Theme.Palette.label)
                .frame(width: 56, alignment: .leading)
            Text(L(label))
                .font(Theme.Font.callout)
                .foregroundStyle(Theme.Palette.label2)
            Spacer(minLength: 0)
        }
        .padding(Theme.Spacing.s8)
        .background(Theme.Palette.bgContent)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.card).strokeBorder(Theme.Palette.hairline, lineWidth: 0.5))
    }

    private var currentContextSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s8) {
            sectionTitle("当前上下文")
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 170), spacing: 10)], spacing: 10) {
                contextTile("来源 App", state.currentContextSourceApp ?? "未捕捉")
                contextTile("来源 URL", state.currentContextSourceURL ?? "无")
                contextTile("当前配置", profileLabel(state.contextProfile))
            }
        }
    }

    private var ruleSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s8) {
            sectionTitle("自动规则")
            ruleRow(
                icon: "doc.text",
                title: "文档与网页",
                detail: "URL、Safari、Chrome、Notion、Confluence 和长文本进入长文理解。",
                isOn: $settings.contextRuleDocumentEnabled
            )
            ruleRow(
                icon: "chevron.left.forwardslash.chevron.right",
                title: "研发协作",
                detail: "GitHub、GitLab、Linear、Jira、Xcode 来源使用开发语境与敏感信息遮罩。",
                isOn: $settings.contextRuleDeveloperEnabled
            )
            ruleRow(
                icon: "lock.shield",
                title: "隐私本地",
                detail: "Password、Keychain、Bank、Wallet 等来源只允许本地引擎。",
                isOn: $settings.contextRulePrivateEnabled
            )
        }
    }

    private var memorySection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s8) {
            sectionTitle("已沉淀记忆")
            HStack(alignment: .top, spacing: Theme.Spacing.s12) {
                memoryList(
                    title: "术语",
                    empty: "暂无术语",
                    rows: Array(settings.terminologyEntries.filter(\.enabled).prefix(5)).map { "\($0.source) -> \($0.target)" }
                )
                memoryList(
                    title: "表达",
                    empty: "暂无表达",
                    rows: Array(settings.learningVocabularyEntries.prefix(5)).map { entry in
                        entry.meaning.isEmpty ? entry.term : "\(entry.term) -> \(entry.meaning)"
                    }
                )
            }
        }
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(L(text))
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(Theme.Palette.label)
    }

    private func contextTile(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(L(label))
                .font(Theme.Font.caption)
                .foregroundStyle(Theme.Palette.label3)
            Text(L(value))
                .font(Theme.Font.callout)
                .foregroundStyle(Theme.Palette.label)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Theme.Spacing.s12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.Palette.bgContent)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.card).strokeBorder(Theme.Palette.hairline, lineWidth: 0.5))
    }

    private func ruleRow(
        icon: String,
        title: String,
        detail: String,
        isOn: Binding<Bool>
    ) -> some View {
        HStack(alignment: .top, spacing: Theme.Spacing.s8) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.Palette.accent)
                .frame(width: 24, height: 24)
            VStack(alignment: .leading, spacing: 3) {
                Text(L(title))
                    .font(Theme.Font.callout)
                    .foregroundStyle(Theme.Palette.label)
                Text(L(detail))
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Palette.label2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            Toggle("", isOn: isOn)
                .toggleStyle(.switch)
                .labelsHidden()
        }
        .padding(Theme.Spacing.s12)
        .background(Theme.Palette.bgContent)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.card).strokeBorder(Theme.Palette.hairline, lineWidth: 0.5))
    }

    private func memoryList(title: String, empty: String, rows: [String]) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s8) {
            Text(L(title))
                .font(Theme.Font.callout.weight(.semibold))
                .foregroundStyle(Theme.Palette.label)
            if rows.isEmpty {
                Text(L(empty))
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Palette.label3)
                    .frame(maxWidth: .infinity, minHeight: 80, alignment: .center)
            } else {
                ForEach(rows, id: \.self) { row in
                    Text(row)
                        .font(Theme.Font.caption)
                        .foregroundStyle(Theme.Palette.label2)
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 3)
                }
            }
        }
        .padding(Theme.Spacing.s12)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(Theme.Palette.bgContent)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.card).strokeBorder(Theme.Palette.hairline, lineWidth: 0.5))
    }

    private func profileLabel(_ profile: TranslationContextProfile) -> String {
        switch profile {
        case .quickTranslate: return "快译"
        case .understand: return "理解"
        case .nativePolish: return "润色"
        case .reply: return "回复"
        case .strictTerminology: return "术语严格"
        case .privateLocal: return "隐私本地"
        case .github: return "GitHub"
        case .social: return "社媒"
        case .email: return "邮件"
        case .document: return "长文"
        }
    }
}
