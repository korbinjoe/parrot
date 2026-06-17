import Foundation
import ParrotCore

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Google Gemini via Generative Language API.
public final class GeminiEngine: TranslationProvider, @unchecked Sendable {
    public let id = "gemini"
    public let displayName = "Gemini"
    public let supportedLanguages: [Language] = [.auto, .zh, .en, .ja, .ko, .fr, .de, .es, .ru]
    public let capabilities = ProviderCapabilities(supportsLookup: true, supportsStream: false, supportsPolish: true)

    private var apiKey: String?
    private var model: String = "gemini-2.0-flash"
    private let session: URLSession

    public init(session: URLSession = .shared) { self.session = session }

    public var modelName: String? { model }

    public func configure(_ config: ProviderConfig) throws {
        apiKey = config.extra["apiKey"]
        if let m = config.extra["model"], !m.isEmpty { model = m }
    }

    public func translate(_ req: TranslateRequest) async throws -> TranslateResult {
        guard let apiKey, !apiKey.isEmpty else { throw ProviderError.notConfigured }
        let prompt = OpenAICompatEngine.systemPrompt(for: req)
        let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent?key=\(apiKey)")!

        let body: [String: Any] = [
            "contents": [
                ["parts": [["text": "\(prompt)\n\n\(req.text)"]]]
            ]
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response): (Data, URLResponse)
        do { (data, response) = try await session.data(for: request) }
        catch { throw ProviderError.network }

        if let http = response as? HTTPURLResponse {
            switch http.statusCode {
            case 200: break
            case 401, 403: throw ProviderError.auth
            case 429: throw ProviderError.rateLimited
            default: throw ProviderError.network
            }
        }
        return try Self.parse(data, providerId: id, detectedFrom: req.from == .auto ? nil : req.from)
    }

    static func parse(_ data: Data, providerId: String, detectedFrom: Language? = nil) throws -> TranslateResult {
        guard
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let candidates = json["candidates"] as? [[String: Any]],
            let content = candidates.first?["content"] as? [String: Any],
            let parts = content["parts"] as? [[String: Any]],
            let text = parts.first?["text"] as? String
        else {
            throw ProviderError.network
        }
        return TranslateResult(
            providerId: providerId,
            translated: text.trimmingCharacters(in: .whitespacesAndNewlines),
            detectedFrom: detectedFrom
        )
    }
}
