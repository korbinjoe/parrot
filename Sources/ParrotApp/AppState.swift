import Foundation
import ParrotCore
import ParrotEngines
import ParrotPlugins
import Combine
import CoreGraphics
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
        case openSettings
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

enum WorkspaceSurface: Equatable {
    case quickPeek
    case workspace
}

struct OCRCandidateViewState: Identifiable, Equatable {
    enum Kind: Equatable {
        case fullText
        case primaryBody
        case reply
        case block
    }

    let id: UUID
    let text: String
    let confidence: Float
    let boundingBox: CGRect
    let score: Double
    let kind: Kind

    var isLowConfidence: Bool { confidence < 0.55 }
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
    @Published var workspaceSurface: WorkspaceSurface = .workspace
    @Published var contextProfile: TranslationContextProfile = .quickTranslate
    @Published var currentOrigin: TranslationOrigin = .unknown
    @Published private(set) var currentContextSourceApp: String?
    @Published private(set) var currentContextWindowTitle: String?
    @Published private(set) var currentContextSourceURL: String?
    @Published var ocrCandidates: [OCRCandidateViewState] = []
    @Published var selectedOCRCandidateID: UUID?
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
    private var currentRequest: TranslateRequest?
    private var didSaveCurrentTranslation = false
    private var currentMode: TranslateMode = .translate
    private let directionResolver = TranslationDirectionResolver()
    private var learningHistoryRefreshGeneration = 0
    private var settingsObserver: AnyCancellable?
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

    var isPolishMode: Bool {
        currentMode == .polish
    }

    var isQuickPeekSurface: Bool {
        workspaceSurface == .quickPeek
    }

    var primarySuccessfulOutcome: AggregatedOutcome? {
        outcomes.first { $0.result?.qualitySummary?.isRecommended == true }
            ?? outcomes.first { $0.result != nil }
    }

    var paragraphHints: [ParagraphHint] {
        if let hints = currentRequest?.context?.paragraphHints, !hints.isEmpty {
            return hints
        }
        let text = committedSourceTrimmed.isEmpty ? sourceDraftTrimmed : committedSourceTrimmed
        return ParagraphSegmenter.segment(text)
    }

    var canShowParagraphBilingualView: Bool {
        workspaceSurface == .workspace
            && paragraphHints.count > 1
            && primarySuccessfulOutcome?.result != nil
    }

    var selectedOCRCandidate: OCRCandidateViewState? {
        guard let selectedOCRCandidateID else { return nil }
        return ocrCandidates.first { $0.id == selectedOCRCandidateID }
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
        settingsObserver = settings.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }
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
            Task { @MainActor [weak self] in self?.isOffline = path.status != .satisfied }
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
        focusComposer: Bool,
        origin: TranslationOrigin = .unknown,
        surface: WorkspaceSurface? = nil,
        profile: TranslationContextProfile? = nil,
        sourceApp: String? = nil,
        windowTitle: String? = nil,
        sourceURL: String? = nil
    ) {
        currentMode = mode
        currentOrigin = origin
        currentContextSourceApp = Self.cleanedMetadata(sourceApp)
        currentContextWindowTitle = Self.cleanedMetadata(windowTitle)
        currentContextSourceURL = Self.cleanedMetadata(sourceURL)
        contextProfile = profile ?? defaultProfile(mode: mode, origin: origin, text: text)
        workspaceSurface = surface ?? defaultSurface(mode: mode, origin: origin, text: text)
        currentRequest = nil
        if origin != .ocr && origin != .screenshot && origin != .latestScreenshot {
            clearOCRCandidates()
        }
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
        currentOrigin = .ocr
        currentContextSourceApp = nil
        currentContextWindowTitle = nil
        currentContextSourceURL = nil
        contextProfile = .understand
        workspaceSurface = .workspace
        isRecognizingOCR = true
        sourceDraft = ""
        clearOCRCandidates()
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
        currentOrigin = .ocr
        currentContextSourceApp = nil
        currentContextWindowTitle = nil
        currentContextSourceURL = nil
        contextProfile = .understand
        workspaceSurface = .workspace
        let text = result.fullText.trimmingCharacters(in: .whitespacesAndNewlines)
        let candidates = Self.makeOCRCandidates(from: result)
        let selectedCandidate = candidates.first
        ocrCandidates = candidates
        selectedOCRCandidateID = selectedCandidate?.id
        sourceDraft = selectedCandidate?.text ?? text
        sourceText = ""
        outcomes = []
        pendingProviders = []
        slowProviderIDs = []
        isTranslating = false
        detectedSource = result.detectedLanguages.first ?? .auto
        savedRecordId = nil
        isFavorite = false
        didSaveCurrentTranslation = false
        currentRequest = nil
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
        clearOCRCandidates()
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
        clearOCRCandidates()
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
        clearOCRCandidates()
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

    func openManualInputWorkspace(sourceApp: String? = nil, windowTitle: String? = nil) {
        currentMode = .translate
        currentOrigin = .manualInput
        currentContextSourceApp = Self.cleanedMetadata(sourceApp)
        currentContextWindowTitle = Self.cleanedMetadata(windowTitle)
        currentContextSourceURL = nil
        contextProfile = manualInputProfile()
        workspaceSurface = .workspace
        isRecognizingOCR = false
        clearOCRCandidates()
        workspaceNotice = nil
        resetManualLearningSelection()
        if !isSourceDirty {
            sourceDraft = ""
            resetTranslationSession(keepDraft: true)
        }
        requestComposerFocus()
    }

    func openManualPolishWorkspace(sourceApp: String? = nil, windowTitle: String? = nil) {
        currentMode = .polish
        currentOrigin = .manualInput
        currentContextSourceApp = Self.cleanedMetadata(sourceApp)
        currentContextWindowTitle = Self.cleanedMetadata(windowTitle)
        currentContextSourceURL = nil
        contextProfile = .nativePolish
        workspaceSurface = .workspace
        isRecognizingOCR = false
        clearOCRCandidates()
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
        let direction = resolvedDirection(text: trimmed, mode: mode)
        sourceLanguage = settings.sourceLanguage == .auto ? .auto : direction.from
        targetLanguage = direction.to
        detectedSource = direction.detected
        isTranslating = true
        let req = makeRequest(text: trimmed, direction: direction, mode: mode)
        currentRequest = req
        let activeProviders = routedActiveProviders(for: req.context)
        if contextProfile == .privateLocal && activeProviders.isEmpty {
            outcomes = []
            slowProviderIDs = []
            pendingProviders = []
            savedRecordId = nil
            isFavorite = false
            isTranslating = false
            workspaceNotice = WorkspaceNotice(
                tone: .warning,
                systemImage: "lock.shield",
                title: L("需要本地引擎"),
                detail: L("隐私本地模式不会发送到云端。请启用 Apple 或 Ollama 本地引擎，或切换到其他上下文配置。"),
                prominence: .card,
                primaryAction: WorkspaceNotice.ButtonSpec(title: L("打开设置"), action: .openSettings),
                secondaryAction: WorkspaceNotice.ButtonSpec(title: L("知道了"), action: .dismiss)
            )
            return
        }
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
            terminology: nil,
            context: TranslationContext.default(mode: .lookup, origin: .lookup, text: term)
        )
        let outcome = await TranslationCoordinator.runProvider(provider, req: req, baseTimeout: 15)
        return outcome.result
    }

    func setContextProfile(_ profile: TranslationContextProfile) {
        guard contextProfile != profile else { return }
        contextProfile = profile
        settings.rememberContextProfile(profile)
        workspaceSurface = .workspace
        if canTranslateDraft {
            translateDraft(mode: currentMode)
        }
    }

    func expandQuickPeek() {
        workspaceSurface = .workspace
    }

    func selectOCRCandidate(id: UUID, autoRun: Bool = true) {
        guard let candidate = ocrCandidates.first(where: { $0.id == id }) else { return }
        selectedOCRCandidateID = id
        sourceDraft = candidate.text
        sourceText = ""
        outcomes = []
        pendingProviders = []
        slowProviderIDs = []
        isTranslating = false
        savedRecordId = nil
        isFavorite = false
        didSaveCurrentTranslation = false
        currentRequest = nil
        if autoRun {
            translateDraft(mode: currentMode)
        }
    }

    private func clearOCRCandidates() {
        ocrCandidates = []
        selectedOCRCandidateID = nil
    }

    private static func makeOCRCandidates(from result: OCRResult) -> [OCRCandidateViewState] {
        let fullText = result.fullText.trimmingCharacters(in: .whitespacesAndNewlines)
        var seen: Set<String> = []
        var candidates: [OCRCandidateViewState] = []

        let blockCandidates = groupedOCRCandidates(from: result.blocks)
            .sorted { lhs, rhs in
                if lhs.score != rhs.score { return lhs.score > rhs.score }
                return lhs.text.count > rhs.text.count
            }

        for candidate in blockCandidates {
            let key = candidateKey(candidate.text)
            guard !seen.contains(key) else { continue }
            seen.insert(key)
            candidates.append(candidate)
            if candidates.count >= 6 { break }
        }

        if !fullText.isEmpty {
            let key = candidateKey(fullText)
            if !seen.contains(key) {
                seen.insert(key)
                candidates.append(OCRCandidateViewState(
                    id: UUID(),
                    text: fullText,
                    confidence: result.confidence,
                    boundingBox: unionRect(result.blocks.map(\.boundingBox)),
                    score: 0,
                    kind: .fullText
                ))
            }
        }
        return Array(candidates.prefix(7))
    }

    private static func candidateKey(_ text: String) -> String {
        text
            .lowercased()
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    private struct OCRCandidateLine {
        let text: String
        let normalizedRect: CGRect
        let sourceRect: CGRect
        let confidence: Float
    }

    private static func groupedOCRCandidates(from blocks: [OCRBlock]) -> [OCRCandidateViewState] {
        let nonEmptyBlockCount = blocks
            .map { $0.text.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .count
        let lines = blocks.compactMap(normalizedOCRCandidateLine(from:))
        guard lines.count >= 2, lines.count == nonEmptyBlockCount else { return [] }

        var groups: [[OCRCandidateLine]] = []
        for line in lines.sorted(by: ocrLineSort) {
            guard var last = groups.popLast() else {
                groups.append([line])
                continue
            }
            if shouldMergeOCRLine(line, into: last) {
                last.append(line)
                groups.append(last)
            } else {
                groups.append(last)
                groups.append([line])
            }
        }

        return groups.compactMap { group in
            let text = group.map(\.text).joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { return nil }
            let confidence = group.map(\.confidence).reduce(0, +) / Float(group.count)
            let sourceRect = unionRect(group.map(\.sourceRect))
            let normalizedRect = unionRect(group.map(\.normalizedRect))
            return OCRCandidateViewState(
                id: UUID(),
                text: text,
                confidence: confidence,
                boundingBox: sourceRect,
                score: ocrCandidateScore(
                    text: text,
                    confidence: confidence,
                    boundingBox: normalizedRect,
                    lineCount: group.count
                ),
                kind: ocrCandidateKind(text: text, lineCount: group.count, boundingBox: normalizedRect)
            )
        }
    }

    private static func normalizedOCRCandidateLine(from block: OCRBlock) -> OCRCandidateLine? {
        let text = block.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, hasUsableOCRGeometry(block.boundingBox) else { return nil }
        let source = block.boundingBox
        let normalized = CGRect(
            x: source.minX,
            y: 1 - source.maxY,
            width: source.width,
            height: source.height
        )
        return OCRCandidateLine(
            text: text,
            normalizedRect: normalized,
            sourceRect: source,
            confidence: block.confidence
        )
    }

    private static func hasUsableOCRGeometry(_ rect: CGRect) -> Bool {
        rect.width > 0
            && rect.height > 0
            && rect.minX >= 0
            && rect.minY >= 0
            && rect.maxX <= 1.05
            && rect.maxY <= 1.05
    }

    private static func ocrLineSort(_ lhs: OCRCandidateLine, _ rhs: OCRCandidateLine) -> Bool {
        if abs(lhs.normalizedRect.minY - rhs.normalizedRect.minY) > 0.012 {
            return lhs.normalizedRect.minY < rhs.normalizedRect.minY
        }
        return lhs.normalizedRect.minX < rhs.normalizedRect.minX
    }

    private static func shouldMergeOCRLine(_ line: OCRCandidateLine, into group: [OCRCandidateLine]) -> Bool {
        guard let previous = group.last else { return false }
        if isLikelyOCRNoise(previous.text) || isLikelyOCRNoise(line.text) {
            return false
        }
        let verticalGap = line.normalizedRect.minY - previous.normalizedRect.maxY
        let overlap = horizontalOverlap(line.normalizedRect, previous.normalizedRect)
        let overlapRatio = overlap / max(0.001, min(line.normalizedRect.width, previous.normalizedRect.width))
        let xDistance = abs(line.normalizedRect.minX - previous.normalizedRect.minX)
        let compatibleColumn = overlapRatio > 0.16 || xDistance < 0.09
        let closeVertically = verticalGap < max(0.032, previous.normalizedRect.height * 2.4)
        let strongIndentChange = xDistance > 0.18 && overlapRatio < 0.08
        return closeVertically && compatibleColumn && !strongIndentChange
    }

    private static func ocrCandidateScore(
        text: String,
        confidence: Float,
        boundingBox: CGRect,
        lineCount: Int
    ) -> Double {
        let tokenCount = text.split { !$0.isLetter && !$0.isNumber && $0 != "'" }.count
        let lengthScore = min(Double(text.count) / 180.0, 1) * 28
        let tokenScore = min(Double(tokenCount) / 28.0, 1) * 24
        let lineScore = min(Double(lineCount) / 4.0, 1) * 12
        let areaScore = min(max(Double(boundingBox.width * boundingBox.height) / 0.22, 0), 1) * 10
        let centerScore = max(0, 1 - abs(Double(boundingBox.midY) - 0.48) * 1.7) * 10
        let confidenceScore = Double(confidence) * 12
        let roleBonus: Double
        switch ocrCandidateKind(text: text, lineCount: lineCount, boundingBox: boundingBox) {
        case .primaryBody:
            roleBonus = 10
        case .reply:
            roleBonus = 5
        case .block:
            roleBonus = 0
        case .fullText:
            roleBonus = -10
        }
        let noisePenalty = isLikelyOCRNoise(text) ? 55.0 : 0
        return max(0, lengthScore + tokenScore + lineScore + areaScore + centerScore + confidenceScore + roleBonus - noisePenalty)
    }

    private static func ocrCandidateKind(
        text: String,
        lineCount: Int,
        boundingBox: CGRect
    ) -> OCRCandidateViewState.Kind {
        if lineCount > 1 || text.count >= 96 || boundingBox.height > 0.12 {
            return .primaryBody
        }
        if isLikelyReplySentence(text) {
            return .reply
        }
        return .block
    }

    private static func isLikelyOCRNoise(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return true }
        if trimmed.count <= 2 { return true }
        if trimmed.range(of: #"^(\d{1,2}:\d{2}|now|today|yesterday)(\s*[·•]\s*.*)?$"#, options: [.regularExpression, .caseInsensitive]) != nil {
            return true
        }
        if trimmed.range(of: #"^\d+(\.\d+)?[kKmM]?\s*(replies|reply|likes|comments|shares|views|votes)?$"#, options: .regularExpression) != nil {
            return true
        }
        let lower = trimmed.lowercased()
        if ["reply", "share", "like", "more", "post", "send", "cancel", "home", "search", "notifications"].contains(lower) {
            return true
        }
        let digits = trimmed.filter(\.isNumber).count
        return trimmed.count <= 5 && digits >= max(2, trimmed.count - 1)
    }

    private static func isLikelyReplySentence(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 18, trimmed.count <= 140 else { return false }
        let sentenceEndings = Set(".?!。！？")
        guard trimmed.contains(where: { sentenceEndings.contains($0) }) else { return false }
        let lower = trimmed.lowercased()
        return lower.hasPrefix("i ")
            || lower.hasPrefix("we ")
            || lower.hasPrefix("you ")
            || lower.hasPrefix("can ")
            || lower.hasPrefix("could ")
            || lower.hasPrefix("would ")
            || lower.hasPrefix("should ")
            || lower.hasPrefix("a ")
            || lower.hasPrefix("the ")
    }

    private static func horizontalOverlap(_ a: CGRect, _ b: CGRect) -> CGFloat {
        max(0, min(a.maxX, b.maxX) - max(a.minX, b.minX))
    }

    private static func unionRect(_ rects: [CGRect]) -> CGRect {
        guard var rect = rects.first else { return .zero }
        for next in rects.dropFirst() {
            rect = rect.union(next)
        }
        return rect
    }

    private func makeRequest(
        text: String,
        direction: ResolvedTranslationDirection,
        mode: TranslateMode
    ) -> TranslateRequest {
        let terminology = settings.terminologySnapshot()
        let context = makeContext(
            text: text,
            mode: mode,
            terminology: terminology
        )
        return TranslateRequest(
            text: text,
            from: direction.from,
            to: direction.to,
            mode: mode,
            terminology: terminology,
            context: context
        )
    }

    private func resolvedDirection(text: String, mode: TranslateMode) -> ResolvedTranslationDirection {
        if mode == .polish {
            return directionResolver.resolvePolish(text: text, from: settings.sourceLanguage)
        }
        return directionResolver.resolve(
            text: text,
            from: settings.sourceLanguage,
            to: settings.targetLanguage
        )
    }

    private func makeContext(
        text: String,
        mode: TranslateMode,
        terminology: TerminologySnapshot?
    ) -> TranslationContext {
        let profile = contextProfile
        let localProviderIDs = routedLocalProviderIDs()
        let allowedProviderIDs = profile == .privateLocal ? localProviderIDs : nil
        return TranslationContext(
            profile: profile,
            origin: currentOrigin,
            sourceApp: currentContextSourceApp,
            windowTitle: currentContextWindowTitle,
            sourceURL: currentContextSourceURL,
            selectedOCRBlockID: selectedOCRCandidateID,
            paragraphHints: ParagraphSegmenter.segment(text),
            privacyPolicy: privacyPolicy(for: profile),
            routingHints: ProviderRoutingHints(
                allowedProviderIDs: allowedProviderIDs,
                preferLLM: profile.prefersLLM,
                preferLocal: profile == .privateLocal
            )
        )
    }

    private func defaultProfile(
        mode: TranslateMode,
        origin: TranslationOrigin,
        text: String
    ) -> TranslationContextProfile {
        if let ruleProfile = automaticRuleProfile(mode: mode, origin: origin, text: text) {
            return ruleProfile
        }
        return TranslationContextProfile.defaultProfile(
            mode: mode,
            origin: origin,
            text: text,
            hasTerminology: settings.terminologySnapshot()?.isEmpty == false
        )
    }

    private func automaticRuleProfile(
        mode: TranslateMode,
        origin: TranslationOrigin,
        text: String
    ) -> TranslationContextProfile? {
        guard mode == .translate else { return nil }
        let sourceApp = (currentContextSourceApp ?? "").lowercased()
        let sourceURL = (currentContextSourceURL ?? "").lowercased()
        let windowTitle = (currentContextWindowTitle ?? "").lowercased()
        let combined = [sourceApp, sourceURL, windowTitle].joined(separator: " ")
        let isPrivateSurface = combined.contains("1password")
            || combined.contains("password")
            || combined.contains("keychain")
            || combined.contains("bank")
            || combined.contains("wallet")
        let isDeveloperSurface = combined.contains("github")
            || combined.contains("gitlab")
            || combined.contains("linear")
            || combined.contains("jira")
            || combined.contains("pull request")
            || combined.contains("xcode")
        let isDocumentSurface = origin == .url
            || combined.contains("notion")
            || combined.contains("docs.google")
            || combined.contains("confluence")
            || combined.contains("medium.com")
            || combined.contains("safari")
            || combined.contains("chrome")
            || text.trimmingCharacters(in: .whitespacesAndNewlines).count >= 280

        if settings.contextRulePrivateEnabled, isPrivateSurface {
            return .privateLocal
        }

        if settings.contextRuleDeveloperEnabled, isDeveloperSurface {
            return .github
        }

        if settings.contextRuleDocumentEnabled, isDocumentSurface {
            return .document
        }

        return nil
    }

    private func manualInputProfile() -> TranslationContextProfile {
        let profile = settings.lastContextProfile
        switch profile {
        case .nativePolish:
            return .quickTranslate
        default:
            return profile
        }
    }

    private func defaultSurface(
        mode: TranslateMode,
        origin: TranslationOrigin,
        text: String
    ) -> WorkspaceSurface {
        if mode == .polish { return .workspace }
        if mode == .lookup { return .quickPeek }
        guard origin == .selection || origin == .shortcut || origin == .popClip || origin == .lookup else {
            return .workspace
        }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.contains("\n") { return .workspace }
        return trimmed.count <= 180 ? .quickPeek : .workspace
    }

    private func privacyPolicy(for profile: TranslationContextProfile) -> PrivacyPolicy {
        switch profile {
        case .privateLocal:
            return .localOnly
        case .github, .email:
            return .maskSensitive
        default:
            return .standard
        }
    }

    private func routedActiveProviders(for context: TranslationContext?) -> [TranslationProvider] {
        let providers = registry.activeProviders()
        guard let allowed = context?.routingHints.allowedProviderIDs else {
            return providers
        }
        let allowedSet = Set(allowed)
        return providers.filter { allowedSet.contains($0.id) }
    }

    private static func cleanedMetadata(_ value: String?) -> String? {
        guard let cleaned = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !cleaned.isEmpty else { return nil }
        return cleaned
    }

    private static func displaySnippet(_ text: String, limit: Int) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > limit else { return trimmed }
        return String(trimmed.prefix(limit)).trimmingCharacters(in: .whitespacesAndNewlines) + "..."
    }

    private func routedLocalProviderIDs() -> [String] {
        registry.activeProviders()
            .map(\.id)
            .filter { providerID in
                let baseID = EngineModelConfig.baseEngineID(forProviderID: providerID)
                return baseID == "apple" || baseID == "ollama"
            }
    }

    private func resetTranslationSession(keepDraft: Bool) {
        translationTask?.cancel()
        slowHintTasks.forEach { $0.cancel() }
        slowHintTasks = []
        resetManualLearningSelection()
        if !keepDraft {
            sourceDraft = ""
            clearOCRCandidates()
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
        currentRequest = nil
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
        if let currentRequest {
            outcomes = ResultQualityEvaluator.withRecommendation(outcomes: outcomes, request: currentRequest)
        }

        if sourceLanguage == .auto, let detected = outcome.result?.detectedFrom {
            detectedSource = detected
        }
    }

    private func finishTranslation(runID: UUID) async {
        guard currentTranslationID == runID else { return }
        isTranslating = false
        pendingProviders = []
        if let currentRequest {
            outcomes = ResultQualityEvaluator.withRecommendation(outcomes: outcomes, request: currentRequest)
        }
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

    @discardableResult
    func saveCurrentExpression(
        translatedText: String,
        sceneLabel: String = "工作区表达"
    ) -> Bool {
        let source = actionSourceText.trimmingCharacters(in: .whitespacesAndNewlines)
        let translated = translatedText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !source.isEmpty || !translated.isEmpty else { return false }
        let termSource = source.isEmpty ? translated : source
        let term = Self.displaySnippet(termSource, limit: 160)
        let savedID = settings.addLearningVocabularyTerm(
            term: term,
            meaning: translated,
            sourceSentence: source,
            sceneLabel: sceneLabel
        )
        if savedID != nil {
            refreshLearningHistory()
            return true
        }
        return false
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
        let direction = resolvedDirection(text: trimmed, mode: currentMode)
        let req = makeRequest(text: trimmed, direction: direction, mode: currentMode)
        currentRequest = req

        guard let provider = routedActiveProviders(for: req.context).first(where: { $0.id == id }) else {
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
