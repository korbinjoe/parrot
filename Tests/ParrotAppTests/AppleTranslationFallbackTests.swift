import Foundation
import Testing
import ParrotCore
@testable import ParrotApp

#if compiler(>=6.0)
import Translation

@available(macOS 15.0, *)
@Test func appleShortWordFallbackRecoversOnlyMissingSourceDetection() {
    let error = TranslationError.unableToIdentifyLanguage
    #expect(AppleTranslationSourceFallback.sourceLanguage(text: "tide", from: nil, to: .zh, error: error) == .en)
    #expect(AppleTranslationSourceFallback.sourceLanguage(text: "ship it", from: nil, to: .ja, error: error) == .en)
    #expect(AppleTranslationSourceFallback.sourceLanguage(text: "tide", from: .fr, to: .zh, error: error) == nil)
    #expect(AppleTranslationSourceFallback.sourceLanguage(text: "tide", from: nil, to: .en, error: error) == nil)
    #expect(AppleTranslationSourceFallback.sourceLanguage(text: "tide", from: nil, to: .custom("en-US"), error: error) == nil)
    #expect(AppleTranslationSourceFallback.sourceLanguage(text: "tide", from: nil, to: .auto, error: error) == nil)
}

@available(macOS 15.0, *)
@Test func appleShortWordFallbackRejectsOtherErrorsAndNonAsciiInput() {
    #expect(AppleTranslationSourceFallback.sourceLanguage(
        text: "tide", from: nil, to: .zh, error: TranslationError.unsupportedLanguagePairing
    ) == nil)
    for text in ["", "  ", "12345", "你好", "café", String(repeating: "a", count: 41), "one two three four five"] {
        #expect(AppleTranslationSourceFallback.sourceLanguage(
            text: text, from: nil, to: .zh, error: TranslationError.unableToIdentifyLanguage
        ) == nil)
    }
}
#endif
