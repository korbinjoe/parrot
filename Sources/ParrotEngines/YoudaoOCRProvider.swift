import Foundation
import CoreGraphics
import ParrotCore
import CryptoKit

/// Youdao OCR API.
public final class YoudaoOCRProvider: OCRProvider, @unchecked Sendable {
    public let id = "youdao-ocr"
    public let displayName = "有道 OCR"
    public var isAvailable: Bool { true }

    private var credentials: String?
    private let session: URLSession

    public init(session: URLSession = .shared) { self.session = session }
    public func configure(_ credentials: String?) { self.credentials = credentials }

    public func recognize(_ image: CGImage, languageHints: [Language]) async throws -> OCRResult {
        guard let creds = TencentCloudSigner.splitCredentials(credentials) else {
            throw ProviderError.notConfigured
        }
        guard let b64 = image.jpegBase64() else { throw ProviderError.network }
        let salt = UUID().uuidString
        let curtime = String(Int(Date().timeIntervalSince1970))
        let signStr = creds.id + truncate(b64) + salt + curtime + creds.secret
        let sign = SHA256.hash(data: Data(signStr.utf8)).map { String(format: "%02x", $0) }.joined()
        var request = URLRequest(url: URL(string: "https://openapi.youdao.com/ocrapi")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let fields = "img=\(b64.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? "")&langType=auto&signType=v3&curtime=\(curtime)&appKey=\(creds.id)&salt=\(salt)&sign=\(sign)&detectType=10012&imageType=1"
        request.httpBody = fields.data(using: .utf8)
        let (data, _) = try await session.data(for: request)
        return try Self.parse(data)
    }

    static func parse(_ data: Data) throws -> OCRResult {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let regions = json["Result"] as? [String: Any],
              let regionsArr = regions["regions"] as? [[String: Any]] else {
            throw ProviderError.network
        }
        var lines: [String] = []
        for region in regionsArr {
            if let linesArr = region["lines"] as? [[String: Any]] {
                for line in linesArr {
                    if let t = line["text"] as? String { lines.append(t) }
                }
            }
        }
        let text = lines.joined(separator: "\n")
        return OCRResult(fullText: text, blocks: lines.map { OCRBlock(text: $0, boundingBox: .zero, confidence: 1) }, confidence: 0.85)
    }

    private func truncate(_ s: String) -> String {
        if s.count <= 20 { return s }
        return String(s.prefix(10)) + String(s.count) + String(s.suffix(10))
    }
}

private extension CGImage {
    func jpegBase64() -> String? {
        let rep = NSBitmapImageRep(cgImage: self)
        return rep.representation(using: .jpeg, properties: [.compressionFactor: 0.8])?.base64EncodedString()
    }
}

import AppKit
