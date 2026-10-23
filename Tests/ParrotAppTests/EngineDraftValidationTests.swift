import Foundation
import Darwin
import Testing
import ParrotCore
@testable import ParrotApp

@Suite(.serialized)
struct EngineDraftValidationTests {
    @MainActor
    @Test func draftProbeUsesEveryEnabledDraftModelWithoutSaving() async throws {
        let (settings, defaults, suite) = fixtureSettings()
        defer { defaults.removePersistentDomain(forName: suite) }
        settings.openAIEndpoint = "https://saved-endpoint.draft-test.invalid/v1/chat/completions"
        let before = defaults.persistentDomain(forName: suite) as NSDictionary?
        let descriptor = draftDescriptor()
        let targets = EngineValidator.makeDraftProviders(
            descriptor: descriptor,
            settings: settings,
            secretDraft: "fixture-draft",
            models: [
                .init(id: "primary", name: "old-primary", enabled: false),
                .init(id: "new-a", name: "draft-model-a"),
                .init(id: "new-b", name: "draft-model-b")
            ],
            endpoint: "https://new-endpoint.draft-test.invalid/v1/chat/completions"
        )
        #expect(targets.map(\.providerID) == ["openai#new-a", "openai#new-b"])
        #expect(targets.map(\.modelName) == ["draft-model-a", "draft-model-b"])
        DraftProbeURLProtocol.reset()
        URLProtocol.registerClass(DraftProbeURLProtocol.self)
        defer { URLProtocol.unregisterClass(DraftProbeURLProtocol.self) }

        #expect(await EngineValidator.validateTargets(targets) == .passed)
        let requests = DraftProbeURLProtocol.requests()
        #expect(requests.count == 2)
        #expect(requests.allSatisfy { $0.url?.host == "new-endpoint.draft-test.invalid" })
        #expect(requests.allSatisfy { $0.value(forHTTPHeaderField: "Authorization") == "Bearer fixture-draft" })
        #expect(requests.compactMap(requestModel) == ["draft-model-a", "draft-model-b"])
        #expect(defaults.persistentDomain(forName: suite) as NSDictionary? == before)
        #expect(settings.credentialRevisions.isEmpty)
    }

    @MainActor
    @Test func emptyDraftEndpointUsesNativeDefaultAndEnvironmentWinsOverDraft() async throws {
        let (settings, defaults, suite) = fixtureSettings()
        defer { defaults.removePersistentDomain(forName: suite) }
        settings.openAIEndpoint = "https://saved-endpoint.draft-test.invalid/v1/chat/completions"
        let variable = "PARROT_DRAFT_VALIDATION_KEY"
        let previous = getenv(variable).map { String(cString: $0) }
        setenv(variable, "fixture-environment", 1)
        defer {
            if let previous { setenv(variable, previous, 1) } else { unsetenv(variable) }
        }
        let targets = EngineValidator.makeDraftProviders(descriptor: draftDescriptor(), settings: settings, secretDraft: "fixture-draft", models: [.init(id: "primary", name: "draft-model")], endpoint: "")
        DraftProbeURLProtocol.reset()
        URLProtocol.registerClass(DraftProbeURLProtocol.self)
        defer { URLProtocol.unregisterClass(DraftProbeURLProtocol.self) }

        #expect(await EngineValidator.validateTargets(targets) == .passed)
        let request = try #require(DraftProbeURLProtocol.requests().first)
        #expect(request.url?.absoluteString == "https://api.openai.com/v1/chat/completions")
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer fixture-environment")
        #expect(settings.openAIEndpoint == "https://saved-endpoint.draft-test.invalid/v1/chat/completions")
    }

    @MainActor
    @Test func invalidDraftNeverBuildsAProbe() {
        let (settings, defaults, suite) = fixtureSettings()
        defer { defaults.removePersistentDomain(forName: suite) }
        let targets = EngineValidator.makeDraftProviders(descriptor: draftDescriptor(), settings: settings, secretDraft: "fixture-draft", models: [.init(id: "primary", name: "")], endpoint: "file:///tmp/service")
        #expect(targets.isEmpty)
        #expect(settings.credentialRevisions.isEmpty)
    }

    @MainActor
    @Test func ollamaOffersARealTranslationProbe() throws {
        let descriptor = try #require(CredentialCatalog.descriptor(matching: "ollama"))
        #expect(descriptor.supportsValidation)
        #expect(descriptor.linkedEngineID == "ollama")
    }

    @Test func validationReportsFailedModelsAndStillTestsRemainingModels() async {
        let log = DraftValidationCallLog()
        let targets = [
            target("first", failure: .auth, log: log),
            target("second", log: log),
            target("third", failure: .service("fixture unavailable"), log: log)
        ]
        guard case .failed(let message) = await EngineValidator.validateTargets(targets) else {
            Issue.record("Expected failed model probes to be reported")
            return
        }
        #expect(message.contains("first"))
        #expect(message.contains("third"))
        #expect(message.contains("fixture unavailable"))
        #expect(await log.calls == ["first", "second", "third"])
    }

    @Test func validationWithNoTargetsDoesNotPass() async {
        #expect(!(await EngineValidator.validateTargets([])).isPassed)
    }

    @Test func slowProbeTimesOutAndReleasesTheCaller() async {
        let start = Date()
        let result = await EngineValidator.validateTargets([target("slow", delay: 5)], timeoutPerTarget: 0.04, totalTimeout: 0.1)
        #expect(!result.isPassed)
        #expect(Date().timeIntervalSince(start) < 1)
    }

    @Test func deadlineDoesNotWaitForAProviderThatIgnoresCancellation() async {
        let provider = DraftValidationProvider(id: "uncooperative", delay: 1.5, ignoresCancellation: true)
        let start = Date()
        let result = await EngineValidator.validateTargets([.init(provider: provider, modelName: nil, providerID: provider.id)], timeoutPerTarget: 0.04, totalTimeout: 0.1)
        #expect(!result.isPassed)
        #expect(Date().timeIntervalSince(start) < 1)
    }

    @Test func cancellationStopsBeforeProbingAnotherModel() async {
        let log = DraftValidationCallLog()
        let task = Task {
            await EngineValidator.validateTargets([target("slow", delay: 5, log: log), target("later", log: log)])
        }
        while await log.calls.isEmpty { await Task.yield() }
        let start = Date()
        task.cancel()
        #expect(!(await task.value).isPassed)
        #expect(Date().timeIntervalSince(start) < 1)
        #expect(await log.calls == ["slow"])
    }

    @MainActor
    private func fixtureSettings() -> (AppSettings, UserDefaults, String) {
        let suite = "parrot.test.draft-validation.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return (AppSettings(defaults: defaults), defaults, suite)
    }

    private func draftDescriptor() -> CredentialDescriptor {
        .init(id: "draft-openai", aliases: [], name: "Draft Fixture", category: .llm,
              credential: .init(account: "test.draft-validation.key", env: "PARROT_DRAFT_VALIDATION_KEY", placeholder: "API Key", missingText: "Missing"),
              fallbackCredential: nil, fallbackLabel: nil, linkedEngineID: "openai", linkedOCRProviderID: nil, linkedTTSProviderID: nil,
              defaultModel: "gpt-default", defaultEndpoint: "", supportsValidation: true, note: nil)
    }

    private func target(_ model: String, failure: ProviderError? = nil, delay: TimeInterval = 0, log: DraftValidationCallLog? = nil) -> EngineValidator.ValidationTarget {
        .init(provider: DraftValidationProvider(id: model, failure: failure, delay: delay, log: log), modelName: model, providerID: "fixture#\(model)")
    }

    private func requestModel(_ request: URLRequest) -> String? {
        guard let data = request.httpBody,
              let payload = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        return payload["model"] as? String
    }
}

private actor DraftValidationCallLog {
    var calls: [String] = []
    func record(_ id: String) { calls.append(id) }
}

private struct DraftValidationProvider: TranslationProvider {
    let id: String
    var failure: ProviderError?
    var delay: TimeInterval = 0
    var log: DraftValidationCallLog?
    var ignoresCancellation = false
    var displayName: String { id }
    let supportedLanguages: [Language] = [.en, .zh]
    let capabilities = ProviderCapabilities()

    func translate(_ request: TranslateRequest) async throws -> TranslateResult {
        await log?.record(id)
        if delay > 0 {
            if ignoresCancellation {
                await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                    DispatchQueue.global().asyncAfter(deadline: .now() + delay) { continuation.resume() }
                }
            } else {
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
        }
        if let failure { throw failure }
        return TranslateResult(providerId: id, translated: "你好")
    }
}

private final class DraftProbeURLProtocol: URLProtocol {
    private static let lock = NSLock()
    private static var captured: [URLRequest] = []

    static func reset() { lock.lock(); captured = []; lock.unlock() }
    static func requests() -> [URLRequest] { lock.lock(); defer { lock.unlock() }; return captured }

    override class func canInit(with request: URLRequest) -> Bool {
        request.url?.host?.hasSuffix(".draft-test.invalid") == true || request.url?.host == "api.openai.com"
    }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        var capturedRequest = request
        if capturedRequest.httpBody == nil, let stream = capturedRequest.httpBodyStream {
            stream.open()
            defer { stream.close() }
            var data = Data()
            var buffer = [UInt8](repeating: 0, count: 1024)
            while stream.hasBytesAvailable {
                let count = stream.read(&buffer, maxLength: buffer.count)
                if count <= 0 { break }
                data.append(buffer, count: count)
            }
            capturedRequest.httpBody = data
        }
        Self.lock.lock(); Self.captured.append(capturedRequest); Self.lock.unlock()
        let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data("{\"choices\":[{\"message\":{\"content\":\"你好\"}}]}".utf8))
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}
