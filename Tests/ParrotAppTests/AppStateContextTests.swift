import Testing
import Foundation
import CoreGraphics
import ParrotCore
@testable import ParrotApp

@MainActor
@Test func shortSelectionUsesQuickPeekAndExpandPreservesDraft() {
    let state = AppState()

    state.openWorkspace(
        text: "Ship it when the tests are green.",
        autoRun: false,
        focusComposer: false,
        origin: .selection
    )

    #expect(state.isQuickPeekSurface)
    #expect(state.sourceDraft == "Ship it when the tests are green.")

    state.expandQuickPeek()

    #expect(!state.isQuickPeekSurface)
    #expect(state.sourceDraft == "Ship it when the tests are green.")
}

@MainActor
@Test func longSelectionUsesFullWorkspace() {
    let state = AppState()
    let text = String(repeating: "This paragraph needs a roomy bilingual workspace. ", count: 8)

    state.openWorkspace(
        text: text,
        autoRun: false,
        focusComposer: false,
        origin: .selection
    )

    #expect(!state.isQuickPeekSurface)
    #expect(state.sourceDraft == text)
}

@MainActor
@Test func explicitURLSurfaceCanOpenQuickPeek() {
    let state = AppState()

    state.openWorkspace(
        text: "Short URL translation.",
        autoRun: false,
        focusComposer: false,
        origin: .url,
        surface: .quickPeek
    )

    #expect(state.isQuickPeekSurface)
    #expect(state.contextProfile == .document)
}

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
@Test func manualPolishOpensNativePolishWorkspace() {
    let state = AppState()

    state.openManualPolishWorkspace()

    #expect(!state.isQuickPeekSurface)
    #expect(state.contextProfile == .nativePolish)
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

@Test func urlRouteOptionsParseSurfaceProfileAndSourceURL() {
    let options = AppURLRouteOptions.parse(queryItems: [
        URLQueryItem(name: "surface", value: "peek"),
        URLQueryItem(name: "profile", value: TranslationContextProfile.github.rawValue),
        URLQueryItem(name: "sourceURL", value: "https://github.com/example/parrot")
    ])

    #expect(options.surface == .quickPeek)
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
