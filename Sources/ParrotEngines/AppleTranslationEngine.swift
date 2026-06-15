import Foundation
import ParrotCore

/// Apple on-device Translation (macOS 15+). No API key required.
/// Requires building with Xcode 16+ against macOS 15 SDK for live translation; CLI builds register a no-op stub.
public final class AppleTranslationEngine: HTTPTranslationEngine, @unchecked Sendable {
    public static var isSupported: Bool {
        if #available(macOS 15.0, *) {
            return ProcessInfo.processInfo.operatingSystemVersion.majorVersion >= 15
        }
        return false
    }

    public init(session: URLSession = .shared) {
        super.init(id: "apple", displayName: "系统翻译", session: session)
    }

    public override func translate(_ req: TranslateRequest) async throws -> TranslateResult {
        guard Self.isSupported else { throw ProviderError.unsupportedLanguage }
        throw ProviderError.unsupportedLanguage
    }
}
