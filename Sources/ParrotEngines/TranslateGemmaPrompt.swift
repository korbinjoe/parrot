import Foundation
import ParrotCore

/// TranslateGemma requires one user message, with explicit language names and raw text.
/// Format: https://ollama.com/library/translategemma
enum TranslateGemmaPrompt {
    static func matches(model: String?) -> Bool {
        guard let model else { return false }
        let basename = model.trimmingCharacters(in: .whitespacesAndNewlines)
            .split(separator: "/").last?
            .split(separator: ":").first?
            .lowercased()
        return basename == "translategemma"
    }

    static func content(for request: TranslateRequest) throws -> String {
        let from = try sourceLanguage(for: request)
        let source = try description(for: from)
        let target = try description(for: request.to)
        let containsTokens = request.text.range(
            of: placeholderPattern, options: .regularExpression
        ) != nil
        let preserveTokens = containsTokens
            ? " Preserve all PARROTTERM and PARROTMASK placeholder tokens exactly."
            : ""
        // Two blank lines separate instructions from the already privacy-masked and
        // terminology-protected input supplied by the coordinator. Metadata stays out.
        return """
        You are a professional \(source.name) (\(source.code)) to \(target.name) (\(target.code)) translator. Your goal is to accurately convey the meaning and nuances of the original \(source.name) text while adhering to \(target.name) grammar, vocabulary, and cultural sensitivities.
        Produce only the \(target.name) translation, without any additional explanations or commentary.\(preserveTokens) Please translate the following \(source.name) text into \(target.name):


        \(request.text)
        """
    }

    private static let placeholderPattern = #"\bPARROTTERM[0-9]{4}\b|\bPARROTMASK_[A-Z]+_[0-9]{4}\b"#

    static func containsOnlyProtectedTokens(_ text: String) -> Bool {
        guard text.range(of: placeholderPattern, options: .regularExpression) != nil else { return false }
        let remainder = text.replacingOccurrences(of: placeholderPattern, with: "", options: .regularExpression)
        let separators = CharacterSet.whitespacesAndNewlines.union(.punctuationCharacters)
        return remainder.unicodeScalars.allSatisfy { separators.contains($0) }
    }

    private static func sourceLanguage(for request: TranslateRequest) throws -> Language {
        guard request.from == .auto else { return request.from }
        let text = request.text.replacingOccurrences(
            of: placeholderPattern, with: " ", options: .regularExpression
        )
        if let detected = LanguageDetector().detect(text, minConfidence: 0.45) { return detected }
        let letters = text.unicodeScalars.filter { CharacterSet.letters.contains($0) }
        let isShortASCIIWord = !letters.isEmpty && letters.count < 12
            && letters.allSatisfy { (65...90).contains($0.value) || (97...122).contains($0.value) }
            && text.split(whereSeparator: \.isWhitespace).count < 3
        if isShortASCIIWord, request.to != .en { return .en }
        throw ProviderError.unsupportedLanguage
    }

    private static func description(for language: Language) throws -> (name: String, code: String) {
        guard let code = language.code else { throw ProviderError.unsupportedLanguage }
        let name: String
        switch language {
        case .en: name = "English"
        case .zh: name = "Chinese"
        case .ja: name = "Japanese"
        case .ko: name = "Korean"
        case .fr: name = "French"
        case .de: name = "German"
        case .es: name = "Spanish"
        case .ru: name = "Russian"
        case .custom:
            guard let localized = Locale(identifier: "en").localizedString(forIdentifier: code),
                  localized.caseInsensitiveCompare(code) != .orderedSame else {
                throw ProviderError.unsupportedLanguage
            }
            name = localized
        case .auto: throw ProviderError.unsupportedLanguage
        }
        return (name, code)
    }
}
