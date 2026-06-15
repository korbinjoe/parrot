import Foundation
import CoreGraphics
import Vision
import ParrotCore

/// Offline OCR via Apple Vision (default).
public final class AppleVisionOCRProvider: OCRProvider, @unchecked Sendable {
    public let id = "apple-vision"
    public let displayName = "离线文本识别"
    public var isAvailable: Bool { true }

    public init() {}

    public func recognize(_ image: CGImage, languageHints: [Language]) async throws -> OCRResult {
        let hints = languageHints.compactMap { lang -> String? in
            switch lang {
            case .zh: return "zh-Hans"
            case .en: return "en-US"
            case .ja: return "ja-JP"
            case .ko: return "ko-KR"
            case .auto: return nil
            default: return lang.code.map { $0 + "-US" } ?? "en-US"
            }
        }
        let langs = hints.isEmpty ? ["zh-Hans", "en-US"] : hints
        return try await Self.recognizeVision(image, languages: langs)
    }

    static func recognizeVision(_ image: CGImage, languages: [String]) async throws -> OCRResult {
        try await withCheckedThrowingContinuation { cont in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let result = try performVision(image, languages: languages)
                    cont.resume(returning: result)
                } catch {
                    cont.resume(throwing: error)
                }
            }
        }
    }

    private static func performVision(_ image: CGImage, languages: [String]) throws -> OCRResult {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.recognitionLanguages = languages

        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        try handler.perform([request])
        guard let observations = request.results else { throw ProviderError.network }

        let lines: [(CGRect, String, Float)] = observations.compactMap { obs in
            guard let top = obs.topCandidates(1).first else { return nil }
            return (obs.boundingBox, top.string, top.confidence)
        }
        let ordered = lines.sorted { a, b in
            if abs(a.0.origin.y - b.0.origin.y) > 0.02 { return a.0.origin.y > b.0.origin.y }
            return a.0.origin.x < b.0.origin.x
        }
        let blocks = ordered.map { OCRBlock(text: $0.1, boundingBox: $0.0, confidence: $0.2) }
        let text = blocks.map(\.text).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }.joined(separator: "\n")
        let avgConf = blocks.isEmpty ? 0 : blocks.map(\.confidence).reduce(0, +) / Float(blocks.count)
        return OCRResult(fullText: text, blocks: blocks, confidence: avgConf)
    }
}
