import AppKit
import SwiftUI
import ParrotCore
import ParrotEngines

// Xcode 16+ (Swift 6) ships the macOS 15 Translation APIs used below; older SDKs get a stub.
#if compiler(>=6.0)
import Translation

/// Runs Apple Translation via SwiftUI `translationTask` (TranslationSession has no public init outside this path).
@available(macOS 15.0, *)
@MainActor
enum AppleTranslationBridge {
    static func translate(text: String, from: Language?, to: Language, requiresPreparation: Bool) async throws -> String {
        let source = from.map(appleLocaleLanguage)
        let target = appleLocaleLanguage(to)
        let runner = AppleTranslationRunner(source: source, target: target, text: text, requiresPreparation: requiresPreparation)
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
    private let requiresPreparation: Bool
    private var panel: NSPanel?
    private var continuation: CheckedContinuation<String, Error>?
    private var watchdogTask: Task<Void, Never>?
    private var completed = false
    private var watchdogNanoseconds: UInt64 {
        requiresPreparation ? 300_000_000_000 : 12_000_000_000
    }

    init(source: Locale.Language?, target: Locale.Language, text: String, requiresPreparation: Bool) {
        self.source = source
        self.target = target
        self.text = text
        self.requiresPreparation = requiresPreparation
    }

    func run() async throws -> String {
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                self.continuation = continuation
                self.start()
            }
        } onCancel: {
            Task { @MainActor [weak self] in
                self?.finish(.failure(CancellationError()))
            }
        }
    }

    private func start() {
        DebugLog.log("apple-translation: start chars=\(text.count)")
        let view = OneShotTranslationView(source: source, target: target, text: text, requiresPreparation: requiresPreparation) { [weak self] result in
            self?.finish(result)
        }
        let hosting = NSHostingController(rootView: view)
        let panelSize = requiresPreparation ? NSSize(width: 380, height: 150) : NSSize(width: 1, height: 1)
        let panel = TranslationTaskPanel(
            contentRect: NSRect(origin: .zero, size: panelSize),
            styleMask: requiresPreparation ? [.titled] : [.borderless],
            backing: .buffered,
            defer: false,
            interactive: requiresPreparation
        )
        panel.contentViewController = hosting
        panel.setContentSize(panelSize)
        panel.level = requiresPreparation ? .floating : .normal
        panel.alphaValue = requiresPreparation ? 1 : 0.01
        panel.title = requiresPreparation ? L("准备系统翻译") : ""
        panel.backgroundColor = requiresPreparation ? .windowBackgroundColor : .clear
        panel.isOpaque = requiresPreparation
        panel.hasShadow = false
        panel.ignoresMouseEvents = !requiresPreparation
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        panel.isReleasedWhenClosed = false
        self.panel = panel
        watchdogTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: self?.watchdogNanoseconds ?? 12_000_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                self?.finish(.failure(ProviderError.timeout))
            }
        }
        if requiresPreparation {
            NSApp.activate(ignoringOtherApps: true)
            panel.center()
            panel.makeKeyAndOrderFront(nil)
        } else {
            panel.orderFrontRegardless()
        }
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
private final class TranslationTaskPanel: NSPanel {
    private let interactive: Bool

    init(contentRect: NSRect, styleMask style: NSWindow.StyleMask, backing bufferingType: NSWindow.BackingStoreType, defer flag: Bool, interactive: Bool) {
        self.interactive = interactive
        super.init(contentRect: contentRect, styleMask: style, backing: bufferingType, defer: flag)
    }

    override var canBecomeKey: Bool { interactive }
    override var canBecomeMain: Bool { false }
}

@available(macOS 15.0, *)
private struct OneShotTranslationView: View {
    let source: Locale.Language?
    let target: Locale.Language
    let text: String
    let requiresPreparation: Bool
    let onComplete: (Result<String, Error>) -> Void
    @State private var started = false

    var body: some View {
        Group {
            if requiresPreparation {
                VStack(spacing: 14) {
                    ProgressView()
                    Text(L("正在下载系统翻译所需的语言资源…")).font(.headline)
                    Text(L("请在出现的系统提示中允许下载；完成后将自动继续翻译。"))
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(24)
                .frame(width: 380, height: 150)
            } else {
                Color.clear.frame(width: 1, height: 1)
            }
        }
            .translationTask(source: source, target: target) { session in
                DebugLog.log("apple-translation: task fired")
                guard !started else { return }
                started = true
                do {
                    if requiresPreparation {
                        DebugLog.log("apple-translation: preparing language resources")
                        try await session.prepareTranslation()
                        DebugLog.log("apple-translation: language resources ready")
                    }
                    let response = try await session.translate(text)
                    onComplete(.success(response.targetText))
                } catch is CancellationError {
                    onComplete(.failure(CancellationError()))
                } catch {
                    DebugLog.log("apple-translation: preparation/translation error \(error)")
                    onComplete(.failure(ProviderError.service(L("系统翻译准备失败，请检查网络后重试"))))
                }
            }
    }
}

/// App-layer Apple Translation engine (requires SwiftUI bridge).
@available(macOS 15.0, *)
final class AppAppleTranslationEngine: HTTPTranslationEngine, @unchecked Sendable {
    static var isSupported: Bool { true }

    init(session: URLSession = .shared) {
        super.init(id: "apple", displayName: L("系统翻译"), session: session)
    }

    override func translate(_ req: TranslateRequest) async throws -> TranslateResult {
        let from: Language? = req.from == .auto ? nil : req.from
        let requiresPreparation = try await preparationRequired(text: req.text, from: from, to: req.to)
        let translated = try await AppleTranslationBridge.translate(text: req.text, from: from, to: req.to, requiresPreparation: requiresPreparation)
        return TranslateResult(
            providerId: id,
            translated: translated,
            detectedFrom: req.from == .auto ? nil : req.from
        )
    }

    private func preparationRequired(text: String, from: Language?, to: Language) async throws -> Bool {
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
            return false
        case .supported:
            return true
        case .unsupported:
            throw ProviderError.unsupportedLanguage
        @unknown default:
            throw ProviderError.unsupportedLanguage
        }
    }
}

#else

/// Stub when building with Xcode 15 / Swift 5 (e.g. CI on macos-14).
@available(macOS 15.0, *)
@MainActor
enum AppleTranslationBridge {
    static func translate(text: String, from: Language?, to: Language, requiresPreparation: Bool) async throws -> String {
        throw ProviderError.unsupportedLanguage
    }
}

@available(macOS 15.0, *)
final class AppAppleTranslationEngine: HTTPTranslationEngine, @unchecked Sendable {
    static var isSupported: Bool { false }

    init(session: URLSession = .shared) {
        super.init(id: "apple", displayName: L("系统翻译"), session: session)
    }

    override func translate(_ req: TranslateRequest) async throws -> TranslateResult {
        throw ProviderError.unsupportedLanguage
    }
}

#endif
