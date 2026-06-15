import Foundation
import ParrotCore

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Shared HTTP helpers for REST-based translation engines (machine translation APIs).
open class HTTPTranslationEngine: TranslationProvider, @unchecked Sendable {
    public let id: String
    public let displayName: String
    public let supportedLanguages: [Language]
    public let capabilities: ProviderCapabilities

    var apiKey: String?
    var extra: [String: String] = [:]
    let session: URLSession

    public init(
        id: String,
        displayName: String,
        supportedLanguages: [Language] = [.auto, .zh, .en, .ja, .ko, .fr, .de, .es, .ru],
        capabilities: ProviderCapabilities = ProviderCapabilities(),
        session: URLSession = .shared
    ) {
        self.id = id
        self.displayName = displayName
        self.supportedLanguages = supportedLanguages
        self.capabilities = capabilities
        self.session = session
    }

    open func configure(_ config: ProviderConfig) throws {
        apiKey = config.extra["apiKey"]
        extra = config.extra
    }

    open func translate(_ req: TranslateRequest) async throws -> TranslateResult {
        throw ProviderError.unsupportedLanguage
    }

    /// Map common HTTP status codes to `ProviderError`.
    func throwIfHTTPError(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else { return }
        switch http.statusCode {
        case 200...299: return
        case 401, 403: throw ProviderError.auth
        case 429: throw ProviderError.rateLimited
        default: throw ProviderError.network
        }
    }

    func postJSON(
        url: URL,
        headers: [String: String] = [:],
        body: Any
    ) async throws -> Data {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        for (k, v) in headers { request.setValue(v, forHTTPHeaderField: k) }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response): (Data, URLResponse)
        do { (data, response) = try await session.data(for: request) }
        catch { throw ProviderError.network }
        try throwIfHTTPError(response)
        return data
    }

    func postForm(
        url: URL,
        headers: [String: String] = [:],
        fields: [String: String]
    ) async throws -> Data {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        for (k, v) in headers { request.setValue(v, forHTTPHeaderField: k) }
        var comps = URLComponents()
        comps.queryItems = fields.map { URLQueryItem(name: $0.key, value: $0.value) }
        request.httpBody = comps.percentEncodedQuery?.data(using: .utf8)
        let (data, response): (Data, URLResponse)
        do { (data, response) = try await session.data(for: request) }
        catch { throw ProviderError.network }
        try throwIfHTTPError(response)
        return data
    }

    func get(url: URL, headers: [String: String] = [:]) async throws -> Data {
        var request = URLRequest(url: url)
        for (k, v) in headers { request.setValue(v, forHTTPHeaderField: k) }
        let (data, response): (Data, URLResponse)
        do { (data, response) = try await session.data(for: request) }
        catch { throw ProviderError.network }
        try throwIfHTTPError(response)
        return data
    }

    /// Provider-specific language codes (defaults to ISO 639-1).
    func langCode(_ lang: Language, auto: String = "auto") -> String {
        lang.code ?? auto
    }
}
