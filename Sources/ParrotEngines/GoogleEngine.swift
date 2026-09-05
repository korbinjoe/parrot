import Foundation
import ParrotCore

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Google's official Translation LLM through Cloud Translation Basic (v2).
///
/// Credentials use `PROJECT_ID:API_KEY`. The project ID is required because
/// Google identifies Translation LLM by its full Cloud resource name.
public final class GoogleTranslationLLMEngine: TranslationProvider, @unchecked Sendable {
    public let id = "google"
    public let displayName = "Google Translation LLM"
    public let supportedLanguages: [Language] = [.auto, .zh, .en, .ja, .ko, .fr, .de, .es, .ru]
    public let capabilities = ProviderCapabilities(supportsLookup: false, supportsStream: false)

    private var projectID: String?
    private var apiKey: String?
    private let session: URLSession

    public init(session: URLSession = .shared) { self.session = session }

    public func configure(_ config: ProviderConfig) throws {
        guard let credentials = config.extra["apiKey"],
              let separator = credentials.firstIndex(of: ":") else {
            projectID = nil
            apiKey = nil
            return
        }
        let project = String(credentials[..<separator]).trimmingCharacters(in: .whitespacesAndNewlines)
        let key = String(credentials[credentials.index(after: separator)...])
            .trimmingCharacters(in: .whitespacesAndNewlines)
        projectID = project.isEmpty ? nil : project
        apiKey = key.isEmpty ? nil : key
    }

    public func translate(_ req: TranslateRequest) async throws -> TranslateResult {
        guard let projectID, let apiKey else { throw ProviderError.notConfigured }
        let url = URL(string: "https://translation.googleapis.com/language/translate/v2")!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "X-goog-api-key")
        request.httpBody = try JSONSerialization.data(withJSONObject: Self.requestBody(for: req, projectID: projectID))

        let (data, response): (Data, URLResponse)
        do { (data, response) = try await session.data(for: request) }
        catch { throw ProviderError.network }

        if let http = response as? HTTPURLResponse {
            switch http.statusCode {
            case 200: break
            case 400: throw ProviderError.service(Self.errorMessage(in: data) ?? "Google Translation LLM 请求无效")
            case 401, 403: throw ProviderError.auth
            case 429: throw ProviderError.rateLimited
            default: throw ProviderError.service(Self.errorMessage(in: data) ?? "Google Translation LLM 服务异常")
            }
        }
        return try Self.parse(data, providerId: id)
    }

    static func requestBody(for req: TranslateRequest, projectID: String) -> [String: Any] {
        var body: [String: Any] = [
            "q": [req.text],
            "target": req.to.code ?? "en",
            "format": "text",
            "model": "projects/\(projectID)/locations/global/models/general/translation-llm"
        ]
        if req.from != .auto, let source = req.from.code { body["source"] = source }
        return body
    }

    static func parse(_ data: Data, providerId: String) throws -> TranslateResult {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let payload = root["data"] as? [String: Any],
              let translations = payload["translations"] as? [[String: Any]],
              let first = translations.first,
              let text = first["translatedText"] as? String,
              !text.isEmpty else {
            throw ProviderError.network
        }
        let detected = (first["detectedSourceLanguage"] as? String).map(Language.init(code:))
        return TranslateResult(providerId: providerId, translated: decodeHTMLEntities(text), detectedFrom: detected)
    }

    private static func errorMessage(in data: Data) -> String? {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let error = root["error"] as? [String: Any] else { return nil }
        return error["message"] as? String
    }

    private static func decodeHTMLEntities(_ text: String) -> String {
        text
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&amp;", with: "&")
    }
}
