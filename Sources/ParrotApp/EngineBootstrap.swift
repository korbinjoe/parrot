import Foundation
import ParrotCore
import ParrotEngines

/// Registers all built-in translation engines from user settings.
enum EngineBootstrap {
    static let defaultOrder: [String] = [
        "google", "deepl", "openai", "tencent", "baidu", "youdao", "caiyun", "microsoft", "apple",
        "opencode", "deepseek", "gemini", "groq", "ollama", "qwen", "doubao", "kimi", "zhipu", "siliconflow",
        "ernie", "hunyuan", "yi", "azure-openai",
        "volcengine", "aliyun", "niutrans", "amazon"
    ]

    static func resolvedOrder(_ stored: [String]) -> [String] {
        guard !stored.isEmpty else { return defaultOrder }
        return stored + defaultOrder.filter { !stored.contains($0) }
    }

    @MainActor
    static func resolvedProviderOrder(settings: AppSettings) -> [String] {
        resolvedOrder(settings.engineOrder).flatMap { engineID -> [String] in
            guard let descriptor = EngineCatalog.descriptor(for: engineID),
                  descriptor.defaultModel != nil else {
                return [engineID]
            }
            let models = settings.modelConfigs(for: engineID, defaultModel: descriptor.defaultModel)
            return models.map { $0.providerID(engineID: engineID) }
        }
    }

    @MainActor
    static func registerAll(
        into registry: ProviderRegistry,
        settings: AppSettings,
        configureDisabledProviders: Bool = false
    ) {
        let keyIfNeeded: (Bool, () -> String?) -> String? = { enabled, loadKey in
            (enabled || configureDisabledProviders) ? loadKey() : nil
        }

        registerKeyed(
            registry,
            GoogleTranslationLLMEngine(),
            key: keyIfNeeded(settings.googleEnabled, settings.googleTranslationLLMCredentials),
            enabled: settings.googleEnabled
        )
        registerKeyed(registry, DeepLEngine(), key: keyIfNeeded(settings.deepLEnabled, settings.deepLKey), enabled: settings.deepLEnabled)
        registerKeyed(registry, TencentEngine(), key: keyIfNeeded(settings.tencentEnabled, settings.tencentCredentials), enabled: settings.tencentEnabled)
        registerKeyed(registry, BaiduEngine(), key: keyIfNeeded(settings.baiduEnabled, settings.baiduCredentials), enabled: settings.baiduEnabled)
        registerKeyed(registry, YoudaoEngine(), key: keyIfNeeded(settings.youdaoEnabled, settings.youdaoCredentials), enabled: settings.youdaoEnabled)
        registerKeyed(registry, CaiyunEngine(), key: keyIfNeeded(settings.caiyunEnabled, settings.caiyunToken), enabled: settings.caiyunEnabled)
        registerMicrosoft(registry, settings, configureWhenDisabled: configureDisabledProviders)

        if #available(macOS 15.0, *), AppleTranslationEngine.isSupported {
            registry.register(AppAppleTranslationEngine(), enabled: settings.appleEnabled)
        }

        registerLLMModels(registry, makeProvider: { OpenAIEngine() }, key: keyIfNeeded(settings.openAIEnabled, settings.openAIKey), enabled: settings.openAIEnabled, settings: settings, engineID: "openai", defaultModel: "gpt-4o-mini", endpoint: settings.openAIEndpoint)
        registerLLMModels(registry, makeProvider: { OpenCodeGoEngine() }, key: keyIfNeeded(settings.openCodeEnabled, settings.openCodeKey), enabled: settings.openCodeEnabled, settings: settings, engineID: "opencode", defaultModel: "glm-5.1")
        registerLLMModels(registry, makeProvider: { DeepSeekEngine() }, key: keyIfNeeded(settings.deepSeekEnabled, settings.deepSeekKey), enabled: settings.deepSeekEnabled, settings: settings, engineID: "deepseek", defaultModel: "deepseek-chat")
        registerLLMModels(registry, makeProvider: { GeminiEngine() }, key: keyIfNeeded(settings.geminiEnabled, settings.geminiKey), enabled: settings.geminiEnabled, settings: settings, engineID: "gemini", defaultModel: "gemini-2.0-flash")
        registerLLMModels(registry, makeProvider: { GroqEngine() }, key: keyIfNeeded(settings.groqEnabled, settings.groqKey), enabled: settings.groqEnabled, settings: settings, engineID: "groq", defaultModel: "llama-3.3-70b-versatile")
        registerLLMModels(registry, makeProvider: { OllamaEngine() }, key: keyIfNeeded(settings.ollamaEnabled, settings.ollamaKey), enabled: settings.ollamaEnabled, settings: settings, engineID: "ollama", defaultModel: "glm-5:cloud", endpoint: settings.ollamaEndpoint.isEmpty ? nil : settings.ollamaEndpoint)
        registerLLMModels(registry, makeProvider: { QwenEngine() }, key: keyIfNeeded(settings.qwenEnabled, settings.qwenKey), enabled: settings.qwenEnabled, settings: settings, engineID: "qwen", defaultModel: "qwen-turbo")
        registerLLMModels(registry, makeProvider: { DoubaoEngine() }, key: keyIfNeeded(settings.doubaoEnabled, settings.doubaoKey), enabled: settings.doubaoEnabled, settings: settings, engineID: "doubao", defaultModel: "doubao-lite-32k")
        registerLLMModels(registry, makeProvider: { KimiEngine() }, key: keyIfNeeded(settings.kimiEnabled, settings.kimiKey), enabled: settings.kimiEnabled, settings: settings, engineID: "kimi", defaultModel: "moonshot-v1-8k")
        registerLLMModels(registry, makeProvider: { ZhipuEngine() }, key: keyIfNeeded(settings.zhipuEnabled, settings.zhipuKey), enabled: settings.zhipuEnabled, settings: settings, engineID: "zhipu", defaultModel: "glm-4.7-flash")
        registerLLMModels(registry, makeProvider: { SiliconFlowEngine() }, key: keyIfNeeded(settings.siliconFlowEnabled, settings.siliconFlowKey), enabled: settings.siliconFlowEnabled, settings: settings, engineID: "siliconflow", defaultModel: "Qwen/Qwen2.5-7B-Instruct")

        registerLLMModels(registry, makeProvider: { ErnieEngine() }, key: keyIfNeeded(settings.ernieEnabled, settings.ernieKey), enabled: settings.ernieEnabled, settings: settings, engineID: "ernie", defaultModel: "ernie-lite-8k")
        registerLLMModels(registry, makeProvider: { HunyuanEngine() }, key: keyIfNeeded(settings.hunyuanEnabled, settings.hunyuanKey), enabled: settings.hunyuanEnabled, settings: settings, engineID: "hunyuan", defaultModel: "hunyuan-lite")
        registerLLMModels(registry, makeProvider: { YiEngine() }, key: keyIfNeeded(settings.yiEnabled, settings.yiKey), enabled: settings.yiEnabled, settings: settings, engineID: "yi", defaultModel: "yi-lightning")
        registerLLMModels(registry, makeProvider: { AzureOpenAIEngine() }, key: keyIfNeeded(settings.azureOpenAIEnabled, settings.azureOpenAIKey), enabled: settings.azureOpenAIEnabled, settings: settings, engineID: "azure-openai", defaultModel: "gpt-4o-mini", endpoint: settings.endpoint(for: "azure-openai"))

        registerKeyed(registry, VolcengineEngine(), key: keyIfNeeded(settings.volcengineEnabled, settings.volcengineKey), enabled: settings.volcengineEnabled)
        registerKeyed(registry, AliyunEngine(), key: keyIfNeeded(settings.aliyunEnabled, settings.aliyunCredentials), enabled: settings.aliyunEnabled)
        registerKeyed(registry, NiutransEngine(), key: keyIfNeeded(settings.niutransEnabled, settings.niutransKey), enabled: settings.niutransEnabled)
        registerKeyed(registry, AmazonTranslateEngine(), key: keyIfNeeded(settings.amazonEnabled, settings.amazonCredentials), enabled: settings.amazonEnabled) { engine, key in
            try? engine.configure(ProviderConfig(extra: ["apiKey": key, "region": settings.amazonRegion]))
        }

        registry.register(MockEngine(), enabled: false)
        registry.setOrder(resolvedProviderOrder(settings: settings))
    }

    @MainActor
    private static func registerKeyed(
        _ registry: ProviderRegistry,
        _ provider: TranslationProvider,
        key: String?,
        enabled: Bool,
        configure: ((TranslationProvider, String) -> Void)? = nil
    ) {
        guard let key, !key.isEmpty else {
            registry.register(provider, enabled: false)
            return
        }
        if let configure { configure(provider, key) }
        else { try? provider.configure(ProviderConfig(extra: ["apiKey": key])) }
        registry.register(provider, enabled: enabled)
    }

    @MainActor
    private static func registerMicrosoft(
        _ registry: ProviderRegistry,
        _ settings: AppSettings,
        configureWhenDisabled: Bool
    ) {
        guard settings.microsoftEnabled || configureWhenDisabled else {
            registry.register(MicrosoftEngine(), enabled: false)
            return
        }
        guard let key = settings.microsoftKey(), !key.isEmpty else {
            registry.register(MicrosoftEngine(), enabled: false)
            return
        }
        let engine = MicrosoftEngine()
        try? engine.configure(ProviderConfig(extra: ["apiKey": key, "region": settings.microsoftRegion]))
        registry.register(engine, enabled: settings.microsoftEnabled)
    }

    @MainActor
    private static func registerLLM(
        _ registry: ProviderRegistry,
        _ provider: TranslationProvider,
        key: String?,
        enabled: Bool,
        settings: AppSettings,
        model: String? = nil,
        endpoint: String? = nil,
        providerID: String? = nil
    ) {
        let exposedProvider = ModelVariantProvider(
            id: providerID ?? provider.id,
            displayName: provider.displayName,
            modelName: model,
            provider: provider
        )
        let ollamaNoKey = provider.id == "ollama"
        guard ollamaNoKey || (key?.isEmpty == false) else {
            registry.register(exposedProvider, enabled: false)
            return
        }
        var extra = settings.llmExtra(apiKey: key, model: model, endpoint: endpoint)
        if ollamaNoKey && key == nil { extra.removeValue(forKey: "apiKey") }
        try? provider.configure(ProviderConfig(extra: extra))
        registry.register(exposedProvider, enabled: enabled)
    }

    @MainActor
    private static func registerLLMModels(
        _ registry: ProviderRegistry,
        makeProvider: () -> TranslationProvider,
        key: String?,
        enabled: Bool,
        settings: AppSettings,
        engineID: String,
        defaultModel: String,
        endpoint: String? = nil
    ) {
        let models = settings.modelConfigs(for: engineID, defaultModel: defaultModel)
        for model in models {
            registerLLM(
                registry,
                makeProvider(),
                key: key,
                enabled: enabled && model.enabled,
                settings: settings,
                model: model.trimmedName.isEmpty ? defaultModel : model.trimmedName,
                endpoint: endpoint,
                providerID: model.providerID(engineID: engineID)
            )
        }
    }
}

private final class ModelVariantProvider: TranslationProvider, @unchecked Sendable {
    let id: String
    let displayName: String
    let modelName: String?
    let provider: TranslationProvider

    var supportedLanguages: [Language] { provider.supportedLanguages }
    var capabilities: ProviderCapabilities { provider.capabilities }

    init(id: String, displayName: String, modelName: String?, provider: TranslationProvider) {
        self.id = id
        self.displayName = displayName
        self.modelName = modelName
        self.provider = provider
    }

    func configure(_ config: ProviderConfig) throws {
        try provider.configure(config)
    }

    func translate(_ req: TranslateRequest) async throws -> TranslateResult {
        let result = try await provider.translate(req)
        return TranslateResult(
            providerId: id,
            translated: result.translated,
            detectedFrom: result.detectedFrom,
            phonetics: result.phonetics,
            definitions: result.definitions,
            terminologyApplication: result.terminologyApplication,
            privacyMaskingReport: result.privacyMaskingReport,
            qualitySummary: result.qualitySummary,
            interpretation: result.interpretation
        )
    }
}
