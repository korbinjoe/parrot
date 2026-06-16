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
        let source = from.map(appleLocaleLanguage)
        let target = appleLocaleLanguage(to)
        let runner = AppleTranslationRunner(source: source, target: target, text: text)
        return try await runner.run()
    }
}

@available(macOS 15.0, *)
fileprivate func appleLocaleLanguage(_ lang: Language) -> Locale.Language {
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

@available(macOS 15.0, *)
@MainActor
private final class AppleTranslationRunner: @unchecked Sendable {
    private let source: Locale.Language?
    private let target: Locale.Language
    private let text: String
    private var panel: NSPanel?
    private var continuation: CheckedContinuation<String, Error>?
    private var watchdogTask: Task<Void, Never>?
    private var completed = false
    private static let watchdogNanoseconds: UInt64 = 12_000_000_000

    init(source: Locale.Language?, target: Locale.Language, text: String) {
        self.source = source
        self.target = target
        self.text = text
    }

    func run() async throws -> String {
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                self.continuation = continuation
                self.start()
            }
        } onCancel: {
            Task { @MainActor in
                self.finish(.failure(CancellationError()))
            }
        }
    }

    private func start() {
        DebugLog.log("apple-translation: start chars=\(text.count)")
        let view = OneShotTranslationView(source: source, target: target, text: text) { [weak self] result in
            self?.finish(result)
        }
        let hosting = NSHostingController(rootView: view)
        let panel = HiddenTranslationPanel(
            contentRect: NSRect(x: 0, y: 0, width: 1, height: 1),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        panel.contentViewController = hosting
        panel.setContentSize(NSSize(width: 1, height: 1))
        panel.level = .normal
        panel.alphaValue = 0.01
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        panel.isReleasedWhenClosed = false
        self.panel = panel
        watchdogTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: Self.watchdogNanoseconds)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                self?.finish(.failure(ProviderError.timeout))
            }
        }
        panel.orderFrontRegardless()
    }

    private func finish(_ result: Result<String, Error>) {
        guard !completed else { return }
        completed = true

        switch result {
        case .success(let text):
            DebugLog.log("apple-translation: success chars=\(text.count)")
        case .failure(let error):
            DebugLog.log("apple-translation: failure \(error)")
        }

        let continuation = continuation
        self.continuation = nil
        watchdogTask?.cancel()
        watchdogTask = nil
        panel?.orderOut(nil)
        panel?.close()
        panel = nil
        continuation?.resume(with: result)
    }
}

@available(macOS 15.0, *)
private final class HiddenTranslationPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
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
                DebugLog.log("apple-translation: task fired")
                guard !started else { return }
                started = true
                do {
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
        try await ensureInstalled(text: req.text, from: from, to: req.to)
        let translated = try await AppleTranslationBridge.translate(text: req.text, from: from, to: req.to)
        return TranslateResult(
            providerId: id,
            translated: translated,
            detectedFrom: req.from == .auto ? nil : req.from
        )
    }

    private func ensureInstalled(text: String, from: Language?, to: Language) async throws {
        let availability = LanguageAvailability()
        let target = appleLocaleLanguage(to)
        let status: LanguageAvailability.Status
        do {
            if let from {
                status = await availability.status(from: appleLocaleLanguage(from), to: target)
            } else {
                status = try await availability.status(for: text, to: target)
            }
        } catch {
            throw ProviderError.unsupportedLanguage
        }

        switch status {
        case .installed:
            return
        case .supported:
            throw ProviderError.service("系统翻译语言包未安装")
        case .unsupported:
            throw ProviderError.unsupportedLanguage
        @unknown default:
            throw ProviderError.unsupportedLanguage
        }
    }
}
