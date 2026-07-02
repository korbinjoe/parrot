import Foundation

public enum TranslationContextProfile: String, Codable, Sendable, Equatable, CaseIterable {
    case quickTranslate
    case understand
    case nativePolish
    case reply
    case strictTerminology
    case privateLocal
    case github
    case social
    case email
    case document

    public static func defaultProfile(
        mode: TranslateMode,
        origin: TranslationOrigin = .unknown,
        text: String = "",
        hasTerminology: Bool = false
    ) -> TranslationContextProfile {
        switch mode {
        case .lookup:
            return .quickTranslate
        case .polish:
            return .nativePolish
        case .translate:
            if hasTerminology { return .strictTerminology }
            switch origin {
            case .ocr, .latestScreenshot, .screenshot, .shareExtension:
                return .understand
            case .url:
                return .document
            case .lookup, .manualInput, .history, .selection, .clipboard, .shortcut, .popClip, .unknown:
                let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                return trimmed.count >= 280 || trimmed.contains("\n\n") ? .document : .quickTranslate
            }
        }
    }
}

public enum TranslationOrigin: String, Codable, Sendable, Equatable, CaseIterable {
    case selection
    case lookup
    case manualInput
    case ocr
    case screenshot
    case latestScreenshot
    case shareExtension
    case clipboard
    case history
    case shortcut
    case popClip
    case url
    case unknown
}

public enum PrivacyPolicy: String, Codable, Sendable, Equatable {
    case standard
    case maskSensitive
    case localOnly

    public var shouldMaskSensitiveEntities: Bool {
        switch self {
        case .standard: return false
        case .maskSensitive, .localOnly: return true
        }
    }

    public var allowsCloudProviders: Bool {
        self != .localOnly
    }
}

public struct ProviderRoutingHints: Codable, Equatable, Sendable {
    public var preferredProviderIDs: [String]
    public var allowedProviderIDs: [String]?
    public var preferLLM: Bool
    public var preferLocal: Bool

    public init(
        preferredProviderIDs: [String] = [],
        allowedProviderIDs: [String]? = nil,
        preferLLM: Bool = false,
        preferLocal: Bool = false
    ) {
        self.preferredProviderIDs = preferredProviderIDs
        self.allowedProviderIDs = allowedProviderIDs
        self.preferLLM = preferLLM
        self.preferLocal = preferLocal
    }
}

public struct ParagraphHint: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public var source: String
    public var ordinal: Int
    public var isProtected: Bool

    public init(
        id: UUID = UUID(),
        source: String,
        ordinal: Int,
        isProtected: Bool = false
    ) {
        self.id = id
        self.source = source
        self.ordinal = ordinal
        self.isProtected = isProtected
    }
}

public struct TranslationContext: Codable, Equatable, Sendable {
    public var profile: TranslationContextProfile
    public var origin: TranslationOrigin
    public var sourceApp: String?
    public var windowTitle: String?
    public var sourceURL: String?
    public var selectedOCRBlockID: UUID?
    public var paragraphHints: [ParagraphHint]
    public var privacyPolicy: PrivacyPolicy
    public var routingHints: ProviderRoutingHints

    public init(
        profile: TranslationContextProfile,
        origin: TranslationOrigin = .unknown,
        sourceApp: String? = nil,
        windowTitle: String? = nil,
        sourceURL: String? = nil,
        selectedOCRBlockID: UUID? = nil,
        paragraphHints: [ParagraphHint] = [],
        privacyPolicy: PrivacyPolicy = .standard,
        routingHints: ProviderRoutingHints = ProviderRoutingHints()
    ) {
        self.profile = profile
        self.origin = origin
        self.sourceApp = sourceApp
        self.windowTitle = windowTitle
        self.sourceURL = sourceURL
        self.selectedOCRBlockID = selectedOCRBlockID
        self.paragraphHints = paragraphHints
        self.privacyPolicy = privacyPolicy
        self.routingHints = routingHints
    }

    public static func `default`(
        mode: TranslateMode,
        origin: TranslationOrigin = .unknown,
        text: String,
        terminology: TerminologySnapshot? = nil
    ) -> TranslationContext {
        let profile = TranslationContextProfile.defaultProfile(
            mode: mode,
            origin: origin,
            text: text,
            hasTerminology: terminology?.isEmpty == false
        )
        let privacyPolicy: PrivacyPolicy
        switch profile {
        case .privateLocal:
            privacyPolicy = .localOnly
        case .github, .email:
            privacyPolicy = .maskSensitive
        default:
            privacyPolicy = .standard
        }
        return TranslationContext(
            profile: profile,
            origin: origin,
            paragraphHints: ParagraphSegmenter.segment(text),
            privacyPolicy: privacyPolicy,
            routingHints: ProviderRoutingHints(preferLLM: profile.prefersLLM, preferLocal: profile == .privateLocal)
        )
    }
}

public extension TranslationContextProfile {
    var prefersLLM: Bool {
        switch self {
        case .understand, .nativePolish, .reply, .github, .social, .email:
            return true
        case .quickTranslate, .strictTerminology, .privateLocal, .document:
            return false
        }
    }
}
