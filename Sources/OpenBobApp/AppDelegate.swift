import AppKit
import Carbon.HIToolbox
import OpenBobCore

/// Menu-bar agent: owns the status item, registers global hotkeys, and routes
/// 划词(⌥D) / 截图OCR(⌥S) / 输入(⌥A) actions into the translation pipeline.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let state = AppState()
    private var statusItem: NSStatusItem?
    private lazy var floating = FloatingPanel(state: state)
    private lazy var inputPanel = InputPanel(state: state) { [weak self] text in
        self?.runTranslation(text)
    }
    private lazy var settingsWindow = SettingsWindow(state: state)

    private var hotkeys: [HotKey] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()
        registerHotKeys()
        _ = SelectionCapture.hasAccessibilityPermission(prompt: true)
    }

    // MARK: - URL scheme (openbob://translate?text=... | openbob://lookup?text=...)

    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls { handle(url) }
    }

    private func handle(_ url: URL) {
        guard url.scheme == "openbob",
              let comps = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return }
        let action = comps.host ?? url.host ?? "translate"
        let text = comps.queryItems?.first(where: { $0.name == "text" })?.value ?? ""
        guard !text.isEmpty else { return }
        switch action {
        case "lookup":
            state.translate(text, mode: .lookup)
            floating.show()
        default:
            runTranslation(text)
        }
    }

    // MARK: - Status item

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = NSImage(systemSymbolName: "character.bubble", accessibilityDescription: "OpenBob")
        let menu = NSMenu()
        menu.addItem(withTitle: "划词翻译 (⌥D)", action: #selector(translateSelection), keyEquivalent: "")
        menu.addItem(withTitle: "查词 (⌥E)", action: #selector(lookupSelection), keyEquivalent: "")
        menu.addItem(withTitle: "截图翻译 (⌥S)", action: #selector(translateScreenshot), keyEquivalent: "")
        menu.addItem(withTitle: "输入翻译 (⌥A)", action: #selector(showInput), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "设置…", action: #selector(showSettings), keyEquivalent: ",")
        menu.addItem(withTitle: "退出 OpenBob", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.items.forEach { $0.target = self }
        item.menu = menu
        self.statusItem = item
    }

    // MARK: - Hotkeys

    private func registerHotKeys() {
        let opt = UInt32(optionKey)
        if let d = HotKey(keyCode: UInt32(kVK_ANSI_D), modifiers: opt, handler: { [weak self] in self?.translateSelection() }) {
            hotkeys.append(d)
        }
        if let s = HotKey(keyCode: UInt32(kVK_ANSI_S), modifiers: opt, handler: { [weak self] in self?.translateScreenshot() }) {
            hotkeys.append(s)
        }
        if let a = HotKey(keyCode: UInt32(kVK_ANSI_A), modifiers: opt, handler: { [weak self] in self?.showInput() }) {
            hotkeys.append(a)
        }
        if let e = HotKey(keyCode: UInt32(kVK_ANSI_E), modifiers: opt, handler: { [weak self] in self?.lookupSelection() }) {
            hotkeys.append(e)
        }
    }

    // MARK: - Actions

    @objc private func translateSelection() {
        guard let text = SelectionCapture.selectedText(), !text.isEmpty else { return }
        runTranslation(text)
    }

    @objc private func lookupSelection() {
        guard let text = SelectionCapture.selectedText(), !text.isEmpty else { return }
        state.translate(text, mode: .lookup)
        floating.show()
    }

    @objc private func showSettings() {
        settingsWindow.show()
    }

    @objc private func translateScreenshot() {
        Task {
            do {
                let text = try await ScreenOCR.captureAndRecognize()
                if !text.isEmpty { runTranslation(text) }
            } catch {
                // user cancelled or nothing recognized — silently ignore (即用即走)
            }
        }
    }

    @objc private func showInput() {
        inputPanel.show()
    }

    private func runTranslation(_ text: String) {
        state.translate(text)
        floating.show()
    }
}
