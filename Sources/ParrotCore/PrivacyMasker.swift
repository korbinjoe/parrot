import Foundation

public enum SensitiveEntityType: String, Codable, Sendable, Equatable, Hashable, CaseIterable {
    case email
    case url
    case apiKey
    case numericID
    case phone
}

public struct PrivacyMaskingReport: Codable, Equatable, Sendable {
    public var applied: Bool
    public var policy: PrivacyPolicy
    public var entityCounts: [SensitiveEntityType: Int]

    public init(
        applied: Bool,
        policy: PrivacyPolicy,
        entityCounts: [SensitiveEntityType: Int] = [:]
    ) {
        self.applied = applied
        self.policy = policy
        self.entityCounts = entityCounts
    }

    public var totalCount: Int {
        entityCounts.values.reduce(0, +)
    }
}

public struct PrivacyMaskedText: Sendable, Equatable {
    public let text: String
    public let replacements: [String: String]
    public let report: PrivacyMaskingReport

    public var hasReplacements: Bool { !replacements.isEmpty }
}

public enum PrivacyMasker {
    public static func mask(_ text: String, policy: PrivacyPolicy) -> PrivacyMaskedText {
        guard policy.shouldMaskSensitiveEntities else {
            return PrivacyMaskedText(
                text: text,
                replacements: [:],
                report: PrivacyMaskingReport(applied: false, policy: policy)
            )
        }

        var output = text
        var replacements: [String: String] = [:]
        var counts: [SensitiveEntityType: Int] = [:]

        for entityType in SensitiveEntityType.allCases {
            let matches = ranges(for: entityType, in: output)
            guard !matches.isEmpty else { continue }
            for (offset, range) in matches.enumerated().reversed() {
                let token = token(for: entityType, index: (counts[entityType] ?? 0) + offset + 1)
                replacements[token] = String(output[range])
                output.replaceSubrange(range, with: token)
            }
            counts[entityType, default: 0] += matches.count
        }

        return PrivacyMaskedText(
            text: output,
            replacements: replacements,
            report: PrivacyMaskingReport(applied: !replacements.isEmpty, policy: policy, entityCounts: counts)
        )
    }

    public static func unmask(_ text: String, using masked: PrivacyMaskedText?) -> String {
        guard let masked, masked.hasReplacements else { return text }
        var output = text
        for (token, original) in masked.replacements {
            output = output.replacingOccurrences(of: token, with: original)
        }
        return output
    }

    private static func ranges(for type: SensitiveEntityType, in text: String) -> [Range<String.Index>] {
        let pattern: String
        switch type {
        case .email:
            pattern = #"[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}"#
        case .phone:
            pattern = #"(?<![A-Z0-9])(?:\+?\d[\d \-().]{7,}\d)(?![A-Z0-9])"#
        case .url:
            pattern = #"https?://[^\s<>\"]+"#
        case .apiKey:
            pattern = #"(?<![A-Za-z0-9])(?:sk|pk|rk|ak|xox[baprs]|gh[pousr])[-_][A-Za-z0-9_\-]{12,}(?![A-Za-z0-9])"#
        case .numericID:
            pattern = #"(?<!\d)\d{12,}(?!\d)"#
        }
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return []
        }
        let fullRange = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.matches(in: text, options: [], range: fullRange).compactMap { match in
            Range(match.range, in: text)
        }
    }

    private static func token(for type: SensitiveEntityType, index: Int) -> String {
        "PARROTMASK_\(type.rawValue.uppercased())_\(String(format: "%04d", index))"
    }
}
