import ParrotCore
import ParrotPlatformiOS
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var state: IOSAppState
    @State private var pane: SettingsPane
    @State private var enabledEngines = ["Google 翻译", "DeepL", "OpenAI"]
    @State private var openAIKey = ""
    @State private var openAIModel = "gpt-4o-mini"
    @State private var openAIEndpoint = ""
    @State private var openAIEnabled = false
    @State private var keyFilter: KeyFilter = .needs
    @State private var keySearch = ""
    @State private var note = "从失败结果进入时，会聚焦到需要处理的服务。"
    @State private var showKeyFilters = false
    @State private var showOpenAIAdvanced = false
    @State private var expandedCredentialIDs: Set<String> = []
    @State private var credentialDrafts: [String: String] = [:]
    @State private var storedCredentialIDs: Set<String> = []
    @State private var terminologyState = TerminologyStoreState()
    @State private var terminologyDraft = IOSTerminologyDraft()
    @State private var terminologySearch = ""
    @State private var terminologyNote = ""

    private let store = IOSKeychainSecretStore()
    private let openAIAccount = "engine.openai.apiKey"
    private let legacyOpenAIAccount = "openai-compatible-api-key"
    private let credentialAccounts: [String: String] = [
        "deepl": "engine.deepl.apiKey",
        "tencent": "engine.tencent.credentials",
        "baidu": "engine.baidu.credentials",
        "youdao": "engine.youdao.credentials",
        "deepseek": "engine.deepseek.apiKey",
        "azure-openai": "engine.azure-openai.apiKey",
        "amazon": "engine.amazon.credentials",
        "baidu-ocr": "ocr.baidu.credentials",
        "tencent-ocr": "ocr.tencent.credentials",
        "google-ocr": "ocr.google.apiKey",
        "google-tts": "tts.google.apiKey",
        "microsoft-tts": "tts.microsoft.apiKey",
        "volcengine-tts": "tts.volcengine.apiKey"
    ]

    init() {
        _pane = State(initialValue: ProcessInfo.processInfo.arguments.contains("--ui-test-keys") ? .keys : .engines)
    }

    var body: some View {
        VStack(spacing: 0) {
            AppHeader(leadingTitle: "Back", leadingAction: {
                state.selectedTab = .work
            }, title: pane.title) {
                EmptyTrailing()
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    contextBanner

                    segmentedControl

                    Group {
                        switch pane {
                        case .engines:
                            enginesPane
                        case .keys:
                            keysPane
                        case .terminology:
                            terminologyPane
                        case .media:
                            mediaPane
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 78)
            }
            .scrollIndicators(.hidden)
        }
        .background(IOSTheme.paper.ignoresSafeArea())
        .task {
            await loadStoredCredentials()
            loadTerminologyState()
        }
    }

    private var contextBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.system(size: 11, weight: .heavy))
                .foregroundStyle(IOSTheme.greenDeep)
            VStack(alignment: .leading, spacing: 1) {
                Text(contextTitle)
                    .font(.system(size: 10, weight: .heavy, design: .rounded))
                    .foregroundStyle(IOSTheme.ink)
                Text(contextSubtitle)
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                    .foregroundStyle(IOSTheme.muted)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 7)
        .background(IOSTheme.green.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: IOSTheme.cardRadius, style: .continuous))
    }

    private var contextTitle: String {
        switch pane {
        case .keys:
            return "修复当前服务配置"
        case .terminology:
            return "同步桌面端术语能力"
        default:
            return "为当前工作区配置服务"
        }
    }

    private var contextSubtitle: String {
        switch pane {
        case .keys:
            return "先处理缺 Key 的服务，保存后返回工作区继续。"
        case .terminology:
            return "术语会写入 App Group，并随 Quick Lens / Understand 翻译请求使用。"
        default:
            return "翻译、Key、OCR/TTS 在这里集中管理。"
        }
    }

    private var segmentedControl: some View {
        HStack(spacing: 3) {
            ForEach(SettingsPane.allCases) { item in
                Button(item.title) {
                    pane = item
                }
                .font(.system(size: 10, weight: .heavy, design: .rounded))
                .foregroundStyle(pane == item ? IOSTheme.greenDeep : IOSTheme.muted)
                .lineLimit(1)
                .minimumScaleFactor(0.82)
                .frame(maxWidth: .infinity)
                .frame(height: 28)
                .background(pane == item ? IOSTheme.green.opacity(0.20) : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: IOSTheme.controlRadius, style: .continuous))
            }
        }
        .padding(3)
        .background(IOSTheme.subtleFill)
        .clipShape(RoundedRectangle(cornerRadius: IOSTheme.controlRadius, style: .continuous))
    }

    private var enginesPane: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("结果卡片按这里的已开启顺序显示；开启服务后到 Keys 配置 Key、Model 与 Endpoint。")
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(IOSTheme.muted)
                .fixedSize(horizontal: false, vertical: true)

            SectionTitle(left: "已开启顺序", right: "对齐桌面端")
            VStack(spacing: 7) {
                ForEach(Array(enabledEngines.enumerated()), id: \.element) { index, name in
                    engineOrderRow(name: name, index: index)
                }
            }

            engineGroup(title: "基础服务", meta: "同桌面端", items: [
                ("系统翻译", "macOS 15+ · iOS later"),
                ("Microsoft 翻译", "Key + region")
            ])
            engineGroup(title: "国内与云厂商", meta: "折叠分组", items: [
                ("腾讯翻译君", "SecretId:SecretKey"),
                ("百度翻译", "AppId:Secret"),
                ("有道翻译", "AppKey:AppSecret"),
                ("彩云小译", "Token")
            ])
            engineGroup(title: "LLM 服务", meta: "模型覆盖", items: [
                ("DeepSeek", "deepseek-chat"),
                ("Gemini", "GEMINI_API_KEY"),
                ("Ollama", "local · no key"),
                ("通义千问", "qwen-turbo")
            ])
        }
    }

    private var keysPane: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("只显示需要处理的服务。搜索或打开筛选后，可以查看已配置、环境变量、OCR、TTS 与 LLM。")
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(IOSTheme.muted)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 7) {
                TextField("搜索服务、Key 或环境变量", text: $keySearch)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .padding(.horizontal, 9)
                    .frame(height: 30)
                    .background(IOSTheme.surface2)
                    .clipShape(RoundedRectangle(cornerRadius: IOSTheme.cardRadius, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: IOSTheme.cardRadius, style: .continuous).stroke(IOSTheme.line))

                Button {
                    showKeyFilters.toggle()
                } label: {
                    Label(keyFilter.title, systemImage: "line.3.horizontal.decrease.circle")
                        .labelStyle(.iconOnly)
                }
                .buttonStyle(.compactMuted)
                .accessibilityLabel("Filter keys")
            }

            if showKeyFilters || keyFilter != .needs || !keySearch.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(KeyFilter.allCases) { filter in
                            Button(filter.title) {
                                keyFilter = filter
                            }
                            .font(.system(size: 9.5, weight: .heavy, design: .rounded))
                            .foregroundStyle(keyFilter == filter ? IOSTheme.greenDeep : IOSTheme.muted)
                            .padding(.horizontal, 8)
                            .frame(height: 22)
                            .background(keyFilter == filter ? IOSTheme.green.opacity(0.15) : IOSTheme.subtleFill)
                            .clipShape(Capsule())
                        }
                    }
                }
            }

            if visibleCredentialSections.isEmpty {
                emptyKeyResults
            } else {
                ForEach(visibleCredentialSections) { section in
                    credentialSection(section)
                }
            }

            if shouldShowBatchKeyActions {
                VStack(alignment: .leading, spacing: 6) {
                    Button("保存当前更改") {
                        Task { await saveOpenAIKey() }
                    }
                    .buttonStyle(.compactMuted)
                    .frame(maxWidth: .infinity)
                    Text("批量保存只处理有草稿的服务；单个失败服务优先使用卡片里的保存并重试。")
                        .font(.system(size: 9, weight: .semibold, design: .rounded))
                        .foregroundStyle(IOSTheme.muted)
                }
                .padding(8)
                .parrotCard()
            }

            Text("存储路径：iOS Keychain。环境变量和系统配置优先于本机保存。")
                .font(.system(size: 9, weight: .semibold, design: .rounded))
                .foregroundStyle(IOSTheme.muted)
        }
    }

    private var emptyKeyResults: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("没有匹配的服务")
                .font(.system(size: 11, weight: .heavy, design: .rounded))
                .foregroundStyle(IOSTheme.ink)
            Text("清空搜索，或切换筛选查看全部服务。")
                .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                .foregroundStyle(IOSTheme.muted)
            Button("查看全部") {
                keyFilter = .all
                keySearch = ""
                showKeyFilters = true
            }
            .buttonStyle(.compactBlue)
        }
        .padding(9)
        .parrotCard()
    }

    private var terminologyPane: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("术语表保证产品名、团队词和专业名词保持固定译法；禁用后不会随翻译请求发送。")
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(IOSTheme.muted)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 7) {
                HStack {
                    Text("启用术语表")
                        .font(.system(size: 11, weight: .heavy, design: .rounded))
                        .foregroundStyle(IOSTheme.ink)
                    Spacer()
                    Toggle("", isOn: Binding(
                        get: { terminologyState.isEnabled },
                        set: { value in
                            terminologyState.isEnabled = value
                            persistTerminologyState(note: value ? "术语表已启用。" : "术语表已禁用。")
                        }
                    ))
                    .labelsHidden()
                }
                HStack {
                    Text("严格模式")
                        .font(.system(size: 11, weight: .heavy, design: .rounded))
                        .foregroundStyle(terminologyState.isEnabled ? IOSTheme.ink : IOSTheme.muted)
                    Spacer()
                    Toggle("", isOn: Binding(
                        get: { terminologyState.strictMode },
                        set: { value in
                            terminologyState.strictMode = value
                            persistTerminologyState(note: value ? "严格模式已开启。" : "严格模式已关闭。")
                        }
                    ))
                    .labelsHidden()
                    .disabled(!terminologyState.isEnabled)
                }
            }
            .padding(9)
            .parrotCard()

            terminologyEditor

            HStack(spacing: 7) {
                TextField("搜索源词、译法或备注", text: $terminologySearch)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .padding(.horizontal, 9)
                    .frame(height: 30)
                    .background(IOSTheme.surface2)
                    .clipShape(RoundedRectangle(cornerRadius: IOSTheme.cardRadius, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: IOSTheme.cardRadius, style: .continuous).stroke(IOSTheme.line))
                StatusPill(text: "\(visibleTerminologyEntries.count)/\(terminologyState.entries.count)")
            }

            if visibleTerminologyEntries.isEmpty {
                VStack(alignment: .leading, spacing: 5) {
                    Text(terminologyState.entries.isEmpty ? "还没有术语" : "没有匹配的术语")
                        .font(.system(size: 11, weight: .heavy, design: .rounded))
                        .foregroundStyle(IOSTheme.ink)
                    Text("添加一个源词和目标译法后，Understand 和 Quick Lens 的翻译会使用同一份规则。")
                        .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                        .foregroundStyle(IOSTheme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(9)
                .parrotCard()
            } else {
                VStack(spacing: 7) {
                    ForEach(visibleTerminologyEntries) { entry in
                        terminologyRow(entry)
                    }
                }
            }

            if !terminologyNote.isEmpty {
                Text(terminologyNote)
                    .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(terminologyNote.contains("重复") || terminologyNote.contains("不能为空") ? IOSTheme.warnDeep : IOSTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var terminologyEditor: some View {
        VStack(alignment: .leading, spacing: 7) {
            SectionTitle(left: terminologyDraft.editingID == nil ? "新增术语" : "编辑术语")
            HStack(spacing: 7) {
                TextField("源词", text: $terminologyDraft.source)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .padding(.horizontal, 8)
                    .frame(height: 30)
                    .background(IOSTheme.surface2)
                    .clipShape(RoundedRectangle(cornerRadius: IOSTheme.cardRadius, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: IOSTheme.cardRadius, style: .continuous).stroke(IOSTheme.line))
                TextField("译法", text: $terminologyDraft.target)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .padding(.horizontal, 8)
                    .frame(height: 30)
                    .background(IOSTheme.surface2)
                    .clipShape(RoundedRectangle(cornerRadius: IOSTheme.cardRadius, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: IOSTheme.cardRadius, style: .continuous).stroke(IOSTheme.line))
            }

            HStack(spacing: 7) {
                Picker("From", selection: $terminologyDraft.from) {
                    ForEach(IOSTerminologyDraft.sourceLanguages, id: \.self) { language in
                        Text(languageTitle(language)).tag(language)
                    }
                }
                .labelsHidden()
                .frame(maxWidth: .infinity)
                .frame(height: 30)
                .background(IOSTheme.subtleFill)
                .clipShape(RoundedRectangle(cornerRadius: IOSTheme.controlRadius, style: .continuous))

                Image(systemName: "arrow.right")
                    .font(.system(size: 10, weight: .heavy))
                    .foregroundStyle(IOSTheme.muted)

                Picker("To", selection: $terminologyDraft.to) {
                    ForEach(IOSTerminologyDraft.targetLanguages, id: \.self) { language in
                        Text(languageTitle(language)).tag(language)
                    }
                }
                .labelsHidden()
                .frame(maxWidth: .infinity)
                .frame(height: 30)
                .background(IOSTheme.subtleFill)
                .clipShape(RoundedRectangle(cornerRadius: IOSTheme.controlRadius, style: .continuous))
            }

            TextField("备注（可选）", text: $terminologyDraft.note)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .padding(.horizontal, 8)
                .frame(height: 30)
                .background(IOSTheme.surface2)
                .clipShape(RoundedRectangle(cornerRadius: IOSTheme.cardRadius, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: IOSTheme.cardRadius, style: .continuous).stroke(IOSTheme.line))

            FlowLayout(spacing: 6) {
                Button(terminologyDraft.caseSensitive ? "区分大小写" : "忽略大小写") {
                    terminologyDraft.caseSensitive.toggle()
                }
                .buttonStyle(.compactMuted)
                Button(terminologyDraft.enabled ? "已启用" : "已停用") {
                    terminologyDraft.enabled.toggle()
                }
                .buttonStyle(terminologyDraft.enabled ? .compactBlue : .compactMuted)
                Button(terminologyDraft.editingID == nil ? "保存术语" : "保存修改") {
                    saveTerminologyDraft()
                }
                .buttonStyle(.compactGreen)
                Button("清空") {
                    terminologyDraft = IOSTerminologyDraft()
                    terminologyNote = ""
                }
                .buttonStyle(.compactMuted)
            }
        }
        .padding(9)
        .parrotCard()
    }

    private func terminologyRow(_ entry: TerminologyEntry) -> some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(entry.trimmedSource)
                        .font(.system(size: 11, weight: .heavy, design: .rounded))
                        .foregroundStyle(IOSTheme.ink)
                        .lineLimit(1)
                    Image(systemName: "arrow.right")
                        .font(.system(size: 9, weight: .heavy))
                        .foregroundStyle(IOSTheme.muted)
                    Text(entry.trimmedTarget)
                        .font(.system(size: 11, weight: .heavy, design: .rounded))
                        .foregroundStyle(IOSTheme.greenDeep)
                        .lineLimit(1)
                }
                FlowLayout(spacing: 5) {
                    StatusPill(text: "\(languageTitle(entry.from)) -> \(languageTitle(entry.to))")
                    StatusPill(text: entry.caseSensitive ? "Aa" : "aa")
                    StatusPill(text: entry.enabled ? "Enabled" : "Off", tone: entry.enabled ? .good : .neutral)
                }
                if let note = entry.note, !note.isEmpty {
                    Text(note)
                        .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                        .foregroundStyle(IOSTheme.muted)
                        .lineLimit(2)
                }
            }
            Spacer(minLength: 0)
            VStack(spacing: 6) {
                Button("Edit") {
                    terminologyDraft = IOSTerminologyDraft(entry: entry)
                    terminologyNote = ""
                }
                .buttonStyle(.compactBlue)
                Button("Delete") {
                    deleteTerminologyEntry(entry.id)
                }
                .buttonStyle(.compactMuted)
            }
        }
        .padding(9)
        .parrotCard()
    }

    private var shouldShowBatchKeyActions: Bool {
        showKeyFilters || keyFilter != .needs || !keySearch.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var mediaPane: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("OCR 与 TTS 有独立默认项；云端凭证统一在 Keys 管理，并可复用翻译凭证。")
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(IOSTheme.muted)

            SectionTitle(left: "Default OCR", right: "Text recognition")
            VStack(spacing: 7) {
                mediaRow(icon: "AV", title: "Apple Vision", subtitle: "离线默认可用 · no key", status: "Selected")
                mediaRow(icon: "百", title: "百度 OCR", subtitle: "Can reuse 百度翻译凭证", status: "Key")
                mediaRow(icon: "腾", title: "腾讯 OCR / 图片翻译", subtitle: "Can reuse 腾讯翻译凭证", status: "Key")
            }
            Button("验证 OCR 配置") {
                note = "Apple Vision OK · cloud OCR needs key"
            }
            .buttonStyle(.compactBlue)

            SectionTitle(left: "Default TTS", right: "Speech")
            VStack(spacing: 7) {
                mediaRow(icon: "SYS", title: "System voice", subtitle: "离线默认可用", status: "Selected")
                mediaRow(icon: "MS", title: "Microsoft TTS", subtitle: "Can reuse Microsoft 翻译 Key", status: "Key")
            }
        }
    }

    private func engineOrderRow(name: String, index: Int) -> some View {
        HStack(spacing: 7) {
            Text("\(index + 1)")
                .font(.system(size: 10, weight: .heavy, design: .rounded))
                .foregroundStyle(IOSTheme.greenDeep)
                .frame(width: 20, height: 20)
                .background(IOSTheme.green.opacity(0.14))
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                    .foregroundStyle(IOSTheme.ink)
                Text(engineSubtitle(name))
                    .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(IOSTheme.muted)
                    .lineLimit(2)
            }

            Spacer()
            StatusPill(text: name == "Google 翻译" ? "可用" : "缺 Key", tone: name == "Google 翻译" ? .good : .warn)
            reorderButton(systemName: "arrow.up", index: index, direction: -1)
            reorderButton(systemName: "arrow.down", index: index, direction: 1)
        }
        .padding(7)
        .parrotCard()
    }

    private func reorderButton(systemName: String, index: Int, direction: Int) -> some View {
        Button {
            let target = index + direction
            guard enabledEngines.indices.contains(index), enabledEngines.indices.contains(target) else { return }
            enabledEngines.swapAt(index, target)
        } label: {
            Image(systemName: systemName)
                .font(.system(size: 10, weight: .heavy))
        }
        .buttonStyle(.compactMuted)
    }

    private func engineGroup(title: String, meta: String, items: [(String, String)]) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            SectionTitle(left: title, right: meta)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 7) {
                ForEach(items, id: \.0) { item in
                    Button {
                        if !enabledEngines.contains(item.0) {
                            enabledEngines.append(item.0)
                        }
                        pane = .keys
                        keyFilter = .needs
                        showKeyFilters = false
                    } label: {
                        VStack(alignment: .leading, spacing: 7) {
                            Text(item.0)
                                .font(.system(size: 10.5, weight: .heavy, design: .rounded))
                                .foregroundStyle(IOSTheme.ink)
                                .lineLimit(1)
                            Text(item.1)
                                .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                                .foregroundStyle(IOSTheme.muted)
                                .lineLimit(2)
                        }
                        .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
                        .padding(7)
                        .parrotCard()
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func credentialSection(_ section: CredentialSection) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionTitle(left: section.title, right: section.meta)
            ForEach(section.items) { item in
                credentialCard(item)
            }
        }
    }

    @ViewBuilder
    private func credentialCard(_ item: CredentialItem) -> some View {
        if item.id == "openai" {
            openAICredentialCard
        } else {
            genericCredentialCard(item)
        }
    }

    private var openAICredentialCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            credentialHeader(
                title: "OpenAI",
                tag: "常用",
                subtitle: openAIKey.isEmpty ? "已启用 · Key 缺失 · OPENAI_API_KEY" : "已启用 · Key 已配置 · iOS Keychain",
                status: openAIKey.isEmpty ? "缺 Key" : "已配置",
                dot: openAIKey.isEmpty ? IOSTheme.amber : IOSTheme.green,
                toggle: $openAIEnabled,
                showsToggle: false
            )
            field("Key") {
                SecureField("sk-...", text: $openAIKey)
            }

            advancedToggle(isExpanded: $showOpenAIAdvanced)
            if showOpenAIAdvanced {
                VStack(alignment: .leading, spacing: 6) {
                    field("Model") {
                        TextField("gpt-4o-mini", text: $openAIModel)
                    }
                    field("Endpoint") {
                        TextField("可选", text: $openAIEndpoint)
                    }
                }
                .padding(.top, 4)
            }

            HStack(alignment: .center, spacing: 6) {
                Button("保存并重试") {
                    Task {
                        await saveOpenAIKey()
                        state.selectedTab = .work
                    }
                }
                .buttonStyle(.compactGreen)
                Button("验证") {
                    Task { await validateOpenAIKey() }
                }
                .buttonStyle(.compactBlue)
                Button("清除") { Task { await clearOpenAIKey() } }
                    .buttonStyle(.compactMuted)
                    .disabled(openAIKey.isEmpty)
            }

            HStack(spacing: 6) {
                Image(systemName: openAIKey.isEmpty ? "exclamationmark.circle" : "checkmark.circle")
                    .font(.system(size: 10, weight: .heavy))
                    .foregroundStyle(openAIKey.isEmpty ? IOSTheme.warnDeep : IOSTheme.greenDeep)
                Text(note)
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                    .foregroundStyle(IOSTheme.muted)
                    .lineLimit(2)
                Spacer(minLength: 0)
            }
        }
        .padding(9)
        .background(IOSTheme.meaningTint)
        .clipShape(RoundedRectangle(cornerRadius: IOSTheme.cardRadius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: IOSTheme.cardRadius, style: .continuous).stroke(IOSTheme.green.opacity(0.45), lineWidth: 1))
    }

    private func genericCredentialCard(_ item: CredentialItem) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            credentialHeader(
                title: item.name,
                tag: item.tag,
                subtitle: item.subtitle,
                status: item.status,
                dot: item.dot,
                toggle: .constant(false),
                showsToggle: false
            )
            if let placeholder = item.keyPlaceholder {
                field("Key") {
                    TextField(placeholder, text: credentialDraftBinding(for: item.id))
                }
            }
            if item.model != nil || item.endpoint != nil {
                advancedToggle(isExpanded: bindingForExpandedCredential(item.id))
                if expandedCredentialIDs.contains(item.id) {
                    VStack(alignment: .leading, spacing: 6) {
                        if let model = item.model {
                            field("Model") {
                                TextField(model, text: .constant(model))
                            }
                        }
                        if let endpoint = item.endpoint {
                            field("Endpoint") {
                                TextField(endpoint, text: .constant(endpoint))
                            }
                        }
                    }
                    .padding(.top, 4)
                }
            }
            if let note = item.note {
                Text(note)
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                    .foregroundStyle(IOSTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if item.keyPlaceholder != nil {
                HStack(spacing: 6) {
                    Button("保存并重试") {
                        Task { await saveGenericCredentialDraft(item) }
                    }
                    .buttonStyle(item.state.contains(.needs) ? .compactGreen : .compactMuted)
                    Button("验证") {
                        validateGenericCredentialDraft(item)
                    }
                    .buttonStyle(.compactBlue)
                    Button("清除") {
                        Task { await clearGenericCredential(item) }
                    }
                    .buttonStyle(.compactMuted)
                    .disabled((credentialDrafts[item.id] ?? "").isEmpty && !storedCredentialIDs.contains(item.id))
                }
            }
        }
        .padding(9)
        .parrotCard()
    }

    private func credentialHeader(
        title: String,
        tag: String,
        subtitle: String,
        status: String?,
        dot: Color,
        toggle: Binding<Bool>,
        showsToggle: Bool = true
    ) -> some View {
        HStack(spacing: 7) {
            Circle()
                .fill(dot)
                .frame(width: 8, height: 8)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 5) {
                    Text(title)
                        .font(.system(size: 11, weight: .heavy, design: .rounded))
                        .foregroundStyle(IOSTheme.ink)
                        .lineLimit(1)
                    Text(tag)
                        .font(.system(size: 8.5, weight: .heavy, design: .rounded))
                        .foregroundStyle(IOSTheme.muted)
                        .padding(.horizontal, 5)
                        .frame(height: 16)
                        .background(IOSTheme.subtleFill)
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                }
                Text(subtitle)
                    .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(IOSTheme.muted)
                    .lineLimit(2)
            }
            Spacer()
            if let status {
                StatusPill(text: status, tone: status == "使用中" || status == "Env" || status == "可用" || status == "已配置" ? .good : .warn)
            } else if showsToggle {
                Toggle("", isOn: toggle)
                    .labelsHidden()
                    .scaleEffect(0.72)
                    .frame(width: 38)
            }
        }
    }

    private func bindingForExpandedCredential(_ id: String) -> Binding<Bool> {
        Binding(
            get: { expandedCredentialIDs.contains(id) },
            set: { isExpanded in
                if isExpanded {
                    expandedCredentialIDs.insert(id)
                } else {
                    expandedCredentialIDs.remove(id)
                }
            }
        )
    }

    private func advancedToggle(isExpanded: Binding<Bool>) -> some View {
        Button {
            isExpanded.wrappedValue.toggle()
        } label: {
            HStack(spacing: 5) {
                Text("高级设置")
                    .font(.system(size: 9.5, weight: .heavy, design: .rounded))
                    .foregroundStyle(IOSTheme.muted)
                Image(systemName: isExpanded.wrappedValue ? "chevron.up" : "chevron.down")
                    .font(.system(size: 8.5, weight: .heavy))
                    .foregroundStyle(IOSTheme.soft)
                Spacer(minLength: 0)
            }
            .frame(height: 22)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func credentialDraftBinding(for id: String) -> Binding<String> {
        Binding(
            get: { credentialDrafts[id] ?? "" },
            set: { credentialDrafts[id] = $0 }
        )
    }

    private func saveGenericCredentialDraft(_ item: CredentialItem) async {
        let value = (credentialDrafts[item.id] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else {
            note = "先输入 \(item.name) Key，再保存并重试。"
            return
        }
        guard let account = item.account else {
            note = "\(item.name) 当前无需保存 Key。"
            return
        }
        do {
            try await store.set(value, account: account)
            credentialDrafts[item.id] = ""
            storedCredentialIDs.insert(item.id)
            note = "\(item.name) 已保存到 iOS Keychain。"
            state.selectedTab = .work
        } catch {
            note = "\(item.name) 保存失败，请稍后重试。"
        }
    }

    private func validateGenericCredentialDraft(_ item: CredentialItem) {
        let value = (credentialDrafts[item.id] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if value.isEmpty && !storedCredentialIDs.contains(item.id) {
            note = "先输入 \(item.name) Key，再验证。"
        } else {
            note = "\(item.name) 格式已填写；在线验证待接入。"
        }
    }

    private func clearGenericCredential(_ item: CredentialItem) async {
        credentialDrafts[item.id] = ""
        if let account = item.account {
            try? await store.remove(account: account)
        }
        storedCredentialIDs.remove(item.id)
        note = "\(item.name) Key 已清除。"
    }

    private func field<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.system(size: 9.5, weight: .heavy, design: .rounded))
                .foregroundStyle(IOSTheme.muted)
                .textCase(.uppercase)
            content()
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding(.horizontal, 9)
                .frame(height: 28)
                .background(IOSTheme.surface2)
                .clipShape(RoundedRectangle(cornerRadius: IOSTheme.cardRadius, style: .continuous))
        }
    }

    private func mediaRow(icon: String, title: String, subtitle: String, status: String) -> some View {
        HStack(spacing: 7) {
            Text(icon)
                .font(.system(size: 9, weight: .heavy, design: .rounded))
                .foregroundStyle(IOSTheme.greenDeep)
                .frame(width: 30, height: 30)
                .background(Color.white.opacity(0.65))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                    .foregroundStyle(IOSTheme.ink)
                Text(subtitle)
                    .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(IOSTheme.muted)
                    .lineLimit(1)
            }
            Spacer()
            Button(status) {
                pane = .keys
                if status != "Selected" {
                    keyFilter = .needs
                    showKeyFilters = false
                }
            }
            .buttonStyle(status == "Selected" ? .compactMuted : .compactBlue)
        }
        .padding(7)
        .parrotCard()
    }

    private var visibleCredentialSections: [CredentialSection] {
        let q = keySearch.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if q.isEmpty, keyFilter == .needs {
            return credentialSections.prefix(1).compactMap { section in
                let filtered = section.items.filter { keyFilter.matches($0) }
                return filtered.isEmpty ? nil : CredentialSection(title: section.title, meta: section.meta, items: filtered)
            }
        }

        return credentialSections.compactMap { section in
            let filtered = section.items.filter { item in
                let matchesSearch = q.isEmpty || item.searchText.contains(q)
                let matchesFilter = keyFilter.matches(item)
                return matchesSearch && matchesFilter
            }
            return filtered.isEmpty ? nil : CredentialSection(title: section.title, meta: section.meta, items: filtered)
        }
    }

    private var credentialSections: [CredentialSection] {
        let openAIConfigured = !openAIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return [
            CredentialSection(title: "需要处理", meta: "已启用但缺配置", items: [
                CredentialItem(id: "openai", name: "OpenAI", tag: "常用", subtitle: openAIConfigured ? "已启用 · Key 已配置 · iOS Keychain" : "已启用 · Key 缺失 · OPENAI_API_KEY", status: openAIConfigured ? "已配置" : "缺 Key", state: openAIConfigured ? [.configured] : [.needs], categories: [.common, .llm], dot: openAIConfigured ? IOSTheme.green : IOSTheme.amber, keyPlaceholder: "sk-...", model: "gpt-4o-mini", endpoint: "可选", note: nil),
                credentialItem(id: "deepl", name: "DeepL", tag: "常用", missingSubtitle: "已启用 · Key 缺失 · DEEPL_API_KEY", configuredSubtitle: "已启用 · Key 已配置 · iOS Keychain", missingStatus: "缺 Key", defaultState: [.needs], categories: [.common], keyPlaceholder: "免费版以 :fx 结尾", note: "未配置：先输入并保存 Key。")
            ]),
            CredentialSection(title: "常用", meta: "Common", items: [
                CredentialItem(id: "google", name: "Google 翻译", tag: "常用", subtitle: "免费 · 无需 Key · 无需在线验证", status: "使用中", state: [.configured], categories: [.common], dot: IOSTheme.green),
                CredentialItem(id: "opencode", name: "OpenCode Go", tag: "常用", subtitle: "环境变量 OPENCODE_API_KEY 已生效", status: "Env", state: [.configured, .environment], categories: [.common, .llm], dot: IOSTheme.green, model: "glm-5.1", note: "OPENCODE_API_KEY 已生效并优先于本机保存。要改用本机 Key，请移除该环境变量后重启 Parrot。")
            ]),
            CredentialSection(title: "国内与云厂商", meta: "Machine", items: [
                credentialItem(id: "tencent", name: "腾讯翻译君", tag: "云厂商", missingSubtitle: "未配置凭证 · TENCENT_CREDENTIALS", configuredSubtitle: "已配置 · iOS Keychain · TENCENT_CREDENTIALS", missingStatus: nil, defaultState: [], categories: [.machine], keyPlaceholder: "SecretId:SecretKey"),
                credentialItem(id: "baidu", name: "百度翻译", tag: "云厂商", missingSubtitle: "未配置凭证 · BAIDU_CREDENTIALS", configuredSubtitle: "已配置 · iOS Keychain · BAIDU_CREDENTIALS", missingStatus: nil, defaultState: [], categories: [.machine], keyPlaceholder: "AppId:Secret"),
                credentialItem(id: "youdao", name: "有道翻译", tag: "云厂商", missingSubtitle: "未配置凭证 · YOUDAO_CREDENTIALS", configuredSubtitle: "已配置 · iOS Keychain · YOUDAO_CREDENTIALS", missingStatus: nil, defaultState: [], categories: [.machine], keyPlaceholder: "AppKey:AppSecret")
            ]),
            CredentialSection(title: "LLM 服务", meta: "Model / Endpoint", items: [
                credentialItem(id: "deepseek", name: "DeepSeek", tag: "LLM", missingSubtitle: "未配置 · DEEPSEEK_API_KEY", configuredSubtitle: "已配置 · iOS Keychain · DEEPSEEK_API_KEY", missingStatus: nil, defaultState: [], categories: [.llm], keyPlaceholder: "API Key", model: "deepseek-chat"),
                CredentialItem(id: "ollama", name: "Ollama", tag: "LLM", subtitle: "本地服务 · 无需 Key", status: "可用", state: [.configured], categories: [.llm], dot: IOSTheme.green, endpoint: "http://127.0.0.1:11434/v1/chat/completions")
            ]),
            CredentialSection(title: "更多服务", meta: "More", items: [
                credentialItem(id: "azure-openai", name: "Azure OpenAI", tag: "更多", missingSubtitle: "未配置 · AZURE_OPENAI_API_KEY", configuredSubtitle: "已配置 · iOS Keychain · AZURE_OPENAI_API_KEY", missingStatus: nil, defaultState: [], categories: [.more, .llm], keyPlaceholder: "API Key", endpoint: "Azure deployment URL"),
                credentialItem(id: "amazon", name: "Amazon 翻译", tag: "更多", missingSubtitle: "未配置凭证 · AWS_CREDENTIALS", configuredSubtitle: "已配置 · iOS Keychain · AWS_CREDENTIALS", missingStatus: nil, defaultState: [], categories: [.more], keyPlaceholder: "AccessKeyId:SecretAccessKey")
            ]),
            CredentialSection(title: "文本识别", meta: "OCR", items: [
                credentialItem(id: "baidu-ocr", name: "百度 OCR", tag: "OCR", missingSubtitle: "BAIDU_OCR_CREDENTIALS · 可复用百度翻译凭证", configuredSubtitle: "已配置 · iOS Keychain · BAIDU_OCR_CREDENTIALS", missingStatus: "OCR", defaultState: [.needs], categories: [.ocr], keyPlaceholder: "AppId:Secret", note: "未填写专用 Key 时复用百度翻译凭证。"),
                credentialItem(id: "tencent-ocr", name: "腾讯 OCR / 图片翻译", tag: "OCR", missingSubtitle: "TENCENT_OCR_CREDENTIALS · 可复用腾讯翻译凭证", configuredSubtitle: "已配置 · iOS Keychain · TENCENT_OCR_CREDENTIALS", missingStatus: "OCR", defaultState: [.needs], categories: [.ocr], keyPlaceholder: "SecretId:SecretKey", note: "同时匹配 tencent-image-translate 和 tencent-tts 别名。"),
                credentialItem(id: "google-ocr", name: "Google OCR", tag: "OCR", missingSubtitle: "未配置 · GOOGLE_OCR_API_KEY", configuredSubtitle: "已配置 · iOS Keychain · GOOGLE_OCR_API_KEY", missingStatus: "OCR", defaultState: [], categories: [.ocr], keyPlaceholder: "API Key")
            ]),
            CredentialSection(title: "语音合成", meta: "TTS", items: [
                credentialItem(id: "google-tts", name: "Google 语音合成", tag: "TTS", missingSubtitle: "未配置 · GOOGLE_TTS_API_KEY", configuredSubtitle: "已配置 · iOS Keychain · GOOGLE_TTS_API_KEY", missingStatus: "TTS", defaultState: [], categories: [.tts], keyPlaceholder: "API Key"),
                credentialItem(id: "microsoft-tts", name: "Microsoft 语音合成", tag: "TTS", missingSubtitle: "MICROSOFT_TTS_KEY · 可复用 Microsoft 翻译凭证", configuredSubtitle: "已配置 · iOS Keychain · MICROSOFT_TTS_KEY", missingStatus: "TTS", defaultState: [.needs], categories: [.tts, .machine], keyPlaceholder: "订阅 Key", note: "未填写专用 Key 时复用 Microsoft 翻译凭证。"),
                credentialItem(id: "volcengine-tts", name: "火山语音合成", tag: "TTS", missingSubtitle: "未配置 · VOLCENGINE_TTS_KEY", configuredSubtitle: "已配置 · iOS Keychain · VOLCENGINE_TTS_KEY", missingStatus: "TTS", defaultState: [], categories: [.tts, .more], keyPlaceholder: "API Key")
            ])
        ]
    }

    private func credentialItem(
        id: String,
        name: String,
        tag: String,
        missingSubtitle: String,
        configuredSubtitle: String,
        missingStatus: String?,
        defaultState: [CredentialState],
        categories: [CredentialCategory],
        keyPlaceholder: String,
        model: String? = nil,
        endpoint: String? = nil,
        note: String? = nil
    ) -> CredentialItem {
        let configured = storedCredentialIDs.contains(id)
        return CredentialItem(
            id: id,
            name: name,
            tag: tag,
            subtitle: configured ? configuredSubtitle : missingSubtitle,
            status: configured ? "已配置" : missingStatus,
            state: configured ? credentialConfiguredState(from: defaultState) : defaultState,
            categories: categories,
            dot: configured ? IOSTheme.green : (defaultState.contains(.needs) ? IOSTheme.amber : IOSTheme.soft),
            account: credentialAccounts[id],
            keyPlaceholder: configured ? "输入新值以替换" : keyPlaceholder,
            model: model,
            endpoint: endpoint,
            note: configured ? nil : note
        )
    }

    private func credentialConfiguredState(from state: [CredentialState]) -> [CredentialState] {
        var next = state.filter { $0 != .needs }
        if !next.contains(.configured) {
            next.append(.configured)
        }
        return next
    }

    private func engineSubtitle(_ name: String) -> String {
        switch name {
        case "Google 翻译": return "免费 · 无需 Key"
        case "DeepL": return "DEEPL_API_KEY · 免费版以 :fx 结尾"
        case "OpenAI": return "OPENAI_API_KEY · \(openAIModel)"
        default: return "需要在 Keys 配置"
        }
    }

    private var visibleTerminologyEntries: [TerminologyEntry] {
        let query = terminologySearch.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let entries = terminologyState.entries.sorted {
            if $0.enabled != $1.enabled { return $0.enabled && !$1.enabled }
            return $0.trimmedSource.localizedCaseInsensitiveCompare($1.trimmedSource) == .orderedAscending
        }
        guard !query.isEmpty else { return entries }
        return entries.filter { entry in
            entry.trimmedSource.lowercased().contains(query)
                || entry.trimmedTarget.lowercased().contains(query)
                || (entry.note?.lowercased().contains(query) ?? false)
        }
    }

    private func loadTerminologyState() {
        terminologyState = state.loadTerminologyState()
    }

    private func persistTerminologyState(note: String) {
        state.saveTerminologyState(terminologyState)
        terminologyNote = note
    }

    private func saveTerminologyDraft() {
        let entry = terminologyDraft.entry()
        do {
            try TerminologyStore.validate(entry, against: terminologyState.entries)
        } catch TerminologyStoreError.emptySourceOrTarget {
            terminologyNote = "源词和译法不能为空。"
            return
        } catch TerminologyStoreError.duplicate {
            terminologyNote = "同一语言对里已经有重复源词。"
            return
        } catch {
            terminologyNote = "无法保存这个术语。"
            return
        }

        var next = terminologyState
        if let idx = next.entries.firstIndex(where: { $0.id == entry.id }) {
            next.entries[idx] = entry
        } else {
            next.entries.append(entry)
        }
        terminologyState = next
        persistTerminologyState(note: "术语已保存。")
        terminologyDraft = IOSTerminologyDraft()
    }

    private func deleteTerminologyEntry(_ id: UUID) {
        terminologyState.entries.removeAll { $0.id == id }
        persistTerminologyState(note: "术语已删除。")
        if terminologyDraft.editingID == id {
            terminologyDraft = IOSTerminologyDraft()
        }
    }

    private func languageTitle(_ language: Language) -> String {
        switch language {
        case .auto: return "Auto"
        case .zh: return "中文"
        case .en: return "English"
        case .ja: return "日本語"
        case .ko: return "한국어"
        case .fr: return "Français"
        case .de: return "Deutsch"
        case .es: return "Español"
        case .ru: return "Русский"
        case .custom(let code): return code
        }
    }

    private func loadStoredCredentials() async {
        await loadOpenAIKey()
        var loaded: Set<String> = []
        for (id, account) in credentialAccounts {
            if let value = try? await store.get(account: account), !value.isEmpty {
                loaded.insert(id)
            }
        }
        storedCredentialIDs = loaded
    }

    private func loadOpenAIKey() async {
        if let value = try? await store.get(account: openAIAccount), !value.isEmpty {
            openAIKey = value
            return
        }
        openAIKey = (try? await store.get(account: legacyOpenAIAccount)) ?? ""
    }

    private func saveOpenAIKey() async {
        let value = openAIKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else {
            try? await store.remove(account: openAIAccount)
            note = "Key 已清除；当前草稿和历史不会丢失。"
            return
        }
        do {
            try await store.set(value, account: openAIAccount)
            try? await store.remove(account: legacyOpenAIAccount)
            note = "已保存到 iOS Keychain。"
        } catch {
            note = "无法保存这个 Key。"
        }
    }

    private func clearOpenAIKey() async {
        openAIKey = ""
        try? await store.remove(account: openAIAccount)
        try? await store.remove(account: legacyOpenAIAccount)
        note = "OpenAI Key 已清除。"
    }

    private func validateOpenAIKey() async {
        let value = openAIKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.isEmpty {
            note = "先输入 OpenAI Key，再验证。"
        } else {
            note = "OpenAI Key 格式已填写；在线验证待接入。"
        }
    }
}

private enum SettingsPane: String, CaseIterable, Identifiable {
    case engines
    case keys
    case terminology
    case media

    var id: String { rawValue }
    var title: String {
        switch self {
        case .engines: return "Engines"
        case .keys: return "Keys"
        case .terminology: return "Terms"
        case .media: return "OCR/TTS"
        }
    }
}

private struct IOSTerminologyDraft: Equatable {
    var source = ""
    var target = ""
    var from: Language = .en
    var to: Language = .zh
    var note = ""
    var caseSensitive = false
    var enabled = true
    var editingID: UUID?

    static let sourceLanguages: [Language] = [.auto, .en, .zh, .ja, .ko]
    static let targetLanguages: [Language] = [.zh, .en, .ja, .ko]

    init() {}

    init(entry: TerminologyEntry) {
        source = entry.source
        target = entry.target
        from = entry.from
        to = entry.to
        note = entry.note ?? ""
        caseSensitive = entry.caseSensitive
        enabled = entry.enabled
        editingID = entry.id
    }

    func entry() -> TerminologyEntry {
        TerminologyEntry(
            id: editingID ?? UUID(),
            source: source.trimmingCharacters(in: .whitespacesAndNewlines),
            target: target.trimmingCharacters(in: .whitespacesAndNewlines),
            from: from,
            to: to,
            note: note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? nil
                : note.trimmingCharacters(in: .whitespacesAndNewlines),
            caseSensitive: caseSensitive,
            enabled: enabled
        )
    }
}

private enum CredentialCategory: String, CaseIterable {
    case common, machine, llm, more, ocr, tts
}

private enum CredentialState: String {
    case needs, configured, environment
}

private enum KeyFilter: CaseIterable, Identifiable {
    case all, needs, configured, environment, ocr, tts, llm

    var id: String { title }
    var title: String {
        switch self {
        case .all: return "全部"
        case .needs: return "需处理"
        case .configured: return "已配置"
        case .environment: return "环境变量"
        case .ocr: return "OCR"
        case .tts: return "TTS"
        case .llm: return "LLM"
        }
    }

    func matches(_ item: CredentialItem) -> Bool {
        switch self {
        case .all: return true
        case .needs: return item.state.contains(.needs)
        case .configured: return item.state.contains(.configured)
        case .environment: return item.state.contains(.environment)
        case .ocr: return item.categories.contains(.ocr)
        case .tts: return item.categories.contains(.tts)
        case .llm: return item.categories.contains(.llm)
        }
    }
}

private struct CredentialSection: Identifiable {
    let id = UUID()
    let title: String
    let meta: String
    let items: [CredentialItem]
}

private struct CredentialItem: Identifiable {
    let id: String
    let name: String
    let tag: String
    let subtitle: String
    let status: String?
    let state: [CredentialState]
    let categories: [CredentialCategory]
    let dot: Color
    var account: String?
    var keyPlaceholder: String?
    var model: String?
    var endpoint: String?
    var note: String?

    var searchText: String {
        ([id, name, tag, subtitle, status, keyPlaceholder, model, endpoint, note].compactMap { $0 })
            .joined(separator: " ")
            .lowercased()
    }
}
