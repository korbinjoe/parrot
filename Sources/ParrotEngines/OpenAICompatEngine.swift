import Foundation
import ParrotCore

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Shared OpenAI Chat Completions client. Subclasses set default endpoint/model.
open class OpenAICompatEngine: TranslationProvider, @unchecked Sendable {
    public let id: String
    public let displayName: String
    public let supportedLanguages: [Language]
    public let capabilities: ProviderCapabilities

    private let defaultEndpoint: URL
    private let defaultModel: String
    private let requiresAPIKey: Bool
    private let requestTimeout: TimeInterval

    private var apiKey: String?
    private var model: String
    private var endpoint: URL
    private let session: URLSession

    public init(
        id: String,
        displayName: String,
        defaultEndpoint: URL,
        defaultModel: String,
        requiresAPIKey: Bool = true,
        supportedLanguages: [Language] = [.auto, .zh, .en, .ja, .ko, .fr, .de, .es, .ru],
        capabilities: ProviderCapabilities = ProviderCapabilities(
            supportsLookup: true,
            supportsStream: true,
            supportsPolish: true,
            terminology: .prompt
        ),
        requestTimeout: TimeInterval = 60,
        session: URLSession = .shared
    ) {
        self.id = id
        self.displayName = displayName
        self.defaultEndpoint = defaultEndpoint
        self.defaultModel = defaultModel
        self.requiresAPIKey = requiresAPIKey
        self.requestTimeout = requestTimeout
        self.model = defaultModel
        self.endpoint = defaultEndpoint
        self.supportedLanguages = supportedLanguages
        self.capabilities = capabilities
        self.session = session
    }

    public var modelName: String? { model }

    open func configure(_ config: ProviderConfig) throws {
        apiKey = config.extra["apiKey"]
        if let m = config.extra["model"], !m.isEmpty { model = m }
        if let e = config.extra["endpoint"], let url = URL(string: e) { endpoint = url }
    }

    public func translate(_ req: TranslateRequest) async throws -> TranslateResult {
        if requiresAPIKey {
            guard let apiKey, !apiKey.isEmpty else { throw ProviderError.notConfigured }
        }

        var payload: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "system", "content": Self.systemPrompt(for: req)],
                ["role": "user", "content": req.text]
            ],
            "temperature": 0.2
        ]
        for (key, value) in additionalPayload(for: req) {
            payload[key] = value
        }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = requestTimeout
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let apiKey, !apiKey.isEmpty {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, response): (Data, URLResponse)
        do { (data, response) = try await session.data(for: request) }
        catch let error as URLError where error.code == .timedOut { throw ProviderError.timeout }
        catch { throw ProviderError.network }

        if let http = response as? HTTPURLResponse {
            switch http.statusCode {
            case 200: break
            case 401, 403:
                if let message = Self.providerErrorMessage(from: data) {
                    throw ProviderError.service(message)
                }
                throw ProviderError.auth
            case 429:
                if let message = Self.providerErrorMessage(from: data) {
                    throw ProviderError.service(message)
                }
                throw ProviderError.rateLimited
            default:
                if let message = Self.providerErrorMessage(from: data) {
                    throw ProviderError.service(message)
                }
                throw ProviderError.network
            }
        }

        return try Self.parseChatCompletion(data, providerId: id, detectedFrom: req.from == .auto ? nil : req.from)
    }

    static func parseChatCompletion(_ data: Data, providerId: String, detectedFrom: Language? = nil) throws -> TranslateResult {
        guard
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let choices = json["choices"] as? [[String: Any]],
            let message = choices.first?["message"] as? [String: Any],
            let content = message["content"] as? String
        else {
            throw ProviderError.network
        }
        return TranslateResult(
            providerId: providerId,
            translated: content.trimmingCharacters(in: .whitespacesAndNewlines),
            detectedFrom: detectedFrom
        )
    }

    static func providerErrorMessage(from data: Data) -> String? {
        guard
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let raw = json["error"]
        else {
            return nil
        }
        if let message = raw as? String {
            return message
        }
        if let error = raw as? [String: Any],
           let message = error["message"] as? String {
            return message
        }
        return nil
    }

    static func systemPrompt(for req: TranslateRequest) -> String {
        let target = req.to.code ?? "the target language"
        switch req.mode {
        case .translate:
            return "You are a professional translator. Translate the user's text into \(target). Output only the translation, no explanations.\(TerminologyProcessor.promptBlock(for: req) ?? "")"
        case .lookup:
            return "You are a dictionary. Explain the user's selected word or phrase in \(target). If a context sentence is provided, give the contextual meaning first. Include part of speech or phonetics only when useful. Output a concise answer with no markdown."
        case .polish:
            return "Polish and improve the user's text in \(target) while preserving meaning. Output only the result.\(TerminologyProcessor.promptBlock(for: req) ?? "")"
        }
    }

    open func additionalPayload(for req: TranslateRequest) -> [String: Any] {
        [:]
    }
}

// MARK: - P1 LLM thin subclasses

public final class OpenAIEngine: OpenAICompatEngine {
    public init(session: URLSession = .shared) {
        super.init(
            id: "openai",
            displayName: "OpenAI",
            defaultEndpoint: URL(string: "https://api.openai.com/v1/chat/completions")!,
            defaultModel: "gpt-4o-mini",
            session: session
        )
    }
}

public final class OpenCodeGoEngine: OpenAICompatEngine {
    public init(session: URLSession = .shared) {
        super.init(
            id: "opencode",
            displayName: "OpenCode Go",
            defaultEndpoint: URL(string: "https://opencode.ai/zen/go/v1/chat/completions")!,
            defaultModel: "glm-5.1",
            requestTimeout: 180,
            session: session
        )
    }
}

public final class DeepSeekEngine: OpenAICompatEngine {
    public init(session: URLSession = .shared) {
        super.init(
            id: "deepseek",
            displayName: "DeepSeek",
            defaultEndpoint: URL(string: "https://api.deepseek.com/v1/chat/completions")!,
            defaultModel: "deepseek-chat",
            session: session
        )
    }
}

public final class GroqEngine: OpenAICompatEngine {
    public init(session: URLSession = .shared) {
        super.init(
            id: "groq",
            displayName: "Groq",
            defaultEndpoint: URL(string: "https://api.groq.com/openai/v1/chat/completions")!,
            defaultModel: "llama-3.3-70b-versatile",
            session: session
        )
    }
}

public final class OllamaEngine: OpenAICompatEngine {
    public init(session: URLSession = .shared) {
        super.init(
            id: "ollama",
            displayName: "Ollama",
            defaultEndpoint: URL(string: "http://127.0.0.1:11434/v1/chat/completions")!,
            defaultModel: "glm-5:cloud",
            requiresAPIKey: false,
            session: session
        )
    }
}

public final class QwenEngine: OpenAICompatEngine {
    public init(session: URLSession = .shared) {
        super.init(
            id: "qwen",
            displayName: "通义千问",
            defaultEndpoint: URL(string: "https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions")!,
            defaultModel: "qwen-turbo",
            session: session
        )
    }
}

public final class DoubaoEngine: OpenAICompatEngine {
    public init(session: URLSession = .shared) {
        super.init(
            id: "doubao",
            displayName: "豆包",
            defaultEndpoint: URL(string: "https://ark.cn-beijing.volces.com/api/v3/chat/completions")!,
            defaultModel: "doubao-lite-32k",
            session: session
        )
    }
}

public final class KimiEngine: OpenAICompatEngine {
    public init(session: URLSession = .shared) {
        super.init(
            id: "kimi",
            displayName: "Kimi",
            defaultEndpoint: URL(string: "https://api.moonshot.cn/v1/chat/completions")!,
            defaultModel: "moonshot-v1-8k",
            session: session
        )
    }
}

public final class ZhipuEngine: OpenAICompatEngine {
    public init(session: URLSession = .shared) {
        super.init(
            id: "zhipu",
            displayName: "智谱 GLM",
            defaultEndpoint: URL(string: "https://open.bigmodel.cn/api/paas/v4/chat/completions")!,
            defaultModel: "glm-4.7-flash",
            requestTimeout: 120,
            session: session
        )
    }

    public override func additionalPayload(for req: TranslateRequest) -> [String: Any] {
        [
            "thinking": ["type": "disabled"],
            "max_tokens": 1024
        ]
    }
}

public final class SiliconFlowEngine: OpenAICompatEngine {
    public init(session: URLSession = .shared) {
        super.init(
            id: "siliconflow",
            displayName: "硅基流动",
            defaultEndpoint: URL(string: "https://api.siliconflow.cn/v1/chat/completions")!,
            defaultModel: "Qwen/Qwen2.5-7B-Instruct",
            session: session
        )
    }
}
