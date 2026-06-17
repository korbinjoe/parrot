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
    private lazy var floating = FloatingPanel(
        state: state,
        onConfigureProvider: { [weak self] providerID in self?.showSettingsForProvider(providerID) },
        onWorkspaceNoticeAction: { [weak self] action in self?.handleWorkspaceNoticeAction(action) }
    )
    private lazy var settingsWindow = SettingsWindow(state: state) { [weak self] providerID in
        self?.state.retryProvider(providerID)
        self?.floating.show()
    }
    private lazy var historyWindow = HistoryWindow(state: state) { [weak self] text in
        self?.runTranslation(text)
    }
    private let popover = NSPopover()
    private var previousFrontmostApp: NSRunningApplication?
    private var shortcutObserver: NSObjectProtocol?
    private var lastHotkeyFireByAction: [String: Date] = [:]

    private var hotkeys: [HotKey] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        terminateOtherRunningInstances()
        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(handleGetURLEvent(_:withReplyEvent:)),
            forEventClass: AEEventClass(kInternetEventClass),
            andEventID: AEEventID(kAEGetURL)
        )
        setupMainMenu()
        setupStatusItem()
        registerHotKeys()
        shortcutObserver = NotificationCenter.default.addObserver(
            forName: .parrotShortcutsDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.registerHotKeys() }
        }
        state.refreshPermissions()
        DebugLog.log("launch: pid=\(getpid()) AXIsProcessTrusted=\(state.permissions.accessibilityGranted) screenRecording=\(state.permissions.screenRecordingGranted) exe=\(Bundle.main.executablePath ?? "?")")
    }

    private func terminateOtherRunningInstances() {
        guard let bundleIdentifier = Bundle.main.bundleIdentifier else { return }
        let currentPID = getpid()
        for app in NSWorkspace.shared.runningApplications
            where app.processIdentifier != currentPID && app.bundleIdentifier == bundleIdentifier {
            DebugLog.log("single-instance: terminating pid=\(app.processIdentifier) path=\(app.bundleURL?.path ?? "?")")
            app.terminate()
        }
    }

    /// LSUIElement menu-bar apps do not get SwiftUI's standard Edit commands for free.
    /// Installing an Edit menu keeps Cmd-C/Cmd-V/Cmd-A working in SwiftUI TextField/SecureField
    /// controls through the normal AppKit responder chain.
    private func setupMainMenu() {
        let mainMenu = NSMenu()

        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu(title: "Parrot")
        appMenu.addItem(appCommand("输入翻译", action: #selector(showInput), key: ""))
        appMenu.addItem(appCommand("查看历史", action: #selector(showHistory), key: ""))
        appMenu.addItem(appCommand("设置…", action: #selector(showSettings), key: ","))
        appMenu.addItem(.separator())
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

    private func appCommand(_ title: String, action: Selector, key: String) -> NSMenuItem {
        let item = command(title, action: action, key: key)
        item.target = self
        return item
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
        case "ocr-fixture":
            openOCRFixture(text: text, queryItems: comps.queryItems ?? [])
        case "lookup":
            runTranslation(text, mode: .lookup)
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
            onSelection: { [weak self] in self?.closePopoverRestoringPreviousApp { self?.translateSelection() } },
            onLookup: { [weak self] in self?.closePopoverRestoringPreviousApp { self?.lookupSelection() } },
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
            previousFrontmostApp = NSWorkspace.shared.frontmostApplication
            NSApp.activate(ignoringOtherApps: true)
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }

    /// Close the popover first so capture/focus targets the frontmost app, then run the action.
    private func closePopoverThen(_ action: @escaping () -> Void) {
        popover.performClose(nil)
        action()
    }

    /// Selection and lookup need the original app to be frontmost before AX/⌘C capture runs.
    /// The status-item popover activates Parrot, so restore focus and let AppKit settle first.
    private func closePopoverRestoringPreviousApp(_ action: @escaping () -> Void) {
        popover.performClose(nil)
        let app = previousFrontmostApp
        previousFrontmostApp = nil
        if let app, app.processIdentifier != getpid(), !app.isTerminated {
            app.activate(options: [.activateIgnoringOtherApps])
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 120_000_000)
                action()
            }
        } else {
            action()
        }
    }

    // MARK: - Hotkeys

    private func registerHotKeys() {
        hotkeys.removeAll()
        lastHotkeyFireByAction = [:]
        for action in ShortcutAction.allCases {
            let spec = state.settings.shortcutSpec(for: action)
            let handler: () -> Void = { [weak self] in
                guard let self, self.acceptHotkey(action) else { return }
                switch action {
                case .selection: self.translateSelection()
                case .lookup: self.lookupSelection()
                case .screenshot: self.translateScreenshot()
                case .input: self.showInput()
                }
            }
            if let hotKey = HotKey(keyCode: spec.keyCode, modifiers: spec.modifiers, handler: handler) {
                hotkeys.append(hotKey)
            } else {
                DebugLog.log("hotkey: failed action=\(action.rawValue) spec=\(spec.displayText)")
            }
        }
    }

    private func acceptHotkey(_ action: ShortcutAction) -> Bool {
        let now = Date()
        let key = action.rawValue
        if let last = lastHotkeyFireByAction[key], now.timeIntervalSince(last) < 0.75 {
            DebugLog.log("hotkey: ignored repeat action=\(action.rawValue)")
            return false
        }
        lastHotkeyFireByAction[key] = now
        return true
    }

    deinit {
        if let shortcutObserver { NotificationCenter.default.removeObserver(shortcutObserver) }
    }

    // MARK: - Actions

    @objc private func translateSelection() {
        state.refreshPermissions()
        guard state.permissions.accessibilityGranted else {
            showPermissionNotice(.accessibility)
            return
        }
        floating.prepareForExternalCapture()
        let text = SelectionCapture.selectedText()
        DebugLog.log("translateSelection: captured=\(text.map { "\"\($0.prefix(40))\" len=\($0.count)" } ?? "nil")")
        guard let text, !text.isEmpty else { warnIfNoAccessibility(); return }
        runTranslation(text)
    }

    @objc private func lookupSelection() {
        state.refreshPermissions()
        guard state.permissions.accessibilityGranted else {
            showPermissionNotice(.accessibility)
            return
        }
        floating.prepareForExternalCapture()
        guard let text = SelectionCapture.selectedText(), !text.isEmpty else { warnIfNoAccessibility(); return }
        runTranslation(text, mode: .lookup)
    }

    /// When selection capture comes back empty, distinguish "no text selected" (silent — 即用即走)
    /// from "Accessibility permission missing" (loud — otherwise the hotkey just appears dead, e.g.
    /// after the app's identity changes and macOS drops the previously-granted permission).
    private func warnIfNoAccessibility() {
        guard !SelectionCapture.hasAccessibilityPermission(prompt: false) else { return }
        showPermissionNotice(.accessibility)
    }

    @objc private func showSettings() {
        settingsWindow.show()
    }

    private func showSettingsForProvider(_ providerID: String?) {
        guard let providerID,
              let serviceID = CredentialCatalog.normalizedServiceID(providerID) else {
            settingsWindow.show()
            return
        }
        settingsWindow.show(pane: .keys, focusServiceID: serviceID, retryProviderID: providerID)
    }

    @objc private func showHistory() {
        historyWindow.show()
    }

    @objc private func translateScreenshot() {
        state.refreshPermissions()
        guard state.permissions.screenRecordingGranted else {
            state.showScreenRecordingPermissionIssue()
            floating.show()
            return
        }
        Task {
            let providerName = state.ocrCoordinator.activeProvider()?.displayName ?? "OCR"
            do {
                let image = try await ScreenOCR.captureImage()
                state.beginOCRRecognition(providerName: providerName)
                floating.show()
                let result = try await ScreenOCR.recognize(image, coordinator: state.ocrCoordinator)
                guard !result.fullText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    state.showOCRNoText(providerName: providerName)
                    floating.show()
                    return
                }
                state.openOCRWorkspace(result: result, providerName: providerName)
                state.translateDraft()
                floating.show(focusComposer: true)
            } catch ScreenOCR.OCRError.captureCancelled {
                return
            } catch {
                state.showOCRError(error, providerName: providerName)
                floating.show()
            }
        }
    }

    private func showPermissionNotice(_ permission: RequiredPermission) {
        state.refreshPermissions()
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = permission.title
        alert.informativeText = permission.detail
        alert.addButton(withTitle: "打开设置")
        alert.addButton(withTitle: "取消")
        if alert.runModal() == .alertFirstButtonReturn {
            permission.openSettings()
        }
    }

    @objc private func showInput() {
        state.openManualInputWorkspace()
        floating.show(focusComposer: true)
    }

    private func runTranslation(_ text: String, mode: TranslateMode = .translate) {
        state.openWorkspace(text: text, mode: mode, autoRun: true, focusComposer: false)
        floating.show()
    }

    private func handleWorkspaceNoticeAction(_ action: WorkspaceNotice.Action) {
        switch action {
        case .retryScreenshot:
            translateScreenshot()
        case .openScreenRecordingSettings:
            AppPermissions.openScreenRecordingSettings()
        case .openOCRSettings:
            settingsWindow.show(pane: .ocr)
        case .dismiss:
            state.dismissWorkspaceNotice()
        }
    }

    private func openOCRFixture(text: String, queryItems: [URLQueryItem]) {
        let providerName = queryItems.first(where: { $0.name == "provider" })?.value ?? "OCR Fixture"
        let confidenceValue = queryItems.first(where: { $0.name == "confidence" })?.value.flatMap(Float.init) ?? 0.91
        let lines = text
            .split(separator: "\n", omittingEmptySubsequences: true)
            .map(String.init)
        let blocks = lines.enumerated().map { index, line in
            OCRBlock(
                text: line,
                boundingBox: CGRect(x: 0, y: CGFloat(index), width: 1, height: 1),
                confidence: confidenceValue
            )
        }
        let result = OCRResult(
            fullText: text,
            blocks: blocks,
            confidence: confidenceValue
        )
        state.openOCRWorkspace(result: result, providerName: providerName)
        state.translateDraft()
        floating.show(focusComposer: true)
    }
}

private enum RequiredPermission {
    case accessibility
    case screenRecording

    var title: String {
        switch self {
        case .accessibility: return "Parrot 需要「辅助功能」权限"
        case .screenRecording: return "Parrot 需要「屏幕录制」权限"
        }
    }

    var detail: String {
        switch self {
        case .accessibility:
            return "无法读取选中的文字。请在系统设置中允许 Parrot 使用辅助功能，然后重试划词翻译。"
        case .screenRecording:
            return "无法进行截图识别。请在系统设置中允许 Parrot 录制屏幕，然后重试截图翻译。"
        }
    }

    func openSettings() {
        switch self {
        case .accessibility: AppPermissions.openAccessibilitySettings()
        case .screenRecording: AppPermissions.openScreenRecordingSettings()
        }
    }
}
