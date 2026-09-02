import Foundation

/// A phrase-level note that explains language, usage, or cultural context.
/// `phrase` is retained as the storage name so existing social-session payloads
/// can migrate to this shared Core model without losing data.
public struct CulturalNote: Codable, Sendable, Equatable, Identifiable {
    public var id: String { "\(phrase)|\(explanation)" }
    public var phrase: String
    public var explanation: String

    public var expression: String {
        get { phrase }
        set { phrase = newValue }
    }

    public init(phrase: String, explanation: String) {
        self.phrase = phrase
        self.explanation = explanation
    }

    public init(expression: String, explanation: String) {
        self.init(phrase: expression, explanation: explanation)
    }

    private enum CodingKeys: String, CodingKey {
        case phrase
        case expression
        case explanation
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        phrase = try container.decodeIfPresent(String.self, forKey: .expression)
            ?? container.decodeIfPresent(String.self, forKey: .phrase)
            ?? ""
        explanation = try container.decodeIfPresent(String.self, forKey: .explanation) ?? ""
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(phrase, forKey: .expression)
        try container.encode(explanation, forKey: .explanation)
    }
}

/// A plausible alternate reading used when the source does not contain enough
/// evidence for one certain pragmatic interpretation.
public struct InterpretationAlternative: Codable, Sendable, Equatable, Identifiable {
    public var id: String { "\(interpretation)|\(when)" }
    public var interpretation: String
    public var when: String

    public init(interpretation: String, when: String) {
        self.interpretation = interpretation
        self.when = when
    }
}

/// Meaning-first output shared by desktop translation and the social assistant.
/// Compatibility aliases keep existing iOS social call sites and persisted JSON
/// readable while the product converges on one result contract.
public struct InterpretationResult: Codable, Sendable, Equatable {
    public var intendedMeaning: String
    public var localizedTranslation: String
    public var literalTranslation: String?
    public var toneTags: [String]
    public var culturalNotes: [CulturalNote]
    public var ambiguities: [InterpretationAlternative]
    public var confidence: Double
    public var confidenceNote: String?

    public var meaningSummary: String {
        get { intendedMeaning }
        set { intendedMeaning = newValue }
    }

    public var phraseExplanations: [CulturalNote] {
        get { culturalNotes }
        set { culturalNotes = newValue }
    }

    public var fullTranslation: String? {
        get {
            let trimmed = localizedTranslation.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : localizedTranslation
        }
        set { localizedTranslation = newValue ?? "" }
    }

    public init(
        intendedMeaning: String,
        localizedTranslation: String,
        literalTranslation: String? = nil,
        toneTags: [String] = [],
        culturalNotes: [CulturalNote] = [],
        ambiguities: [InterpretationAlternative] = [],
        confidence: Double = 0.5,
        confidenceNote: String? = nil
    ) {
        self.intendedMeaning = intendedMeaning
        self.localizedTranslation = localizedTranslation
        self.literalTranslation = literalTranslation
        self.toneTags = toneTags
        self.culturalNotes = culturalNotes
        self.ambiguities = ambiguities
        self.confidence = Self.normalizedConfidence(confidence)
        self.confidenceNote = confidenceNote
    }

    /// Compatibility initializer for the original social-assistant result model.
    public init(
        meaningSummary: String,
        toneTags: [String] = [],
        phraseExplanations: [CulturalNote] = [],
        fullTranslation: String? = nil,
        confidenceNote: String? = nil
    ) {
        self.init(
            intendedMeaning: meaningSummary,
            localizedTranslation: fullTranslation ?? "",
            toneTags: toneTags,
            culturalNotes: phraseExplanations,
            confidence: confidenceNote == nil ? 0.75 : 0.5,
            confidenceNote: confidenceNote
        )
    }

    private enum CodingKeys: String, CodingKey {
        case intendedMeaning
        case localizedTranslation
        case literalTranslation
        case toneTags
        case culturalNotes
        case ambiguities
        case confidence
        case confidenceNote
        // Legacy social-assistant keys.
        case meaningSummary
        case phraseExplanations
        case fullTranslation
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        intendedMeaning = try container.decodeIfPresent(String.self, forKey: .intendedMeaning)
            ?? container.decodeIfPresent(String.self, forKey: .meaningSummary)
            ?? ""
        localizedTranslation = try container.decodeIfPresent(String.self, forKey: .localizedTranslation)
            ?? container.decodeIfPresent(String.self, forKey: .fullTranslation)
            ?? ""
        literalTranslation = try container.decodeIfPresent(String.self, forKey: .literalTranslation)
        toneTags = try container.decodeIfPresent([String].self, forKey: .toneTags) ?? []
        culturalNotes = try container.decodeIfPresent([CulturalNote].self, forKey: .culturalNotes)
            ?? container.decodeIfPresent([CulturalNote].self, forKey: .phraseExplanations)
            ?? []
        ambiguities = try container.decodeIfPresent([InterpretationAlternative].self, forKey: .ambiguities) ?? []
        let numericConfidence = try? container.decodeIfPresent(Double.self, forKey: .confidence)
        let stringConfidence = try? container.decodeIfPresent(String.self, forKey: .confidence)
            .flatMap(Double.init)
        confidence = Self.normalizedConfidence(numericConfidence ?? stringConfidence ?? 0.5)
        confidenceNote = try container.decodeIfPresent(String.self, forKey: .confidenceNote)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(intendedMeaning, forKey: .intendedMeaning)
        try container.encode(localizedTranslation, forKey: .localizedTranslation)
        try container.encodeIfPresent(literalTranslation, forKey: .literalTranslation)
        try container.encode(toneTags, forKey: .toneTags)
        try container.encode(culturalNotes, forKey: .culturalNotes)
        try container.encode(ambiguities, forKey: .ambiguities)
        try container.encode(confidence, forKey: .confidence)
        try container.encodeIfPresent(confidenceNote, forKey: .confidenceNote)
    }

    func mappingTextFields(_ transform: (String) -> String) -> InterpretationResult {
        InterpretationResult(
            intendedMeaning: transform(intendedMeaning),
            localizedTranslation: transform(localizedTranslation),
            literalTranslation: literalTranslation.map(transform),
            toneTags: toneTags.map(transform),
            culturalNotes: culturalNotes.map {
                CulturalNote(phrase: transform($0.phrase), explanation: transform($0.explanation))
            },
            ambiguities: ambiguities.map {
                InterpretationAlternative(
                    interpretation: transform($0.interpretation),
                    when: transform($0.when)
                )
            },
            confidence: confidence,
            confidenceNote: confidenceNote.map(transform)
        )
    }

    var textFields: [String] {
        [intendedMeaning, localizedTranslation]
            + [literalTranslation, confidenceNote].compactMap { $0 }
            + toneTags
            + culturalNotes.flatMap { [$0.phrase, $0.explanation] }
            + ambiguities.flatMap { [$0.interpretation, $0.when] }
    }

    private static func normalizedConfidence(_ value: Double) -> Double {
        guard value.isFinite else { return 0.5 }
        return min(1, max(0, value))
    }
}

public enum InterpretationParsingError: Error, Equatable, Sendable {
    case invalidJSON
    case missingMeaning
}

public enum InterpretationParser {
    public static func parse(_ raw: String) throws -> InterpretationResult {
        let data = try jsonData(from: raw)
        let result: InterpretationResult
        do {
            result = try JSONDecoder().decode(InterpretationResult.self, from: data)
        } catch {
            throw InterpretationParsingError.invalidJSON
        }

        let meaning = result.intendedMeaning.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !meaning.isEmpty else { throw InterpretationParsingError.missingMeaning }

        if result.localizedTranslation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            var fallback = result
            fallback.localizedTranslation = meaning
            return fallback
        }
        return result
    }

    private static func jsonData(from raw: String) throws -> Data {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if let data = trimmed.data(using: .utf8),
           (try? JSONSerialization.jsonObject(with: data)) != nil {
            return data
        }

        var objectStart: String.Index?
        var depth = 0
        var isInsideString = false
        var isEscaped = false
        for index in trimmed.indices {
            let character = trimmed[index]
            if isInsideString {
                if isEscaped {
                    isEscaped = false
                } else if character == "\\" {
                    isEscaped = true
                } else if character == "\"" {
                    isInsideString = false
                }
                continue
            }
            if character == "\"" {
                isInsideString = true
            } else if character == "{" {
                if depth == 0 { objectStart = index }
                depth += 1
            } else if character == "}", depth > 0 {
                depth -= 1
                guard depth == 0, let objectStart else { continue }
                let candidate = String(trimmed[objectStart...index])
                if let data = candidate.data(using: .utf8),
                   (try? JSONSerialization.jsonObject(with: data)) is [String: Any] {
                    return data
                }
            }
        }
        throw InterpretationParsingError.invalidJSON
    }
}
