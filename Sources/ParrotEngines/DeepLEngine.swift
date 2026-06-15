import Foundation
import ParrotCore

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// DeepL translation via the official API. Supports both Free (api-free) and Pro (api) hosts.
/// API key injected via `ProviderConfig.extra["apiKey"]` (free keys end with ":fx").
public final class DeepLEngine: TranslationProvider, @unchecked Sendable {
    public let id = "deepl"
    public let displayName = "DeepL"
    public let supportedLanguages: [Language] = [.auto, .zh, .en, .ja, .ko, .fr, .de, .es, .ru]
    public let capabilities = ProviderCapabilities()

    private var apiKey: String?
    private let session: URLSession
    public init(session: URLSession = .shared) { self.session = session }

    public func configure(_ config: ProviderConfig) throws {
        self.apiKey = config.extra["apiKey"]
    }

    private var host: String {
        // Free-tier keys carry the ":fx" suffix and use a different host.
        (apiKey?.hasSuffix(":fx") ?? false) ? "https://api-free.deepl.com" : "https://api.deepl.com"
    }

    public func translate(_ req: TranslateRequest) async throws -> TranslateResult {
        guard let apiKey, !apiKey.isEmpty else { throw ProviderError.notConfigured }
        guard let url = URL(string: "\(host)/v2/translate") else { throw ProviderError.network }

        var body = URLComponents()
        var items: [URLQueryItem] = [
            .init(name: "text", value: req.text),
            .init(name: "target_lang", value: (req.to.code ?? "EN").uppercased())
        ]
        if let src = req.from.code { items.append(.init(name: "source_lang", value: src.uppercased())) }
        body.queryItems = items

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("DeepL-Auth-Key \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = body.percentEncodedQuery?.data(using: .utf8)

        let (data, response): (Data, URLResponse)
        do { (data, response) = try await session.data(for: request) }
        catch { throw ProviderError.network }

        if let http = response as? HTTPURLResponse {
            switch http.statusCode {
            case 200: break
            case 403: throw ProviderError.auth
            case 429, 456: throw ProviderError.rateLimited
            default: throw ProviderError.network
            }
        }
        return try Self.parse(data, providerId: id)
    }

    /// Parse `{ "translations": [ { "text": "...", "detected_source_language": "EN" } ] }`
    static func parse(_ data: Data, providerId: String) throws -> TranslateResult {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let translations = json["translations"] as? [[String: Any]],
              let first = translations.first,
              let text = first["text"] as? String else {
            throw ProviderError.network
        }
        var detected: Language?
        if let code = first["detected_source_language"] as? String { detected = Language(code: code) }
        return TranslateResult(providerId: providerId, translated: text, detectedFrom: detected)
    }
}
