import CoreGraphics
import Foundation
import ParrotCore

public enum SocialMode: String, Codable, Sendable, CaseIterable {
    case understand
    case express
    case ocr
}

public enum SourceOrigin: String, Codable, Sendable, CaseIterable {
    case shareExtension
    case clipboard
    case screenshot
    case latestScreenshot
    case photoLibrary
    case manualInput
    case history
    case keyboard
    case shortcut
}

public enum PlatformPreset: String, Codable, Sendable, CaseIterable, Identifiable {
    case general
    case x
    case reddit
    case linkedin
    case email

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .general: return "General"
        case .x: return "X"
        case .reddit: return "Reddit"
        case .linkedin: return "LinkedIn"
        case .email: return "Email"
        }
    }
}

public enum TonePreset: String, Codable, Sendable, CaseIterable, Identifiable {
    case natural
    case friendly
    case firm
    case redditStyle
    case xShort
    case politeDisagreement

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .natural: return "Natural"
        case .friendly: return "Friendly"
        case .firm: return "Firm"
        case .redditStyle: return "Reddit-style"
        case .xShort: return "X-short"
        case .politeDisagreement: return "Polite disagreement"
        }
    }
}

public enum RefinementAction: String, Codable, Sendable, CaseIterable, Identifiable {
    case shorter
    case moreCasual
    case morePolite
    case keepMyAttitude
    case addContext

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .shorter: return "Shorter"
        case .moreCasual: return "More casual"
        case .morePolite: return "More polite"
        case .keepMyAttitude: return "Keep my attitude"
        case .addContext: return "Add context"
        }
    }
}

public struct PhraseExplanation: Codable, Sendable, Equatable, Identifiable {
    public var id: String { phrase }
    public var phrase: String
    public var explanation: String

    public init(phrase: String, explanation: String) {
        self.phrase = phrase
        self.explanation = explanation
    }
}

public struct UnderstandResult: Codable, Sendable, Equatable {
    public var meaningSummary: String
    public var toneTags: [String]
    public var phraseExplanations: [PhraseExplanation]
    public var fullTranslation: String?
    public var confidenceNote: String?

    public init(
        meaningSummary: String,
        toneTags: [String] = [],
        phraseExplanations: [PhraseExplanation] = [],
        fullTranslation: String? = nil,
        confidenceNote: String? = nil
    ) {
        self.meaningSummary = meaningSummary
        self.toneTags = toneTags
        self.phraseExplanations = phraseExplanations
        self.fullTranslation = fullTranslation
        self.confidenceNote = confidenceNote
    }
}

public struct ReplyCandidate: Identifiable, Codable, Sendable, Equatable {
    public var id: UUID
    public var title: String
    public var text: String
    public var tone: TonePreset

    public init(id: UUID = UUID(), title: String, text: String, tone: TonePreset) {
        self.id = id
        self.title = title
        self.text = text
        self.tone = tone
    }
}

public struct ExpressResult: Codable, Sendable, Equatable {
    public var candidates: [ReplyCandidate]

    public init(candidates: [ReplyCandidate]) {
        self.candidates = candidates
    }
}

public struct CGRectCodable: Codable, Sendable, Equatable {
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double

    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }

    public init(_ rect: CGRect) {
        self.init(
            x: Double(rect.origin.x),
            y: Double(rect.origin.y),
            width: Double(rect.size.width),
            height: Double(rect.size.height)
        )
    }

    public var cgRect: CGRect {
        CGRect(x: x, y: y, width: width, height: height)
    }

    public var clampedUnitRect: CGRectCodable {
        let minX = max(0, min(1, x))
        let minY = max(0, min(1, y))
        let maxX = max(minX, min(1, x + width))
        let maxY = max(minY, min(1, y + height))
        return CGRectCodable(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }
}

public struct CGSizeCodable: Codable, Sendable, Equatable {
    public var width: Double
    public var height: Double

    public init(width: Double, height: Double) {
        self.width = width
        self.height = height
    }

    public init(_ size: CGSize) {
        self.init(width: Double(size.width), height: Double(size.height))
    }

    public var cgSize: CGSize {
        CGSize(width: width, height: height)
    }
}

public enum QuickLensRoleHint: String, Codable, Sendable, Equatable {
    case primaryBody
    case comment
    case quote
    case username
    case timestamp
    case navigation
    case unknown
}

public struct QuickLensCandidate: Identifiable, Codable, Sendable, Equatable {
    public var id: UUID
    public var text: String
    public var boundingBox: CGRectCodable
    public var lineBoxes: [CGRectCodable]
    public var confidence: Float
    public var score: Double
    public var debugReason: String?
    public var roleHint: QuickLensRoleHint
    public var isNoise: Bool

    public init(
        id: UUID = UUID(),
        text: String,
        boundingBox: CGRectCodable,
        lineBoxes: [CGRectCodable],
        confidence: Float,
        score: Double,
        debugReason: String? = nil,
        roleHint: QuickLensRoleHint = .unknown,
        isNoise: Bool = false
    ) {
        self.id = id
        self.text = text
        self.boundingBox = boundingBox
        self.lineBoxes = lineBoxes
        self.confidence = confidence
        self.score = score
        self.debugReason = debugReason
        self.roleHint = roleHint
        self.isNoise = isNoise
    }
}

public struct QuickLensState: Codable, Sendable, Equatable {
    public var imageFileName: String
    public var imagePixelSize: CGSizeCodable
    public var screenshotCreatedAt: Date
    public var candidates: [QuickLensCandidate]
    public var selectedCandidateID: UUID?
    public var ocrConfidence: Float

    public init(
        imageFileName: String,
        imagePixelSize: CGSizeCodable,
        screenshotCreatedAt: Date,
        candidates: [QuickLensCandidate],
        selectedCandidateID: UUID? = nil,
        ocrConfidence: Float
    ) {
        self.imageFileName = imageFileName
        self.imagePixelSize = imagePixelSize
        self.screenshotCreatedAt = screenshotCreatedAt
        self.candidates = candidates
        self.selectedCandidateID = selectedCandidateID
        self.ocrConfidence = ocrConfidence
    }

    public var selectedCandidate: QuickLensCandidate? {
        guard let selectedCandidateID else { return nil }
        return candidates.first { $0.id == selectedCandidateID }
    }

    public mutating func selectCandidate(id: UUID) -> QuickLensCandidate? {
        guard let candidate = candidates.first(where: { $0.id == id }) else { return nil }
        selectedCandidateID = id
        return candidate
    }
}

public struct SocialTextSession: Identifiable, Codable, Sendable, Equatable {
    public var id: UUID
    public var mode: SocialMode
    public var origin: SourceOrigin
    public var platform: PlatformPreset
    public var sourceDraft: String
    public var sourceImageFileName: String?
    public var contextText: String?
    public var userIntentDraft: String
    public var selectedTone: TonePreset
    public var understand: UnderstandResult?
    public var express: ExpressResult?
    public var quickLens: QuickLensState?
    public var createdAt: Date
    public var updatedAt: Date
    public var isFavorite: Bool

    public init(
        id: UUID = UUID(),
        mode: SocialMode = .understand,
        origin: SourceOrigin,
        platform: PlatformPreset = .general,
        sourceDraft: String,
        sourceImageFileName: String? = nil,
        contextText: String? = nil,
        userIntentDraft: String = "",
        selectedTone: TonePreset = .natural,
        understand: UnderstandResult? = nil,
        express: ExpressResult? = nil,
        quickLens: QuickLensState? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        isFavorite: Bool = false
    ) {
        self.id = id
        self.mode = mode
        self.origin = origin
        self.platform = platform
        self.sourceDraft = sourceDraft
        self.sourceImageFileName = sourceImageFileName
        self.contextText = contextText
        self.userIntentDraft = userIntentDraft
        self.selectedTone = selectedTone
        self.understand = understand
        self.express = express
        self.quickLens = quickLens
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isFavorite = isFavorite
    }

    public var sourceDraftTrimmed: String {
        sourceDraft.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public var userIntentTrimmed: String {
        userIntentDraft.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public mutating func switchToExpress() {
        mode = .express
        contextText = sourceDraftTrimmed.isEmpty ? contextText : sourceDraft
        updatedAt = Date()
    }

    public mutating func apply(_ result: UnderstandResult) {
        understand = result
        updatedAt = Date()
    }

    public mutating func apply(_ result: ExpressResult) {
        express = result
        updatedAt = Date()
    }
}

public extension Language {
    var socialDisplayName: String {
        switch self {
        case .auto: return "auto"
        case .zh: return "Chinese"
        case .en: return "English"
        case .ja: return "Japanese"
        case .ko: return "Korean"
        case .fr: return "French"
        case .de: return "German"
        case .es: return "Spanish"
        case .ru: return "Russian"
        case .custom(let code): return code
        }
    }
}
