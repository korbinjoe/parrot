import Foundation
import ParrotCore
import Testing
@testable import ParrotSocial

private struct StubSocialProvider: TranslationProvider {
    let translated: String
    let error: Error?

    var id: String { "stub-social" }
    var displayName: String { "Stub Social" }
    var supportedLanguages: [Language] { [.auto, .zh, .en] }
    var capabilities: ProviderCapabilities { ProviderCapabilities(supportsPolish: true) }

    init(translated: String = "", error: Error? = nil) {
        self.translated = translated
        self.error = error
    }

    func translate(_ req: TranslateRequest) async throws -> TranslateResult {
        if let error {
            throw error
        }
        return TranslateResult(providerId: id, translated: translated)
    }
}

private struct DirectionEchoProvider: TranslationProvider {
    var id: String { "direction-echo" }
    var displayName: String { "Direction Echo" }
    var supportedLanguages: [Language] { [.auto, .zh, .en, .ja, .ko, .fr, .de, .es, .ru] }
    var capabilities: ProviderCapabilities { ProviderCapabilities() }

    func translate(_ req: TranslateRequest) async throws -> TranslateResult {
        let from = req.from.code ?? "auto"
        let to = req.to.code ?? "auto"
        return TranslateResult(
            providerId: id,
            translated: "\(from)->\(to): \(req.text)",
            detectedFrom: req.from == .auto ? nil : req.from
        )
    }
}

private struct FailingTranslationProvider: TranslationProvider {
    var id: String { "failing-translation" }
    var displayName: String { "Failing Translation" }
    var supportedLanguages: [Language] { [.auto, .zh, .en] }
    var capabilities: ProviderCapabilities { ProviderCapabilities() }

    func translate(_ req: TranslateRequest) async throws -> TranslateResult {
        throw ProviderError.network
    }
}

@Test func parseUnderstandResultFromJSONWithSurroundingText() throws {
    let raw = """
    Here is the JSON:
    {
      "meaningSummary": "It criticizes onboarding.",
      "toneTags": ["UX feedback", "calm"],
      "phraseExplanations": [{"phrase": "onboarding", "explanation": "first-run flow"}],
      "fullTranslation": "它在批评新手引导。"
    }
    """

    let result = try SocialResultParser().parseUnderstand(raw)

    #expect(result.meaningSummary == "It criticizes onboarding.")
    #expect(result.toneTags == ["UX feedback", "calm"])
    #expect(result.phraseExplanations.first?.phrase == "onboarding")
    #expect(result.fullTranslation == "它在批评新手引导。")
}

@Test func parseExpressResultRequiresCandidates() throws {
    let raw = """
    {
      "candidates": [
        {"id": "\(UUID().uuidString)", "title": "Natural reply", "text": "Fair take.", "tone": "natural"},
        {"id": "\(UUID().uuidString)", "title": "Short version", "text": "Good feature, bad flow.", "tone": "xShort"}
      ]
    }
    """

    let result = try SocialResultParser().parseExpress(raw)

    #expect(result.candidates.count == 2)
    #expect(result.candidates[0].tone == .natural)
    #expect(result.candidates[1].tone == .xShort)
}

@Test func malformedProviderOutputFallsBackWithoutDroppingDraft() {
    let parser = SocialResultParser()
    let understand = parser.fallbackUnderstand(
        from: "This is useful but not valid JSON.",
        source: "Original social post"
    )
    let express = parser.fallbackExpress(from: "Fair take.", tone: .firm)

    #expect(understand.meaningSummary == "This is useful but not valid JSON.")
    #expect(understand.fullTranslation == "Original social post")
    #expect(understand.toneTags == ["unstructured"])
    #expect(express.candidates.count == 1)
    #expect(express.candidates.first?.text == "Fair take.")
    #expect(express.candidates.first?.tone == .firm)
}

@Test func providerBackedServiceFallsBackForMalformedJSON() async throws {
    let service = ProviderBackedSocialService(provider: StubSocialProvider(translated: "Readable but not JSON"))
    let session = SocialTextSession(origin: .manualInput, sourceDraft: "Original social post")

    let result = try await service.understand(session: session)

    #expect(result.meaningSummary == "Readable but not JSON")
    #expect(result.fullTranslation == "Original social post")
    #expect(result.confidenceNote != nil)
}

@Test func providerBackedServicePropagatesTimeoutWithoutMutatingSession() async {
    let service = ProviderBackedSocialService(provider: StubSocialProvider(error: ProviderError.timeout))
    let session = SocialTextSession(
        mode: .express,
        origin: .manualInput,
        sourceDraft: "Original context",
        userIntentDraft: "Keep my draft"
    )

    do {
        _ = try await service.generateReplies(session: session)
        Issue.record("Expected timeout")
    } catch {
        #expect((error as? ProviderError) == .timeout)
        #expect(session.sourceDraft == "Original context")
        #expect(session.userIntentDraft == "Keep my draft")
    }
}

@Test func promptBuilderIncludesSocialContractsAndDrafts() {
    let session = SocialTextSession(
        origin: .manualInput,
        platform: .reddit,
        sourceDraft: "The onboarding asks too much too early.",
        userIntentDraft: "我觉得这个评价公平。",
        selectedTone: .friendly
    )
    let builder = SocialPromptBuilder()

    let understand = builder.understandPrompt(for: session)
    let express = builder.expressPrompt(for: session)

    #expect(understand.contains("\"meaningSummary\""))
    #expect(understand.contains("Reddit"))
    #expect(understand.contains(session.sourceDraft))
    #expect(express.contains("\"candidates\""))
    #expect(express.contains("Friendly"))
    #expect(express.contains(session.userIntentDraft))
}

@Test func promptBuilderUsesPolishContractForPolishMode() {
    let session = SocialTextSession(
        mode: .polish,
        origin: .manualInput,
        sourceDraft: "this product useful but onboarding make me confused",
        selectedTone: .firm
    )

    let prompt = SocialPromptBuilder().expressPrompt(for: session)

    #expect(prompt.contains("Rewrite the rough draft"))
    #expect(prompt.contains("\"Native polish\""))
    #expect(prompt.contains("Firm"))
    #expect(prompt.contains(session.sourceDraft))
}

@Test func promptBuilderUsesPolishRefinementLanguageForPolishMode() {
    let session = SocialTextSession(
        mode: .polish,
        origin: .manualInput,
        sourceDraft: "rough draft"
    )
    let candidate = ReplyCandidate(title: "Native polish", text: "Polished draft.", tone: .natural)

    let prompt = SocialPromptBuilder().refinePrompt(candidate: candidate, action: .shorter, session: session)

    #expect(prompt.contains("polished draft"))
    #expect(prompt.contains("Original draft"))
    #expect(!prompt.contains("social reply"))
}

@Test func socialSessionSwitchesToExpressWithoutLosingSource() {
    var session = SocialTextSession(
        origin: .shareExtension,
        platform: .reddit,
        sourceDraft: "The onboarding asks too much too early."
    )

    session.switchToExpress()

    #expect(session.mode == .express)
    #expect(session.sourceDraft == "The onboarding asks too much too early.")
    #expect(session.contextText == "The onboarding asks too much too early.")
}

@Test func ruleBasedServiceGeneratesThreeCandidates() async throws {
    let service = RuleBasedSocialService()
    var session = SocialTextSession(
        mode: .express,
        origin: .manualInput,
        platform: .reddit,
        sourceDraft: "The product is useful, but onboarding is confusing.",
        userIntentDraft: "我觉得产品不差，但新用户第一次用会迷路。",
        selectedTone: .redditStyle
    )

    let understand = try await service.understand(session: session)
    session.apply(understand)
    let result = try await service.generateReplies(session: session)

    #expect(understand.meaningSummary.contains("首次使用流程"))
    #expect(result.candidates.count >= 3)
    #expect(result.candidates.contains { $0.tone == .xShort })
}

@Test func ruleBasedServicePolishesSourceDraftInPolishMode() async throws {
    let service = RuleBasedSocialService()
    let session = SocialTextSession(
        mode: .polish,
        origin: .manualInput,
        sourceDraft: "i think this product useful but onboarding make me confused",
        selectedTone: .firm
    )

    let result = try await service.generateReplies(session: session)

    #expect(result.candidates.count >= 3)
    #expect(result.candidates.first?.title == "Native polish")
    #expect(result.candidates.first?.text.contains("onboarding") == true)
    #expect(result.candidates.first?.tone == .firm)
}

@Test func translationAugmentedServiceAutoTranslatesEnglishToChinese() async throws {
    let service = TranslationAugmentedSocialService(
        base: RuleBasedSocialService(),
        translationProvider: DirectionEchoProvider()
    )
    let session = SocialTextSession(
        origin: .clipboard,
        sourceDraft: "This is clearly an English sentence about onboarding friction."
    )

    let result = try await service.understand(session: session)

    #expect(result.fullTranslation?.hasPrefix("en->zh:") == true)
}

@Test func translationAugmentedServiceAutoTranslatesChineseToEnglish() async throws {
    let service = TranslationAugmentedSocialService(
        base: RuleBasedSocialService(),
        translationProvider: DirectionEchoProvider()
    )
    let session = SocialTextSession(
        origin: .latestScreenshot,
        sourceDraft: "这是一段中文内容，应该自动翻译成英文。"
    )

    let result = try await service.understand(session: session)

    #expect(result.fullTranslation?.hasPrefix("zh->en:") == true)
}

@Test func translationAugmentedServiceDoesNotEchoSourceWhenTranslationFails() async throws {
    let service = TranslationAugmentedSocialService(
        base: RuleBasedSocialService(),
        translationProvider: FailingTranslationProvider()
    )
    let source = "This text was recognized, but translation failed."
    let session = SocialTextSession(origin: .clipboard, sourceDraft: source)

    let result = try await service.understand(session: session)

    #expect(result.fullTranslation != source)
    #expect(result.confidenceNote?.contains("Translation is temporarily unavailable") == true)
}

@Test func ocrCleanerRemovesSocialNoise() {
    let cleaner = OCRTextCleaner()
    let raw = """
    u/productdesign
    The feature is useful,
    but the first-run flow asks too much.
    2h  48 replies

    """

    let cleaned = cleaner.joinBrokenLines(
        cleaner.removeTimestamps(
            cleaner.removeUsernames(raw)
        )
    )

    #expect(!cleaned.contains("u/productdesign"))
    #expect(!cleaned.contains("48 replies"))
    #expect(cleaned == "The feature is useful, but the first-run flow asks too much.")
}
