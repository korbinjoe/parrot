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
    static func registerAll(into registry: ProviderRegistry, settings: AppSettings) {
        registry.register(GoogleEngine(), enabled: settings.googleEnabled)
        registerKeyed(registry, DeepLEngine(), key: settings.deepLEnabled ? settings.deepLKey() : nil, enabled: settings.deepLEnabled)
        registerKeyed(registry, TencentEngine(), key: settings.tencentEnabled ? settings.tencentCredentials() : nil, enabled: settings.tencentEnabled)
        registerKeyed(registry, BaiduEngine(), key: settings.baiduEnabled ? settings.baiduCredentials() : nil, enabled: settings.baiduEnabled)
        registerKeyed(registry, YoudaoEngine(), key: settings.youdaoEnabled ? settings.youdaoCredentials() : nil, enabled: settings.youdaoEnabled)
        registerKeyed(registry, CaiyunEngine(), key: settings.caiyunEnabled ? settings.caiyunToken() : nil, enabled: settings.caiyunEnabled)
        registerMicrosoft(registry, settings)

        if #available(macOS 15.0, *), AppleTranslationEngine.isSupported {
            registry.register(AppAppleTranslationEngine(), enabled: settings.appleEnabled)
        }

        registerLLM(registry, OpenAIEngine(), key: settings.openAIEnabled ? settings.openAIKey() : nil, enabled: settings.openAIEnabled, settings: settings, model: settings.openAIModel, endpoint: settings.openAIEndpoint)
        registerLLM(registry, OpenCodeGoEngine(), key: settings.openCodeEnabled ? settings.openCodeKey() : nil, enabled: settings.openCodeEnabled, settings: settings, model: settings.model(for: "opencode"))
        registerLLM(registry, DeepSeekEngine(), key: settings.deepSeekEnabled ? settings.deepSeekKey() : nil, enabled: settings.deepSeekEnabled, settings: settings, model: settings.model(for: "deepseek"))
        registerLLM(registry, GeminiEngine(), key: settings.geminiEnabled ? settings.geminiKey() : nil, enabled: settings.geminiEnabled, settings: settings, model: settings.model(for: "gemini"))
        registerLLM(registry, GroqEngine(), key: settings.groqEnabled ? settings.groqKey() : nil, enabled: settings.groqEnabled, settings: settings, model: settings.model(for: "groq"))
        registerLLM(registry, OllamaEngine(), key: settings.ollamaEnabled ? settings.ollamaKey() : nil, enabled: settings.ollamaEnabled, settings: settings, model: settings.model(for: "ollama"), endpoint: settings.ollamaEndpoint.isEmpty ? nil : settings.ollamaEndpoint)
        registerLLM(registry, QwenEngine(), key: settings.qwenEnabled ? settings.qwenKey() : nil, enabled: settings.qwenEnabled, settings: settings, model: settings.model(for: "qwen"))
        registerLLM(registry, DoubaoEngine(), key: settings.doubaoEnabled ? settings.doubaoKey() : nil, enabled: settings.doubaoEnabled, settings: settings, model: settings.model(for: "doubao"))
        registerLLM(registry, KimiEngine(), key: settings.kimiEnabled ? settings.kimiKey() : nil, enabled: settings.kimiEnabled, settings: settings, model: settings.model(for: "kimi"))
        registerLLM(registry, ZhipuEngine(), key: settings.zhipuEnabled ? settings.zhipuKey() : nil, enabled: settings.zhipuEnabled, settings: settings, model: settings.model(for: "zhipu"))
        registerLLM(registry, SiliconFlowEngine(), key: settings.siliconFlowEnabled ? settings.siliconFlowKey() : nil, enabled: settings.siliconFlowEnabled, settings: settings, model: settings.model(for: "siliconflow"))

        registerLLM(registry, ErnieEngine(), key: settings.ernieEnabled ? settings.ernieKey() : nil, enabled: settings.ernieEnabled, settings: settings, model: settings.model(for: "ernie"))
        registerLLM(registry, HunyuanEngine(), key: settings.hunyuanEnabled ? settings.hunyuanKey() : nil, enabled: settings.hunyuanEnabled, settings: settings, model: settings.model(for: "hunyuan"))
        registerLLM(registry, YiEngine(), key: settings.yiEnabled ? settings.yiKey() : nil, enabled: settings.yiEnabled, settings: settings, model: settings.model(for: "yi"))
        registerLLM(registry, AzureOpenAIEngine(), key: settings.azureOpenAIEnabled ? settings.azureOpenAIKey() : nil, enabled: settings.azureOpenAIEnabled, settings: settings, model: settings.model(for: "azure-openai"), endpoint: settings.endpoint(for: "azure-openai"))

        registerKeyed(registry, VolcengineEngine(), key: settings.volcengineEnabled ? settings.volcengineKey() : nil, enabled: settings.volcengineEnabled)
        registerKeyed(registry, AliyunEngine(), key: settings.aliyunEnabled ? settings.aliyunCredentials() : nil, enabled: settings.aliyunEnabled)
        registerKeyed(registry, NiutransEngine(), key: settings.niutransEnabled ? settings.niutransKey() : nil, enabled: settings.niutransEnabled)
        registerKeyed(registry, AmazonTranslateEngine(), key: settings.amazonEnabled ? settings.amazonCredentials() : nil, enabled: settings.amazonEnabled) { engine, key in
            try? engine.configure(ProviderConfig(extra: ["apiKey": key, "region": settings.amazonRegion]))
        }

        registry.register(MockEngine(), enabled: false)
        registry.setOrder(resolvedOrder(settings.engineOrder))
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
    private static func registerMicrosoft(_ registry: ProviderRegistry, _ settings: AppSettings) {
        guard settings.microsoftEnabled else {
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
        endpoint: String? = nil
    ) {
        let ollamaNoKey = provider.id == "ollama"
        guard ollamaNoKey || (key?.isEmpty == false) else {
            registry.register(provider, enabled: false)
            return
        }
        var extra = settings.llmExtra(apiKey: key, model: model, endpoint: endpoint)
        if ollamaNoKey && key == nil { extra.removeValue(forKey: "apiKey") }
        try? provider.configure(ProviderConfig(extra: extra))
        registry.register(provider, enabled: enabled)
    }
}
