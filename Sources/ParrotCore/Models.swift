import Foundation

/// Supported languages. `.auto` triggers detection. `.custom` carries an ISO 639-1 code
/// for languages not yet first-classed.
public enum Language: Equatable, Hashable, Sendable, Codable {
    case auto
    case zh
    case en
    case ja
    case ko
    case fr
    case de
    case es
    case ru
    case custom(String)

    /// ISO 639-1 code. `.auto` has no code.
    public var code: String? {
        switch self {
        case .auto: return nil
        case .zh: return "zh"
        case .en: return "en"
        case .ja: return "ja"
        case .ko: return "ko"
        case .fr: return "fr"
        case .de: return "de"
        case .es: return "es"
        case .ru: return "ru"
        case .custom(let c): return c
        }
    }

    public init(code: String) {
        switch code.lowercased() {
        case "zh", "zh-hans", "zh-hant": self = .zh
        case "en": self = .en
        case "ja": self = .ja
        case "ko": self = .ko
        case "fr": self = .fr
        case "de": self = .de
        case "es": self = .es
        case "ru": self = .ru
        default: self = .custom(code)
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let code = try container.decode(String.self)
        self = code == "auto" ? .auto : Language(code: code)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(code ?? "auto")
    }
}

/// What kind of operation the user is requesting.
public enum TranslateMode: Sendable, Equatable {
    case translate
    case lookup   // dictionary lookup for a single word
    case polish   // rewrite/polish text
}

public struct TranslateRequest: Sendable {
    public let text: String
    public let from: Language
    public let to: Language
    public let mode: TranslateMode
    public let terminology: TerminologySnapshot?
    public let context: TranslationContext?

    public init(
        text: String,
        from: Language = .auto,
        to: Language,
        mode: TranslateMode = .translate,
        terminology: TerminologySnapshot? = nil,
        context: TranslationContext? = nil
    ) {
        self.text = text
        self.from = from
        self.to = to
        self.mode = mode
        self.terminology = terminology
        self.context = context
    }

    public func withText(_ text: String) -> TranslateRequest {
        TranslateRequest(
            text: text,
            from: from,
            to: to,
            mode: mode,
            terminology: terminology,
            context: context
        )
    }

    public func withContext(_ context: TranslationContext?) -> TranslateRequest {
        TranslateRequest(
            text: text,
            from: from,
            to: to,
            mode: mode,
            terminology: terminology,
            context: context
        )
    }
}

public struct Phonetic: Sendable, Equatable {
    public let type: String   // e.g. "US", "UK"
    public let value: String
    public init(type: String, value: String) {
        self.type = type
        self.value = value
    }
}

public struct Definition: Sendable, Equatable {
    public let partOfSpeech: String
    public let meanings: [String]
    public let examples: [String]
    public init(partOfSpeech: String, meanings: [String], examples: [String] = []) {
        self.partOfSpeech = partOfSpeech
        self.meanings = meanings
        self.examples = examples
    }
}

public struct TranslateResult: Sendable {
    public let providerId: String
    public let translated: String
    public let detectedFrom: Language?
    public let phonetics: [Phonetic]?
    public let definitions: [Definition]?
    public let terminologyApplication: TerminologyApplication?
    public let privacyMaskingReport: PrivacyMaskingReport?
    public let qualitySummary: ResultQualitySummary?
    public let interpretation: InterpretationResult?

    public init(providerId: String,
                translated: String,
                detectedFrom: Language? = nil,
                phonetics: [Phonetic]? = nil,
                definitions: [Definition]? = nil,
                terminologyApplication: TerminologyApplication? = nil,
                privacyMaskingReport: PrivacyMaskingReport? = nil,
                qualitySummary: ResultQualitySummary? = nil,
                interpretation: InterpretationResult? = nil) {
        self.providerId = providerId
        self.translated = translated
        self.detectedFrom = detectedFrom
        self.phonetics = phonetics
        self.definitions = definitions
        self.terminologyApplication = terminologyApplication
        self.privacyMaskingReport = privacyMaskingReport
        self.qualitySummary = qualitySummary
        self.interpretation = interpretation
    }

    public func withTranslated(
        _ translated: String,
        terminologyApplication: TerminologyApplication? = nil,
        privacyMaskingReport: PrivacyMaskingReport? = nil,
        qualitySummary: ResultQualitySummary? = nil,
        interpretation: InterpretationResult? = nil
    ) -> TranslateResult {
        var updatedInterpretation = interpretation ?? self.interpretation
        if var existing = updatedInterpretation,
           existing.localizedTranslation == self.translated {
            existing.localizedTranslation = translated
            updatedInterpretation = existing
        }
        return TranslateResult(
            providerId: providerId,
            translated: translated,
            detectedFrom: detectedFrom,
            phonetics: phonetics,
            definitions: definitions,
            terminologyApplication: terminologyApplication ?? self.terminologyApplication,
            privacyMaskingReport: privacyMaskingReport ?? self.privacyMaskingReport,
            qualitySummary: qualitySummary ?? self.qualitySummary,
            interpretation: updatedInterpretation
        )
    }

    public func withPrivacyMaskingReport(_ report: PrivacyMaskingReport?) -> TranslateResult {
        withTranslated(translated, privacyMaskingReport: report)
    }

    public func withQualitySummary(_ summary: ResultQualitySummary?) -> TranslateResult {
        withTranslated(translated, qualitySummary: summary)
    }

    public func withInterpretation(_ interpretation: InterpretationResult?) -> TranslateResult {
        withTranslated(
            interpretation?.localizedTranslation ?? translated,
            interpretation: interpretation
        )
    }
}

public enum TerminologySupport: String, Codable, Sendable, Equatable {
    case unsupported
    case placeholder
    case prompt
    case promptAndPlaceholder
    case nativeGlossary
}

public struct ProviderCapabilities: Sendable {
    public let supportsLookup: Bool
    public let supportsStream: Bool
    public let supportsPolish: Bool
    public let supportsInterpretation: Bool
    public let terminology: TerminologySupport
    public init(
        supportsLookup: Bool = false,
        supportsStream: Bool = false,
        supportsPolish: Bool = true,
        supportsInterpretation: Bool = false,
        terminology: TerminologySupport = .placeholder
    ) {
        self.supportsLookup = supportsLookup
        self.supportsStream = supportsStream
        self.supportsPolish = supportsPolish
        self.supportsInterpretation = supportsInterpretation
        self.terminology = terminology
    }
}

/// Provider configuration. Credentials are referenced by a Keychain key, never stored in plaintext here.
public struct ProviderConfig: Sendable {
    public let credentialRef: String?
    public let extra: [String: String]
    public init(credentialRef: String? = nil, extra: [String: String] = [:]) {
        self.credentialRef = credentialRef
        self.extra = extra
    }
}

/// Unified error model for all providers (built-in & plugins).
public enum ProviderError: Error, Equatable, Sendable {
    case auth
    case rateLimited
    case network
    case unsupportedLanguage
    case timeout
    case service(String)
    case plugin(String)
    case notConfigured
}
