import Foundation
import OpenBobCore

/// User-facing preferences, persisted to UserDefaults (non-secret) and Keychain (API keys).
///
/// Secrets (API keys) are NEVER stored in UserDefaults — only their presence is reflected in the
/// UI. `AppState` reads these values at launch to configure engines.
@MainActor
final class AppSettings: ObservableObject {
    private let defaults: UserDefaults

    // Keychain account identifiers for keyed engines.
    static let deepLAccount = "engine.deepl.apiKey"
    static let openAIAccount = "engine.openai.apiKey"

    @Published var targetLanguageCode: String {
        didSet { defaults.set(targetLanguageCode, forKey: "targetLanguageCode") }
    }

    @Published var googleEnabled: Bool {
        didSet { defaults.set(googleEnabled, forKey: "engine.google.enabled") }
    }
    @Published var deepLEnabled: Bool {
        didSet { defaults.set(deepLEnabled, forKey: "engine.deepl.enabled") }
    }
    @Published var openAIEnabled: Bool {
        didSet { defaults.set(openAIEnabled, forKey: "engine.openai.enabled") }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.targetLanguageCode = defaults.string(forKey: "targetLanguageCode") ?? "zh"
        // Google is on by default (no key required); keyed engines default on so a saved key activates them.
        self.googleEnabled = defaults.object(forKey: "engine.google.enabled") as? Bool ?? true
        self.deepLEnabled = defaults.object(forKey: "engine.deepl.enabled") as? Bool ?? true
        self.openAIEnabled = defaults.object(forKey: "engine.openai.enabled") as? Bool ?? true
    }

    var targetLanguage: Language { Language(code: targetLanguageCode) }

    // MARK: - API keys (Keychain-backed)

    /// Resolve a key from Keychain, falling back to an environment variable for headless/dev use.
    func deepLKey() -> String? {
        KeychainStore.get(account: Self.deepLAccount) ?? envNonEmpty("DEEPL_API_KEY")
    }

    func openAIKey() -> String? {
        KeychainStore.get(account: Self.openAIAccount) ?? envNonEmpty("OPENAI_API_KEY")
    }

    func setDeepLKey(_ value: String) { KeychainStore.set(value, account: Self.deepLAccount) }
    func setOpenAIKey(_ value: String) { KeychainStore.set(value, account: Self.openAIAccount) }

    var hasDeepLKey: Bool { deepLKey()?.isEmpty == false }
    var hasOpenAIKey: Bool { openAIKey()?.isEmpty == false }

    private func envNonEmpty(_ name: String) -> String? {
        let v = ProcessInfo.processInfo.environment[name]
        return (v?.isEmpty == false) ? v : nil
    }
}
