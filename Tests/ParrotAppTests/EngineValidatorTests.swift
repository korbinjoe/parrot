import Foundation
import Darwin
import Testing
import ParrotCore
@testable import ParrotApp

@MainActor
@Test func credentialValidationUsesAvailableKeyWhenEngineIsDisabled() async throws {
    let suiteName = "parrot.test.disabled-validation.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defaults.removePersistentDomain(forName: suiteName)

    StubURLProtocol.responseData = Data("""
    {"choices":[{"message":{"content":"你好"}}]}
    """.utf8)
    StubURLProtocol.lastAuthorization = nil

    let previousZhipuKey = getenv("ZHIPU_API_KEY").map { String(cString: $0) }
    setenv("ZHIPU_API_KEY", "glm-test-key", 1)
    URLProtocol.registerClass(StubURLProtocol.self)
    defer {
        URLProtocol.unregisterClass(StubURLProtocol.self)
        if let previousZhipuKey {
            setenv("ZHIPU_API_KEY", previousZhipuKey, 1)
        } else {
            unsetenv("ZHIPU_API_KEY")
        }
        defaults.removePersistentDomain(forName: suiteName)
    }

    defaults.set(false, forKey: "engine.zhipu.enabled")

    let settings = AppSettings(defaults: defaults)
    let provider = try #require(EngineValidator.makeConfiguredProvider(id: "zhipu", settings: settings))

    #expect(await EngineValidator.validateDetailed(provider) == .passed)
    #expect(StubURLProtocol.lastAuthorization == "Bearer glm-test-key")
}

@MainActor
@Test func enabledLLMModelConfigsRegisterAsIndependentProviders() throws {
    let suiteName = "parrot.test.model-configs.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defaults.removePersistentDomain(forName: suiteName)

    let previousZhipuKey = getenv("ZHIPU_API_KEY").map { String(cString: $0) }
    setenv("ZHIPU_API_KEY", "glm-test-key", 1)
    defer {
        if let previousZhipuKey {
            setenv("ZHIPU_API_KEY", previousZhipuKey, 1)
        } else {
            unsetenv("ZHIPU_API_KEY")
        }
        defaults.removePersistentDomain(forName: suiteName)
    }

    let settings = AppSettings(defaults: defaults)
    settings.zhipuEnabled = true
    let primary = EngineModelConfig(id: EngineModelConfig.primaryID, name: "glm-main", enabled: true)
    let disabled = EngineModelConfig(id: "disabled", name: "glm-off", enabled: false)
    let alternate = EngineModelConfig(id: "alternate", name: "glm-alt", enabled: true)
    settings.setModelConfigs([primary, disabled, alternate], for: "zhipu")

    let registry = ProviderRegistry()
    EngineBootstrap.registerAll(into: registry, settings: settings)

    let zhipuProviders = registry.activeProviders()
        .filter { EngineModelConfig.baseEngineID(forProviderID: $0.id) == "zhipu" }
    #expect(zhipuProviders.map(\.id) == [
        primary.providerID(engineID: "zhipu"),
        alternate.providerID(engineID: "zhipu")
    ])
    #expect(zhipuProviders.map(\.modelName) == ["glm-main", "glm-alt"])
    #expect(registry.provider(id: disabled.providerID(engineID: "zhipu")) != nil)
}

@MainActor
@Test func terminologySettingsPersistAndDisabledSnapshotIsNil() throws {
    let suiteName = "parrot.test.terminology.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defaults.removePersistentDomain(forName: suiteName)
    let fileURL = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent("parrot-settings-terminology-\(UUID().uuidString).json")
    defer {
        defaults.removePersistentDomain(forName: suiteName)
        try? FileManager.default.removeItem(at: fileURL)
    }

    let settings = AppSettings(
        defaults: defaults,
        terminologyStore: TerminologyStore(fileURL: fileURL)
    )
    let saveResult = settings.saveTerminologyEntry(
        TerminologyEntry(source: "AI Agent", target: "AI Agent", from: .en, to: .zh)
    )
    if case .failure(let error) = saveResult {
        Issue.record("Expected terminology save to succeed, got \(error)")
    }
    #expect(settings.terminologySnapshot()?.entries.count == 1)

    settings.terminologyEnabled = false
    #expect(settings.terminologySnapshot() == nil)

    let reloaded = AppSettings(
        defaults: defaults,
        terminologyStore: TerminologyStore(fileURL: fileURL)
    )
    #expect(reloaded.terminologyEntries.first?.source == "AI Agent")
    #expect(reloaded.terminologyEnabled == false)
}

@MainActor
@Test func learningSettingsClampAndPersistFeedback() throws {
    let suiteName = "parrot.test.learning-settings.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defaults.removePersistentDomain(forName: suiteName)
    let fileURL = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent("parrot-settings-learning-\(UUID().uuidString).json")
    defer {
        defaults.removePersistentDomain(forName: suiteName)
        try? FileManager.default.removeItem(at: fileURL)
    }

    let settings = AppSettings(
        defaults: defaults,
        terminologyStore: TerminologyStore(fileURL: fileURL)
    )
    settings.learningRecommendationLimit = 99
    #expect(settings.learningRecommendationLimit == 6)
    settings.learningRecommendationLimit = 0
    #expect(settings.learningRecommendationLimit == 1)

    settings.markLearningSaved("proposal")
    settings.markLearningSaved("proposal")
    settings.markLearningMastered("proposal")

    let reloaded = AppSettings(
        defaults: defaults,
        terminologyStore: TerminologyStore(fileURL: fileURL)
    )
    #expect(reloaded.learningRecommendationLimit == 1)
    #expect(reloaded.learningSavedExpressionIDs == ["proposal"])
    #expect(reloaded.learningMasteredExpressionIDs == ["proposal"])
}

@Test func learningRecommendationsUseHistoricalOccurrenceCounts() throws {
    let record = TranslationRecord(
        sourceText: "该提案因证据不足被驳回。",
        translated: "The proposal was rejected due to insufficient evidence.",
        providerId: "mock",
        sourceLang: "zh",
        targetLang: "en"
    )
    let counts = LearningRecommendationEngine.occurrenceCounts(records: [record, record])

    let recommendations = LearningRecommendationEngine.recommendations(
        in: record.translated,
        sourceText: record.sourceText,
        limit: 3,
        occurrenceCounts: counts
    )

    #expect(recommendations.map(\.term).contains("insufficient evidence"))
    #expect(recommendations.map(\.term).contains("due to"))
    #expect(recommendations.first(where: { $0.term == "proposal" })?.occurrenceCount == 2)
    #expect(!recommendations.map(\.term).contains("evidence"))
    let options = LearningRecommendationEngine.stableReviewOptions(for: "proposal")
    #expect(options.count == 3)
    #expect(options.contains("proposal"))
    #expect(options == LearningRecommendationEngine.stableReviewOptions(for: "proposal"))
}

@Test func learningVocabularyDoesNotAutoPopulateFromHistory() throws {
    let record = TranslationRecord(
        sourceText: "The proposal was rejected due to insufficient evidence.",
        translated: "该提案因 iCloud Drive 中缺少证据而被驳回。",
        providerId: "mock",
        sourceLang: "en",
        targetLang: "zh"
    )
    let counts = LearningRecommendationEngine.occurrenceCounts(records: [record])
    let items = LearningRecommendationEngine.vocabularyItems(records: [record], occurrenceCounts: counts)

    #expect(items.isEmpty)
}

@Test func learningTextUsesEnglishSourceForChineseTranslationWithLatinProperNouns() throws {
    let source = "The proposal was rejected due to insufficient evidence."
    let translated = "该提案因 iCloud Drive 中缺少证据而被驳回。"

    #expect(LearningRecommendationEngine.learningText(
        translatedText: translated,
        sourceText: source,
        sourceLanguage: .en,
        targetLanguage: .zh
    ) == source)

    #expect(LearningRecommendationEngine.learningText(
        translatedText: "The proposal was rejected due to insufficient evidence.",
        sourceText: "该提案因证据不足被驳回。",
        sourceLanguage: .zh,
        targetLanguage: .en
    ) == "The proposal was rejected due to insufficient evidence.")
}

@Test func manualLearningSelectionBuildsExpressionFromSelectedText() throws {
    let record = TranslationRecord(
        sourceText: "The proposal was rejected due to insufficient evidence.",
        translated: "该提案因证据不足被驳回。",
        providerId: "mock",
        sourceLang: "en",
        targetLang: "zh"
    )
    let expression = try #require(LearningRecommendationEngine.expressionForManualSelection(
        " insufficient evidence. ",
        contextText: record.sourceText,
        sourceText: record.sourceText,
        occurrenceCounts: LearningRecommendationEngine.occurrenceCounts(records: [record, record])
    ))

    #expect(expression.term == "insufficient evidence")
    #expect(expression.kind == "关键理解")
    #expect(expression.occurrenceCount == 2)
}

@Test func manualLearningSelectionUsesKnownTechnicalGlosses() throws {
    let source = "But once you get into production, observability and tracing almost always point to proprietary products."
    let expression = try #require(LearningRecommendationEngine.expressionForManualSelection(
        "proprietary",
        contextText: source,
        sourceText: source,
        occurrenceCounts: [:]
    ))

    #expect(expression.term == "proprietary")
    #expect(expression.kind == "技术词")
    #expect(expression.meaning.contains("专有"))
}

@MainActor
@Test func learningVocabularyEntriesPersistAndDriveVocabularyItems() throws {
    let suiteName = "parrot.test.learning-vocab.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defaults.removePersistentDomain(forName: suiteName)
    let fileURL = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent("parrot-settings-learning-vocab-\(UUID().uuidString).json")
    defer {
        defaults.removePersistentDomain(forName: suiteName)
        try? FileManager.default.removeItem(at: fileURL)
    }

    let settings = AppSettings(
        defaults: defaults,
        terminologyStore: TerminologyStore(fileURL: fileURL)
    )
    let record = TranslationRecord(
        sourceText: "该提案因证据不足被驳回。",
        translated: "The proposal was rejected due to insufficient evidence.",
        providerId: "mock",
        sourceLang: "zh",
        targetLang: "en"
    )
    let expression = try #require(LearningRecommendationEngine.expressionForManualSelection(
        "proposal",
        contextText: record.translated,
        sourceText: record.sourceText,
        occurrenceCounts: LearningRecommendationEngine.occurrenceCounts(records: [record])
    ))

    settings.markLearningSaved(expression, sceneLabel: "商务 / 审批")
    settings.toggleLearningVocabularyFavorite(expression.id)
    settings.recordLearningReview(expression, correct: false)
    let manualID = try #require(settings.addLearningVocabularyTerm(
        term: "context window",
        meaning: "上下文窗口",
        sourceSentence: "Open the context window."
    ))

    let reloaded = AppSettings(
        defaults: defaults,
        terminologyStore: TerminologyStore(fileURL: fileURL)
    )
    let proposal = try #require(reloaded.learningVocabularyEntries.first { $0.id == expression.id })
    #expect(proposal.isFavorite)
    #expect(proposal.wrongCount == 1)
    #expect(proposal.nextReviewAt != nil)
    #expect(reloaded.learningSavedExpressionIDs.contains(expression.id))

    let items = LearningRecommendationEngine.vocabularyItems(
        records: [],
        occurrenceCounts: [:],
        vocabularyEntries: reloaded.learningVocabularyEntries
    )
    #expect(items.contains { $0.id == manualID && $0.isManual })
    #expect(items.contains { $0.id == expression.id && $0.isFavorite && $0.isDue })
}

private final class StubURLProtocol: URLProtocol {
    static var responseData = Data()
    static var lastAuthorization: String?

    override class func canInit(with request: URLRequest) -> Bool {
        request.url?.host == "open.bigmodel.cn"
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        Self.lastAuthorization = request.value(forHTTPHeaderField: "Authorization")
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Self.responseData)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
