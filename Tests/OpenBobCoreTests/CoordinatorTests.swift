import Testing
@testable import OpenBobCore
@testable import OpenBobEngines

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

@Test func languageDetection() {
    let detector = LanguageDetector()
    let lang = detector.detect("This is clearly an English sentence with enough words.")
    #expect(lang == .en)
}

@Test func openAIEngineNotConfiguredThrows() async {
    let engine = OpenAIEngine()
    await #expect(throws: ProviderError.notConfigured) {
        _ = try await engine.translate(TranslateRequest(text: "hi", to: .zh))
    }
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
