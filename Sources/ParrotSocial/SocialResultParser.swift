import Foundation

public enum SocialResultParserError: Error, Equatable {
    case invalidJSON
    case missingRequiredField(String)
}

public struct SocialResultParser: Sendable {
    private let decoder: JSONDecoder

    public init(decoder: JSONDecoder = JSONDecoder()) {
        self.decoder = decoder
    }

    public func parseUnderstand(_ raw: String) throws -> UnderstandResult {
        let data = try jsonData(from: raw)
        do {
            let result = try decoder.decode(UnderstandResult.self, from: data)
            guard !result.meaningSummary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw SocialResultParserError.missingRequiredField("meaningSummary")
            }
            return result
        } catch let error as SocialResultParserError {
            throw error
        } catch {
            throw SocialResultParserError.invalidJSON
        }
    }

    public func parseExpress(_ raw: String) throws -> ExpressResult {
        let data = try jsonData(from: raw)
        do {
            let result = try decoder.decode(ExpressResult.self, from: data)
            guard result.candidates.contains(where: { !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) else {
                throw SocialResultParserError.missingRequiredField("candidates")
            }
            return result
        } catch let error as SocialResultParserError {
            throw error
        } catch {
            throw SocialResultParserError.invalidJSON
        }
    }

    public func fallbackUnderstand(from raw: String, source: String) -> UnderstandResult {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return UnderstandResult(
            meaningSummary: trimmed.isEmpty ? "No structured explanation was returned." : trimmed,
            toneTags: ["unstructured"],
            phraseExplanations: [],
            fullTranslation: source,
            confidenceNote: "The provider did not return structured JSON."
        )
    }

    public func fallbackExpress(from raw: String, tone: TonePreset) -> ExpressResult {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return ExpressResult(candidates: [
            ReplyCandidate(title: "Provider reply", text: trimmed, tone: tone)
        ])
    }

    private func jsonData(from raw: String) throws -> Data {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if let data = trimmed.data(using: .utf8),
           (try? JSONSerialization.jsonObject(with: data)) != nil {
            return data
        }
        if let start = trimmed.firstIndex(of: "{"),
           let end = trimmed.lastIndex(of: "}"),
           start <= end {
            let json = String(trimmed[start...end])
            if let data = json.data(using: .utf8),
               (try? JSONSerialization.jsonObject(with: data)) != nil {
                return data
            }
        }
        throw SocialResultParserError.invalidJSON
    }
}
