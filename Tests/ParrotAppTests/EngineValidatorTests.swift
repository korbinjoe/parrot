import Foundation
import Darwin
import Testing
import ParrotCore
@testable import ParrotApp

@MainActor
@Test func credentialValidationUsesAvailableKeyWhenEngineIsDisabled() async throws {
    let suiteName = "parrot.test.disabled-validation.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defaults.removePersistentDomain(forName: suiteName)

    StubURLProtocol.responseData = Data("""
    {"choices":[{"message":{"content":"你好"}}]}
    """.utf8)
    StubURLProtocol.lastAuthorization = nil

    let previousZhipuKey = getenv("ZHIPU_API_KEY").map { String(cString: $0) }
    setenv("ZHIPU_API_KEY", "glm-test-key", 1)
    URLProtocol.registerClass(StubURLProtocol.self)
    defer {
        URLProtocol.unregisterClass(StubURLProtocol.self)
        if let previousZhipuKey {
            setenv("ZHIPU_API_KEY", previousZhipuKey, 1)
        } else {
            unsetenv("ZHIPU_API_KEY")
        }
        defaults.removePersistentDomain(forName: suiteName)
    }

    defaults.set(false, forKey: "engine.zhipu.enabled")

    let settings = AppSettings(defaults: defaults)
    let provider = try #require(EngineValidator.makeConfiguredProvider(id: "zhipu", settings: settings))

    #expect(await EngineValidator.validateDetailed(provider) == .passed)
    #expect(StubURLProtocol.lastAuthorization == "Bearer glm-test-key")
}

@MainActor
@Test func enabledLLMModelConfigsRegisterAsIndependentProviders() throws {
    let suiteName = "parrot.test.model-configs.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defaults.removePersistentDomain(forName: suiteName)

    let previousZhipuKey = getenv("ZHIPU_API_KEY").map { String(cString: $0) }
    setenv("ZHIPU_API_KEY", "glm-test-key", 1)
    defer {
        if let previousZhipuKey {
            setenv("ZHIPU_API_KEY", previousZhipuKey, 1)
        } else {
            unsetenv("ZHIPU_API_KEY")
        }
        defaults.removePersistentDomain(forName: suiteName)
    }

    let settings = AppSettings(defaults: defaults)
    settings.zhipuEnabled = true
    let primary = EngineModelConfig(id: EngineModelConfig.primaryID, name: "glm-main", enabled: true)
    let disabled = EngineModelConfig(id: "disabled", name: "glm-off", enabled: false)
    let alternate = EngineModelConfig(id: "alternate", name: "glm-alt", enabled: true)
    settings.setModelConfigs([primary, disabled, alternate], for: "zhipu")

    let registry = ProviderRegistry()
    EngineBootstrap.registerAll(into: registry, settings: settings)

    let zhipuProviders = registry.activeProviders()
        .filter { EngineModelConfig.baseEngineID(forProviderID: $0.id) == "zhipu" }
    #expect(zhipuProviders.map(\.id) == [
        primary.providerID(engineID: "zhipu"),
        alternate.providerID(engineID: "zhipu")
    ])
    #expect(zhipuProviders.map(\.modelName) == ["glm-main", "glm-alt"])
    #expect(registry.provider(id: disabled.providerID(engineID: "zhipu")) != nil)
}

@MainActor
@Test func terminologySettingsPersistAndDisabledSnapshotIsNil() throws {
    let suiteName = "parrot.test.terminology.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defaults.removePersistentDomain(forName: suiteName)
    let fileURL = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent("parrot-settings-terminology-\(UUID().uuidString).json")
    defer {
        defaults.removePersistentDomain(forName: suiteName)
        try? FileManager.default.removeItem(at: fileURL)
    }

    let settings = AppSettings(
        defaults: defaults,
        terminologyStore: TerminologyStore(fileURL: fileURL)
    )
    let saveResult = settings.saveTerminologyEntry(
        TerminologyEntry(source: "AI Agent", target: "AI Agent", from: .en, to: .zh)
    )
    if case .failure(let error) = saveResult {
        Issue.record("Expected terminology save to succeed, got \(error)")
    }
    #expect(settings.terminologySnapshot()?.entries.count == 1)

    settings.terminologyEnabled = false
    #expect(settings.terminologySnapshot() == nil)

    let reloaded = AppSettings(
        defaults: defaults,
        terminologyStore: TerminologyStore(fileURL: fileURL)
    )
    #expect(reloaded.terminologyEntries.first?.source == "AI Agent")
    #expect(reloaded.terminologyEnabled == false)
}

private final class StubURLProtocol: URLProtocol {
    static var responseData = Data()
    static var lastAuthorization: String?

    override class func canInit(with request: URLRequest) -> Bool {
        request.url?.host == "open.bigmodel.cn"
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        Self.lastAuthorization = request.value(forHTTPHeaderField: "Authorization")
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Self.responseData)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
