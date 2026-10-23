import Foundation
import Testing
@testable import ParrotCore
@testable import ParrotEngines

@Suite(.serialized)
struct OpenCodeRequestTests {
    @Test func goRequestsIdentifyParrotAndReuseRequestSession() async throws {
        let session = makeSession()
        defer { session.invalidateAndCancel() }
        let sessionID = UUID()
        let engine = OpenCodeGoEngine(session: session)
        try engine.configure(ProviderConfig(extra: ["apiKey": "test-key"]))
        let inputs = ["tide", "shore"]
        for input in inputs {
            _ = try await engine.translate(TranslateRequest(text: input, from: .en, to: .zh, sessionID: sessionID))
        }

        let requests = OpenCodeRequestProtocol.requests
        #expect(requests.count == 2)
        for (index, request) in requests.enumerated() {
            #expect(request.url?.absoluteString == "https://opencode.ai/zen/go/v1/chat/completions")
            #expect(request.httpMethod == "POST")
            #expect(request.value(forHTTPHeaderField: "User-Agent")?.hasPrefix("Parrot/") == true)
            #expect(request.value(forHTTPHeaderField: "x-opencode-session") == sessionID.uuidString)
            #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer test-key")
            #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
            let body = try #require(request.httpBody)
            let payload = try #require(JSONSerialization.jsonObject(with: body) as? [String: Any])
            #expect(payload["model"] as? String == "glm-5.1")
            let messages = try #require(payload["messages"] as? [[String: String]])
            let original = TranslateRequest(text: inputs[index], from: .en, to: .zh)
            #expect(messages == [
                ["role": "system", "content": OpenAICompatEngine.systemPrompt(for: original)],
                ["role": "user", "content": OpenAICompatEngine.userPrompt(for: original)]
            ])
        }
    }

    @Test func requestSessionSurvivesCopiesAndEngineReplacementWhileNewRequestsStayDistinct() async throws {
        let session = makeSession()
        defer { session.invalidateAndCancel() }
        let first = OpenCodeGoEngine(session: session)
        let second = OpenCodeGoEngine(session: session)
        for engine in [first, second] {
            try engine.configure(ProviderConfig(extra: ["apiKey": "test-key"]))
        }
        let request = TranslateRequest(text: "tide", from: .en, to: .zh)
        let nextRequest = TranslateRequest(text: "shore", from: .en, to: .zh)
        _ = try await first.translate(request)
        _ = try await first.translate(request.withText("tide again"))
        _ = try await second.translate(request.withContext(nil))
        _ = try await first.translate(nextRequest)

        let requests = OpenCodeRequestProtocol.requests
        #expect(requests.count == 4)
        for sent in requests.prefix(3) {
            #expect(sent.value(forHTTPHeaderField: "x-opencode-session") == request.sessionID.uuidString)
        }
        #expect(requests[3].value(forHTTPHeaderField: "x-opencode-session") == nextRequest.sessionID.uuidString)
        #expect(nextRequest.sessionID != request.sessionID)
    }

    @Test func otherCompatibleEnginesDoNotSendGoSessionHeaders() async throws {
        let session = makeSession()
        defer { session.invalidateAndCancel() }
        let engine = OpenAIEngine(session: session)
        try engine.configure(ProviderConfig(extra: ["apiKey": "test-key"]))
        let input = TranslateRequest(text: "tide", from: .en, to: .zh)
        _ = try await engine.translate(input)

        let request = try #require(OpenCodeRequestProtocol.requests.first)
        #expect(engine.additionalHeaders(for: input).isEmpty)
        #expect(request.value(forHTTPHeaderField: "x-opencode-session") == nil)
        #expect(request.url?.host == "api.openai.com")
    }

    @Test(arguments: [400, 403])
    func goServiceRejectionsRemainVisible(status: Int) async throws {
        let message = status == 400 ? "Upstream Model unavailable" : "Country restriction"
        let session = makeSession(status: status, message: message)
        defer { session.invalidateAndCancel() }
        let engine = OpenCodeGoEngine(session: session)
        try engine.configure(ProviderConfig(extra: ["apiKey": "test-key"]))

        await #expect(throws: ProviderError.service(message)) {
            _ = try await engine.translate(TranslateRequest(text: "tide", from: .en, to: .zh))
        }
    }

    private func makeSession(status: Int = 200, message: String? = nil) -> URLSession {
        OpenCodeRequestProtocol.prepare(status: status, message: message)
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [OpenCodeRequestProtocol.self]
        return URLSession(configuration: configuration)
    }
}

private final class OpenCodeRequestProtocol: URLProtocol {
    private static let lock = NSLock()
    private static var capturedRequests: [URLRequest] = []
    private static var statusCode = 200
    private static var responseMessage: String?

    static var requests: [URLRequest] {
        lock.lock()
        defer { lock.unlock() }
        return capturedRequests
    }

    static func prepare(status: Int, message: String?) {
        lock.lock()
        defer { lock.unlock() }
        capturedRequests = []
        statusCode = status
        responseMessage = message
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
        let status = Self.statusCode
        let message = Self.responseMessage
        Self.lock.unlock()

        let payload: [String: Any]
        if let message {
            payload = ["error": ["message": message]]
        } else {
            payload = ["choices": [["message": ["content": "潮汐"]]]]
        }
        let data = try! JSONSerialization.data(withJSONObject: payload)
        let response = HTTPURLResponse(url: request.url!, statusCode: status,
                                       httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
