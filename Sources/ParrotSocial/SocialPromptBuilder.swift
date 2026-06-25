import Foundation
import ParrotCore

public struct SocialPromptBuilder: Sendable {
    public init() {}

    public func understandPrompt(
        for session: SocialTextSession,
        targetLanguage: Language = .zh
    ) -> String {
        """
        You are Parrot, a social reading assistant.
        Explain the following \(session.platform.displayName) text for a user whose preferred explanation language is \(targetLanguage.socialDisplayName).

        Return JSON only with this shape:
        {
          "meaningSummary": "short practical explanation",
          "toneTags": ["tag"],
          "phraseExplanations": [{"phrase": "text", "explanation": "meaning and usage"}],
          "fullTranslation": "literal but natural translation",
          "confidenceNote": "optional note when context is ambiguous"
        }

        Rules:
        - Explain implied meaning before literal translation.
        - Identify sarcasm, disagreement, jokes, hostility, formality, slang, and platform-specific phrasing.
        - Do not invent external facts.
        - Keep the summary concise.

        Source:
        \(session.sourceDraft)
        """
    }

    public func expressPrompt(
        for session: SocialTextSession,
        targetLanguage: Language = .en
    ) -> String {
        if session.mode == .polish {
            return polishPrompt(for: session, targetLanguage: targetLanguage)
        }

        let context = session.contextText ?? session.sourceDraft
        return """
        You are Parrot, a native speaker-style social writing assistant.
        Turn the user's intent into \(targetLanguage.socialDisplayName) replies for \(session.platform.displayName).

        Return JSON only with this shape:
        {
          "candidates": [
            {"title": "Natural reply", "text": "reply", "tone": "natural"},
            {"title": "Short version", "text": "reply", "tone": "xShort"},
            {"title": "Polite disagreement", "text": "reply", "tone": "politeDisagreement"}
          ]
        }

        Rules:
        - Preserve the user's stance.
        - Avoid corporate or obviously AI-polished language.
        - Match tone preset: \(session.selectedTone.displayName).
        - Do not add facts the user did not provide.

        Context:
        \(context)

        User intent:
        \(session.userIntentDraft)
        """
    }

    private func polishPrompt(
        for session: SocialTextSession,
        targetLanguage: Language
    ) -> String {
        """
        You are Parrot, a native speaker-style writing assistant.
        Rewrite the rough draft into natural \(targetLanguage.socialDisplayName) while preserving the user's intent and stance.

        Return JSON only with this shape:
        {
          "candidates": [
            {"title": "Native polish", "text": "polished draft", "tone": "natural"},
            {"title": "Warmer", "text": "polished draft", "tone": "friendly"},
            {"title": "Sharper", "text": "polished draft", "tone": "firm"}
          ]
        }

        Rules:
        - Preserve meaning, claims, and attitude.
        - Make the draft sound native, not corporate or obviously AI-polished.
        - Match tone preset: \(session.selectedTone.displayName).
        - Do not add facts the user did not provide.
        - Keep the primary result copy-ready.

        Rough draft:
        \(session.sourceDraft)
        """
    }

    public func refinePrompt(
        candidate: ReplyCandidate,
        action: RefinementAction,
        session: SocialTextSession
    ) -> String {
        if session.mode == .polish {
            return """
            Rewrite this polished draft using the action "\(action.displayName)".
            Preserve the user's stance and do not add new facts.

            Original draft: \(session.sourceDraft)
            Current polished draft: \(candidate.text)

            Output only the rewritten draft.
            """
        }

        return """
        Rewrite this social reply using the action "\(action.displayName)".
        Preserve the user's stance and do not add new facts.

        Platform: \(session.platform.displayName)
        Context: \(session.contextText ?? session.sourceDraft)
        User intent: \(session.userIntentDraft)
        Current reply: \(candidate.text)

        Output only the rewritten reply.
        """
    }
}
