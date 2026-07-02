import Foundation
import ParrotCore

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Google translation via the free `translate_a/single` web endpoint (no API key).
/// Great as an out-of-the-box default engine. For production volume, swap to the paid Cloud API.
public final class GoogleEngine: TranslationProvider, @unchecked Sendable {
    public let id = "google"
    public let displayName = "Google"
    public let supportedLanguages: [Language] = [.auto, .zh, .en, .ja, .ko, .fr, .de, .es, .ru]
    public let capabilities = ProviderCapabilities(supportsLookup: false, supportsStream: false)

    private let session: URLSession
    public init(session: URLSession = .shared) { self.session = session }

    public func translate(_ req: TranslateRequest) async throws -> TranslateResult {
        let sl = req.from.code ?? "auto"
        let tl = req.to.code ?? "en"
        var comps = URLComponents(string: "https://translate.googleapis.com/translate_a/single")!
        comps.queryItems = [
            .init(name: "client", value: "gtx"),
            .init(name: "sl", value: sl),
            .init(name: "tl", value: tl),
            .init(name: "dt", value: "t"),
            .init(name: "q", value: req.text)
        ]
        guard let url = comps.url else { throw ProviderError.network }

        let (data, response): (Data, URLResponse)
        do { (data, response) = try await session.data(from: url) }
        catch { throw ProviderError.network }

        if let http = response as? HTTPURLResponse {
            switch http.statusCode {
            case 200: break
            case 429: throw ProviderError.rateLimited
            default: throw ProviderError.network
            }
        }
        return try Self.parse(data, providerId: id)
    }

    /// Parse the gtx response: `[[["译文","src",...],...], ..., "detectedLang", ...]`
    static func parse(_ data: Data, providerId: String) throws -> TranslateResult {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [Any],
              let segments = root.first as? [Any] else {
            throw ProviderError.network
        }
        var translated = ""
        for seg in segments {
            if let pair = seg as? [Any], let piece = pair.first as? String {
                translated += piece
            }
        }
        var detected: Language?
        if root.count > 2, let code = root[2] as? String { detected = Language(code: code) }
        guard !translated.isEmpty else { throw ProviderError.network }
        return TranslateResult(providerId: providerId, translated: translated, detectedFrom: detected)
    }
}
