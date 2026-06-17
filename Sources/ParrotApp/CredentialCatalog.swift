import Foundation

enum CredentialCategory: String, CaseIterable, Identifiable {
    case common
    case machine
    case llm
    case more
    case ocr
    case tts

    var id: String { rawValue }

    var title: String {
        switch self {
        case .common: return L("常用")
        case .machine: return L("国内与云厂商")
        case .llm: return L("LLM 服务")
        case .more: return L("更多服务")
        case .ocr: return L("文本识别")
        case .tts: return L("语音合成")
        }
    }

    var filterTitle: String {
        switch self {
        case .common: return L("常用")
        case .machine: return L("云厂商")
        case .llm: return "LLM"
        case .more: return L("更多")
        case .ocr: return "OCR"
        case .tts: return "TTS"
        }
    }
}

struct CredentialDescriptor: Identifiable, Equatable {
    let id: String
    let aliases: [String]
    let name: String
    let category: CredentialCategory
    let credential: EngineCredential?
    let fallbackCredential: EngineCredential?
    let fallbackLabel: String?
    let linkedEngineID: String?
    let linkedOCRProviderID: String?
    let linkedTTSProviderID: String?
    let defaultModel: String?
    let defaultEndpoint: String?
    let supportsValidation: Bool
    let note: String?

    var requiresCredential: Bool { credential != nil }
    var hasAdvancedFields: Bool { defaultModel != nil || defaultEndpoint != nil }
    var searchableText: String {
        ([id, name] + aliases + [credential?.env, fallbackCredential?.env].compactMap { $0 })
            .joined(separator: " ")
            .lowercased()
    }

    func matchesServiceID(_ serviceID: String?) -> Bool {
        guard let serviceID else { return false }
        return id == serviceID || aliases.contains(serviceID)
    }
}

@MainActor
enum CredentialCatalog {
    static var all: [CredentialDescriptor] {
        translationDescriptors + ocrDescriptors + ttsDescriptors
    }

    static func descriptor(matching serviceID: String?) -> CredentialDescriptor? {
        guard let serviceID else { return nil }
        return all.first { $0.matchesServiceID(serviceID) }
    }

    static func normalizedServiceID(_ serviceID: String?) -> String? {
        descriptor(matching: serviceID)?.id
    }

    private static var translationDescriptors: [CredentialDescriptor] {
        EngineCatalog.all.compactMap { descriptor in
            guard descriptor.credential != nil || descriptor.defaultModel != nil || descriptor.defaultEndpoint != nil else {
                return nil
            }
            return CredentialDescriptor(
                id: descriptor.id,
                aliases: [],
                name: descriptor.name,
                category: credentialCategory(for: descriptor),
                credential: descriptor.credential,
                fallbackCredential: nil,
                fallbackLabel: nil,
                linkedEngineID: descriptor.id,
                linkedOCRProviderID: nil,
                linkedTTSProviderID: nil,
                defaultModel: descriptor.defaultModel,
                defaultEndpoint: descriptor.defaultEndpoint,
                supportsValidation: descriptor.supportsValidation,
                note: descriptor.noCredentialNote
            )
        }
    }

    private static var ocrDescriptors: [CredentialDescriptor] {
        [
            credential(
                id: "baidu-ocr",
                name: "百度 OCR",
                category: .ocr,
                account: AppSettings.baiduOCRKeyAccount,
                env: "BAIDU_OCR_CREDENTIALS",
                placeholder: "AppId:Secret",
                fallback: EngineCatalog.descriptor(for: "baidu")?.credential,
                fallbackLabel: "百度翻译凭证",
                aliases: []
            ),
            credential(
                id: "tencent-ocr",
                name: "腾讯 OCR / 图片翻译",
                category: .ocr,
                account: AppSettings.tencentOCRKeyAccount,
                env: "TENCENT_OCR_CREDENTIALS",
                placeholder: "SecretId:SecretKey",
                fallback: EngineCatalog.descriptor(for: "tencent")?.credential,
                fallbackLabel: "腾讯翻译凭证",
                aliases: ["tencent-image-translate", "tencent-tts"]
            ),
            credential(
                id: "google-ocr",
                name: "Google OCR",
                category: .ocr,
                account: AppSettings.googleOCRKeyAccount,
                env: "GOOGLE_OCR_API_KEY",
                placeholder: "API Key",
                aliases: []
            ),
            credential(
                id: "youdao-ocr",
                name: "有道 OCR",
                category: .ocr,
                account: AppSettings.youdaoOCRKeyAccount,
                env: "YOUDAO_OCR_CREDENTIALS",
                placeholder: "AppKey:AppSecret",
                fallback: EngineCatalog.descriptor(for: "youdao")?.credential,
                fallbackLabel: "有道翻译凭证",
                aliases: []
            ),
            credential(
                id: "volcengine-ocr",
                name: "火山 OCR",
                category: .ocr,
                account: AppSettings.volcengineOCRKeyAccount,
                env: "VOLCENGINE_OCR_KEY",
                placeholder: "API Key",
                aliases: []
            )
        ]
    }

    private static var ttsDescriptors: [CredentialDescriptor] {
        [
            credential(
                id: "google-tts",
                name: "Google 语音合成",
                category: .tts,
                account: AppSettings.googleTTSKeyAccount,
                env: "GOOGLE_TTS_API_KEY",
                placeholder: "API Key",
                aliases: []
            ),
            credential(
                id: "microsoft-tts",
                name: "Microsoft 语音合成",
                category: .tts,
                account: AppSettings.microsoftTTSKeyAccount,
                env: "MICROSOFT_TTS_KEY",
                placeholder: "订阅 Key",
                fallback: EngineCatalog.descriptor(for: "microsoft")?.credential,
                fallbackLabel: "Microsoft 翻译凭证",
                aliases: []
            ),
            credential(
                id: "volcengine-tts",
                name: "火山语音合成",
                category: .tts,
                account: AppSettings.volcengineTTSKeyAccount,
                env: "VOLCENGINE_TTS_KEY",
                placeholder: "API Key",
                aliases: []
            )
        ]
    }

    private static func credentialCategory(for descriptor: EngineDescriptor) -> CredentialCategory {
        if ["deepl", "openai", "opencode"].contains(descriptor.id) {
            return .common
        }
        switch descriptor.category {
        case .base: return .common
        case .machine: return .machine
        case .llm: return .llm
        case .more: return .more
        }
    }

    private static func credential(
        id: String,
        name: String,
        category: CredentialCategory,
        account: String,
        env: String,
        placeholder: String,
        fallback: EngineCredential? = nil,
        fallbackLabel: String? = nil,
        aliases: [String]
    ) -> CredentialDescriptor {
        CredentialDescriptor(
            id: id,
            aliases: aliases,
            name: L(name),
            category: category,
            credential: EngineCredential(
                account: account,
                env: env,
                placeholder: L(placeholder),
                missingText: L("未配置 Key")
            ),
            fallbackCredential: fallback,
            fallbackLabel: fallbackLabel.map { L($0) },
            linkedEngineID: nil,
            linkedOCRProviderID: category == .ocr ? id : nil,
            linkedTTSProviderID: category == .tts ? id : nil,
            defaultModel: nil,
            defaultEndpoint: nil,
            supportsValidation: false,
            note: fallbackLabel.map { L("未填写专用 Key 时复用%@。", L($0)) }
        )
    }
}
