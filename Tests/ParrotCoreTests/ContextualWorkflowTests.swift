import Testing
@testable import ParrotCore

@Test func contextDefaultProfileUsesModeOriginAndTerminology() {
    let lookup = TranslationContext.default(
        mode: .lookup,
        origin: .selection,
        text: "context",
        terminology: nil
    )
    #expect(lookup.profile == .quickTranslate)

    let longDocument = TranslationContext.default(
        mode: .translate,
        origin: .manualInput,
        text: String(repeating: "Long document sentence. ", count: 20),
        terminology: nil
    )
    #expect(longDocument.profile == .document)
    #expect(!longDocument.paragraphHints.isEmpty)

    let shortSelection = TranslationContext.default(
        mode: .translate,
        origin: .selection,
        text: "That's a bold choice.",
        terminology: nil
    )
    #expect(shortSelection.profile == .understand)
    #expect(shortSelection.routingHints.preferLLM)

    let terminology = TerminologySnapshot(entries: [
        TerminologyEntry(source: "AI Agent", target: "AI Agent", from: .en, to: .zh)
    ])
    let strict = TranslationContext.default(
        mode: .translate,
        origin: .manualInput,
        text: "AI Agent works.",
        terminology: terminology
    )
    #expect(strict.profile == .strictTerminology)

    let contextualTerminology = TranslationContext.default(
        mode: .translate,
        origin: .selection,
        text: "AI Agent is really moving the needle.",
        terminology: terminology
    )
    #expect(contextualTerminology.profile == .understand)
    #expect(contextualTerminology.routingHints.preferLLM)
}

@Test func privacyMaskerMasksAndRestoresSensitiveEntities() {
    let source = "Email alex.chen@example.com with sk-live-82a1b2c3d4e5f6 after build 123456789012 passes."
    let masked = PrivacyMasker.mask(source, policy: .maskSensitive)

    #expect(masked.report.applied)
    #expect(masked.report.entityCounts[.email] == 1)
    #expect(masked.report.entityCounts[.apiKey] == 1)
    #expect(masked.report.entityCounts[.numericID] == 1)
    #expect(!masked.text.contains("alex.chen@example.com"))
    #expect(!masked.text.contains("sk-live"))

    let restored = PrivacyMasker.unmask(masked.text, using: masked)
    #expect(restored == source)
}

@Test func coordinatorMasksProviderRequestAndRestoresResult() async {
    let recorder = ContextRequestRecorder()
    let registry = ProviderRegistry()
    registry.register(PrivacyEchoEngine(recorder: recorder))
    let coordinator = TranslationCoordinator(registry: registry)
    let context = TranslationContext(
        profile: .email,
        origin: .manualInput,
        privacyPolicy: .maskSensitive
    )

    let outcomes = await coordinator.translateAll(
        TranslateRequest(
            text: "Contact alex.chen@example.com with sk-live-82a1b2c3d4e5f6.",
            from: .en,
            to: .zh,
            context: context
        )
    )

    let providerRequest = await recorder.request
    #expect(providerRequest?.text.contains("PARROTMASK_EMAIL") == true)
    #expect(providerRequest?.text.contains("PARROTMASK_APIKEY") == true)
    #expect(outcomes.first?.result?.translated.contains("alex.chen@example.com") == true)
    #expect(outcomes.first?.result?.translated.contains("sk-live-82a1b2c3d4e5f6") == true)
    #expect(outcomes.first?.result?.privacyMaskingReport?.totalCount == 2)
}

@Test func qualityEvaluatorFlagsPlaceholderLeaksAndWrongLanguage() {
    let req = TranslateRequest(text: "Please translate this sentence.", from: .en, to: .zh)
    let result = TranslateResult(providerId: "bad", translated: "PARROTMASK_EMAIL_0001")
    let quality = ResultQualityEvaluator.evaluate(result: result, request: req)

    #expect(quality.issues.contains(.placeholderLeak))
    #expect(quality.issues.contains(.wrongLanguage))
    #expect(quality.needsReview)
}

@Test func coordinatorMarksBestPassingResultAsRecommended() async {
    let registry = ProviderRegistry()
    registry.register(FixedResultEngine(id: "bad", translated: "same source"))
    registry.register(FixedResultEngine(id: "good", translated: "这是可用的译文。"))
    let coordinator = TranslationCoordinator(registry: registry)

    let outcomes = await coordinator.translateAll(
        TranslateRequest(text: "same source", from: .en, to: .zh)
    )

    #expect(outcomes.first { $0.providerId == "bad" }?.result?.qualitySummary?.issues.contains(.unchangedSource) == true)
    #expect(outcomes.first { $0.providerId == "bad" }?.result?.qualitySummary?.isRecommended == false)
    #expect(outcomes.first { $0.providerId == "good" }?.result?.qualitySummary?.isRecommended == true)
}

@Test func paragraphSegmenterPreservesCodeFenceAsProtectedHint() {
    let hints = ParagraphSegmenter.segment("""
    Intro paragraph.

    ```swift
    let value = "Do not translate"
    ```
    """)

    #expect(hints.count == 2)
    #expect(hints[1].isProtected)
}

private actor ContextRequestRecorder {
    var request: TranslateRequest?
    func record(_ req: TranslateRequest) {
        request = req
    }
}

private struct PrivacyEchoEngine: TranslationProvider {
    let recorder: ContextRequestRecorder
    let id = "privacy-echo"
    let displayName = "Privacy Echo"
    let supportedLanguages: [Language] = [.auto, .en, .zh]
    let capabilities = ProviderCapabilities()

    func translate(_ req: TranslateRequest) async throws -> TranslateResult {
        await recorder.record(req)
        return TranslateResult(providerId: id, translated: req.text)
    }
}

private struct FixedResultEngine: TranslationProvider {
    let id: String
    let translated: String
    var displayName: String { id }
    let supportedLanguages: [Language] = [.auto, .en, .zh]
    let capabilities = ProviderCapabilities()

    func translate(_ req: TranslateRequest) async throws -> TranslateResult {
        TranslateResult(providerId: id, translated: translated)
    }
}
