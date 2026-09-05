import Foundation
import Testing
@testable import ParrotCore
@testable import ParrotEngines

@Test func interpretationParserReadsMeaningFirstPayloadInsideMarkdownFence() throws {
    let raw = """
    ```json
    {
      "intendedMeaning": "说话者在委婉质疑这个决定。",
      "localizedTranslation": "你这个决定还真够大胆的。",
      "literalTranslation": "这是一个大胆的选择。",
      "toneTags": ["委婉讽刺", "怀疑"],
      "culturalNotes": [{"expression":"bold choice","explanation":"在特定语境中可表示不赞同。"}],
      "ambiguities": [{"interpretation":"真诚赞扬","when":"前文明确肯定冒险精神时"}],
      "confidence": 0.78
    }
    ```
    """

    let result = try InterpretationParser.parse(raw)

    #expect(result.intendedMeaning.contains("质疑"))
    #expect(result.localizedTranslation == "你这个决定还真够大胆的。")
    #expect(result.culturalNotes.first?.phrase == "bold choice")
    #expect(result.ambiguities.first?.interpretation == "真诚赞扬")
    #expect(result.confidence == 0.78)
}

@Test func interpretationParserReadsLegacySocialPayloadAndClampsConfidence() throws {
    let raw = """
    {
      "meaningSummary": "这是带有限定的赞扬。",
      "toneTags": ["保留态度"],
      "phraseExplanations": [{"phrase":"not bad","explanation":"通常没有字面上那么积极。"}],
      "fullTranslation": "还行。",
      "confidence": "1.4"
    }
    """

    let result = try InterpretationParser.parse(raw)

    #expect(result.meaningSummary == "这是带有限定的赞扬。")
    #expect(result.fullTranslation == "还行。")
    #expect(result.phraseExplanations.first?.phrase == "not bad")
    #expect(result.confidence == 1)
}

@Test func interpretationParserNormalizesNonFiniteConfidence() throws {
    let raw = #"{"intendedMeaning":"含义","localizedTranslation":"译文","confidence":"NaN"}"#

    let result = try InterpretationParser.parse(raw)

    #expect(result.confidence == 0.5)
    #expect(result.confidence.isFinite)
}

@Test func interpretationParserRejectsPayloadWithoutMeaning() {
    #expect(throws: InterpretationParsingError.missingMeaning) {
        _ = try InterpretationParser.parse(#"{"localizedTranslation":"自然译文"}"#)
    }
}

@Test func interpretationParserFindsBalancedObjectAroundNoisyBraces() throws {
    let raw = #"Draft {not JSON}. Result: {"intendedMeaning":"这句话借故推迟。","localizedTranslation":"我们改天再聊。","literalTranslation":"Let's take a rain check {for now}.","confidence":0.7} trailing {note}"#

    let result = try InterpretationParser.parse(raw)

    #expect(result.intendedMeaning == "这句话借故推迟。")
    #expect(result.literalTranslation == "Let's take a rain check {for now}.")
}

@Test func culturalInterpretationFixturesKeepMeaningDistinctFromLiteralWords() throws {
    let fixtures = [
        ("break a leg", "祝你好运", "摔断一条腿"),
        ("yeah, right", "说话者表示不相信", "是啊，对"),
        ("not bad", "带保留的肯定", "不坏"),
        ("bless your heart", "可能是礼貌包装的批评", "愿上帝保佑你的心"),
        ("touch base", "稍后简短沟通", "触碰基地")
    ]

    for (expression, meaning, literal) in fixtures {
        let data: [String: Any] = [
            "intendedMeaning": meaning,
            "localizedTranslation": meaning,
            "literalTranslation": literal,
            "toneTags": [],
            "culturalNotes": [["expression": expression, "explanation": meaning]],
            "ambiguities": [],
            "confidence": 0.8
        ]
        let encoded = try JSONSerialization.data(withJSONObject: data)
        let raw = try #require(String(data: encoded, encoding: .utf8))
        let result = try InterpretationParser.parse(raw)

        #expect(result.intendedMeaning != result.literalTranslation)
        #expect(result.culturalNotes.first?.phrase == expression)
    }
}

@Test func openAIUnderstandPromptIncludesBoundedContextAndStripsURLSecrets() {
    let context = TranslationContext(
        profile: .understand,
        origin: .selection,
        sourceApp: "Safari",
        windowTitle: "A discussion about product risk",
        sourceURL: "https://user:password@example.com/thread/42?token=secret#reply",
        surroundingText: "The previous reply strongly disagreed with the proposal."
    )
    let request = TranslateRequest(
        text: "That's a bold choice.",
        from: .en,
        to: .zh,
        context: context
    )

    let systemPrompt = OpenAICompatEngine.systemPrompt(for: request)
    let userPrompt = OpenAICompatEngine.userPrompt(for: request)

    #expect(systemPrompt.contains("meaning-first cross-cultural interpreter"))
    #expect(systemPrompt.contains("intendedMeaning"))
    #expect(systemPrompt.contains("meaningAddsValue"))
    #expect(systemPrompt.contains("mere paraphrase"))
    #expect(!systemPrompt.contains("Safari"))
    #expect(!systemPrompt.contains("strongly disagreed"))
    #expect(userPrompt.contains("Safari"))
    #expect(userPrompt.contains("strongly disagreed"))
    #expect(userPrompt.contains(#"https:\/\/example.com\/thread\/42"#))
    #expect(!userPrompt.contains("password"))
    #expect(!userPrompt.contains("token=secret"))
}

@Test func understandPromptDropsMalformedSourceURLInsteadOfLeakingSecrets() {
    let request = TranslateRequest(
        text: "Translate this.",
        from: .en,
        to: .zh,
        context: TranslationContext(
            profile: .understand,
            origin: .selection,
            sourceURL: "not a valid URL?token=secret#private"
        )
    )

    let prompt = OpenAICompatEngine.userPrompt(for: request)

    #expect(prompt.contains("token=secret") == false)
    #expect(prompt.contains("private") == false)
    #expect(prompt.contains("sourceURL") == false)
}

@Test func understandPromptLimitsOptionalContextWhenPrivacyMaskingIsEnabled() {
    let request = TranslateRequest(
        text: "Contact alex@example.com.",
        from: .en,
        to: .zh,
        context: TranslationContext(
            profile: .understand,
            origin: .selection,
            sourceApp: "Mail",
            windowTitle: "Confidential project",
            sourceURL: "https://example.com/private/customer-42",
            surroundingText: "Call +1 555 010 1234 next.",
            privacyPolicy: .maskSensitive
        )
    )

    let prompt = OpenAICompatEngine.userPrompt(for: request)

    #expect(prompt.contains("Mail"))
    #expect(prompt.contains("Confidential project") == false)
    #expect(prompt.contains("customer-42") == false)
    #expect(prompt.contains("555 010") == false)
    #expect(prompt.contains(#"https:\/\/example.com"#))
    #expect(prompt.contains(#""origin":"selection""#))
}

@Test func documentLLMPromptReceivesExplicitSourceContextAsUserData() {
    let request = TranslateRequest(
        text: "A short paragraph.",
        from: .en,
        to: .zh,
        context: TranslationContext(
            profile: .document,
            origin: .url,
            sourceApp: "Safari",
            windowTitle: "Product strategy",
            sourceURL: "https://example.com/articles/strategy"
        )
    )

    let systemPrompt = OpenAICompatEngine.systemPrompt(for: request)
    let userPrompt = OpenAICompatEngine.userPrompt(for: request)

    #expect(systemPrompt.contains("untrusted JSON envelope"))
    #expect(systemPrompt.contains("Product strategy") == false)
    #expect(userPrompt.contains("Product strategy"))
    #expect(userPrompt.contains("articles"))
}

@Test func openAIResponseAttachesStructuredInterpretationForUnderstandProfile() throws {
    let content = #"{"intendedMeaning":"委婉质疑","localizedTranslation":"这决定还真大胆。","toneTags":["讽刺"],"culturalNotes":[],"ambiguities":[],"confidence":0.8}"#
    let envelope = ["choices": [["message": ["content": content]]]]
    let data = try JSONSerialization.data(withJSONObject: envelope)
    let request = TranslateRequest(
        text: "That's a bold choice.",
        from: .en,
        to: .zh,
        context: TranslationContext(profile: .understand)
    )

    let result = try OpenAICompatEngine.parseChatCompletion(
        data,
        providerId: "openai",
        request: request
    )

    #expect(result.translated == "这决定还真大胆。")
    #expect(result.interpretation?.intendedMeaning == "委婉质疑")
}

@Test func geminiStructuredRequestSeparatesSystemRulesFromUserContextAndParsesResult() throws {
    let request = TranslateRequest(
        text: "Break a leg.",
        from: .en,
        to: .zh,
        context: TranslationContext(
            profile: .understand,
            origin: .selection,
            sourceApp: "Safari"
        )
    )
    let body = GeminiEngine.requestBody(for: request)
    let systemInstruction = try #require(body["system_instruction"] as? [String: Any])
    let systemParts = try #require(systemInstruction["parts"] as? [[String: String]])
    let contents = try #require(body["contents"] as? [[String: Any]])
    let userParts = try #require(contents.first?["parts"] as? [[String: String]])

    #expect(systemParts.first?["text"]?.contains("meaning-first") == true)
    #expect(systemParts.first?["text"]?.contains("Safari") == false)
    #expect(userParts.first?["text"]?.contains("Safari") == true)

    let content = #"{"intendedMeaning":"祝对方好运","localizedTranslation":"祝你好运！","confidence":0.95}"#
    let envelope = ["candidates": [["content": ["parts": [["text": content]]]]]]
    let data = try JSONSerialization.data(withJSONObject: envelope)
    let result = try GeminiEngine.parse(data, providerId: "gemini", request: request)

    #expect(result.translated == "祝你好运！")
    #expect(result.interpretation?.intendedMeaning == "祝对方好运")
}

@Test func understandRecommendationPrefersStructuredMeaningOverPlainFastResult() {
    let request = TranslateRequest(
        text: "That's a bold choice.",
        from: .en,
        to: .zh,
        context: TranslationContext(profile: .understand)
    )
    let plain = AggregatedOutcome(
        providerId: "machine",
        displayName: "Machine",
        result: TranslateResult(providerId: "machine", translated: "这是一个大胆的选择。"),
        error: nil,
        latencyMs: 20
    )
    let interpretation = InterpretationResult(
        intendedMeaning: "说话者可能在委婉表达怀疑。",
        localizedTranslation: "你这个决定还真够大胆的。",
        confidence: 0.8
    )
    let structured = AggregatedOutcome(
        providerId: "llm",
        displayName: "LLM",
        result: TranslateResult(
            providerId: "llm",
            translated: interpretation.localizedTranslation,
            interpretation: interpretation
        ),
        error: nil,
        latencyMs: 600
    )

    let results = ResultQualityEvaluator.withRecommendation(
        outcomes: [plain, structured],
        request: request
    )

    #expect(results.first { $0.providerId == "llm" }?.result?.qualitySummary?.isRecommended == true)
    #expect(results.first { $0.providerId == "machine" }?.result?.qualitySummary?.issues.contains(.missingInterpretation) == true)
    #expect(results.first { $0.providerId == "machine" }?.result?.qualitySummary?.needsReview == false)
}

@Test func understandRecommendationDoesNotRewardStructurallyBadInterpretation() {
    let request = TranslateRequest(
        text: "This source sentence is long enough to trigger a length-ratio quality check.",
        from: .en,
        to: .zh,
        context: TranslationContext(profile: .understand)
    )
    let plain = AggregatedOutcome(
        providerId: "machine",
        displayName: "Machine",
        result: TranslateResult(providerId: "machine", translated: "这是一个完整、自然且忠实的普通翻译结果。"),
        error: nil,
        latencyMs: 20
    )
    let weakInterpretation = InterpretationResult(
        intendedMeaning: "过短且不完整。",
        localizedTranslation: "短",
        confidence: 0.99
    )
    let structured = AggregatedOutcome(
        providerId: "llm",
        displayName: "LLM",
        result: TranslateResult(
            providerId: "llm",
            translated: weakInterpretation.localizedTranslation,
            interpretation: weakInterpretation
        ),
        error: nil,
        latencyMs: 600
    )

    let results = ResultQualityEvaluator.withRecommendation(
        outcomes: [structured, plain],
        request: request
    )

    #expect(results.first { $0.providerId == "machine" }?.result?.qualitySummary?.isRecommended == true)
    #expect(results.first { $0.providerId == "llm" }?.result?.qualitySummary?.issues.contains(.extremeLengthRatio) == true)
}

@Test func coordinatorOrdersInterpretationProviderFirstWhenProfilePrefersLLM() async {
    let registry = ProviderRegistry()
    registry.register(InterpretationFixtureProvider(id: "machine", supportsInterpretation: false))
    registry.register(InterpretationFixtureProvider(id: "llm", supportsInterpretation: true))
    let coordinator = TranslationCoordinator(registry: registry)
    let request = TranslateRequest(
        text: "Break a leg.",
        from: .en,
        to: .zh,
        context: TranslationContext(
            profile: .understand,
            routingHints: ProviderRoutingHints(preferLLM: true)
        )
    )

    let outcomes = await coordinator.translateAll(request)

    #expect(outcomes.map(\.providerId) == ["llm", "machine"])
}

@Test func coordinatorHonorsExplicitAndAllowedProviderIDsBeforeLLMPreference() async {
    let registry = ProviderRegistry()
    registry.register(InterpretationFixtureProvider(id: "excluded", supportsInterpretation: true))
    registry.register(InterpretationFixtureProvider(id: "llm", supportsInterpretation: true))
    registry.register(InterpretationFixtureProvider(id: "preferred-plain", supportsInterpretation: false))
    let coordinator = TranslationCoordinator(registry: registry)
    let request = TranslateRequest(
        text: "Break a leg.",
        from: .en,
        to: .zh,
        context: TranslationContext(
            profile: .understand,
            routingHints: ProviderRoutingHints(
                preferredProviderIDs: ["preferred-plain"],
                allowedProviderIDs: ["llm", "preferred-plain"],
                preferLLM: true
            )
        )
    )

    let outcomes = await coordinator.translateAll(request)

    #expect(outcomes.map(\.providerId) == ["preferred-plain", "llm"])
}

@Test func coordinatorRestoresPrivacyAndTerminologyTokensAcrossInterpretationFields() async throws {
    let registry = ProviderRegistry()
    registry.register(StructuredEchoProvider())
    let coordinator = TranslationCoordinator(registry: registry)
    let terminology = TerminologySnapshot(
        entries: [TerminologyEntry(source: "Parrot", target: "鹦鹉", from: .en, to: .zh)],
        strictMode: true
    )
    let request = TranslateRequest(
        text: "Parrot contact alex@example.com",
        from: .en,
        to: .zh,
        terminology: terminology,
        context: TranslationContext(
            profile: .understand,
            privacyPolicy: .maskSensitive,
            routingHints: ProviderRoutingHints(preferLLM: true)
        )
    )

    let result = try #require(await coordinator.translateAll(request).first?.result)
    let interpretation = try #require(result.interpretation)

    #expect(interpretation.textFields.allSatisfy { !$0.contains("PARROTTERM") && !$0.contains("PARROTMASK") })
    #expect(interpretation.intendedMeaning.contains("鹦鹉"))
    #expect(
        interpretation.culturalNotes.first?.explanation.contains("alex@example.com") == true,
        "Restored fields: \(interpretation.textFields)"
    )
    #expect(result.qualitySummary?.issues.contains(.placeholderLeak) == false)
}

private struct InterpretationFixtureProvider: TranslationProvider {
    let id: String
    let supportsInterpretation: Bool
    var displayName: String { id }
    let supportedLanguages: [Language] = [.en, .zh]
    var capabilities: ProviderCapabilities {
        ProviderCapabilities(supportsInterpretation: supportsInterpretation)
    }

    func translate(_ req: TranslateRequest) async throws -> TranslateResult {
        if supportsInterpretation {
            let interpretation = InterpretationResult(
                intendedMeaning: "祝你好运。",
                localizedTranslation: "祝你好运！",
                literalTranslation: "摔断一条腿。",
                culturalNotes: [CulturalNote(expression: "break a leg", explanation: "演出前的祝好运说法。")],
                confidence: 0.95
            )
            return TranslateResult(
                providerId: id,
                translated: interpretation.localizedTranslation,
                interpretation: interpretation
            )
        }
        return TranslateResult(providerId: id, translated: "摔断一条腿。")
    }
}

private struct StructuredEchoProvider: TranslationProvider {
    let id = "structured-echo"
    let displayName = "Structured Echo"
    let supportedLanguages: [Language] = [.en, .zh]
    let capabilities = ProviderCapabilities(
        supportsInterpretation: true,
        terminology: .placeholder
    )

    func translate(_ req: TranslateRequest) async throws -> TranslateResult {
        let interpretation = InterpretationResult(
            intendedMeaning: req.text,
            localizedTranslation: req.text,
            literalTranslation: req.text,
            toneTags: [req.text],
            culturalNotes: [CulturalNote(expression: req.text, explanation: req.text)],
            ambiguities: [InterpretationAlternative(interpretation: req.text, when: req.text)],
            confidence: 0.8,
            confidenceNote: req.text
        )
        return TranslateResult(
            providerId: id,
            translated: req.text,
            interpretation: interpretation
        )
    }
}
