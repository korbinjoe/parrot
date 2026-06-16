import AppKit
import SwiftUI
import ParrotCore
import ParrotEngines

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
        case general, engines, ocr, tts, keys, shortcuts, plugins, about
        var id: String { rawValue }
        var title: String {
            switch self {
            case .general: return "通用"
            case .engines: return "翻译"
            case .ocr: return "识别"
            case .tts: return "语音"
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
            case .ocr: return "doc.text.viewfinder"
            case .tts: return "waveform"
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
    @State private var openCodeKey: String = ""
    @State private var tencentCreds: String = ""
    @State private var baiduCreds: String = ""
    @State private var youdaoCreds: String = ""
    @State private var caiyunToken: String = ""
    @State private var microsoftKey: String = ""
    @State private var deepSeekKey: String = ""
    @State private var geminiKey: String = ""
    @State private var groqKey: String = ""
    @State private var qwenKey: String = ""
    @State private var doubaoKey: String = ""
    @State private var kimiKey: String = ""
    @State private var zhipuKey: String = ""
    @State private var siliconFlowKey: String = ""
    @State private var ollamaEndpointField: String = ""
    @State private var ollamaModelField: String = ""
    @State private var openAIModelField: String = ""
    @State private var openAIEndpointField: String = ""
    @State private var openCodeModelField: String = ""
    @State private var azureEndpointField: String = ""
    @State private var validateNote: String = ""
    @State private var savedNote: String = ""
    @State private var engineOrderDraft: [String] = []
    @State private var keysLoaded = false
    @State private var loadedSecretAccounts: Set<String> = []

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
                    .id(selection)
                    .transition(.opacity)
            }
            .background(Theme.Palette.bgContent)
            .animation(.easeInOut(duration: 0.15), value: selection)
        }
        .frame(width: 640, height: 460)
        .onAppear {
            ollamaEndpointField = settings.ollamaEndpoint
            ollamaModelField = settings.model(for: "ollama") ?? "llama3.2"
            openAIModelField = settings.openAIModel
            openAIEndpointField = settings.openAIEndpoint
            openCodeModelField = settings.model(for: "opencode") ?? "glm-5.1"
            azureEndpointField = settings.endpoint(for: "azure-openai") ?? ""
            engineOrderDraft = EngineBootstrap.resolvedOrder(settings.engineOrder)
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
        case .ocr: ocrPane
        case .tts: ttsPane
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
            Text("完整对照见 docs/bob-service-matrix.md")
                .font(Theme.Font.caption).foregroundStyle(Theme.Palette.label3)
                .padding(.bottom, Theme.Spacing.s8)
            engineRow("Google 翻译", note: "免费 · 无需 Key",
                      status: settings.googleEnabled ? .ok : .off,
                      isOn: $settings.googleEnabled)
            engineRow("DeepL", note: settings.hasDeepLKey ? nil : "未配置 Key",
                      status: status(enabled: settings.deepLEnabled, hasKey: settings.hasDeepLKey),
                      isOn: $settings.deepLEnabled)
            engineRow("OpenAI", note: settings.hasOpenAIKey ? nil : "未配置 Key",
                      status: status(enabled: settings.openAIEnabled, hasKey: settings.hasOpenAIKey),
                      isOn: $settings.openAIEnabled)
            engineRow("腾讯翻译君", note: settings.hasTencentCredentials ? nil : "SecretId:SecretKey",
                      status: status(enabled: settings.tencentEnabled, hasKey: settings.hasTencentCredentials),
                      isOn: $settings.tencentEnabled)
            engineRow("百度翻译", note: settings.hasBaiduCredentials ? nil : "AppId:Secret",
                      status: status(enabled: settings.baiduEnabled, hasKey: settings.hasBaiduCredentials),
                      isOn: $settings.baiduEnabled)
            engineRow("有道翻译", note: settings.hasYoudaoCredentials ? nil : "AppKey:Secret",
                      status: status(enabled: settings.youdaoEnabled, hasKey: settings.hasYoudaoCredentials),
                      isOn: $settings.youdaoEnabled)
            engineRow("彩云小译", note: settings.hasCaiyunToken ? nil : "Token",
                      status: status(enabled: settings.caiyunEnabled, hasKey: settings.hasCaiyunToken),
                      isOn: $settings.caiyunEnabled)
            engineRow("Microsoft 翻译", note: settings.hasMicrosoftKey ? nil : "订阅 Key",
                      status: status(enabled: settings.microsoftEnabled, hasKey: settings.hasMicrosoftKey),
                      isOn: $settings.microsoftEnabled)
            if AppleTranslationEngine.isSupported {
                engineRow("系统翻译", note: "macOS 15+ · 离线",
                          status: settings.appleEnabled ? .ok : .off,
                          isOn: $settings.appleEnabled)
            }
            sectionTitle("LLM 引擎").padding(.top, Theme.Spacing.s12)
            llmEngineRow("OpenCode Go", hasKey: settings.hasOpenCodeKey, isOn: $settings.openCodeEnabled)
            llmEngineRow("DeepSeek", hasKey: settings.hasDeepSeekKey, isOn: $settings.deepSeekEnabled)
            llmEngineRow("Gemini", hasKey: settings.hasGeminiKey, isOn: $settings.geminiEnabled)
            llmEngineRow("Groq", hasKey: settings.hasGroqKey, isOn: $settings.groqEnabled)
            llmEngineRow("Ollama", hasKey: true, isOn: $settings.ollamaEnabled)
            llmEngineRow("通义千问", hasKey: settings.hasQwenKey, isOn: $settings.qwenEnabled)
            llmEngineRow("豆包", hasKey: settings.hasDoubaoKey, isOn: $settings.doubaoEnabled)
            llmEngineRow("Kimi", hasKey: settings.hasKimiKey, isOn: $settings.kimiEnabled)
            llmEngineRow("智谱 GLM", hasKey: settings.hasZhipuKey, isOn: $settings.zhipuEnabled)
            llmEngineRow("硅基流动", hasKey: settings.hasSiliconFlowKey, isOn: $settings.siliconFlowEnabled)
            sectionTitle("P2 引擎").padding(.top, Theme.Spacing.s12)
            llmEngineRow("文心一言", hasKey: settings.ernieKey()?.isEmpty == false, isOn: $settings.ernieEnabled)
            llmEngineRow("混元", hasKey: settings.hunyuanKey()?.isEmpty == false, isOn: $settings.hunyuanEnabled)
            llmEngineRow("零一万物", hasKey: settings.yiKey()?.isEmpty == false, isOn: $settings.yiEnabled)
            llmEngineRow("Azure OpenAI", hasKey: settings.azureOpenAIKey()?.isEmpty == false, isOn: $settings.azureOpenAIEnabled)
            sectionTitle("P3 引擎").padding(.top, Theme.Spacing.s12)
            engineRow("火山翻译", note: nil, status: settings.volcengineEnabled ? .ok : .off, isOn: $settings.volcengineEnabled)
            engineRow("阿里翻译", note: nil, status: settings.aliyunEnabled ? .ok : .off, isOn: $settings.aliyunEnabled)
            engineRow("小牛翻译", note: nil, status: settings.niutransEnabled ? .ok : .off, isOn: $settings.niutransEnabled)
            engineRow("Amazon 翻译", note: nil, status: settings.amazonEnabled ? .ok : .off, isOn: $settings.amazonEnabled)
            sectionTitle("引擎排序").padding(.top, Theme.Spacing.s12)
            Text("拖拽调整翻译结果面板中的引擎顺序（仅影响已注册引擎）")
                .font(Theme.Font.caption).foregroundStyle(Theme.Palette.label3)
                .padding(.bottom, Theme.Spacing.s8)
            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(engineOrderDraft.enumerated()), id: \.element) { index, id in
                    HStack(spacing: Theme.Spacing.s8) {
                        Text(engineDisplayName(id))
                            .font(Theme.Font.body)
                        Spacer()
                        Button("↑") { moveEngine(from: index, to: index - 1) }
                            .disabled(index == 0)
                        Button("↓") { moveEngine(from: index, to: index + 1) }
                            .disabled(index == engineOrderDraft.count - 1)
                    }
                    .frame(minHeight: 24)
                    Divider()
                }
            }
            .frame(maxHeight: 200)
        }
    }

    private func engineDisplayName(_ id: String) -> String {
        switch id {
        case "google": return "Google 翻译"
        case "deepl": return "DeepL"
        case "openai": return "OpenAI"
        case "opencode": return "OpenCode Go"
        case "tencent": return "腾讯翻译君"
        case "baidu": return "百度翻译"
        case "youdao": return "有道翻译"
        case "caiyun": return "彩云小译"
        case "microsoft": return "Microsoft 翻译"
        case "apple": return "系统翻译"
        case "deepseek": return "DeepSeek"
        case "gemini": return "Gemini"
        case "groq": return "Groq"
        case "ollama": return "Ollama"
        case "qwen": return "通义千问"
        case "doubao": return "豆包"
        case "kimi": return "Kimi"
        case "zhipu": return "智谱 GLM"
        case "siliconflow": return "硅基流动"
        case "ernie": return "文心一言"
        case "hunyuan": return "混元"
        case "yi": return "零一万物"
        case "azure-openai": return "Azure OpenAI"
        case "volcengine": return "火山翻译"
        case "aliyun": return "阿里翻译"
        case "niutrans": return "小牛翻译"
        case "amazon": return "Amazon 翻译"
        default: return id
        }
    }

    private var ocrPane: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionTitle("文本识别")
            settingRow("默认 OCR 引擎") {
                Picker("", selection: $settings.ocrProviderId) {
                    ForEach(state.ocrCoordinator.availableProviders(), id: \.id) { p in
                        Text(p.name).tag(p.id)
                    }
                }
                .labelsHidden().frame(width: 200)
                .onChange(of: settings.ocrProviderId) { _ in state.applySettings() }
            }
            callout("离线默认可用 Apple Vision。百度/腾讯 OCR 密钥与翻译相同格式，在「密钥」页配置。")
            HStack(spacing: Theme.Spacing.s12) {
                Button("验证 OCR 配置") { validateOCR() }
                if !validateNote.isEmpty {
                    Text(validateNote).font(Theme.Font.callout).foregroundStyle(Theme.Palette.label2)
                }
                Spacer()
            }
            .padding(.top, Theme.Spacing.s12)
        }
    }

    private var ttsPane: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionTitle("语音合成")
            settingRow("默认 TTS 引擎") {
                Picker("", selection: $settings.ttsProviderId) {
                    ForEach(state.ttsCoordinator.availableProviders(), id: \.id) { p in
                        Text(p.name).tag(p.id)
                    }
                }
                .labelsHidden().frame(width: 200)
                .onChange(of: settings.ttsProviderId) { _ in state.applySettings() }
            }
            callout("默认使用系统离线语音。云端 TTS 需在「密钥」页配置对应 API Key。")
        }
    }

    private func llmEngineRow(_ name: String, hasKey: Bool, isOn: Binding<Bool>) -> some View {
        engineRow(name, note: hasKey ? nil : "未配置 Key",
                  status: status(enabled: isOn.wrappedValue, hasKey: hasKey),
                  isOn: isOn)
    }

    private var keysPane: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionTitle("API Keys")
            Text("复合密钥格式：腾讯/百度/有道为 `Id:Secret`")
                .font(Theme.Font.caption).foregroundStyle(Theme.Palette.label3)
                .padding(.bottom, Theme.Spacing.s8)
            keyRow("DeepL", $deepLKey, placeholder: "免费版以 :fx 结尾")
            keyRow("OpenAI", $openAIKey, placeholder: "sk-…")
            keyRow("OpenCode Go", $openCodeKey, placeholder: "Go API Key")
            keyRow("腾讯翻译君", $tencentCreds, placeholder: "SecretId:SecretKey")
            keyRow("百度翻译", $baiduCreds, placeholder: "AppId:Secret")
            keyRow("有道翻译", $youdaoCreds, placeholder: "AppKey:AppSecret")
            keyRow("彩云小译", $caiyunToken, placeholder: "Token")
            keyRow("Microsoft", $microsoftKey, placeholder: "订阅 Key")
            keyRow("DeepSeek", $deepSeekKey, placeholder: "API Key")
            keyRow("Gemini", $geminiKey, placeholder: "API Key")
            keyRow("Groq", $groqKey, placeholder: "API Key")
            keyRow("通义千问", $qwenKey, placeholder: "DashScope Key")
            keyRow("豆包", $doubaoKey, placeholder: "方舟 API Key")
            keyRow("Kimi", $kimiKey, placeholder: "Moonshot Key")
            keyRow("智谱 GLM", $zhipuKey, placeholder: "API Key")
            keyRow("硅基流动", $siliconFlowKey, placeholder: "API Key")
            sectionTitle("LLM 高级").padding(.top, Theme.Spacing.s12)
            settingRow("OpenAI Model") { TextField("gpt-4o-mini", text: $openAIModelField).frame(width: 230) }
            settingRow("OpenAI Endpoint") { TextField("可选", text: $openAIEndpointField).frame(width: 230) }
            settingRow("OpenCode Go Model") { TextField("glm-5.1", text: $openCodeModelField).frame(width: 230) }
            settingRow("Ollama Model") { TextField("llama3.2", text: $ollamaModelField).frame(width: 230) }
            settingRow("Ollama Endpoint") { TextField("http://127.0.0.1:11434/v1/chat/completions", text: $ollamaEndpointField).frame(width: 230) }
            settingRow("Azure Endpoint") { TextField("Azure deployment URL", text: $azureEndpointField).frame(width: 230) }
            VStack(alignment: .leading, spacing: Theme.Spacing.s8) {
                HStack(spacing: Theme.Spacing.s12) {
                    Button("保存到钥匙串") { saveKeys() }
                    if !savedNote.isEmpty {
                        Text(savedNote).font(Theme.Font.callout).foregroundStyle(Theme.Palette.success)
                    }
                    Spacer()
                }
                HStack(spacing: Theme.Spacing.s12) {
                    Button("验证 OpenAI") { validateEngine("openai") }
                    Button("验证 OpenCode") { validateEngine("opencode") }
                    Button("验证 DeepSeek") { validateEngine("deepseek") }
                    Button("验证智谱") { validateEngine("zhipu") }
                    if !validateNote.isEmpty {
                        Text(validateNote).font(Theme.Font.callout).foregroundStyle(Theme.Palette.label2)
                    }
                    Spacer()
                }
            }
            .padding(.top, Theme.Spacing.s12)
            callout("🔒 API Key 存储于 macOS 钥匙串。申请教程见 docs/bob-service-matrix.md")
        }
        .onAppear { loadKeysIfNeeded() }
    }

    private func keyRow(_ label: String, _ text: Binding<String>, placeholder: String) -> some View {
        settingRow(label) {
            SecureField(placeholder, text: text).frame(width: 230)
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
        let trim: (String) -> String = { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        saveSecret(AppSettings.deepLAccount, value: trim(deepLKey), setter: settings.setDeepLKey)
        saveSecret(AppSettings.openAIAccount, value: trim(openAIKey), setter: settings.setOpenAIKey)
        saveSecret(AppSettings.openCodeAccount, value: trim(openCodeKey), setter: settings.setOpenCodeKey)
        saveSecret(AppSettings.tencentAccount, value: trim(tencentCreds), setter: settings.setTencentCredentials)
        saveSecret(AppSettings.baiduAccount, value: trim(baiduCreds), setter: settings.setBaiduCredentials)
        saveSecret(AppSettings.youdaoAccount, value: trim(youdaoCreds), setter: settings.setYoudaoCredentials)
        saveSecret(AppSettings.caiyunAccount, value: trim(caiyunToken), setter: settings.setCaiyunToken)
        saveSecret(AppSettings.microsoftAccount, value: trim(microsoftKey), setter: settings.setMicrosoftKey)
        saveSecret(AppSettings.deepSeekAccount, value: trim(deepSeekKey), setter: settings.setDeepSeekKey)
        saveSecret(AppSettings.geminiAccount, value: trim(geminiKey), setter: settings.setGeminiKey)
        saveSecret(AppSettings.groqAccount, value: trim(groqKey), setter: settings.setGroqKey)
        saveSecret(AppSettings.qwenAccount, value: trim(qwenKey), setter: settings.setQwenKey)
        saveSecret(AppSettings.doubaoAccount, value: trim(doubaoKey), setter: settings.setDoubaoKey)
        saveSecret(AppSettings.kimiAccount, value: trim(kimiKey), setter: settings.setKimiKey)
        saveSecret(AppSettings.zhipuAccount, value: trim(zhipuKey), setter: settings.setZhipuKey)
        saveSecret(AppSettings.siliconFlowAccount, value: trim(siliconFlowKey), setter: settings.setSiliconFlowKey)
        settings.openAIModel = trim(openAIModelField)
        settings.openAIEndpoint = trim(openAIEndpointField)
        settings.setModel(trim(openCodeModelField), for: "opencode")
        settings.setModel(trim(ollamaModelField), for: "ollama")
        settings.ollamaEndpoint = trim(ollamaEndpointField)
        settings.setEndpoint(trim(azureEndpointField), for: "azure-openai")
        state.applySettings()
        savedNote = "已保存 ✓"
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { savedNote = "" }
    }

    private func loadKeysIfNeeded() {
        guard !keysLoaded else { return }
        deepLKey = loadSecret(AppSettings.deepLAccount, settings.deepLKey(allowPrompt: true))
        openAIKey = loadSecret(AppSettings.openAIAccount, settings.openAIKey(allowPrompt: true))
        openCodeKey = loadSecret(AppSettings.openCodeAccount, settings.openCodeKey(allowPrompt: true))
        tencentCreds = loadSecret(AppSettings.tencentAccount, settings.tencentCredentials(allowPrompt: true))
        baiduCreds = loadSecret(AppSettings.baiduAccount, settings.baiduCredentials(allowPrompt: true))
        youdaoCreds = loadSecret(AppSettings.youdaoAccount, settings.youdaoCredentials(allowPrompt: true))
        caiyunToken = loadSecret(AppSettings.caiyunAccount, settings.caiyunToken(allowPrompt: true))
        microsoftKey = loadSecret(AppSettings.microsoftAccount, settings.microsoftKey(allowPrompt: true))
        deepSeekKey = loadSecret(AppSettings.deepSeekAccount, settings.deepSeekKey(allowPrompt: true))
        geminiKey = loadSecret(AppSettings.geminiAccount, settings.geminiKey(allowPrompt: true))
        groqKey = loadSecret(AppSettings.groqAccount, settings.groqKey(allowPrompt: true))
        qwenKey = loadSecret(AppSettings.qwenAccount, settings.qwenKey(allowPrompt: true))
        doubaoKey = loadSecret(AppSettings.doubaoAccount, settings.doubaoKey(allowPrompt: true))
        kimiKey = loadSecret(AppSettings.kimiAccount, settings.kimiKey(allowPrompt: true))
        zhipuKey = loadSecret(AppSettings.zhipuAccount, settings.zhipuKey(allowPrompt: true))
        siliconFlowKey = loadSecret(AppSettings.siliconFlowAccount, settings.siliconFlowKey(allowPrompt: true))
        keysLoaded = true
    }

    private func loadSecret(_ account: String, _ value: String?) -> String {
        guard let value, !value.isEmpty else { return "" }
        loadedSecretAccounts.insert(account)
        return value
    }

    private func saveSecret(_ account: String, value: String, setter: (String) -> Void) {
        guard !value.isEmpty || loadedSecretAccounts.contains(account) else { return }
        setter(value)
        if value.isEmpty {
            loadedSecretAccounts.remove(account)
        } else {
            loadedSecretAccounts.insert(account)
        }
    }

    private func moveEngine(from: Int, to: Int) {
        guard to >= 0, to < engineOrderDraft.count, from != to else { return }
        engineOrderDraft.move(fromOffsets: IndexSet(integer: from), toOffset: to > from ? to + 1 : to)
        settings.setEngineOrder(engineOrderDraft)
        state.applySettings()
    }

    private func validateEngine(_ id: String) {
        saveKeys()
        Task {
            let ok = await settings.validateKey(for: id)
            validateNote = ok ? "验证通过 ✓" : "验证失败"
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) { validateNote = "" }
        }
    }

    private func validateOCR() {
        let id = settings.ocrProviderId
        if id == "apple-vision" {
            validateNote = "离线 OCR 无需 Key ✓"
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) { validateNote = "" }
            return
        }
        let configured: Bool = switch id {
        case "baidu-ocr": settings.baiduOCRCredentials()?.isEmpty == false
        case "tencent-ocr", "tencent-image-translate": settings.tencentOCRCredentials()?.isEmpty == false
        case "google-ocr": settings.googleOCRKey()?.isEmpty == false
        case "youdao-ocr": settings.youdaoOCRCredentials()?.isEmpty == false
        case "volcengine-ocr": settings.volcengineOCRKey()?.isEmpty == false
        default: false
        }
        validateNote = configured ? "OCR 密钥已配置 ✓" : "OCR 密钥未配置"
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { validateNote = "" }
    }
}
