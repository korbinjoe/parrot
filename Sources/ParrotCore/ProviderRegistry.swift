import Foundation

/// Holds the enabled providers and their display order. Thread-safe via an internal lock.
public final class ProviderRegistry: @unchecked Sendable {
    private var providers: [String: TranslationProvider] = [:]
    private var order: [String] = []
    private var enabled: Set<String> = []
    private let lock = NSLock()

    public init() {}

    public func register(_ provider: TranslationProvider, enabled: Bool = true) {
        lock.lock(); defer { lock.unlock() }
        if providers[provider.id] == nil {
            order.append(provider.id)
        }
        providers[provider.id] = provider
        if enabled { self.enabled.insert(provider.id) } else { self.enabled.remove(provider.id) }
    }

    public func removeAll() {
        lock.lock(); defer { lock.unlock() }
        providers.removeAll()
        order.removeAll()
        enabled.removeAll()
    }

    public func setEnabled(_ id: String, _ value: Bool) {
        lock.lock(); defer { lock.unlock() }
        if value { enabled.insert(id) } else { enabled.remove(id) }
    }

    public func setOrder(_ ids: [String]) {
        lock.lock(); defer { lock.unlock() }
        order = ids.filter { providers[$0] != nil }
    }

    /// Enabled providers in display order.
    public func activeProviders() -> [TranslationProvider] {
        lock.lock(); defer { lock.unlock() }
        return order.compactMap { id in enabled.contains(id) ? providers[id] : nil }
    }

    public func provider(id: String) -> TranslationProvider? {
        lock.lock(); defer { lock.unlock() }
        return providers[id]
    }
}
