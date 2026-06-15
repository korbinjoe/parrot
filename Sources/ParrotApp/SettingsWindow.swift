import AppKit
import SwiftUI
import ParrotCore

/// Hosts the SwiftUI settings UI in a standard titled window (separate from the floating panel).
@MainActor
final class SettingsWindow {
    private let state: AppState
    private var window: NSWindow?

    init(state: AppState) {
        self.state = state
    }

    func show() {
        if window == nil {
            let hosting = NSHostingController(rootView: SettingsView(state: state))
            let win = NSWindow(contentViewController: hosting)
            win.title = "Parrot 设置"
            win.styleMask = [.titled, .closable, .miniaturizable]
            win.isReleasedWhenClosed = false
            win.setContentSize(NSSize(width: 640, height: 460))
            window = win
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.center()
        window?.makeKeyAndOrderFront(nil)
    }
}

/// Preferences laid out as a sidebar + content panel (see redesign-app-ui mockups/surf-settings).
struct SettingsView: View {
    @ObservedObject var state: AppState
    @ObservedObject private var settings: AppSettings

    enum Pane: String, CaseIterable, Identifiable {
        case general, engines, keys, shortcuts, plugins, about
        var id: String { rawValue }
        var title: String {
            switch self {
            case .general: return "通用"
            case .engines: return "引擎"
            case .keys: return "密钥"
            case .shortcuts: return "快捷键"
            case .plugins: return "插件"
            case .about: return "关于"
            }
        }
        var icon: String {
            switch self {
            case .general: return "gearshape"
            case .engines: return "globe"
            case .keys: return "key"
            case .shortcuts: return "command"
            case .plugins: return "puzzlepiece"
            case .about: return "info.circle"
            }
        }
    }

    @State private var selection: Pane = .general
    @State private var deepLKey: String = ""
    @State private var openAIKey: String = ""
    @State private var savedNote: String = ""

    private let languages: [(String, String)] = [
        ("zh", "中文"), ("en", "English"), ("ja", "日本語"), ("ko", "한국어"),
        ("fr", "Français"), ("de", "Deutsch"), ("es", "Español"), ("ru", "Русский"),
    ]

    init(state: AppState) {
        self.state = state
        self.settings = state.settings
    }

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            Divider()
            ScrollView {
                content
                    .padding(.horizontal, Theme.Spacing.s20 + 4)
                    .padding(.vertical, Theme.Spacing.s20)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(Theme.Palette.bgContent)
        }
        .frame(width: 640, height: 460)
        .onAppear {
            deepLKey = settings.deepLKey() ?? ""
            openAIKey = settings.openAIKey() ?? ""
        }
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(Pane.allCases) { pane in
                sidebarRow(pane)
            }
            Spacer()
        }
        .padding(Theme.Spacing.s8)
        .frame(width: 180)
        .background(.regularMaterial)
    }

    private func sidebarRow(_ pane: Pane) -> some View {
        let selected = selection == pane
        return HStack(spacing: 9) {
            Image(systemName: pane.icon).frame(width: 16)
            Text(pane.title)
            Spacer()
        }
        .font(Theme.Font.body)
        .foregroundStyle(selected ? Color.white : Theme.Palette.label)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(selected ? Theme.Palette.accent : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 7))
        .contentShape(Rectangle())
        .onTapGesture { selection = pane }
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        switch selection {
        case .general: generalPane
        case .engines: enginesPane
        case .keys: keysPane
        case .shortcuts: shortcutsPane
        case .plugins: pluginsPane
        case .about: aboutPane
        }
    }

    private var generalPane: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionTitle("通用")
            settingRow("默认目标语言") {
                Picker("", selection: $settings.targetLanguageCode) {
                    ForEach(languages, id: \.0) { code, name in Text(name).tag(code) }
                }
                .labelsHidden()
                .frame(width: 140)
                .onChange(of: settings.targetLanguageCode) { _ in state.applySettings() }
            }
        }
    }

    private var enginesPane: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionTitle("翻译引擎")
            engineRow("Google 翻译", note: "免费 · 无需 Key",
                      status: settings.googleEnabled ? .ok : .off,
                      isOn: $settings.googleEnabled)
            engineRow("DeepL", note: settings.hasDeepLKey ? nil : "未配置 Key",
                      status: status(enabled: settings.deepLEnabled, hasKey: settings.hasDeepLKey),
                      isOn: $settings.deepLEnabled)
            engineRow("OpenAI", note: settings.hasOpenAIKey ? nil : "未配置 Key",
                      status: status(enabled: settings.openAIEnabled, hasKey: settings.hasOpenAIKey),
                      isOn: $settings.openAIEnabled)
        }
    }

    private var keysPane: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionTitle("API Keys")
            settingRow("DeepL API Key") {
                SecureField("免费版以 :fx 结尾", text: $deepLKey).frame(width: 230)
            }
            settingRow("OpenAI API Key") {
                SecureField("sk-…", text: $openAIKey).frame(width: 230)
            }
            HStack(spacing: Theme.Spacing.s12) {
                Button("保存到钥匙串") { saveKeys() }
                if !savedNote.isEmpty {
                    Text(savedNote).font(Theme.Font.callout).foregroundStyle(Theme.Palette.success)
                }
                Spacer()
            }
            .padding(.top, Theme.Spacing.s12)
            callout("🔒 API Key 存储于 macOS 钥匙串，绝不写入 UserDefaults、历史库或日志。")
        }
    }

    private var shortcutsPane: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionTitle("全局快捷键")
            shortcutRow("划词翻译", "⌥D")
            shortcutRow("查词", "⌥E")
            shortcutRow("截图翻译", "⌥S")
            shortcutRow("输入翻译", "⌥A")
        }
    }

    private var pluginsPane: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionTitle("插件")
            Text("JS 插件可接入任意 LLM / 词典，运行于沙箱（网络白名单）。")
                .font(Theme.Font.callout).foregroundStyle(Theme.Palette.label2)
                .padding(.bottom, Theme.Spacing.s12)
            HStack(spacing: Theme.Spacing.s12) {
                Button("打开插件目录") { openPluginsFolder() }
                Spacer()
            }
            callout("插件目录：~/Library/Application Support/Parrot/Plugins\n开发文档见仓库 docs/plugin-development.md")
        }
    }

    private var aboutPane: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s8) {
            sectionTitle("关于")
            HStack(spacing: Theme.Spacing.s12) {
                Image(systemName: "character.bubble.fill")
                    .font(.system(size: 36)).foregroundStyle(Theme.Palette.accent)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Parrot").font(.system(size: 17, weight: .semibold))
                    Text("版本 \(appVersion)").font(Theme.Font.callout).foregroundStyle(Theme.Palette.label2)
                }
            }
            Text("开源的 macOS 翻译 + OCR 工具 · 完全免费、无次数限制")
                .font(Theme.Font.callout).foregroundStyle(Theme.Palette.label2)
                .padding(.top, Theme.Spacing.s4)
            Link("GitHub 仓库", destination: URL(string: "https://github.com/korbinjoe/parrot")!)
                .font(Theme.Font.callout)
        }
    }

    // MARK: - Row builders

    private func sectionTitle(_ t: String) -> some View {
        Text(t).font(.system(size: 15, weight: .semibold))
            .foregroundStyle(Theme.Palette.label)
            .padding(.bottom, Theme.Spacing.s12)
    }

    private func settingRow<Control: View>(_ label: String, @ViewBuilder control: () -> Control) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text(label).font(Theme.Font.body).foregroundStyle(Theme.Palette.label)
                Spacer()
                control()
            }
            .frame(minHeight: 30)
            Divider()
        }
    }

    private func engineRow(_ name: String, note: String?, status: EngineStatus, isOn: Binding<Bool>) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: Theme.Spacing.s8) {
                Text(name).font(Theme.Font.body).foregroundStyle(Theme.Palette.label)
                if let note { Text(note).font(Theme.Font.caption).foregroundStyle(Theme.Palette.label3) }
                Spacer()
                Circle().fill(status.color).frame(width: 7, height: 7)
                Toggle("", isOn: isOn).labelsHidden().toggleStyle(.switch).controlSize(.small)
                    .onChange(of: isOn.wrappedValue) { _ in state.applySettings() }
            }
            .frame(minHeight: 30)
            Divider()
        }
    }

    private func shortcutRow(_ label: String, _ key: String) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text(label).font(Theme.Font.body).foregroundStyle(Theme.Palette.label)
                Spacer()
                Text(key)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.Palette.label)
                    .padding(.horizontal, 9).padding(.vertical, 3)
                    .background(Theme.Palette.bgContent2)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Theme.Palette.separator, lineWidth: 0.5))
            }
            .frame(minHeight: 30)
            Divider()
        }
    }

    private func callout(_ text: String) -> some View {
        Text(text)
            .font(Theme.Font.callout).foregroundStyle(Theme.Palette.label2)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Theme.Spacing.s12)
            .background(Theme.Palette.bgContent2)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .padding(.top, Theme.Spacing.s12)
    }

    // MARK: - Helpers

    enum EngineStatus {
        case ok, warn, off
        var color: Color {
            switch self {
            case .ok: return Theme.Palette.success
            case .warn: return Theme.Palette.warning
            case .off: return Theme.Palette.label3
            }
        }
    }

    private func status(enabled: Bool, hasKey: Bool) -> EngineStatus {
        if !enabled { return .off }
        return hasKey ? .ok : .warn
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.1.0"
    }

    private func openPluginsFolder() {
        let url = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/Parrot/Plugins")
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        NSWorkspace.shared.open(url)
    }

    private func saveKeys() {
        settings.setDeepLKey(deepLKey.trimmingCharacters(in: .whitespacesAndNewlines))
        settings.setOpenAIKey(openAIKey.trimmingCharacters(in: .whitespacesAndNewlines))
        state.applySettings()
        savedNote = "已保存 ✓"
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { savedNote = "" }
    }
}
