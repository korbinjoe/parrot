import Foundation
import ParrotCore

/// An in-memory description of the configuration that produced a translation.
/// Order is presentation state; credentials are represented only by local revisions.
struct TranslationConfigurationSnapshot: Equatable {
    struct Provider: Equatable {
        let id: String
        let model: String?
        let endpoint: String
        let region: String
        let credentialRevision: UInt64
    }

    struct RequestOptions: Equatable {
        let source: String
        let target: String
        let compare: Bool
        let advanced: Bool
        let lastProfile: String?
        let documentRule: Bool
        let developerRule: Bool
        let privateRule: Bool
        let terminology: [TerminologyEntry]
        let strictTerminology: Bool
    }

    let providers: [Provider]
    let requestOptions: RequestOptions

    @MainActor
    init(
        settings: AppSettings,
        providers: [TranslationProvider],
        credentialRevisions: [String: UInt64]? = nil
    ) {
        let revisions = credentialRevisions ?? settings.credentialRevisions
        let descriptors = Dictionary(uniqueKeysWithValues: EngineCatalog.all.map { ($0.id, $0) })
        self.providers = providers.map { provider in
            let engineID = EngineModelConfig.baseEngineID(forProviderID: provider.id)
            let account = engineID == "ollama"
                ? AppSettings.ollamaAccount
                : descriptors[engineID]?.credential?.account
            let endpoint: String
            switch engineID {
            case "openai": endpoint = settings.openAIEndpoint
            case "ollama": endpoint = settings.ollamaEndpoint
            default: endpoint = settings.endpoint(for: engineID) ?? ""
            }
            let region: String
            switch engineID {
            case "microsoft": region = settings.microsoftRegion
            case "amazon": region = settings.amazonRegion
            default: region = ""
            }
            return Provider(
                id: provider.id,
                model: provider.modelName,
                endpoint: endpoint.trimmingCharacters(in: .whitespacesAndNewlines),
                region: region.trimmingCharacters(in: .whitespacesAndNewlines),
                credentialRevision: account.flatMap { revisions[$0] } ?? 0
            )
        }.sorted { $0.id < $1.id }
        let terminology = settings.terminologySnapshot()
        let advanced = settings.advancedFeaturesEnabled
        requestOptions = RequestOptions(
            source: settings.sourceLanguageCode,
            target: settings.targetLanguageCode,
            compare: settings.compareTranslations,
            advanced: advanced,
            lastProfile: advanced || settings.lastContextProfile == .privateLocal
                ? settings.lastContextProfileCode : nil,
            documentRule: advanced && settings.contextRuleDocumentEnabled,
            developerRule: advanced && settings.contextRuleDeveloperEnabled,
            privateRule: settings.contextRulePrivateEnabled,
            terminology: terminology?.entries ?? [],
            strictTerminology: terminology?.strictMode ?? false
        )
    }

    func matchesResult(from providerID: String, in current: Self) -> Bool {
        guard requestOptions == current.requestOptions,
              let producedBy = providers.first(where: { $0.id == providerID }),
              let configured = current.providers.first(where: { $0.id == providerID }) else {
            return false
        }
        return producedBy == configured
    }
}
