import Foundation

public struct ProtectedTerminologyText: Sendable {
    public let text: String
    public let matches: [TerminologyMatch]
    public let replacements: [String: String]

    public var hasMatches: Bool { !matches.isEmpty }
}

public enum TerminologyProcessor {
    public static func protect(_ req: TranslateRequest) -> ProtectedTerminologyText {
        let matches = TerminologyMatcher.matches(
            in: req.text,
            snapshot: req.terminology,
            from: req.from,
            to: req.to,
            mode: req.mode
        )
        guard !matches.isEmpty else {
            return ProtectedTerminologyText(text: req.text, matches: [], replacements: [:])
        }

        var protected = req.text
        var replacements: [String: String] = [:]
        for (idx, match) in matches.enumerated().reversed() {
            guard let range = match.range else { continue }
            let token = token(for: idx)
            protected.replaceSubrange(range, with: token)
            replacements[token] = match.target
        }
        return ProtectedTerminologyText(text: protected, matches: matches, replacements: replacements)
    }

    public static func restore(
        _ translated: String,
        using protected: ProtectedTerminologyText
    ) -> (text: String, succeeded: Bool) {
        guard protected.hasMatches else { return (translated, true) }
        var output = translated
        var succeeded = true
        for (token, target) in protected.replacements {
            if output.contains(token) {
                output = output.replacingOccurrences(of: token, with: target)
            } else if let range = output.range(of: token, options: [.caseInsensitive]) {
                output.replaceSubrange(range, with: target)
            } else if !output.localizedCaseInsensitiveContains(target) {
                succeeded = false
            }
        }
        return (output, succeeded)
    }

    public static func promptConstraints(for req: TranslateRequest) -> [TerminologyMatch] {
        TerminologyMatcher.applicableEntries(
            in: req.terminology,
            from: req.from,
            to: req.to,
            mode: req.mode
        ).map { TerminologyMatch(entry: $0) }
    }

    public static func promptBlock(for req: TranslateRequest) -> String? {
        let matches = promptConstraints(for: req)
        guard !matches.isEmpty else { return nil }
        let lines = matches.map { "- \($0.source) => \($0.target)" }.joined(separator: "\n")
        return """

        Terminology constraints:
        \(lines)

        Use the exact target term whenever the source term appears. Do not translate, localize, or paraphrase protected product names unless the terminology list provides that target wording.
        """
    }

    private static func token(for index: Int) -> String {
        String(format: "PARROTTERM%04d", index + 1)
    }
}
