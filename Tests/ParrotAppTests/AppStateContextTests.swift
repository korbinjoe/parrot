import Testing
import Foundation
import CoreGraphics
import AppKit
import ParrotCore
@testable import ParrotApp

@MainActor
@Test func sourceMetadataRulesSelectDeveloperProfile() {
    let state = makeContextTestState()
    state.settings.advancedFeaturesEnabled = true
    state.settings.contextRuleDeveloperEnabled = true

    state.openWorkspace(
        text: "Review this pull request note.",
        autoRun: false,
        focusComposer: false,
        origin: .selection,
        sourceURL: "https://github.com/example/parrot/pull/42"
    )

    #expect(state.contextProfile == .github)
    #expect(state.currentContextSourceURL == "https://github.com/example/parrot/pull/42")
}

@MainActor
@Test func shortBrowserSelectionUsesUnderstandProfile() {
    let state = makeContextTestState()
    state.settings.advancedFeaturesEnabled = true
    state.settings.contextRuleDocumentEnabled = true

    state.openWorkspace(
        text: "That's a bold choice.",
        autoRun: false,
        focusComposer: false,
        origin: .selection,
        sourceApp: "Safari",
        windowTitle: "A conversation"
    )

    #expect(state.contextProfile == .understand)
}

@MainActor
@Test func mvpCapturesUseQuickTranslationWithoutImplicitProfiles() {
    let state = makeContextTestState()
    for origin in [TranslationOrigin.selection, .clipboard, .screenshot, .history, .url] {
        state.openWorkspace(
            text: "Review this pull request note.", autoRun: false, focusComposer: false,
            origin: origin, sourceApp: "GitHub", sourceURL: "https://github.com/example/parrot"
        )
        #expect(state.contextProfile == .quickTranslate)
    }
    state.openWorkspace(text: "An ambiguous comment.", autoRun: false, focusComposer: false,
                        origin: .selection, profile: .understand)
    #expect(state.contextProfile == .understand)
    #expect(state.learningHistoryRecords.isEmpty)
    #expect(state.learningOccurrenceCounts.isEmpty)
}

@MainActor
@Test func emptySelectionCaptureKeepsDraftResultsAndLabelsPreviouslyShownContent() {
    let state = makeContextTestState()
    let existing = TranslationRecord(
        sourceText: "Previously translated text.", translated: "先前的译文", providerId: "saved",
        sourceLang: "en", targetLang: "zh", isFavorite: true
    )
    state.openHistoryWorkspace(existing)
    state.updateDraft("An unfinished edit.")

    state.showSelectionCaptureNotice(openInput: false)

    #expect(state.sourceDraft == "An unfinished edit.")
    #expect(state.sourceText == existing.sourceText)
    #expect(state.outcomes.first?.result?.translated == existing.translated)
    #expect(state.savedRecordId == existing.id)
    #expect(state.isFavorite)
    #expect(state.workspaceNotice?.title == L("未获取到选中文字"))
    #expect(state.workspaceNotice?.detail == L("本次没有获取到新选文，下方仍是原有内容。请在其他应用选中文字后重试，或直接在这里输入。"))
    #expect(!state.isTranslating)
}

@MainActor
@Test func translatingEditedTextClearsThePreviousCaptureFailureNotice() async throws {
    let state = makeContextTestState()
    state.registry.removeAll()
    state.registry.register(AppMVPFixtureEngine(id: "primary", calls: AppProviderCalls()))
    state.openWorkspace(text: "Old source.", autoRun: false, focusComposer: false, origin: .selection)
    state.showSelectionCaptureNotice(openInput: false)

    state.translate("   ")
    #expect(state.workspaceNotice != nil)

    state.updateDraft("A new source.")
    state.translateDraft()
    try await waitForMVPTranslation(state)

    #expect(state.workspaceNotice == nil)
    #expect(state.sourceText == "A new source.")
    #expect(state.primaryActionTranslatedText == "quickTranslate:A new source.")
}

@MainActor
@Test func captureWithoutExternalSourceOpensInputWithoutDiscardingExistingWork() {
    let state = makeContextTestState()
    state.openWorkspace(text: "Keep this draft.", autoRun: false, focusComposer: false, origin: .selection)
    let previousFocusRequest = state.composerFocusRequest

    state.showSelectionCaptureNotice(openInput: true)

    #expect(state.currentOrigin == .selection)
    #expect(state.sourceDraft == "Keep this draft.")
    #expect(state.composerFocusRequest > previousFocusRequest)
    #expect(state.workspaceNotice != nil)
    #expect(!state.isTranslating)
}

@MainActor
@Test func captureWithoutExternalSourceStartsManualInputForAnEmptyWorkspace() {
    let state = makeContextTestState()

    state.showSelectionCaptureNotice(openInput: true)

    #expect(state.currentOrigin == .manualInput)
    #expect(state.sourceDraft.isEmpty)
    #expect(state.composerFocusRequest > 0)
    #expect(state.workspaceNotice?.detail == L("请先在其他应用选中文字后再按快捷键，或直接在这里输入。"))
}

@MainActor
@Test func changingLanguageDoesNotRebuildProviders() {
    let state = makeContextTestState()
    state.registry.removeAll()
    state.registry.register(AppMVPFixtureEngine(id: "configured-primary", calls: AppProviderCalls()))

    state.setLanguageDirection(targetCode: "ja")

    #expect(state.targetLanguage == .ja)
    #expect(state.registry.activeProviders().map(\.id) == ["configured-primary"])
}

@MainActor
@Test func explicitWorkspaceTargetRetranslatesWithoutBeingReversedByTheCoordinator() async throws {
    let state = makeContextTestState()
    let calls = AppDirectionRequests()
    state.settings.sourceLanguageCode = "auto"
    state.settings.targetLanguageCode = "zh"
    state.registry.removeAll()
    state.registry.register(AppDirectionFixtureEngine(calls: calls))
    state.openWorkspace(text: "今天天气很好，我们去公园散步。", autoRun: true,
                        focusComposer: false, origin: .selection)
    try await waitForMVPTranslation(state)
    #expect(state.targetLanguage == .en)
    #expect(state.primaryActionTranslatedText == "zh->en")

    state.setLanguageDirection(targetCode: "zh")
    #expect(state.targetLanguage == .zh)
    #expect(state.outcomes.isEmpty)
    try await waitForMVPTranslation(state)

    let requests = await calls.requests
    #expect(requests.map(\.from) == [.zh, .zh])
    #expect(requests.map(\.to) == [.en, .zh])
    #expect(state.primaryActionTranslatedText == "zh->zh")
    #expect(state.registry.activeProviders().map(\.id) == ["direction-fixture"])
}

@MainActor
@Test func newSelectionAndOCRRestoreDefaultAutomaticDirectionAfterAnExplicitTarget() async throws {
    let state = makeContextTestState()
    let calls = AppDirectionRequests()
    let text = "今天天气很好，我们去公园散步。"
    state.settings.sourceLanguageCode = "auto"
    state.settings.targetLanguageCode = "zh"
    state.registry.removeAll()
    state.registry.register(AppDirectionFixtureEngine(calls: calls))
    state.openWorkspace(text: text, autoRun: false, focusComposer: false, origin: .selection)
    state.setLanguageDirection(targetCode: "zh")
    try await waitForMVPTranslation(state)

    state.openWorkspace(text: text, autoRun: true, focusComposer: false, origin: .selection)
    try await waitForMVPTranslation(state)
    #expect(state.targetLanguage == .en)

    state.setLanguageDirection(targetCode: "zh")
    try await waitForMVPTranslation(state)
    state.openOCRWorkspace(result: OCRResult(fullText: text, blocks: [], confidence: 0.99), providerName: "Fixture")
    state.translateDraft()
    try await waitForMVPTranslation(state)

    let requests = await calls.requests
    #expect(requests.map(\.to) == [.zh, .en, .zh, .en])
    #expect(state.targetLanguage == .en)
}

@MainActor
@Test func mvpPreservesPrivateSurfacesAndSavedLocalOnlyProfile() {
    let state = makeContextTestState()
    state.openWorkspace(text: "Account details", autoRun: false, focusComposer: false,
                        origin: .selection, sourceApp: "1Password")
    #expect(!state.settings.advancedFeaturesEnabled)
    #expect(state.contextProfile == .privateLocal)

    state.settings.rememberContextProfile(.privateLocal)
    state.openManualInputWorkspace()
    #expect(state.contextProfile == .privateLocal)
}

@MainActor
@Test func mvpQueriesOneProviderAndComparesOthersOnlyWhenRequested() async throws {
    let state = makeContextTestState()
    let calls = AppProviderCalls()
    state.registry.removeAll()
    state.registry.register(AppMVPFixtureEngine(id: "primary", calls: calls))
    state.registry.register(AppMVPFixtureEngine(id: "second", calls: calls))
    state.registry.register(AppMVPFixtureEngine(id: "third", calls: calls))

    state.openWorkspace(text: "first source", autoRun: true, focusComposer: false, origin: .selection)
    try await waitForMVPTranslation(state)

    #expect(await calls.ids == ["primary"])
    #expect(state.outcomes.map(\.providerId) == ["primary"])
    #expect(state.primaryActionTranslatedText == "quickTranslate:first source")
    #expect(state.canCompareOtherEngines)
    let savedID = state.savedRecordId

    state.compareOtherEngines()
    try await waitForMVPTranslation(state)

    #expect(await calls.ids.filter { $0 == "primary" }.count == 1)
    #expect(Set(await calls.ids) == ["primary", "second", "third"])
    #expect(state.outcomes.count == 3)
    #expect(state.savedRecordId == savedID)
    #expect(!state.canCompareOtherEngines)
    let records = await state.history.all()
    #expect(records.count == 1)
    let saved = try #require(records.first)
    #expect(saved.id == savedID)
    #expect(saved.outcomes.count == 3)
    state.openHistoryWorkspace(saved)
    #expect(state.outcomes.count == 3)
    #expect(!state.isTranslating)
}

@MainActor
@Test func successfulBackupRemovesPrimaryFailureCard() async throws {
    let state = makeContextTestState()
    let calls = AppProviderCalls()
    state.registry.removeAll()
    state.registry.register(AppMVPFixtureEngine(id: "failed-primary", calls: calls, fails: true))
    state.registry.register(AppMVPFixtureEngine(id: "backup", calls: calls))
    state.translate("source")
    try await waitForMVPTranslation(state)

    #expect(await calls.ids == ["failed-primary", "backup"])
    #expect(state.outcomes.map(\.providerId) == ["backup"])
    #expect(state.pendingProviders.isEmpty)
}

@MainActor
@Test func fallbackReachesUsableProviderAfterUnsupportedLanguage() async throws {
    let state = makeContextTestState()
    let calls = AppProviderCalls()
    state.registry.removeAll()
    state.registry.register(AppMVPFixtureEngine(id: "primary", calls: calls, fails: true))
    state.registry.register(AppMVPFixtureEngine(id: "unsupported", calls: calls, failure: .unsupportedLanguage))
    state.registry.register(AppMVPFixtureEngine(id: "usable", calls: calls))
    state.translate("tide")
    try await waitForMVPTranslation(state)

    #expect(await calls.ids == ["primary", "unsupported", "usable"])
    #expect(state.outcomes.map(\.providerId) == ["usable"])
    #expect(state.primaryActionTranslatedText == "quickTranslate:tide")
    #expect(state.pendingProviders.isEmpty)
}

@MainActor
@Test func replacementRequestCancelsOldResultAndHistoryWrite() async throws {
    let state = makeContextTestState()
    let calls = AppProviderCalls()
    state.registry.removeAll()
    state.registry.register(AppMVPFixtureEngine(id: "primary", calls: calls, delayMs: 80))
    state.translate("old source")
    for _ in 0..<100 {
        if await !calls.ids.isEmpty { break }
        try await Task.sleep(nanoseconds: 5_000_000)
    }
    state.translate("new source")
    try await waitForMVPTranslation(state)

    #expect(state.sourceText == "new source")
    #expect(state.primaryActionTranslatedText == "quickTranslate:new source")
    #expect(await state.history.all().map(\.sourceText) == ["new source"])
}

@MainActor
@Test func explicitRetryCancelsPendingAutomaticBackup() async throws {
    let state = makeContextTestState()
    let calls = AppProviderCalls()
    state.registry.removeAll()
    state.registry.register(AppMVPFixtureEngine(id: "primary", calls: calls, fails: true))
    state.registry.register(AppMVPFixtureEngine(id: "backup", calls: calls, suspendUntilCancelled: true))
    state.translate("source")
    for _ in 0..<100 {
        if await calls.ids.contains("backup"), state.pendingProviders.map(\.id) == ["backup"] { break }
        try await Task.sleep(nanoseconds: 5_000_000)
    }
    #expect(await calls.ids == ["primary", "backup"])
    #expect(state.pendingProviders.map(\.id) == ["backup"])
    #expect(state.isTranslating)
    state.retryProvider("primary")
    for _ in 0..<100 {
        if !state.isTranslating { break }
        try await Task.sleep(nanoseconds: 5_000_000)
    }
    #expect(!state.isTranslating)
    #expect(await calls.ids == ["primary", "backup", "primary"])
    #expect(state.outcomes.map(\.providerId) == ["primary"])
    #expect(state.outcomes.first?.error == .network)
    #expect(state.pendingProviders.isEmpty)
    #expect(await state.history.all().isEmpty)
}

@MainActor
@Test func correctingOCRCandidateCancelsPreviousTranslation() async throws {
    let state = makeContextTestState()
    let calls = AppProviderCalls()
    state.registry.removeAll()
    state.registry.register(AppMVPFixtureEngine(id: "primary", calls: calls, delayMs: 80))
    state.openOCRWorkspace(result: OCRResult(
        fullText: "First OCR sentence.\nSecond OCR sentence.",
        blocks: [
            OCRBlock(text: "First OCR sentence.", boundingBox: CGRect(x: 0.1, y: 0.8, width: 0.8, height: 0.1), confidence: 0.9),
            OCRBlock(text: "Second OCR sentence.", boundingBox: CGRect(x: 0.1, y: 0.2, width: 0.8, height: 0.1), confidence: 0.9)
        ], confidence: 0.9
    ), providerName: "Fixture OCR")
    let replacement = try #require(state.ocrCandidates.first { $0.id != state.selectedOCRCandidateID })
    state.translateDraft()
    for _ in 0..<100 {
        if await !calls.ids.isEmpty { break }
        try await Task.sleep(nanoseconds: 5_000_000)
    }

    state.selectOCRCandidate(id: replacement.id, autoRun: false)
    try await Task.sleep(nanoseconds: 100_000_000)

    #expect(state.sourceDraft == replacement.text)
    #expect(state.sourceText.isEmpty)
    #expect(state.outcomes.isEmpty)
    #expect(state.pendingProviders.isEmpty)
    #expect(!state.isTranslating)
    #expect(await state.history.all().isEmpty)
}

@MainActor
@Test func structuredMeaningResultKeepsProviderCardForMultiParagraphText() {
    let state = makeContextTestState()
    state.sourceDraft = "First paragraph.\n\nSecond paragraph."
    let interpretation = InterpretationResult(
        intendedMeaning: "说话者在表达两层意思。",
        localizedTranslation: "第一段。\n\n第二段。",
        confidence: 0.9
    )
    state.outcomes = [
        AggregatedOutcome(
            providerId: "llm",
            displayName: "LLM",
            result: TranslateResult(
                providerId: "llm",
                translated: interpretation.localizedTranslation,
                interpretation: interpretation
            ),
            error: nil,
            latencyMs: 10
        )
    ]

    #expect(state.paragraphHints.count == 2)
    #expect(!state.canShowParagraphBilingualView)
}

@Test func literalReferenceHidesPunctuationAndWhitespaceOnlyVariants() {
    #expect(!shouldShowLiteralTranslation("Hello, world!", comparedTo: " hello world "))
    #expect(shouldShowLiteralTranslation("A bold decision.", comparedTo: "A risky decision."))
}

@Test func intendedMeaningUsesExplicitMaterialDifferenceSignal() {
    let straightforward = InterpretationResult(
        intendedMeaning: "这段介绍了 BM25 的用途。",
        meaningAddsValue: false,
        localizedTranslation: "这段文字介绍了 BM25 在精确匹配中的用途。"
    )
    #expect(!shouldShowIntendedMeaning(straightforward))

    let implied = InterpretationResult(
        intendedMeaning: "说话者并非赞赏，而是在委婉质疑这个决定。",
        meaningAddsValue: true,
        localizedTranslation: "你这个决定还真够大胆的。"
    )
    #expect(shouldShowIntendedMeaning(implied))
}

@Test func legacyIntendedMeaningOnlyShowsWhenAmbiguityWasReported() {
    let duplicateLegacy = InterpretationResult(
        intendedMeaning: "这是个大胆的选择。",
        localizedTranslation: "这是一个大胆的选择。"
    )
    #expect(!shouldShowIntendedMeaning(duplicateLegacy))

    let ambiguousLegacy = InterpretationResult(
        intendedMeaning: "说话者可能是在讽刺。",
        localizedTranslation: "你这个决定还真够大胆的。",
        ambiguities: [InterpretationAlternative(interpretation: "真诚赞赏", when: "前文明示支持")]
    )
    #expect(shouldShowIntendedMeaning(ambiguousLegacy))
}

@Test func sourceComposerSubmitsOnlyForUnmodifiedReturn() {
    for characters in ["\r", "\u{3}"] {
        #expect(shouldSubmitSourceComposer(charactersIgnoringModifiers: characters, modifierFlags: []))
        #expect(!shouldSubmitSourceComposer(charactersIgnoringModifiers: characters, modifierFlags: .command))
        #expect(!shouldSubmitSourceComposer(charactersIgnoringModifiers: characters, modifierFlags: .shift))
        #expect(!shouldSubmitSourceComposer(charactersIgnoringModifiers: characters, modifierFlags: .option))
        #expect(!shouldSubmitSourceComposer(charactersIgnoringModifiers: characters, modifierFlags: .control))
    }
    #expect(!shouldSubmitSourceComposer(charactersIgnoringModifiers: "x", modifierFlags: []))
}

@MainActor
@Test func shortSelectionUsesCompactWorkspaceButManualInputDoesNot() {
    let state = makeContextTestState()

    state.openWorkspace(
        text: "Ship the recommended result first.",
        autoRun: false,
        focusComposer: false,
        origin: .selection
    )
    #expect(state.prefersCompactWorkspace)

    state.openWorkspace(
        text: "Ship the recommended result first.",
        autoRun: false,
        focusComposer: false,
        origin: .manualInput
    )
    #expect(!state.prefersCompactWorkspace)
}

@MainActor
@Test func historyWorkspaceRestoresLanguageDirection() {
    let state = makeContextTestState()
    let record = TranslationRecord(
        sourceText: "Review the release note.",
        translated: "リリースノートを確認してください。",
        providerId: "fixture",
        sourceLang: "en",
        targetLang: "ja"
    )

    state.openHistoryWorkspace(record, autoRun: false)

    #expect(state.sourceDraft == record.sourceText)
    #expect(state.sourceLanguage == .en)
    #expect(state.targetLanguage == .ja)
    #expect(state.currentOrigin == .history)
    #expect(state.sourceText == record.sourceText)
    #expect(state.primaryActionTranslatedText == record.translated)
    #expect(state.savedRecordId == record.id)
    #expect(!state.isTranslating)
}

@MainActor
@Test func lookupPrefersDictionaryOutcomeAsPrimaryResult() {
    let state = makeContextTestState()
    state.openWorkspace(
        text: "context",
        mode: .lookup,
        autoRun: false,
        focusComposer: false,
        origin: .lookup
    )
    state.outcomes = [
        AggregatedOutcome(
            providerId: "generic",
            displayName: "Generic",
            result: TranslateResult(providerId: "generic", translated: "上下文"),
            error: nil,
            latencyMs: 1
        ),
        AggregatedOutcome(
            providerId: "dictionary",
            displayName: "Dictionary",
            result: TranslateResult(
                providerId: "dictionary",
                translated: "上下文；语境",
                phonetics: [Phonetic(type: "UK", value: "/ˈkɒntekst/")],
                definitions: [Definition(partOfSpeech: "n.", meanings: ["上下文", "语境"])]
            ),
            error: nil,
            latencyMs: 2
        )
    ]

    #expect(state.primarySuccessfulOutcome?.providerId == "dictionary")
}

@MainActor
@Test func manualPolishOpensNativePolishWorkspace() {
    let state = makeContextTestState()

    state.openManualPolishWorkspace()

    #expect(state.contextProfile == .nativePolish)
}

@MainActor
@Test func manualPolishPrefillsFocusedInputDraft() {
    let state = makeContextTestState()

    state.openManualPolishWorkspace(
        sourceApp: "Linear",
        initialDraft: "这个流程有点重，用户还没看到价值就被要求配置太多东西。"
    )

    #expect(state.sourceDraft == "这个流程有点重，用户还没看到价值就被要求配置太多东西。")
    #expect(state.currentContextSourceApp == "Linear")
    #expect(state.didCaptureFocusedInputDraft)
}

@MainActor
@Test func manualPolishBuildsToneVariantsAndCanSwitchTone() {
    let state = makeContextTestState()
    state.openManualPolishWorkspace(initialDraft: "这个流程有点重。")
    state.outcomes = [
        AggregatedOutcome(
            providerId: "fixture",
            displayName: "Fixture",
            result: TranslateResult(
                providerId: "fixture",
                translated: "The flow feels a bit heavy: users are asked to configure too much before they have seen the product's value."
            ),
            error: nil,
            latencyMs: 1
        )
    ]

    #expect(state.polishVariants.count == 3)
    #expect(state.polishVariants.first { $0.tone == .direct }?.text.hasPrefix("The flow feels") == true)
    #expect(state.polishVariants.first { $0.tone == .softer }?.text.hasPrefix("I think") == true)
    #expect(state.polishVariants.first { $0.tone == .concise }?.text.hasSuffix(".") == true)

    state.selectPolishTone(.softer, autoRun: false)
    #expect(state.selectedPolishTone == .softer)
    #expect(state.polishVariants.first { $0.tone == .softer }?.isRecommended == true)
}

@MainActor
@Test func polishUsesDetectedSourceLanguageInsteadOfTargetLanguage() {
    let state = makeContextTestState()
    state.setLanguageDirection(sourceCode: "auto", targetCode: "zh")
    state.registry.removeAll()

    state.translate("This draft should be polished in English.", mode: .polish)

    #expect(state.targetLanguage == .en)
    #expect(state.detectedSource == .en)
}

@MainActor
@Test func privateLocalWithoutLocalProviderDoesNotStartCloudTranslation() {
    let state = makeContextTestState()
    state.registry.removeAll()

    state.openWorkspace(
        text: "account secret 123",
        autoRun: false,
        focusComposer: false,
        origin: .selection,
        profile: .privateLocal
    )
    state.translateDraft()

    #expect(!state.isTranslating)
    #expect(state.pendingProviders.isEmpty)
    #expect(state.outcomes.isEmpty)
    #expect(state.workspaceNotice?.primaryAction?.action == .openTranslationSettings)
}

@MainActor
@Test func saveCurrentExpressionPersistsToLearningVocabulary() {
    let state = makeContextTestState()
    state.settings.learningVocabularyEntries = []

    state.openWorkspace(
        text: "ship it",
        autoRun: false,
        focusComposer: false,
        origin: .selection
    )
    let saved = state.saveCurrentExpression(translatedText: "发布它", sceneLabel: "测试摘录")

    #expect(saved)
    #expect(state.settings.learningVocabularyEntries.contains { entry in
        entry.term == "ship it" && entry.meaning == "发布它" && entry.sceneLabel == "测试摘录"
    })
}

@Test func urlRouteOptionsParseProfileAndSourceURL() {
    let options = AppURLRouteOptions.parse(queryItems: [
        URLQueryItem(name: "surface", value: "peek"),
        URLQueryItem(name: "profile", value: TranslationContextProfile.github.rawValue),
        URLQueryItem(name: "sourceURL", value: "https://github.com/example/parrot")
    ])

    #expect(options.profile == .github)
    #expect(options.sourceURL == "https://github.com/example/parrot")
}

@MainActor
@Test func ocrWorkspacePreservesCandidatesAndSwitchesDraft() throws {
    let state = makeContextTestState()
    let body = [
        "AI products do not fail because translation is missing. They fail because users lose the next action.",
        "A workspace should help people understand, rewrite, reply, and remember."
    ].joined(separator: "\n")
    let result = OCRResult(
        fullText: "Product notes\n\(body)\n12:41 · Product notes",
        blocks: [
            OCRBlock(text: "Product notes", boundingBox: CGRect(x: 0.10, y: 0.86, width: 0.30, height: 0.04), confidence: 0.92),
            OCRBlock(text: "AI products do not fail because translation is missing. They fail because users lose the next action.", boundingBox: CGRect(x: 0.12, y: 0.62, width: 0.72, height: 0.08), confidence: 0.94),
            OCRBlock(text: "A workspace should help people understand, rewrite, reply, and remember.", boundingBox: CGRect(x: 0.12, y: 0.53, width: 0.66, height: 0.06), confidence: 0.91),
            OCRBlock(text: "12:41 · Product notes", boundingBox: CGRect(x: 0.10, y: 0.26, width: 0.30, height: 0.04), confidence: 0.88)
        ],
        confidence: 0.89
    )

    state.openOCRWorkspace(result: result, providerName: "Test OCR")

    #expect(state.ocrCandidates.count >= 3)
    #expect(state.selectedOCRCandidate?.kind == .primaryBody)
    #expect(state.sourceDraft == body)
    #expect(state.ocrCandidates.contains { $0.kind == .fullText })

    let fullText = try #require(state.ocrCandidates.first { $0.kind == .fullText })
    state.selectOCRCandidate(id: fullText.id, autoRun: false)
    #expect(state.selectedOCRCandidateID == fullText.id)
    #expect(state.sourceDraft == result.fullText)
}

@MainActor
@Test func ocrWorkspaceFallsBackToFullTextWhenGeometryIsNotReliable() {
    let state = makeContextTestState()
    let result = OCRResult(
        fullText: "OCR fixture line 1\nOCR fixture line 2",
        blocks: [
            OCRBlock(text: "OCR fixture line 1", boundingBox: CGRect(x: 0, y: 0, width: 1, height: 1), confidence: 0.62),
            OCRBlock(text: "OCR fixture line 2", boundingBox: CGRect(x: 0, y: 1, width: 1, height: 1), confidence: 0.62)
        ],
        confidence: 0.62
    )

    state.openOCRWorkspace(result: result, providerName: "Fixture OCR")

    #expect(state.selectedOCRCandidate?.kind == .fullText)
    #expect(state.sourceDraft == "OCR fixture line 1\nOCR fixture line 2")
}


@MainActor
private func makeContextTestState() -> AppState {
    let defaults = UserDefaults(suiteName: "parrot.context-tests.\(UUID().uuidString)")!
    for engine in EngineBootstrap.defaultOrder {
        defaults.set(false, forKey: "engine.\(engine).enabled")
    }
    let base = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let settings = AppSettings(defaults: defaults, terminologyStore: TerminologyStore(fileURL: base.appendingPathComponent("terminology.json")))
    return AppState(settings: settings, history: HistoryStore(fileURL: base.appendingPathComponent("history.json")))
}

@MainActor
@Test func disabledEnginesShowRecoveryAndKeepTheSource() {
    let state = makeContextTestState()
    state.translate("Keep this draft")
    #expect(!state.isTranslating)
    #expect(state.sourceDraft == "Keep this draft")
    #expect(state.workspaceNotice?.primaryAction?.action == .openTranslationSettings)
    #expect(state.outcomes.isEmpty)
}

@MainActor
private func waitForMVPTranslation(_ state: AppState) async throws {
    for _ in 0..<200 {
        if !state.isTranslating, state.savedRecordId != nil { return }
        try await Task.sleep(nanoseconds: 5_000_000)
    }
    #expect(!state.isTranslating)
    #expect(state.savedRecordId != nil)
}

private actor AppProviderCalls {
    var ids: [String] = []
    func record(_ id: String) { ids.append(id) }
}

private actor AppDirectionRequests {
    var requests: [TranslateRequest] = []
    func record(_ request: TranslateRequest) { requests.append(request) }
}

private struct AppDirectionFixtureEngine: TranslationProvider {
    let calls: AppDirectionRequests
    let id = "direction-fixture"
    let displayName = "Direction Fixture"
    let supportedLanguages: [Language] = [.auto, .zh, .en]
    let capabilities = ProviderCapabilities()

    func translate(_ request: TranslateRequest) async throws -> TranslateResult {
        await calls.record(request)
        return TranslateResult(providerId: id,
            translated: "\(request.from.code ?? "auto")->\(request.to.code ?? "auto")")
    }
}

private struct AppMVPFixtureEngine: TranslationProvider {
    let id: String
    let calls: AppProviderCalls
    var fails = false
    var delayMs: UInt64 = 0
    var failure: ProviderError?
    var suspendUntilCancelled = false
    var displayName: String { id }
    var supportedLanguages: [Language] { [.auto, .zh, .en] }
    var capabilities: ProviderCapabilities { ProviderCapabilities() }

    func translate(_ req: TranslateRequest) async throws -> TranslateResult {
        await calls.record(id)
        if suspendUntilCancelled {
            // A cancellation test needs an in-flight request, independent of how
            // quickly the main actor returns to the test under parallel load.
            let (stream, continuation) = AsyncStream<Void>.makeStream()
            await withTaskCancellationHandler {
                for await _ in stream {}
            } onCancel: {
                continuation.finish()
            }
            try Task.checkCancellation()
        }
        if delayMs > 0 { try await Task.sleep(nanoseconds: delayMs * 1_000_000) }
        if let failure { throw failure }
        if fails { throw ProviderError.network }
        return TranslateResult(providerId: id, translated: "\(req.context?.profile.rawValue ?? "quickTranslate"):\(req.text)")
    }
}
