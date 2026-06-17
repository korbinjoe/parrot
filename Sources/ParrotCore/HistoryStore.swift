import Foundation

/// One provider result persisted inside a translation history record.
public struct TranslationRecordOutcome: Codable, Sendable, Identifiable, Equatable {
    public var id: String { providerId }
    public var providerId: String
    public var displayName: String
    public var translated: String
    public var latencyMs: Int?

    public init(providerId: String, displayName: String, translated: String, latencyMs: Int? = nil) {
        self.providerId = providerId
        self.displayName = displayName
        self.translated = translated
        self.latencyMs = latencyMs
    }
}

/// A persisted translation record (one source text + all successful provider results).
public struct TranslationRecord: Codable, Sendable, Identifiable, Equatable {
    public let id: UUID
    public var sourceText: String
    public var translated: String
    public var providerId: String
    public var outcomes: [TranslationRecordOutcome]
    public var sourceLang: String
    public var targetLang: String
    public var createdAt: Date
    public var isFavorite: Bool

    public init(id: UUID = UUID(),
                sourceText: String,
                translated: String,
                providerId: String,
                outcomes: [TranslationRecordOutcome] = [],
                sourceLang: String,
                targetLang: String,
                createdAt: Date = Date(),
                isFavorite: Bool = false) {
        self.id = id
        self.sourceText = sourceText
        self.translated = translated
        self.providerId = providerId
        if outcomes.isEmpty {
            self.outcomes = [TranslationRecordOutcome(providerId: providerId, displayName: providerId, translated: translated)]
        } else {
            self.outcomes = outcomes
        }
        self.sourceLang = sourceLang
        self.targetLang = targetLang
        self.createdAt = createdAt
        self.isFavorite = isFavorite
    }

    public var displayOutcomes: [TranslationRecordOutcome] {
        outcomes.isEmpty
            ? [TranslationRecordOutcome(providerId: providerId, displayName: providerId, translated: translated)]
            : outcomes
    }

    private enum CodingKeys: String, CodingKey {
        case id, sourceText, translated, providerId, outcomes, sourceLang, targetLang, createdAt, isFavorite
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        sourceText = try container.decode(String.self, forKey: .sourceText)
        translated = try container.decode(String.self, forKey: .translated)
        providerId = try container.decode(String.self, forKey: .providerId)
        outcomes = try container.decodeIfPresent([TranslationRecordOutcome].self, forKey: .outcomes) ?? [
            TranslationRecordOutcome(providerId: providerId, displayName: providerId, translated: translated)
        ]
        sourceLang = try container.decode(String.self, forKey: .sourceLang)
        targetLang = try container.decode(String.self, forKey: .targetLang)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        isFavorite = try container.decode(Bool.self, forKey: .isFavorite)
    }
}

/// Thread-safe history & favorites store with JSON-file persistence.
///
/// JSON keeps the store dependency-free and trivially portable; the on-disk format is an
/// implementation detail and can be swapped for SQLite/GRDB later without changing callers.
public actor HistoryStore {
    private var records: [TranslationRecord] = []
    private let fileURL: URL
    private let maxRecords: Int

    public init(fileURL: URL? = nil, maxRecords: Int = 5000) {
        if let fileURL {
            self.fileURL = fileURL
        } else {
            let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            let dir = base.appendingPathComponent("Parrot", isDirectory: true)
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            self.fileURL = dir.appendingPathComponent("history.json")
        }
        self.maxRecords = maxRecords
        load()
    }

    private func load() {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? decoder.decode([TranslationRecord].self, from: data) else {
            return
        }
        records = decoded
    }

    private func persist() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(records) {
            try? data.write(to: fileURL, options: .atomic)
        }
    }

    /// Insert a record at the front, trimming to `maxRecords`. Returns the stored record.
    @discardableResult
    public func add(_ record: TranslationRecord) -> TranslationRecord {
        records.insert(record, at: 0)
        trim()
        persist()
        return record
    }

    /// Enforce the cap by removing the oldest *non-favorite* records first.
    /// Favorites are preserved even if the total exceeds `maxRecords`.
    private func trim() {
        guard records.count > maxRecords else { return }
        var toRemove = records.count - maxRecords
        // Index 0 is newest, so the highest indices are the oldest. Remove from oldest down.
        let removableOldestFirst = records.indices
            .filter { !records[$0].isFavorite }
            .sorted(by: >)
        for idx in removableOldestFirst where toRemove > 0 {
            records.remove(at: idx)
            toRemove -= 1
        }
    }

    public func all() -> [TranslationRecord] { records }

    public func favorites() -> [TranslationRecord] { records.filter { $0.isFavorite } }

    /// Case-insensitive substring search over source and translated text.
    public func search(_ query: String) -> [TranslationRecord] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return records }
        return records.filter {
            $0.sourceText.lowercased().contains(q) || $0.translated.lowercased().contains(q)
        }
    }

    @discardableResult
    public func setFavorite(_ id: UUID, _ value: Bool) -> Bool {
        guard let idx = records.firstIndex(where: { $0.id == id }) else { return false }
        records[idx].isFavorite = value
        persist()
        return true
    }

    public func delete(_ id: UUID) {
        records.removeAll { $0.id == id }
        persist()
    }

    public func clear() {
        records.removeAll()
        persist()
    }
}
