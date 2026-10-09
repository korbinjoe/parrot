import Testing
import Foundation
@testable import ParrotCore
@testable import ParrotEngines

@Test func googleTranslationLLMParsesTranslationAndDetectedLang() throws {
    let json = """
    {"data":{"translations":[{"translatedText":"你好 &amp; 欢迎","detectedSourceLanguage":"en","model":"projects/demo/locations/global/models/general/translation-llm"}]}}
    """
    let result = try GoogleTranslationLLMEngine.parse(Data(json.utf8), providerId: "google")
    #expect(result.translated == "你好 & 欢迎")
    #expect(result.detectedFrom == .en)
}

@Test func googleTranslationLLMBuildsOfficialModelResource() {
    let body = GoogleTranslationLLMEngine.requestBody(
        for: TranslateRequest(text: "hello", from: .auto, to: .zh),
        projectID: "parrot-demo"
    )
    #expect(body["model"] as? String == "projects/parrot-demo/locations/global/models/general/translation-llm")
    #expect(body["source"] == nil)
}

@Test func googleThrowsOnGarbage() {
    #expect(throws: ProviderError.self) {
        _ = try GoogleTranslationLLMEngine.parse(Data("not json".utf8), providerId: "google")
    }
}

@Test func googleTranslationLLMRequiresCredentials() async {
    let engine = GoogleTranslationLLMEngine()
    await #expect(throws: ProviderError.notConfigured) {
        _ = try await engine.translate(TranslateRequest(text: "hi", to: .zh))
    }
}

@Test func deeplParsesTranslation() throws {
    let json = """
    { "translations": [ { "detected_source_language": "EN", "text": "你好世界" } ] }
    """
    let result = try DeepLEngine.parse(Data(json.utf8), providerId: "deepl")
    #expect(result.translated == "你好世界")
    #expect(result.detectedFrom == .en)
}

@Test func deeplThrowsOnEmpty() {
    #expect(throws: ProviderError.self) {
        _ = try DeepLEngine.parse(Data("{\"translations\":[]}".utf8), providerId: "deepl")
    }
}

@Test func deeplNotConfiguredThrows() async {
    let engine = DeepLEngine()
    await #expect(throws: ProviderError.notConfigured) {
        _ = try await engine.translate(TranslateRequest(text: "hi", to: .zh))
    }
}

@Test func ollamaDoesNotRequireAPIKey() async {
    let engine = OllamaEngine()
    do {
        _ = try await engine.translate(TranslateRequest(text: "hi", to: .zh))
    } catch ProviderError.notConfigured {
        Issue.record("Ollama should not require API key")
        #expect(Bool(false))
    } catch {
        // Network errors are fine when no local Ollama server is running in CI.
    }
}

@Test func baiduParsesTranslation() throws {
    let json = """
    {"from":"en","to":"zh","trans_result":[{"src":"hello","dst":"你好"}]}
    """
    let result = try BaiduEngine.parse(Data(json.utf8), providerId: "baidu")
    #expect(result.translated == "你好")
}

@Test func youdaoParsesTranslation() throws {
    let json = """
    {"errorCode":"0","translation":["你好"]}
    """
    let result = try YoudaoEngine.parse(Data(json.utf8), providerId: "youdao")
    #expect(result.translated == "你好")
}

@Test func microsoftParsesTranslation() throws {
    let json = """
    [{"detectedLanguage":{"language":"en","score":1},"translations":[{"text":"你好","to":"zh-Hans"}]}]
    """
    let result = try MicrosoftEngine.parse(Data(json.utf8), providerId: "microsoft")
    #expect(result.translated == "你好")
    #expect(result.detectedFrom == .en)
}

@Test func openAICompatParsesChatCompletion() throws {
    let json = """
    {"choices":[{"message":{"content":" 你好 "}}]}
    """
    let result = try OpenAICompatEngine.parseChatCompletion(Data(json.utf8), providerId: "openai")
    #expect(result.translated == "你好")
}

@Test func openAICompatPolishPromptPreservesOriginalLanguage() {
    let prompt = OpenAICompatEngine.systemPrompt(for: TranslateRequest(
        text: "This draft needs polish.",
        from: .en,
        to: .en,
        mode: .polish
    ))

    #expect(prompt.contains("Keep the output in the same language"))
    #expect(prompt.contains("do not translate it into another language"))
}

@Test func openAICompatPolishPromptIncludesRewriteTone() {
    let context = TranslationContext(
        profile: .nativePolish,
        origin: .manualInput,
        rewriteTone: "Use a softer, collaborative tone."
    )
    let prompt = OpenAICompatEngine.systemPrompt(for: TranslateRequest(
        text: "This draft needs polish.",
        from: .en,
        to: .en,
        mode: .polish,
        context: context
    ))

    #expect(prompt.contains("Rewrite tone: Use a softer, collaborative tone."))
    #expect(prompt.contains("Make the result native"))
}

@Test func openAICompatPromptUsesContextProfileInstruction() {
    let context = TranslationContext(profile: .document, origin: .manualInput)
    let prompt = OpenAICompatEngine.systemPrompt(for: TranslateRequest(
        text: "Heading\n\nBody",
        from: .en,
        to: .zh,
        context: context
    ))

    #expect(prompt.contains("Preserve paragraph breaks"))
    #expect(prompt.contains("document structure"))
}

@Test func openCodeGoUsesGoDefaults() {
    let engine = OpenCodeGoEngine()
    #expect(engine.id == "opencode")
    #expect(engine.displayName == "OpenCode Go")
}

@Test func openCodeGoSendsStableSessionHeader() async throws {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [OpenCodeRequestStub.self]
    let session = URLSession(configuration: configuration)
    defer { session.invalidateAndCancel() }

    let engine = OpenCodeGoEngine(session: session)
    try engine.configure(ProviderConfig(extra: ["apiKey": "test-key"]))
    let request = TranslateRequest(text: "hello", to: .zh)

    _ = try await engine.translate(request)
    _ = try await engine.translate(request)
    _ = try await engine.translate(TranslateRequest(text: "goodbye", to: .zh))

    let sent = OpenCodeRequestStub.recordedRequests
    #expect(sent.count == 3)
    #expect(sent[0].value(forHTTPHeaderField: "x-opencode-session") == request.sessionID.uuidString)
    #expect(sent[1].value(forHTTPHeaderField: "x-opencode-session") == request.sessionID.uuidString)
    #expect(sent[2].value(forHTTPHeaderField: "x-opencode-session") != request.sessionID.uuidString)
    #expect(sent.allSatisfy { $0.value(forHTTPHeaderField: "User-Agent")?.hasPrefix("Parrot/") == true })
    #expect(sent.allSatisfy { $0.value(forHTTPHeaderField: "Authorization") == "Bearer test-key" })
    #expect(request.withText("hello again").sessionID == request.sessionID)
    #expect(request.withContext(nil).sessionID == request.sessionID)
}

private final class OpenCodeRequestStub: URLProtocol {
    private static let lock = NSLock()
    private static var requests: [URLRequest] = []

    static var recordedRequests: [URLRequest] {
        lock.lock()
        defer { lock.unlock() }
        return requests
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        Self.lock.lock()
        Self.requests.append(request)
        Self.lock.unlock()
        let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(#"{"choices":[{"message":{"content":"你好"}}]}"#.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

@Test func geminiParsesContent() throws {
    let json = """
    {"candidates":[{"content":{"parts":[{"text":"你好"}]}}]}
    """
    let result = try GeminiEngine.parse(Data(json.utf8), providerId: "gemini")
    #expect(result.translated == "你好")
}

@Test func tencentParsesTranslation() throws {
    let json = """
    {"Response":{"Source":"en","Target":"zh","TargetText":"你好","RequestId":"x"}}
    """
    let result = try TencentEngine.parse(Data(json.utf8), providerId: "tencent")
    #expect(result.translated == "你好")
}

@Test func caiyunParsesTranslation() throws {
    let json = """
    {"target":["你好","世界"]}
    """
    let result = try CaiyunEngine.parse(Data(json.utf8), providerId: "caiyun")
    #expect(result.translated == "你好\n世界")
}
