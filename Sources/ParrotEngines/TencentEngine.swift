import Foundation
import ParrotCore
import CryptoKit

/// Tencent Cloud TMT (TextTranslate) via API 3.0 JSON + TC3-HMAC-SHA256.
public final class TencentEngine: HTTPTranslationEngine {
    public init(session: URLSession = .shared) {
        super.init(id: "tencent", displayName: "腾讯翻译君", session: session)
    }

    public override func translate(_ req: TranslateRequest) async throws -> TranslateResult {
        guard let creds = splitCredentials(apiKey, extra: extra, idKey: "secretId", secretKey: "secretKey"),
              !creds.id.isEmpty, !creds.secret.isEmpty else {
            throw ProviderError.notConfigured
        }

        let payload: [String: Any] = [
            "SourceText": req.text,
            "Source": LanguageCodes.tencent(req.from == .auto ? .auto : req.from),
            "Target": LanguageCodes.tencent(req.to),
            "ProjectId": Int(extra["projectId"] ?? "0") ?? 0
        ]
        let bodyData = try JSONSerialization.data(withJSONObject: payload)
        let bodyString = String(data: bodyData, encoding: .utf8) ?? "{}"

        let host = "tmt.tencentcloudapi.com"
        let service = "tmt"
        let action = "TextTranslate"
        let version = "2018-03-21"
        let timestamp = Int(Date().timeIntervalSince1970)
        let date = tencentDateString(timestamp: timestamp)

        let auth = try tencentAuthorization(
            secretId: creds.id,
            secretKey: creds.secret,
            host: host,
            service: service,
            action: action,
            version: version,
            timestamp: timestamp,
            date: date,
            payload: bodyString
        )

        var request = URLRequest(url: URL(string: "https://\(host)/")!)
        request.httpMethod = "POST"
        request.httpBody = bodyData
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(host, forHTTPHeaderField: "Host")
        request.setValue(action, forHTTPHeaderField: "X-TC-Action")
        request.setValue(version, forHTTPHeaderField: "X-TC-Version")
        request.setValue(String(timestamp), forHTTPHeaderField: "X-TC-Timestamp")
        request.setValue(extra["region"] ?? "ap-guangzhou", forHTTPHeaderField: "X-TC-Region")
        request.setValue(auth, forHTTPHeaderField: "Authorization")

        let (data, response): (Data, URLResponse)
        do { (data, response) = try await session.data(for: request) }
        catch { throw ProviderError.network }
        try throwIfHTTPError(response)
        return try Self.parse(data, providerId: id)
    }

    static func parse(_ data: Data, providerId: String) throws -> TranslateResult {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let resp = json["Response"] as? [String: Any] else {
            throw ProviderError.network
        }
        if resp["Error"] != nil { throw ProviderError.auth }
        guard let text = resp["TargetText"] as? String else { throw ProviderError.network }
        var detected: Language?
        if let src = resp["Source"] as? String { detected = Language(code: src) }
        return TranslateResult(providerId: providerId, translated: text, detectedFrom: detected)
    }
}

// MARK: - TC3 signing (minimal subset for TMT)

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

private func tencentDateString(timestamp: Int) -> String {
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = TimeZone(identifier: "UTC")!
    let d = Date(timeIntervalSince1970: TimeInterval(timestamp))
    let c = cal.dateComponents([.year, .month, .day], from: d)
    return String(format: "%04d-%02d-%02d", c.year!, c.month!, c.day!)
}

private func tencentAuthorization(
    secretId: String,
    secretKey: String,
    host: String,
    service: String,
    action: String,
    version: String,
    timestamp: Int,
    date: String,
    payload: String
) throws -> String {
    let hashedPayload = sha256Hex(payload)
    let canonical = """
    POST
    /
    
    content-type:application/json
    host:\(host)
    
    content-type;host
    \(hashedPayload)
    """
    let credentialScope = "\(date)/\(service)/tc3_request"
    let stringToSign = """
    TC3-HMAC-SHA256
    \(timestamp)
    \(credentialScope)
    \(sha256Hex(canonical))
    """
    let kDate = hmacSHA256(key: Data("TC3\(secretKey)".utf8), data: Data(date.utf8))
    let kService = hmacSHA256(key: kDate, data: Data(service.utf8))
    let kSigning = hmacSHA256(key: kService, data: Data("tc3_request".utf8))
    let signature = hmacSHA256Hex(key: kSigning, data: Data(stringToSign.utf8))
    return "TC3-HMAC-SHA256 Credential=\(secretId)/\(credentialScope), SignedHeaders=content-type;host, Signature=\(signature)"
}

private func sha256Hex(_ s: String) -> String {
    sha256Hex(Data(s.utf8))
}

private func sha256Hex(_ data: Data) -> String {
    SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
}

private func hmacSHA256(key: Data, data: Data) -> Data {
    let keySym = SymmetricKey(data: key)
    let mac = HMAC<SHA256>.authenticationCode(for: data, using: keySym)
    return Data(mac)
}

private func hmacSHA256Hex(key: Data, data: Data) -> String {
    hmacSHA256(key: key, data: data).map { String(format: "%02x", $0) }.joined()
}
