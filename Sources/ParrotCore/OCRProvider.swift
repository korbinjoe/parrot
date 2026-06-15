import Foundation
import CoreGraphics
import ParrotCore

public struct OCRBlock: Sendable, Equatable {
    public let text: String
    public let boundingBox: CGRect
    public let confidence: Float
    public init(text: String, boundingBox: CGRect, confidence: Float) {
        self.text = text
        self.boundingBox = boundingBox
        self.confidence = confidence
    }
}

public struct OCRResult: Sendable {
    public let fullText: String
    public let blocks: [OCRBlock]
    public let detectedLanguages: [Language]
    public let confidence: Float
    public init(fullText: String, blocks: [OCRBlock], detectedLanguages: [Language] = [], confidence: Float = 1) {
        self.fullText = fullText
        self.blocks = blocks
        self.detectedLanguages = detectedLanguages
        self.confidence = confidence
    }
}

public protocol OCRProvider: Sendable {
    var id: String { get }
    var displayName: String { get }
    var isAvailable: Bool { get }
    func recognize(_ image: CGImage, languageHints: [Language]) async throws -> OCRResult
}

/// Selects and runs the active OCR provider.
public final class OCRCoordinator: @unchecked Sendable {
    private var providers: [String: OCRProvider] = [:]
    private var defaultId: String = "apple-vision"
    private let lock = NSLock()

    public init() {}

    public func register(_ provider: OCRProvider) {
        lock.lock(); defer { lock.unlock() }
        providers[provider.id] = provider
    }

    public func setDefaultProvider(id: String) {
        lock.lock(); defer { lock.unlock() }
        defaultId = id
    }

    public func activeProvider() -> OCRProvider? {
        lock.lock(); defer { lock.unlock() }
        if let p = providers[defaultId], p.isAvailable { return p }
        return providers["apple-vision"]
    }

    public func recognize(_ image: CGImage, languageHints: [Language] = []) async throws -> OCRResult {
        guard let provider = activeProvider() else { throw ProviderError.notConfigured }
        return try await provider.recognize(image, languageHints: languageHints)
    }
}
