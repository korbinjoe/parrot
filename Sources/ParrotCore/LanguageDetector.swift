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

public struct ResolvedTranslationDirection: Sendable, Equatable {
    public let from: Language
    public let to: Language
    public let detected: Language
    public let targetWasAdjusted: Bool
}

/// Resolves the request direction before dispatching to providers.
/// If the input is already in the target language, translate away from it instead of
/// returning a same-language result.
public struct TranslationDirectionResolver: Sendable {
    private let detector: LanguageDetector
    private let minConfidence: Double

    public init(detector: LanguageDetector = LanguageDetector(), minConfidence: Double = 0.45) {
        self.detector = detector
        self.minConfidence = minConfidence
    }

    public func resolve(text: String, from configuredFrom: Language, to configuredTo: Language) -> ResolvedTranslationDirection {
        let detected = detector.detect(text, minConfidence: minConfidence)
        let resolvedFrom = configuredFrom == .auto ? (detected ?? .auto) : configuredFrom
        let visibleDetected = detected ?? resolvedFrom

        guard let detected, detected == configuredTo else {
            return ResolvedTranslationDirection(
                from: resolvedFrom,
                to: configuredTo,
                detected: visibleDetected,
                targetWasAdjusted: false
            )
        }

        return ResolvedTranslationDirection(
            from: detected,
            to: Self.fallbackTarget(for: configuredTo),
            detected: detected,
            targetWasAdjusted: true
        )
    }

    public func resolvePolish(text: String, from configuredFrom: Language) -> ResolvedTranslationDirection {
        let detected = detector.detect(text, minConfidence: minConfidence)
        let resolvedFrom = configuredFrom == .auto ? (detected ?? .auto) : configuredFrom
        let polishLanguage = resolvedFrom == .auto ? (detected ?? .auto) : resolvedFrom
        return ResolvedTranslationDirection(
            from: resolvedFrom,
            to: polishLanguage,
            detected: detected ?? resolvedFrom,
            targetWasAdjusted: false
        )
    }

    private static func fallbackTarget(for target: Language) -> Language {
        target == .en ? .zh : .en
    }
}
