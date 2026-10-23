import Foundation
import ParrotCore
import ParrotEngines

enum EngineValidator {
    enum Result: Equatable, Sendable {
        case passed
        case failed(String)

        var isPassed: Bool {
            if case .passed = self { return true }
            return false
        }
    }

    struct ValidationTarget: Sendable {
        let provider: TranslationProvider
        let modelName: String?
        let providerID: String
    }

    /// Builds isolated providers from a draft. This never saves credentials or preferences.
    @MainActor
    static func makeDraftProviders(
        descriptor: CredentialDescriptor,
        settings: AppSettings,
        secretDraft: String,
        models: [EngineModelConfig],
        endpoint: String,
        region: String? = nil
    ) -> [ValidationTarget] {
        guard descriptor.supportsValidation, let engineID = descriptor.linkedEngineID,
              CredentialDraftValidation.issues(descriptor: descriptor, secret: secretDraft, models: models, endpoint: endpoint, region: region).isEmpty else {
            return []
        }

        let key: String?
        if let credential = descriptor.credential {
            let draft = secretDraft.trimmingCharacters(in: .whitespacesAndNewlines)
            key = settings.envNonEmpty(credential.env)
                ?? (draft.isEmpty ? nil : draft)
                ?? settings.key(credential.account, env: credential.env)
                ?? descriptor.fallbackCredential.flatMap { settings.key($0.account, env: $0.env) }
        } else if engineID == "ollama" {
            key = settings.ollamaKey()
        } else {
            key = nil
        }
        var extra: [String: String] = [:]
        if let key { extra["apiKey"] = key }
        let endpoint = endpoint.trimmingCharacters(in: .whitespacesAndNewlines)
        if !endpoint.isEmpty { extra["endpoint"] = endpoint }
        if let region {
            extra["region"] = region.trimmingCharacters(in: .whitespacesAndNewlines)
        } else if engineID == "microsoft" {
            extra["region"] = settings.microsoftRegion
        } else if engineID == "amazon" {
            extra["region"] = settings.amazonRegion
        }

        if descriptor.defaultModel != nil {
            return models.filter(\.enabled).compactMap { model in
                guard let provider = makeUnconfiguredProvider(id: engineID) else { return nil }
                var modelExtra = extra
                modelExtra["model"] = model.trimmedName
                do { try provider.configure(ProviderConfig(extra: modelExtra)) }
                catch { return nil }
                return ValidationTarget(provider: provider, modelName: model.trimmedName, providerID: model.providerID(engineID: engineID))
            }
        }
        guard let provider = makeUnconfiguredProvider(id: engineID) else { return [] }
        do { try provider.configure(ProviderConfig(extra: extra)) }
        catch { return [] }
        return [ValidationTarget(provider: provider, modelName: nil, providerID: engineID)]
    }

    /// Probe every enabled model, within a shared deadline, without touching the live registry.
    static func validateTargets(
        _ targets: [ValidationTarget],
        timeoutPerTarget: TimeInterval = 30,
        totalTimeout: TimeInterval = 90
    ) async -> Result {
        guard !targets.isEmpty else { return .failed(L("没有可测试的服务，请检查配置并至少启用一个模型。")) }
        let deadline = Date().addingTimeInterval(max(0, totalTimeout))
        var failures: [String] = []
        for target in targets {
            if Task.isCancelled { return .failed(L("已取消连接测试。")) }
            let remaining = deadline.timeIntervalSinceNow
            guard remaining > 0 else {
                failures.append(L("连接测试超时，请检查服务或稍后重试。"))
                return .failed(failures.joined(separator: "\n"))
            }
            let result = await validateWithinDeadline(target.provider, timeout: min(max(0, timeoutPerTarget), remaining))
            if Task.isCancelled { return .failed(L("已取消连接测试。")) }
            if case .failed(let message) = result {
                failures.append(target.modelName.map { L("模型 %@：%@", $0, message) } ?? message)
            }
        }
        return failures.isEmpty ? .passed : .failed(failures.joined(separator: "\n"))
    }

    private static func validateWithinDeadline(_ provider: TranslationProvider, timeout: TimeInterval) async -> Result {
        let race = ValidationRace()
        return await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                race.setContinuation(continuation)
                let requestTask = Task {
                    let result = await validateDetailed(provider)
                    race.finish(result)
                }
                let deadlineTask = Task {
                    do {
                        try await Task.sleep(nanoseconds: UInt64(min(max(0, timeout), 90) * 1_000_000_000))
                        race.finish(.failed(L("连接测试超时，请检查服务或稍后重试。")))
                    } catch {}
                }
                race.setTasks([requestTask, deadlineTask])
            }
        } onCancel: {
            race.finish(.failed(L("已取消连接测试。")))
        }
    }

    private static func makeUnconfiguredProvider(id: String) -> TranslationProvider? {
        switch id {
        case "google": return GoogleTranslationLLMEngine()
        case "deepl": return DeepLEngine()
        case "tencent": return TencentEngine()
        case "baidu": return BaiduEngine()
        case "youdao": return YoudaoEngine()
        case "caiyun": return CaiyunEngine()
        case "microsoft": return MicrosoftEngine()
        case "openai": return OpenAIEngine()
        case "opencode": return OpenCodeGoEngine()
        case "deepseek": return DeepSeekEngine()
        case "gemini": return GeminiEngine()
        case "groq": return GroqEngine()
        case "ollama": return OllamaEngine()
        case "qwen": return QwenEngine()
        case "doubao": return DoubaoEngine()
        case "kimi": return KimiEngine()
        case "zhipu": return ZhipuEngine()
        case "siliconflow": return SiliconFlowEngine()
        case "ernie": return ErnieEngine()
        case "hunyuan": return HunyuanEngine()
        case "yi": return YiEngine()
        case "azure-openai": return AzureOpenAIEngine()
        case "volcengine": return VolcengineEngine()
        case "aliyun": return AliyunEngine()
        case "niutrans": return NiutransEngine()
        case "amazon": return AmazonTranslateEngine()
        default: return nil
        }
    }

    /// Probe a configured engine with a minimal translate request.
    static func validate(_ provider: TranslationProvider) async -> Bool {
        await validateDetailed(provider).isPassed
    }

    /// Probe a configured engine and preserve enough failure detail for settings recovery UI.
    static func validateDetailed(_ provider: TranslationProvider) async -> Result {
        do {
            let result = try await provider.translate(TranslateRequest(text: "hi", from: .en, to: .zh))
            guard !result.translated.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                return .failed(L("服务未返回译文，请检查模型配置后重试。"))
            }
            return .passed
        } catch ProviderError.auth {
            return .failed(L("鉴权失败：检查 Key 是否正确、是否已开通该服务。"))
        } catch ProviderError.notConfigured {
            return .failed(L("尚未填写 Key，请输入后再测试连接。"))
        } catch ProviderError.service(let message) {
            return .failed(L("服务返回错误：%@", message))
        } catch ProviderError.unsupportedLanguage {
            return .failed(L("不支持当前验证语言：检查服务区域或语言能力。"))
        } catch ProviderError.network {
            return .failed(L("网络错误"))
        } catch ProviderError.timeout {
            return .failed(L("请求超时"))
        } catch ProviderError.rateLimited {
            return .failed(L("请求过于频繁，请稍后重试"))
        } catch ProviderError.plugin(let message) {
            return .failed(L("插件错误：%@", message))
        } catch {
            return .failed(L("服务返回错误：%@", error.localizedDescription))
        }
    }

    @MainActor
    static func makeConfiguredProvider(id: String, settings: AppSettings) -> TranslationProvider? {
        let registry = ProviderRegistry()
        EngineBootstrap.registerAll(into: registry, settings: settings, configureDisabledProviders: true)
        return registry.provider(id: id)
    }
}

/// Resumes exactly once and cancels the losing request/deadline. An uncooperative provider
/// cannot hold the settings UI open after cancellation or the validation deadline.
private final class ValidationRace: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<EngineValidator.Result, Never>?
    private var result: EngineValidator.Result?
    private var tasks: [Task<Void, Never>] = []

    func setContinuation(_ continuation: CheckedContinuation<EngineValidator.Result, Never>) {
        lock.lock()
        if let result {
            lock.unlock()
            continuation.resume(returning: result)
        } else {
            self.continuation = continuation
            lock.unlock()
        }
    }

    func setTasks(_ tasks: [Task<Void, Never>]) {
        lock.lock()
        if result != nil {
            lock.unlock()
            tasks.forEach { $0.cancel() }
        } else {
            self.tasks = tasks
            lock.unlock()
        }
    }

    func finish(_ result: EngineValidator.Result) {
        lock.lock()
        guard self.result == nil else { lock.unlock(); return }
        self.result = result
        let continuation = self.continuation
        self.continuation = nil
        let tasks = self.tasks
        self.tasks = []
        lock.unlock()
        tasks.forEach { $0.cancel() }
        continuation?.resume(returning: result)
    }
}
