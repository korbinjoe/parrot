import Foundation

public struct OCRTextCleaner: Sendable {
    public init() {}

    public func removeUsernames(_ text: String) -> String {
        text
            .components(separatedBy: .newlines)
            .filter { line in
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                return !trimmed.hasPrefix("u/") && !trimmed.hasPrefix("@")
            }
            .joined(separator: "\n")
    }

    public func removeTimestamps(_ text: String) -> String {
        text
            .components(separatedBy: .newlines)
            .filter { line in
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                if trimmed.range(of: #"^\d+\s*(s|m|h|d|w|mo|y)\b"#, options: .regularExpression) != nil {
                    return false
                }
                if trimmed.contains("replies") || trimmed.contains("reply") || trimmed.contains("upvotes") {
                    return false
                }
                return true
            }
            .joined(separator: "\n")
    }

    public func joinBrokenLines(_ text: String) -> String {
        text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    public func deleteEmptyLines(_ text: String) -> String {
        text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
    }
}
