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
            win.setContentSize(NSSize(width: 460, height: 420))
            window = win
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.center()
        window?.makeKeyAndOrderFront(nil)
    }
}

/// Preferences: default target language, engine toggles, and API keys (Keychain-backed).
struct SettingsView: View {
    @ObservedObject var state: AppState
    @ObservedObject private var settings: AppSettings

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
        Form {
            Section("通用") {
                Picker("默认目标语言", selection: $settings.targetLanguageCode) {
                    ForEach(languages, id: \.0) { code, name in
                        Text(name).tag(code)
                    }
                }
                .onChange(of: settings.targetLanguageCode) { _ in apply() }
            }

            Section("翻译引擎") {
                Toggle("Google 翻译（免费，无需 Key）", isOn: $settings.googleEnabled)
                    .onChange(of: settings.googleEnabled) { _ in apply() }
                Toggle("DeepL", isOn: $settings.deepLEnabled)
                    .onChange(of: settings.deepLEnabled) { _ in apply() }
                Toggle("OpenAI", isOn: $settings.openAIEnabled)
                    .onChange(of: settings.openAIEnabled) { _ in apply() }
            }

            Section("API Keys（存储于钥匙串）") {
                SecureField("DeepL API Key", text: $deepLKey)
                SecureField("OpenAI API Key", text: $openAIKey)
                HStack {
                    Button("保存 Keys") { saveKeys() }
                    if !savedNote.isEmpty {
                        Text(savedNote).font(.caption).foregroundStyle(.secondary)
                    }
                }
            }

            Section("快捷键") {
                LabeledContent("划词翻译", value: "⌥D")
                LabeledContent("查词", value: "⌥E")
                LabeledContent("截图翻译", value: "⌥S")
                LabeledContent("输入翻译", value: "⌥A")
            }
        }
        .formStyle(.grouped)
        .frame(width: 460, height: 420)
        .onAppear {
            deepLKey = settings.deepLKey() ?? ""
            openAIKey = settings.openAIKey() ?? ""
        }
    }

    private func apply() {
        state.applySettings()
    }

    private func saveKeys() {
        settings.setDeepLKey(deepLKey.trimmingCharacters(in: .whitespacesAndNewlines))
        settings.setOpenAIKey(openAIKey.trimmingCharacters(in: .whitespacesAndNewlines))
        state.applySettings()
        savedNote = "已保存 ✓"
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { savedNote = "" }
    }
}
