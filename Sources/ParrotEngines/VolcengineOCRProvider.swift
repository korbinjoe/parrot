import Foundation
import CoreGraphics
import ParrotCore

/// Volcengine OCR placeholder (same credential pattern as translate).
public final class VolcengineOCRProvider: OCRProvider, @unchecked Sendable {
    public let id = "volcengine-ocr"
    public let displayName = "火山 OCR"
    public var isAvailable: Bool { apiKey?.isEmpty == false }

    private var apiKey: String?
    private let session: URLSession

    public init(session: URLSession = .shared) { self.session = session }
    public func configure(apiKey: String?) { self.apiKey = apiKey }

    public func recognize(_ image: CGImage, languageHints: [Language]) async throws -> OCRResult {
        guard let key = apiKey, !key.isEmpty else { throw ProviderError.notConfigured }
        guard let b64 = image.jpegBase64() else { throw ProviderError.network }
        let body: [String: Any] = ["image_base64": b64]
        var request = URLRequest(url: URL(string: "https://visual.volcengineapi.com?Action=OCRNormal&Version=2020-08-26")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, _) = try await session.data(for: request)
        return try Self.parse(data)
    }

    static func parse(_ data: Data) throws -> OCRResult {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let text = json["text"] as? String ?? (json["data"] as? [String: Any])?["text"] as? String else {
            throw ProviderError.network
        }
        return OCRResult(fullText: text, blocks: [OCRBlock(text: text, boundingBox: .zero, confidence: 1)], confidence: 0.85)
    }
}

private extension CGImage {
    func jpegBase64() -> String? {
        let rep = NSBitmapImageRep(cgImage: self)
        return rep.representation(using: .jpeg, properties: [.compressionFactor: 0.8])?.base64EncodedString()
    }
}

import AppKit
