import Foundation
import Testing
@testable import ParrotCore
@testable import ParrotEngines
@testable import ParrotPlugins

@Test func terminologyMatcherPrefersLongestEnabledMatch() {
    let snapshot = TerminologySnapshot(entries: [
        TerminologyEntry(source: "Agent", target: "智能体", from: .en, to: .zh),
        TerminologyEntry(source: "AI Agent", target: "AI Agent", from: .en, to: .zh),
        TerminologyEntry(source: "Agent", target: "Agent", from: .en, to: .ja)
    ])

    let matches = TerminologyMatcher.matches(
        in: "An AI Agent should preserve intent.",
        snapshot: snapshot,
        from: .en,
        to: .zh,
        mode: .translate
    )

    #expect(matches.map(\.source) == ["AI Agent"])
    #expect(matches.first?.target == "AI Agent")
}

@Test func terminologyMatcherHonorsCaseSensitivityAndLanguagePair() {
    let snapshot = TerminologySnapshot(entries: [
        TerminologyEntry(source: "LLM", target: "LLM", from: .en, to: .zh, caseSensitive: true),
        TerminologyEntry(source: "prompt", target: "提示词", from: .en, to: .zh)
    ])

    let lower = TerminologyMatcher.matches(
        in: "llm prompt",
        snapshot: snapshot,
        from: .en,
        to: .zh,
        mode: .translate
    )
    let upper = TerminologyMatcher.matches(
        in: "LLM prompt",
        snapshot: snapshot,
        from: .en,
        to: .zh,
        mode: .translate
    )
    let wrongTarget = TerminologyMatcher.matches(
        in: "LLM prompt",
        snapshot: snapshot,
        from: .en,
        to: .ja,
        mode: .translate
    )

    #expect(lower.map(\.source) == ["prompt"])
    #expect(upper.map(\.source) == ["LLM", "prompt"])
    #expect(wrongTarget.isEmpty)
}

@Test func terminologyStorePersistsEntriesAndRejectsInvalidRows() throws {
    let url = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent("parrot-terminology-\(UUID().uuidString).json")
    defer { try? FileManager.default.removeItem(at: url) }

    let store = TerminologyStore(fileURL: url)
    try store.upsert(TerminologyEntry(source: "AI Agent", target: "AI Agent", from: .en, to: .zh))

    let restored = TerminologyStore(fileURL: url)
    #expect(restored.loadState().entries.first?.source == "AI Agent")
    #expect(throws: TerminologyStoreError.emptySourceOrTarget) {
        try restored.upsert(TerminologyEntry(source: " ", target: "AI Agent", from: .en, to: .zh))
    }
}

@Test func terminologyProcessorProtectsAndRestoresMatchedTerms() {
    let snapshot = TerminologySnapshot(entries: [
        TerminologyEntry(source: "AI Agent", target: "AI Agent", from: .en, to: .zh)
    ])
    let req = TranslateRequest(
        text: "AI Agent should preserve intent.",
        from: .en,
        to: .zh,
        terminology: snapshot
    )

    let protected = TerminologyProcessor.protect(req)
    let restored = TerminologyProcessor.restore("PARROTTERM0001 应保留意图。", using: protected)

    #expect(protected.text == "PARROTTERM0001 should preserve intent.")
    #expect(restored.text == "AI Agent 应保留意图。")
    #expect(restored.succeeded)
}

@Test func coordinatorUsesSameTerminologySnapshotForAllProvidersAndRestoresPlaceholders() async {
    let registry = ProviderRegistry()
    let first = RequestRecorder()
    let second = RequestRecorder()
    registry.register(RecordingTerminologyEngine(id: "first", recorder: first))
    registry.register(RecordingTerminologyEngine(id: "second", recorder: second))

    let snapshot = TerminologySnapshot(entries: [
        TerminologyEntry(source: "AI Agent", target: "AI Agent", from: .en, to: .zh)
    ])
    let coordinator = TranslationCoordinator(registry: registry)
    let outcomes = await coordinator.translateAll(
        TranslateRequest(text: "AI Agent works.", from: .en, to: .zh, terminology: snapshot)
    )

    let firstRequest = await first.request
    let secondRequest = await second.request
    #expect(firstRequest?.terminology?.createdAt == snapshot.createdAt)
    #expect(secondRequest?.terminology?.createdAt == snapshot.createdAt)
    #expect(firstRequest?.text == "PARROTTERM0001 works.")
    #expect(secondRequest?.text == "PARROTTERM0001 works.")
    #expect(outcomes.allSatisfy { $0.result?.translated.contains("AI Agent") == true })
    #expect(outcomes.allSatisfy { $0.result?.terminologyApplication?.matchCount == 1 })
}

@Test func coordinatorProtectsPreservationTermsForPromptOnlyProviders() async {
    let recorder = RequestRecorder()
    let provider = PromptOnlyTerminologyEngine(recorder: recorder)
    let snapshot = TerminologySnapshot(entries: [
        TerminologyEntry(source: "Agent", target: "Agent", from: .en, to: .zh)
    ])

    let outcome = await TranslationCoordinator.runProvider(
        provider,
        req: TranslateRequest(text: "An Agent should preserve intent.", from: .en, to: .zh, terminology: snapshot),
        baseTimeout: 2
    )

    let providerRequest = await recorder.request
    #expect(providerRequest?.text == "An PARROTTERM0001 should preserve intent.")
    #expect(outcome.result?.translated == "An Agent should preserve intent. translated")
    #expect(outcome.result?.terminologyApplication?.strategy == .promptAndPlaceholder)
    #expect(outcome.result?.terminologyApplication?.restorationSucceeded == true)
}

@Test func openAICompatPromptIncludesTerminologyConstraints() {
    let snapshot = TerminologySnapshot(entries: [
        TerminologyEntry(source: "AI Agent", target: "AI Agent", from: .en, to: .zh)
    ])
    let req = TranslateRequest(text: "AI Agent works.", from: .en, to: .zh, terminology: snapshot)
    let prompt = OpenAICompatEngine.systemPrompt(for: req)

    #expect(prompt.contains("Terminology constraints"))
    #expect(prompt.contains("AI Agent => AI Agent"))
}

@Test func pluginProviderPassesTerminologyToTerminologyAwarePlugin() async throws {
    let manifest = try PluginManifest.parse(Data("""
    { "identifier":"term","name":"Term","version":"1.0.0",
      "capabilities":["translate"], "supportsTerminology": true,
      "permissions":{"network":[]} }
    """.utf8))
    let script = """
    function translate(q, c){
      c({ result: { translated: q.terminology[0].source + "=>" + q.terminology[0].target } });
    }
    """
    let runtime = try PluginRuntime(script: script, allowedHosts: [], options: [:])
    let provider = PluginProvider(manifest: manifest, runtime: runtime)
    let snapshot = TerminologySnapshot(entries: [
        TerminologyEntry(source: "AI Agent", target: "AI Agent", from: .en, to: .zh)
    ])

    let result = try await provider.translate(
        TranslateRequest(text: "AI Agent", from: .en, to: .zh, terminology: snapshot)
    )

    #expect(result.translated == "AI Agent=>AI Agent")
}

@Test func terminologyCSVImportExportRoundTripsAndPlansOverwrite() throws {
    let existing = TerminologyEntry(source: "AI Agent", target: "AI Agent", from: .en, to: .zh)
    let csv = """
    source,target,from,to,caseSensitive,note,enabled
    AI Agent,AI Agent,en,zh,true,AI,true
    LLM,LLM,en,zh,true,Models,true
    """
    let decoded = try TerminologyCSV.decode(csv)
    let plan = TerminologyCSV.planImport(decoded: decoded, existing: [existing])
    let encoded = TerminologyCSV.encode(decoded)

    #expect(plan.addedCount == 1)
    #expect(plan.overwrittenCount == 1)
    #expect(encoded.contains("AI Agent"))
    #expect(encoded.contains("LLM"))
}

private actor RequestRecorder {
    var request: TranslateRequest?
    func record(_ req: TranslateRequest) {
        request = req
    }
}

private struct RecordingTerminologyEngine: TranslationProvider {
    let id: String
    let recorder: RequestRecorder
    var displayName: String { id }
    var supportedLanguages: [Language] { [.auto, .en, .zh] }
    var capabilities: ProviderCapabilities { ProviderCapabilities(terminology: .placeholder) }

    func translate(_ req: TranslateRequest) async throws -> TranslateResult {
        await recorder.record(req)
        return TranslateResult(providerId: id, translated: "\(req.text) translated")
    }
}

private struct PromptOnlyTerminologyEngine: TranslationProvider {
    let recorder: RequestRecorder
    let id = "prompt-only"
    let displayName = "Prompt Only"
    let supportedLanguages: [Language] = [.auto, .en, .zh]
    let capabilities = ProviderCapabilities(terminology: .prompt)

    func translate(_ req: TranslateRequest) async throws -> TranslateResult {
        await recorder.record(req)
        return TranslateResult(providerId: id, translated: "\(req.text) translated")
    }
}
