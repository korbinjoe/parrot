import Foundation
import ParrotSocial

public protocol SecretStoreProtocol: Sendable {
    func set(_ value: String, account: String) async throws
    func get(account: String) async throws -> String?
    func remove(account: String) async throws
}

public protocol SocialSessionStore: Sendable {
    func save(_ session: SocialTextSession) async throws
    func recent(limit: Int) async throws -> [SocialTextSession]
    func search(_ query: String) async throws -> [SocialTextSession]
    func delete(_ id: UUID) async throws
    func setFavorite(_ id: UUID, _ value: Bool) async throws
}

public enum ShareHandoffKind: String, Codable, Sendable {
    case text
    case url
    case image
    case unsupported
}

public struct ShareHandoff: Identifiable, Codable, Sendable, Equatable {
    public var id: UUID
    public var kind: ShareHandoffKind
    public var text: String?
    public var url: URL?
    public var imageFileName: String?
    public var sourceApplication: String?
    public var platformHint: PlatformPreset
    public var createdAt: Date

    public init(
        id: UUID = UUID(),
        kind: ShareHandoffKind,
        text: String? = nil,
        url: URL? = nil,
        imageFileName: String? = nil,
        sourceApplication: String? = nil,
        platformHint: PlatformPreset = .general,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.kind = kind
        self.text = text
        self.url = url
        self.imageFileName = imageFileName
        self.sourceApplication = sourceApplication
        self.platformHint = platformHint
        self.createdAt = createdAt
    }

    public func makeSession() -> SocialTextSession {
        let source: String
        switch kind {
        case .text:
            source = text ?? ""
        case .url:
            source = [text, url?.absoluteString].compactMap { $0 }.joined(separator: "\n")
        case .image:
            source = text ?? ""
        case .unsupported:
            source = text ?? ""
        }
        return SocialTextSession(
            mode: kind == .image ? .ocr : .understand,
            origin: kind == .image ? .screenshot : .shareExtension,
            platform: platformHint,
            sourceDraft: source,
            sourceImageFileName: imageFileName
        )
    }
}

public protocol SharedHandoffStore: Sendable {
    func write(_ handoff: ShareHandoff) async throws
    func consumeLatest() async throws -> ShareHandoff?
}
