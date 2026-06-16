import Foundation
import ParrotCore
import ParrotEngines
import ParrotPlugins
import Combine
import Network

struct PendingProviderViewState: Identifiable, Equatable {
    let id: String
    let displayName: String
    let isSlow: Bool
    var softTimedOut: Bool = false
}

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
    @Published var pendingProviders: [PendingProviderViewState] = []
    @Published var slowProviderIDs: Set<String> = []
    @Published var isTranslating: Bool = false
    @Published var sourceLanguage: Language = .auto
    @Published var targetLanguage: Language = .zh
    @Published var detectedSource: Language = .auto
    @Published var savedRecordId: UUID?
    @Published var isFavorite: Bool = false
    @Published var isOffline: Bool = false

    private let netMonitor = NWPathMonitor()
    private var translationTask: Task<Void, Never>?
    private var slowHintTasks: [Task<Void, Never>] = []
    private var currentTranslationID = UUID()
    private var didSaveCurrentTranslation = false
    private var currentMode: TranslateMode = .translate
    private static let slowProviderSoftTimeout: TimeInterval = 8

    init() {
        coordinator = TranslationCoordinator(registry: registry)
        sourceLanguage = settings.sourceLanguage
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
        sourceLanguage = settings.sourceLanguage
        targetLanguage = settings.targetLanguage
        reloadProviders()
        loadPlugins()
    }

    func setLanguageDirection(sourceCode: String? = nil, targetCode: String? = nil) {
        if let sourceCode {
            settings.sourceLanguageCode = sourceCode
        }
        if let targetCode {
            settings.targetLanguageCode = targetCode
        }
        applySettings()
        guard !sourceText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        translate(sourceText, mode: currentMode)
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
        translationTask?.cancel()
        slowHintTasks.forEach { $0.cancel() }
        slowHintTasks = []

        let runID = UUID()
        currentTranslationID = runID
        didSaveCurrentTranslation = false
        currentMode = mode

        reloadProviders()
        loadPlugins()
        sourceText = trimmed
        detectedSource = sourceLanguage
        isTranslating = true
        outcomes = []
        let activeProviders = registry.activeProviders()
        slowProviderIDs = Set(activeProviders.filter(Self.isSlowProvider).map(\.id))
        pendingProviders = activeProviders.map {
            PendingProviderViewState(
                id: $0.id,
                displayName: $0.displayName,
                isSlow: Self.isSlowProvider($0)
            )
        }
        savedRecordId = nil
        isFavorite = false

        scheduleSlowProviderHints(runID: runID)

        let req = TranslateRequest(text: trimmed, from: sourceLanguage, to: targetLanguage, mode: mode)
        let coordinator = coordinator
        translationTask = Task { [weak self, coordinator] in
            let stream = await coordinator.translateIncrementally(req)
            for await outcome in stream {
                guard !Task.isCancelled else { break }
                await self?.handleIncrementalOutcome(outcome, sourceText: trimmed, runID: runID)
            }
            self?.finishTranslation(runID: runID)
        }
    }

    private static func isSlowProvider(_ provider: TranslationProvider) -> Bool {
        provider.id == "opencode" || provider.capabilities.supportsStream
    }

    private func scheduleSlowProviderHints(runID: UUID) {
        for provider in pendingProviders where provider.isSlow {
            let task = Task { [weak self, providerID = provider.id] in
                try? await Task.sleep(nanoseconds: UInt64(Self.slowProviderSoftTimeout * 1_000_000_000))
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    guard let self, self.currentTranslationID == runID else { return }
                    if let index = self.pendingProviders.firstIndex(where: { $0.id == providerID }) {
                        self.pendingProviders[index].softTimedOut = true
                    }
                }
            }
            slowHintTasks.append(task)
        }
    }

    private func handleIncrementalOutcome(
        _ outcome: AggregatedOutcome,
        sourceText trimmed: String,
        runID: UUID
    ) async {
        guard currentTranslationID == runID else { return }
        log(outcome)

        if let index = outcomes.firstIndex(where: { $0.providerId == outcome.providerId }) {
            outcomes[index] = outcome
        } else {
            outcomes.append(outcome)
        }
        pendingProviders.removeAll { $0.id == outcome.providerId }

        if sourceLanguage == .auto, let detected = outcome.result?.detectedFrom {
            detectedSource = detected
        }

        guard let primary = outcome.result, !didSaveCurrentTranslation else { return }
        didSaveCurrentTranslation = true
        let record = TranslationRecord(
            sourceText: trimmed,
            translated: primary.translated,
            providerId: primary.providerId,
            sourceLang: ((sourceLanguage == .auto ? detectedSource : sourceLanguage).code ?? "auto"),
            targetLang: (targetLanguage.code ?? "")
        )
        await history.add(record)
        guard currentTranslationID == runID else { return }
        savedRecordId = record.id
    }

    private func finishTranslation(runID: UUID) {
        guard currentTranslationID == runID else { return }
        isTranslating = false
        pendingProviders = []
        slowHintTasks.forEach { $0.cancel() }
        slowHintTasks = []
    }

    private func log(_ outcome: AggregatedOutcome) {
        if let error = outcome.error {
            DebugLog.log("translate: provider=\(outcome.providerId) error=\(error) latencyMs=\(outcome.latencyMs)")
        } else if let translated = outcome.result?.translated {
            DebugLog.log("translate: provider=\(outcome.providerId) ok latencyMs=\(outcome.latencyMs) chars=\(translated.count)")
        }
    }

    func toggleFavorite() {
        guard let id = savedRecordId else { return }
        isFavorite.toggle()
        let value = isFavorite
        Task { _ = await history.setFavorite(id, value) }
    }

    func speakSource() {
        Speaker.shared.speak(sourceText, language: sourceLanguage == .auto ? detectedSource : sourceLanguage)
    }

    func speakTranslation(_ text: String) {
        Speaker.shared.speak(text, language: targetLanguage)
    }
}
