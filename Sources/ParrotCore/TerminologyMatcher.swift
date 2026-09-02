import Foundation

public enum TerminologyMatcher {
    public static func applicableEntries(
        in snapshot: TerminologySnapshot?,
        from: Language,
        to: Language,
        mode: TranslateMode
    ) -> [TerminologyEntry] {
        guard mode != .lookup, let snapshot else { return [] }
        return snapshot.entries
            .filter { entry in
                entry.enabled
                    && entry.isValid
                    && languageMatches(entry.from, request: from, allowAuto: true)
                    && languageMatches(entry.to, request: to, allowAuto: false)
            }
            .sorted {
                if $0.trimmedSource.count == $1.trimmedSource.count {
                    return $0.trimmedSource < $1.trimmedSource
                }
                return $0.trimmedSource.count > $1.trimmedSource.count
            }
    }

    public static func matches(
        in text: String,
        snapshot: TerminologySnapshot?,
        from: Language,
        to: Language,
        mode: TranslateMode
    ) -> [TerminologyMatch] {
        let entries = applicableEntries(in: snapshot, from: from, to: to, mode: mode)
        guard !entries.isEmpty, !text.isEmpty else { return [] }

        let reservedRanges = privacyPlaceholderRanges(in: text)
        var ranges: [Range<String.Index>] = []
        var matches: [TerminologyMatch] = []
        for entry in entries {
            for range in findRanges(of: entry.trimmedSource, in: text, caseSensitive: entry.caseSensitive) {
                guard !reservedRanges.contains(where: { overlaps($0, range) }) else { continue }
                guard !ranges.contains(where: { overlaps($0, range) }) else { continue }
                ranges.append(range)
                matches.append(TerminologyMatch(entry: entry, range: range))
            }
        }
        return matches.sorted { lhs, rhs in
            guard let l = lhs.range, let r = rhs.range else { return lhs.source < rhs.source }
            return l.lowerBound < r.lowerBound
        }
    }

    private static func languageMatches(_ entry: Language, request: Language, allowAuto: Bool) -> Bool {
        if allowAuto && entry == .auto { return true }
        return normalized(entry) == normalized(request)
    }

    private static func normalized(_ language: Language) -> String {
        language.code?.lowercased() ?? "auto"
    }

    private static func findRanges(
        of needle: String,
        in haystack: String,
        caseSensitive: Bool
    ) -> [Range<String.Index>] {
        guard !needle.isEmpty else { return [] }
        var result: [Range<String.Index>] = []
        var searchStart = haystack.startIndex
        let options: String.CompareOptions = caseSensitive ? [] : [.caseInsensitive, .diacriticInsensitive]
        while searchStart < haystack.endIndex,
              let range = haystack.range(of: needle, options: options, range: searchStart..<haystack.endIndex) {
            result.append(range)
            searchStart = range.upperBound
        }
        return result
    }

    private static func privacyPlaceholderRanges(in text: String) -> [Range<String.Index>] {
        guard let regex = try? NSRegularExpression(
            pattern: #"PARROTMASK_[A-Z]+_[0-9]{4}"#,
            options: [.caseInsensitive]
        ) else { return [] }
        let fullRange = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.matches(in: text, range: fullRange).compactMap { match in
            Range(match.range, in: text)
        }
    }

    private static func overlaps(_ lhs: Range<String.Index>, _ rhs: Range<String.Index>) -> Bool {
        lhs.lowerBound < rhs.upperBound && rhs.lowerBound < lhs.upperBound
    }
}
