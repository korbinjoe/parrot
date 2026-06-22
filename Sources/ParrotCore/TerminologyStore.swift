import Foundation

public final class TerminologyStore: @unchecked Sendable {
    private let fileURL: URL
    private let lock = NSLock()
    private var state: TerminologyStoreState

    public init(fileURL: URL? = nil) {
        if let fileURL {
            self.fileURL = fileURL
        } else {
            let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            let dir = base.appendingPathComponent("Parrot", isDirectory: true)
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            self.fileURL = dir.appendingPathComponent("terminology.json")
        }
        self.state = Self.load(from: self.fileURL) ?? TerminologyStoreState()
    }

    public func loadState() -> TerminologyStoreState {
        lock.lock()
        defer { lock.unlock() }
        return state
    }

    public func saveState(_ next: TerminologyStoreState) {
        lock.lock()
        state = next
        Self.persist(next, to: fileURL)
        lock.unlock()
    }

    public func snapshot() -> TerminologySnapshot? {
        let current = loadState()
        guard current.isEnabled else { return nil }
        let snapshot = TerminologySnapshot(entries: current.entries, strictMode: current.strictMode)
        return snapshot.isEmpty ? nil : snapshot
    }

    public func upsert(_ entry: TerminologyEntry) throws {
        let current = loadState()
        try Self.validate(entry, against: current.entries)
        var entries = current.entries
        if let idx = entries.firstIndex(where: { $0.id == entry.id }) {
            entries[idx] = entry
        } else {
            entries.append(entry)
        }
        saveState(TerminologyStoreState(
            isEnabled: current.isEnabled,
            strictMode: current.strictMode,
            entries: entries
        ))
    }

    public func delete(_ id: UUID) {
        var current = loadState()
        current.entries.removeAll { $0.id == id }
        saveState(current)
    }

    public static func validate(
        _ entry: TerminologyEntry,
        against entries: [TerminologyEntry]
    ) throws {
        guard entry.isValid else { throw TerminologyStoreError.emptySourceOrTarget }
        let source = entry.trimmedSource.lowercased()
        let to = entry.to.code ?? "auto"
        let from = entry.from.code ?? "auto"
        let duplicate = entries.contains { existing in
            existing.id != entry.id
                && existing.enabled
                && existing.trimmedSource.lowercased() == source
                && (existing.from.code ?? "auto") == from
                && (existing.to.code ?? "auto") == to
        }
        if duplicate { throw TerminologyStoreError.duplicate }
    }

    public static func hasOverlap(
        _ entry: TerminologyEntry,
        in entries: [TerminologyEntry]
    ) -> Bool {
        let source = entry.trimmedSource.lowercased()
        guard !source.isEmpty else { return false }
        return entries.contains { existing in
            guard existing.id != entry.id, existing.enabled else { return false }
            let other = existing.trimmedSource.lowercased()
            guard !other.isEmpty, other != source else { return false }
            return source.contains(other) || other.contains(source)
        }
    }

    private static func load(from url: URL) -> TerminologyStoreState? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(TerminologyStoreState.self, from: data)
    }

    private static func persist(_ state: TerminologyStoreState, to url: URL) {
        try? FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(state) else { return }
        try? data.write(to: url, options: .atomic)
    }
}

public enum TerminologyStoreError: Error, Equatable, Sendable {
    case emptySourceOrTarget
    case duplicate
}
