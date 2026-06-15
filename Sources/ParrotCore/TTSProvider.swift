import Foundation
import ParrotCore

public protocol TTSProvider: Sendable {
    var id: String { get }
    var displayName: String { get }
    var isOfflineCapable: Bool { get }
    func speak(_ text: String, language: Language) async throws
    func stop() async
}

@MainActor
public final class TTSCoordinator {
    private var providers: [String: TTSProvider] = [:]
    public var defaultProviderId: String = "system"

    public init() {}

    public func register(_ provider: TTSProvider) {
        providers[provider.id] = provider
    }

    public func provider(id: String) -> TTSProvider? { providers[id] }

    public func activeProvider() -> TTSProvider? {
        if let p = providers[defaultProviderId] { return p }
        return providers["system"]
    }

    public func speak(_ text: String, language: Language) async {
        guard !text.isEmpty else { return }
        await activeProvider()?.stop()
        try? await activeProvider()?.speak(text, language: language)
    }

    public func stop() async {
        await activeProvider()?.stop()
    }
}
