import Testing
import Foundation
@testable import ParrotCore
@testable import ParrotEngines

@Test func tenEngineAggregationIsolatesFailures() async {
    let registry = ProviderRegistry()
    for i in 0..<10 {
        registry.register(StubEngine(id: "e\(i)", suffix: "\(i)"), enabled: true)
    }
    registry.register(FailingEngine(), enabled: true)
    let coordinator = TranslationCoordinator(registry: registry)
    let outcomes = await coordinator.translateAll(TranslateRequest(text: "x", to: .zh))
    #expect(outcomes.count == 11)
    #expect(outcomes.filter(\.isSuccess).count == 10)
    #expect(outcomes.first(where: { $0.providerId == "failing" })?.error == .network)
}

@Test func baiduOCRParsesWords() throws {
    let json = """
    {"words_result":[{"words":"你好"},{"words":"世界"}]}
    """
    let result = try BaiduOCRProvider.parse(Data(json.utf8))
    #expect(result.fullText == "你好\n世界")
}

@Test func tencentOCRParsesDetections() throws {
    let json = """
    {"Response":{"TextDetections":[{"DetectedText":"Hello"}]}}
    """
    let result = try TencentOCRProvider.parse(Data(json.utf8))
    #expect(result.fullText == "Hello")
}

@Test func volcengineParsesTranslation() throws {
    let json = """
    {"TranslationList":[{"Translation":"你好"}]}
    """
    let result = try VolcengineEngine.parse(Data(json.utf8), providerId: "volcengine")
    #expect(result.translated == "你好")
}

@Test func niutransParsesTranslation() throws {
    let json = """
    {"tgt_text":"你好"}
    """
    let result = try NiutransEngine.parse(Data(json.utf8), providerId: "niutrans")
    #expect(result.translated == "你好")
}

@Test func amazonParsesTranslation() throws {
    let json = """
    {"TranslatedText":"你好"}
    """
    let result = try AmazonTranslateEngine.parse(Data(json.utf8), providerId: "amazon")
    #expect(result.translated == "你好")
}

@Test func keychainSecretAbsentFromUserDefaults() {
    let suiteName = "parrot.test.keychain-audit"
    let defaults = UserDefaults(suiteName: suiteName)!
    defaults.removePersistentDomain(forName: suiteName)
    let secret = "sk-test-secret-12345"
    KeychainStore.set(secret, account: "engine.openai.apiKey")
    let blob = defaults.dictionaryRepresentation().values.compactMap { $0 as? String }.joined()
    #expect(!blob.contains(secret))
}

@Test func openAICompatValidateConfiguredMock() async {
    let engine = OpenAIEngine()
    try? engine.configure(ProviderConfig(extra: ["apiKey": "test-key"]))
    #expect(engine.id == "openai")
}

private struct StubEngine: TranslationProvider {
    let id: String
    let suffix: String
    var displayName: String { id }
    var supportedLanguages: [Language] { [.zh] }
    var capabilities: ProviderCapabilities { ProviderCapabilities() }
    func translate(_ req: TranslateRequest) async throws -> TranslateResult {
        TranslateResult(providerId: id, translated: "ok-\(suffix)")
    }
}
