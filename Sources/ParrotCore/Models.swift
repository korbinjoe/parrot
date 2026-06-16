import Foundation

/// Supported languages. `.auto` triggers detection. `.custom` carries an ISO 639-1 code
/// for languages not yet first-classed.
public enum Language: Equatable, Hashable, Sendable {
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
}

/// What kind of operation the user is requesting.
public enum TranslateMode: Sendable {
    case translate
    case lookup   // dictionary lookup for a single word
    case polish   // rewrite/polish text
}

public struct TranslateRequest: Sendable {
    public let text: String
    public let from: Language
    public let to: Language
    public let mode: TranslateMode

    public init(text: String, from: Language = .auto, to: Language, mode: TranslateMode = .translate) {
        self.text = text
        self.from = from
        self.to = to
        self.mode = mode
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

    public init(providerId: String,
                translated: String,
                detectedFrom: Language? = nil,
                phonetics: [Phonetic]? = nil,
                definitions: [Definition]? = nil) {
        self.providerId = providerId
        self.translated = translated
        self.detectedFrom = detectedFrom
        self.phonetics = phonetics
        self.definitions = definitions
    }
}

public struct ProviderCapabilities: Sendable {
    public let supportsLookup: Bool
    public let supportsStream: Bool
    public let supportsPolish: Bool
    public init(supportsLookup: Bool = false, supportsStream: Bool = false, supportsPolish: Bool = false) {
        self.supportsLookup = supportsLookup
        self.supportsStream = supportsStream
        self.supportsPolish = supportsPolish
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
