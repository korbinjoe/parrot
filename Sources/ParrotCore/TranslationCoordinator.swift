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
                        let timeout = Self.timeout(for: provider, base: perProviderTimeout)
                        let result = try await Self.withTimeout(timeout) {
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

    /// Fan out to every active provider concurrently and yield each outcome as soon as it finishes.
    /// The stream order is completion order, so fast machine-translation providers can appear before
    /// slower LLM providers finish.
    public func translateIncrementally(_ request: TranslateRequest) -> AsyncStream<AggregatedOutcome> {
        let req = resolved(request)
        let providers = registry.activeProviders()
        let baseTimeout = perProviderTimeout

        return AsyncStream { continuation in
            guard !providers.isEmpty else {
                continuation.finish()
                return
            }

            let task = Task {
                await withTaskGroup(of: AggregatedOutcome.self) { group in
                    for provider in providers {
                        group.addTask {
                            await Self.run(provider, req: req, baseTimeout: baseTimeout)
                        }
                    }
                    for await outcome in group {
                        continuation.yield(outcome)
                    }
                }
                continuation.finish()
            }

            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private static func run(
        _ provider: TranslationProvider,
        req: TranslateRequest,
        baseTimeout: TimeInterval
    ) async -> AggregatedOutcome {
        let start = Date()
        do {
            let timeout = Self.timeout(for: provider, base: baseTimeout)
            let result = try await Self.withTimeout(timeout) {
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

    /// Provider-specific timeout budget for slower LLM services.
    static func timeout(for provider: TranslationProvider, base: TimeInterval) -> TimeInterval {
        if provider.id == "opencode" {
            return max(base, 180)
        }
        if provider.id == "zhipu" {
            return max(base, 90)
        }
        if provider.capabilities.supportsStream {
            return max(base, 45)
        }
        return base
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
