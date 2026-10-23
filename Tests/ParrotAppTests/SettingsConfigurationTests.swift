import Foundation
import Testing
import ParrotCore
@testable import ParrotApp

@MainActor
struct SettingsConfigurationTests {
    @Test func repeatedSelectionRestoresOnlyMatchingUsefulTranslation() async throws {
        let fixture = makeFixture()
        let state = fixture.state
        state.registry.register(ConfigurationFixtureProvider())
        state.translate("A useful source sentence.")
        try await waitUntil { !state.isTranslating && state.savedRecordId != nil }

        #expect(state.canRestoreCapturedTranslation(text: "  A useful source sentence.\n"))
        #expect(!state.canRestoreCapturedTranslation(text: "Another sentence."))

        state.translate("A useful source sentence.", mode: .lookup)
        try await waitUntil { !state.isTranslating && state.savedRecordId != nil }
        #expect(!state.canRestoreCapturedTranslation(text: "A useful source sentence."))

        // Returning to the same selection must keep an unfinished edit, even if
        // the previously committed operation was a lookup or settings changed.
        state.updateDraft("An unfinished edit.")
        state.settings.ollamaEndpoint = "http://127.0.0.1:11435/v1/chat/completions"
        state.applySettings()
        #expect(state.sourceDraft == "An unfinished edit.")
        #expect(state.canRestoreCapturedTranslation(text: "A useful source sentence."))
    }

    @Test func fixingConfigurationMakesTheSameFailedSelectionTranslateAgain() async throws {
        let fixture = makeFixture()
        let state = fixture.state
        state.registry.register(ConfigurationFixtureProvider(failure: .notConfigured))
        state.translate("Retry this same source.")
        try await waitUntil { !state.isTranslating }
        #expect(!state.canRestoreCapturedTranslation(text: "Retry this same source."))
        #expect(state.outcomes.first?.error == .notConfigured)

        state.settings.setModelConfigs([EngineModelConfig(id: "primary", name: "repaired-model")], for: "ollama")
        state.applySettings()
        #expect(state.sourceDraft == "Retry this same source.")
        #expect(state.outcomes.first?.error == .notConfigured)
        #expect(state.workspaceNotice?.prominence == .compact)
        #expect(state.workspaceNotice?.primaryAction?.action == .retryTranslation)
        #expect(!state.canRestoreCapturedTranslation(text: "Retry this same source."))

        state.registry.register(ConfigurationFixtureProvider(modelName: "repaired-model", translated: "已修复的译文"))
        state.retryCurrentTranslation()
        try await waitUntil { !state.isTranslating && state.savedRecordId != nil }
        #expect(state.primaryActionTranslatedText == "已修复的译文")
        #expect(state.workspaceNotice == nil)
        #expect(state.canRestoreCapturedTranslation(text: "Retry this same source."))
    }

    @Test func endpointChangeCancelsOldWorkAndRejectsItsLateResult() async throws {
        let fixture = makeFixture()
        let state = fixture.state
        let gate = ConfigurationRequestGate()
        state.registry.register(ConfigurationFixtureProvider(gate: gate))
        state.translate("Keep the source while configuring.")
        try await waitUntil { await gate.started }
        #expect(state.canRestoreCapturedTranslation(text: "Keep the source while configuring."))

        state.updateDraft("Keep this unfinished edit too.")
        state.settings.ollamaEndpoint = "http://127.0.0.1:11435/v1/chat/completions"
        state.applySettings()
        #expect(!state.isTranslating)
        #expect(state.pendingProviders.isEmpty)
        #expect(state.sourceText == "Keep the source while configuring.")
        #expect(state.sourceDraft == "Keep this unfinished edit too.")
        #expect(state.workspaceNotice?.primaryAction?.action == .retryTranslation)

        await gate.release()
        try await waitUntil { await gate.returned }
        await Task.yield()
        #expect(state.outcomes.isEmpty)
        #expect(state.savedRecordId == nil)
    }

    @Test func pureOrderingAndUnrelatedServiceChangesKeepTheRunningRequest() async throws {
        let fixture = makeFixture()
        let state = fixture.state
        let gate = ConfigurationRequestGate()
        state.registry.register(ConfigurationFixtureProvider(gate: gate))
        state.translate("The running request should finish.")
        try await waitUntil { await gate.started }

        state.settings.setEngineOrder(["ollama", "opencode", "apple"])
        state.settings.amazonRegion = "eu-west-1" // Amazon is disabled.
        state.settings.ocrProviderId = "apple-vision"
        state.applySettings()
        #expect(state.isTranslating)
        #expect(state.workspaceNotice?.primaryAction?.action != .retryTranslation)
        #expect(state.canRestoreCapturedTranslation(text: "The running request should finish."))

        await gate.release()
        try await waitUntil { !state.isTranslating && state.savedRecordId != nil }
        #expect(state.primaryActionTranslatedText == "fixture result")
        #expect(state.canRestoreCapturedTranslation(text: "The running request should finish."))
    }

    @Test func configurationChangePreservesAlreadyArrivedResultsWhileCancelingTheRest() async throws {
        let fixture = makeFixture()
        let state = fixture.state
        let gate = ConfigurationRequestGate()
        state.settings.compareTranslations = true
        state.settings.setModelConfigs([
            EngineModelConfig(id: "primary", name: "fixture-model"),
            EngineModelConfig(id: "alternate", name: "slow-model")
        ], for: "ollama")
        state.applySettings()
        state.registry.register(ConfigurationFixtureProvider(translated: "已到达的结果"))
        state.registry.register(ConfigurationFixtureProvider(id: "ollama#alternate", modelName: "slow-model", gate: gate))
        state.translate("Keep the result that already arrived.")
        try await waitUntil { await gate.started && state.outcomes.count == 1 }

        state.settings.ollamaEndpoint = "http://127.0.0.1:11435/v1/chat/completions"
        state.applySettings()
        #expect(!state.isTranslating)
        #expect(state.outcomes.count == 1)
        #expect(state.outcomes.first?.result?.translated == "已到达的结果")
        #expect(state.workspaceNotice?.primaryAction?.action == .retryTranslation)
        #expect(!state.canRestoreCapturedTranslation(text: "Keep the result that already arrived."))
        #expect(!state.canCompareOtherEngines)

        await gate.release()
        try await waitUntil { await gate.returned }
        await Task.yield()
        #expect(state.outcomes.count == 1)
    }

    @Test func compareModeChangeInvalidatesAnInFlightPrimaryRequest() async throws {
        let fixture = makeFixture()
        let state = fixture.state
        let gate = ConfigurationRequestGate()
        state.registry.register(ConfigurationFixtureProvider(gate: gate))
        state.translate("Compare when requested.")
        try await waitUntil { await gate.started }

        state.settings.compareTranslations = true
        state.applySettings()
        #expect(!state.isTranslating)
        #expect(state.workspaceNotice?.primaryAction?.action == .retryTranslation)
        #expect(!state.canRestoreCapturedTranslation(text: "Compare when requested."))
        await gate.release()
    }

    @Test func reorderingDoesNotReplaceTheEffectiveDetectedTargetWithTheDefault() async throws {
        let fixture = makeFixture()
        let state = fixture.state
        state.registry.register(ConfigurationFixtureProvider())
        state.translate("今天阳光很好，我们去公园散步。")
        try await waitUntil { !state.isTranslating && state.savedRecordId != nil }
        #expect(state.settings.targetLanguageCode == "zh")
        #expect(state.targetLanguage == .en)

        state.settings.setEngineOrder(["ollama", "opencode", "apple"])
        state.applySettings()
        #expect(state.targetLanguage == .en)
        #expect(state.workspaceNotice?.primaryAction?.action != .retryTranslation)
        #expect(state.canRestoreCapturedTranslation(text: "今天阳光很好，我们去公园散步。"))
    }

    @Test func snapshotTracksOnlyCredentialsUsedByItsProvidersAndIgnoresOrder() {
        let fixture = makeFixture()
        let settings = fixture.state.settings
        let openAI = ConfigurationFixtureProvider(id: "openai", modelName: "configured-model")
        let ollama = ConfigurationFixtureProvider()
        let original = TranslationConfigurationSnapshot(settings: settings, providers: [openAI, ollama],
            credentialRevisions: [AppSettings.openAIAccount: 2])
        let reordered = TranslationConfigurationSnapshot(settings: settings, providers: [ollama, openAI],
            credentialRevisions: [AppSettings.openAIAccount: 2, AppSettings.tencentOCRKeyAccount: 99])
        #expect(original == reordered)

        let replacedKey = TranslationConfigurationSnapshot(settings: settings, providers: [openAI, ollama],
            credentialRevisions: [AppSettings.openAIAccount: 3])
        #expect(original != replacedKey)
        #expect(original.matchesResult(from: "ollama", in: replacedKey))
        #expect(!original.matchesResult(from: "openai", in: replacedKey))
    }

    @Test func retryingOneUpdatedModelKeepsTheOtherCurrentResultsAndClearsTheNotice() async throws {
        let fixture = makeFixture()
        let state = fixture.state
        state.settings.compareTranslations = true
        state.settings.setModelConfigs([
            EngineModelConfig(id: "primary", name: "fixture-model"),
            EngineModelConfig(id: "alternate", name: "old-alternate")
        ], for: "ollama")
        state.applySettings()
        state.registry.register(ConfigurationFixtureProvider(translated: "保留的主模型译文"))
        state.registry.register(ConfigurationFixtureProvider(id: "ollama#alternate", modelName: "old-alternate", translated: "旧备用译文"))
        state.translate("Keep the unaffected provider result.")
        try await waitUntil { !state.isTranslating && state.outcomes.count == 2 }

        state.settings.setModelConfigs([
            EngineModelConfig(id: "primary", name: "fixture-model"),
            EngineModelConfig(id: "alternate", name: "new-alternate")
        ], for: "ollama")
        state.applySettings()
        #expect(!state.canRestoreCapturedTranslation(text: "Keep the unaffected provider result."))
        #expect(state.outcomes.count == 2)
        state.registry.register(ConfigurationFixtureProvider(id: "ollama#alternate", modelName: "new-alternate", translated: "新的备用译文"))
        state.retryProvider("ollama#alternate")
        try await waitUntil { !state.isTranslating }

        #expect(state.outcomes.first(where: { $0.providerId == "ollama" })?.result?.translated == "保留的主模型译文")
        #expect(state.outcomes.first(where: { $0.providerId == "ollama#alternate" })?.result?.translated == "新的备用译文")
        #expect(state.workspaceNotice == nil)
        #expect(state.canRestoreCapturedTranslation(text: "Keep the unaffected provider result."))

        // A second change affects both models. Retrying just the alternate must
        // not certify the old primary result under the new primary model.
        state.settings.setModelConfigs([
            EngineModelConfig(id: "primary", name: "new-primary"),
            EngineModelConfig(id: "alternate", name: "third-alternate")
        ], for: "ollama")
        state.applySettings()
        state.registry.register(ConfigurationFixtureProvider(id: "ollama#alternate", modelName: "third-alternate", translated: "第三个备用译文"))
        state.retryProvider("ollama#alternate")
        try await waitUntil { !state.isTranslating }
        #expect(state.outcomes.first(where: { $0.providerId == "ollama" })?.result?.translated == "保留的主模型译文")
        #expect(state.workspaceNotice?.primaryAction?.action == .retryTranslation)
        #expect(!state.canRestoreCapturedTranslation(text: "Keep the unaffected provider result."))
    }

    @Test func credentialRecoveryMatchesTheExactServicesModelVariants() throws {
        let descriptor = try #require(CredentialCatalog.descriptor(matching: "ollama#alternate"))
        #expect(descriptor.id == "ollama")
        #expect(descriptor.matchesServiceID("ollama#alternate"))
        #expect(!descriptor.matchesServiceID("opencode#alternate"))
        let tencent = try #require(CredentialCatalog.descriptor(matching: "tencent-image-translate"))
        #expect(tencent.matchesServiceID("tencent-image-translate"))
        #expect(!tencent.matchesServiceID(nil))
    }

    private func makeFixture() -> ConfigurationStateFixture {
        ConfigurationStateFixture()
    }

    private func waitUntil(_ predicate: () async -> Bool) async throws {
        for _ in 0..<300 {
            if await predicate() { return }
            try await Task.sleep(nanoseconds: 5_000_000)
        }
        #expect(await predicate())
    }
}

@MainActor
private final class ConfigurationStateFixture {
    let state: AppState
    private let defaults: UserDefaults
    private let suite: String
    private let directory: URL

    init() {
        suite = "parrot.settings-configuration.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suite)!
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        for engine in EngineBootstrap.defaultOrder {
            defaults.set(false, forKey: "engine.\(engine).enabled")
        }
        let settings = AppSettings(defaults: defaults,
            terminologyStore: TerminologyStore(fileURL: directory.appendingPathComponent("terms.json")))
        settings.ollamaEnabled = true
        settings.setModelConfigs([EngineModelConfig(id: "primary", name: "fixture-model")], for: "ollama")
        state = AppState(settings: settings, history: HistoryStore(fileURL: directory.appendingPathComponent("history.json")))
    }

    deinit {
        defaults.removePersistentDomain(forName: suite)
        try? FileManager.default.removeItem(at: directory)
    }
}

private struct ConfigurationFixtureProvider: TranslationProvider {
    var id = "ollama"
    var modelName: String? = "fixture-model"
    var translated = "fixture result"
    var failure: ProviderError?
    var gate: ConfigurationRequestGate?
    var displayName: String { id }
    var supportedLanguages: [Language] { [.auto, .en, .zh] }
    var capabilities: ProviderCapabilities { ProviderCapabilities() }

    func translate(_ request: TranslateRequest) async throws -> TranslateResult {
        if let gate { await gate.wait() }
        if let failure { throw failure }
        return TranslateResult(providerId: id, translated: translated)
    }
}

private actor ConfigurationRequestGate {
    private(set) var started = false
    private(set) var returned = false
    private var continuation: CheckedContinuation<Void, Never>?

    func wait() async {
        started = true
        await withCheckedContinuation { continuation = $0 }
        returned = true
    }

    func release() {
        continuation?.resume()
        continuation = nil
    }
}
