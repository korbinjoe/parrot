import AppKit
import SwiftUI
import Translation
import ParrotCore
import ParrotEngines

/// Runs Apple Translation via SwiftUI `translationTask` (TranslationSession has no public init outside this path).
@available(macOS 15.0, *)
@MainActor
enum AppleTranslationBridge {
    static func translate(text: String, from: Language?, to: Language) async throws -> String {
        let source = from.map(localeLanguage)
        let target = localeLanguage(to)
        return try await withCheckedThrowingContinuation { continuation in
            var window: NSWindow?
            var resumed = false
            let finish: (Result<String, Error>) -> Void = { result in
                window?.close()
                window = nil
                guard !resumed else { return }
                resumed = true
                continuation.resume(with: result)
            }
            let view = OneShotTranslationView(source: source, target: target, text: text, onComplete: finish)
            let hosting = NSHostingController(rootView: view)
            let w = NSWindow(contentViewController: hosting)
            w.setContentSize(NSSize(width: 1, height: 1))
            w.styleMask = []
            w.level = .statusBar
            w.isReleasedWhenClosed = true
            window = w
            w.orderFrontRegardless()
        }
    }

    private static func localeLanguage(_ lang: Language) -> Locale.Language {
        switch lang {
        case .zh: return Locale.Language(identifier: "zh-Hans")
        case .en: return Locale.Language(identifier: "en")
        case .ja: return Locale.Language(identifier: "ja")
        case .ko: return Locale.Language(identifier: "ko")
        case .fr: return Locale.Language(identifier: "fr")
        case .de: return Locale.Language(identifier: "de")
        case .es: return Locale.Language(identifier: "es")
        case .ru: return Locale.Language(identifier: "ru")
        case .custom(let c): return Locale.Language(identifier: c)
        case .auto: return Locale.Language(identifier: "en")
        }
    }
}

@available(macOS 15.0, *)
private struct OneShotTranslationView: View {
    let source: Locale.Language?
    let target: Locale.Language
    let text: String
    let onComplete: (Result<String, Error>) -> Void
    @State private var started = false

    var body: some View {
        Color.clear
            .frame(width: 1, height: 1)
            .translationTask(source: source, target: target) { session in
                guard !started else { return }
                started = true
                do {
                    try await session.prepareTranslation()
                    let response = try await session.translate(text)
                    onComplete(.success(response.targetText))
                } catch {
                    onComplete(.failure(error))
                }
            }
    }
}

/// App-layer Apple Translation engine (requires SwiftUI bridge).
@available(macOS 15.0, *)
final class AppAppleTranslationEngine: HTTPTranslationEngine, @unchecked Sendable {
    static var isSupported: Bool { true }

    init(session: URLSession = .shared) {
        super.init(id: "apple", displayName: "系统翻译", session: session)
    }

    override func translate(_ req: TranslateRequest) async throws -> TranslateResult {
        let from: Language? = req.from == .auto ? nil : req.from
        let translated = try await AppleTranslationBridge.translate(text: req.text, from: from, to: req.to)
        return TranslateResult(
            providerId: id,
            translated: translated,
            detectedFrom: req.from == .auto ? nil : req.from
        )
    }
}
