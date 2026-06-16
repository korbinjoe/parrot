import Foundation
import ParrotCore
import ParrotEngines

enum EngineValidator {
    /// Probe a configured engine with a minimal translate request.
    static func validate(_ provider: TranslationProvider) async -> Bool {
        do {
            _ = try await provider.translate(TranslateRequest(text: "hi", from: .en, to: .zh))
            return true
        } catch ProviderError.auth, ProviderError.notConfigured, ProviderError.service(_) {
            return false
        } catch {
            // Network/rate-limit still means credentials likely OK.
            return true
        }
    }

    @MainActor
    static func makeConfiguredProvider(id: String, settings: AppSettings) -> TranslationProvider? {
        let registry = ProviderRegistry()
        EngineBootstrap.registerAll(into: registry, settings: settings)
        return registry.provider(id: id)
    }
}
