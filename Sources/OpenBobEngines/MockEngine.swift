import Foundation
import OpenBobCore

/// Deterministic offline engine for tests and first-run demo. No network.
public struct MockEngine: TranslationProvider {
    public let id = "mock"
    public let displayName = "Mock (Demo)"
    public let supportedLanguages: [Language] = [.auto, .zh, .en, .ja, .ko, .fr, .de, .es, .ru]
    public let capabilities = ProviderCapabilities(supportsLookup: true, supportsStream: true, supportsPolish: false)

    public init() {}

    public func translate(_ req: TranslateRequest) async throws -> TranslateResult {
        let prefix: String
        switch req.to {
        case .zh: prefix = "【译】"
        case .en: prefix = "[EN] "
        default: prefix = "[\(req.to.code ?? "?")] "
        }
        if req.mode == .lookup {
            return TranslateResult(
                providerId: id,
                translated: prefix + req.text,
                detectedFrom: req.from == .auto ? .en : req.from,
                phonetics: [Phonetic(type: "US", value: "/mɒk/")],
                definitions: [Definition(partOfSpeech: "n.", meanings: ["示例释义"], examples: ["This is a mock example."])]
            )
        }
        return TranslateResult(
            providerId: id,
            translated: prefix + req.text,
            detectedFrom: req.from == .auto ? .en : req.from
        )
    }
}
