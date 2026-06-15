import Foundation
import ParrotCore
import CryptoKit

/// Baidu general translation API (vip translate).
public final class BaiduEngine: HTTPTranslationEngine {
    public init(session: URLSession = .shared) {
        super.init(id: "baidu", displayName: "百度翻译", session: session)
    }

    public override func translate(_ req: TranslateRequest) async throws -> TranslateResult {
        guard let creds = splitCredentials(apiKey, extra: extra, idKey: "appId", secretKey: "appSecret"),
              !creds.id.isEmpty, !creds.secret.isEmpty else {
            throw ProviderError.notConfigured
        }

        let salt = String(Int.random(in: 10000...99999))
        let sign = md5Hex(creds.id + req.text + salt + creds.secret)
        let fields: [String: String] = [
            "q": req.text,
            "from": LanguageCodes.baidu(req.from),
            "to": LanguageCodes.baidu(req.to),
            "appid": creds.id,
            "salt": salt,
            "sign": sign
        ]
        let data = try await postForm(
            url: URL(string: "https://fanyi-api.baidu.com/api/trans/vip/translate")!,
            fields: fields
        )
        return try Self.parse(data, providerId: id)
    }

    static func parse(_ data: Data, providerId: String) throws -> TranslateResult {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ProviderError.network
        }
        if json["error_code"] != nil { throw ProviderError.auth }
        guard let trans = json["trans_result"] as? [[String: Any]],
              let first = trans.first,
              let dst = first["dst"] as? String else {
            throw ProviderError.network
        }
        var detected: Language?
        if let src = first["src"] as? String { detected = Language(code: src) }
        return TranslateResult(providerId: providerId, translated: dst, detectedFrom: detected)
    }
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

private func md5Hex(_ s: String) -> String {
    Insecure.MD5.hash(data: Data(s.utf8)).map { String(format: "%02x", $0) }.joined()
}
