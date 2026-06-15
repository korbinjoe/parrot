import Foundation

/// The single abstraction every translation source implements — built-in engines and plugins alike.
/// New engines plug in by conforming to this protocol and registering with `ProviderRegistry`;
/// the orchestration layer and UI never change.
public protocol TranslationProvider: Sendable {
    var id: String { get }
    var displayName: String { get }
    var supportedLanguages: [Language] { get }
    var capabilities: ProviderCapabilities { get }

    func configure(_ config: ProviderConfig) throws
    func translate(_ req: TranslateRequest) async throws -> TranslateResult
    /// Incremental output for streaming-capable engines (LLMs). Default impl bridges `translate`.
    func stream(_ req: TranslateRequest) -> AsyncThrowingStream<String, Error>
}

public extension TranslationProvider {
    func configure(_ config: ProviderConfig) throws {}

    func stream(_ req: TranslateRequest) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    let result = try await self.translate(req)
                    continuation.yield(result.translated)
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}
