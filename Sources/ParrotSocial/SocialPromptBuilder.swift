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

    public func refinePrompt(
        candidate: ReplyCandidate,
        action: RefinementAction,
        session: SocialTextSession
    ) -> String {
        """
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
