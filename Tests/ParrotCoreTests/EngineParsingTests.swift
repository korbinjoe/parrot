import Testing
import Foundation
@testable import ParrotCore
@testable import ParrotEngines

@Test func googleParsesTranslationAndDetectedLang() throws {
    // Shape: [[["你好","hello",null,null,10]],null,"en",...]
    let json = """
    [[["你好","hello",null,null,10]],null,"en",null,null,null,1.0,null,[["en"]]]
    """
    let result = try GoogleEngine.parse(Data(json.utf8), providerId: "google")
    #expect(result.translated == "你好")
    #expect(result.detectedFrom == .en)
}

@Test func googleConcatenatesMultipleSegments() throws {
    let json = """
    [[["你好","Hello",null,null],["世界","World",null,null]],null,"en"]
    """
    let result = try GoogleEngine.parse(Data(json.utf8), providerId: "google")
    #expect(result.translated == "你好世界")
}

@Test func googleThrowsOnGarbage() {
    #expect(throws: ProviderError.self) {
        _ = try GoogleEngine.parse(Data("not json".utf8), providerId: "google")
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

@Test func openCodeGoUsesGoDefaults() {
    let engine = OpenCodeGoEngine()
    #expect(engine.id == "opencode")
    #expect(engine.displayName == "OpenCode Go")
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
