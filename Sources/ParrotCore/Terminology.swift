import Foundation

public struct TerminologyEntry: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public var source: String
    public var target: String
    public var from: Language
    public var to: Language
    public var note: String?
    public var caseSensitive: Bool
    public var enabled: Bool

    public init(
        id: UUID = UUID(),
        source: String,
        target: String,
        from: Language = .auto,
        to: Language,
        note: String? = nil,
        caseSensitive: Bool = false,
        enabled: Bool = true
    ) {
        self.id = id
        self.source = source
        self.target = target
        self.from = from
        self.to = to
        self.note = note
        self.caseSensitive = caseSensitive
        self.enabled = enabled
    }

    public var trimmedSource: String {
        source.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public var trimmedTarget: String {
        target.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public var isValid: Bool {
        !trimmedSource.isEmpty && !trimmedTarget.isEmpty
    }
}

public struct TerminologySnapshot: Codable, Equatable, Sendable {
    public let entries: [TerminologyEntry]
    public let strictMode: Bool
    public let createdAt: Date

    public init(entries: [TerminologyEntry], strictMode: Bool = false, createdAt: Date = Date()) {
        self.entries = entries.filter { $0.enabled && $0.isValid }
        self.strictMode = strictMode
        self.createdAt = createdAt
    }

    public var isEmpty: Bool { entries.isEmpty }
}

public struct TerminologyMatch: Codable, Equatable, Sendable, Identifiable {
    public var id: UUID { entryId }
    public let entryId: UUID
    public let source: String
    public let target: String
    public let range: Range<String.Index>?

    public init(entry: TerminologyEntry, range: Range<String.Index>? = nil) {
        self.entryId = entry.id
        self.source = entry.trimmedSource
        self.target = entry.trimmedTarget
        self.range = range
    }

    private enum CodingKeys: String, CodingKey {
        case entryId, source, target
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        entryId = try container.decode(UUID.self, forKey: .entryId)
        source = try container.decode(String.self, forKey: .source)
        target = try container.decode(String.self, forKey: .target)
        range = nil
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(entryId, forKey: .entryId)
        try container.encode(source, forKey: .source)
        try container.encode(target, forKey: .target)
    }
}

public enum TerminologyApplicationStrategy: String, Codable, Sendable, Equatable {
    case nativeGlossary
    case placeholder
    case prompt
    case promptAndPlaceholder
    case unsupported
}

public struct TerminologyApplication: Codable, Equatable, Sendable {
    public let strategy: TerminologyApplicationStrategy
    public let matches: [TerminologyMatch]
    public let restorationSucceeded: Bool

    public init(
        strategy: TerminologyApplicationStrategy,
        matches: [TerminologyMatch],
        restorationSucceeded: Bool = true
    ) {
        self.strategy = strategy
        self.matches = matches
        self.restorationSucceeded = restorationSucceeded
    }

    public var matchCount: Int { matches.count }
}

public struct TerminologyStoreState: Codable, Equatable, Sendable {
    public var isEnabled: Bool
    public var strictMode: Bool
    public var entries: [TerminologyEntry]

    public init(
        isEnabled: Bool = true,
        strictMode: Bool = false,
        entries: [TerminologyEntry] = []
    ) {
        self.isEnabled = isEnabled
        self.strictMode = strictMode
        self.entries = entries
    }
}

public enum TerminologyValidationIssue: Equatable, Sendable {
    case emptySourceOrTarget
    case duplicate
    case overlapping
}
