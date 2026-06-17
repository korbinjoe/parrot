import Foundation
import ParrotCore
import ParrotEngines

enum EngineValidator {
    enum Result: Equatable {
        case passed
        case failed(String)

        var isPassed: Bool {
            if case .passed = self { return true }
            return false
        }
    }

    /// Probe a configured engine with a minimal translate request.
    static func validate(_ provider: TranslationProvider) async -> Bool {
        await validateDetailed(provider).isPassed
    }

    /// Probe a configured engine and preserve enough failure detail for settings recovery UI.
    static func validateDetailed(_ provider: TranslationProvider) async -> Result {
        do {
            _ = try await provider.translate(TranslateRequest(text: "hi", from: .en, to: .zh))
            return .passed
        } catch ProviderError.auth {
            return .failed("鉴权失败：检查 Key 是否正确、是否已开通该服务。")
        } catch ProviderError.notConfigured {
            return .failed("未配置：先保存 Key，再验证。")
        } catch ProviderError.service(let message) {
            return .failed("服务返回错误：\(message)")
        } catch ProviderError.unsupportedLanguage {
            return .failed("不支持当前验证语言：检查服务区域或语言能力。")
        } catch {
            // Network/rate-limit still means credentials likely OK.
            return .passed
        }
    }

    @MainActor
    static func makeConfiguredProvider(id: String, settings: AppSettings) -> TranslationProvider? {
        let registry = ProviderRegistry()
        EngineBootstrap.registerAll(into: registry, settings: settings)
        return registry.provider(id: id)
    }
}
