import AppKit
import SwiftUI
import Carbon.HIToolbox
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

    func show(pane: SettingsView.Pane = .general) {
        if window == nil {
            let hosting = NSHostingController(rootView: SettingsView(state: state, initialPane: pane))
            let win = NSWindow(contentViewController: hosting)
            win.title = "Parrot 设置"
            win.styleMask = [.titled, .closable, .miniaturizable, .resizable]
            win.isReleasedWhenClosed = false
            win.contentMinSize = NSSize(width: 640, height: 420)
            win.setContentSize(NSSize(width: 720, height: 500))
            window = win
        } else {
            window?.contentViewController = NSHostingController(rootView: SettingsView(state: state, initialPane: pane))
        }
        NSApp.activate(ignoringOtherApps: true)
        if let window {
            WindowPlacement.center(window)
        }
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
    @State private var secretDrafts: [String: String] = [:]
    @State private var modelDrafts: [String: String] = [:]
    @State private var endpointDrafts: [String: String] = [:]
    @State private var validateNote: String = ""
    @State private var savedNote: String = ""
    @State private var engineOrderDraft: [String] = []
    @State private var showMachineEngines = true
    @State private var showLLMEngines = true
    @State private var showMoreEngines = true
    @State private var showEngineOrder = true
    @State private var showMachineKeys = false
    @State private var showLLMKeys = false
    @State private var showAdvancedKeys = false
    @State private var recordingShortcut: ShortcutAction?
    @State private var shortcutMonitor: Any?

    private let languages: [(String, String)] = [
        ("zh", "中文"), ("en", "English"), ("ja", "日本語"), ("ko", "한국어"),
        ("fr", "Français"), ("de", "Deutsch"), ("es", "Español"), ("ru", "Русский"),
    ]

    init(state: AppState, initialPane: Pane = .general) {
        self.state = state
        self.settings = state.settings
        _selection = State(initialValue: initialPane)
    }

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            Divider()
            ScrollView {
                content
                    .padding(.horizontal, 22)
                    .padding(.vertical, 20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .id(selection)
                    .transition(.opacity)
            }
            .background(Theme.Palette.bgCanvas)
            .animation(.easeInOut(duration: 0.15), value: selection)
        }
        .frame(minWidth: 640, minHeight: 420)
        .onAppear {
            state.refreshPermissions()
            loadAdvancedDrafts()
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
        .padding(.horizontal, Theme.Spacing.s8)
        .padding(.vertical, 10)
        .frame(width: 184)
        .background(Theme.Palette.bgSidebar)
    }

    private func sidebarRow(_ pane: Pane) -> some View {
        let selected = selection == pane
        return Button {
            selection = pane
        } label: {
            HStack(spacing: 9) {
                Image(systemName: pane.icon).frame(width: 16)
                Text(pane.title)
                Spacer()
            }
            .padding(.horizontal, 10)
            .frame(minHeight: 32)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .font(Theme.Font.body)
        .foregroundStyle(selected ? Theme.Palette.label : Theme.Palette.label)
        .background(selected ? Theme.Palette.bgSelection : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .contentShape(Rectangle())
        .accessibilityLabel(pane.title)
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
            permissionGroup
            formGroup {
                settingRow("默认来源语言") {
                    Picker("", selection: $settings.sourceLanguageCode) {
                        Text("自动").tag("auto")
                        ForEach(languages, id: \.0) { code, name in Text(name).tag(code) }
                    }
                    .labelsHidden()
                    .frame(width: 140)
                    .onChange(of: settings.sourceLanguageCode) { _ in state.applySettings() }
                }
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
    }

    private var enginesPane: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionTitle("翻译引擎")
            subsectionTitle("已开启")
            engineOptionsGroup(enabledEngineOptions, emptyText: "还没有开启任何翻译引擎")

            subsectionTitle("基础服务")
            engineOptionsGroup(disabledEngineOptions(in: .base), emptyText: "基础服务都已开启")

            disclosureSection("国内与云厂商", isExpanded: $showMachineEngines) {
                engineOptionsGroup(disabledEngineOptions(in: .machine), emptyText: "国内与云厂商引擎都已开启")
            }

            disclosureSection("LLM 服务", isExpanded: $showLLMEngines) {
                engineOptionsGroup(disabledEngineOptions(in: .llm), emptyText: "LLM 服务都已开启")
            }

            disclosureSection("更多服务", isExpanded: $showMoreEngines) {
                engineOptionsGroup(disabledEngineOptions(in: .more), emptyText: "更多服务都已开启")
            }

            disclosureSection("结果顺序", isExpanded: $showEngineOrder) {
                formGroup {
                    VStack(alignment: .leading, spacing: 0) {
                        Text("用箭头调整翻译结果面板中的已启用引擎顺序")
                            .font(Theme.Font.caption)
                            .foregroundStyle(Theme.Palette.label3)
                            .padding(.horizontal, Theme.Spacing.s12)
                            .padding(.vertical, 9)
                        Divider()
                        ForEach(Array(orderableEngineIDs.enumerated()), id: \.element) { index, id in
                            HStack(spacing: Theme.Spacing.s8) {
                                Text(engineDisplayName(id))
                                    .font(Theme.Font.body)
                                    .foregroundStyle(Theme.Palette.label)
                                Spacer()
                                Button("↑") { moveEnabledEngine(from: index, to: index - 1) }
                                    .disabled(index == 0)
                                Button("↓") { moveEnabledEngine(from: index, to: index + 1) }
                                    .disabled(index == orderableEngineIDs.count - 1)
                            }
                            .padding(.horizontal, Theme.Spacing.s12)
                            .frame(minHeight: 32)
                            if index != orderableEngineIDs.count - 1 {
                                Divider()
                                    .padding(.leading, Theme.Spacing.s12)
                            }
                        }
                    }
                    .frame(maxHeight: 220)
                }
            }
        }
    }

    private var enabledEngineOptions: [EngineDescriptor] {
        EngineCatalog.orderedDescriptors(settings: settings)
            .filter { settings.isEngineEnabled($0.id) }
    }

    private var orderableEngineIDs: [String] {
        engineOrderDraft.filter { settings.isEngineEnabled($0) }
    }

    private func disabledEngineOptions(in category: EngineCategory) -> [EngineDescriptor] {
        EngineCatalog.orderedDescriptors(settings: settings)
            .filter { $0.category == category && !settings.isEngineEnabled($0.id) }
    }

    private func binding(forEngine id: String) -> Binding<Bool> {
        Binding(
            get: { settings.isEngineEnabled(id) },
            set: { newValue in
                settings.setEngineEnabled(id, newValue)
                state.applySettings()
            }
        )
    }

    private func engineDisplayName(_ id: String) -> String {
        EngineCatalog.descriptor(for: id)?.name ?? id
    }

    private var ocrPane: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionTitle("文本识别")
            formGroup {
                settingRow("默认 OCR 引擎") {
                    Picker("", selection: $settings.ocrProviderId) {
                        ForEach(state.ocrCoordinator.availableProviders(), id: \.id) { p in
                            Text(p.name).tag(p.id)
                        }
                    }
                    .labelsHidden().frame(width: 200)
                    .onChange(of: settings.ocrProviderId) { _ in state.applySettings() }
                }
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
            formGroup {
                settingRow("默认 TTS 引擎") {
                    Picker("", selection: $settings.ttsProviderId) {
                        ForEach(state.ttsCoordinator.availableProviders(), id: \.id) { p in
                            Text(p.name).tag(p.id)
                        }
                    }
                    .labelsHidden().frame(width: 200)
                    .onChange(of: settings.ttsProviderId) { _ in state.applySettings() }
                }
            }
            callout("默认使用系统离线语音。云端 TTS 需在「密钥」页配置对应 API Key。")
        }
    }

    private func engineOptionsGroup(_ options: [EngineDescriptor], emptyText: String) -> some View {
        formGroup {
            if options.isEmpty {
                emptyEngineRow(emptyText)
            } else {
                ForEach(options) { descriptor in
                    engineOptionRow(descriptor)
                }
            }
        }
    }

    private func engineOptionRow(_ descriptor: EngineDescriptor) -> some View {
        engineRow(
            descriptor.name,
            note: settings.engineStatusText(descriptor),
            status: status(descriptor),
            isOn: binding(forEngine: descriptor.id)
        )
    }

    private func emptyEngineRow(_ text: String) -> some View {
        HStack {
            Text(text)
                .font(Theme.Font.callout)
                .foregroundStyle(Theme.Palette.label3)
            Spacer()
        }
        .padding(.horizontal, Theme.Spacing.s12)
        .frame(minHeight: 40)
    }

    private var keysPane: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionTitle("密钥")
            Text("密钥只保存在本机。需要双字段凭证的服务使用 Id:Secret 格式。")
                .font(Theme.Font.callout)
                .foregroundStyle(Theme.Palette.label2)
                .padding(.bottom, Theme.Spacing.s12)

            subsectionTitle("常用")
            formGroup {
                ForEach(commonKeyDescriptors) { descriptor in
                    secretRow(descriptor)
                }
            }

            disclosureSection("国内与云厂商", isExpanded: $showMachineKeys) {
                formGroup {
                    ForEach(keyDescriptors(in: .machine)) { descriptor in
                        secretRow(descriptor)
                    }
                }
            }

            disclosureSection("LLM Keys", isExpanded: $showLLMKeys) {
                formGroup {
                    ForEach(keyDescriptors(in: .llm).filter { !commonKeyIDs.contains($0.id) }) { descriptor in
                        secretRow(descriptor)
                    }
                }
            }

            disclosureSection("更多服务", isExpanded: $showMoreEngines) {
                formGroup {
                    ForEach(keyDescriptors(in: .more)) { descriptor in
                        secretRow(descriptor)
                    }
                }
            }

            disclosureSection("高级模型与端点", isExpanded: $showAdvancedKeys) {
                formGroup {
                    ForEach(modelDescriptors) { descriptor in
                        settingRow("\(descriptor.name) Model") {
                            compactTextField(descriptor.defaultModel ?? "model", text: modelBinding(for: descriptor))
                        }
                    }
                    ForEach(endpointDescriptors) { descriptor in
                        settingRow("\(descriptor.name) Endpoint") {
                            compactTextField(endpointPlaceholder(for: descriptor), text: endpointBinding(for: descriptor))
                        }
                    }
                }
            }

            keyActionBar
            keyFootnote
        }
    }

    private var keyActionBar: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s8) {
            HStack(spacing: Theme.Spacing.s8) {
                Button("保存到本机") { saveKeys() }
                    .controlSize(.small)
                Button("验证 OpenAI") { validateEngine("openai") }
                    .controlSize(.small)
                Button("验证 OpenCode") { validateEngine("opencode") }
                    .controlSize(.small)
                Button("验证 DeepSeek") { validateEngine("deepseek") }
                    .controlSize(.small)
                Button("验证智谱") { validateEngine("zhipu") }
                    .controlSize(.small)
                Spacer(minLength: 0)
            }
            if !savedNote.isEmpty || !validateNote.isEmpty {
                Text(savedNote.isEmpty ? validateNote : savedNote)
                    .font(Theme.Font.caption)
                    .foregroundStyle(savedNote.isEmpty ? Theme.Palette.label2 : Theme.Palette.success)
            }
        }
        .padding(Theme.Spacing.s12)
        .background(Theme.Palette.bgContent)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.group))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.group).strokeBorder(Theme.Palette.hairline, lineWidth: 0.5))
        .padding(.top, Theme.Spacing.s12)
    }

    private var keyFootnote: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.s8) {
            Image(systemName: "info.circle")
                .font(.system(size: 12))
                .foregroundStyle(Theme.Palette.label3)
            Text("存储路径：~/Library/Application Support/Parrot/secrets.json。文件权限限制为当前用户可读写；环境变量优先于本地配置。")
                .font(Theme.Font.caption)
                .foregroundStyle(Theme.Palette.label2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, Theme.Spacing.s8)
    }

    private func compactTextField(_ placeholder: String, text: Binding<String>) -> some View {
        TextField(placeholder, text: text)
            .textFieldStyle(.roundedBorder)
            .font(Theme.Font.callout)
            .frame(width: 280)
    }

    private func secretRow(_ descriptor: EngineDescriptor) -> some View {
        guard let credential = descriptor.credential else { return AnyView(EmptyView()) }
        let status = settings.secretStatus(account: credential.account, env: credential.env)
        let fromEnv = status.hasPrefix("环境变量")
        let configured = status != "未配置"
        return AnyView(VStack(spacing: 0) {
            HStack(alignment: .center, spacing: Theme.Spacing.s12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(descriptor.name)
                        .font(Theme.Font.body)
                        .foregroundStyle(Theme.Palette.label)
                    Text(status)
                        .font(Theme.Font.caption)
                        .foregroundStyle(configured ? Theme.Palette.label2 : Theme.Palette.label3)
                        .lineLimit(1)
                }
                Spacer(minLength: Theme.Spacing.s12)
                SecureField(fromEnv ? "环境变量优先" : (configured ? "输入新值以替换" : credential.placeholder),
                            text: secretBinding(for: credential.account))
                    .textFieldStyle(.roundedBorder)
                    .font(Theme.Font.callout)
                    .frame(width: 280)
                    .disabled(fromEnv)
                Button("清除") { clearSecret(credential.account) }
                    .controlSize(.small)
                    .disabled(!settings.hasStoredSecret(account: credential.account))
            }
            .padding(.horizontal, Theme.Spacing.s12)
            .padding(.vertical, 8)
            .frame(minHeight: 52)
            Divider()
        }
        .background(Color.clear))
    }

    private var shortcutsPane: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionTitle("全局快捷键")
            Text(recordingShortcut == nil ? "点击录制后按下新的组合键。至少包含一个修饰键。" : "正在录制 \(recordingShortcut?.title ?? "")，按 Esc 取消。")
                .font(Theme.Font.callout)
                .foregroundStyle(recordingShortcut == nil ? Theme.Palette.label2 : Theme.Palette.accent)
                .padding(.bottom, Theme.Spacing.s12)
            formGroup {
                ForEach(ShortcutAction.allCases) { action in
                    shortcutRow(action)
                }
            }
            HStack(spacing: Theme.Spacing.s8) {
                Button("恢复默认快捷键") {
                    stopShortcutRecording()
                    settings.resetShortcuts()
                    savedNote = "已恢复默认快捷键"
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) { savedNote = "" }
                }
                .controlSize(.small)
                if !savedNote.isEmpty || !validateNote.isEmpty {
                    Text(savedNote.isEmpty ? validateNote : savedNote)
                        .font(Theme.Font.caption)
                        .foregroundStyle(savedNote.isEmpty ? Theme.Palette.label2 : Theme.Palette.success)
                }
                Spacer()
            }
            .padding(.top, Theme.Spacing.s8)
        }
        .onDisappear { stopShortcutRecording() }
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
            formGroup {
                settingRow("Bundle ID") {
                    Text(bundleIdentifier)
                        .font(Theme.Font.caption)
                        .foregroundStyle(Theme.Palette.label2)
                        .lineLimit(1)
                }
                settingRow("运行路径") {
                    Text(appPath)
                        .font(Theme.Font.caption)
                        .foregroundStyle(Theme.Palette.label2)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .frame(maxWidth: 360, alignment: .trailing)
                }
                settingRow("运行实例") {
                    Text(sameBundleInstanceSummary)
                        .font(Theme.Font.caption)
                        .foregroundStyle(hasSameBundleConflict ? Theme.Palette.warning : Theme.Palette.label2)
                        .lineLimit(1)
                }
            }
            .padding(.top, Theme.Spacing.s8)
            Link("GitHub 仓库", destination: URL(string: "https://github.com/korbinjoe/parrot")!)
                .font(Theme.Font.callout)
        }
    }

    private var permissionGroup: some View {
        formGroup {
            permissionRow(
                "辅助功能",
                granted: state.permissions.accessibilityGranted,
                detail: "划词翻译、查词和快捷键捕获需要此权限。",
                actionTitle: "打开设置",
                action: AppPermissions.openAccessibilitySettings
            )
            permissionRow(
                "屏幕录制",
                granted: state.permissions.screenRecordingGranted,
                detail: "截图翻译需要此权限。",
                actionTitle: "打开设置",
                action: AppPermissions.openScreenRecordingSettings
            )
        }
    }

    // MARK: - Row builders

    private func sectionTitle(_ t: String) -> some View {
        Text(t).font(.system(size: 17, weight: .semibold))
            .foregroundStyle(Theme.Palette.label)
            .padding(.bottom, Theme.Spacing.s12)
    }

    private func subsectionTitle(_ t: String) -> some View {
        Text(t)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(Theme.Palette.label2)
            .padding(.bottom, Theme.Spacing.s4)
    }

    private func disclosureSection<Content: View>(
        _ title: String,
        isExpanded: Binding<Bool>,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        DisclosureGroup(isExpanded: isExpanded) {
            VStack(alignment: .leading, spacing: 0) {
                content()
            }
            .padding(.top, Theme.Spacing.s8)
        } label: {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.Palette.label)
        }
        .padding(.top, Theme.Spacing.s12)
    }

    private func settingRow<Control: View>(_ label: String, @ViewBuilder control: () -> Control) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text(label).font(Theme.Font.body).foregroundStyle(Theme.Palette.label)
                Spacer()
                control()
            }
            .padding(.horizontal, Theme.Spacing.s12)
            .padding(.vertical, 7)
            .frame(minHeight: 38)
            Divider()
        }
        .background(Color.clear)
    }

    private func permissionRow(
        _ name: String,
        granted: Bool,
        detail: String,
        actionTitle: String,
        action: @escaping () -> Void
    ) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: Theme.Spacing.s12) {
                Circle()
                    .fill(granted ? Theme.Palette.success : Theme.Palette.warning)
                    .frame(width: 8, height: 8)
                VStack(alignment: .leading, spacing: 2) {
                    Text(name)
                        .font(Theme.Font.body)
                        .foregroundStyle(Theme.Palette.label)
                    Text(granted ? "已开启" : detail)
                        .font(Theme.Font.caption)
                        .foregroundStyle(granted ? Theme.Palette.label2 : Theme.Palette.label3)
                        .lineLimit(1)
                }
                Spacer()
                if granted {
                    Text("可用")
                        .font(Theme.Font.caption)
                        .foregroundStyle(Theme.Palette.success)
                } else {
                    Button(actionTitle) { action() }
                        .controlSize(.small)
                }
            }
            .padding(.horizontal, Theme.Spacing.s12)
            .padding(.vertical, 8)
            .frame(minHeight: 44)
            Divider()
        }
        .background(Color.clear)
    }

    private func engineRow(_ name: String, note: String?, status: EngineStatus, isOn: Binding<Bool>) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: Theme.Spacing.s8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(name)
                        .font(Theme.Font.body)
                        .foregroundStyle(Theme.Palette.label)
                    if let note {
                        Text(note)
                            .font(Theme.Font.caption)
                            .foregroundStyle(Theme.Palette.label3)
                            .lineLimit(1)
                    }
                }
                Spacer()
                Circle().fill(status.color).frame(width: 7, height: 7)
                Toggle("", isOn: isOn).labelsHidden().toggleStyle(.switch).controlSize(.small)
                    .onChange(of: isOn.wrappedValue) { _ in state.applySettings() }
            }
            .padding(.horizontal, Theme.Spacing.s12)
            .padding(.vertical, 8)
            .frame(minHeight: 44)
            Divider()
        }
        .background(Color.clear)
    }

    private func shortcutRow(_ action: ShortcutAction) -> some View {
        let isRecording = recordingShortcut == action
        let key = settings.shortcutSpec(for: action).displayText
        return VStack(spacing: 0) {
            HStack {
                Text(action.title).font(Theme.Font.body).foregroundStyle(Theme.Palette.label)
                Spacer()
                Button(isRecording ? "按键中…" : key) {
                    beginShortcutRecording(action)
                }
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(isRecording ? Theme.Palette.accent : Theme.Palette.label)
                .padding(.horizontal, 9).padding(.vertical, 3)
                .background(isRecording ? Theme.Palette.bgSelection : Theme.Palette.bgControl)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(isRecording ? Theme.Palette.accent : Theme.Palette.separator, lineWidth: 0.5))
                .buttonStyle(.plain)
            }
            .padding(.horizontal, Theme.Spacing.s12)
            .padding(.vertical, 7)
            .frame(minHeight: 38)
            Divider()
        }
        .background(Color.clear)
    }

    private func callout(_ text: String) -> some View {
        Text(text)
            .font(Theme.Font.callout).foregroundStyle(Theme.Palette.label2)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Theme.Spacing.s12)
            .background(Theme.Palette.bgContent)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.group))
            .overlay(RoundedRectangle(cornerRadius: Theme.Radius.group).strokeBorder(Theme.Palette.hairline, lineWidth: 0.5))
            .padding(.top, Theme.Spacing.s12)
    }

    private func formGroup<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(spacing: 0) {
            content()
        }
        .background(Theme.Palette.bgContent)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.group))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.group).strokeBorder(Theme.Palette.hairline, lineWidth: 0.5))
        .padding(.bottom, Theme.Spacing.s16)
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

    private func status(_ descriptor: EngineDescriptor) -> EngineStatus {
        if !settings.isEngineEnabled(descriptor.id) { return .off }
        return settings.isEngineConfigured(descriptor) ? .ok : .warn
    }

    private func beginShortcutRecording(_ action: ShortcutAction) {
        stopShortcutRecording(removeAction: false)
        recordingShortcut = action
        validateNote = ""
        shortcutMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            handleShortcutEvent(event)
            return nil
        }
    }

    private func stopShortcutRecording(removeAction: Bool = true) {
        if let shortcutMonitor {
            NSEvent.removeMonitor(shortcutMonitor)
            self.shortcutMonitor = nil
        }
        if removeAction { recordingShortcut = nil }
    }

    private func handleShortcutEvent(_ event: NSEvent) {
        guard let action = recordingShortcut else { return }
        if Int(event.keyCode) == kVK_Escape {
            stopShortcutRecording()
            return
        }
        guard let spec = HotKeySpec.from(event: event) else {
            validateNote = "请至少包含一个修饰键"
            return
        }
        if let conflict = ShortcutAction.allCases.first(where: { $0 != action && settings.shortcutSpec(for: $0) == spec }) {
            validateNote = "快捷键已被「\(conflict.title)」使用"
            return
        }
        settings.setShortcutSpec(spec, for: action)
        stopShortcutRecording()
        savedNote = "已设置 \(action.title)：\(spec.displayText)"
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { savedNote = "" }
    }

    private var commonKeyIDs: Set<String> { ["deepl", "openai", "opencode"] }

    private var commonKeyDescriptors: [EngineDescriptor] {
        EngineCatalog.all.filter { commonKeyIDs.contains($0.id) }
    }

    private func keyDescriptors(in category: EngineCategory) -> [EngineDescriptor] {
        EngineCatalog.all.filter { $0.category == category && $0.credential != nil }
    }

    private var modelDescriptors: [EngineDescriptor] {
        EngineCatalog.all.filter { $0.defaultModel != nil }
    }

    private var endpointDescriptors: [EngineDescriptor] {
        EngineCatalog.all.filter { $0.defaultEndpoint != nil }
    }

    private func secretBinding(for account: String) -> Binding<String> {
        Binding(
            get: { secretDrafts[account] ?? "" },
            set: { secretDrafts[account] = $0 }
        )
    }

    private func modelBinding(for descriptor: EngineDescriptor) -> Binding<String> {
        Binding(
            get: { modelDrafts[descriptor.id] ?? descriptor.defaultModel ?? "" },
            set: { modelDrafts[descriptor.id] = $0 }
        )
    }

    private func endpointBinding(for descriptor: EngineDescriptor) -> Binding<String> {
        Binding(
            get: { endpointDrafts[descriptor.id] ?? currentEndpoint(for: descriptor) },
            set: { endpointDrafts[descriptor.id] = $0 }
        )
    }

    private func endpointPlaceholder(for descriptor: EngineDescriptor) -> String {
        switch descriptor.id {
        case "openai": return "可选"
        case "azure-openai": return "Azure deployment URL"
        default: return descriptor.defaultEndpoint ?? "Endpoint"
        }
    }

    private func loadAdvancedDrafts() {
        modelDrafts = Dictionary(uniqueKeysWithValues: modelDescriptors.map { ($0.id, currentModel(for: $0)) })
        endpointDrafts = Dictionary(uniqueKeysWithValues: endpointDescriptors.map { ($0.id, currentEndpoint(for: $0)) })
    }

    private func currentModel(for descriptor: EngineDescriptor) -> String {
        if descriptor.id == "openai" { return settings.openAIModel }
        return settings.model(for: descriptor.id) ?? descriptor.defaultModel ?? ""
    }

    private func currentEndpoint(for descriptor: EngineDescriptor) -> String {
        if descriptor.id == "openai" { return settings.openAIEndpoint }
        if descriptor.id == "ollama" { return settings.ollamaEndpoint }
        return settings.endpoint(for: descriptor.id) ?? ""
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.1.0"
    }

    private var bundleIdentifier: String {
        Bundle.main.bundleIdentifier ?? "unknown"
    }

    private var appPath: String {
        Bundle.main.bundleURL.path
    }

    private var sameBundleInstanceSummary: String {
        let apps = runningSameBundleApps
        if apps.count <= 1 { return "仅当前实例" }
        return "\(apps.count) 个实例，URL Scheme 可能路由到旧版本"
    }

    private var hasSameBundleConflict: Bool {
        runningSameBundleApps.count > 1
    }

    private var runningSameBundleApps: [NSRunningApplication] {
        guard let bundleIdentifier = Bundle.main.bundleIdentifier else { return [] }
        return NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier)
            .filter { !$0.isTerminated }
    }

    private func openPluginsFolder() {
        let url = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/Parrot/Plugins")
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        NSWorkspace.shared.open(url)
    }

    private func saveKeys() {
        let trim: (String) -> String = { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        for descriptor in EngineCatalog.all {
            if let credential = descriptor.credential {
                saveSecret(trim(secretDrafts[credential.account] ?? ""), account: credential.account)
            }
            if descriptor.defaultModel != nil {
                saveModel(trim(modelDrafts[descriptor.id] ?? ""), for: descriptor)
            }
            if descriptor.defaultEndpoint != nil {
                saveEndpoint(trim(endpointDrafts[descriptor.id] ?? ""), for: descriptor)
            }
        }
        clearKeyFields()
        state.applySettings()
        savedNote = "已保存到本地 ✓"
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { savedNote = "" }
    }

    private func saveSecret(_ value: String, account: String) {
        guard !value.isEmpty else { return }
        settings.setKey(value, account: account)
    }

    private func saveModel(_ value: String, for descriptor: EngineDescriptor) {
        guard !value.isEmpty else { return }
        if descriptor.id == "openai" {
            settings.openAIModel = value
        } else {
            settings.setModel(value, for: descriptor.id)
        }
    }

    private func saveEndpoint(_ value: String, for descriptor: EngineDescriptor) {
        if descriptor.id == "openai" {
            settings.openAIEndpoint = value
        } else if descriptor.id == "ollama" {
            settings.ollamaEndpoint = value
        } else {
            settings.setEndpoint(value, for: descriptor.id)
        }
    }

    private func clearSecret(_ account: String) {
        guard confirm(title: "清除这项密钥？", message: "清除后，对应服务会在下次翻译时显示为需配置。") else { return }
        settings.removeKey(account: account)
        secretDrafts[account] = ""
        state.applySettings()
        savedNote = "已清除 ✓"
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { savedNote = "" }
    }

    private func confirm(title: String, message: String) -> Bool {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "继续")
        alert.addButton(withTitle: "取消")
        return alert.runModal() == .alertFirstButtonReturn
    }

    private func clearKeyFields() {
        secretDrafts = [:]
    }

    private func moveEnabledEngine(from: Int, to: Int) {
        var enabled = orderableEngineIDs
        guard to >= 0, to < enabled.count, from != to else { return }
        enabled.move(fromOffsets: IndexSet(integer: from), toOffset: to > from ? to + 1 : to)
        let disabled = engineOrderDraft.filter { !settings.isEngineEnabled($0) }
        engineOrderDraft = enabled + disabled
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
