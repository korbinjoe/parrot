import Foundation
import ParrotCore
import ParrotEngines
import ParrotPlugins
import Combine
import Network

@MainActor
final class AppState: ObservableObject {
    let registry = ProviderRegistry()
    let coordinator: TranslationCoordinator
    let ocrCoordinator = OCRCoordinator()
    let ttsCoordinator = TTSCoordinator()

    let history = HistoryStore()
    let settings = AppSettings()

    @Published var sourceText: String = ""
    @Published var outcomes: [AggregatedOutcome] = []
    @Published var isTranslating: Bool = false
    @Published var targetLanguage: Language = .zh
    @Published var detectedSource: Language = .auto
    @Published var savedRecordId: UUID?
    @Published var isFavorite: Bool = false
    @Published var isOffline: Bool = false

    private let netMonitor = NWPathMonitor()

    init() {
        coordinator = TranslationCoordinator(registry: registry)
        targetLanguage = settings.targetLanguage
        Speaker.shared.coordinator = ttsCoordinator
        startNetworkMonitor()
        reloadProviders()
        loadPlugins()
    }

    func reloadProviders() {
        registry.removeAll()
        EngineBootstrap.registerAll(into: registry, settings: settings)
        ocrCoordinator.applySettings(settings)
        ttsCoordinator.applySettings(settings)
    }

    private func startNetworkMonitor() {
        netMonitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in self?.isOffline = path.status != .satisfied }
        }
        netMonitor.start(queue: DispatchQueue(label: "parrot.net.monitor"))
    }

    func applySettings() {
        targetLanguage = settings.targetLanguage
        reloadProviders()
        loadPlugins()
    }

    private func loadPlugins() {
        for plugin in PluginLoader.loadAll() {
            registry.register(plugin, enabled: true)
        }
    }

    func validateEngine(id: String) async -> Bool {
        guard let provider = registry.provider(id: id) else { return false }
        return await EngineValidator.validate(provider)
    }

    func translate(_ text: String, mode: TranslateMode = .translate) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        reloadProviders()
        loadPlugins()
        sourceText = trimmed
        isTranslating = true
        outcomes = []
        savedRecordId = nil
        isFavorite = false
        Task {
            let req = TranslateRequest(text: trimmed, from: .auto, to: targetLanguage, mode: mode)
            let result = await coordinator.translateAll(req)
            for outcome in result {
                if let error = outcome.error {
                    DebugLog.log("translate: provider=\(outcome.providerId) error=\(error) latencyMs=\(outcome.latencyMs)")
                } else if let translated = outcome.result?.translated {
                    DebugLog.log("translate: provider=\(outcome.providerId) ok latencyMs=\(outcome.latencyMs) chars=\(translated.count)")
                }
            }
            self.outcomes = result
            self.isTranslating = false

            if let detected = result.compactMap({ $0.result?.detectedFrom }).first {
                self.detectedSource = detected
            }
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
