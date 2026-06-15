import Foundation
import ParrotCore

/// Azure Cognitive Services Translator (Microsoft 翻译).
public final class MicrosoftEngine: HTTPTranslationEngine {
    public init(session: URLSession = .shared) {
        super.init(id: "microsoft", displayName: "Microsoft 翻译", session: session)
    }

    public override func translate(_ req: TranslateRequest) async throws -> TranslateResult {
        guard let key = apiKey, !key.isEmpty else { throw ProviderError.notConfigured }
        let region = extra["region"] ?? "eastasia"
        let to = LanguageCodes.microsoft(req.to)
        var urlString = "https://api.cognitive.microsofttranslator.com/translate?api-version=3.0&to=\(to)"
        if req.from != .auto {
            let from = LanguageCodes.microsoft(req.from)
            if !from.isEmpty { urlString += "&from=\(from)" }
        }
        guard let url = URL(string: urlString) else { throw ProviderError.network }

        var headers = [
            "Ocp-Apim-Subscription-Key": key,
            "Content-Type": "application/json"
        ]
        if !region.isEmpty {
            headers["Ocp-Apim-Subscription-Region"] = region
        }

        let data = try await postJSON(
            url: url,
            headers: headers,
            body: [["Text": req.text]]
        )
        return try Self.parse(data, providerId: id)
    }

    static func parse(_ data: Data, providerId: String) throws -> TranslateResult {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]],
              let first = json.first,
              let translations = first["translations"] as? [[String: Any]],
              let text = translations.first?["text"] as? String else {
            throw ProviderError.network
        }
        var detected: Language?
        if let det = first["detectedLanguage"] as? [String: Any],
           let code = det["language"] as? String {
            detected = Language(code: code)
        }
        return TranslateResult(providerId: providerId, translated: text, detectedFrom: detected)
    }
}
