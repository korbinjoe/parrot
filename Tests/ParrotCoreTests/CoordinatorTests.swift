import Testing
import Foundation
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

@Test func coordinatorIncludesProviderModelName() async {
    let registry = ProviderRegistry()
    registry.register(ModelEngine())
    let coordinator = TranslationCoordinator(registry: registry)
    let outcomes = await coordinator.translateAll(
        TranslateRequest(text: "world", to: .zh)
    )
    #expect(outcomes.first?.displayName == "Model Engine")
    #expect(outcomes.first?.modelName == "test-model")
}

@Test(arguments: [false, true])
func coordinatorPreservesSessionThroughLanguageResolutionAndProtectedDispatch(protectsContent: Bool) async {
    let calls = SessionRequestCalls()
    let registry = ProviderRegistry()
    registry.register(SessionEchoEngine(calls: calls))
    let coordinator = TranslationCoordinator(registry: registry)
    let source = "An AI Agent will email me at person@example.com tomorrow."
    let terminology = protectsContent ? TerminologySnapshot(entries: [
        TerminologyEntry(source: "AI Agent", target: "AI Agent", from: .en, to: .zh)
    ]) : nil
    let request = TranslateRequest(
        text: source, from: .auto, to: .zh, terminology: terminology,
        context: TranslationContext(
            profile: .quickTranslate,
            privacyPolicy: protectsContent ? .maskSensitive : .standard
        )
    )

    let outcomes = await coordinator.translateAll(request)
    let stream = await coordinator.translateIncrementally(request, strategy: .firstSuccessful)
    var streamed: [AggregatedOutcome] = []
    for await outcome in stream { streamed.append(outcome) }

    let requests = await calls.requests
    #expect(requests.count == 2)
    for sent in requests {
        #expect(sent.sessionID == request.sessionID)
        #expect(sent.from == .en)
        #expect(sent.to == .zh)
        if protectsContent {
            #expect(sent.text.contains("PARROTTERM0001"))
            #expect(sent.text.contains("PARROTMASK_EMAIL"))
            #expect(!sent.text.contains("AI Agent"))
            #expect(!sent.text.contains("person@example.com"))
        } else {
            #expect(sent.text == source)
        }
    }
    #expect(outcomes.first?.result?.translated == source)
    #expect(streamed.first?.result?.translated == source)
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

@Test func polishModeUsesAllActiveProviders() async {
    let registry = ProviderRegistry()
    registry.register(DelayedEngine(id: "translate-only", delayMs: 0))
    registry.register(MockEngine())
    let coordinator = TranslationCoordinator(registry: registry)
    let outcomes = await coordinator.translateAll(
        TranslateRequest(text: "rough draft", to: .en, mode: .polish)
    )

    #expect(outcomes.map(\.providerId) == ["translate-only", "mock"])
    #expect(outcomes.allSatisfy { $0.isSuccess })
}

@Test func polishModePreservesDetectedSourceLanguage() async {
    let registry = ProviderRegistry()
    registry.register(DirectionEchoEngine())
    let coordinator = TranslationCoordinator(registry: registry)

    let outcomes = await coordinator.translateAll(
        TranslateRequest(
            text: "This draft needs clearer wording before I send it.",
            from: .auto,
            to: .zh,
            mode: .polish
        )
    )

    #expect(outcomes.first?.result?.translated == "en->en")
}

@Test func registryExposesDisplayOrderIDsForCachedRendering() {
    let registry = ProviderRegistry()
    registry.register(DelayedEngine(id: "a", delayMs: 0))
    registry.register(DelayedEngine(id: "b", delayMs: 0))
    registry.register(DelayedEngine(id: "disabled", delayMs: 0), enabled: false)
    registry.setOrder(["b", "a", "disabled"])
    registry.register(DelayedEngine(id: "plugin", delayMs: 0))

    #expect(registry.providerIDsInDisplayOrder() == ["b", "a", "plugin"])
    #expect(registry.providerIDsInDisplayOrder(includeDisabled: true) == ["b", "a", "disabled", "plugin"])
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

@Test func singleResultUsesOnlyConfiguredPrimary() async {
    let calls = ProviderCalls()
    let registry = ProviderRegistry()
    registry.register(TrackedEngine(id: "primary", calls: calls))
    registry.register(TrackedEngine(id: "unused-backup", calls: calls))
    let coordinator = TranslationCoordinator(registry: registry)
    let stream = await coordinator.translateIncrementally(
        TranslateRequest(text: "hello", to: .zh), strategy: .firstSuccessful
    )
    var outcomes: [AggregatedOutcome] = []
    for await outcome in stream { outcomes.append(outcome) }

    #expect(await calls.ids == ["primary"])
    #expect(outcomes.map(\.providerId) == ["primary"])
    #expect(outcomes.first?.isSuccess == true)
}

@Test func singleResultTriesOneBackupAfterFailure() async {
    let calls = ProviderCalls()
    let registry = ProviderRegistry()
    registry.register(TrackedEngine(id: "primary", calls: calls, fails: true))
    registry.register(TrackedEngine(id: "backup", calls: calls))
    registry.register(TrackedEngine(id: "unused", calls: calls))
    let coordinator = TranslationCoordinator(registry: registry)
    let stream = await coordinator.translateIncrementally(
        TranslateRequest(text: "hello", to: .zh), strategy: .firstSuccessful
    )
    var outcomes: [AggregatedOutcome] = []
    for await outcome in stream { outcomes.append(outcome) }

    #expect(await calls.ids == ["primary", "backup"])
    #expect(outcomes.first?.error == .network)
    #expect(outcomes.last?.isSuccess == true)
}

@Test func singleResultBoundsAutomaticFallbackWork() async {
    let calls = ProviderCalls()
    let registry = ProviderRegistry()
    for id in ["primary", "backup", "unused"] {
        registry.register(TrackedEngine(id: id, calls: calls, fails: true))
    }
    let coordinator = TranslationCoordinator(registry: registry)
    let stream = await coordinator.translateIncrementally(
        TranslateRequest(text: "hello", to: .zh), strategy: .firstSuccessful
    )
    for await _ in stream {}

    #expect(await calls.ids == ["primary", "backup"])
}

@Test func unsupportedBackupDoesNotHideLaterUsableProvider() async {
    let calls = ProviderCalls()
    let registry = ProviderRegistry()
    registry.register(TrackedEngine(id: "primary", calls: calls, fails: true))
    registry.register(TrackedEngine(id: "unsupported", calls: calls, failure: .unsupportedLanguage))
    registry.register(TrackedEngine(id: "usable", calls: calls))
    registry.register(TrackedEngine(id: "unused", calls: calls))
    let coordinator = TranslationCoordinator(registry: registry)
    let stream = await coordinator.translateIncrementally(
        TranslateRequest(text: "tide", to: .zh), strategy: .firstSuccessful
    )
    var outcomes: [AggregatedOutcome] = []
    for await outcome in stream { outcomes.append(outcome) }

    #expect(await calls.ids == ["primary", "unsupported", "usable"])
    #expect(outcomes.last?.providerId == "usable")
    #expect(outcomes.last?.isSuccess == true)
}

@Test func unconfiguredProvidersDoNotConsumeOperationalAttemptBudget() async {
    let calls = ProviderCalls()
    let registry = ProviderRegistry()
    registry.register(TrackedEngine(id: "unconfigured", calls: calls, failure: .notConfigured))
    registry.register(TrackedEngine(id: "first-failure", calls: calls, fails: true))
    registry.register(TrackedEngine(id: "second-failure", calls: calls, fails: true))
    registry.register(TrackedEngine(id: "unused", calls: calls))
    let coordinator = TranslationCoordinator(registry: registry)
    let stream = await coordinator.translateIncrementally(
        TranslateRequest(text: "tide", to: .zh), strategy: .firstSuccessful
    )
    for await _ in stream {}

    #expect(await calls.ids == ["unconfigured", "first-failure", "second-failure"])
}

@Test func singleResultLookupPrefersDictionaryBeforePlainTranslation() async {
    let calls = ProviderCalls()
    let registry = ProviderRegistry()
    registry.register(TrackedEngine(id: "plain", calls: calls))
    registry.register(TrackedEngine(id: "dictionary", calls: calls, supportsLookup: true))
    registry.register(TrackedEngine(id: "second-dictionary", calls: calls, supportsLookup: true))
    let coordinator = TranslationCoordinator(registry: registry)
    let request = TranslateRequest(text: "tide", to: .zh, mode: .lookup)
    let stream = await coordinator.translateIncrementally(request, strategy: .firstSuccessful)
    var outcomes: [AggregatedOutcome] = []
    for await outcome in stream { outcomes.append(outcome) }

    #expect(await calls.ids == ["dictionary"])
    #expect(outcomes.first?.result?.definitions?.isEmpty == false)
    #expect(coordinator.plannedProviders(for: request, strategy: .comparison).map(\.id)
            == ["plain", "dictionary", "second-dictionary"])
}

@Test func lookupFallsBackToPlainTranslationAfterDictionaryFailure() async {
    let calls = ProviderCalls()
    let registry = ProviderRegistry()
    registry.register(TrackedEngine(id: "plain", calls: calls))
    registry.register(TrackedEngine(id: "dictionary", calls: calls, fails: true, supportsLookup: true))
    let coordinator = TranslationCoordinator(registry: registry)
    let stream = await coordinator.translateIncrementally(
        TranslateRequest(text: "tide", to: .zh, mode: .lookup), strategy: .firstSuccessful
    )
    var outcomes: [AggregatedOutcome] = []
    for await outcome in stream { outcomes.append(outcome) }

    #expect(await calls.ids == ["dictionary", "plain"])
    #expect(outcomes.last?.providerId == "plain")
    #expect(outcomes.last?.isSuccess == true)
}

@Test func lookupPreferencePreservesExplicitProviderRouting() async {
    let calls = ProviderCalls()
    let registry = ProviderRegistry()
    registry.register(TrackedEngine(id: "plain", calls: calls))
    registry.register(TrackedEngine(id: "dictionary", calls: calls, supportsLookup: true))
    let coordinator = TranslationCoordinator(registry: registry)
    let preferred = TranslateRequest(text: "tide", to: .zh, mode: .lookup,
        context: TranslationContext(profile: .quickTranslate,
            routingHints: ProviderRoutingHints(preferredProviderIDs: ["plain"])))
    #expect(coordinator.plannedProviders(for: preferred, strategy: .firstSuccessful).map(\.id)
            == ["plain", "dictionary"])
    let privateRequest = preferred.withContext(TranslationContext(profile: .privateLocal,
        routingHints: ProviderRoutingHints(allowedProviderIDs: ["plain"])))
    let stream = await coordinator.translateIncrementally(privateRequest, strategy: .firstSuccessful)
    for await _ in stream {}
    #expect(await calls.ids == ["plain"])
}

@Test func singleResultRejectsBlankResponseAndUsesBackup() async {
    let calls = ProviderCalls()
    let registry = ProviderRegistry()
    registry.register(TrackedEngine(id: "blank", calls: calls, translated: " \n "))
    registry.register(TrackedEngine(id: "backup", calls: calls))
    let coordinator = TranslationCoordinator(registry: registry)
    let stream = await coordinator.translateIncrementally(
        TranslateRequest(text: "hello", to: .zh), strategy: .firstSuccessful
    )
    var outcomes: [AggregatedOutcome] = []
    for await outcome in stream { outcomes.append(outcome) }

    #expect(await calls.ids == ["blank", "backup"])
    #expect(outcomes.first?.isSuccess == false)
    #expect(outcomes.last?.providerId == "backup")
    #expect(outcomes.last?.isSuccess == true)
}

@Test func cancelledSingleResultDoesNotStartBackupOrPublishAnError() async throws {
    let calls = ProviderCalls()
    let registry = ProviderRegistry()
    registry.register(TrackedEngine(id: "primary", calls: calls, delayMs: 5_000))
    registry.register(TrackedEngine(id: "unused-backup", calls: calls))
    let coordinator = TranslationCoordinator(registry: registry)
    let task = Task {
        let stream = await coordinator.translateIncrementally(
            TranslateRequest(text: "hello", to: .zh), strategy: .firstSuccessful
        )
        var outcomes: [AggregatedOutcome] = []
        for await outcome in stream { outcomes.append(outcome) }
        return outcomes
    }
    for _ in 0..<100 {
        if await !calls.ids.isEmpty { break }
        try await Task.sleep(nanoseconds: 5_000_000)
    }
    #expect(await calls.ids == ["primary"])
    task.cancel()
    #expect(await task.value.isEmpty)
    #expect(await calls.ids == ["primary"])
}

@Test func shortLatinWordKeepsAutomaticSourceLanguage() {
    let resolver = TranslationDirectionResolver()
    for word in ["tide", "chat", "gift"] {
        let direction = resolver.resolve(text: word, from: .auto, to: .zh)
        #expect(direction.from == .auto)
        #expect(direction.detected == .auto)
        #expect(direction.to == .zh)
    }
    let explicit = resolver.resolve(text: "tide", from: .en, to: .zh)
    #expect(explicit.from == .en)
    let englishTarget = resolver.resolve(text: "hello", from: .auto, to: .en)
    #expect(englishTarget.from == .en)
    #expect(englishTarget.to == .zh)
    #expect(englishTarget.targetWasAdjusted)
    let polish = resolver.resolvePolish(text: "tide", from: .auto)
    #expect(polish.from == .en)
    #expect(polish.to == .en)
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

@Test func directionResolverPreservesExplicitSourceEvenWhenDetectionMatchesTarget() {
    let resolver = TranslationDirectionResolver()
    let direction = resolver.resolve(
        text: "今天天气很好，我们去公园散步。", from: .en, to: .zh
    )

    #expect(direction.from == .en)
    #expect(direction.to == .zh)
    #expect(direction.detected == .zh)
    #expect(!direction.targetWasAdjusted)
}

@Test func directionResolverPreservesAnExplicitlySelectedAutomaticTarget() {
    let resolver = TranslationDirectionResolver()
    let direction = resolver.resolve(
        text: "今天天气很好，我们去公园散步。", from: .auto, to: .zh,
        allowTargetAdjustment: false
    )

    #expect(direction.from == .zh)
    #expect(direction.to == .zh)
    #expect(!direction.targetWasAdjusted)
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
    #expect(TranslationCoordinator.timeout(for: AppleTimeoutFixtureEngine(), base: 15) == 300)
}

private struct AppleTimeoutFixtureEngine: TranslationProvider {
    let id = "apple"
    let displayName = "System Translation"
    let supportedLanguages: [Language] = [.auto, .zh, .en]
    let capabilities = ProviderCapabilities()

    func translate(_ req: TranslateRequest) async throws -> TranslateResult {
        TranslateResult(providerId: id, translated: req.text)
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

struct ModelEngine: TranslationProvider {
    let id = "model-engine"
    let displayName = "Model Engine"
    let modelName: String? = "test-model"
    var supportedLanguages: [Language] { [.auto, .zh] }
    var capabilities: ProviderCapabilities { ProviderCapabilities() }

    func translate(_ req: TranslateRequest) async throws -> TranslateResult {
        TranslateResult(providerId: id, translated: "ok")
    }
}

private actor ProviderCalls {
    var ids: [String] = []
    func record(_ id: String) { ids.append(id) }
}

private actor SessionRequestCalls {
    var requests: [TranslateRequest] = []
    func record(_ request: TranslateRequest) { requests.append(request) }
}

private struct SessionEchoEngine: TranslationProvider {
    let calls: SessionRequestCalls
    let id = "session-echo"
    let displayName = "Session Echo"
    let supportedLanguages: [Language] = [.auto, .en, .zh]
    let capabilities = ProviderCapabilities(terminology: .placeholder)

    func translate(_ req: TranslateRequest) async throws -> TranslateResult {
        await calls.record(req)
        return TranslateResult(providerId: id, translated: req.text)
    }
}

private struct TrackedEngine: TranslationProvider {
    let id: String
    let calls: ProviderCalls
    var fails = false
    var delayMs: UInt64 = 0
    var translated = "translated"
    var failure: ProviderError?
    var supportsLookup = false
    var displayName: String { id }
    var supportedLanguages: [Language] { [.auto, .zh, .en] }
    var capabilities: ProviderCapabilities { ProviderCapabilities(supportsLookup: supportsLookup) }

    func translate(_ req: TranslateRequest) async throws -> TranslateResult {
        await calls.record(id)
        if delayMs > 0 { try await Task.sleep(nanoseconds: delayMs * 1_000_000) }
        if let failure { throw failure }
        if fails { throw ProviderError.network }
        return TranslateResult(
            providerId: id, translated: translated,
            definitions: supportsLookup ? [Definition(partOfSpeech: "n.", meanings: ["definition"])] : nil
        )
    }
}
