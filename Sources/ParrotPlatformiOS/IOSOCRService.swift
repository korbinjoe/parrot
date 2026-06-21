import CoreGraphics
import Foundation
import ParrotCore

#if canImport(Vision)
import Vision
#endif

#if canImport(UIKit)
import UIKit
#endif

public struct IOSOCRService: Sendable {
    public init() {}

    public func recognize(fileURL: URL) async throws -> OCRResult {
        #if canImport(UIKit)
        guard let image = UIImage(contentsOfFile: fileURL.path)?.cgImage else {
            throw ProviderError.service("Unable to load image for OCR.")
        }
        return try await recognize(image)
        #else
        _ = fileURL
        throw ProviderError.unsupportedLanguage
        #endif
    }

    public func recognize(_ image: CGImage) async throws -> OCRResult {
        #if canImport(Vision)
        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                let observations = (request.results as? [VNRecognizedTextObservation]) ?? []
                let blocks = observations.compactMap { observation -> OCRBlock? in
                    guard let candidate = observation.topCandidates(1).first else { return nil }
                    return OCRBlock(
                        text: candidate.string,
                        boundingBox: observation.boundingBox,
                        confidence: candidate.confidence
                    )
                }
                let text = blocks.map(\.text).joined(separator: "\n")
                let confidence = blocks.isEmpty ? 0 : blocks.map(\.confidence).reduce(0, +) / Float(blocks.count)
                continuation.resume(returning: OCRResult(fullText: text, blocks: blocks, confidence: confidence))
            }
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            let handler = VNImageRequestHandler(cgImage: image)
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
        #else
        _ = image
        throw ProviderError.unsupportedLanguage
        #endif
    }
}
