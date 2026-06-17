import AppKit
import SwiftUI
import Carbon.HIToolbox
import ParrotCore
import ParrotEngines

/// Hosts the SwiftUI settings UI in a standard titled window (separate from the floating panel).
@MainActor
final class SettingsWindow {
    private let state: AppState
    private let onRetryProvider: (String) -> Void
    private var window: NSWindow?

    init(state: AppState, onRetryProvider: @escaping (String) -> Void = { _ in }) {
        self.state = state
        self.onRetryProvider = onRetryProvider
    }

    func show(
        pane: SettingsView.Pane = .general,
        focusServiceID: String? = nil,
        retryProviderID: String? = nil
    ) {
        if window == nil {
            let hosting = NSHostingController(rootView: SettingsView(
                state: state,
                initialPane: pane,
                focusedServiceID: focusServiceID,
                retryProviderID: retryProviderID,
                onRetryProvider: onRetryProvider
            ))
            let win = NSWindow(contentViewController: hosting)
            win.title = L("Parrot 设置")
            win.styleMask = [.titled, .closable, .miniaturizable, .resizable]
            win.isReleasedWhenClosed = false
            win.contentMinSize = NSSize(width: 640, height: 420)
            win.setContentSize(NSSize(width: 720, height: 500))
            window = win
        } else {
            window?.contentViewController = NSHostingController(rootView: SettingsView(
                state: state,
                initialPane: pane,
                focusedServiceID: focusServiceID,
                retryProviderID: retryProviderID,
                onRetryProvider: onRetryProvider
            ))
        }
        NSApp.activate(ignoringOtherApps: true)
        if let window {
            WindowPlacement.center(window)
        }
        window?.makeKeyAndOrderFront(nil)
    }
}

private struct SettingsMiniButtonStyle: ButtonStyle {
    enum Prominence {
        case normal
        case accent
    }

    @Environment(\.isEnabled) private var isEnabled
    let prominence: Prominence

    init(prominence: Prominence = .normal) {
        self.prominence = prominence
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.Font.caption)
            .foregroundStyle(foregroundColor)
            .padding(.horizontal, 9)
            .frame(height: 24)
            .background(backgroundColor(isPressed: configuration.isPressed))
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.control))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.control)
                    .strokeBorder(borderColor, lineWidth: 0.5)
            )
            .opacity(isEnabled ? 1 : 0.45)
    }

    private var foregroundColor: Color {
        switch prominence {
        case .normal: return Theme.Palette.label2
        case .accent: return Theme.Palette.accentInk
        }
    }

    private var borderColor: Color {
        switch prominence {
        case .normal: return Theme.Palette.hairline
        case .accent: return Color.clear
        }
    }

    private func backgroundColor(isPressed: Bool) -> Color {
        switch prominence {
        case .normal:
            return isPressed ? Theme.Palette.bgSelection : Theme.Palette.bgControl
        case .accent:
            return isPressed ? Theme.Palette.accent.opacity(0.82) : Theme.Palette.accent
        }
    }
}

private struct NativeSearchField: NSViewRepresentable {
    let placeholder: String
    @Binding var text: String

    init(_ placeholder: String, text: Binding<String>) {
        self.placeholder = placeholder
        self._text = text
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    func makeNSView(context: Context) -> NSSearchField {
        let field = NSSearchField()
        field.placeholderString = L(placeholder)
        field.controlSize = .small
        field.font = NSFont.systemFont(ofSize: 12)
        field.sendsSearchStringImmediately = true
        field.target = context.coordinator
        field.action = #selector(Coordinator.searchChanged(_:))
        field.delegate = context.coordinator
        return field
    }

    func updateNSView(_ field: NSSearchField, context: Context) {
        if field.stringValue != text {
            field.stringValue = text
        }
        let localizedPlaceholder = L(placeholder)
        if field.placeholderString != localizedPlaceholder {
            field.placeholderString = localizedPlaceholder
        }
    }

    final class Coordinator: NSObject, NSSearchFieldDelegate {
        @Binding var text: String

        init(text: Binding<String>) {
            self._text = text
        }

        @objc func searchChanged(_ sender: NSSearchField) {
            text = sender.stringValue
        }

        func controlTextDidChange(_ notification: Notification) {
            guard let field = notification.object as? NSSearchField else { return }
            text = field.stringValue
        }
    }
}

/// Preferences laid out as a sidebar + content panel (see redesign-app-ui mockups/surf-settings).
@MainActor
struct SettingsView: View {
    @ObservedObject var state: AppState
    @ObservedObject private var settings: AppSettings
    private let initialFocusedServiceID: String?
    private let retryProviderID: String?
    private let onRetryProvider: (String) -> Void

    enum Pane: String, CaseIterable, Identifiable {
        case general, engines, ocr, tts, keys, shortcuts, plugins, about
        var id: String { rawValue }
        var title: String {
            switch self {
            case .general: return L("通用")
            case .engines: return L("翻译")
            case .ocr: return L("识别")
            case .tts: return L("语音")
            case .keys: return L("密钥")
            case .shortcuts: return L("快捷键")
            case .plugins: return L("插件")
            case .about: return L("关于")
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
    @State private var focusedServiceID: String?
    @State private var secretDrafts: [String: String] = [:]
    @State private var modelDrafts: [String: String] = [:]
    @State private var endpointDrafts: [String: String] = [:]
    @State private var validateNote: String = ""
    @State private var savedNote: String = ""
    @State private var keySearchText = ""
    @State private var keyFilter: KeyFilter = .all
    @State private var credentialNotes: [String: CredentialNote] = [:]
    @State private var engineOrderDraft: [String] = []
    @State private var showMachineEngines = true
    @State private var showLLMEngines = true
    @State private var showMoreEngines = true
    @State private var recordingShortcut: ShortcutAction?
    @State private var shortcutMonitor: Any?
    @FocusState private var focusedCredentialFieldID: String?

    private let languages: [(String, String)] = [
        ("zh", "中文"), ("en", "English"), ("ja", "日本語"), ("ko", "한국어"),
        ("fr", "Français"), ("de", "Deutsch"), ("es", "Español"), ("ru", "Русский"),
        ("pt", "Português"), ("it", "Italiano"), ("nl", "Nederlands"), ("pl", "Polski"),
        ("uk", "Українська"), ("tr", "Türkçe"), ("ar", "العربية"), ("hi", "हिन्दी"),
        ("id", "Bahasa Indonesia"), ("vi", "Tiếng Việt"), ("th", "ไทย"), ("ms", "Bahasa Melayu"),
        ("he", "עברית"), ("fa", "فارسی"), ("el", "Ελληνικά"), ("sv", "Svenska"),
        ("da", "Dansk"), ("fi", "Suomi"), ("no", "Norsk"), ("cs", "Čeština"),
        ("hu", "Magyar"), ("ro", "Română"),
    ]

    enum KeyFilter: String, CaseIterable, Identifiable {
        case all, needsAction, configured, environment, ocr, tts, llm
        var id: String { rawValue }
        var title: String {
            switch self {
            case .all: return L("全部")
            case .needsAction: return L("需处理")
            case .configured: return L("已配置")
            case .environment: return L("环境变量")
            case .ocr: return "OCR"
            case .tts: return "TTS"
            case .llm: return "LLM"
            }
        }
    }

    enum CredentialNote: Equatable {
        case saved(String)
        case failed(String)
        case validating
        case valid(String)

        var text: String {
            switch self {
            case .saved(let message), .failed(let message), .valid(let message): return message
            case .validating: return L("正在验证…")
            }
        }

        var color: Color {
            switch self {
            case .saved, .valid: return Theme.Palette.success
            case .failed: return Theme.Palette.danger
            case .validating: return Theme.Palette.label2
            }
        }
    }

    init(
        state: AppState,
        initialPane: Pane = .general,
        focusedServiceID: String? = nil,
        retryProviderID: String? = nil,
        onRetryProvider: @escaping (String) -> Void = { _ in }
    ) {
        self.state = state
        self.settings = state.settings
        self.initialFocusedServiceID = CredentialCatalog.normalizedServiceID(focusedServiceID)
        self.retryProviderID = retryProviderID
        self.onRetryProvider = onRetryProvider
        _selection = State(initialValue: initialPane)
        _focusedServiceID = State(initialValue: CredentialCatalog.normalizedServiceID(focusedServiceID))
    }

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            Divider()
            ScrollViewReader { proxy in
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
                .onAppear {
                    revealFocusedCredential(with: proxy)
                }
                .onChange(of: selection) { _ in
                    revealFocusedCredential(with: proxy)
                }
                .onChange(of: focusedServiceID) { _ in
                    revealFocusedCredential(with: proxy)
                }
            }
        }
        .frame(minWidth: 640, minHeight: 420)
        .onAppear {
            state.refreshPermissions()
            loadAdvancedDrafts()
            engineOrderDraft = EngineBootstrap.resolvedOrder(settings.engineOrder)
            if initialFocusedServiceID != nil {
                selection = .keys
            }
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
            Text("结果面板按这里的顺序显示；用箭头调整优先级。")
                .font(Theme.Font.caption)
                .foregroundStyle(Theme.Palette.label3)
                .padding(.bottom, Theme.Spacing.s8)
            enabledEngineOptionsGroup

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
        }
    }

    private var enabledEngineOptions: [EngineDescriptor] {
        orderableEngineIDs.compactMap { EngineCatalog.descriptor(for: $0) }
    }

    private var effectiveEngineOrder: [String] {
        engineOrderDraft.isEmpty ? EngineBootstrap.resolvedOrder(settings.engineOrder) : engineOrderDraft
    }

    private var orderableEngineIDs: [String] {
        effectiveEngineOrder.filter { settings.isEngineEnabled($0) }
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
                if newValue {
                    var nextOrder = effectiveEngineOrder
                    if !nextOrder.contains(id) {
                        nextOrder.append(id)
                    }
                    engineOrderDraft = nextOrder
                    settings.setEngineOrder(nextOrder)
                }
                state.applySettings()
            }
        )
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
                Button("配置当前 OCR 密钥") { focusCredentialService(settings.ocrProviderId) }
                    .controlSize(.small)
                    .disabled(CredentialCatalog.descriptor(matching: settings.ocrProviderId) == nil)
                Button("验证 OCR 配置") { validateOCR() }
                    .controlSize(.small)
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
            HStack(spacing: Theme.Spacing.s12) {
                Button("配置当前 TTS 密钥") { focusCredentialService(settings.ttsProviderId) }
                    .controlSize(.small)
                    .disabled(CredentialCatalog.descriptor(matching: settings.ttsProviderId) == nil)
                Spacer()
            }
            .padding(.top, Theme.Spacing.s12)
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

    private var enabledEngineOptionsGroup: some View {
        formGroup {
            if enabledEngineOptions.isEmpty {
                emptyEngineRow("还没有开启任何翻译引擎")
            } else {
                ForEach(Array(enabledEngineOptions.enumerated()), id: \.element.id) { index, descriptor in
                    enabledEngineOptionRow(descriptor, index: index, count: enabledEngineOptions.count)
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

    private func enabledEngineOptionRow(_ descriptor: EngineDescriptor, index: Int, count: Int) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: Theme.Spacing.s8) {
                Text("\(index + 1)")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.Palette.label2)
                    .frame(width: 22, height: 22)
                    .background(Theme.Palette.bgControl)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.control))
                VStack(alignment: .leading, spacing: 2) {
                    Text(descriptor.name)
                        .font(Theme.Font.body)
                        .foregroundStyle(Theme.Palette.label)
                    if let note = settings.engineStatusText(descriptor) {
                        Text(L(note))
                            .font(Theme.Font.caption)
                            .foregroundStyle(Theme.Palette.label3)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: Theme.Spacing.s8)
                Circle().fill(status(descriptor).color).frame(width: 7, height: 7)
                HStack(spacing: 2) {
                    reorderButton(
                        systemName: "chevron.up",
                        help: L("上移 %@", descriptor.name),
                        disabled: index == 0
                    ) {
                        moveEnabledEngine(from: index, to: index - 1)
                    }
                    reorderButton(
                        systemName: "chevron.down",
                        help: L("下移 %@", descriptor.name),
                        disabled: index == count - 1
                    ) {
                        moveEnabledEngine(from: index, to: index + 1)
                    }
                }
                Toggle("", isOn: binding(forEngine: descriptor.id))
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.small)
            }
            .padding(.horizontal, Theme.Spacing.s12)
            .padding(.vertical, 8)
            .frame(minHeight: 44)
            Divider()
        }
        .background(Color.clear)
    }

    private func emptyEngineRow(_ text: String) -> some View {
        HStack {
            Text(L(text))
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

            keySearchAndFilter
            keyNeedsAttentionSection
            keyServiceSections
            keyActionBar
            keyFootnote
        }
    }

    private var keySearchAndFilter: some View {
        VStack(alignment: .leading, spacing: 9) {
            NativeSearchField("搜索服务、Key 或环境变量", text: $keySearchText)
                .frame(width: 330, height: 24, alignment: .leading)

            Picker("", selection: $keyFilter) {
                ForEach(KeyFilter.allCases) { filter in
                    Text(filter.title).tag(filter)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .controlSize(.small)
            .fixedSize(horizontal: true, vertical: false)
        }
        .padding(.bottom, Theme.Spacing.s16)
    }

    @ViewBuilder
    private var keyNeedsAttentionSection: some View {
        let descriptors = keyDescriptorsNeedingAttention
        if shouldShowNeedsAttentionSection && !descriptors.isEmpty {
            subsectionTitle("需要处理")
            VStack(spacing: Theme.Spacing.s8) {
                ForEach(descriptors) { descriptor in
                    credentialServiceCard(descriptor, highlighted: descriptor.matchesServiceID(focusedServiceID))
                }
            }
            .padding(.bottom, Theme.Spacing.s16)
        }
    }

    @ViewBuilder
    private var keyServiceSections: some View {
        let descriptors = keyVisibleDescriptors
        if descriptors.isEmpty {
            callout("没有匹配的服务。可以清空搜索或切换筛选。")
        } else if keySearchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  keyFilter == .all {
            ForEach(CredentialCategory.allCases) { category in
                let sectionDescriptors = descriptors
                    .filter { $0.category == category }
                    .filter { !shouldShowNeedsAttentionSection || !keyDescriptorsNeedingAttention.contains($0) }
                if !sectionDescriptors.isEmpty {
                    subsectionTitle(category.title)
                    VStack(spacing: Theme.Spacing.s8) {
                        ForEach(sectionDescriptors) { descriptor in
                            credentialServiceCard(descriptor, highlighted: descriptor.matchesServiceID(focusedServiceID))
                        }
                    }
                    .padding(.bottom, Theme.Spacing.s16)
                }
            }
        } else {
            subsectionTitle("匹配服务")
            VStack(spacing: Theme.Spacing.s8) {
                ForEach(descriptors) { descriptor in
                    credentialServiceCard(descriptor, highlighted: descriptor.matchesServiceID(focusedServiceID))
                }
            }
            .padding(.bottom, Theme.Spacing.s16)
        }
    }

    private var keyActionBar: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s8) {
            HStack(spacing: Theme.Spacing.s8) {
                Button("保存全部更改") { saveKeys() }
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

    private func credentialServiceCard(_ descriptor: CredentialDescriptor, highlighted: Bool) -> some View {
        let status = credentialDisplayStatus(for: descriptor)
        let active = isCredentialServiceActive(descriptor)
        let dirty = isCredentialServiceDirty(descriptor)
        let note = credentialNotes[descriptor.id]

        return VStack(alignment: .leading, spacing: Theme.Spacing.s12) {
            HStack(alignment: .center, spacing: Theme.Spacing.s12) {
                Circle()
                    .fill(dirty ? Theme.Palette.warning : (status.configured ? Theme.Palette.success : Theme.Palette.label3))
                    .frame(width: 8, height: 8)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: Theme.Spacing.s8) {
                        Text(descriptor.name)
                            .font(Theme.Font.body)
                            .foregroundStyle(Theme.Palette.label)
                        Text(descriptor.category.filterTitle)
                            .font(Theme.Font.tag)
                            .foregroundStyle(Theme.Palette.label2)
                            .padding(.horizontal, 6)
                            .frame(height: 18)
                            .background(Theme.Palette.bgControl)
                            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.control))
                    }
                    Text(status.text)
                        .font(Theme.Font.caption)
                        .foregroundStyle(status.configured ? Theme.Palette.label2 : Theme.Palette.label3)
                        .lineLimit(1)
                }
                Spacer(minLength: Theme.Spacing.s12)
                if active {
                    settingsStatusBadge("使用中", tone: .success)
                } else if let engineID = descriptor.linkedEngineID {
                    Toggle("", isOn: binding(forEngine: engineID))
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .controlSize(.small)
                }
            }

            if let noteText = descriptor.note {
                Text(noteText)
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Palette.label3)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let credential = descriptor.credential {
                VStack(alignment: .leading, spacing: Theme.Spacing.s8) {
                    credentialSecretRow(
                        descriptor: descriptor,
                        credential: credential,
                        status: status,
                        dirty: dirty
                    )
                    if status.fromPrimaryEnv {
                        formHelpText(L("%@ 已生效并优先于本机保存。要改用本机 Key，请移除该环境变量后重启 Parrot。", credential.env))
                    }
                }
            }

            if descriptor.defaultModel != nil || descriptor.defaultEndpoint != nil {
                VStack(alignment: .leading, spacing: Theme.Spacing.s8) {
                    if descriptor.defaultModel != nil {
                        credentialTextFieldRow("Model", placeholder: descriptor.defaultModel ?? "model", text: modelBinding(for: descriptor))
                    }
                    if descriptor.defaultEndpoint != nil {
                        credentialTextFieldRow("Endpoint", placeholder: endpointPlaceholder(for: descriptor), text: endpointBinding(for: descriptor))
                    }
                }
            }

            HStack(alignment: .center, spacing: Theme.Spacing.s8) {
                Button("验证") { validateCredentialService(descriptor) }
                    .buttonStyle(SettingsMiniButtonStyle())
                    .disabled(credentialNotes[descriptor.id] == .validating)
                if canRetryFromCredential(descriptor) {
                    Button("保存并重试") { saveAndRetryCredentialService(descriptor) }
                        .buttonStyle(SettingsMiniButtonStyle(prominence: .accent))
                }
                if let note {
                    Text(note.text)
                        .font(Theme.Font.caption)
                        .foregroundStyle(note.color)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
        }
        .id(descriptor.id)
        .padding(Theme.Spacing.s12)
        .background(highlighted ? Theme.Palette.bgSelection : Theme.Palette.bgContent)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.group))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.group)
                .strokeBorder(highlighted ? Theme.Palette.accent.opacity(0.65) : Theme.Palette.hairline, lineWidth: highlighted ? 1 : 0.5)
        )
    }

    private func credentialSecretRow(
        descriptor: CredentialDescriptor,
        credential: EngineCredential,
        status: (text: String, configured: Bool, fromPrimaryEnv: Bool, fromFallback: Bool),
        dirty: Bool
    ) -> some View {
        HStack(alignment: .center, spacing: Theme.Spacing.s8) {
            formRowLabel("Key")
            SecureField(credentialPlaceholder(for: descriptor, status: status),
                        text: secretBinding(for: credential.account))
                .textFieldStyle(.roundedBorder)
                .controlSize(.small)
                .font(Theme.Font.callout)
                .focused($focusedCredentialFieldID, equals: descriptor.id)
                .disabled(status.fromPrimaryEnv)
                .frame(minWidth: 180, idealWidth: 320, maxWidth: 380, minHeight: 22, idealHeight: 22, maxHeight: 22)
            Button("保存") { saveCredentialService(descriptor) }
                .buttonStyle(SettingsMiniButtonStyle())
                .disabled(!dirty && !hasSecretDraft(for: descriptor))
            Button("清除") { clearSecret(credential.account, serviceID: descriptor.id) }
                .buttonStyle(SettingsMiniButtonStyle())
                .disabled(!settings.hasStoredSecret(account: credential.account))
        }
    }

    private func credentialTextFieldRow(_ label: String, placeholder: String, text: Binding<String>) -> some View {
        HStack(alignment: .center, spacing: Theme.Spacing.s8) {
            formRowLabel(label)
            TextField(placeholder, text: text)
                .textFieldStyle(.roundedBorder)
                .controlSize(.small)
                .font(Theme.Font.callout)
                .frame(minWidth: 180, idealWidth: 320, maxWidth: 380, minHeight: 22, idealHeight: 22, maxHeight: 22)
            Spacer(minLength: 0)
        }
    }

    private func formRowLabel(_ label: String) -> some View {
        Text(L(label))
            .font(Theme.Font.caption)
            .foregroundStyle(Theme.Palette.label2)
            .frame(width: 64, alignment: .leading)
    }

    private func formHelpText(_ text: String) -> some View {
        HStack(alignment: .top, spacing: Theme.Spacing.s8) {
            Spacer()
                .frame(width: 64)
            Text(L(text))
                .font(Theme.Font.caption)
                .foregroundStyle(Theme.Palette.label3)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private enum SettingsBadgeTone {
        case success, secondary
    }

    private func settingsStatusBadge(_ text: String, tone: SettingsBadgeTone) -> some View {
        Text(L(text))
            .font(Theme.Font.tag)
            .foregroundStyle(tone == .success ? Theme.Palette.success : Theme.Palette.label2)
            .padding(.horizontal, 7)
            .frame(height: 20)
            .background(tone == .success ? Theme.Palette.success.opacity(0.12) : Theme.Palette.bgControl)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.control))
    }

    private var shortcutsPane: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionTitle("全局快捷键")
            Text(recordingShortcut == nil ? L("点击录制后按下新的组合键。至少包含一个修饰键。") : L("正在录制 %@，按 Esc 取消。", recordingShortcut?.title ?? ""))
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
                    savedNote = L("已恢复默认快捷键")
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
                    Text(L("版本 %@", appVersion)).font(Theme.Font.callout).foregroundStyle(Theme.Palette.label2)
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
        Text(L(t)).font(.system(size: 17, weight: .semibold))
            .foregroundStyle(Theme.Palette.label)
            .padding(.bottom, Theme.Spacing.s12)
    }

    private func subsectionTitle(_ t: String) -> some View {
        Text(L(t))
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
            Text(L(title))
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.Palette.label)
        }
        .padding(.top, Theme.Spacing.s12)
    }

    private func settingRow<Control: View>(_ label: String, @ViewBuilder control: () -> Control) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text(L(label)).font(Theme.Font.body).foregroundStyle(Theme.Palette.label)
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
                    Text(L(name))
                        .font(Theme.Font.body)
                        .foregroundStyle(Theme.Palette.label)
                    Text(granted ? L("已开启") : L(detail))
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
                    Button(L(actionTitle)) { action() }
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
                    Text(L(name))
                        .font(Theme.Font.body)
                        .foregroundStyle(Theme.Palette.label)
                    if let note {
                        Text(L(note))
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

    private func reorderButton(
        systemName: String,
        help: String,
        disabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(disabled ? Theme.Palette.label3.opacity(0.45) : Theme.Palette.label2)
                .frame(width: 22, height: 22)
        }
        .buttonStyle(.borderless)
        .background(disabled ? Theme.Palette.bgControl.opacity(0.25) : Theme.Palette.bgControl)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.control))
        .disabled(disabled)
        .help(L(help))
        .accessibilityLabel(L(help))
    }

    private func shortcutRow(_ action: ShortcutAction) -> some View {
        let isRecording = recordingShortcut == action
        let key = settings.shortcutSpec(for: action).displayText
        return VStack(spacing: 0) {
            HStack {
                Text(action.title).font(Theme.Font.body).foregroundStyle(Theme.Palette.label)
                Spacer()
                Button(isRecording ? L("按键中…") : key) {
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
        Text(L(text))
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

    private func credentialDisplayStatus(
        for descriptor: CredentialDescriptor
    ) -> (text: String, configured: Bool, fromPrimaryEnv: Bool, fromFallback: Bool) {
        guard let credential = descriptor.credential else {
            return (descriptor.note ?? L("无需 Key"), true, false, false)
        }

        let primaryStatus = settings.secretStatus(account: credential.account, env: credential.env)
        if settings.envNonEmpty(credential.env) != nil {
            return (L("环境变量 %@ 已生效", credential.env), true, true, false)
        }
        if primaryStatus != L("未配置") {
            return (primaryStatus, true, false, false)
        }

        if let fallback = descriptor.fallbackCredential,
           settings.hasSecret(fallback.account, env: fallback.env) {
            let source = descriptor.fallbackLabel ?? L("共享凭证")
            return (L("复用%@", source), true, false, true)
        }

        return (L("未配置"), false, false, false)
    }

    private func credentialPlaceholder(
        for descriptor: CredentialDescriptor,
        status: (text: String, configured: Bool, fromPrimaryEnv: Bool, fromFallback: Bool)
    ) -> String {
        guard let credential = descriptor.credential else { return "" }
        if status.fromPrimaryEnv { return L("环境变量 %@ 优先", credential.env) }
        if status.fromFallback { return L("输入专用 Key 覆盖复用凭证") }
        return status.configured ? L("输入新值以替换") : credential.placeholder
    }

    private func hasSecretDraft(for descriptor: CredentialDescriptor) -> Bool {
        guard let credential = descriptor.credential else { return false }
        return !(secretDrafts[credential.account] ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func isCredentialServiceDirty(_ descriptor: CredentialDescriptor) -> Bool {
        if hasSecretDraft(for: descriptor) { return true }
        if descriptor.defaultModel != nil,
           (modelDrafts[descriptor.id] ?? currentModel(for: descriptor)) != currentModel(for: descriptor) {
            return true
        }
        if descriptor.defaultEndpoint != nil,
           (endpointDrafts[descriptor.id] ?? currentEndpoint(for: descriptor)) != currentEndpoint(for: descriptor) {
            return true
        }
        return false
    }

    private func isCredentialServiceActive(_ descriptor: CredentialDescriptor) -> Bool {
        if let engineID = descriptor.linkedEngineID, settings.isEngineEnabled(engineID) {
            return true
        }
        return descriptor.matchesServiceID(settings.ocrProviderId)
            || descriptor.matchesServiceID(settings.ttsProviderId)
    }

    private func canRetryFromCredential(_ descriptor: CredentialDescriptor) -> Bool {
        guard let retryProviderID else { return false }
        return descriptor.linkedEngineID != nil && descriptor.matchesServiceID(retryProviderID)
    }

    @discardableResult
    private func saveCredentialService(_ descriptor: CredentialDescriptor, showNote: Bool = true) -> Bool {
        let trim: (String) -> String = { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        var ok = true

        if let credential = descriptor.credential {
            let value = trim(secretDrafts[credential.account] ?? "")
            if !value.isEmpty {
                if settings.setKey(value, account: credential.account) {
                    secretDrafts[credential.account] = ""
                } else {
                    ok = false
                }
            }
        }

        if descriptor.defaultModel != nil {
            let value = trim(modelDrafts[descriptor.id] ?? currentModel(for: descriptor))
            saveModel(value, for: descriptor)
            modelDrafts[descriptor.id] = currentModel(for: descriptor)
        }

        if descriptor.defaultEndpoint != nil {
            let value = trim(endpointDrafts[descriptor.id] ?? currentEndpoint(for: descriptor))
            saveEndpoint(value, for: descriptor)
            endpointDrafts[descriptor.id] = currentEndpoint(for: descriptor)
        }

        state.applySettings()
        if showNote {
            credentialNotes[descriptor.id] = ok ? .saved(L("已保存到本机 ✓")) : .failed(L("保存失败：检查 secrets.json 权限。"))
            clearCredentialNote(descriptor.id)
        }
        return ok
    }

    private func saveAndRetryCredentialService(_ descriptor: CredentialDescriptor) {
        guard saveCredentialService(descriptor, showNote: false) else {
            credentialNotes[descriptor.id] = .failed(L("保存失败，未重试。"))
            clearCredentialNote(descriptor.id)
            return
        }
        guard let providerID = descriptor.linkedEngineID else {
            credentialNotes[descriptor.id] = .valid(L("已保存。当前服务无需翻译重试。"))
            clearCredentialNote(descriptor.id)
            return
        }
        credentialNotes[descriptor.id] = .saved(L("已保存，正在重试 %@…", descriptor.name))
        onRetryProvider(providerID)
        clearCredentialNote(descriptor.id, after: 3)
    }

    private func validateCredentialService(_ descriptor: CredentialDescriptor) {
        guard saveCredentialService(descriptor, showNote: false) else {
            credentialNotes[descriptor.id] = .failed(L("保存失败，无法验证。"))
            clearCredentialNote(descriptor.id)
            return
        }

        guard credentialDisplayStatus(for: descriptor).configured || !descriptor.requiresCredential else {
            credentialNotes[descriptor.id] = .failed(L("未配置：先输入并保存 Key。"))
            clearCredentialNote(descriptor.id)
            return
        }

        guard let engineID = descriptor.linkedEngineID, descriptor.supportsValidation else {
            credentialNotes[descriptor.id] = .valid(descriptor.requiresCredential ? L("已配置 ✓") : L("此服务无需在线验证"))
            clearCredentialNote(descriptor.id)
            return
        }

        credentialNotes[descriptor.id] = .validating
        Task { @MainActor in
            guard let provider = EngineValidator.makeConfiguredProvider(id: engineID, settings: settings) else {
                credentialNotes[descriptor.id] = .failed(L("服务未启用或不可用。"))
                clearCredentialNote(descriptor.id)
                return
            }
            switch await EngineValidator.validateDetailed(provider) {
            case .passed:
                credentialNotes[descriptor.id] = .valid(L("验证通过 ✓"))
            case .failed(let message):
                credentialNotes[descriptor.id] = .failed(message)
            }
            clearCredentialNote(descriptor.id, after: 4)
        }
    }

    private func clearCredentialNote(_ serviceID: String, after seconds: Double = 2.5) {
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds) {
            credentialNotes[serviceID] = nil
        }
    }

    private func focusCredentialService(_ serviceID: String?) {
        guard let normalized = CredentialCatalog.normalizedServiceID(serviceID) else {
            selection = .keys
            return
        }
        keySearchText = ""
        keyFilter = .all
        focusedServiceID = normalized
        selection = .keys
    }

    private func revealFocusedCredential(with proxy: ScrollViewProxy) {
        guard selection == .keys,
              let serviceID = focusedServiceID else { return }
        DispatchQueue.main.async {
            withAnimation(.easeInOut(duration: 0.18)) {
                proxy.scrollTo(serviceID, anchor: .center)
            }
            focusedCredentialFieldID = serviceID
        }
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
            validateNote = L("请至少包含一个修饰键")
            return
        }
        if let conflict = ShortcutAction.allCases.first(where: { $0 != action && settings.shortcutSpec(for: $0) == spec }) {
            validateNote = L("快捷键已被「%@」使用", conflict.title)
            return
        }
        settings.setShortcutSpec(spec, for: action)
        stopShortcutRecording()
        savedNote = L("已设置 %@：%@", action.title, spec.displayText)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { savedNote = "" }
    }

    private var allCredentialDescriptors: [CredentialDescriptor] {
        CredentialCatalog.all
    }

    private var shouldShowNeedsAttentionSection: Bool {
        keySearchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && keyFilter == .all
    }

    private var keyDescriptorsNeedingAttention: [CredentialDescriptor] {
        allCredentialDescriptors.filter { descriptor in
            descriptor.requiresCredential
                && isCredentialServiceActive(descriptor)
                && !credentialDisplayStatus(for: descriptor).configured
        }
    }

    private var keyVisibleDescriptors: [CredentialDescriptor] {
        let query = keySearchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return allCredentialDescriptors.filter { descriptor in
            let matchesSearch = query.isEmpty || descriptor.searchableText.contains(query)
            return matchesSearch && keyDescriptor(descriptor, matches: keyFilter)
        }
    }

    private func keyDescriptor(_ descriptor: CredentialDescriptor, matches filter: KeyFilter) -> Bool {
        switch filter {
        case .all: return true
        case .needsAction:
            return descriptor.requiresCredential
                && isCredentialServiceActive(descriptor)
                && !credentialDisplayStatus(for: descriptor).configured
        case .configured:
            return credentialDisplayStatus(for: descriptor).configured
        case .environment:
            return credentialDisplayStatus(for: descriptor).fromPrimaryEnv
        case .ocr:
            return descriptor.category == .ocr
        case .tts:
            return descriptor.category == .tts || descriptor.aliases.contains(settings.ttsProviderId)
        case .llm:
            return descriptor.category == .llm || descriptor.defaultModel != nil
        }
    }

    private func secretBinding(for account: String) -> Binding<String> {
        Binding(
            get: { secretDrafts[account] ?? "" },
            set: { secretDrafts[account] = $0 }
        )
    }

    private func modelBinding(for descriptor: CredentialDescriptor) -> Binding<String> {
        Binding(
            get: { modelDrafts[descriptor.id] ?? currentModel(for: descriptor) },
            set: { modelDrafts[descriptor.id] = $0 }
        )
    }

    private func endpointBinding(for descriptor: CredentialDescriptor) -> Binding<String> {
        Binding(
            get: { endpointDrafts[descriptor.id] ?? currentEndpoint(for: descriptor) },
            set: { endpointDrafts[descriptor.id] = $0 }
        )
    }

    private func endpointPlaceholder(for descriptor: CredentialDescriptor) -> String {
        switch descriptor.id {
        case "openai": return L("可选")
        case "azure-openai": return "Azure deployment URL"
        default: return descriptor.defaultEndpoint ?? "Endpoint"
        }
    }

    private func loadAdvancedDrafts() {
        modelDrafts = Dictionary(uniqueKeysWithValues: allCredentialDescriptors
            .filter { $0.defaultModel != nil }
            .map { ($0.id, currentModel(for: $0)) })
        endpointDrafts = Dictionary(uniqueKeysWithValues: allCredentialDescriptors
            .filter { $0.defaultEndpoint != nil }
            .map { ($0.id, currentEndpoint(for: $0)) })
    }

    private func currentModel(for descriptor: CredentialDescriptor) -> String {
        if descriptor.id == "openai" { return settings.openAIModel }
        return settings.model(for: descriptor.id) ?? descriptor.defaultModel ?? ""
    }

    private func currentEndpoint(for descriptor: CredentialDescriptor) -> String {
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
        if apps.count <= 1 { return L("仅当前实例") }
        return L("%d 个实例，URL Scheme 可能路由到旧版本", apps.count)
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
        var ok = true
        for descriptor in allCredentialDescriptors {
            if let credential = descriptor.credential {
                ok = saveSecret(trim(secretDrafts[credential.account] ?? ""), account: credential.account) && ok
            }
            if descriptor.defaultModel != nil {
                saveModel(trim(modelDrafts[descriptor.id] ?? currentModel(for: descriptor)), for: descriptor)
            }
            if descriptor.defaultEndpoint != nil {
                saveEndpoint(trim(endpointDrafts[descriptor.id] ?? currentEndpoint(for: descriptor)), for: descriptor)
            }
        }
        clearKeyFields()
        loadAdvancedDrafts()
        state.applySettings()
        savedNote = ok ? L("已保存全部更改 ✓") : L("部分密钥保存失败")
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { savedNote = "" }
    }

    @discardableResult
    private func saveSecret(_ value: String, account: String) -> Bool {
        guard !value.isEmpty else { return true }
        return settings.setKey(value, account: account)
    }

    private func saveModel(_ value: String, for descriptor: CredentialDescriptor) {
        guard !value.isEmpty else { return }
        if descriptor.id == "openai" {
            settings.openAIModel = value
        } else {
            settings.setModel(value, for: descriptor.id)
        }
    }

    private func saveEndpoint(_ value: String, for descriptor: CredentialDescriptor) {
        if descriptor.id == "openai" {
            settings.openAIEndpoint = value
        } else if descriptor.id == "ollama" {
            settings.ollamaEndpoint = value
        } else {
            settings.setEndpoint(value, for: descriptor.id)
        }
    }

    private func clearSecret(_ account: String, serviceID: String? = nil) {
        guard confirm(title: L("清除这项密钥？"), message: L("清除后，对应服务会在下次翻译时显示为需配置。")) else { return }
        settings.removeKey(account: account)
        secretDrafts[account] = ""
        state.applySettings()
        if let serviceID {
            credentialNotes[serviceID] = .saved(L("已清除 ✓"))
            clearCredentialNote(serviceID)
        } else {
            savedNote = L("已清除 ✓")
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { savedNote = "" }
        }
    }

    private func confirm(title: String, message: String) -> Bool {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: L("继续"))
        alert.addButton(withTitle: L("取消"))
        return alert.runModal() == .alertFirstButtonReturn
    }

    private func clearKeyFields() {
        secretDrafts = [:]
    }

    private func moveEnabledEngine(from: Int, to: Int) {
        var enabled = orderableEngineIDs
        guard to >= 0, to < enabled.count, from != to else { return }
        enabled.move(fromOffsets: IndexSet(integer: from), toOffset: to > from ? to + 1 : to)
        let disabled = effectiveEngineOrder.filter { !settings.isEngineEnabled($0) }
        engineOrderDraft = enabled + disabled
        settings.setEngineOrder(engineOrderDraft)
        state.applySettings()
    }

    private func validateOCR() {
        let id = settings.ocrProviderId
        if id == "apple-vision" {
            validateNote = L("离线 OCR 无需 Key ✓")
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
        validateNote = configured ? L("OCR 密钥已配置 ✓") : L("OCR 密钥未配置")
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { validateNote = "" }
    }
}
