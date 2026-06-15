import Foundation
import NaturalLanguage

/// Wraps `NLLanguageRecognizer` for offline source-language detection.
public struct LanguageDetector: Sendable {
    public init() {}

    /// Returns the most likely language, or `nil` if confidence is below `minConfidence`.
    public func detect(_ text: String, minConfidence: Double = 0.5) -> Language? {
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)
        let hypotheses = recognizer.languageHypotheses(withMaximum: 1)
        guard let (lang, confidence) = hypotheses.first, confidence >= minConfidence else {
            return nil
        }
        return Language(code: lang.rawValue)
    }
}
