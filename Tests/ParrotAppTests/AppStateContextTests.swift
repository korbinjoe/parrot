import Testing
import Foundation
import CoreGraphics
import AppKit
import ParrotCore
@testable import ParrotApp

@MainActor
@Test func sourceMetadataRulesSelectDeveloperProfile() {
    let state = AppState()
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
    let state = AppState()
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
@Test func structuredMeaningResultKeepsProviderCardForMultiParagraphText() {
    let state = AppState()
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
    let state = AppState()

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
    let state = AppState()
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
}

@MainActor
@Test func lookupPrefersDictionaryOutcomeAsPrimaryResult() {
    let state = AppState()
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
@Test func translationResultPresentationPrioritizesLLMSuccessesAndMovesFailuresLast() {
    let slots: [TranslationSlot] = [
        .outcome(AggregatedOutcome(
            providerId: "google",
            displayName: "Google",
            result: TranslateResult(providerId: "google", translated: "谷歌结果"),
            error: nil,
            latencyMs: 10
        )),
        .outcome(AggregatedOutcome(
            providerId: "baidu",
            displayName: "Baidu",
            result: nil,
            error: .network,
            latencyMs: 12
        )),
        .pending(PendingProviderViewState(
            id: "microsoft",
            displayName: "Microsoft",
            modelName: nil,
            isSlow: false
        )),
        .pending(PendingProviderViewState(
            id: "ollama",
            displayName: "Ollama",
            modelName: "glm-5:cloud",
            isSlow: true
        )),
        .pending(PendingProviderViewState(
            id: "doubao#pending",
            displayName: "豆包",
            modelName: "doubao-pro",
            isSlow: true
        )),
        .outcome(AggregatedOutcome(
            providerId: "deepseek#alternate",
            displayName: "DeepSeek",
            result: TranslateResult(providerId: "deepseek#alternate", translated: "DeepSeek 结果"),
            error: nil,
            latencyMs: 20
        )),
        .outcome(AggregatedOutcome(
            providerId: "doubao",
            displayName: "豆包",
            result: TranslateResult(providerId: "doubao", translated: "豆包结果"),
            error: nil,
            latencyMs: 18
        )),
        .outcome(AggregatedOutcome(
            providerId: "qwen",
            displayName: "通义千问",
            result: nil,
            error: .timeout,
            latencyMs: 15_000
        )),
        .outcome(AggregatedOutcome(
            providerId: "doubao#failed",
            displayName: "豆包",
            modelName: "doubao-lite-32k",
            result: nil,
            error: .rateLimited,
            latencyMs: 300
        )),
        .outcome(AggregatedOutcome(
            providerId: "custom-model-provider",
            displayName: "Custom Model Provider",
            modelName: "custom-translate-1",
            result: TranslateResult(providerId: "custom-model-provider", translated: "自定义模型结果"),
            error: nil,
            latencyMs: 25
        ))
    ]

    let providerIDs = sortedTranslationSlotsForPresentation(slots).map(\.id)

    #expect(providerIDs == [
        "doubao",
        "deepseek#alternate",
        "custom-model-provider",
        "google",
        "doubao#pending",
        "ollama",
        "microsoft",
        "doubao#failed",
        "qwen",
        "baidu"
    ])
}

@MainActor
@Test func manualPolishOpensNativePolishWorkspace() {
    let state = AppState()

    state.openManualPolishWorkspace()

    #expect(state.contextProfile == .nativePolish)
}

@MainActor
@Test func manualPolishPrefillsFocusedInputDraft() {
    let state = AppState()

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
    let state = AppState()
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
    let state = AppState()
    state.setLanguageDirection(sourceCode: "auto", targetCode: "zh")
    state.registry.removeAll()

    state.translate("This draft should be polished in English.", mode: .polish)

    #expect(state.targetLanguage == .en)
    #expect(state.detectedSource == .en)
}

@MainActor
@Test func privateLocalWithoutLocalProviderDoesNotStartCloudTranslation() {
    let state = AppState()
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
    #expect(state.workspaceNotice?.primaryAction?.action == .openSettings)
}

@MainActor
@Test func saveCurrentExpressionPersistsToLearningVocabulary() {
    let state = AppState()
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
    let state = AppState()
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
    let state = AppState()
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
