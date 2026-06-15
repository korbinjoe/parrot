import Foundation
import ParrotCore

// MARK: - P2 LLM

public final class AzureOpenAIEngine: OpenAICompatEngine {
    public init(session: URLSession = .shared) {
        super.init(
            id: "azure-openai",
            displayName: "Azure OpenAI",
            defaultEndpoint: URL(string: "https://YOUR-RESOURCE.openai.azure.com/openai/deployments/YOUR-DEPLOYMENT/chat/completions?api-version=2024-02-15-preview")!,
            defaultModel: "gpt-4o-mini",
            session: session
        )
    }
}

public final class ErnieEngine: OpenAICompatEngine {
    public init(session: URLSession = .shared) {
        super.init(
            id: "ernie",
            displayName: "文心一言",
            defaultEndpoint: URL(string: "https://qianfan.baidubce.com/v2/chat/completions")!,
            defaultModel: "ernie-lite-8k",
            session: session
        )
    }
}

public final class HunyuanEngine: OpenAICompatEngine {
    public init(session: URLSession = .shared) {
        super.init(
            id: "hunyuan",
            displayName: "混元",
            defaultEndpoint: URL(string: "https://api.hunyuan.cloud.tencent.com/v1/chat/completions")!,
            defaultModel: "hunyuan-lite",
            session: session
        )
    }
}

public final class YiEngine: OpenAICompatEngine {
    public init(session: URLSession = .shared) {
        super.init(
            id: "yi",
            displayName: "零一万物",
            defaultEndpoint: URL(string: "https://api.lingyiwanwu.com/v1/chat/completions")!,
            defaultModel: "yi-lightning",
            session: session
        )
    }
}

// MARK: - P3 machine translation

public final class VolcengineEngine: HTTPTranslationEngine {
    public init(session: URLSession = .shared) {
        super.init(id: "volcengine", displayName: "火山翻译", session: session)
    }

    public override func translate(_ req: TranslateRequest) async throws -> TranslateResult {
        guard let key = apiKey, !key.isEmpty else { throw ProviderError.notConfigured }
        let body: [String: Any] = [
            "TargetLanguage": langCode(req.to, auto: "zh"),
            "TextList": [req.text]
        ]
        let data = try await postJSON(
            url: URL(string: "https://open.volcengineapi.com/?Action=TranslateText&Version=2020-06-01")!,
            headers: ["Authorization": "Bearer \(key)"],
            body: body
        )
        return try Self.parse(data, providerId: id)
    }

    static func parse(_ data: Data, providerId: String) throws -> TranslateResult {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let list = json["TranslationList"] as? [[String: Any]],
              let text = list.first?["Translation"] as? String else {
            throw ProviderError.network
        }
        return TranslateResult(providerId: providerId, translated: text)
    }
}

public final class AliyunEngine: HTTPTranslationEngine {
    public init(session: URLSession = .shared) {
        super.init(id: "aliyun", displayName: "阿里翻译", session: session)
    }

    public override func translate(_ req: TranslateRequest) async throws -> TranslateResult {
        guard let creds = EngineCredentials.split(apiKey, idKey: "accessKeyId", secretKey: "accessKeySecret", extra: extra)
        else { throw ProviderError.notConfigured }
        let body: [String: Any] = [
            "FormatType": "text",
            "SourceLanguage": langCode(req.from),
            "TargetLanguage": langCode(req.to, auto: "zh"),
            "SourceText": req.text,
            "Scene": "general"
        ]
        let data = try await postJSON(
            url: URL(string: "https://mt.aliyuncs.com/")!,
            headers: [
                "x-acs-action": "TranslateGeneral",
                "x-acs-version": "2018-10-12",
                "Authorization": "ACS3-HMAC-SHA256 Credential=\(creds.id)"
            ],
            body: body
        )
        return try Self.parse(data, providerId: id)
    }

    static func parse(_ data: Data, providerId: String) throws -> TranslateResult {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let text = json["Data"] as? [String: Any],
              let translated = text["Translated"] as? String else {
            throw ProviderError.network
        }
        return TranslateResult(providerId: providerId, translated: translated)
    }
}

public final class NiutransEngine: HTTPTranslationEngine {
    public init(session: URLSession = .shared) {
        super.init(id: "niutrans", displayName: "小牛翻译", session: session)
    }

    public override func translate(_ req: TranslateRequest) async throws -> TranslateResult {
        guard let key = apiKey, !key.isEmpty else { throw ProviderError.notConfigured }
        let body: [String: Any] = [
            "from": langCode(req.from),
            "to": langCode(req.to, auto: "zh"),
            "src_text": req.text
        ]
        let data = try await postJSON(
            url: URL(string: "https://api.niutrans.com/NiuTransServer/translation")!,
            headers: ["apikey": key],
            body: body
        )
        return try Self.parse(data, providerId: id)
    }

    static func parse(_ data: Data, providerId: String) throws -> TranslateResult {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let text = json["tgt_text"] as? String else {
            throw ProviderError.network
        }
        return TranslateResult(providerId: providerId, translated: text)
    }
}

public final class AmazonTranslateEngine: HTTPTranslationEngine {
    public init(session: URLSession = .shared) {
        super.init(id: "amazon", displayName: "Amazon 翻译", session: session)
    }

    public override func translate(_ req: TranslateRequest) async throws -> TranslateResult {
        guard let creds = EngineCredentials.split(apiKey, idKey: "accessKeyId", secretKey: "secretAccessKey", extra: extra)
        else { throw ProviderError.notConfigured }
        let region = extra["region"] ?? "us-east-1"
        let body: [String: Any] = [
            "Text": req.text,
            "SourceLanguageCode": langCode(req.from, auto: "auto"),
            "TargetLanguageCode": langCode(req.to, auto: "zh")
        ]
        let data = try await postJSON(
            url: URL(string: "https://translate.\(region).amazonaws.com/")!,
            headers: [
                "X-Amz-Target": "AWSShineFrontendService_20170701.TranslateText",
                "Authorization": "AWS4-HMAC-SHA256 Credential=\(creds.id)"
            ],
            body: body
        )
        return try Self.parse(data, providerId: id)
    }

    static func parse(_ data: Data, providerId: String) throws -> TranslateResult {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let text = json["TranslatedText"] as? String else {
            throw ProviderError.network
        }
        return TranslateResult(providerId: providerId, translated: text)
    }
}
