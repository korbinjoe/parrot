import Testing
import Foundation
@testable import ParrotCore
@testable import ParrotPlugins

@Test func manifestParses() throws {
    let json = """
    {
      "identifier": "com.example.x", "name": "X", "version": "1.0.0",
      "capabilities": ["translate", "lookup"],
      "permissions": { "network": ["api.openai.com"] },
      "options": [ { "key": "apiKey", "type": "secret", "required": true } ]
    }
    """
    let m = try PluginManifest.parse(Data(json.utf8))
    #expect(m.identifier == "com.example.x")
    #expect(m.allowedHosts == ["api.openai.com"])
    #expect(m.capabilities?.contains("lookup") == true)
}

@Test func manifestParseFailsOnGarbage() {
    #expect(throws: PluginError.self) {
        _ = try PluginManifest.parse(Data("nope".utf8))
    }
}

@Test func resolveOptionsMergesSecretsOverDefaults() throws {
    let json = """
    { "identifier":"x","name":"X","version":"1.0.0",
      "options":[ {"key":"model","type":"string","default":"gpt-4o-mini"},
                  {"key":"apiKey","type":"secret"} ] }
    """
    let m = try PluginManifest.parse(Data(json.utf8))
    let opts = PluginLoader.resolveOptions(manifest: m, secrets: ["apiKey": "sk-123"])
    #expect(opts["model"] == "gpt-4o-mini")   // default applied
    #expect(opts["apiKey"] == "sk-123")       // secret injected
}

@Test func runtimeRunsEchoPluginWithOption() async throws {
    let script = """
    function translate(query, completion) {
      completion({ result: { translated: ($option.prefix || "") + query.text } });
    }
    """
    let runtime = try PluginRuntime(script: script, allowedHosts: [], options: ["prefix": "echo: "])
    let out = try await runtime.callTranslate(query: ["text": "hello", "to": "zh"])
    let result = out["result"] as? [String: Any]
    #expect(result?["translated"] as? String == "echo: hello")
}

@Test func runtimeRejectsScriptWithoutTranslate() {
    #expect(throws: PluginError.self) {
        _ = try PluginRuntime(script: "var x = 1;", allowedHosts: [], options: [:])
    }
}

@Test func httpBlocksNonWhitelistedHost() async throws {
    // Plugin tries a host not in the (empty) whitelist; $http must return an error to the handler.
    let script = """
    function translate(query, completion) {
      $http.get({ url: "https://evil.example.com/x", handler: function(r){
        completion({ error: r.error || "no-error" });
      }});
    }
    """
    let runtime = try PluginRuntime(script: script, allowedHosts: [], options: [:], timeout: 5)
    let out = try await runtime.callTranslate(query: ["text": "x"])
    let err = out["error"] as? String ?? ""
    #expect(err.contains("network not permitted"))
}

@Test func pluginProviderAdaptsToTranslationProvider() async throws {
    let json = """
    { "identifier":"echo","name":"Echo","version":"1.0.0","capabilities":["translate"],
      "permissions":{"network":[]} }
    """
    let manifest = try PluginManifest.parse(Data(json.utf8))
    let script = "function translate(q, c){ c({ result: { translated: \"[\" + q.to + \"]\" + q.text } }); }"
    let runtime = try PluginRuntime(script: script, allowedHosts: [], options: [:])
    let provider = PluginProvider(manifest: manifest, runtime: runtime)
    #expect(provider.id == "plugin.echo")
    let result = try await provider.translate(TranslateRequest(text: "hi", to: .zh))
    #expect(result.translated == "[zh]hi")
    #expect(provider.capabilities.supportsPolish)
}
