import AppKit
import SwiftUI
import Carbon.HIToolbox
import ParrotCore
import ParrotEngines
import UniformTypeIdentifiers

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
            configureTitle(for: win)
            win.styleMask = [.titled, .closable, .miniaturizable, .resizable]
            win.isReleasedWhenClosed = false
            win.contentMinSize = NSSize(width: 720, height: 520)
            win.setContentSize(NSSize(width: 820, height: 650))
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
        if let window {
            configureTitle(for: window)
        }
        NSApp.activate(ignoringOtherApps: true)
        if let window {
            WindowPlacement.center(window)
        }
        window?.makeKeyAndOrderFront(nil)
    }

    private func configureTitle(for window: NSWindow) {
        let title = L("Parrot 设置")
        window.title = title
        window.setAccessibilityTitle(title)
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

private struct KeyFilterChipStyle: ButtonStyle {
    let selected: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.Font.callout.weight(.semibold))
            .foregroundStyle(selected ? Theme.Palette.accent : Theme.Palette.label2)
            .padding(.horizontal, 10)
            .frame(height: 25)
            .background(backgroundColor(isPressed: configuration.isPressed))
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .strokeBorder(selected ? Theme.Palette.accent.opacity(0.24) : Color.clear, lineWidth: 0.5)
            )
    }

    private func backgroundColor(isPressed: Bool) -> Color {
        if isPressed { return Theme.Palette.bgSelection }
        return selected ? Theme.Palette.accentSoft : Theme.Palette.bgControl
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
        case general, engines, learning, terminology, ocr, tts, keys, shortcuts, plugins, about
        var id: String { rawValue }
        var title: String {
            switch self {
            case .general: return L("通用")
            case .engines: return L("翻译")
            case .learning: return L("学习")
            case .terminology: return L("术语")
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
            case .learning: return "brain.head.profile"
            case .terminology: return "text.book.closed"
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
    @State private var modelListDrafts: [String: [EngineModelConfig]] = [:]
    @State private var endpointDrafts: [String: String] = [:]
    @State private var validateNote: String = ""
    @State private var savedNote: String = ""
    @State private var keySearchText = ""
    @State private var keyFilter: KeyFilter = .needsAction
    @State private var showProviderPicker = false
    @State private var providerPickerSearchText = ""
    @State private var credentialNotes: [String: CredentialNote] = [:]
    @State private var engineOrderDraft: [String] = []
    @State private var showMachineEngines = true
    @State private var showLLMEngines = true
    @State private var showMoreEngines = true
    @State private var recordingShortcut: ShortcutAction?
    @State private var shortcutMonitor: Any?
    @State private var terminologySearchText = ""
    @State private var terminologyDraft = TerminologyDraft()
    @State private var editingTerminologyID: UUID?
    @State private var terminologyNote = ""
    @State private var pendingTerminologyImport: TerminologyImportPlan?
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
        case needsAction, configured, environment, llm, media, all
        var id: String { rawValue }
        var title: String {
            switch self {
            case .needsAction: return L("需处理")
            case .configured: return L("已配置")
            case .environment: return L("环境变量")
            case .llm: return "LLM"
            case .media: return "OCR/TTS"
            case .all: return L("全部")
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

    struct TerminologyDraft: Equatable {
        var source = ""
        var target = ""
        var fromCode = "auto"
        var toCode = "zh"
        var note = ""
        var caseSensitive = false
        var enabled = true

        init(entry: TerminologyEntry? = nil, defaultTarget: String = "zh") {
            guard let entry else {
                toCode = defaultTarget
                return
            }
            source = entry.source
            target = entry.target
            fromCode = entry.from.code ?? "auto"
            toCode = entry.to.code ?? defaultTarget
            note = entry.note ?? ""
            caseSensitive = entry.caseSensitive
            enabled = entry.enabled
        }

        func entry(id: UUID? = nil) -> TerminologyEntry {
            TerminologyEntry(
                id: id ?? UUID(),
                source: source,
                target: target,
                from: fromCode == "auto" ? .auto : Language(code: fromCode),
                to: Language(code: toCode),
                note: note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : note,
                caseSensitive: caseSensitive,
                enabled: enabled
            )
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
        .frame(minWidth: 720, minHeight: 520)
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
                if pane == .keys, keyDescriptorsNeedingAttention.count > 0 {
                    Text("\(keyDescriptorsNeedingAttention.count)")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Theme.Palette.warning)
                        .frame(minWidth: 18, minHeight: 18)
                        .padding(.horizontal, 3)
                        .background(Theme.Palette.warning.opacity(0.14))
                        .clipShape(Capsule())
                }
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
        case .learning: learningPane
        case .terminology: terminologyPane
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

    private var learningPane: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionTitle("学习")
            formGroup {
                settingRow("手动选词学习") {
                    Toggle("", isOn: $settings.learningRecognitionEnabled)
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .controlSize(.small)
                }
                settingRow("翻译后微练习") {
                    Toggle("", isOn: $settings.learningMicroPracticeEnabled)
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .controlSize(.small)
                }
            }

            formGroup {
                settingRow("每日复习强度") {
                    Picker("", selection: $settings.learningReviewIntensity) {
                        Text("轻量 · 3 分钟").tag("light")
                        Text("标准 · 5 分钟").tag("standard")
                        Text("强化 · 10 分钟").tag("intense")
                    }
                    .labelsHidden()
                    .frame(width: 150)
                }
                settingRow("只复习真实翻译句") {
                    Toggle("", isOn: $settings.learningRealSentenceOnly)
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .controlSize(.small)
                }
            }
            callout("学习词库与术语表分开管理：术语表保证译法稳定，学习词库追踪用户掌握程度。选中原文或译文中的表达后，才会出现加入词库、掌握标记和微练习。")
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

    private var terminologyPane: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionTitle("术语")
            formGroup {
                settingRow("启用术语表") {
                    Toggle("", isOn: $settings.terminologyEnabled)
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .controlSize(.small)
                }
                settingRow("严格术语模式") {
                    Toggle("", isOn: $settings.terminologyStrictMode)
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .controlSize(.small)
                        .disabled(!settings.terminologyEnabled)
                }
            }

            HStack(spacing: Theme.Spacing.s8) {
                NativeSearchField("搜索源词、译法或备注", text: $terminologySearchText)
                    .frame(width: 240, height: 24)
                Button {
                    beginNewTerminologyEntry()
                } label: {
                    Label("新增", systemImage: "plus")
                }
                .buttonStyle(SettingsMiniButtonStyle(prominence: .accent))
                Button {
                    importTerminologyCSV()
                } label: {
                    Label("导入", systemImage: "square.and.arrow.down")
                }
                .buttonStyle(SettingsMiniButtonStyle())
                Button {
                    exportTerminologyCSV()
                } label: {
                    Label("导出", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(SettingsMiniButtonStyle())
                Spacer()
            }
            .padding(.bottom, Theme.Spacing.s12)

            if editingTerminologyID != nil {
                terminologyEditor
            }

            if let pendingTerminologyImport {
                terminologyImportPreview(pendingTerminologyImport)
            }

            if !terminologyNote.isEmpty {
                Text(terminologyNote)
                    .font(Theme.Font.caption)
                    .foregroundStyle(terminologyNote.contains("失败") || terminologyNote.contains("重复") ? Theme.Palette.danger : Theme.Palette.label2)
                    .padding(.bottom, Theme.Spacing.s8)
            }

            formGroup {
                if filteredTerminologyEntries.isEmpty {
                    emptyEngineRow(settings.terminologyEntries.isEmpty ? "还没有术语" : "没有匹配的术语")
                } else {
                    ForEach(filteredTerminologyEntries) { entry in
                        terminologyEntryRow(entry)
                    }
                }
            }
            callout("术语会随每次翻译请求生成快照。机器翻译优先用占位符保护，LLM 会收到术语约束。")
        }
    }

    private var filteredTerminologyEntries: [TerminologyEntry] {
        let query = terminologySearchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return settings.terminologyEntries }
        return settings.terminologyEntries.filter { entry in
            entry.source.lowercased().contains(query)
                || entry.target.lowercased().contains(query)
                || (entry.note ?? "").lowercased().contains(query)
        }
    }

    private var terminologyEditor: some View {
        formGroup {
            settingRow("源词") {
                TextField("AI Agent", text: $terminologyDraft.source)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 240)
            }
            settingRow("译法") {
                TextField("AI Agent", text: $terminologyDraft.target)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 240)
            }
            settingRow("源语言") {
                Picker("", selection: $terminologyDraft.fromCode) {
                    Text("任意").tag("auto")
                    ForEach(languages, id: \.0) { code, name in Text(name).tag(code) }
                }
                .labelsHidden()
                .frame(width: 150)
            }
            settingRow("目标语言") {
                Picker("", selection: $terminologyDraft.toCode) {
                    ForEach(languages, id: \.0) { code, name in Text(name).tag(code) }
                }
                .labelsHidden()
                .frame(width: 150)
            }
            settingRow("大小写敏感") {
                Toggle("", isOn: $terminologyDraft.caseSensitive)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.small)
            }
            settingRow("启用") {
                Toggle("", isOn: $terminologyDraft.enabled)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.small)
            }
            settingRow("备注") {
                TextField("可选", text: $terminologyDraft.note)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 240)
            }
            HStack(spacing: Theme.Spacing.s8) {
                Spacer()
                Button("取消") { cancelTerminologyEdit() }
                    .buttonStyle(SettingsMiniButtonStyle())
                Button("保存") { saveTerminologyDraft() }
                    .buttonStyle(SettingsMiniButtonStyle(prominence: .accent))
            }
            .padding(.horizontal, Theme.Spacing.s12)
            .padding(.vertical, 8)
        }
    }

    private func terminologyEntryRow(_ entry: TerminologyEntry) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: Theme.Spacing.s8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(entry.source) -> \(entry.target)")
                        .font(Theme.Font.body)
                        .foregroundStyle(Theme.Palette.label)
                    Text(terminologySubtitle(entry))
                        .font(Theme.Font.caption)
                        .foregroundStyle(Theme.Palette.label3)
                        .lineLimit(1)
                }
                Spacer(minLength: Theme.Spacing.s8)
                Toggle("", isOn: terminologyEnabledBinding(entry))
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.small)
                IconButton("pencil", help: "编辑术语", size: 11) { editTerminologyEntry(entry) }
                IconButton("trash", help: "删除术语", size: 11) { deleteTerminologyEntry(entry) }
            }
            .padding(.horizontal, Theme.Spacing.s12)
            .padding(.vertical, 8)
            .frame(minHeight: 46)
            Divider()
        }
    }

    private func terminologyImportPreview(_ plan: TerminologyImportPlan) -> some View {
        formGroup {
            settingRow("导入预览") {
                Text("新增 \(plan.addedCount) · 覆盖 \(plan.overwrittenCount) · 冲突 \(plan.conflictCount)")
                    .font(Theme.Font.caption)
                    .foregroundStyle(plan.conflictCount > 0 ? Theme.Palette.warning : Theme.Palette.label2)
            }
            HStack(spacing: Theme.Spacing.s8) {
                Spacer()
                Button("取消") { pendingTerminologyImport = nil }
                    .buttonStyle(SettingsMiniButtonStyle())
                Button("确认导入") {
                    settings.applyTerminologyImport(plan)
                    pendingTerminologyImport = nil
                    terminologyNote = "已导入术语"
                    clearTerminologyNote()
                }
                .buttonStyle(SettingsMiniButtonStyle(prominence: .accent))
                .disabled(plan.importableEntries.isEmpty)
            }
            .padding(.horizontal, Theme.Spacing.s12)
            .padding(.vertical, 8)
        }
    }

    private func terminologySubtitle(_ entry: TerminologyEntry) -> String {
        let from = entry.from.code ?? "auto"
        let to = entry.to.code ?? ""
        var parts = ["\(from) -> \(to)"]
        if entry.caseSensitive { parts.append("大小写敏感") }
        if let note = entry.note, !note.isEmpty { parts.append(note) }
        return parts.joined(separator: " · ")
    }

    private func terminologyEnabledBinding(_ entry: TerminologyEntry) -> Binding<Bool> {
        Binding(
            get: {
                settings.terminologyEntries.first(where: { $0.id == entry.id })?.enabled ?? entry.enabled
            },
            set: { value in
                var updated = entry
                updated.enabled = value
                _ = settings.saveTerminologyEntry(updated)
            }
        )
    }

    private func beginNewTerminologyEntry() {
        terminologyDraft = TerminologyDraft(defaultTarget: settings.targetLanguageCode)
        editingTerminologyID = UUID()
        terminologyNote = ""
    }

    private func editTerminologyEntry(_ entry: TerminologyEntry) {
        terminologyDraft = TerminologyDraft(entry: entry, defaultTarget: settings.targetLanguageCode)
        editingTerminologyID = entry.id
        terminologyNote = ""
    }

    private func cancelTerminologyEdit() {
        editingTerminologyID = nil
        terminologyDraft = TerminologyDraft(defaultTarget: settings.targetLanguageCode)
        terminologyNote = ""
    }

    private func saveTerminologyDraft() {
        guard let editingTerminologyID else { return }
        let existing = settings.terminologyEntries.first(where: { $0.id == editingTerminologyID })
        let entry = terminologyDraft.entry(id: existing?.id ?? editingTerminologyID)
        switch settings.saveTerminologyEntry(entry) {
        case .success:
            if TerminologyStore.hasOverlap(entry, in: settings.terminologyEntries) {
                terminologyNote = "已保存。存在包含关系，翻译时会优先匹配更长术语。"
            } else {
                terminologyNote = "已保存术语"
            }
            self.editingTerminologyID = nil
            terminologyDraft = TerminologyDraft(defaultTarget: settings.targetLanguageCode)
            clearTerminologyNote()
        case .failure(.emptySourceOrTarget):
            terminologyNote = "保存失败：源词和译法不能为空"
        case .failure(.duplicate):
            terminologyNote = "保存失败：相同语言对下已有重复源词"
        }
    }

    private func deleteTerminologyEntry(_ entry: TerminologyEntry) {
        settings.deleteTerminologyEntry(entry.id)
        if editingTerminologyID == entry.id {
            cancelTerminologyEdit()
        }
        terminologyNote = "已删除术语"
        clearTerminologyNote()
    }

    private func importTerminologyCSV() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.commaSeparatedText, .plainText]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let csv = try String(contentsOf: url, encoding: .utf8)
            pendingTerminologyImport = try settings.terminologyImportPlan(csv: csv)
            terminologyNote = ""
        } catch {
            terminologyNote = "导入失败：CSV 格式不正确"
            clearTerminologyNote(after: 4)
        }
    }

    private func exportTerminologyCSV() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.commaSeparatedText]
        panel.nameFieldStringValue = "parrot-terminology.csv"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try settings.terminologyCSV().write(to: url, atomically: true, encoding: .utf8)
            terminologyNote = "已导出术语"
            clearTerminologyNote()
        } catch {
            terminologyNote = "导出失败：无法写入文件"
            clearTerminologyNote(after: 4)
        }
    }

    private func clearTerminologyNote(after seconds: Double = 2.5) {
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds) {
            terminologyNote = ""
        }
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
        VStack(alignment: .leading, spacing: Theme.Spacing.s12) {
            keyPaneHeader
            keySummaryGrid
            keySearchAndFilter
            selectedCredentialForm
            keyServiceSections
            keyFootnote
        }
    }

    private var keyPaneHeader: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.s16) {
            VStack(alignment: .leading, spacing: 3) {
                Text("密钥")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(Theme.Palette.label)
                Text("默认展示需要处理和已生效的服务；完整 provider 目录通过选择器添加，不再把所有低频服务平铺在主页面。")
                    .font(Theme.Font.body)
                    .foregroundStyle(Theme.Palette.label2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: Theme.Spacing.s16)
            Button {
                providerPickerSearchText = ""
                showProviderPicker = true
            } label: {
                Label("添加 Provider", systemImage: "plus")
            }
            .buttonStyle(SettingsMiniButtonStyle(prominence: .accent))
            .popover(isPresented: $showProviderPicker, arrowEdge: .top) {
                keyProviderPicker
                    .frame(width: 390, height: 500)
                    .padding(Theme.Spacing.s12)
                    .background(Theme.Palette.bgWindow)
            }
        }
    }

    private var keySummaryGrid: some View {
        HStack(spacing: 10) {
            keySummaryCard(value: keyDescriptorsNeedingAttention.count, label: "需处理", color: Theme.Palette.warning)
            keySummaryCard(value: keyConfiguredDescriptorCount, label: "已配置", color: Theme.Palette.success)
            keySummaryCard(value: keyEnvironmentDescriptorCount, label: "环境变量", color: Color(nsColor: .systemBlue))
        }
    }

    private func keySummaryCard(value: Int, label: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s4) {
            Text("\(value)")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(color)
                .monospacedDigit()
            Text(L(label))
                .font(Theme.Font.callout)
                .foregroundStyle(Theme.Palette.label2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Spacing.s12)
        .frame(minHeight: 74)
        .background(Theme.Palette.bgContent)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Theme.Palette.hairline, lineWidth: 0.5))
    }

    private var keySearchAndFilter: some View {
        VStack(alignment: .leading, spacing: 10) {
            NativeSearchField("搜索服务、Key 或环境变量", text: $keySearchText)
                .frame(maxWidth: 420, minHeight: 28, alignment: .leading)

            HStack(spacing: 7) {
                ForEach(KeyFilter.allCases) { filter in
                    Button(filter.title) {
                        keyFilter = filter
                    }
                    .buttonStyle(KeyFilterChipStyle(selected: keyFilter == filter))
                }
                Spacer(minLength: 0)
            }
        }
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
            keyEmptyState
        } else {
            keySectionHeader
            VStack(spacing: Theme.Spacing.s8) {
                ForEach(descriptors) { descriptor in
                    credentialServiceCard(descriptor, highlighted: descriptor.matchesServiceID(focusedServiceID))
                }
            }
        }
    }

    private var keySectionHeader: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(keySectionTitle)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.Palette.label)
            Spacer()
            Text(keySectionMeta)
                .font(Theme.Font.callout)
                .foregroundStyle(Theme.Palette.label3)
        }
    }

    private var keyFootnote: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.s8) {
            Image(systemName: "key.fill")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color(nsColor: .systemBlue))
                .frame(width: 28, height: 28)
                .background(Color(nsColor: .systemBlue).opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            VStack(alignment: .leading, spacing: 2) {
                Text("密钥存储在本机密钥库")
                    .font(Theme.Font.body)
                    .foregroundStyle(Theme.Palette.label)
                Text("存储路径：~/Library/Application Support/Parrot/secrets.json。环境变量和系统配置优先于本机保存；清除 Key 不会影响历史记录、收藏或当前草稿。")
                    .font(Theme.Font.callout)
                    .foregroundStyle(Theme.Palette.label2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(Theme.Spacing.s12)
        .background(Theme.Palette.bgContent)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Theme.Palette.hairline, lineWidth: 0.5))
    }

    private var keyProviderPicker: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("选择 Provider")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.Palette.label)
                    Text("按服务类型选择，不把低频 provider 固定平铺。")
                        .font(Theme.Font.callout)
                        .foregroundStyle(Theme.Palette.label2)
                }
                Spacer()
                Button {
                    showProviderPicker = false
                } label: {
                    Image(systemName: "xmark")
                }
                .buttonStyle(.borderless)
                .foregroundStyle(Theme.Palette.label2)
            }

            NativeSearchField("OpenAI、DeepL、OCR、腾讯…", text: $providerPickerSearchText)
                .frame(height: 28)

            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.s12) {
                    let descriptors = providerPickerVisibleDescriptors
                    if descriptors.isEmpty {
                        keyEmptyState
                    } else {
                        ForEach(providerPickerGroups, id: \.title) { group in
                            let section = group.descriptors
                            if !section.isEmpty {
                                Text(group.title)
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(Theme.Palette.label3)
                                    .textCase(.uppercase)
                                VStack(spacing: Theme.Spacing.s4) {
                                    ForEach(section) { descriptor in
                                        providerPickerRow(descriptor)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private func providerPickerRow(_ descriptor: CredentialDescriptor) -> some View {
        Button {
            selectCredentialDescriptor(descriptor)
        } label: {
            HStack(spacing: Theme.Spacing.s8) {
                keyProviderLogo(descriptor, size: 34)
                VStack(alignment: .leading, spacing: 2) {
                    Text(descriptor.name)
                        .font(Theme.Font.body.weight(.semibold))
                        .foregroundStyle(Theme.Palette.label)
                        .lineLimit(1)
                    Text(keyProviderSubtitle(for: descriptor))
                        .font(Theme.Font.caption)
                        .foregroundStyle(Theme.Palette.label3)
                        .lineLimit(1)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.Palette.label3)
            }
            .padding(8)
            .frame(minHeight: 56)
            .background(Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
    }

    private var keyEmptyState: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("没有匹配的 Provider")
                .font(Theme.Font.body.weight(.semibold))
                .foregroundStyle(Theme.Palette.label)
            Text("清空搜索，或通过添加 Provider 打开完整目录。")
                .font(Theme.Font.callout)
                .foregroundStyle(Theme.Palette.label2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Theme.Palette.bgContent)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Theme.Palette.hairline, lineWidth: 0.5))
    }

    private func credentialServiceCard(_ descriptor: CredentialDescriptor, highlighted: Bool) -> some View {
        let status = credentialDisplayStatus(for: descriptor)
        let active = isCredentialServiceActive(descriptor)
        let dirty = isCredentialServiceDirty(descriptor)
        let tone = keyTone(for: descriptor)

        return Button {
            focusedServiceID = descriptor.id
        } label: {
            HStack(alignment: .center, spacing: 10) {
                keyProviderLogo(descriptor)
                VStack(alignment: .leading, spacing: 2) {
                    Text(descriptor.name)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.Palette.label)
                        .lineLimit(1)
                    Text(status.text)
                        .font(Theme.Font.caption)
                        .foregroundStyle(Theme.Palette.label3)
                        .lineLimit(1)
                }
                Spacer(minLength: Theme.Spacing.s12)
                if dirty {
                    settingsStatusBadge("未保存", tone: .secondary)
                }
                if active {
                    settingsStatusBadge("使用中", tone: .success)
                }
                keyProviderPill(text: keyProviderStatusText(for: descriptor), tone: tone)
            }
        }
        .buttonStyle(.plain)
        .id(descriptor.id)
        .padding(10)
        .frame(minHeight: 64)
        .background(highlighted ? Theme.Palette.bgSelection : Theme.Palette.bgContent)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(highlighted ? Theme.Palette.accent.opacity(0.65) : Theme.Palette.hairline, lineWidth: highlighted ? 1 : 0.5)
        )
    }

    @ViewBuilder
    private var selectedCredentialForm: some View {
        if let descriptor = selectedCredentialDescriptor {
            credentialDetailForm(descriptor)
                .id(descriptor.id)
        }
    }

    private func credentialDetailForm(_ descriptor: CredentialDescriptor) -> some View {
        let status = credentialDisplayStatus(for: descriptor)
        let note = credentialNotes[descriptor.id]

        return VStack(alignment: .leading, spacing: Theme.Spacing.s12) {
            HStack(alignment: .center, spacing: 10) {
                keyProviderLogo(descriptor)
                VStack(alignment: .leading, spacing: 2) {
                    Text(descriptor.name)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.Palette.label)
                    Text(status.fromPrimaryEnv ? L("环境变量已生效，本机 Key 可作为备用。") : (descriptor.note ?? L("配置这个 Provider 的 Key、Model 与 Endpoint。")))
                        .font(Theme.Font.caption)
                        .foregroundStyle(Theme.Palette.label2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                Button {
                    focusedServiceID = nil
                } label: {
                    Image(systemName: "xmark")
                }
                .buttonStyle(.borderless)
                .foregroundStyle(Theme.Palette.label2)
            }

            if let credential = descriptor.credential {
                VStack(alignment: .leading, spacing: Theme.Spacing.s8) {
                    credentialSecretRow(
                        descriptor: descriptor,
                        credential: credential,
                        status: status,
                        dirty: isCredentialServiceDirty(descriptor)
                    )
                    if status.fromPrimaryEnv {
                        formHelpText(L("%@ 已生效并优先于本机保存。要改用本机 Key，请移除该环境变量后重启 Parrot。", credential.env))
                    }
                }
            }

            if descriptor.defaultModel != nil || descriptor.defaultEndpoint != nil {
                VStack(alignment: .leading, spacing: Theme.Spacing.s8) {
                    if descriptor.defaultModel != nil {
                        credentialModelList(descriptor)
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
                if let credential = descriptor.credential {
                    Button("清除") { clearSecret(credential.account, serviceID: descriptor.id) }
                        .buttonStyle(SettingsMiniButtonStyle())
                        .disabled(!settings.hasStoredSecret(account: credential.account))
                }
                if canRetryFromCredential(descriptor) {
                    Button("保存并重试") { saveAndRetryCredentialService(descriptor) }
                        .buttonStyle(SettingsMiniButtonStyle(prominence: .accent))
                } else {
                    Button("保存到本机") { saveCredentialService(descriptor) }
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
        .padding(14)
        .background(Theme.Palette.bgContent)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Theme.Palette.accent.opacity(0.28), lineWidth: 1.5))
    }

    private func credentialSecretRow(
        descriptor: CredentialDescriptor,
        credential: EngineCredential,
        status: (text: String, configured: Bool, fromPrimaryEnv: Bool, fromFallback: Bool),
        dirty: Bool
    ) -> some View {
        HStack(alignment: .center, spacing: Theme.Spacing.s8) {
            formRowLabel(credential.account.contains("credentials") ? "Credentials" : "API Key")
            SecureField(credentialPlaceholder(for: descriptor, status: status),
                        text: secretBinding(for: credential.account))
                .textFieldStyle(.roundedBorder)
                .controlSize(.small)
                .font(Theme.Font.callout)
                .focused($focusedCredentialFieldID, equals: descriptor.id)
                .disabled(status.fromPrimaryEnv)
                .frame(minWidth: 180, idealWidth: 320, maxWidth: 380, minHeight: 22, idealHeight: 22, maxHeight: 22)
            if dirty {
                settingsStatusBadge("未保存", tone: .secondary)
            }
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

    private func credentialModelList(_ descriptor: CredentialDescriptor) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s8) {
            HStack(spacing: Theme.Spacing.s8) {
                formRowLabel("Model")
                Text(L("模型"))
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Palette.label2)
                Spacer(minLength: 0)
                Button {
                    addModelConfig(for: descriptor)
                } label: {
                    Label("新增", systemImage: "plus")
                }
                .buttonStyle(SettingsMiniButtonStyle())
            }

            ForEach(Array(modelConfigsDraft(for: descriptor).enumerated()), id: \.element.id) { index, model in
                modelConfigRow(model, descriptor: descriptor, index: index)
            }
        }
    }

    private func modelConfigRow(
        _ model: EngineModelConfig,
        descriptor: CredentialDescriptor,
        index: Int
    ) -> some View {
        HStack(alignment: .center, spacing: Theme.Spacing.s8) {
            Spacer()
                .frame(width: 64)
            TextField(descriptor.defaultModel ?? "model", text: modelNameBinding(for: descriptor, modelID: model.id))
                .textFieldStyle(.roundedBorder)
                .controlSize(.small)
                .font(Theme.Font.callout)
                .frame(minWidth: 180, idealWidth: 300, maxWidth: 360, minHeight: 22, idealHeight: 22, maxHeight: 22)
            Toggle("", isOn: modelEnabledBinding(for: descriptor, modelID: model.id))
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
                .help(L("启用模型"))
            IconButton("trash", help: "删除模型", size: 11) {
                removeModelConfig(model.id, from: descriptor)
            }
            .disabled(model.id == EngineModelConfig.primaryID || modelConfigsDraft(for: descriptor).count <= 1)
            if index == 0 {
                Text("默认")
                    .font(Theme.Font.tag)
                    .foregroundStyle(Theme.Palette.label2)
                    .padding(.horizontal, 6)
                    .frame(height: 18)
                    .background(Theme.Palette.bgControl)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.control))
            }
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

    enum KeyProviderTone {
        case need, ready, env, plain
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
           modelConfigsDraft(for: descriptor) != currentModelConfigs(for: descriptor) {
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
            saveModelConfigs(modelConfigsDraft(for: descriptor), for: descriptor)
            modelListDrafts[descriptor.id] = currentModelConfigs(for: descriptor)
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
        if let descriptor = CredentialCatalog.descriptor(matching: normalized) {
            keyFilter = preferredKeyFilter(for: descriptor)
        } else {
            keyFilter = .needsAction
        }
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
        case .needsAction:
            return descriptor.requiresCredential
                && isCredentialServiceActive(descriptor)
                && !credentialDisplayStatus(for: descriptor).configured
        case .configured:
            return credentialDisplayStatus(for: descriptor).configured
        case .environment:
            return credentialDisplayStatus(for: descriptor).fromPrimaryEnv
        case .llm:
            return descriptor.category == .llm || descriptor.defaultModel != nil
        case .media:
            return descriptor.category == .ocr
                || descriptor.category == .tts
                || descriptor.aliases.contains(settings.ttsProviderId)
        case .all:
            return true
        }
    }

    private var selectedCredentialDescriptor: CredentialDescriptor? {
        guard let focusedServiceID else { return nil }
        return CredentialCatalog.descriptor(matching: focusedServiceID)
    }

    private var keyConfiguredDescriptorCount: Int {
        allCredentialDescriptors.filter { descriptor in
            let status = credentialDisplayStatus(for: descriptor)
            return status.configured && !status.fromPrimaryEnv
        }.count
    }

    private var keyEnvironmentDescriptorCount: Int {
        allCredentialDescriptors.filter { credentialDisplayStatus(for: $0).fromPrimaryEnv }.count
    }

    private var keySectionTitle: String {
        switch keyFilter {
        case .needsAction: return L("优先处理")
        case .configured: return L("已配置")
        case .environment: return L("环境变量")
        case .llm: return "LLM Providers"
        case .media: return "OCR / TTS"
        case .all: return L("全部卡片")
        }
    }

    private var keySectionMeta: String {
        switch keyFilter {
        case .needsAction: return L("缺 Key / 当前启用")
        case .configured: return L("可直接使用")
        case .environment: return L("系统配置优先")
        case .llm: return L("模型 / Endpoint")
        case .media: return L("识别与语音")
        case .all: return L("当前可管理服务")
        }
    }

    private var providerPickerVisibleDescriptors: [CredentialDescriptor] {
        let query = providerPickerSearchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return allCredentialDescriptors }
        return allCredentialDescriptors.filter { $0.searchableText.contains(query) }
    }

    private var providerPickerGroups: [(title: String, descriptors: [CredentialDescriptor])] {
        let descriptors = providerPickerVisibleDescriptors
        let common = descriptors.filter { $0.category == .common }
        let commonIDs = Set(common.map(\.id))
        let llm = descriptors.filter {
            !commonIDs.contains($0.id) && ($0.category == .llm || $0.defaultModel != nil)
        }
        let groupedIDs = commonIDs.union(llm.map(\.id))
        let media = descriptors.filter {
            !groupedIDs.contains($0.id) && ($0.category == .ocr || $0.category == .tts)
        }
        let mediaIDs = groupedIDs.union(media.map(\.id))
        let vendors = descriptors.filter { descriptor in
            !mediaIDs.contains(descriptor.id)
                && (descriptor.category == .machine || descriptor.category == .more)
        }
        return [
            (L("常用"), common),
            ("LLM", llm),
            ("OCR & TTS", media),
            (L("云厂商"), vendors)
        ].filter { !$0.descriptors.isEmpty }
    }

    private func selectCredentialDescriptor(_ descriptor: CredentialDescriptor) {
        focusedServiceID = descriptor.id
        selection = .keys
        showProviderPicker = false
        providerPickerSearchText = ""
        if !keyDescriptor(descriptor, matches: keyFilter) {
            keyFilter = preferredKeyFilter(for: descriptor)
        }
    }

    private func preferredKeyFilter(for descriptor: CredentialDescriptor) -> KeyFilter {
        let status = credentialDisplayStatus(for: descriptor)
        if descriptor.requiresCredential && isCredentialServiceActive(descriptor) && !status.configured {
            return .needsAction
        }
        if status.fromPrimaryEnv { return .environment }
        if status.configured { return .configured }
        if descriptor.category == .llm || descriptor.defaultModel != nil { return .llm }
        if descriptor.category == .ocr || descriptor.category == .tts { return .media }
        return .all
    }

    private func keyTone(for descriptor: CredentialDescriptor) -> KeyProviderTone {
        let status = credentialDisplayStatus(for: descriptor)
        if status.fromPrimaryEnv { return .env }
        if status.configured { return .ready }
        if descriptor.requiresCredential && isCredentialServiceActive(descriptor) { return .need }
        return .plain
    }

    private func keyProviderStatusText(for descriptor: CredentialDescriptor) -> String {
        switch keyTone(for: descriptor) {
        case .env:
            return "Env"
        case .ready:
            return descriptor.requiresCredential ? L("已配置") : L("无需 Key")
        case .need:
            return descriptor.category == .ocr ? "OCR" : descriptor.category == .tts ? "TTS" : L("缺 Key")
        case .plain:
            return descriptor.requiresCredential ? L("可添加") : L("无需 Key")
        }
    }

    private func keyProviderSubtitle(for descriptor: CredentialDescriptor) -> String {
        let status = credentialDisplayStatus(for: descriptor)
        if status.fromPrimaryEnv { return status.text }
        if status.configured { return status.text }
        if let credential = descriptor.credential {
            if isCredentialServiceActive(descriptor) {
                return L("已启用 · Key 缺失 · %@", credential.env)
            }
            return credential.env
        }
        if let endpoint = descriptor.defaultEndpoint, !endpoint.isEmpty {
            return endpoint
        }
        return descriptor.note ?? L("无需 Key")
    }

    private func keyProviderLogo(_ descriptor: CredentialDescriptor, size: CGFloat = 38) -> some View {
        let title = keyProviderLogoTitle(for: descriptor)
        return Text(title)
            .font(.system(size: size >= 38 ? 12 : 11, weight: .bold))
            .foregroundStyle(keyLogoForeground(for: descriptor))
            .frame(width: size, height: size)
            .background(keyLogoBackground(for: descriptor))
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func keyProviderLogoTitle(for descriptor: CredentialDescriptor) -> String {
        switch descriptor.id {
        case "openai": return "AI"
        case "deepl": return "DL"
        case "google": return "G"
        case "opencode": return "OC"
        case "deepseek": return "DS"
        case "azure-openai": return "AZ"
        case "ollama": return "OL"
        case "google-tts": return "TTS"
        case "amazon": return "AWS"
        default:
            let trimmed = descriptor.name.trimmingCharacters(in: .whitespacesAndNewlines)
            return String(trimmed.prefix(1))
        }
    }

    private func keyLogoForeground(for descriptor: CredentialDescriptor) -> Color {
        switch keyTone(for: descriptor) {
        case .need: return Theme.Palette.warning
        case .ready: return Theme.Palette.success
        case .env: return Color(nsColor: .systemBlue)
        case .plain: return Theme.Palette.label2
        }
    }

    private func keyLogoBackground(for descriptor: CredentialDescriptor) -> Color {
        switch keyTone(for: descriptor) {
        case .need: return Theme.Palette.warning.opacity(0.16)
        case .ready: return Theme.Palette.success.opacity(0.14)
        case .env: return Color(nsColor: .systemBlue).opacity(0.12)
        case .plain: return Theme.Palette.bgControl
        }
    }

    private func keyProviderPill(text: String, tone: KeyProviderTone) -> some View {
        Text(text)
            .font(Theme.Font.callout.weight(.semibold))
            .foregroundStyle(keyPillForeground(tone))
            .padding(.horizontal, 9)
            .frame(minWidth: 58, minHeight: 24)
            .background(keyPillBackground(tone))
            .clipShape(Capsule())
    }

    private func keyPillForeground(_ tone: KeyProviderTone) -> Color {
        switch tone {
        case .need: return Theme.Palette.warning
        case .ready: return Theme.Palette.success
        case .env: return Color(nsColor: .systemBlue)
        case .plain: return Theme.Palette.label2
        }
    }

    private func keyPillBackground(_ tone: KeyProviderTone) -> Color {
        switch tone {
        case .need: return Theme.Palette.warning.opacity(0.16)
        case .ready: return Theme.Palette.success.opacity(0.14)
        case .env: return Color(nsColor: .systemBlue).opacity(0.12)
        case .plain: return Theme.Palette.bgControl
        }
    }

    private func secretBinding(for account: String) -> Binding<String> {
        Binding(
            get: { secretDrafts[account] ?? "" },
            set: { secretDrafts[account] = $0 }
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
        modelListDrafts = Dictionary(uniqueKeysWithValues: allCredentialDescriptors
            .filter { $0.defaultModel != nil }
            .map { ($0.id, currentModelConfigs(for: $0)) })
        endpointDrafts = Dictionary(uniqueKeysWithValues: allCredentialDescriptors
            .filter { $0.defaultEndpoint != nil }
            .map { ($0.id, currentEndpoint(for: $0)) })
    }

    private func currentModelConfigs(for descriptor: CredentialDescriptor) -> [EngineModelConfig] {
        settings.modelConfigs(for: descriptor.id, defaultModel: descriptor.defaultModel)
    }

    private func modelConfigsDraft(for descriptor: CredentialDescriptor) -> [EngineModelConfig] {
        modelListDrafts[descriptor.id] ?? currentModelConfigs(for: descriptor)
    }

    private func updateModelConfig(
        for descriptor: CredentialDescriptor,
        modelID: String,
        mutate: (inout EngineModelConfig) -> Void
    ) {
        var configs = modelConfigsDraft(for: descriptor)
        guard let index = configs.firstIndex(where: { $0.id == modelID }) else { return }
        mutate(&configs[index])
        modelListDrafts[descriptor.id] = configs
    }

    private func modelNameBinding(for descriptor: CredentialDescriptor, modelID: String) -> Binding<String> {
        Binding(
            get: {
                modelConfigsDraft(for: descriptor).first(where: { $0.id == modelID })?.name ?? ""
            },
            set: { value in
                updateModelConfig(for: descriptor, modelID: modelID) { $0.name = value }
            }
        )
    }

    private func modelEnabledBinding(for descriptor: CredentialDescriptor, modelID: String) -> Binding<Bool> {
        Binding(
            get: {
                modelConfigsDraft(for: descriptor).first(where: { $0.id == modelID })?.enabled ?? false
            },
            set: { value in
                updateModelConfig(for: descriptor, modelID: modelID) { $0.enabled = value }
            }
        )
    }

    private func addModelConfig(for descriptor: CredentialDescriptor) {
        var configs = modelConfigsDraft(for: descriptor)
        configs.append(EngineModelConfig(name: "", enabled: true))
        modelListDrafts[descriptor.id] = configs
    }

    private func removeModelConfig(_ modelID: String, from descriptor: CredentialDescriptor) {
        guard modelID != EngineModelConfig.primaryID else { return }
        var configs = modelConfigsDraft(for: descriptor)
        guard configs.count > 1 else { return }
        configs.removeAll { $0.id == modelID }
        modelListDrafts[descriptor.id] = configs
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
                saveModelConfigs(modelConfigsDraft(for: descriptor), for: descriptor)
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

    private func saveModelConfigs(_ configs: [EngineModelConfig], for descriptor: CredentialDescriptor) {
        let cleaned = configs.compactMap { config -> EngineModelConfig? in
            let name = config.trimmedName
            if name.isEmpty {
                guard config.id == EngineModelConfig.primaryID,
                      let defaultModel = descriptor.defaultModel,
                      !defaultModel.isEmpty else {
                    return nil
                }
                return EngineModelConfig(id: config.id, name: defaultModel, enabled: config.enabled)
            }
            return EngineModelConfig(id: config.id, name: name, enabled: config.enabled)
        }
        settings.setModelConfigs(cleaned, for: descriptor.id)
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
