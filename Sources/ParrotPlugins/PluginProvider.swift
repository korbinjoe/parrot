import Foundation
import ParrotCore

/// Wraps a loaded JS plugin so it participates in the engine registry / aggregation exactly
/// like a built-in `TranslationProvider`.
public final class PluginProvider: TranslationProvider, @unchecked Sendable {
    public let id: String
    public let displayName: String
    public let supportedLanguages: [Language] = [.auto, .zh, .en, .ja, .ko, .fr, .de, .es, .ru]
    public let capabilities: ProviderCapabilities

    private let runtime: PluginRuntime

    public init(manifest: PluginManifest, runtime: PluginRuntime) {
        self.id = "plugin.\(manifest.identifier)"
        self.displayName = manifest.name
        self.runtime = runtime
        let caps = manifest.capabilities ?? ["translate"]
        self.capabilities = ProviderCapabilities(
            supportsLookup: caps.contains("lookup"),
            supportsStream: false,
            supportsPolish: caps.contains("polish"),
            terminology: manifest.supportsTerminology == true ? .prompt : .placeholder
        )
    }

    public func translate(_ req: TranslateRequest) async throws -> TranslateResult {
        var query: [String: Any] = [
            "text": req.text,
            "from": req.from.code ?? "auto",
            "to": req.to.code ?? "en",
            "mode": modeString(req.mode)
        ]
        let terminology = TerminologyProcessor.promptConstraints(for: req)
        if !terminology.isEmpty {
            query["terminology"] = terminology.map {
                [
                    "source": $0.source,
                    "target": $0.target,
                    "from": req.from.code ?? "auto",
                    "to": req.to.code ?? "en"
                ]
            }
        }
        let payload: [String: Any]
        do {
            payload = try await runtime.callTranslate(query: query)
        } catch let e as PluginError {
            throw map(e)
        }

        if let errMsg = payload["error"] as? String {
            throw ProviderError.plugin(errMsg)
        }
        // Accept either { result: { translated } } or { result: { toParagraphs:[...] } } or flat { translated }.
        if let result = payload["result"] as? [String: Any] {
            if let t = result["translated"] as? String {
                return TranslateResult(providerId: id, translated: t)
            }
            if let paras = result["toParagraphs"] as? [String] {
                return TranslateResult(providerId: id, translated: paras.joined(separator: "\n"))
            }
        }
        if let t = payload["translated"] as? String {
            return TranslateResult(providerId: id, translated: t)
        }
        throw ProviderError.plugin("plugin returned no translation")
    }

    private func modeString(_ m: TranslateMode) -> String {
        switch m {
        case .translate: return "translate"
        case .lookup: return "lookup"
        case .polish: return "polish"
        }
    }

    private func map(_ e: PluginError) -> ProviderError {
        switch e {
        case .timeout: return .timeout
        case .networkNotPermitted(let h): return .plugin("network blocked: \(h)")
        default: return .plugin(String(describing: e))
        }
    }
}
