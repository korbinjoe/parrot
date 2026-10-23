import Foundation
import Testing
@testable import ParrotCore
@testable import ParrotEngines

@Suite(.serialized)
struct OllamaRequestTests {
    @Test func translateGemmaRequestsCarryExplicitDirectionAndOnlySourceText() async throws {
        let directions: [(Language, Language, String, String)] = [
            (.en, .zh, "Angler", "English (en) to Chinese (zh)"),
            (.en, .ja, "The weather is sunny today.", "English (en) to Japanese (ja)"),
            (.zh, .en, "今天适合出去散步。", "Chinese (zh) to English (en)"),
            // An explicit source is authoritative even when the text detector disagrees.
            (.fr, .de, "Angler", "French (fr) to German (de)")
        ]
        for (from, to, text, direction) in directions {
            let context = TranslationContext(profile: .quickTranslate, origin: .url,
                sourceApp: "Private browser", windowTitle: "Private window",
                sourceURL: "https://private.example/account?token=metadata")
            let (request, _) = try await send(model: "translategemma:latest",
                input: TranslateRequest(text: text, from: from, to: to, context: context))
            let messages = try messageList(in: request)
            #expect(messages.count == 1)
            #expect(messages.first?["role"] == "user")
            let content = try #require(messages.first?["content"])
            #expect(content.contains(direction))
            #expect(content.hasSuffix("\n\n\n" + text))
            #expect(!content.contains("referenceContext"))
            #expect(!content.contains("sourceText"))
            #expect(!content.contains("Private browser"))
            #expect(!content.contains("Private window"))
            #expect(!content.contains("private.example"))
            let payload = try body(in: request)
            #expect(payload["model"] as? String == "translategemma:latest")
            #expect(request.url?.absoluteString == "http://127.0.0.1:11434/v1/chat/completions")
        }
    }

    @Test func translateGemmaResolvesAutomaticSourceWithoutChangingTarget() async throws {
        for text in ["Angler", "tide"] {
            let (request, _) = try await send(model: "translategemma",
                input: TranslateRequest(text: text, from: .auto, to: .zh))
            let content = try #require(messageList(in: request).first?["content"])
            #expect(content.contains("English (en) to Chinese (zh)"))
            #expect(content.hasSuffix("\n\n\n" + text))
        }
        let (request, _) = try await send(model: "translategemma",
            input: TranslateRequest(text: "今天适合出去散步。", from: .auto, to: .en))
        #expect(try messageList(in: request).first?["content"]?.contains("Chinese (zh) to English (en)") == true)
    }

    @Test func translateGemmaMatchesExactModelBasenameAndKeepsOtherModelsUnchanged() async throws {
        let input = TranslateRequest(text: "Angler", from: .en, to: .zh)
        for model in ["translategemma", "translategemma:4b", "library/translategemma:latest", "team/TranslateGemma:12b"] {
            let (request, _) = try await send(model: model, input: input)
            #expect(try messageList(in: request).count == 1)
        }
        for model in ["glm-5:cloud", "translategemma-custom", "custom-translategemma", "translategemma2:latest"] {
            let (request, _) = try await send(model: model, input: input)
            #expect(try messageList(in: request) == genericMessages(for: input))
        }
        let engine = OllamaEngine()
        try engine.configure(ProviderConfig(extra: ["model": "translategemma:latest"]))
        #expect(engine.capabilities.terminology == .placeholder)
        #expect(!engine.capabilities.supportsLookup)
        #expect(!engine.capabilities.supportsInterpretation)
        try engine.configure(ProviderConfig(extra: ["model": "glm-5:cloud"]))
        #expect(engine.capabilities.terminology == .prompt)
        #expect(engine.capabilities.supportsLookup)
        #expect(engine.capabilities.supportsInterpretation)
    }

    @Test func lookupAndInterpretationUseTranslationFallbackInSelectedLanguage() async throws {
        let inputs = [
            TranslateRequest(text: "Angler", from: .en, to: .zh, mode: .lookup),
            TranslateRequest(text: "That's a bold choice.", from: .en, to: .zh,
                context: TranslationContext(profile: .understand, origin: .selection))
        ]
        for input in inputs {
            let (request, result) = try await send(model: "translategemma:latest", input: input)
            let messages = try messageList(in: request)
            #expect(messages.count == 1)
            #expect(messages.first?["role"] == "user")
            #expect(messages.first?["content"]?.contains("English (en) to Chinese (zh)") == true)
            #expect(messages.first?["content"]?.hasSuffix("\n\n\n" + input.text) == true)
            #expect(result.translated == "垂钓者")
            #expect(result.interpretation == nil)
        }
    }

    @Test func polishKeepsExistingMessages() async throws {
        let input = TranslateRequest(text: "A clearer sentence.", from: .en, to: .en, mode: .polish)
        let (request, _) = try await send(model: "translategemma:latest", input: input)
        #expect(try messageList(in: request) == genericMessages(for: input))
    }

    @Test func unspecifiedTargetAndUnknownSourceDoNotSilentlyBecomeEnglish() async throws {
        let session = makeSession()
        defer { session.invalidateAndCancel() }
        let engine = OllamaEngine(session: session)
        try engine.configure(ProviderConfig(extra: ["model": "translategemma"]))
        let inputs = [
            TranslateRequest(text: "Angler", from: .en, to: .auto),
            TranslateRequest(text: "1234 😀", from: .auto, to: .zh),
            TranslateRequest(text: "tide", from: .auto, to: .en)
        ]
        for input in inputs {
            await #expect(throws: ProviderError.unsupportedLanguage) {
                _ = try await engine.translate(input)
            }
        }
        #expect(OllamaRequestProtocol.requests.isEmpty)
    }

    @Test func nonStrictTerminologyAndPrivateEntitiesAreProtectedAndRestored() async throws {
        let session = makeSession(response: "PARROTTERM0001：PARROTMASK_EMAIL_0001 PARROTMASK_URL_0001")
        defer { session.invalidateAndCancel() }
        let engine = OllamaEngine(session: session)
        try engine.configure(ProviderConfig(extra: ["model": "translategemma:latest"]))
        let terminology = TerminologySnapshot(entries: [
            TerminologyEntry(source: "Angler", target: "垂钓者", from: .en, to: .zh)
        ], strictMode: false)
        let input = TranslateRequest(
            text: "Angler can contact reader@example.com at https://example.com/account", from: .en, to: .zh,
            terminology: terminology,
            context: TranslationContext(profile: .quickTranslate, origin: .selection,
                windowTitle: "Private title", sourceURL: "https://metadata.example/secret", privacyPolicy: .maskSensitive)
        )
        let outcome = await TranslationCoordinator.runProvider(engine, req: input, baseTimeout: 1)

        let result = try #require(outcome.result)
        #expect(result.translated == "垂钓者：reader@example.com https://example.com/account")
        #expect(result.terminologyApplication?.strategy == .placeholder)
        #expect(result.terminologyApplication?.restorationSucceeded == true)
        #expect(result.privacyMaskingReport?.applied == true)
        let request = try #require(OllamaRequestProtocol.requests.first)
        let content = try #require(messageList(in: request).first?["content"])
        #expect(content.contains("PARROTTERM0001"))
        #expect(content.contains("PARROTMASK_EMAIL_0001"))
        #expect(content.contains("PARROTMASK_URL_0001"))
        #expect(!content.contains("Angler"))
        #expect(!content.contains("reader@example.com"))
        #expect(!content.contains("https://example.com/account"))
        #expect(!content.contains("metadata.example"))
        #expect(!content.contains("Private title"))
    }

    @Test func protectedOnlyInputRestoresLocallyWithoutGuessingSourceOrCallingModel() async throws {
        let session = makeSession()
        defer { session.invalidateAndCancel() }
        let engine = OllamaEngine(session: session)
        try engine.configure(ProviderConfig(extra: ["model": "translategemma"]))
        let terminology = TerminologySnapshot(entries: [
            TerminologyEntry(source: "Angler", target: "垂钓者", from: .auto, to: .zh)
        ], strictMode: false)
        let input = TranslateRequest(text: "Angler, reader@example.com!", from: .auto, to: .zh,
            terminology: terminology,
            context: TranslationContext(profile: .quickTranslate, privacyPolicy: .maskSensitive))
        let outcome = await TranslationCoordinator.runProvider(engine, req: input, baseTimeout: 1)

        #expect(outcome.result?.translated == "垂钓者, reader@example.com!")
        #expect(outcome.result?.terminologyApplication?.restorationSucceeded == true)
        #expect(outcome.result?.privacyMaskingReport?.applied == true)
        #expect(OllamaRequestProtocol.requests.isEmpty)
        // Arbitrary unknown content must not take the protected-only shortcut.
        #expect(!TranslateGemmaPrompt.containsOnlyProtectedTokens("1234 😀"))
        #expect(!TranslateGemmaPrompt.containsOnlyProtectedTokens("PARROTTERM0001 unknown"))
    }

    private func send(model: String, input: TranslateRequest) async throws -> (URLRequest, TranslateResult) {
        let session = makeSession()
        defer { session.invalidateAndCancel() }
        let engine = OllamaEngine(session: session)
        try engine.configure(ProviderConfig(extra: ["model": model]))
        let result = try await engine.translate(input)
        return (try #require(OllamaRequestProtocol.requests.first), result)
    }

    private func genericMessages(for input: TranslateRequest) -> [[String: String]] {
        [
            ["role": "system", "content": OpenAICompatEngine.systemPrompt(for: input)],
            ["role": "user", "content": OpenAICompatEngine.userPrompt(for: input)]
        ]
    }

    private func messageList(in request: URLRequest) throws -> [[String: String]] {
        try #require(body(in: request)["messages"] as? [[String: String]])
    }

    private func body(in request: URLRequest) throws -> [String: Any] {
        let data = try #require(request.httpBody)
        return try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    private func makeSession(response: String = "垂钓者") -> URLSession {
        OllamaRequestProtocol.prepare(response: response)
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [OllamaRequestProtocol.self]
        return URLSession(configuration: configuration)
    }
}

private final class OllamaRequestProtocol: URLProtocol {
    private static let lock = NSLock()
    private static var capturedRequests: [URLRequest] = []
    private static var responseText = ""

    static var requests: [URLRequest] {
        lock.lock()
        defer { lock.unlock() }
        return capturedRequests
    }

    static func prepare(response: String) {
        lock.lock()
        defer { lock.unlock() }
        capturedRequests = []
        responseText = response
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        var captured = request
        if captured.httpBody == nil, let stream = request.httpBodyStream {
            stream.open()
            defer { stream.close() }
            var data = Data()
            var buffer = [UInt8](repeating: 0, count: 4_096)
            while true {
                let count = stream.read(&buffer, maxLength: 4_096)
                guard count > 0 else { break }
                data.append(contentsOf: buffer.prefix(count))
            }
            captured.httpBody = data
        }
        Self.lock.lock()
        Self.capturedRequests.append(captured)
        let text = Self.responseText
        Self.lock.unlock()
        let data = try! JSONSerialization.data(withJSONObject: ["choices": [["message": ["content": text]]]])
        let response = HTTPURLResponse(url: request.url!, statusCode: 200,
                                       httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
