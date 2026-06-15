import Foundation
import CoreGraphics
import ParrotCore

/// Google Cloud Vision TEXT_DETECTION (API key in query).
public final class GoogleOCRProvider: OCRProvider, @unchecked Sendable {
    public let id = "google-ocr"
    public let displayName = "Google OCR"
    public var isAvailable: Bool { apiKey?.isEmpty == false }

    private var apiKey: String?
    private let session: URLSession

    public init(session: URLSession = .shared) { self.session = session }
    public func configure(apiKey: String?) { self.apiKey = apiKey }

    public func recognize(_ image: CGImage, languageHints: [Language]) async throws -> OCRResult {
        guard let key = apiKey, !key.isEmpty else { throw ProviderError.notConfigured }
        guard let b64 = image.jpegBase64() else { throw ProviderError.network }
        let url = URL(string: "https://vision.googleapis.com/v1/images:annotate?key=\(key)")!
        let body: [String: Any] = [
            "requests": [[
                "image": ["content": b64],
                "features": [["type": "TEXT_DETECTION"]]
            ]]
        ]
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, _) = try await session.data(for: request)
        return try Self.parse(data)
    }

    static func parse(_ data: Data) throws -> OCRResult {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let responses = json["responses"] as? [[String: Any]],
              let first = responses.first,
              let annotation = first["fullTextAnnotation"] as? [String: Any],
              let text = annotation["text"] as? String else {
            throw ProviderError.network
        }
        return OCRResult(fullText: text, blocks: [OCRBlock(text: text, boundingBox: .zero, confidence: 1)], confidence: 0.9)
    }
}

private extension CGImage {
    func jpegBase64() -> String? {
        let rep = NSBitmapImageRep(cgImage: self)
        return rep.representation(using: .jpeg, properties: [.compressionFactor: 0.8])?.base64EncodedString()
    }
}

import AppKit
