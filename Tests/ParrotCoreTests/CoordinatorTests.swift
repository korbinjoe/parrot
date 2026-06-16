import Testing
@testable import ParrotCore
@testable import ParrotEngines

@Test func mockEngineTranslates() async throws {
    let engine = MockEngine()
    let result = try await engine.translate(
        TranslateRequest(text: "hello", from: .en, to: .zh)
    )
    #expect(result.providerId == "mock")
    #expect(result.translated.contains("hello"))
}

@Test func coordinatorAggregatesActiveProviders() async {
    let registry = ProviderRegistry()
    registry.register(MockEngine())
    let coordinator = TranslationCoordinator(registry: registry)
    let outcomes = await coordinator.translateAll(
        TranslateRequest(text: "world", to: .zh)
    )
    #expect(outcomes.count == 1)
    #expect(outcomes[0].isSuccess)
}

@Test func disabledProviderIsExcluded() async {
    let registry = ProviderRegistry()
    registry.register(MockEngine(), enabled: false)
    let coordinator = TranslationCoordinator(registry: registry)
    let outcomes = await coordinator.translateAll(
        TranslateRequest(text: "x", to: .zh)
    )
    #expect(outcomes.isEmpty)
}

@Test func failingProviderIsIsolated() async {
    let registry = ProviderRegistry()
    registry.register(MockEngine())
    registry.register(FailingEngine())
    let coordinator = TranslationCoordinator(registry: registry)
    let outcomes = await coordinator.translateAll(
        TranslateRequest(text: "x", to: .zh)
    )
    #expect(outcomes.count == 2)
    let mock = outcomes.first { $0.providerId == "mock" }
    let failing = outcomes.first { $0.providerId == "failing" }
    #expect(mock?.isSuccess ?? false)
    #expect(failing?.error == .network)
}

@Test func coordinatorStreamsOutcomesInCompletionOrder() async {
    let registry = ProviderRegistry()
    registry.register(DelayedEngine(id: "slow", delayMs: 120))
    registry.register(DelayedEngine(id: "fast", delayMs: 10))
    let coordinator = TranslationCoordinator(registry: registry)

    let stream = await coordinator.translateIncrementally(
        TranslateRequest(text: "x", to: .zh)
    )
    var ids: [String] = []
    for await outcome in stream {
        ids.append(outcome.providerId)
    }

    #expect(ids == ["fast", "slow"])
}

@Test func languageDetection() {
    let detector = LanguageDetector()
    let lang = detector.detect("This is clearly an English sentence with enough words.")
    #expect(lang == .en)
}

@Test func directionResolverTargetsEnglishWhenInputAlreadyMatchesChineseTarget() {
    let resolver = TranslationDirectionResolver()
    let direction = resolver.resolve(text: "今天天气很好，我们去公园散步。", from: .auto, to: .zh)
    #expect(direction.from == .zh)
    #expect(direction.to == .en)
    #expect(direction.targetWasAdjusted)
}

@Test func coordinatorAvoidsSameLanguageTranslationWhenDetectedInputMatchesTarget() async {
    let registry = ProviderRegistry()
    registry.register(DirectionEchoEngine())
    let coordinator = TranslationCoordinator(registry: registry)

    let outcomes = await coordinator.translateAll(
        TranslateRequest(text: "今天天气很好，我们去公园散步。", to: .zh)
    )

    #expect(outcomes.first?.result?.translated == "zh->en")
}

@Test func openAIEngineNotConfiguredThrows() async {
    let engine = OpenAIEngine()
    await #expect(throws: ProviderError.notConfigured) {
        _ = try await engine.translate(TranslateRequest(text: "hi", to: .zh))
    }
}

@Test func coordinatorUsesLongerTimeoutForOpenCodeGo() {
    #expect(TranslationCoordinator.timeout(for: OpenCodeGoEngine(), base: 15) == 180)
    #expect(TranslationCoordinator.timeout(for: ZhipuEngine(), base: 15) == 90)
    #expect(TranslationCoordinator.timeout(for: OpenAIEngine(), base: 15) == 45)
}

/// Test double that always fails, to verify error isolation in the coordinator.
struct FailingEngine: TranslationProvider {
    let id = "failing"
    let displayName = "Failing"
    let supportedLanguages: [Language] = [.auto, .zh]
    let capabilities = ProviderCapabilities()
    func translate(_ req: TranslateRequest) async throws -> TranslateResult {
        throw ProviderError.network
    }
}

struct DelayedEngine: TranslationProvider {
    let id: String
    let delayMs: UInt64
    var displayName: String { id }
    var supportedLanguages: [Language] { [.auto, .zh] }
    var capabilities: ProviderCapabilities { ProviderCapabilities() }

    func translate(_ req: TranslateRequest) async throws -> TranslateResult {
        try await Task.sleep(nanoseconds: delayMs * 1_000_000)
        return TranslateResult(providerId: id, translated: id)
    }
}

struct DirectionEchoEngine: TranslationProvider {
    let id = "direction-echo"
    let displayName = "Direction Echo"
    var supportedLanguages: [Language] { [.auto, .zh, .en] }
    var capabilities: ProviderCapabilities { ProviderCapabilities() }

    func translate(_ req: TranslateRequest) async throws -> TranslateResult {
        let from = req.from.code ?? "auto"
        let to = req.to.code ?? "auto"
        return TranslateResult(providerId: id, translated: "\(from)->\(to)", detectedFrom: req.from)
    }
}
