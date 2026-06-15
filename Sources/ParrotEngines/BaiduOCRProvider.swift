import AppKit
import Foundation
import CoreGraphics
import ParrotCore
import CryptoKit

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Baidu general OCR (general_basic). Credentials: `ApiKey:SecretKey` (same app as translate).
public final class BaiduOCRProvider: OCRProvider, @unchecked Sendable {
    public let id = "baidu-ocr"
    public let displayName = "百度 OCR"
    public var isAvailable: Bool { true }

    private var credentials: String?
    private let session: URLSession

    public init(session: URLSession = .shared) { self.session = session }

    public func configure(_ credentials: String?) { self.credentials = credentials }

    public func recognize(_ image: CGImage, languageHints: [Language]) async throws -> OCRResult {
        guard let creds = TencentCloudSigner.splitCredentials(credentials) else {
            throw ProviderError.notConfigured
        }
        let token = try await fetchToken(apiKey: creds.id, secret: creds.secret)
        guard let png = image.pngData()?.base64EncodedString() else { throw ProviderError.network }
        var request = URLRequest(url: URL(string: "https://aip.baidubce.com/rest/2.0/ocr/v1/general_basic?access_token=\(token)")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = "image=\(png.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")".data(using: .utf8)
        let (data, response) = try await session.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw ProviderError.auth }
        return try Self.parse(data)
    }

    static func parse(_ data: Data) throws -> OCRResult {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let words = json["words_result"] as? [[String: Any]] else {
            throw ProviderError.network
        }
        let lines = words.compactMap { $0["words"] as? String }
        let text = lines.joined(separator: "\n")
        let blocks = lines.enumerated().map { i, t in
            OCRBlock(text: t, boundingBox: CGRect(x: 0, y: CGFloat(i), width: 1, height: 1), confidence: 1)
        }
        return OCRResult(fullText: text, blocks: blocks, confidence: 0.9)
    }

    private func fetchToken(apiKey: String, secret: String) async throws -> String {
        var comps = URLComponents(string: "https://aip.baidubce.com/oauth/2.0/token")!
        comps.queryItems = [
            URLQueryItem(name: "grant_type", value: "client_credentials"),
            URLQueryItem(name: "client_id", value: apiKey),
            URLQueryItem(name: "client_secret", value: secret)
        ]
        let (data, _) = try await session.data(from: comps.url!)
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let token = json["access_token"] as? String else {
            throw ProviderError.auth
        }
        return token
    }
}

private extension CGImage {
    func pngData() -> Data? {
        let rep = NSBitmapImageRep(cgImage: self)
        return rep.representation(using: .png, properties: [:])
    }
}