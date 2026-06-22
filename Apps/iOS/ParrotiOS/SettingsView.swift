import ParrotPlatformiOS
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var state: IOSAppState
    @State private var pane: SettingsPane = .engines
    @State private var enabledEngines = ["Google 翻译", "DeepL", "OpenAI"]
    @State private var openAIKey = ""
    @State private var openAIModel = "gpt-4o-mini"
    @State private var openAIEndpoint = ""
    @State private var openAIEnabled = false
    @State private var keyFilter: KeyFilter = .all
    @State private var keySearch = ""
    @State private var note = "服务未配置；从失败结果进入时会聚焦这里。"

    private let store = IOSKeychainSecretStore()
    private let openAIAccount = "openai-compatible-api-key"

    var body: some View {
        VStack(spacing: 0) {
            AppHeader(leadingTitle: "Back", leadingAction: {
                state.selectedTab = .work
            }, title: "Engines") {
                MiniIconButton(systemName: "checkmark") {
                    pane = .keys
                    note = "Google 可用 · OpenAI 等待验证。"
                }
                .accessibilityLabel("Validate")
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("为当前工作区配置服务")
                            .font(.system(size: 10, weight: .heavy, design: .rounded))
                            .foregroundStyle(Color(red: 0.02, green: 0.23, blue: 0.12))
                        Spacer()
                        Button("Return") {
                            state.selectedTab = .work
                        }
                        .buttonStyle(.compactBlue)
                    }
                    .padding(8)
                    .background(IOSTheme.green.opacity(0.16))
                    .clipShape(RoundedRectangle(cornerRadius: IOSTheme.cardRadius, style: .continuous))

                    segmentedControl

                    Group {
                        switch pane {
                        case .engines:
                            enginesPane
                        case .keys:
                            keysPane
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
        .task { await loadOpenAIKey() }
    }

    private var segmentedControl: some View {
        HStack(spacing: 3) {
            ForEach(SettingsPane.allCases) { item in
                Button(item.title) {
                    pane = item
                }
                .font(.system(size: 10, weight: .heavy, design: .rounded))
                .foregroundStyle(pane == item ? Color(red: 0.02, green: 0.23, blue: 0.12) : IOSTheme.muted)
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
            Text("密钥只保存在本机。需要双字段凭证的服务使用 Id:Secret 格式；环境变量优先于本机保存。")
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(IOSTheme.muted)
                .fixedSize(horizontal: false, vertical: true)

            TextField("搜索服务、Key 或环境变量", text: $keySearch)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .padding(.horizontal, 9)
                .frame(height: 28)
                .background(IOSTheme.surface2)
                .clipShape(RoundedRectangle(cornerRadius: IOSTheme.cardRadius, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: IOSTheme.cardRadius, style: .continuous).stroke(IOSTheme.line))

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

            ForEach(visibleCredentialSections) { section in
                credentialSection(section)
            }

            VStack(alignment: .leading, spacing: 6) {
                Button("保存全部更改") {
                    Task { await saveOpenAIKey() }
                }
                .buttonStyle(.compactGreen)
                .frame(maxWidth: .infinity)
                Text("未保存的 Key、Model、Endpoint 会一起写入。")
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                    .foregroundStyle(IOSTheme.muted)
            }
            .padding(8)
            .parrotCard()

            Text("存储路径：iOS Keychain。环境变量和系统配置优先于本机保存。")
                .font(.system(size: 9, weight: .semibold, design: .rounded))
                .foregroundStyle(IOSTheme.muted)
        }
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
            Button("Validate OCR configuration") {
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
            StatusPill(text: name == "Google 翻译" ? "可用" : "需 Key", tone: name == "Google 翻译" ? .good : .warn)
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
                subtitle: openAIKey.isEmpty ? "未配置 · OPENAI_API_KEY" : "已配置 sk-•••• · local keychain",
                status: nil,
                dot: openAIKey.isEmpty ? IOSTheme.amber : IOSTheme.green,
                toggle: $openAIEnabled
            )
            HStack(alignment: .bottom, spacing: 5) {
                field("Key") {
                    SecureField("sk-...", text: $openAIKey)
                }
                Button("保存") { Task { await saveOpenAIKey() } }
                    .buttonStyle(.compactBlue)
                Button("清除") { Task { await clearOpenAIKey() } }
                    .buttonStyle(.compactMuted)
            }
            field("Model") {
                TextField("gpt-4o-mini", text: $openAIModel)
            }
            field("Endpoint") {
                TextField("可选", text: $openAIEndpoint)
            }
            HStack(spacing: 6) {
                Button("验证") {
                    Task { await validateOpenAIKey() }
                }
                .buttonStyle(.compactBlue)
                Button("保存并重试") {
                    Task {
                        await saveOpenAIKey()
                        state.selectedTab = .work
                    }
                }
                .buttonStyle(.compactBlue)
                Text(note)
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                    .foregroundStyle(IOSTheme.muted)
                    .lineLimit(2)
            }
        }
        .padding(7)
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
                toggle: .constant(false)
            )
            if let placeholder = item.keyPlaceholder {
                HStack(alignment: .bottom, spacing: 5) {
                    field("Key") {
                        TextField(placeholder, text: .constant(""))
                    }
                    Button("保存") {}
                        .buttonStyle(.compactBlue)
                    Button("清除") {}
                        .buttonStyle(.compactMuted)
                }
            }
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
            if let note = item.note {
                Text(note)
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                    .foregroundStyle(IOSTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(7)
        .parrotCard()
    }

    private func credentialHeader(
        title: String,
        tag: String,
        subtitle: String,
        status: String?,
        dot: Color,
        toggle: Binding<Bool>
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
                StatusPill(text: status, tone: status == "使用中" || status == "Env" ? .good : .warn)
            } else {
                Toggle("", isOn: toggle)
                    .labelsHidden()
                    .scaleEffect(0.72)
                    .frame(width: 38)
            }
        }
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
            }
            .buttonStyle(status == "Selected" ? .compactMuted : .compactBlue)
        }
        .padding(7)
        .parrotCard()
    }

    private var visibleCredentialSections: [CredentialSection] {
        credentialSections.compactMap { section in
            let filtered = section.items.filter { item in
                let q = keySearch.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                let matchesSearch = q.isEmpty || item.searchText.contains(q)
                let matchesFilter = keyFilter.matches(item)
                return matchesSearch && matchesFilter
            }
            return filtered.isEmpty ? nil : CredentialSection(title: section.title, meta: section.meta, items: filtered)
        }
    }

    private var credentialSections: [CredentialSection] {
        [
            CredentialSection(title: "需要处理", meta: "已启用但缺配置", items: [
                CredentialItem(id: "openai", name: "OpenAI", tag: "常用", subtitle: "未配置 · OPENAI_API_KEY", status: nil, state: [.needs], categories: [.common, .llm], dot: IOSTheme.amber, keyPlaceholder: "sk-...", model: "gpt-4o-mini", endpoint: "可选", note: nil),
                CredentialItem(id: "deepl", name: "DeepL", tag: "常用", subtitle: "未配置 · DEEPL_API_KEY", status: "使用中", state: [.needs], categories: [.common], dot: IOSTheme.amber, keyPlaceholder: "免费版以 :fx 结尾", note: "未配置：先输入并保存 Key。")
            ]),
            CredentialSection(title: "常用", meta: "Common", items: [
                CredentialItem(id: "google", name: "Google 翻译", tag: "常用", subtitle: "免费 · 无需 Key · 无需在线验证", status: "使用中", state: [.configured], categories: [.common], dot: IOSTheme.green),
                CredentialItem(id: "opencode", name: "OpenCode Go", tag: "常用", subtitle: "环境变量 OPENCODE_API_KEY 已生效", status: "Env", state: [.configured, .environment], categories: [.common, .llm], dot: IOSTheme.green, model: "glm-5.1", note: "OPENCODE_API_KEY 已生效并优先于本机保存。要改用本机 Key，请移除该环境变量后重启 Parrot。")
            ]),
            CredentialSection(title: "国内与云厂商", meta: "Machine", items: [
                CredentialItem(id: "tencent", name: "腾讯翻译君", tag: "云厂商", subtitle: "未配置凭证 · TENCENT_CREDENTIALS", status: nil, state: [], categories: [.machine], dot: IOSTheme.soft, keyPlaceholder: "SecretId:SecretKey"),
                CredentialItem(id: "baidu", name: "百度翻译", tag: "云厂商", subtitle: "未配置凭证 · BAIDU_CREDENTIALS", status: nil, state: [], categories: [.machine], dot: IOSTheme.soft, keyPlaceholder: "AppId:Secret"),
                CredentialItem(id: "youdao", name: "有道翻译", tag: "云厂商", subtitle: "未配置凭证 · YOUDAO_CREDENTIALS", status: nil, state: [], categories: [.machine], dot: IOSTheme.soft, keyPlaceholder: "AppKey:AppSecret")
            ]),
            CredentialSection(title: "LLM 服务", meta: "Model / Endpoint", items: [
                CredentialItem(id: "deepseek", name: "DeepSeek", tag: "LLM", subtitle: "未配置 · DEEPSEEK_API_KEY", status: nil, state: [], categories: [.llm], dot: IOSTheme.soft, keyPlaceholder: "API Key", model: "deepseek-chat"),
                CredentialItem(id: "ollama", name: "Ollama", tag: "LLM", subtitle: "本地服务 · 无需 Key", status: "可用", state: [.configured], categories: [.llm], dot: IOSTheme.green, endpoint: "http://127.0.0.1:11434/v1/chat/completions")
            ]),
            CredentialSection(title: "更多服务", meta: "More", items: [
                CredentialItem(id: "azure-openai", name: "Azure OpenAI", tag: "更多", subtitle: "未配置 · AZURE_OPENAI_API_KEY", status: nil, state: [], categories: [.more, .llm], dot: IOSTheme.soft, keyPlaceholder: "API Key", endpoint: "Azure deployment URL"),
                CredentialItem(id: "amazon", name: "Amazon 翻译", tag: "更多", subtitle: "未配置凭证 · AWS_CREDENTIALS", status: nil, state: [], categories: [.more], dot: IOSTheme.soft, keyPlaceholder: "AccessKeyId:SecretAccessKey")
            ]),
            CredentialSection(title: "文本识别", meta: "OCR", items: [
                CredentialItem(id: "baidu-ocr", name: "百度 OCR", tag: "OCR", subtitle: "BAIDU_OCR_CREDENTIALS · 可复用百度翻译凭证", status: "OCR", state: [.needs], categories: [.ocr], dot: IOSTheme.amber, keyPlaceholder: "AppId:Secret", note: "未填写专用 Key 时复用百度翻译凭证。"),
                CredentialItem(id: "tencent-ocr", name: "腾讯 OCR / 图片翻译", tag: "OCR", subtitle: "TENCENT_OCR_CREDENTIALS · 可复用腾讯翻译凭证", status: "OCR", state: [.needs], categories: [.ocr], dot: IOSTheme.amber, keyPlaceholder: "SecretId:SecretKey", note: "同时匹配 tencent-image-translate 和 tencent-tts 别名。"),
                CredentialItem(id: "google-ocr", name: "Google OCR", tag: "OCR", subtitle: "未配置 · GOOGLE_OCR_API_KEY", status: "OCR", state: [], categories: [.ocr], dot: IOSTheme.soft, keyPlaceholder: "API Key")
            ]),
            CredentialSection(title: "语音合成", meta: "TTS", items: [
                CredentialItem(id: "google-tts", name: "Google 语音合成", tag: "TTS", subtitle: "未配置 · GOOGLE_TTS_API_KEY", status: "TTS", state: [], categories: [.tts], dot: IOSTheme.soft, keyPlaceholder: "API Key"),
                CredentialItem(id: "microsoft-tts", name: "Microsoft 语音合成", tag: "TTS", subtitle: "MICROSOFT_TTS_KEY · 可复用 Microsoft 翻译凭证", status: "TTS", state: [.needs], categories: [.tts, .machine], dot: IOSTheme.amber, keyPlaceholder: "订阅 Key", note: "未填写专用 Key 时复用 Microsoft 翻译凭证。"),
                CredentialItem(id: "volcengine-tts", name: "火山语音合成", tag: "TTS", subtitle: "未配置 · VOLCENGINE_TTS_KEY", status: "TTS", state: [], categories: [.tts, .more], dot: IOSTheme.soft, keyPlaceholder: "API Key")
            ])
        ]
    }

    private func engineSubtitle(_ name: String) -> String {
        switch name {
        case "Google 翻译": return "免费 · 无需 Key"
        case "DeepL": return "DEEPL_API_KEY · 免费版以 :fx 结尾"
        case "OpenAI": return "OPENAI_API_KEY · \(openAIModel)"
        default: return "需要在 Keys 配置"
        }
    }

    private func loadOpenAIKey() async {
        openAIKey = (try? await store.get(account: openAIAccount)) ?? ""
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
            note = "已保存到 iOS Keychain。"
        } catch {
            note = "无法保存这个 Key。"
        }
    }

    private func clearOpenAIKey() async {
        openAIKey = ""
        try? await store.remove(account: openAIAccount)
        note = "OpenAI Key 已清除。"
    }

    private func validateOpenAIKey() async {
        let saved = (try? await store.get(account: openAIAccount)) ?? ""
        note = saved.isEmpty ? "默认 Google 翻译无需 Key；OpenAI 仍未配置。" : "验证通过。"
    }
}

private enum SettingsPane: String, CaseIterable, Identifiable {
    case engines
    case keys
    case media

    var id: String { rawValue }
    var title: String {
        switch self {
        case .engines: return "Engines"
        case .keys: return "Keys"
        case .media: return "OCR/TTS"
        }
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
