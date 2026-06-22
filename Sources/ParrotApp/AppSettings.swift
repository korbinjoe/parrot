import Foundation
import ParrotCore

/// User-facing preferences, persisted to UserDefaults (non-secret) and SecretStore (API keys).
@MainActor
final class AppSettings: ObservableObject {
    private let defaults: UserDefaults
    private var keyCache: [String: String] = [:]
    private var missingKeyCache: Set<String> = []
    private let terminologyStore: TerminologyStore

    // MARK: - Secret account IDs

    static let deepLAccount = "engine.deepl.apiKey"
    static let openAIAccount = "engine.openai.apiKey"
    static let tencentAccount = "engine.tencent.credentials"
    static let baiduAccount = "engine.baidu.credentials"
    static let youdaoAccount = "engine.youdao.credentials"
    static let caiyunAccount = "engine.caiyun.token"
    static let microsoftAccount = "engine.microsoft.key"
    static let deepSeekAccount = "engine.deepseek.apiKey"
    static let geminiAccount = "engine.gemini.apiKey"
    static let groqAccount = "engine.groq.apiKey"
    static let ollamaAccount = "engine.ollama.apiKey"
    static let qwenAccount = "engine.qwen.apiKey"
    static let doubaoAccount = "engine.doubao.apiKey"
    static let kimiAccount = "engine.kimi.apiKey"
    static let zhipuAccount = "engine.zhipu.apiKey"
    static let siliconFlowAccount = "engine.siliconflow.apiKey"
    static let openCodeAccount = "engine.opencode.apiKey"

    @Published var targetLanguageCode: String {
        didSet { defaults.set(targetLanguageCode, forKey: "targetLanguageCode") }
    }
    @Published var sourceLanguageCode: String {
        didSet { defaults.set(sourceLanguageCode, forKey: "sourceLanguageCode") }
    }

    // MARK: - Engine toggles

    @Published var googleEnabled: Bool { didSet { defaults.set(googleEnabled, forKey: "engine.google.enabled") } }
    @Published var deepLEnabled: Bool { didSet { defaults.set(deepLEnabled, forKey: "engine.deepl.enabled") } }
    @Published var openAIEnabled: Bool { didSet { defaults.set(openAIEnabled, forKey: "engine.openai.enabled") } }
    @Published var tencentEnabled: Bool { didSet { defaults.set(tencentEnabled, forKey: "engine.tencent.enabled") } }
    @Published var baiduEnabled: Bool { didSet { defaults.set(baiduEnabled, forKey: "engine.baidu.enabled") } }
    @Published var youdaoEnabled: Bool { didSet { defaults.set(youdaoEnabled, forKey: "engine.youdao.enabled") } }
    @Published var caiyunEnabled: Bool { didSet { defaults.set(caiyunEnabled, forKey: "engine.caiyun.enabled") } }
    @Published var microsoftEnabled: Bool { didSet { defaults.set(microsoftEnabled, forKey: "engine.microsoft.enabled") } }
    @Published var appleEnabled: Bool { didSet { defaults.set(appleEnabled, forKey: "engine.apple.enabled") } }
    @Published var deepSeekEnabled: Bool { didSet { defaults.set(deepSeekEnabled, forKey: "engine.deepseek.enabled") } }
    @Published var geminiEnabled: Bool { didSet { defaults.set(geminiEnabled, forKey: "engine.gemini.enabled") } }
    @Published var groqEnabled: Bool { didSet { defaults.set(groqEnabled, forKey: "engine.groq.enabled") } }
    @Published var ollamaEnabled: Bool { didSet { defaults.set(ollamaEnabled, forKey: "engine.ollama.enabled") } }
    @Published var qwenEnabled: Bool { didSet { defaults.set(qwenEnabled, forKey: "engine.qwen.enabled") } }
    @Published var doubaoEnabled: Bool { didSet { defaults.set(doubaoEnabled, forKey: "engine.doubao.enabled") } }
    @Published var kimiEnabled: Bool { didSet { defaults.set(kimiEnabled, forKey: "engine.kimi.enabled") } }
    @Published var zhipuEnabled: Bool { didSet { defaults.set(zhipuEnabled, forKey: "engine.zhipu.enabled") } }
    @Published var siliconFlowEnabled: Bool { didSet { defaults.set(siliconFlowEnabled, forKey: "engine.siliconflow.enabled") } }
    @Published var openCodeEnabled: Bool { didSet { defaults.set(openCodeEnabled, forKey: "engine.opencode.enabled") } }
    @Published var ernieEnabled: Bool { didSet { defaults.set(ernieEnabled, forKey: "engine.ernie.enabled") } }
    @Published var hunyuanEnabled: Bool { didSet { defaults.set(hunyuanEnabled, forKey: "engine.hunyuan.enabled") } }
    @Published var yiEnabled: Bool { didSet { defaults.set(yiEnabled, forKey: "engine.yi.enabled") } }
    @Published var azureOpenAIEnabled: Bool { didSet { defaults.set(azureOpenAIEnabled, forKey: "engine.azure-openai.enabled") } }
    @Published var volcengineEnabled: Bool { didSet { defaults.set(volcengineEnabled, forKey: "engine.volcengine.enabled") } }
    @Published var aliyunEnabled: Bool { didSet { defaults.set(aliyunEnabled, forKey: "engine.aliyun.enabled") } }
    @Published var niutransEnabled: Bool { didSet { defaults.set(niutransEnabled, forKey: "engine.niutrans.enabled") } }
    @Published var amazonEnabled: Bool { didSet { defaults.set(amazonEnabled, forKey: "engine.amazon.enabled") } }

    // LLM model / endpoint overrides (non-secret)
    @Published var openAIModel: String { didSet { defaults.set(openAIModel, forKey: "engine.openai.model") } }
    @Published var openAIEndpoint: String { didSet { defaults.set(openAIEndpoint, forKey: "engine.openai.endpoint") } }
    @Published var ollamaEndpoint: String { didSet { defaults.set(ollamaEndpoint, forKey: "engine.ollama.endpoint") } }
    @Published var microsoftRegion: String { didSet { defaults.set(microsoftRegion, forKey: "engine.microsoft.region") } }

    // OCR / TTS
    @Published var ocrProviderId: String { didSet { defaults.set(ocrProviderId, forKey: "ocr.providerId") } }
    @Published var ttsProviderId: String { didSet { defaults.set(ttsProviderId, forKey: "tts.providerId") } }
    @Published var tencentOCRRegion: String { didSet { defaults.set(tencentOCRRegion, forKey: "ocr.tencent.region") } }
    @Published var amazonRegion: String { didSet { defaults.set(amazonRegion, forKey: "engine.amazon.region") } }

    @Published var terminologyEnabled: Bool {
        didSet { persistTerminologyState() }
    }
    @Published var terminologyStrictMode: Bool {
        didSet { persistTerminologyState() }
    }
    @Published var terminologyEntries: [TerminologyEntry] {
        didSet { persistTerminologyState() }
    }

    // Legacy placeholders (use static accounts in extension)
    @Published var baiduOCRAccount = "ocr.baidu.credentials"
    @Published var tencentOCRAccount = "ocr.tencent.credentials"

    init(defaults: UserDefaults = .standard, terminologyStore: TerminologyStore = TerminologyStore()) {
        self.defaults = defaults
        self.terminologyStore = terminologyStore
        let terminologyState = terminologyStore.loadState()
        self.targetLanguageCode = defaults.string(forKey: "targetLanguageCode") ?? "zh"
        self.sourceLanguageCode = defaults.string(forKey: "sourceLanguageCode") ?? "auto"
        self.googleEnabled = defaults.object(forKey: "engine.google.enabled") as? Bool ?? true
        self.deepLEnabled = defaults.object(forKey: "engine.deepl.enabled") as? Bool ?? true
        self.openAIEnabled = defaults.object(forKey: "engine.openai.enabled") as? Bool ?? true
        self.tencentEnabled = defaults.object(forKey: "engine.tencent.enabled") as? Bool ?? false
        self.baiduEnabled = defaults.object(forKey: "engine.baidu.enabled") as? Bool ?? false
        self.youdaoEnabled = defaults.object(forKey: "engine.youdao.enabled") as? Bool ?? false
        self.caiyunEnabled = defaults.object(forKey: "engine.caiyun.enabled") as? Bool ?? false
        self.microsoftEnabled = defaults.object(forKey: "engine.microsoft.enabled") as? Bool ?? false
        self.appleEnabled = defaults.object(forKey: "engine.apple.enabled") as? Bool ?? false
        self.deepSeekEnabled = defaults.object(forKey: "engine.deepseek.enabled") as? Bool ?? false
        self.geminiEnabled = defaults.object(forKey: "engine.gemini.enabled") as? Bool ?? false
        self.groqEnabled = defaults.object(forKey: "engine.groq.enabled") as? Bool ?? false
        self.ollamaEnabled = defaults.object(forKey: "engine.ollama.enabled") as? Bool ?? false
        self.qwenEnabled = defaults.object(forKey: "engine.qwen.enabled") as? Bool ?? false
        self.doubaoEnabled = defaults.object(forKey: "engine.doubao.enabled") as? Bool ?? false
        self.kimiEnabled = defaults.object(forKey: "engine.kimi.enabled") as? Bool ?? false
        self.zhipuEnabled = defaults.object(forKey: "engine.zhipu.enabled") as? Bool ?? false
        self.siliconFlowEnabled = defaults.object(forKey: "engine.siliconflow.enabled") as? Bool ?? false
        self.openCodeEnabled = defaults.object(forKey: "engine.opencode.enabled") as? Bool ?? false
        self.ernieEnabled = defaults.object(forKey: "engine.ernie.enabled") as? Bool ?? false
        self.hunyuanEnabled = defaults.object(forKey: "engine.hunyuan.enabled") as? Bool ?? false
        self.yiEnabled = defaults.object(forKey: "engine.yi.enabled") as? Bool ?? false
        self.azureOpenAIEnabled = defaults.object(forKey: "engine.azure-openai.enabled") as? Bool ?? false
        self.volcengineEnabled = defaults.object(forKey: "engine.volcengine.enabled") as? Bool ?? false
        self.aliyunEnabled = defaults.object(forKey: "engine.aliyun.enabled") as? Bool ?? false
        self.niutransEnabled = defaults.object(forKey: "engine.niutrans.enabled") as? Bool ?? false
        self.amazonEnabled = defaults.object(forKey: "engine.amazon.enabled") as? Bool ?? false
        self.openAIModel = defaults.string(forKey: "engine.openai.model") ?? "gpt-4o-mini"
        self.openAIEndpoint = defaults.string(forKey: "engine.openai.endpoint") ?? ""
        self.ollamaEndpoint = defaults.string(forKey: "engine.ollama.endpoint") ?? ""
        self.microsoftRegion = defaults.string(forKey: "engine.microsoft.region") ?? "eastasia"
        self.ocrProviderId = defaults.string(forKey: "ocr.providerId") ?? "apple-vision"
        self.ttsProviderId = defaults.string(forKey: "tts.providerId") ?? "system"
        self.tencentOCRRegion = defaults.string(forKey: "ocr.tencent.region") ?? "ap-guangzhou"
        self.amazonRegion = defaults.string(forKey: "engine.amazon.region") ?? "us-east-1"
        self.terminologyEnabled = terminologyState.isEnabled
        self.terminologyStrictMode = terminologyState.strictMode
        self.terminologyEntries = terminologyState.entries
    }

    /// Probe whether credentials for an engine are configured and accepted by the provider.
    func validateKey(for engineId: String) async -> Bool {
        guard let provider = EngineValidator.makeConfiguredProvider(id: engineId, settings: self) else { return false }
        return await EngineValidator.validate(provider)
    }

    var engineOrder: [String] { defaults.stringArray(forKey: "engine.order") ?? [] }
    func setEngineOrder(_ ids: [String]) { defaults.set(ids, forKey: "engine.order") }

    func shortcutSpec(for action: ShortcutAction) -> HotKeySpec {
        let key = "shortcut.\(action.rawValue)"
        guard let data = defaults.data(forKey: key),
              let spec = try? JSONDecoder().decode(HotKeySpec.self, from: data) else {
            return action.defaultSpec
        }
        return spec
    }

    func setShortcutSpec(_ spec: HotKeySpec, for action: ShortcutAction) {
        let key = "shortcut.\(action.rawValue)"
        if let data = try? JSONEncoder().encode(spec) {
            defaults.set(data, forKey: key)
            objectWillChange.send()
            NotificationCenter.default.post(name: .parrotShortcutsDidChange, object: nil)
        }
    }

    func resetShortcuts() {
        for action in ShortcutAction.allCases {
            defaults.removeObject(forKey: "shortcut.\(action.rawValue)")
        }
        objectWillChange.send()
        NotificationCenter.default.post(name: .parrotShortcutsDidChange, object: nil)
    }

    func model(for engineId: String) -> String? {
        if let stored = storedModelConfigs(for: engineId),
           let primary = stored.first(where: { $0.id == EngineModelConfig.primaryID }) ?? stored.first {
            let value = primary.trimmedName
            return value.isEmpty ? nil : value
        }

        let v = defaults.string(forKey: "engine.\(engineId).model") ?? ""
        return v.isEmpty ? nil : v
    }
    func setModel(_ value: String, for engineId: String) {
        var configs = modelConfigs(for: engineId, defaultModel: value)
        if let index = configs.firstIndex(where: { $0.id == EngineModelConfig.primaryID }) {
            configs[index].name = value
        } else if configs.isEmpty {
            configs = [EngineModelConfig(id: EngineModelConfig.primaryID, name: value)]
        } else {
            configs[0].name = value
        }
        setModelConfigs(configs, for: engineId)
        defaults.set(value, forKey: "engine.\(engineId).model")
    }
    func endpoint(for engineId: String) -> String? {
        let v = defaults.string(forKey: "engine.\(engineId).endpoint") ?? ""
        return v.isEmpty ? nil : v
    }
    func setEndpoint(_ value: String, for engineId: String) {
        defaults.set(value, forKey: "engine.\(engineId).endpoint")
    }

    func modelConfigs(for engineId: String, defaultModel: String?) -> [EngineModelConfig] {
        if let stored = storedModelConfigs(for: engineId), !stored.isEmpty {
            return normalizedModelConfigs(stored, defaultModel: defaultModel)
        }

        let legacyModel: String
        if engineId == "openai" {
            legacyModel = openAIModel
        } else {
            legacyModel = defaults.string(forKey: "engine.\(engineId).model") ?? ""
        }
        let model = legacyModel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? (defaultModel ?? "")
            : legacyModel
        guard !model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return [] }
        return [EngineModelConfig(id: EngineModelConfig.primaryID, name: model, enabled: true)]
    }

    func setModelConfigs(_ configs: [EngineModelConfig], for engineId: String) {
        let normalized = normalizedModelConfigs(configs, defaultModel: nil)
        if let encoded = try? JSONEncoder().encode(normalized) {
            defaults.set(encoded, forKey: modelConfigsKey(engineId))
        }

        if let primary = normalized.first(where: { $0.id == EngineModelConfig.primaryID }) ?? normalized.first {
            defaults.set(primary.trimmedName, forKey: "engine.\(engineId).model")
            if engineId == "openai" {
                openAIModel = primary.trimmedName
            }
        }
        objectWillChange.send()
    }

    func isModelEnabled(engineId: String, modelId: String, defaultModel: String?) -> Bool {
        modelConfigs(for: engineId, defaultModel: defaultModel)
            .first(where: { $0.id == modelId })?
            .enabled ?? false
    }

    private func storedModelConfigs(for engineId: String) -> [EngineModelConfig]? {
        guard let data = defaults.data(forKey: modelConfigsKey(engineId)) else { return nil }
        return try? JSONDecoder().decode([EngineModelConfig].self, from: data)
    }

    private func normalizedModelConfigs(
        _ configs: [EngineModelConfig],
        defaultModel: String?
    ) -> [EngineModelConfig] {
        var seen: Set<String> = []
        let trimmed = configs.compactMap { config -> EngineModelConfig? in
            let id = config.id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? UUID().uuidString
                : config.id
            guard !seen.contains(id) else { return nil }
            seen.insert(id)

            let name = config.trimmedName
            if name.isEmpty {
                guard config.id == EngineModelConfig.primaryID,
                      let defaultModel,
                      !defaultModel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    return nil
                }
                return EngineModelConfig(id: id, name: defaultModel, enabled: config.enabled)
            }
            return EngineModelConfig(id: id, name: name, enabled: config.enabled)
        }

        if trimmed.contains(where: { $0.id == EngineModelConfig.primaryID }) {
            return trimmed
        }
        if let first = trimmed.first {
            return [EngineModelConfig(id: EngineModelConfig.primaryID, name: first.name, enabled: first.enabled)]
                + trimmed.dropFirst()
        }
        return []
    }

    private func modelConfigsKey(_ engineId: String) -> String {
        "engine.\(engineId).models"
    }

    func secretsAbsentFromDefaults(sampleSecret: String) -> Bool {
        guard !sampleSecret.isEmpty else { return true }
        let blob = defaults.dictionaryRepresentation().values.compactMap { $0 as? String }.joined()
        return !blob.contains(sampleSecret)
    }

    var sourceLanguage: Language {
        sourceLanguageCode == "auto" ? .auto : Language(code: sourceLanguageCode)
    }
    var targetLanguage: Language { Language(code: targetLanguageCode) }

    func terminologySnapshot() -> TerminologySnapshot? {
        guard terminologyEnabled else { return nil }
        let snapshot = TerminologySnapshot(entries: terminologyEntries, strictMode: terminologyStrictMode)
        return snapshot.isEmpty ? nil : snapshot
    }

    @discardableResult
    func saveTerminologyEntry(_ entry: TerminologyEntry) -> Result<Void, TerminologyStoreError> {
        do {
            try TerminologyStore.validate(entry, against: terminologyEntries)
            if let idx = terminologyEntries.firstIndex(where: { $0.id == entry.id }) {
                terminologyEntries[idx] = entry
            } else {
                terminologyEntries.append(entry)
            }
            return .success(())
        } catch let error as TerminologyStoreError {
            return .failure(error)
        } catch {
            return .failure(.emptySourceOrTarget)
        }
    }

    func deleteTerminologyEntry(_ id: UUID) {
        terminologyEntries.removeAll { $0.id == id }
    }

    func replaceTerminologyEntries(_ entries: [TerminologyEntry]) {
        terminologyEntries = entries
    }

    func terminologyImportPlan(csv: String) throws -> TerminologyImportPlan {
        let decoded = try TerminologyCSV.decode(csv)
        return TerminologyCSV.planImport(decoded: decoded, existing: terminologyEntries)
    }

    func applyTerminologyImport(_ plan: TerminologyImportPlan) {
        var next = terminologyEntries
        for entry in plan.overwritten {
            if let idx = next.firstIndex(where: { $0.id == entry.id }) {
                next[idx] = entry
            }
        }
        next.append(contentsOf: plan.added)
        terminologyEntries = next
    }

    func terminologyCSV() -> String {
        TerminologyCSV.encode(terminologyEntries)
    }

    private func persistTerminologyState() {
        terminologyStore.saveState(TerminologyStoreState(
            isEnabled: terminologyEnabled,
            strictMode: terminologyStrictMode,
            entries: terminologyEntries
        ))
        objectWillChange.send()
    }

    // MARK: - Keys

    func deepLKey() -> String? { key(Self.deepLAccount, env: "DEEPL_API_KEY") }
    func openAIKey() -> String? { key(Self.openAIAccount, env: "OPENAI_API_KEY") }
    func tencentCredentials() -> String? { key(Self.tencentAccount, env: "TENCENT_CREDENTIALS") }
    func baiduCredentials() -> String? { key(Self.baiduAccount, env: "BAIDU_CREDENTIALS") }
    func youdaoCredentials() -> String? { key(Self.youdaoAccount, env: "YOUDAO_CREDENTIALS") }
    func caiyunToken() -> String? { key(Self.caiyunAccount, env: "CAIYUN_TOKEN") }
    func microsoftKey() -> String? { key(Self.microsoftAccount, env: "MICROSOFT_TRANSLATOR_KEY") }
    func deepSeekKey() -> String? { key(Self.deepSeekAccount, env: "DEEPSEEK_API_KEY") }
    func geminiKey() -> String? { key(Self.geminiAccount, env: "GEMINI_API_KEY") }
    func groqKey() -> String? { key(Self.groqAccount, env: "GROQ_API_KEY") }
    func ollamaKey() -> String? { key(Self.ollamaAccount, env: "OLLAMA_API_KEY") }
    func qwenKey() -> String? { key(Self.qwenAccount, env: "DASHSCOPE_API_KEY") }
    func doubaoKey() -> String? { key(Self.doubaoAccount, env: "DOUBAO_API_KEY") }
    func kimiKey() -> String? { key(Self.kimiAccount, env: "MOONSHOT_API_KEY") }
    func zhipuKey() -> String? { key(Self.zhipuAccount, env: "ZHIPU_API_KEY") }
    func siliconFlowKey() -> String? { key(Self.siliconFlowAccount, env: "SILICONFLOW_API_KEY") }
    func openCodeKey() -> String? { key(Self.openCodeAccount, env: "OPENCODE_API_KEY") }

    func setDeepLKey(_ v: String) { setKey(v, account: Self.deepLAccount) }
    func setOpenAIKey(_ v: String) { setKey(v, account: Self.openAIAccount) }
    func setTencentCredentials(_ v: String) { setKey(v, account: Self.tencentAccount) }
    func setBaiduCredentials(_ v: String) { setKey(v, account: Self.baiduAccount) }
    func setYoudaoCredentials(_ v: String) { setKey(v, account: Self.youdaoAccount) }
    func setCaiyunToken(_ v: String) { setKey(v, account: Self.caiyunAccount) }
    func setMicrosoftKey(_ v: String) { setKey(v, account: Self.microsoftAccount) }
    func setDeepSeekKey(_ v: String) { setKey(v, account: Self.deepSeekAccount) }
    func setGeminiKey(_ v: String) { setKey(v, account: Self.geminiAccount) }
    func setGroqKey(_ v: String) { setKey(v, account: Self.groqAccount) }
    func setOllamaKey(_ v: String) { setKey(v, account: Self.ollamaAccount) }
    func setQwenKey(_ v: String) { setKey(v, account: Self.qwenAccount) }
    func setDoubaoKey(_ v: String) { setKey(v, account: Self.doubaoAccount) }
    func setKimiKey(_ v: String) { setKey(v, account: Self.kimiAccount) }
    func setZhipuKey(_ v: String) { setKey(v, account: Self.zhipuAccount) }
    func setSiliconFlowKey(_ v: String) { setKey(v, account: Self.siliconFlowAccount) }
    func setOpenCodeKey(_ v: String) { setKey(v, account: Self.openCodeAccount) }

    var hasDeepLKey: Bool { hasSecret(Self.deepLAccount, env: "DEEPL_API_KEY") }
    var hasOpenAIKey: Bool { hasSecret(Self.openAIAccount, env: "OPENAI_API_KEY") }
    var hasTencentCredentials: Bool { hasSecret(Self.tencentAccount, env: "TENCENT_CREDENTIALS") }
    var hasBaiduCredentials: Bool { hasSecret(Self.baiduAccount, env: "BAIDU_CREDENTIALS") }
    var hasYoudaoCredentials: Bool { hasSecret(Self.youdaoAccount, env: "YOUDAO_CREDENTIALS") }
    var hasCaiyunToken: Bool { hasSecret(Self.caiyunAccount, env: "CAIYUN_TOKEN") }
    var hasMicrosoftKey: Bool { hasSecret(Self.microsoftAccount, env: "MICROSOFT_TRANSLATOR_KEY") }
    var hasDeepSeekKey: Bool { hasSecret(Self.deepSeekAccount, env: "DEEPSEEK_API_KEY") }
    var hasGeminiKey: Bool { hasSecret(Self.geminiAccount, env: "GEMINI_API_KEY") }
    var hasGroqKey: Bool { hasSecret(Self.groqAccount, env: "GROQ_API_KEY") }
    var hasQwenKey: Bool { hasSecret(Self.qwenAccount, env: "DASHSCOPE_API_KEY") }
    var hasDoubaoKey: Bool { hasSecret(Self.doubaoAccount, env: "DOUBAO_API_KEY") }
    var hasKimiKey: Bool { hasSecret(Self.kimiAccount, env: "MOONSHOT_API_KEY") }
    var hasZhipuKey: Bool { hasSecret(Self.zhipuAccount, env: "ZHIPU_API_KEY") }
    var hasSiliconFlowKey: Bool { hasSecret(Self.siliconFlowAccount, env: "SILICONFLOW_API_KEY") }
    var hasOpenCodeKey: Bool { hasSecret(Self.openCodeAccount, env: "OPENCODE_API_KEY") }

    /// Build ProviderConfig extra dict for an LLM engine including optional model/endpoint.
    func llmExtra(apiKey: String?, model: String? = nil, endpoint: String? = nil) -> [String: String] {
        var extra: [String: String] = [:]
        if let apiKey { extra["apiKey"] = apiKey }
        if let model, !model.isEmpty { extra["model"] = model }
        if let endpoint, !endpoint.isEmpty { extra["endpoint"] = endpoint }
        return extra
    }

    func key(_ account: String, env: String) -> String? {
        if let v = envNonEmpty(env) { return v }
        if let cached = keyCache[account] { return cached }
        if missingKeyCache.contains(account) { return nil }

        guard let value = SecretStore.get(account: account) else {
            missingKeyCache.insert(account)
            return nil
        }
        keyCache[account] = value
        missingKeyCache.remove(account)
        updateSecretMetadata(account: account, value: value)
        return value
    }

    @discardableResult
    func setKey(_ value: String, account: String) -> Bool {
        guard SecretStore.set(value, account: account) else { return false }
        if value.isEmpty {
            keyCache.removeValue(forKey: account)
            missingKeyCache.insert(account)
        } else {
            keyCache[account] = value
            missingKeyCache.remove(account)
        }
        updateSecretMetadata(account: account, value: value)
        objectWillChange.send()
        return true
    }

    func removeKey(account: String) {
        setKey("", account: account)
    }

    func hasSecret(_ account: String, env: String) -> Bool {
        if envNonEmpty(env) != nil { return true }
        return hasStoredSecret(account: account)
    }

    func hasStoredSecret(account: String) -> Bool {
        if nonEmpty(keyCache[account]) { return true }
        return SecretStore.has(account: account)
    }

    func secretStatus(account: String, env: String) -> String {
        if let envValue = envNonEmpty(env) {
            return L("环境变量 %@", Self.maskSecret(envValue))
        }
        if let cached = keyCache[account], !cached.isEmpty {
            return L("已配置 %@", Self.maskSecret(cached))
        }
        if hasStoredSecret(account: account),
           let preview = defaults.string(forKey: secretPreviewKey(account)),
           !preview.isEmpty {
            return L("已配置 %@", preview)
        }
        if let value = SecretStore.get(account: account), !value.isEmpty {
            return L("已配置 %@", Self.maskSecret(value))
        }
        return L("未配置")
    }

    func envNonEmpty(_ name: String) -> String? {
        let v = ProcessInfo.processInfo.environment[name]
        return nonEmpty(v) ? v : nil
    }

    private func updateSecretMetadata(account: String, value: String) {
        let configuredKey = secretConfiguredKey(account)
        let previewKey = secretPreviewKey(account)
        if value.isEmpty {
            defaults.set(false, forKey: configuredKey)
            defaults.removeObject(forKey: previewKey)
        } else {
            defaults.set(true, forKey: configuredKey)
            defaults.set(Self.maskSecret(value), forKey: previewKey)
        }
    }

    private func secretConfiguredKey(_ account: String) -> String {
        "secret.configured.\(account)"
    }

    private func secretPreviewKey(_ account: String) -> String {
        "secret.preview.\(account)"
    }

    private static func maskSecret(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        let suffix = String(trimmed.suffix(min(4, trimmed.count)))
        if trimmed.hasPrefix("sk-") {
            return "sk-...\(suffix)"
        }
        let prefix = trimmed.count > 8 ? String(trimmed.prefix(3)) : ""
        return prefix.isEmpty ? "...\(suffix)" : "\(prefix)...\(suffix)"
    }

    private func nonEmpty(_ v: String?) -> Bool { v?.isEmpty == false }
}
