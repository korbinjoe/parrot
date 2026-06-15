import Foundation

/// One engine's slot in the aggregated comparison view: either a result or an isolated error.
public struct AggregatedOutcome: Sendable {
    public let providerId: String
    public let displayName: String
    public let result: TranslateResult?
    public let error: ProviderError?
    public let latencyMs: Int

    public var isSuccess: Bool { result != nil }
}

/// Orchestrates language detection + concurrent fan-out across all active providers.
/// A single provider failing produces an error slot and never affects the others.
public actor TranslationCoordinator {
    private let registry: ProviderRegistry
    private let detector: LanguageDetector
    private let perProviderTimeout: TimeInterval

    public init(registry: ProviderRegistry,
                detector: LanguageDetector = LanguageDetector(),
                perProviderTimeout: TimeInterval = 15) {
        self.registry = registry
        self.detector = detector
        self.perProviderTimeout = perProviderTimeout
    }

    /// Resolve `.auto` source language before dispatching.
    private func resolved(_ req: TranslateRequest) -> TranslateRequest {
        guard req.from == .auto else { return req }
        let detected = detector.detect(req.text) ?? .auto
        return TranslateRequest(text: req.text, from: detected, to: req.to, mode: req.mode)
    }

    /// Fan out to every active provider concurrently, preserving registry order in the output.
    public func translateAll(_ request: TranslateRequest) async -> [AggregatedOutcome] {
        let req = resolved(request)
        let providers = registry.activeProviders()
        guard !providers.isEmpty else { return [] }

        var outcomes: [String: AggregatedOutcome] = [:]

        await withTaskGroup(of: AggregatedOutcome.self) { group in
            for provider in providers {
                group.addTask { [perProviderTimeout] in
                    let start = Date()
                    do {
                        let result = try await Self.withTimeout(perProviderTimeout) {
                            try await provider.translate(req)
                        }
                        return AggregatedOutcome(
                            providerId: provider.id,
                            displayName: provider.displayName,
                            result: result,
                            error: nil,
                            latencyMs: Int(Date().timeIntervalSince(start) * 1000)
                        )
                    } catch {
                        let pErr = (error as? ProviderError) ?? .network
                        return AggregatedOutcome(
                            providerId: provider.id,
                            displayName: provider.displayName,
                            result: nil,
                            error: pErr,
                            latencyMs: Int(Date().timeIntervalSince(start) * 1000)
                        )
                    }
                }
            }
            for await outcome in group {
                outcomes[outcome.providerId] = outcome
            }
        }

        // Preserve display order from the registry.
        return providers.compactMap { outcomes[$0.id] }
    }

    /// Runs `operation` with a timeout, throwing `ProviderError.timeout` if it overruns.
    static func withTimeout<T: Sendable>(_ seconds: TimeInterval,
                                         operation: @escaping @Sendable () async throws -> T) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask { try await operation() }
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw ProviderError.timeout
            }
            guard let first = try await group.next() else { throw ProviderError.timeout }
            group.cancelAll()
            return first
        }
    }
}
