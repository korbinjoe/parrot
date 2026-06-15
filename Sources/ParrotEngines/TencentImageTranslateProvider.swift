import Foundation
import CoreGraphics
import ParrotCore

/// Tencent TMT ImageTranslate (OCR + translate in one call).
public final class TencentImageTranslateProvider: OCRProvider, @unchecked Sendable {
    public let id = "tencent-image-translate"
    public let displayName = "腾讯图片翻译"
    public var isAvailable: Bool { true }

    private var credentials: String?
    private var region: String = "ap-guangzhou"
    private let session: URLSession

    public init(session: URLSession = .shared) { self.session = session }

    public func configure(credentials: String?, region: String = "ap-guangzhou") {
        self.credentials = credentials
        self.region = region
    }

    public func recognize(_ image: CGImage, languageHints: [Language]) async throws -> OCRResult {
        guard let creds = TencentCloudSigner.splitCredentials(credentials) else {
            throw ProviderError.notConfigured
        }
        guard let b64 = image.jpegBase64() else { throw ProviderError.network }
        let payload: [String: Any] = ["Data": b64, "Source": "auto", "Target": "zh"]
        let bodyData = try JSONSerialization.data(withJSONObject: payload)
        let bodyString = String(data: bodyData, encoding: .utf8) ?? "{}"
        let host = "tmt.tencentcloudapi.com"
        let signed = TencentCloudSigner.authorize(
            secretId: creds.id, secretKey: creds.secret,
            host: host, service: "tmt", action: "ImageTranslate", version: "2018-03-21",
            region: region, payload: bodyString
        )
        var request = URLRequest(url: URL(string: "https://\(host)/")!)
        request.httpMethod = "POST"
        request.httpBody = bodyData
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(host, forHTTPHeaderField: "Host")
        request.setValue("ImageTranslate", forHTTPHeaderField: "X-TC-Action")
        request.setValue("2018-03-21", forHTTPHeaderField: "X-TC-Version")
        request.setValue(String(signed.timestamp), forHTTPHeaderField: "X-TC-Timestamp")
        request.setValue(region, forHTTPHeaderField: "X-TC-Region")
        request.setValue(signed.authorization, forHTTPHeaderField: "Authorization")
        let (data, _) = try await session.data(for: request)
        return try Self.parse(data)
    }

    static func parse(_ data: Data) throws -> OCRResult {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let resp = json["Response"] as? [String: Any],
              let source = resp["SourceText"] as? String else {
            throw ProviderError.network
        }
        return OCRResult(fullText: source, blocks: [OCRBlock(text: source, boundingBox: .zero, confidence: 1)], confidence: 0.9)
    }
}

private extension CGImage {
    func jpegBase64() -> String? {
        let rep = NSBitmapImageRep(cgImage: self)
        return rep.representation(using: .jpeg, properties: [.compressionFactor: 0.8])?.base64EncodedString()
    }
}

import AppKit
