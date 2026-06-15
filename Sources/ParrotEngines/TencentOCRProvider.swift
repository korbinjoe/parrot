import Foundation
import CoreGraphics
import ParrotCore

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Tencent general OCR (GeneralBasicOCR).
public final class TencentOCRProvider: OCRProvider, @unchecked Sendable {
    public let id = "tencent-ocr"
    public let displayName = "腾讯 OCR"
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
        let payloadObj: [String: Any] = ["ImageBase64": b64]
        let bodyData = try JSONSerialization.data(withJSONObject: payloadObj)
        let bodyString = String(data: bodyData, encoding: .utf8) ?? "{}"
        let host = "ocr.tencentcloudapi.com"
        let signed = TencentCloudSigner.authorize(
            secretId: creds.id, secretKey: creds.secret,
            host: host, service: "ocr", action: "GeneralBasicOCR", version: "2018-11-19",
            region: region, payload: bodyString
        )
        var request = URLRequest(url: URL(string: "https://\(host)/")!)
        request.httpMethod = "POST"
        request.httpBody = bodyData
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(host, forHTTPHeaderField: "Host")
        request.setValue("GeneralBasicOCR", forHTTPHeaderField: "X-TC-Action")
        request.setValue("2018-11-19", forHTTPHeaderField: "X-TC-Version")
        request.setValue(String(signed.timestamp), forHTTPHeaderField: "X-TC-Timestamp")
        request.setValue(region, forHTTPHeaderField: "X-TC-Region")
        request.setValue(signed.authorization, forHTTPHeaderField: "Authorization")
        let (data, response) = try await session.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw ProviderError.auth }
        return try Self.parse(data)
    }

    static func parse(_ data: Data) throws -> OCRResult {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let resp = json["Response"] as? [String: Any],
              let items = resp["TextDetections"] as? [[String: Any]] else {
            throw ProviderError.network
        }
        let lines = items.compactMap { $0["DetectedText"] as? String }
        let text = lines.joined(separator: "\n")
        let blocks = lines.enumerated().map { i, t in
            OCRBlock(text: t, boundingBox: CGRect(x: 0, y: CGFloat(i), width: 1, height: 1), confidence: 1)
        }
        return OCRResult(fullText: text, blocks: blocks, confidence: 0.9)
    }
}

private extension CGImage {
    func jpegBase64() -> String? {
        let rep = NSBitmapImageRep(cgImage: self)
        return rep.representation(using: .jpeg, properties: [.compressionFactor: 0.8])?.base64EncodedString()
    }
}

import AppKit
