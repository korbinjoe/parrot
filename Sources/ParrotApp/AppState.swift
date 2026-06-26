import Foundation
import ParrotCore
import ParrotEngines
import ParrotPlugins
import Combine
import Network

struct PendingProviderViewState: Identifiable, Equatable {
    let id: String
    let displayName: String
    let modelName: String?
    let isSlow: Bool
    var softTimedOut: Bool = false
}

struct WorkspaceNotice: Equatable {
    enum Tone: Equatable {
        case info
        case warning
        case error
    }

    enum Prominence: Equatable {
        case compact
        case card
    }

    enum Action: Equatable {
        case retryScreenshot
        case openScreenRecordingSettings
        case openOCRSettings
        case dismiss
    }

    struct ButtonSpec: Equatable {
        let title: String
        let action: Action
    }

    let tone: Tone
    let systemImage: String
    let title: String
    let detail: String
    let prominence: Prominence
    let primaryAction: ButtonSpec?
    let secondaryAction: ButtonSpec?
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
    @Published var sourceDraft: String = ""
    @Published var outcomes: [AggregatedOutcome] = []
    @Published var pendingProviders: [PendingProviderViewState] = []
    @Published var slowProviderIDs: Set<String> = []
    @Published var isTranslating: Bool = false
    @Published var isComposerFocused: Bool = false
    @Published var composerFocusRequest: Int = 0
    @Published var isRecognizingOCR: Bool = false
    @Published var workspaceNotice: WorkspaceNotice?
    @Published var sourceLanguage: Language = .auto
    @Published var targetLanguage: Language = .zh
    @Published var detectedSource: Language = .auto
    @Published var savedRecordId: UUID?
    @Published var isFavorite: Bool = false
    @Published var isOffline: Bool = false
    @Published var permissions: PermissionSnapshot = AppPermissions.snapshot()
    @Published var learningHistoryRecords: [TranslationRecord] = []
    @Published var learningOccurrenceCounts: [String: Int] = [:]
    @Published private(set) var manualLearningSelectionRevision: Int = 0
    @Published private(set) var providerDisplayOrder: [String] = []
    @Published private(set) var missingConfigurationOutcomes: [AggregatedOutcome] = []

    private let netMonitor = NWPathMonitor()
    private var translationTask: Task<Void, Never>?
    private var slowHintTasks: [Task<Void, Never>] = []
    private var currentTranslationID = UUID()
    private var didSaveCurrentTranslation = false
    private var currentMode: TranslateMode = .translate
    private let directionResolver = TranslationDirectionResolver()
    private var learningHistoryRefreshGeneration = 0
    private static let slowProviderSoftTimeout: TimeInterval = 8

    var sourceDraftTrimmed: String {
        sourceDraft.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var committedSourceTrimmed: String {
        sourceText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var isSourceDirty: Bool {
        sourceDraftTrimmed != committedSourceTrimmed
    }

    var canTranslateDraft: Bool {
        !sourceDraftTrimmed.isEmpty
    }

    var actionSourceText: String {
        sourceDraftTrimmed.isEmpty ? committedSourceTrimmed : sourceDraft
    }

    var shouldKeepWorkspaceVisible: Bool {
        isComposerFocused
            || isSourceDirty
            || isRecognizingOCR
            || isTranslating
            || canTranslateDraft
            || hasRestorableWorkspace
    }

    var hasRestorableWorkspace: Bool {
        !committedSourceTrimmed.isEmpty
            || !outcomes.isEmpty
            || !pendingProviders.isEmpty
            || workspaceNotice != nil
    }

    init() {
        coordinator = TranslationCoordinator(registry: registry)
        sourceLanguage = settings.sourceLanguage
        targetLanguage = settings.targetLanguage
        Speaker.shared.coordinator = ttsCoordinator
        startNetworkMonitor()
        reloadProviders()
        loadPlugins()
        refreshLearningHistory()
    }

    func reloadProviders() {
        registry.removeAll()
        EngineBootstrap.registerAll(into: registry, settings: settings)
        ocrCoordinator.applySettings(settings)
        ttsCoordinator.applySettings(settings)
        refreshProviderCaches()
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

    func refreshPermissions(promptAccessibility: Bool = false, promptScreenRecording: Bool = false) {
        permissions = AppPermissions.snapshot(
            promptAccessibility: promptAccessibility,
            promptScreenRecording: promptScreenRecording
        )
    }

    func setLanguageDirection(sourceCode: String? = nil, targetCode: String? = nil) {
        if let sourceCode {
            settings.sourceLanguageCode = sourceCode
        }
        if let targetCode {
            settings.targetLanguageCode = targetCode
        }
        applySettings()
        let text = sourceDraftTrimmed.isEmpty ? committedSourceTrimmed : sourceDraft
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        translate(text, mode: currentMode)
    }

    private func loadPlugins() {
        for plugin in PluginLoader.loadAll() {
            registry.register(plugin, enabled: true)
        }
        refreshProviderCaches()
    }

    private func refreshProviderCaches() {
        let configuredOrder = EngineBootstrap.resolvedProviderOrder(settings: settings)
        let configuredIDs = Set(configuredOrder)
        let activeRuntimeIDs = registry.providerIDsInDisplayOrder()
        providerDisplayOrder = configuredOrder + activeRuntimeIDs.filter { !configuredIDs.contains($0) }
        missingConfigurationOutcomes = EngineCatalog.missingConfigurationDescriptors(settings: settings).map {
            AggregatedOutcome(
                providerId: $0.id,
                displayName: $0.name,
                modelName: configuredModelName(for: $0),
                result: nil,
                error: .notConfigured,
                latencyMs: 0
            )
        }
    }

    func validateEngine(id: String) async -> Bool {
        guard let provider = registry.provider(id: id) else { return false }
        return await EngineValidator.validate(provider)
    }

    func updateDraft(_ text: String) {
        sourceDraft = text
    }

    func clearDraft() {
        resetTranslationSession(keepDraft: false)
        workspaceNotice = nil
    }

    func removeBlankDraftLines() {
        let cleaned = sourceDraft
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
        sourceDraft = cleaned
    }

    func mergeDraftLines() {
        let merged = sourceDraft
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        sourceDraft = merged
    }

    func dismissWorkspaceNotice() {
        workspaceNotice = nil
    }

    func requestComposerFocus() {
        composerFocusRequest += 1
    }

    func setComposerFocused(_ focused: Bool) {
        isComposerFocused = focused
    }

    func resetManualLearningSelection() {
        manualLearningSelectionRevision &+= 1
    }

    func openWorkspace(
        text: String,
        mode: TranslateMode = .translate,
        autoRun: Bool,
        focusComposer: Bool
    ) {
        currentMode = mode
        isRecognizingOCR = false
        workspaceNotice = nil
        sourceDraft = text
        if autoRun {
            translateDraft(mode: mode)
        } else if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            resetTranslationSession(keepDraft: true)
        }
        if focusComposer {
            requestComposerFocus()
        }
    }

    func beginOCRRecognition(providerName: String) {
        currentMode = .translate
        isRecognizingOCR = true
        sourceDraft = ""
        resetTranslationSession(keepDraft: true)
        workspaceNotice = WorkspaceNotice(
            tone: .info,
            systemImage: "doc.text.viewfinder",
            title: L("正在识别截图"),
            detail: L("%@ 正在读取框选区域；识别完成后会进入可编辑源文区。", L(providerName)),
            prominence: .compact,
            primaryAction: nil,
            secondaryAction: nil
        )
    }

    func openOCRWorkspace(result: OCRResult, providerName: String) {
        isRecognizingOCR = false
        currentMode = .translate
        let text = result.fullText.trimmingCharacters(in: .whitespacesAndNewlines)
        sourceDraft = text
        sourceText = ""
        outcomes = []
        pendingProviders = []
        slowProviderIDs = []
        isTranslating = false
        detectedSource = result.detectedLanguages.first ?? .auto
        savedRecordId = nil
        isFavorite = false
        didSaveCurrentTranslation = false
        currentTranslationID = UUID()

        let lineCount = max(1, text.split(separator: "\n", omittingEmptySubsequences: true).count)
        let confidence = Int((result.confidence * 100).rounded())
        workspaceNotice = WorkspaceNotice(
            tone: .info,
            systemImage: "doc.text.magnifyingglass",
            title: L("OCR · %d 行 · %d%%", lineCount, confidence),
            detail: L("%@ 已自动翻译；可继续校对源文后按 ⌘↩ 重译。", L(providerName)),
            prominence: .compact,
            primaryAction: nil,
            secondaryAction: nil
        )
        requestComposerFocus()
    }

    func showOCRNoText(providerName: String) {
        isRecognizingOCR = false
        sourceDraft = ""
        resetTranslationSession(keepDraft: true)
        workspaceNotice = WorkspaceNotice(
            tone: .warning,
            systemImage: "text.viewfinder",
            title: L("未识别到文字"),
            detail: L("%@ 没有读到可翻译文本。请重新框选包含清晰文字的区域，或切换 OCR 引擎。", L(providerName)),
            prominence: .card,
            primaryAction: WorkspaceNotice.ButtonSpec(title: L("重新截图"), action: .retryScreenshot),
            secondaryAction: WorkspaceNotice.ButtonSpec(title: L("识别设置"), action: .openOCRSettings)
        )
    }

    func showOCRError(_ error: Error, providerName: String) {
        isRecognizingOCR = false
        sourceDraft = ""
        resetTranslationSession(keepDraft: true)
        workspaceNotice = WorkspaceNotice(
            tone: .error,
            systemImage: "exclamationmark.triangle",
            title: L("截图识别失败"),
            detail: L("%@ 无法完成识别。请重试截图，或检查 OCR 引擎配置。", L(providerName)),
            prominence: .card,
            primaryAction: WorkspaceNotice.ButtonSpec(title: L("重新截图"), action: .retryScreenshot),
            secondaryAction: WorkspaceNotice.ButtonSpec(title: L("识别设置"), action: .openOCRSettings)
        )
    }

    func showScreenRecordingPermissionIssue() {
        isRecognizingOCR = false
        sourceDraft = ""
        resetTranslationSession(keepDraft: true)
        workspaceNotice = WorkspaceNotice(
            tone: .error,
            systemImage: "lock.shield",
            title: L("需要屏幕录制权限"),
            detail: L("Parrot 需要屏幕录制权限才能截图识别。授权后回到这里重新截图。"),
            prominence: .card,
            primaryAction: WorkspaceNotice.ButtonSpec(title: L("打开设置"), action: .openScreenRecordingSettings),
            secondaryAction: WorkspaceNotice.ButtonSpec(title: L("重新截图"), action: .retryScreenshot)
        )
    }

    func openManualInputWorkspace() {
        currentMode = .translate
        isRecognizingOCR = false
        workspaceNotice = nil
        resetManualLearningSelection()
        if !isSourceDirty {
            sourceDraft = ""
            resetTranslationSession(keepDraft: true)
        }
        requestComposerFocus()
    }

    func translateDraft(mode: TranslateMode? = nil) {
        let trimmed = sourceDraftTrimmed
        guard !trimmed.isEmpty else { return }
        translate(trimmed, mode: mode ?? currentMode)
    }

    func translate(_ text: String, mode: TranslateMode = .translate) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        translationTask?.cancel()
        slowHintTasks.forEach { $0.cancel() }
        slowHintTasks = []
        isRecognizingOCR = false
        resetManualLearningSelection()

        let runID = UUID()
        currentTranslationID = runID
        didSaveCurrentTranslation = false
        currentMode = mode

        sourceText = trimmed
        sourceDraft = trimmed
        let direction = directionResolver.resolve(
            text: trimmed,
            from: settings.sourceLanguage,
            to: settings.targetLanguage
        )
        sourceLanguage = settings.sourceLanguage == .auto ? .auto : direction.from
        targetLanguage = direction.to
        detectedSource = direction.detected
        isTranslating = true
        let activeProviders = registry.activeProviders()
        outcomes = missingConfigurationOutcomes
        slowProviderIDs = Set(activeProviders.filter(Self.isSlowProvider).map(\.id))
        pendingProviders = activeProviders.map {
            PendingProviderViewState(
                id: $0.id,
                displayName: $0.displayName,
                modelName: $0.modelName,
                isSlow: Self.isSlowProvider($0)
            )
        }
        savedRecordId = nil
        isFavorite = false

        scheduleSlowProviderHints(runID: runID)

        let req = TranslateRequest(
            text: trimmed,
            from: direction.from,
            to: direction.to,
            mode: mode,
            terminology: settings.terminologySnapshot()
        )
        let coordinator = coordinator
        translationTask = Task { [weak self, coordinator] in
            let stream = await coordinator.translateIncrementally(req)
            for await outcome in stream {
                guard !Task.isCancelled else { break }
                await self?.handleIncrementalOutcome(outcome, runID: runID)
            }
            await self?.finishTranslation(runID: runID)
        }
    }

    func lookupLearningSelection(
        _ selection: String,
        contextText: String,
        providerID: String,
        usesTranslation: Bool
    ) async -> TranslateResult? {
        let term = selection.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !term.isEmpty,
              let provider = lookupProvider(preferredID: providerID) else { return nil }
        let direction = lookupDirection(usesTranslation: usesTranslation)
        let req = TranslateRequest(
            text: lookupRequestText(term: term, contextText: contextText, providerID: provider.id),
            from: direction.from,
            to: direction.to,
            mode: .lookup,
            terminology: nil
        )
        let outcome = await TranslationCoordinator.runProvider(provider, req: req, baseTimeout: 15)
        return outcome.result
    }

    private func resetTranslationSession(keepDraft: Bool) {
        translationTask?.cancel()
        slowHintTasks.forEach { $0.cancel() }
        slowHintTasks = []
        resetManualLearningSelection()
        if !keepDraft {
            sourceDraft = ""
        }
        sourceText = ""
        outcomes = []
        pendingProviders = []
        slowProviderIDs = []
        isTranslating = false
        detectedSource = .auto
        savedRecordId = nil
        isFavorite = false
        didSaveCurrentTranslation = false
        currentTranslationID = UUID()
    }

    private func lookupProvider(preferredID: String) -> TranslationProvider? {
        if let provider = registry.provider(id: preferredID),
           provider.capabilities.supportsLookup {
            return provider
        }
        return registry.activeProviders().first { $0.capabilities.supportsLookup }
    }

    private func lookupDirection(usesTranslation: Bool) -> (from: Language, to: Language) {
        let resolvedSource = sourceLanguage == .auto ? detectedSource : sourceLanguage
        if usesTranslation {
            let target = resolvedSource == .auto ? Language.en : resolvedSource
            return (from: targetLanguage, to: target)
        }
        return (from: resolvedSource, to: targetLanguage)
    }

    private func lookupRequestText(term: String, contextText: String, providerID: String) -> String {
        let context = contextText.trimmingCharacters(in: .whitespacesAndNewlines)
        let baseID = EngineModelConfig.baseEngineID(forProviderID: providerID)
        guard !context.isEmpty, Self.contextualLookupProviderIDs.contains(baseID) else {
            return term
        }
        return """
        Selected expression: \(term)
        Context sentence: \(context)
        """
    }

    private static let contextualLookupProviderIDs: Set<String> = [
        "openai", "opencode", "deepseek", "gemini", "groq", "ollama", "qwen",
        "doubao", "kimi", "zhipu", "siliconflow", "ernie", "hunyuan", "yi", "azure-openai"
    ]

    private static func isSlowProvider(_ provider: TranslationProvider) -> Bool {
        provider.id == "opencode" || provider.capabilities.supportsStream
    }

    private func configuredModelName(for descriptor: EngineDescriptor) -> String? {
        let model = settings.model(for: descriptor.id) ?? descriptor.defaultModel ?? ""
        let trimmed = model.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func configuredModelName(forProviderID providerID: String) -> String? {
        let engineID = EngineModelConfig.baseEngineID(forProviderID: providerID)
        guard let descriptor = EngineCatalog.descriptor(for: engineID),
              let defaultModel = descriptor.defaultModel else {
            return nil
        }
        let model = settings.modelConfigs(for: engineID, defaultModel: defaultModel)
            .first { $0.providerID(engineID: engineID) == providerID }?
            .trimmedName
        return model?.isEmpty == false ? model : configuredModelName(for: descriptor)
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
    }

    private func finishTranslation(runID: UUID) async {
        guard currentTranslationID == runID else { return }
        isTranslating = false
        pendingProviders = []
        slowHintTasks.forEach { $0.cancel() }
        slowHintTasks = []
        await saveCurrentTranslationIfNeeded(runID: runID)
    }

    private func saveCurrentTranslationIfNeeded(runID: UUID) async {
        guard currentTranslationID == runID, !didSaveCurrentTranslation else { return }
        let successes = outcomes.compactMap { outcome -> TranslationRecordOutcome? in
            guard let result = outcome.result else { return nil }
            return TranslationRecordOutcome(
                providerId: outcome.providerId,
                displayName: outcome.displayName,
                modelName: outcome.modelName,
                translated: result.translated,
                latencyMs: outcome.latencyMs,
                terminologyApplication: result.terminologyApplication
            )
        }
        guard let primary = successes.first else { return }
        didSaveCurrentTranslation = true
        let record = TranslationRecord(
            sourceText: sourceText,
            translated: primary.translated,
            providerId: primary.providerId,
            outcomes: successes,
            sourceLang: ((sourceLanguage == .auto ? detectedSource : sourceLanguage).code ?? "auto"),
            targetLang: (targetLanguage.code ?? "")
        )
        await history.add(record)
        guard currentTranslationID == runID else { return }
        savedRecordId = record.id
        refreshLearningHistory()
    }

    func refreshLearningHistory() {
        learningHistoryRefreshGeneration += 1
        let generation = learningHistoryRefreshGeneration
        let historyStore = history
        Task {
            let records = await historyStore.all()
            let counts = await Task.detached(priority: .utility) {
                LearningRecommendationEngine.occurrenceCounts(records: records)
            }.value
            guard generation == learningHistoryRefreshGeneration else { return }
            self.learningHistoryRecords = records
            self.learningOccurrenceCounts = counts
        }
    }

    var learningVocabularyItems: [LearningVocabularyItem] {
        LearningRecommendationEngine.vocabularyItems(
            records: learningHistoryRecords,
            occurrenceCounts: learningOccurrenceCounts,
            vocabularyEntries: settings.learningVocabularyEntries,
            includeHistoryRecommendations: false
        )
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

    func retryCurrentTranslation() {
        translateDraft(mode: currentMode)
    }

    func retryProvider(_ id: String) {
        if isSourceDirty {
            translateDraft(mode: currentMode)
            return
        }
        let trimmed = committedSourceTrimmed
        guard !trimmed.isEmpty else { return }
        let direction = directionResolver.resolve(
            text: trimmed,
            from: settings.sourceLanguage,
            to: settings.targetLanguage
        )
        let req = TranslateRequest(
            text: trimmed,
            from: direction.from,
            to: direction.to,
            mode: currentMode,
            terminology: settings.terminologySnapshot()
        )

        guard let provider = registry.activeProviders().first(where: { $0.id == id }) else {
            if let descriptor = EngineCatalog.descriptor(for: id) {
                upsertOutcome(AggregatedOutcome(
                    providerId: id,
                    displayName: descriptor.name,
                    modelName: configuredModelName(forProviderID: id) ?? configuredModelName(for: descriptor),
                    result: nil,
                    error: .notConfigured,
                    latencyMs: 0
                ))
            }
            return
        }

        let runID = currentTranslationID
        outcomes.removeAll { $0.providerId == id }
        pendingProviders.removeAll { $0.id == id }
        pendingProviders.append(PendingProviderViewState(
            id: provider.id,
            displayName: provider.displayName,
            modelName: provider.modelName,
            isSlow: Self.isSlowProvider(provider)
        ))
        isTranslating = true

        Task { [weak self, provider] in
            let outcome = await TranslationCoordinator.runProvider(provider, req: req, baseTimeout: 15)
            await self?.handleIncrementalOutcome(outcome, runID: runID)
            await MainActor.run {
                guard let self else { return }
                if self.pendingProviders.isEmpty { self.isTranslating = false }
            }
        }
    }

    private func upsertOutcome(_ outcome: AggregatedOutcome) {
        if let index = outcomes.firstIndex(where: { $0.providerId == outcome.providerId }) {
            outcomes[index] = outcome
        } else {
            outcomes.append(outcome)
        }
    }

    func speakSource() {
        Speaker.shared.speak(actionSourceText, language: sourceLanguage == .auto ? detectedSource : sourceLanguage)
    }

    func speakTranslation(_ text: String) {
        Speaker.shared.speak(text, language: targetLanguage)
    }
}
