import Foundation
import CryptoKit

enum TencentCloudSigner {
    static func authorize(
        secretId: String,
        secretKey: String,
        host: String,
        service: String,
        action: String,
        version: String,
        region: String,
        payload: String,
        timestamp: Int = Int(Date().timeIntervalSince1970)
    ) -> (authorization: String, timestamp: Int, date: String) {
        let date = dateString(timestamp: timestamp)
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
        let auth = "TC3-HMAC-SHA256 Credential=\(secretId)/\(credentialScope), SignedHeaders=content-type;host, Signature=\(signature)"
        return (auth, timestamp, date)
    }

    static func splitCredentials(_ combined: String?) -> (id: String, secret: String)? {
        guard let combined else { return nil }
        let parts = combined.split(separator: ":", maxSplits: 1).map(String.init)
        guard parts.count == 2, !parts[0].isEmpty, !parts[1].isEmpty else { return nil }
        return (parts[0], parts[1])
    }

    private static func dateString(timestamp: Int) -> String {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        let d = Date(timeIntervalSince1970: TimeInterval(timestamp))
        let c = cal.dateComponents([.year, .month, .day], from: d)
        return String(format: "%04d-%02d-%02d", c.year!, c.month!, c.day!)
    }

    private static func sha256Hex(_ s: String) -> String { sha256Hex(Data(s.utf8)) }
    private static func sha256Hex(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    private static func hmacSHA256(key: Data, data: Data) -> Data {
        HMAC<SHA256>.authenticationCode(for: data, using: SymmetricKey(data: key)).withUnsafeBytes { Data($0) }
    }

    private static func hmacSHA256Hex(key: Data, data: Data) -> String {
        hmacSHA256(key: key, data: data).map { String(format: "%02x", $0) }.joined()
    }
}
