import Foundation
import Testing
@testable import ParrotApp

@MainActor
struct CredentialDraftValidationTests {
    @Test(arguments: ["", "https://example.com/v1/chat/completions", "http://127.0.0.1:11434/v1/chat/completions", "http://[::1]:11434/v1/chat/completions"])
    func endpointAcceptsDefaultAndHTTPServices(_ endpoint: String) throws {
        let descriptor = try #require(CredentialCatalog.descriptor(matching: "ollama"))
        #expect(CredentialDraftValidation.issues(descriptor: descriptor, secret: "", models: [model("translategemma")], endpoint: endpoint).isEmpty)
    }

    @Test(arguments: ["localhost:11434", "file:///tmp/server", "https://", "https://user:password@example.com/v1", "https://example.com/a b", "https://example.com:99999/v1", "https://example.com/v1#credentials"])
    func endpointRejectsMalformedOrEmbeddedCredentialValues(_ endpoint: String) throws {
        let descriptor = try #require(CredentialCatalog.descriptor(matching: "ollama"))
        let issues = CredentialDraftValidation.issues(descriptor: descriptor, secret: "", models: [model("translategemma")], endpoint: endpoint)
        #expect(issues.contains { $0.field == .endpoint })
    }

    @Test func enabledModelsRequireNamesAndDistinctValues() throws {
        let descriptor = try #require(CredentialCatalog.descriptor(matching: "openai"))
        let models = [model("gpt-main"), model(" ", id: "empty"), model(" gpt-main ", id: "duplicate"), model("", id: "disabled", enabled: false)]
        let issues = CredentialDraftValidation.issues(descriptor: descriptor, secret: "", models: models, endpoint: "")
        #expect(issues.map(\.field) == [.model("empty"), .model("duplicate")])
    }

    @Test func allDisabledModelsAreNotAUsableService() throws {
        let descriptor = try #require(CredentialCatalog.descriptor(matching: "openai"))
        let issues = CredentialDraftValidation.issues(descriptor: descriptor, secret: "", models: [model("gpt-main", enabled: false)], endpoint: "")
        #expect(issues.contains { $0.field == .model(EngineModelConfig.primaryID) })
        #expect(issues.allSatisfy { !$0.message.isEmpty })
    }

    @Test(arguments: ["missing-separator", ":secret", "account:", " : "])
    func newCompoundCredentialsRequireBothParts(_ secret: String) throws {
        let descriptor = try #require(CredentialCatalog.descriptor(matching: "tencent"))
        #expect(CredentialDraftValidation.issues(descriptor: descriptor, secret: secret, models: [], endpoint: "").contains { $0.field == .secret })
    }

    @Test func unchangedStoredCredentialsAndDeepLKeysAreNotMistakenForNewPairs() throws {
        let tencent = try #require(CredentialCatalog.descriptor(matching: "tencent"))
        let deepL = try #require(CredentialCatalog.descriptor(matching: "deepl"))
        #expect(CredentialDraftValidation.issues(descriptor: tencent, secret: "", models: [], endpoint: "").isEmpty)
        #expect(CredentialDraftValidation.issues(descriptor: deepL, secret: "plain-key", models: [], endpoint: "").isEmpty)
        #expect(CredentialDraftValidation.issues(descriptor: deepL, secret: "free-key:fx", models: [], endpoint: "").isEmpty)
    }

    @Test func regionMustBeUsableInTheResourceAddress() throws {
        let descriptor = try #require(CredentialCatalog.descriptor(matching: "amazon"))
        #expect(CredentialDraftValidation.issues(descriptor: descriptor, secret: "", models: [], endpoint: "", region: "us-east-1").isEmpty)
        #expect(CredentialDraftValidation.issues(descriptor: descriptor, secret: "", models: [], endpoint: "", region: "https://example.com").contains { $0.field == .region })
    }

    private func model(_ name: String, id: String = EngineModelConfig.primaryID, enabled: Bool = true) -> EngineModelConfig {
        .init(id: id, name: name, enabled: enabled)
    }
}
