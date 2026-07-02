import Foundation

public enum ResultQualityIssue: String, Codable, Sendable, Equatable, Hashable, CaseIterable {
    case emptyOutput
    case wrongLanguage
    case extremeLengthRatio
    case unchangedSource
    case placeholderLeak
    case terminologyMiss
    case softTimeout
    case malformedResponse
}

public struct ResultQualitySummary: Codable, Equatable, Sendable {
    public var score: Double
    public var issues: [ResultQualityIssue]
    public var isRecommended: Bool

    public init(
        score: Double,
        issues: [ResultQualityIssue] = [],
        isRecommended: Bool = false
    ) {
        self.score = score
        self.issues = issues
        self.isRecommended = isRecommended
    }

    public var needsReview: Bool { !issues.isEmpty }
}

public enum ResultQualityEvaluator {
    public static func evaluate(
        result: TranslateResult,
        request: TranslateRequest,
        error: ProviderError? = nil
    ) -> ResultQualitySummary {
        if error == .timeout {
            return ResultQualitySummary(score: 0, issues: [.softTimeout])
        }

        let source = request.text.trimmingCharacters(in: .whitespacesAndNewlines)
        let translated = result.translated.trimmingCharacters(in: .whitespacesAndNewlines)
        var issues: [ResultQualityIssue] = []

        if translated.isEmpty {
            issues.append(.emptyOutput)
        }
        if !source.isEmpty && source.caseInsensitiveCompare(translated) == .orderedSame && request.mode == .translate {
            issues.append(.unchangedSource)
        }
        if hasPlaceholderLeak(translated) {
            issues.append(.placeholderLeak)
        }
        if hasExtremeLengthRatio(source: source, translated: translated, mode: request.mode) {
            issues.append(.extremeLengthRatio)
        }
        if request.mode == .translate && appearsWrongLanguage(translated, target: request.to) {
            issues.append(.wrongLanguage)
        }
        if let terminology = result.terminologyApplication,
           terminology.strategy != .unsupported,
           !terminology.restorationSucceeded {
            issues.append(.terminologyMiss)
        }

        let score = max(0, 1 - (Double(Set(issues).count) * 0.18))
        return ResultQualitySummary(score: score, issues: Array(Set(issues)).sorted { $0.rawValue < $1.rawValue })
    }

    public static func withRecommendation(
        outcomes: [AggregatedOutcome],
        request: TranslateRequest
    ) -> [AggregatedOutcome] {
        var bestIndex: Int?
        var bestScore: Double = -1
        var updated = outcomes.map { outcome in
            if let result = outcome.result {
                let quality = result.qualitySummary ?? evaluate(result: result, request: request, error: outcome.error)
                return outcome.withResult(result.withQualitySummary(quality))
            }
            return outcome
        }

        for (index, outcome) in updated.enumerated() {
            guard let quality = outcome.result?.qualitySummary else { continue }
            let candidateScore = quality.issues.isEmpty ? quality.score + 0.1 : quality.score
            if candidateScore > bestScore {
                bestScore = candidateScore
                bestIndex = index
            }
        }

        guard let bestIndex else { return updated }
        for index in updated.indices {
            guard let result = updated[index].result,
                  var quality = result.qualitySummary else { continue }
            quality.isRecommended = index == bestIndex
            updated[index] = updated[index].withResult(result.withQualitySummary(quality))
        }
        return updated
    }

    private static func hasPlaceholderLeak(_ translated: String) -> Bool {
        translated.localizedCaseInsensitiveContains("PARROTTERM")
            || translated.localizedCaseInsensitiveContains("PARROTMASK")
    }

    private static func hasExtremeLengthRatio(source: String, translated: String, mode: TranslateMode) -> Bool {
        guard mode == .translate, source.count >= 20, translated.count >= 1 else { return false }
        let ratio = Double(translated.count) / Double(source.count)
        return ratio < 0.18 || ratio > 5.5
    }

    private static func appearsWrongLanguage(_ translated: String, target: Language) -> Bool {
        guard translated.count >= 8 else { return false }
        switch target {
        case .zh:
            return translated.unicodeScalars.filter { $0.value >= 0x4E00 && $0.value <= 0x9FFF }.count == 0
        case .en:
            let letters = translated.unicodeScalars.filter { CharacterSet.letters.contains($0) }.count
            let cjk = translated.unicodeScalars.filter { $0.value >= 0x4E00 && $0.value <= 0x9FFF }.count
            return cjk > letters
        default:
            return false
        }
    }
}
