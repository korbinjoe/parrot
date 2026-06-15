import Foundation

enum EngineCredentials {
    static func split(_ combined: String?, idKey: String, secretKey: String, extra: [String: String]) -> (id: String, secret: String)? {
        if let id = extra[idKey], let secret = extra[secretKey], !id.isEmpty, !secret.isEmpty {
            return (id, secret)
        }
        return TencentCloudSigner.splitCredentials(combined)
    }
}
