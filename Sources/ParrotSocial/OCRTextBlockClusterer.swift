import CoreGraphics
import Foundation
import ParrotCore

public struct OCRTextBlockClusterer: Sendable {
    public init() {}

    public func cluster(
        blocks: [OCRBlock],
        platform: PlatformPreset = .general
    ) -> [QuickLensCandidate] {
        let lines = blocks
            .map(Self.normalizedLine(from:))
            .filter { !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .sorted { lhs, rhs in
                if abs(lhs.rect.minY - rhs.rect.minY) > 0.012 {
                    return lhs.rect.minY < rhs.rect.minY
                }
                return lhs.rect.minX < rhs.rect.minX
            }

        guard !lines.isEmpty else { return [] }

        let groups = group(lines)
        return groups
            .compactMap { makeCandidate(from: $0, platform: platform) }
            .sorted { lhs, rhs in
                if lhs.isNoise != rhs.isNoise { return !lhs.isNoise }
                return lhs.score > rhs.score
            }
    }

    private func group(_ lines: [Line]) -> [[Line]] {
        var groups: [[Line]] = []

        for line in lines {
            guard var last = groups.popLast() else {
                groups.append([line])
                continue
            }

            if shouldMerge(line, into: last) {
                last.append(line)
                groups.append(last)
            } else {
                groups.append(last)
                groups.append([line])
            }
        }

        return groups.flatMap(splitLargeVerticalJumps)
    }

    private func shouldMerge(_ line: Line, into group: [Line]) -> Bool {
        guard let previous = group.last else { return false }
        let verticalGap = line.rect.minY - previous.rect.maxY
        let sameColumnOverlap = horizontalOverlap(line.rect, previous.rect) / max(0.001, min(line.rect.width, previous.rect.width))
        let xDistance = abs(line.rect.minX - previous.rect.minX)
        let compatibleColumn = sameColumnOverlap > 0.16 || xDistance < 0.09
        let closeVertically = verticalGap < max(0.026, previous.rect.height * 2.4)
        let strongIndentChange = xDistance > 0.18 && sameColumnOverlap < 0.08

        if previous.noiseKind == .navigation || line.noiseKind == .navigation {
            return false
        }
        return closeVertically && compatibleColumn && !strongIndentChange
    }

    private func splitLargeVerticalJumps(_ group: [Line]) -> [[Line]] {
        guard group.count > 2 else { return [group] }
        var result: [[Line]] = []
        var current: [Line] = []
        for line in group {
            if let previous = current.last,
               line.rect.minY - previous.rect.maxY > 0.06 {
                result.append(current)
                current = [line]
            } else {
                current.append(line)
            }
        }
        if !current.isEmpty { result.append(current) }
        return result
    }

    private func makeCandidate(from group: [Line], platform: PlatformPreset) -> QuickLensCandidate? {
        let nonNoise = group.filter { !$0.isNoise }
        let bodyLines = nonNoise.isEmpty ? group : nonNoise
        let text = bodyLines.map(\.text).joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }

        let unionRect = bodyLines.map(\.rect).reduce(bodyLines[0].rect) { $0.union($1) }
        let confidence = bodyLines.map(\.confidence).reduce(0, +) / Float(bodyLines.count)
        let isNoise = nonNoise.isEmpty || text.count < 3
        let role = roleHint(for: bodyLines, isNoise: isNoise, platform: platform)
        let score = candidateScore(
            text: text,
            rect: unionRect,
            lineCount: bodyLines.count,
            confidence: confidence,
            role: role,
            isNoise: isNoise,
            platform: platform
        )

        return QuickLensCandidate(
            text: text,
            boundingBox: CGRectCodable(unionRect).clampedUnitRect,
            lineBoxes: bodyLines.map { CGRectCodable($0.rect).clampedUnitRect },
            confidence: confidence,
            score: score,
            debugReason: "lines=\(bodyLines.count) chars=\(text.count) confidence=\(String(format: "%.2f", confidence)) role=\(role.rawValue) noise=\(isNoise)",
            roleHint: role,
            isNoise: isNoise
        )
    }

    private func candidateScore(
        text: String,
        rect: CGRect,
        lineCount: Int,
        confidence: Float,
        role: QuickLensRoleHint,
        isNoise: Bool,
        platform: PlatformPreset
    ) -> Double {
        let tokens = naturalTokenCount(text)
        let charScore = min(Double(text.count) / 180.0, 1.0) * 22
        let tokenScore = min(Double(tokens) / 28.0, 1.0) * 28
        let lineScore = min(Double(lineCount) / 5.0, 1.0) * 14
        let areaScore = min(Double(rect.width * rect.height) / 0.22, 1.0) * 12
        let centerY = rect.midY
        let centerX = rect.midX
        let centerScore = max(0, 1 - abs(centerY - 0.48) * 1.7) * 13
            + max(0, 1 - abs(centerX - 0.52) * 1.2) * 5
        let confidenceScore = Double(confidence) * 10
        let roleScore: Double
        switch role {
        case .primaryBody, .comment:
            roleScore = platform == .general ? 10 : 13
        case .quote:
            roleScore = 7
        case .unknown:
            roleScore = 0
        case .username, .timestamp, .navigation:
            roleScore = -30
        }

        let edgePenalty = (rect.minY < 0.07 || rect.maxY > 0.92) ? 18.0 : 0
        let noisePenalty = isNoise ? 60.0 : 0
        return charScore + tokenScore + lineScore + areaScore + centerScore + confidenceScore + roleScore - edgePenalty - noisePenalty
    }

    private func roleHint(for lines: [Line], isNoise: Bool, platform: PlatformPreset) -> QuickLensRoleHint {
        if isNoise {
            if lines.contains(where: { $0.noiseKind == .timestamp }) { return .timestamp }
            if lines.contains(where: { $0.noiseKind == .username }) { return .username }
            if lines.contains(where: { $0.noiseKind == .navigation }) { return .navigation }
            return .unknown
        }

        let text = lines.map(\.text).joined(separator: " ").lowercased()
        if text.contains("quote") || text.contains("reposted") {
            return .quote
        }
        if platform == .reddit || text.contains("reddit") || text.contains("comment") {
            return .comment
        }
        return .primaryBody
    }

    private func naturalTokenCount(_ text: String) -> Int {
        text
            .split { !$0.isLetter && !$0.isNumber && $0 != "'" }
            .filter { token in
                token.count > 1 && token.contains { $0.isLetter }
            }
            .count
    }

    private func horizontalOverlap(_ a: CGRect, _ b: CGRect) -> CGFloat {
        max(0, min(a.maxX, b.maxX) - max(a.minX, b.minX))
    }

    private static func normalizedLine(from block: OCRBlock) -> Line {
        let source = block.boundingBox
        let topLeftRect: CGRect
        if source == .zero {
            topLeftRect = CGRect(x: 0.08, y: 0.12, width: 0.84, height: 0.04)
        } else {
            topLeftRect = CGRect(
                x: source.minX,
                y: 1 - source.maxY,
                width: source.width,
                height: source.height
            )
        }
        let text = block.text.trimmingCharacters(in: .whitespacesAndNewlines)
        let noiseKind = classifyNoise(text: text, rect: topLeftRect)
        return Line(text: text, rect: topLeftRect, confidence: block.confidence, noiseKind: noiseKind)
    }

    private static func classifyNoise(text: String, rect: CGRect) -> NoiseKind? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = trimmed.lowercased()
        if trimmed.isEmpty { return .navigation }

        if rect.minY < 0.055, trimmed.range(of: #"^\d{1,2}:\d{2}$"#, options: .regularExpression) != nil {
            return .navigation
        }
        if rect.maxY > 0.92, ["home", "search", "notifications", "messages", "inbox", "profile"].contains(lower) {
            return .navigation
        }
        if ["reply", "share", "like", "more", "post", "send", "cancel"].contains(lower) {
            return .navigation
        }
        if trimmed.range(of: #"^(@[\w._-]+|u/[\w._-]+|r/[\w._-]+)$"#, options: .regularExpression) != nil {
            return .username
        }
        if trimmed.range(of: #"^(\d+[smhdwy]|now|today|yesterday|[0-2]?\d:[0-5]\d\s?(am|pm)?)(\s*[·•]\s*.*)?$"#, options: [.regularExpression, .caseInsensitive]) != nil {
            return .timestamp
        }
        if trimmed.range(of: #"^\d+(\.\d+)?[kKmM]?\s*(replies|reply|likes|comments|shares|views|votes)?$"#, options: .regularExpression) != nil {
            return .timestamp
        }
        if lower.range(of: #"^(liked by|follow|following|promoted)$"#, options: .regularExpression) != nil {
            return .navigation
        }
        return nil
    }

    private struct Line {
        var text: String
        var rect: CGRect
        var confidence: Float
        var noiseKind: NoiseKind?

        var isNoise: Bool { noiseKind != nil }
    }

    private enum NoiseKind {
        case username
        case timestamp
        case navigation
    }
}
