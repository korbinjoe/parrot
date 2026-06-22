import Foundation

/// One engine's slot in the aggregated comparison view: either a result or an isolated error.
public struct AggregatedOutcome: Sendable {
    public let providerId: String
    public let displayName: String
    public let modelName: String?
    public let result: TranslateResult?
    public let error: ProviderError?
    public let latencyMs: Int

    public init(
        providerId: String,
        displayName: String,
        modelName: String? = nil,
        result: TranslateResult?,
        error: ProviderError?,
        latencyMs: Int
    ) {
        self.providerId = providerId
        self.displayName = displayName
        self.modelName = modelName
        self.result = result
        self.error = error
        self.latencyMs = latencyMs
    }

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
        let direction = TranslationDirectionResolver(detector: detector)
            .resolve(text: req.text, from: req.from, to: req.to)
        return TranslateRequest(
            text: req.text,
            from: direction.from,
            to: direction.to,
            mode: req.mode,
            terminology: req.terminology
        )
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
                    await Self.runProvider(provider, req: req, baseTimeout: perProviderTimeout)
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
                            await Self.runProvider(provider, req: req, baseTimeout: baseTimeout)
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

    public static func runProvider(
        _ provider: TranslationProvider,
        req: TranslateRequest,
        baseTimeout: TimeInterval
    ) async -> AggregatedOutcome {
        let start = Date()
        do {
            return try await runProvider(provider, req: req, baseTimeout: baseTimeout, start: start)
        } catch {
            let pErr = (error as? ProviderError) ?? .network
            return AggregatedOutcome(
                providerId: provider.id,
                displayName: provider.displayName,
                modelName: provider.modelName,
                result: nil,
                error: pErr,
                latencyMs: Int(Date().timeIntervalSince(start) * 1000)
            )
        }
    }

    private static func runProvider(
        _ provider: TranslationProvider,
        req: TranslateRequest,
        baseTimeout: TimeInterval,
        start: Date
    ) async throws -> AggregatedOutcome {
        let prepared = prepare(req, for: provider)
        let timeout = Self.timeout(for: provider, base: baseTimeout)
        let result = try await Self.withTimeout(timeout) {
            try await provider.translate(prepared.request)
        }
        let finalResult = applyTerminology(
            to: result,
            application: prepared.application,
            protected: prepared.protected
        )
        return AggregatedOutcome(
            providerId: provider.id,
            displayName: provider.displayName,
            modelName: provider.modelName,
            result: finalResult,
            error: nil,
            latencyMs: Int(Date().timeIntervalSince(start) * 1000)
        )
    }

    private struct PreparedRequest: Sendable {
        let request: TranslateRequest
        let application: TerminologyApplication?
        let protected: ProtectedTerminologyText?
    }

    private static func prepare(_ req: TranslateRequest, for provider: TranslationProvider) -> PreparedRequest {
        guard req.terminology != nil else {
            return PreparedRequest(request: req, application: nil, protected: nil)
        }

        let matches = TerminologyMatcher.matches(
            in: req.text,
            snapshot: req.terminology,
            from: req.from,
            to: req.to,
            mode: req.mode
        )
        let support = effectiveTerminologySupport(
            provider.capabilities.terminology,
            snapshot: req.terminology,
            matches: matches
        )
        let strategy = applicationStrategy(for: support)

        switch support {
        case .placeholder, .promptAndPlaceholder:
            let protected = TerminologyProcessor.protect(req)
            let protectedRequest = TranslateRequest(
                text: protected.text,
                from: req.from,
                to: req.to,
                mode: req.mode,
                terminology: req.terminology
            )
            return PreparedRequest(
                request: protectedRequest,
                application: TerminologyApplication(strategy: strategy, matches: matches),
                protected: protected
            )
        case .prompt, .nativeGlossary, .unsupported:
            return PreparedRequest(
                request: req,
                application: TerminologyApplication(strategy: strategy, matches: matches),
                protected: nil
            )
        }
    }

    private static func effectiveTerminologySupport(
        _ support: TerminologySupport,
        snapshot: TerminologySnapshot?,
        matches: [TerminologyMatch]
    ) -> TerminologySupport {
        guard support == .prompt else { return support }
        if snapshot?.strictMode == true { return .promptAndPlaceholder }
        return matches.contains(where: isPreservationMatch) ? .promptAndPlaceholder : .prompt
    }

    private static func isPreservationMatch(_ match: TerminologyMatch) -> Bool {
        match.source.trimmingCharacters(in: .whitespacesAndNewlines)
            .caseInsensitiveCompare(match.target.trimmingCharacters(in: .whitespacesAndNewlines)) == .orderedSame
    }

    private static func applicationStrategy(for support: TerminologySupport) -> TerminologyApplicationStrategy {
        switch support {
        case .unsupported: return .unsupported
        case .placeholder: return .placeholder
        case .prompt: return .prompt
        case .promptAndPlaceholder: return .promptAndPlaceholder
        case .nativeGlossary: return .nativeGlossary
        }
    }

    private static func applyTerminology(
        to result: TranslateResult,
        application: TerminologyApplication?,
        protected: ProtectedTerminologyText?
    ) -> TranslateResult {
        guard let application else { return result }
        guard let protected, protected.hasMatches else {
            return result.withTranslated(result.translated, terminologyApplication: application)
        }
        let restored = TerminologyProcessor.restore(result.translated, using: protected)
        let finalApplication = TerminologyApplication(
            strategy: application.strategy,
            matches: application.matches,
            restorationSucceeded: restored.succeeded
        )
        return result.withTranslated(restored.text, terminologyApplication: finalApplication)
    }

    /// Provider-specific timeout budget for slower LLM services.
    static func timeout(for provider: TranslationProvider, base: TimeInterval) -> TimeInterval {
        let baseProviderID = provider.id.components(separatedBy: "#").first ?? provider.id
        if baseProviderID == "opencode" {
            return max(base, 180)
        }
        if baseProviderID == "zhipu" {
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
