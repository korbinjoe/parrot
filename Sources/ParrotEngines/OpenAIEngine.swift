import Foundation
import ParrotCore

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Reference LLM engine using the OpenAI Chat Completions API. Pure Foundation/URLSession.
/// API key is injected via `ProviderConfig` (resolved from Keychain by the app layer) — never stored here.
public final class OpenAIEngine: TranslationProvider, @unchecked Sendable {
    public let id = "openai"
    public let displayName = "OpenAI"
    public let supportedLanguages: [Language] = [.auto, .zh, .en, .ja, .ko, .fr, .de, .es, .ru]
    public let capabilities = ProviderCapabilities(supportsLookup: true, supportsStream: true, supportsPolish: true)

    private var apiKey: String?
    private var model: String = "gpt-4o-mini"
    private var endpoint: URL = URL(string: "https://api.openai.com/v1/chat/completions")!
    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func configure(_ config: ProviderConfig) throws {
        // In the app, credentialRef resolves to a Keychain lookup; here we accept an inline key via extra for testing.
        self.apiKey = config.extra["apiKey"]
        if let m = config.extra["model"], !m.isEmpty { self.model = m }
        if let e = config.extra["endpoint"], let url = URL(string: e) { self.endpoint = url }
    }

    public func translate(_ req: TranslateRequest) async throws -> TranslateResult {
        guard let apiKey, !apiKey.isEmpty else { throw ProviderError.notConfigured }

        let system = Self.systemPrompt(for: req)
        let payload: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "system", "content": system],
                ["role": "user", "content": req.text]
            ],
            "temperature": 0.2
        ]

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw ProviderError.network
        }

        if let http = response as? HTTPURLResponse {
            switch http.statusCode {
            case 200: break
            case 401, 403: throw ProviderError.auth
            case 429: throw ProviderError.rateLimited
            default: throw ProviderError.network
            }
        }

        guard
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let choices = json["choices"] as? [[String: Any]],
            let message = choices.first?["message"] as? [String: Any],
            let content = message["content"] as? String
        else {
            throw ProviderError.network
        }

        return TranslateResult(
            providerId: id,
            translated: content.trimmingCharacters(in: .whitespacesAndNewlines),
            detectedFrom: req.from == .auto ? nil : req.from
        )
    }

    static func systemPrompt(for req: TranslateRequest) -> String {
        let target = req.to.code ?? "the target language"
        switch req.mode {
        case .translate:
            return "You are a professional translator. Translate the user's text into \(target). Output only the translation, no explanations."
        case .lookup:
            return "You are a dictionary. For the user's word, give the \(target) meaning, part of speech, phonetics, and one example. Be concise."
        case .polish:
            return "Polish and improve the user's text in \(target) while preserving meaning. Output only the result."
        }
    }
}
