import Foundation
import ParrotCore

public protocol SocialUnderstandingService: Sendable {
    func understand(session: SocialTextSession) async throws -> UnderstandResult
}

public protocol SocialExpressionService: Sendable {
    func generateReplies(session: SocialTextSession) async throws -> ExpressResult
    func refine(candidate: ReplyCandidate, action: RefinementAction, session: SocialTextSession) async throws -> ReplyCandidate
}

public struct ProviderBackedSocialService: SocialUnderstandingService, SocialExpressionService {
    private let provider: TranslationProvider
    private let parser: SocialResultParser
    private let prompts: SocialPromptBuilder

    public init(
        provider: TranslationProvider,
        parser: SocialResultParser = SocialResultParser(),
        prompts: SocialPromptBuilder = SocialPromptBuilder()
    ) {
        self.provider = provider
        self.parser = parser
        self.prompts = prompts
    }

    public func understand(session: SocialTextSession) async throws -> UnderstandResult {
        let prompt = prompts.understandPrompt(for: session)
        let result = try await provider.translate(TranslateRequest(text: prompt, from: .auto, to: .zh, mode: .translate))
        do {
            return try parser.parseUnderstand(result.translated)
        } catch {
            return parser.fallbackUnderstand(from: result.translated, source: session.sourceDraft)
        }
    }

    public func generateReplies(session: SocialTextSession) async throws -> ExpressResult {
        let prompt = prompts.expressPrompt(for: session)
        let result = try await provider.translate(TranslateRequest(text: prompt, from: .auto, to: .en, mode: .polish))
        do {
            return try parser.parseExpress(result.translated)
        } catch {
            return parser.fallbackExpress(from: result.translated, tone: session.selectedTone)
        }
    }

    public func refine(candidate: ReplyCandidate, action: RefinementAction, session: SocialTextSession) async throws -> ReplyCandidate {
        let prompt = prompts.refinePrompt(candidate: candidate, action: action, session: session)
        let result = try await provider.translate(TranslateRequest(text: prompt, from: .auto, to: .en, mode: .polish))
        var updated = candidate
        updated.text = result.translated.trimmingCharacters(in: .whitespacesAndNewlines)
        return updated
    }
}

public struct TranslationAugmentedSocialService<Base: SocialUnderstandingService & SocialExpressionService>: SocialUnderstandingService, SocialExpressionService {
    private let base: Base
    private let translationProvider: TranslationProvider
    private let directionResolver: TranslationDirectionResolver
    private let defaultTarget: Language
    private let translationTimeout: TimeInterval
    private let terminologySnapshot: @Sendable () -> TerminologySnapshot?

    public init(
        base: Base,
        translationProvider: TranslationProvider,
        directionResolver: TranslationDirectionResolver = TranslationDirectionResolver(),
        defaultTarget: Language = .zh,
        translationTimeout: TimeInterval = 8,
        terminologySnapshot: @escaping @Sendable () -> TerminologySnapshot? = { nil }
    ) {
        self.base = base
        self.translationProvider = translationProvider
        self.directionResolver = directionResolver
        self.defaultTarget = defaultTarget
        self.translationTimeout = translationTimeout
        self.terminologySnapshot = terminologySnapshot
    }

    public func understand(session: SocialTextSession) async throws -> UnderstandResult {
        async let baseResult = base.understand(session: session)
        async let translation = translateSource(session.sourceDraftTrimmed)

        var result = try await baseResult
        do {
            let translated = try await translation
            let trimmed = translated.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                result.fullTranslation = trimmed
            }
        } catch {
            if result.fullTranslation?.trimmingCharacters(in: .whitespacesAndNewlines) == session.sourceDraftTrimmed {
                result.fullTranslation = nil
            }
            result.confidenceNote = Self.append(
                result.confidenceNote,
                note: "Translation is temporarily unavailable. The source text was still recognized correctly."
            )
        }
        return result
    }

    public func generateReplies(session: SocialTextSession) async throws -> ExpressResult {
        try await base.generateReplies(session: session)
    }

    public func refine(candidate: ReplyCandidate, action: RefinementAction, session: SocialTextSession) async throws -> ReplyCandidate {
        try await base.refine(candidate: candidate, action: action, session: session)
    }

    private func translateSource(_ text: String) async throws -> String {
        guard !text.isEmpty else { return "" }
        let direction = directionResolver.resolve(text: text, from: .auto, to: defaultTarget)
        let request = TranslateRequest(
            text: text,
            from: direction.from,
            to: direction.to,
            mode: .translate,
            terminology: terminologySnapshot()
        )
        return try await withTimeout(translationTimeout) {
            (try await translationProvider.translate(request)).translated
        }
    }

    private func withTimeout<T: Sendable>(
        _ seconds: TimeInterval,
        operation: @escaping @Sendable () async throws -> T
    ) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask { try await operation() }
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw ProviderError.timeout
            }
            guard let first = try await group.next() else { throw ProviderError.timeout }
            group.cancelAll()
            return first
        }
    }

    private static func append(_ existing: String?, note: String) -> String {
        guard let existing, !existing.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return note
        }
        return existing + " " + note
    }
}

public struct RuleBasedSocialService: SocialUnderstandingService, SocialExpressionService {
    public init() {}

    public func understand(session: SocialTextSession) async throws -> UnderstandResult {
        let text = session.sourceDraftTrimmed
        let lower = text.lowercased()
        var tags: [String] = []
        var phrases: [PhraseExplanation] = []

        if lower.contains("not bad") {
            tags.append("qualified praise")
            phrases.append(PhraseExplanation(phrase: "not bad", explanation: "It usually means acceptable, with room for criticism."))
        }
        if lower.contains("roadmap") {
            tags.append("product critique")
            phrases.append(PhraseExplanation(phrase: "roadmap doc", explanation: "Internal planning language; often contrasts ideal plans with real usage."))
        }
        if lower.contains("onboarding") {
            tags.append("UX feedback")
            phrases.append(PhraseExplanation(phrase: "onboarding", explanation: "The first-run experience that helps new users understand value and setup."))
        }
        if lower.contains("collapses") {
            tags.append("sharp")
            phrases.append(PhraseExplanation(phrase: "collapses", explanation: "Here it means the experience fails under real user behavior."))
        }
        if tags.isEmpty {
            tags = ["social context", session.platform.displayName]
        }

        let meaning: String
        if lower.contains("onboarding") || lower.contains("first-run") {
            meaning = "这段内容主要在批评首次使用流程：产品或功能可能有价值，但太早让用户做决定，导致新用户难以理解收益。"
        } else if lower.contains("roadmap") || lower.contains("collapses") {
            meaning = "这段内容的意思是：功能在规划文档里听起来不错，但一到真实用户手里就暴露体验问题。"
        } else {
            meaning = "这段内容需要结合社交语境理解：它不只是字面翻译，还包含说话者的态度、立场和隐含评价。"
        }

        return UnderstandResult(
            meaningSummary: meaning,
            toneTags: Array(Set(tags)).sorted(),
            phraseExplanations: phrases,
            fullTranslation: text,
            confidenceNote: nil
        )
    }

    public func generateReplies(session: SocialTextSession) async throws -> ExpressResult {
        if session.mode == .polish {
            return polishDraft(session: session)
        }

        let intent = session.userIntentTrimmed.isEmpty ? session.sourceDraftTrimmed : session.userIntentTrimmed
        let base = englishReply(from: intent, platform: session.platform)
        let candidates = [
            ReplyCandidate(title: "Natural reply", text: toneAdjusted(base, tone: session.selectedTone), tone: session.selectedTone),
            ReplyCandidate(title: "Short version", text: "Fair take. Solid idea, but the first-run experience asks too much too early.", tone: .xShort),
            ReplyCandidate(title: "Polite disagreement", text: "I would not call the feature broken, but I do think the onboarding needs to show value before asking for setup.", tone: .politeDisagreement)
        ]
        return ExpressResult(candidates: candidates)
    }

    public func refine(candidate: ReplyCandidate, action: RefinementAction, session: SocialTextSession) async throws -> ReplyCandidate {
        if session.mode == .polish {
            return refinePolish(candidate: candidate, action: action)
        }

        var updated = candidate
        switch action {
        case .shorter:
            updated.text = "Fair take. Good product, but the onboarding asks too much too early."
            updated.tone = .xShort
        case .moreCasual:
            updated.text = "Yeah, I think they have a point. The product seems solid, but onboarding makes people work too hard before they see the value."
            updated.tone = .friendly
        case .morePolite:
            updated.text = "I think that is a fair point. The product seems useful, but the first-run flow could do a better job showing value before asking for setup."
            updated.tone = .politeDisagreement
        case .keepMyAttitude:
            updated.text = candidate.text
        case .addContext:
            updated.text = candidate.text + " That sequencing matters because users need confidence before they commit to configuration."
        }
        return updated
    }

    private func polishDraft(session: SocialTextSession) -> ExpressResult {
        let base = polishedDraft(from: session.sourceDraftTrimmed, tone: session.selectedTone)
        let candidates = [
            ReplyCandidate(title: "Native polish", text: base, tone: session.selectedTone),
            ReplyCandidate(
                title: "Warmer",
                text: "I can see the value in this, but the onboarding still leaves me a bit unsure about where to start.",
                tone: .friendly
            ),
            ReplyCandidate(
                title: "Sharper",
                text: "The product has value, but the onboarding makes it harder to understand than it should be.",
                tone: .firm
            )
        ]
        return ExpressResult(candidates: candidates)
    }

    private func refinePolish(candidate: ReplyCandidate, action: RefinementAction) -> ReplyCandidate {
        var updated = candidate
        switch action {
        case .shorter:
            updated.text = "Useful product, confusing onboarding."
            updated.tone = .xShort
        case .moreCasual:
            updated.text = "I like the idea, but the onboarding still makes it harder to get started than it should."
            updated.tone = .friendly
        case .morePolite:
            updated.text = "The product seems useful, but the onboarding could do more to help new users understand the value sooner."
            updated.tone = .politeDisagreement
        case .keepMyAttitude:
            updated.text = candidate.text
        case .addContext:
            updated.text = candidate.text + " A clearer first step would make the value easier to see."
        }
        return updated
    }

    private func englishReply(from intent: String, platform: PlatformPreset) -> String {
        let lower = intent.lowercased()
        if lower.contains("onboarding") || lower.contains("新用户") || lower.contains("第一次") || lower.contains("迷路") {
            if platform == .reddit {
                return "I think that's a fair read. The product itself seems solid, but the onboarding asks people to do too much before they understand the value."
            }
            return "That's a fair take. The product is solid, but the first-run experience makes people work too hard before they see the value."
        }
        if lower.contains("不同意") || lower.contains("反驳") {
            return "I see the point, but I do not fully agree. The issue feels more about the flow than the core idea."
        }
        return "I think the point is fair. The idea can work, but the experience needs to make the value clearer before asking users to commit."
    }

    private func toneAdjusted(_ text: String, tone: TonePreset) -> String {
        switch tone {
        case .natural:
            return text
        case .friendly:
            return "Yeah, " + text.prefix(1).lowercased() + text.dropFirst()
        case .firm:
            return "The issue is not the feature. It is the sequence. Users should see the payoff before being asked to make setup decisions."
        case .redditStyle:
            return "This feels like a classic 'great in the roadmap, confusing in the first 30 seconds' problem."
        case .xShort:
            return "Good feature, bad first-run flow."
        case .politeDisagreement:
            return "I would frame it slightly differently: " + text.prefix(1).lowercased() + text.dropFirst()
        }
    }

    private func polishedDraft(from draft: String, tone: TonePreset) -> String {
        let lower = draft.lowercased()
        let base: String
        if lower.contains("onboarding") || lower.contains("first-run") || lower.contains("新用户") || lower.contains("第一次") {
            base = "The product is useful, but the onboarding still makes new users work too hard before they understand the value."
        } else if lower.contains("roadmap") {
            base = "The roadmap sounds promising, but the experience needs to hold up when real users try it."
        } else if draft.isEmpty {
            base = ""
        } else {
            base = draft.prefix(1).uppercased() + draft.dropFirst()
        }

        switch tone {
        case .natural:
            return base
        case .friendly:
            return "I think " + base.prefix(1).lowercased() + base.dropFirst()
        case .firm:
            return "The core issue is clear: " + base.prefix(1).lowercased() + base.dropFirst()
        case .redditStyle:
            return "This reads like a solid idea running into a messy first-run experience."
        case .xShort:
            return "Useful product, confusing onboarding."
        case .politeDisagreement:
            return "I would phrase it this way: " + base.prefix(1).lowercased() + base.dropFirst()
        }
    }
}
