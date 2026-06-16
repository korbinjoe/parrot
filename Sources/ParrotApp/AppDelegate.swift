import AppKit
import SwiftUI
import Carbon.HIToolbox
import ParrotCore

/// Menu-bar agent: owns the status item, registers global hotkeys, and routes
/// 划词(⌥D) / 截图OCR(⌥S) / 输入(⌥A) actions into the translation pipeline.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let state = AppState()
    private var statusItem: NSStatusItem?
    private lazy var floating = FloatingPanel(state: state) { [weak self] in
        self?.showSettings()
    }
    private lazy var inputPanel = InputPanel(state: state) { [weak self] text in
        self?.runTranslation(text)
    }
    private lazy var settingsWindow = SettingsWindow(state: state)
    private lazy var historyWindow = HistoryWindow(state: state) { [weak self] text in
        self?.runTranslation(text)
    }
    private lazy var ocrResultPanel = OCRResultPanel { [weak self] text in
        self?.runTranslation(text)
    }
    private let popover = NSPopover()

    private var hotkeys: [HotKey] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(handleGetURLEvent(_:withReplyEvent:)),
            forEventClass: AEEventClass(kInternetEventClass),
            andEventID: AEEventID(kAEGetURL)
        )
        setupMainMenu()
        setupStatusItem()
        registerHotKeys()
        let trusted = SelectionCapture.hasAccessibilityPermission(prompt: true)
        DebugLog.log("launch: pid=\(getpid()) AXIsProcessTrusted=\(trusted) exe=\(Bundle.main.executablePath ?? "?")")
    }

    /// LSUIElement menu-bar apps do not get SwiftUI's standard Edit commands for free.
    /// Installing an Edit menu keeps Cmd-C/Cmd-V/Cmd-A working in SwiftUI TextField/SecureField
    /// controls through the normal AppKit responder chain.
    private func setupMainMenu() {
        let mainMenu = NSMenu()

        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu(title: "Parrot")
        appMenu.addItem(NSMenuItem(title: "退出 Parrot", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)

        let editMenuItem = NSMenuItem()
        let editMenu = NSMenu(title: "编辑")
        editMenu.addItem(command("撤销", action: Selector(("undo:")), key: "z"))
        editMenu.addItem(command("重做", action: Selector(("redo:")), key: "Z"))
        editMenu.addItem(.separator())
        editMenu.addItem(command("剪切", action: #selector(NSText.cut(_:)), key: "x"))
        editMenu.addItem(command("复制", action: #selector(NSText.copy(_:)), key: "c"))
        editMenu.addItem(command("粘贴", action: #selector(NSText.paste(_:)), key: "v"))
        editMenu.addItem(command("删除", action: #selector(NSText.delete(_:)), key: ""))
        editMenu.addItem(.separator())
        editMenu.addItem(command("全选", action: #selector(NSText.selectAll(_:)), key: "a"))
        editMenuItem.submenu = editMenu
        mainMenu.addItem(editMenuItem)

        NSApp.mainMenu = mainMenu
    }

    private func command(_ title: String, action: Selector, key: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.keyEquivalentModifierMask = key.isEmpty ? [] : [.command]
        item.target = nil
        return item
    }

    // MARK: - URL scheme (parrot://translate?text=... | parrot://lookup?text=...)

    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls { handle(url) }
    }

    private func handle(_ url: URL) {
        guard url.scheme == "parrot",
              let comps = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return }
        let action = comps.host ?? url.host ?? "translate"
        let text = comps.queryItems?.first(where: { $0.name == "text" })?.value ?? ""
        guard !text.isEmpty else { return }
        DebugLog.log("url: action=\(action) textLen=\(text.count)")
        switch action {
        case "lookup":
            state.translate(text, mode: .lookup)
            floating.show()
        default:
            runTranslation(text)
        }
    }

    @objc private func handleGetURLEvent(_ event: NSAppleEventDescriptor, withReplyEvent replyEvent: NSAppleEventDescriptor) {
        guard let value = event.paramDescriptor(forKeyword: keyDirectObject)?.stringValue,
              let url = URL(string: value) else { return }
        handle(url)
    }

    // MARK: - Status item

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = NSImage(systemSymbolName: "character.bubble", accessibilityDescription: "Parrot")
        item.button?.action = #selector(togglePopover)
        item.button?.target = self
        self.statusItem = item

        let content = MenuBarPopoverView(
            state: state,
            onSelection: { [weak self] in self?.closePopoverThen { self?.translateSelection() } },
            onLookup: { [weak self] in self?.closePopoverThen { self?.lookupSelection() } },
            onScreenshot: { [weak self] in self?.closePopoverThen { self?.translateScreenshot() } },
            onInput: { [weak self] in self?.closePopoverThen { self?.showInput() } },
            onSettings: { [weak self] in self?.closePopoverThen { self?.showSettings() } },
            onHistory: { [weak self] in self?.closePopoverThen { self?.historyWindow.show() } },
            onRetranslate: { [weak self] text in self?.closePopoverThen { self?.runTranslation(text) } },
            onQuit: { NSApp.terminate(nil) }
        )
        popover.contentViewController = NSHostingController(rootView: content)
        popover.behavior = .transient
    }

    @objc private func togglePopover() {
        guard let button = statusItem?.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            NSApp.activate(ignoringOtherApps: true)
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }

    /// Close the popover first so capture/focus targets the frontmost app, then run the action.
    private func closePopoverThen(_ action: @escaping () -> Void) {
        popover.performClose(nil)
        action()
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
        floating.prepareForExternalCapture()
        let text = SelectionCapture.selectedText()
        DebugLog.log("translateSelection: captured=\(text.map { "\"\($0.prefix(40))\" len=\($0.count)" } ?? "nil")")
        guard let text, !text.isEmpty else { warnIfNoAccessibility(); return }
        runTranslation(text)
    }

    @objc private func lookupSelection() {
        floating.prepareForExternalCapture()
        guard let text = SelectionCapture.selectedText(), !text.isEmpty else { warnIfNoAccessibility(); return }
        state.translate(text, mode: .lookup)
        floating.show()
    }

    /// When selection capture comes back empty, distinguish "no text selected" (silent — 即用即走)
    /// from "Accessibility permission missing" (loud — otherwise the hotkey just appears dead, e.g.
    /// after the app's identity changes and macOS drops the previously-granted permission).
    private func warnIfNoAccessibility() {
        guard !SelectionCapture.hasAccessibilityPermission(prompt: false) else { return }
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "Parrot 需要「辅助功能」权限"
        alert.informativeText = "无法读取选中的文字。请在 系统设置 → 隐私与安全性 → 辅助功能 中重新勾选 Parrot，然后重试 ⌥D。"
        alert.addButton(withTitle: "打开设置")
        alert.addButton(withTitle: "取消")
        if alert.runModal() == .alertFirstButtonReturn,
           let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    @objc private func showSettings() {
        settingsWindow.show()
    }

    @objc private func translateScreenshot() {
        Task {
            do {
                let lines = try await ScreenOCR.captureAndRecognizeLines(coordinator: state.ocrCoordinator)
                guard !lines.isEmpty else { return }
                if lines.count == 1 {
                    // Single line — translate immediately (即用即走), no picker.
                    runTranslation(lines[0])
                } else {
                    // Multiple lines — let the user pick which to translate.
                    ocrResultPanel.present(lines: lines)
                }
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
