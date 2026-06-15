import Foundation
import OpenBobCore
import OpenBobEngines
import OpenBobPlugins
import Combine

/// Observable application state shared across the menu bar, input panel and floating result window.
@MainActor
final class AppState: ObservableObject {
    let registry = ProviderRegistry()
    let coordinator: TranslationCoordinator

    let history = HistoryStore()
    let settings = AppSettings()

    @Published var sourceText: String = ""
    @Published var outcomes: [AggregatedOutcome] = []
    @Published var isTranslating: Bool = false
    @Published var targetLanguage: Language = .zh
    @Published var detectedSource: Language = .auto
    @Published var savedRecordId: UUID?
    @Published var isFavorite: Bool = false

    init() {
        coordinator = TranslationCoordinator(registry: registry)

        targetLanguage = settings.targetLanguage

        // Google — free web endpoint, no key, enabled per settings (default on).
        registry.register(GoogleEngine(), enabled: settings.googleEnabled)

        // DeepL — needs an API key (free keys end with ":fx"). Enabled only if toggled on AND keyed.
        registerKeyed(DeepLEngine(), key: settings.deepLKey(), enabled: settings.deepLEnabled)

        // OpenAI — LLM engine, needs a key.
        registerKeyed(OpenAIEngine(), key: settings.openAIKey(), enabled: settings.openAIEnabled)

        // Mock — offline demo, disabled by default once real engines exist.
        registry.register(MockEngine(), enabled: false)

        // Community plugins from ~/Library/Application Support/OpenBob/Plugins.
        loadPlugins()
    }

    /// Re-apply settings to the live registry (called after the user edits preferences).
    func applySettings() {
        targetLanguage = settings.targetLanguage
        registry.setEnabled(GoogleEngine().id, settings.googleEnabled)

        if let key = settings.deepLKey(), !key.isEmpty {
            let engine = DeepLEngine()
            try? engine.configure(ProviderConfig(extra: ["apiKey": key]))
            registry.register(engine, enabled: settings.deepLEnabled)
        } else {
            registry.setEnabled(DeepLEngine().id, false)
        }

        if let key = settings.openAIKey(), !key.isEmpty {
            let engine = OpenAIEngine()
            try? engine.configure(ProviderConfig(extra: ["apiKey": key]))
            registry.register(engine, enabled: settings.openAIEnabled)
        } else {
            registry.setEnabled(OpenAIEngine().id, false)
        }
    }

    /// Discover and register installed JS plugins. Failures are skipped silently.
    private func loadPlugins() {
        for plugin in PluginLoader.loadAll() {
            registry.register(plugin, enabled: true)
        }
    }

    /// Register a key-requiring engine: configure it and enable only if a non-empty key exists
    /// AND the user has it toggled on.
    private func registerKeyed(_ provider: TranslationProvider, key: String?, enabled: Bool) {
        if let key, !key.isEmpty {
            try? provider.configure(ProviderConfig(extra: ["apiKey": key]))
            registry.register(provider, enabled: enabled)
        } else {
            registry.register(provider, enabled: false)
        }
    }

    /// Translate `text` across all active engines, publish outcomes, and record to history.
    func translate(_ text: String, mode: TranslateMode = .translate) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        sourceText = trimmed
        isTranslating = true
        outcomes = []
        savedRecordId = nil
        isFavorite = false
        Task {
            let req = TranslateRequest(text: trimmed, from: .auto, to: targetLanguage, mode: mode)
            let result = await coordinator.translateAll(req)
            self.outcomes = result
            self.isTranslating = false

            // Detected source (from first successful engine) drives TTS for the original text.
            if let detected = result.compactMap({ $0.result?.detectedFrom }).first {
                self.detectedSource = detected
            }
            // Record the primary (first successful) translation to history.
            if let primary = result.first(where: { $0.isSuccess })?.result {
                let record = TranslationRecord(
                    sourceText: trimmed,
                    translated: primary.translated,
                    providerId: primary.providerId,
                    sourceLang: (self.detectedSource.code ?? "auto"),
                    targetLang: (self.targetLanguage.code ?? "")
                )
                await self.history.add(record)
                self.savedRecordId = record.id
            }
        }
    }

    /// Toggle favorite on the most recently saved record.
    func toggleFavorite() {
        guard let id = savedRecordId else { return }
        isFavorite.toggle()
        let value = isFavorite
        Task { _ = await history.setFavorite(id, value) }
    }

    func speakSource() {
        Speaker.shared.speak(sourceText, language: detectedSource)
    }

    func speakTranslation(_ text: String) {
        Speaker.shared.speak(text, language: targetLanguage)
    }
}
