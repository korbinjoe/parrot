import Foundation
import NaturalLanguage

/// Wraps `NLLanguageRecognizer` for offline source-language detection.
public struct LanguageDetector: Sendable {
    public init() {}

    /// Returns the most likely language, or `nil` if confidence is below `minConfidence`.
    public func detect(_ text: String, minConfidence: Double = 0.5) -> Language? {
        let letters = text.unicodeScalars.filter { CharacterSet.letters.contains($0) }
        guard !letters.isEmpty else { return nil }
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)
        let hypotheses = recognizer.languageHypotheses(withMaximum: 1)
        guard let (lang, confidence) = hypotheses.first, confidence >= minConfidence else {
            return nil
        }
        // Short shared words can get a weak Scandinavian-language guess ("tide" is
        // reported as Norwegian at about 0.47). Keep automatic detection for these,
        // while retaining English and strong signals such as French "bonjour".
        if Self.isShortLatinInput(text), lang != .english, confidence < 0.8 { return nil }
        return Language(code: lang.rawValue)
    }

    fileprivate static func isShortLatinInput(_ text: String) -> Bool {
        let letters = text.unicodeScalars.filter { CharacterSet.letters.contains($0) }
        return !letters.isEmpty && letters.count < 12
            && letters.allSatisfy { (65...90).contains($0.value) || (97...122).contains($0.value) }
            && text.split(whereSeparator: \.isWhitespace).count < 3
    }
}

public struct ResolvedTranslationDirection: Sendable, Equatable {
    public let from: Language
    public let to: Language
    public let detected: Language
    public let targetWasAdjusted: Bool
}

/// Resolves the request direction before dispatching to providers.
/// Automatic input can translate away from the default target language. Explicit
/// source directions and workspace target selections remain authoritative.
public struct TranslationDirectionResolver: Sendable {
    private let detector: LanguageDetector
    private let minConfidence: Double

    public init(detector: LanguageDetector = LanguageDetector(), minConfidence: Double = 0.45) {
        self.detector = detector
        self.minConfidence = minConfidence
    }

    public func resolve(
        text: String,
        from configuredFrom: Language,
        to configuredTo: Language,
        allowTargetAdjustment: Bool = true
    ) -> ResolvedTranslationDirection {
        let detected = detector.detect(text, minConfidence: minConfidence)
        let resolvedFrom = configuredFrom == .auto ? (detected ?? .auto) : configuredFrom
        let visibleDetected = detected ?? resolvedFrom

        guard configuredFrom == .auto, allowTargetAdjustment,
              let detected, detected == configuredTo else {
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
        // An ambiguous single Latin word still needs a concrete polish language.
        // English is the quick-writing default; an explicit source language wins.
        let fallback: Language = LanguageDetector.isShortLatinInput(text) ? .en : .auto
        let resolvedFrom = configuredFrom == .auto ? (detected ?? fallback) : configuredFrom
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
