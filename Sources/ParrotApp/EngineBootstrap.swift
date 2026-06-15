import Foundation
import ParrotCore
import ParrotEngines

/// Registers all built-in translation engines from user settings.
enum EngineBootstrap {
    static let defaultOrder: [String] = [
        "google", "deepl", "openai", "tencent", "baidu", "youdao", "caiyun", "microsoft", "apple",
        "deepseek", "gemini", "groq", "ollama", "qwen", "doubao", "kimi", "zhipu", "siliconflow",
        "ernie", "hunyuan", "yi", "azure-openai",
        "volcengine", "aliyun", "niutrans", "amazon"
    ]

    @MainActor
    static func registerAll(into registry: ProviderRegistry, settings: AppSettings) {
        registry.register(GoogleEngine(), enabled: settings.googleEnabled)
        registerKeyed(registry, DeepLEngine(), key: settings.deepLKey(), enabled: settings.deepLEnabled)
        registerKeyed(registry, TencentEngine(), key: settings.tencentCredentials(), enabled: settings.tencentEnabled)
        registerKeyed(registry, BaiduEngine(), key: settings.baiduCredentials(), enabled: settings.baiduEnabled)
        registerKeyed(registry, YoudaoEngine(), key: settings.youdaoCredentials(), enabled: settings.youdaoEnabled)
        registerKeyed(registry, CaiyunEngine(), key: settings.caiyunToken(), enabled: settings.caiyunEnabled)
        registerMicrosoft(registry, settings)

        if #available(macOS 15.0, *), AppleTranslationEngine.isSupported {
            registry.register(AppAppleTranslationEngine(), enabled: settings.appleEnabled)
        }

        registerLLM(registry, OpenAIEngine(), key: settings.openAIKey(), enabled: settings.openAIEnabled, settings: settings, model: settings.openAIModel, endpoint: settings.openAIEndpoint)
        registerLLM(registry, DeepSeekEngine(), key: settings.deepSeekKey(), enabled: settings.deepSeekEnabled, settings: settings, model: settings.model(for: "deepseek"))
        registerLLM(registry, GeminiEngine(), key: settings.geminiKey(), enabled: settings.geminiEnabled, settings: settings, model: settings.model(for: "gemini"))
        registerLLM(registry, GroqEngine(), key: settings.groqKey(), enabled: settings.groqEnabled, settings: settings, model: settings.model(for: "groq"))
        registerLLM(registry, OllamaEngine(), key: settings.ollamaKey(), enabled: settings.ollamaEnabled, settings: settings, model: settings.model(for: "ollama"), endpoint: settings.ollamaEndpoint.isEmpty ? nil : settings.ollamaEndpoint)
        registerLLM(registry, QwenEngine(), key: settings.qwenKey(), enabled: settings.qwenEnabled, settings: settings, model: settings.model(for: "qwen"))
        registerLLM(registry, DoubaoEngine(), key: settings.doubaoKey(), enabled: settings.doubaoEnabled, settings: settings, model: settings.model(for: "doubao"))
        registerLLM(registry, KimiEngine(), key: settings.kimiKey(), enabled: settings.kimiEnabled, settings: settings, model: settings.model(for: "kimi"))
        registerLLM(registry, ZhipuEngine(), key: settings.zhipuKey(), enabled: settings.zhipuEnabled, settings: settings, model: settings.model(for: "zhipu"))
        registerLLM(registry, SiliconFlowEngine(), key: settings.siliconFlowKey(), enabled: settings.siliconFlowEnabled, settings: settings, model: settings.model(for: "siliconflow"))

        registerLLM(registry, ErnieEngine(), key: settings.ernieKey(), enabled: settings.ernieEnabled, settings: settings, model: settings.model(for: "ernie"))
        registerLLM(registry, HunyuanEngine(), key: settings.hunyuanKey(), enabled: settings.hunyuanEnabled, settings: settings, model: settings.model(for: "hunyuan"))
        registerLLM(registry, YiEngine(), key: settings.yiKey(), enabled: settings.yiEnabled, settings: settings, model: settings.model(for: "yi"))
        registerLLM(registry, AzureOpenAIEngine(), key: settings.azureOpenAIKey(), enabled: settings.azureOpenAIEnabled, settings: settings, model: settings.model(for: "azure-openai"), endpoint: settings.endpoint(for: "azure-openai"))

        registerKeyed(registry, VolcengineEngine(), key: settings.volcengineKey(), enabled: settings.volcengineEnabled)
        registerKeyed(registry, AliyunEngine(), key: settings.aliyunCredentials(), enabled: settings.aliyunEnabled)
        registerKeyed(registry, NiutransEngine(), key: settings.niutransKey(), enabled: settings.niutransEnabled)
        registerKeyed(registry, AmazonTranslateEngine(), key: settings.amazonCredentials(), enabled: settings.amazonEnabled) { engine, key in
            try? engine.configure(ProviderConfig(extra: ["apiKey": key, "region": settings.amazonRegion]))
        }

        registry.register(MockEngine(), enabled: false)
        registry.setOrder(settings.engineOrder.isEmpty ? defaultOrder : settings.engineOrder)
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
