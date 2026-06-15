import Foundation
import ParrotCore

/// Caiyun Xiaoyi translator API v1.
public final class CaiyunEngine: HTTPTranslationEngine {
    public init(session: URLSession = .shared) {
        super.init(id: "caiyun", displayName: "彩云小译", session: session)
    }

    public override func translate(_ req: TranslateRequest) async throws -> TranslateResult {
        guard let token = apiKey, !token.isEmpty else { throw ProviderError.notConfigured }

        let transType = LanguageCodes.caiyunType(from: req.from, to: req.to)
        let body: [String: Any] = [
            "source": req.text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init),
            "trans_type": transType,
            "request_id": UUID().uuidString,
            "detect": true
        ]
        let data = try await postJSON(
            url: URL(string: "https://api.interpreter.caiyunai.com/v1/translator")!,
            headers: ["X-Authorization": "token \(token)"],
            body: body
        )
        return try Self.parse(data, providerId: id)
    }

    static func parse(_ data: Data, providerId: String) throws -> TranslateResult {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let target = json["target"] as? [String],
              !target.isEmpty else {
            throw ProviderError.network
        }
        return TranslateResult(providerId: providerId, translated: target.joined(separator: "\n"))
    }
}
