import Foundation
import ParrotCore
import CryptoKit

/// Youdao Zhiyun translation / dictionary API.
public final class YoudaoEngine: HTTPTranslationEngine {
    public init(session: URLSession = .shared) {
        super.init(
            id: "youdao",
            displayName: "有道翻译",
            capabilities: ProviderCapabilities(supportsLookup: true)
        )
    }

    public override func translate(_ req: TranslateRequest) async throws -> TranslateResult {
        guard let creds = splitCredentials(apiKey, extra: extra, idKey: "appKey", secretKey: "appSecret"),
              !creds.id.isEmpty, !creds.secret.isEmpty else {
            throw ProviderError.notConfigured
        }

        let salt = String(Int.random(in: 10000...99999))
        let curtime = String(Int(Date().timeIntervalSince1970))
        let truncated = truncateQuery(req.text)
        let signStr = creds.id + truncated + salt + curtime + creds.secret
        let sign = sha256Hex(signStr)

        let fields: [String: String] = [
            "q": req.text,
            "from": LanguageCodes.youdao(req.from),
            "to": LanguageCodes.youdao(req.to),
            "appKey": creds.id,
            "salt": salt,
            "sign": sign,
            "signType": "v3",
            "curtime": curtime
        ]
        let data = try await postForm(
            url: URL(string: "https://openapi.youdao.com/api")!,
            fields: fields
        )
        return try Self.parse(data, providerId: id, mode: req.mode)
    }

    static func parse(_ data: Data, providerId: String, mode: TranslateMode = .translate) throws -> TranslateResult {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let errorCode = json["errorCode"] as? String,
              errorCode == "0" else {
            throw ProviderError.auth
        }
        guard let results = (json["translation"] as? [String])?.joined(),
              !results.isEmpty else {
            throw ProviderError.network
        }

        var phonetics: [Phonetic]?
        var definitions: [Definition]?
        if mode == .lookup, let basic = json["basic"] as? [String: Any] {
            if let us = basic["us-phonetic"] as? String { phonetics = [Phonetic(type: "US", value: us)] }
            if let uk = basic["uk-phonetic"] as? String {
                phonetics = (phonetics ?? []) + [Phonetic(type: "UK", value: uk)]
            }
            if let explains = basic["explains"] as? [String], !explains.isEmpty {
                definitions = [Definition(partOfSpeech: "", meanings: explains)]
            }
        }

        return TranslateResult(
            providerId: providerId,
            translated: results,
            phonetics: phonetics,
            definitions: definitions
        )
    }
}

private func truncateQuery(_ q: String) -> String {
    if q.count <= 20 { return q }
    return String(q.prefix(10)) + String(q.count) + String(q.suffix(10))
}

private func splitCredentials(
    _ apiKey: String?,
    extra: [String: String],
    idKey: String,
    secretKey: String
) -> (id: String, secret: String)? {
    if let id = extra[idKey], let secret = extra[secretKey], !id.isEmpty, !secret.isEmpty {
        return (id, secret)
    }
    guard let combined = apiKey else { return nil }
    let parts = combined.split(separator: ":", maxSplits: 1).map(String.init)
    guard parts.count == 2 else { return nil }
    return (parts[0], parts[1])
}

private func sha256Hex(_ s: String) -> String {
    SHA256.hash(data: Data(s.utf8)).map { String(format: "%02x", $0) }.joined()
}
