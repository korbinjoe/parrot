import Foundation

public enum ParagraphSegmenter {
    public static func segment(_ text: String) -> [ParagraphHint] {
        let normalized = text.replacingOccurrences(of: "\r\n", with: "\n")
        let rawParagraphs = normalized.components(separatedBy: "\n\n")
        let paragraphs: [String]
        if rawParagraphs.count > 1 {
            paragraphs = rawParagraphs
        } else {
            paragraphs = fallbackSegments(for: normalized)
        }
        return paragraphs.enumerated().compactMap { index, raw in
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return nil }
            return ParagraphHint(
                source: trimmed,
                ordinal: index,
                isProtected: isProtectedBlock(trimmed)
            )
        }
    }

    private static func fallbackSegments(for text: String) -> [String] {
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        guard lines.count > 1 else { return [text] }
        var segments: [String] = []
        var current: [String] = []
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                if !current.isEmpty {
                    segments.append(current.joined(separator: "\n"))
                    current.removeAll()
                }
            } else if isListLine(trimmed) || isCodeFence(trimmed) {
                if !current.isEmpty {
                    segments.append(current.joined(separator: "\n"))
                    current.removeAll()
                }
                segments.append(line)
            } else {
                current.append(line)
            }
        }
        if !current.isEmpty {
            segments.append(current.joined(separator: "\n"))
        }
        return segments.isEmpty ? [text] : segments
    }

    private static func isProtectedBlock(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return isCodeFence(trimmed)
            || trimmed.contains("\n|")
            || trimmed.hasPrefix("|")
            || trimmed.contains("```")
    }

    private static func isCodeFence(_ text: String) -> Bool {
        text.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("```")
    }

    private static func isListLine(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        return trimmed.hasPrefix("- ")
            || trimmed.hasPrefix("* ")
            || trimmed.hasPrefix("1. ")
    }
}

