import Foundation
import ParrotSocial

public actor JSONSocialSessionStore: SocialSessionStore {
    private var sessions: [SocialTextSession] = []
    private let fileURL: URL
    private let maxSessions: Int

    public init(fileURL: URL, maxSessions: Int = 5000) {
        self.fileURL = fileURL
        self.maxSessions = maxSessions
        self.sessions = Self.load(from: fileURL)
    }

    public func save(_ session: SocialTextSession) async throws {
        var copy = session
        copy.updatedAt = Date()
        sessions.removeAll { $0.id == copy.id }
        sessions.insert(copy, at: 0)
        trim()
        try persist()
    }

    public func recent(limit: Int) async throws -> [SocialTextSession] {
        Array(sessions.prefix(max(0, limit)))
    }

    public func search(_ query: String) async throws -> [SocialTextSession] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return sessions }
        return sessions.filter { session in
            session.sourceDraft.lowercased().contains(q)
                || session.userIntentDraft.lowercased().contains(q)
                || (session.understand?.meaningSummary.lowercased().contains(q) ?? false)
                || (session.express?.candidates.contains { $0.text.lowercased().contains(q) } ?? false)
        }
    }

    public func delete(_ id: UUID) async throws {
        sessions.removeAll { $0.id == id }
        try persist()
    }

    public func setFavorite(_ id: UUID, _ value: Bool) async throws {
        guard let index = sessions.firstIndex(where: { $0.id == id }) else { return }
        sessions[index].isFavorite = value
        sessions[index].updatedAt = Date()
        try persist()
    }

    private static func load(from fileURL: URL) -> [SocialTextSession] {
        guard let data = try? Data(contentsOf: fileURL), !data.isEmpty else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode([SocialTextSession].self, from: data)) ?? []
    }

    private func persist() throws {
        let directory = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(sessions)
        try data.write(to: fileURL, options: .atomic)
    }

    private func trim() {
        guard sessions.count > maxSessions else { return }
        var overflow = sessions.count - maxSessions
        let removable = sessions.indices.filter { !sessions[$0].isFavorite }.sorted(by: >)
        for index in removable where overflow > 0 {
            sessions.remove(at: index)
            overflow -= 1
        }
    }
}
