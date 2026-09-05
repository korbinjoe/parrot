import Foundation
import ParrotEngines

enum EngineCategory: Equatable {
    case base
    case machine
    case llm
    case more
}

struct EngineCredential: Equatable {
    let account: String
    let env: String
    let placeholder: String
    let missingText: String
}

struct EngineDescriptor: Identifiable, Equatable {
    let id: String
    let name: String
    let category: EngineCategory
    let credential: EngineCredential?
    let noCredentialNote: String?
    let defaultModel: String?
    let defaultEndpoint: String?
    let supportsValidation: Bool

    var requiresCredential: Bool { credential != nil }
}

@MainActor
enum EngineCatalog {
    static var all: [EngineDescriptor] {
        var descriptors: [EngineDescriptor] = [
            descriptor(
                "google",
                "Google 翻译 LLM",
                .llm,
                account: AppSettings.googleTranslationLLMAccount,
                env: "GOOGLE_TRANSLATION_LLM_CREDENTIALS",
                placeholder: "Project ID:API Key",
                missingText: "未配置 Google Cloud 项目与 API Key",
                noCredentialNote: "需在 Google Cloud 启用 Cloud Translation API；格式：Project ID:API Key"
            ),
            descriptor("deepl", "DeepL", .base, account: AppSettings.deepLAccount, env: "DEEPL_API_KEY", placeholder: "免费版以 :fx 结尾"),
            descriptor("openai", "OpenAI", .base, account: AppSettings.openAIAccount, env: "OPENAI_API_KEY", placeholder: "sk-...", defaultModel: "gpt-4o-mini", defaultEndpoint: ""),
            descriptor("tencent", "腾讯翻译君", .machine, account: AppSettings.tencentAccount, env: "TENCENT_CREDENTIALS", placeholder: "SecretId:SecretKey", missingText: "未配置凭证"),
            descriptor("baidu", "百度翻译", .machine, account: AppSettings.baiduAccount, env: "BAIDU_CREDENTIALS", placeholder: "AppId:Secret", missingText: "未配置凭证"),
            descriptor("youdao", "有道翻译", .machine, account: AppSettings.youdaoAccount, env: "YOUDAO_CREDENTIALS", placeholder: "AppKey:AppSecret", missingText: "未配置凭证"),
            descriptor("caiyun", "彩云小译", .machine, account: AppSettings.caiyunAccount, env: "CAIYUN_TOKEN", placeholder: "Token"),
            descriptor("microsoft", "Microsoft 翻译", .machine, account: AppSettings.microsoftAccount, env: "MICROSOFT_TRANSLATOR_KEY", placeholder: "订阅 Key"),
            descriptor("opencode", "OpenCode Go", .llm, account: AppSettings.openCodeAccount, env: "OPENCODE_API_KEY", placeholder: "Go API Key", defaultModel: "glm-5.1"),
            descriptor("deepseek", "DeepSeek", .llm, account: AppSettings.deepSeekAccount, env: "DEEPSEEK_API_KEY", placeholder: "API Key", defaultModel: "deepseek-chat"),
            descriptor("gemini", "Gemini", .llm, account: AppSettings.geminiAccount, env: "GEMINI_API_KEY", placeholder: "API Key", defaultModel: "gemini-2.0-flash"),
            descriptor("groq", "Groq", .llm, account: AppSettings.groqAccount, env: "GROQ_API_KEY", placeholder: "API Key", defaultModel: "llama-3.3-70b-versatile"),
            descriptor("ollama", "Ollama", .llm, noCredentialNote: "本地服务 · 无需 Key", defaultModel: "glm-5:cloud", defaultEndpoint: "http://127.0.0.1:11434/v1/chat/completions", supportsValidation: false),
            descriptor("qwen", "通义千问", .llm, account: AppSettings.qwenAccount, env: "DASHSCOPE_API_KEY", placeholder: "DashScope Key", defaultModel: "qwen-turbo"),
            descriptor("doubao", "豆包", .llm, account: AppSettings.doubaoAccount, env: "DOUBAO_API_KEY", placeholder: "方舟 API Key", defaultModel: "doubao-lite-32k"),
            descriptor("kimi", "Kimi", .llm, account: AppSettings.kimiAccount, env: "MOONSHOT_API_KEY", placeholder: "Moonshot Key", defaultModel: "moonshot-v1-8k"),
            descriptor("zhipu", "智谱 GLM", .llm, account: AppSettings.zhipuAccount, env: "ZHIPU_API_KEY", placeholder: "API Key", defaultModel: "glm-4.7-flash"),
            descriptor("siliconflow", "硅基流动", .llm, account: AppSettings.siliconFlowAccount, env: "SILICONFLOW_API_KEY", placeholder: "API Key", defaultModel: "Qwen/Qwen2.5-7B-Instruct"),
            descriptor("ernie", "文心一言", .more, account: AppSettings.ernieAccount, env: "ERNIE_API_KEY", placeholder: "API Key", defaultModel: "ernie-lite-8k"),
            descriptor("hunyuan", "混元", .more, account: AppSettings.hunyuanAccount, env: "HUNYUAN_API_KEY", placeholder: "API Key", defaultModel: "hunyuan-lite"),
            descriptor("yi", "零一万物", .more, account: AppSettings.yiAccount, env: "YI_API_KEY", placeholder: "API Key", defaultModel: "yi-lightning"),
            descriptor("azure-openai", "Azure OpenAI", .more, account: AppSettings.azureOpenAIAccount, env: "AZURE_OPENAI_API_KEY", placeholder: "API Key", defaultModel: "gpt-4o-mini", defaultEndpoint: "Azure deployment URL"),
            descriptor("volcengine", "火山翻译", .more, account: AppSettings.volcengineAccount, env: "VOLCENGINE_API_KEY", placeholder: "API Key"),
            descriptor("aliyun", "阿里翻译", .more, account: AppSettings.aliyunAccount, env: "ALIYUN_CREDENTIALS", placeholder: "AccessKeyId:AccessKeySecret", missingText: "未配置凭证"),
            descriptor("niutrans", "小牛翻译", .more, account: AppSettings.niutransAccount, env: "NIUTRANS_API_KEY", placeholder: "API Key"),
            descriptor("amazon", "Amazon 翻译", .more, account: AppSettings.amazonAccount, env: "AWS_CREDENTIALS", placeholder: "AccessKeyId:SecretAccessKey", missingText: "未配置凭证")
        ]
        if AppleTranslationEngine.isSupported {
            descriptors.insert(
                descriptor("apple", "系统翻译", .base, noCredentialNote: "macOS 15+ · 需离线语言包", supportsValidation: false),
                at: min(3, descriptors.count)
            )
        }
        return descriptors
    }

    static func descriptor(for id: String) -> EngineDescriptor? {
        let engineID = EngineModelConfig.baseEngineID(forProviderID: id)
        return all.first { $0.id == engineID }
    }

    /// Result-page priority within the same completion state. Doubao leads the
    /// LLM group, other model-backed engines follow, and classic MT engines keep
    /// their configured relative order after that.
    static func resultPresentationPriority(for providerID: String, modelName: String? = nil) -> Int {
        let engineID = EngineModelConfig.baseEngineID(forProviderID: providerID)
        if engineID == "doubao" { return 0 }
        let hasRuntimeModel = modelName?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .isEmpty == false
        if hasRuntimeModel || descriptor(for: engineID)?.defaultModel != nil { return 1 }
        return 2
    }

    static func orderedDescriptors(settings: AppSettings) -> [EngineDescriptor] {
        let byID = Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) })
        return EngineBootstrap.resolvedOrder(settings.engineOrder).compactMap { byID[$0] }
    }

    @MainActor
    static func missingConfigurationDescriptors(settings: AppSettings) -> [EngineDescriptor] {
        orderedDescriptors(settings: settings).filter { descriptor in
            settings.isEngineEnabled(descriptor.id)
                && descriptor.requiresCredential
                && !settings.isEngineConfigured(descriptor)
        }
    }

    private static func descriptor(
        _ id: String,
        _ name: String,
        _ category: EngineCategory,
        account: String? = nil,
        env: String? = nil,
        placeholder: String? = nil,
        missingText: String = "未配置 Key",
        noCredentialNote: String? = nil,
        defaultModel: String? = nil,
        defaultEndpoint: String? = nil,
        supportsValidation: Bool = true
    ) -> EngineDescriptor {
        let credential: EngineCredential?
        if let account, let env, let placeholder {
            credential = EngineCredential(account: account, env: env, placeholder: L(placeholder), missingText: L(missingText))
        } else {
            credential = nil
        }
        return EngineDescriptor(
            id: id,
            name: L(name),
            category: category,
            credential: credential,
            noCredentialNote: noCredentialNote.map { L($0) },
            defaultModel: defaultModel,
            defaultEndpoint: defaultEndpoint,
            supportsValidation: supportsValidation
        )
    }
}
