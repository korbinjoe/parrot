import Testing
import Foundation
@testable import OpenBobCore
@testable import OpenBobEngines

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
