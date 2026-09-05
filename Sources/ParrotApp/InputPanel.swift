import AppKit
import SwiftUI
import ParrotCore

/// Spotlight-style input window: type text, press Enter to translate (results show in the
/// floating panel), Esc to dismiss.
@MainActor
final class InputPanel {
    private var window: NSWindow?
    private let state: AppState
    private let onSubmit: (String) -> Void
    private let baseSize = NSSize(width: 540, height: 60)
    private var resignObserver: NSObjectProtocol?
    private var globalMouseDownMonitor: Any?
    private var localMouseDownMonitor: Any?
    private var localKeyDownMonitor: Any?
    private var isHiding = false

    init(state: AppState, onSubmit: @escaping (String) -> Void) {
        self.state = state
        self.onSubmit = onSubmit
    }

    func toggle() {
        if let window, window.isVisible {
            hide()
        } else {
            show()
        }
    }

    func show() {
        if window == nil { build() }
        NSApp.activate(ignoringOtherApps: true)
        guard let window else { return }
        if window.isVisible {
            window.makeKeyAndOrderFront(nil)
            return
        }
        WindowPlacement.center(window)
        isHiding = false
        window.alphaValue = 0
        window.makeKeyAndOrderFront(nil)
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.14
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            window.animator().alphaValue = 1
        }
    }

    func hide() {
        guard let window, window.isVisible else { return }
        guard !isHiding else { return }
        isHiding = true
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.12
            ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
            window.animator().alphaValue = 0
        } completionHandler: { [weak self, weak window] in
            Task { @MainActor [weak self, weak window] in
                window?.orderOut(nil)
                window?.alphaValue = 1
                self?.isHiding = false
            }
        }
    }

    private func build() {
        let view = InputView(
            settings: state.settings,
            onSubmit: { [weak self] text in
                self?.hide()
                self?.onSubmit(text)
            },
            onCancel: { [weak self] in self?.hide() },
            onHeightChange: { [weak self] height in
                self?.resize(toContentHeight: height)
            }
        )
        let hosting = NSHostingController(rootView: view)
        hosting.sizingOptions = [.preferredContentSize]
        let w = NSWindow(contentViewController: hosting)
        w.styleMask = [.titled, .closable, .fullSizeContentView]
        w.titleVisibility = .hidden
        w.titlebarAppearsTransparent = true
        w.level = .floating
        // Clear base so the SwiftUI material + rounded corners define the visible shape.
        w.backgroundColor = .clear
        w.isOpaque = false
        w.hasShadow = true
        w.standardWindowButton(.closeButton)?.isHidden = true
        w.standardWindowButton(.miniaturizeButton)?.isHidden = true
        w.standardWindowButton(.zoomButton)?.isHidden = true
        w.setContentSize(baseSize)
        self.window = w
        installKeyDownMonitor(for: w)

        resignObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didResignKeyNotification, object: w, queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in self?.hide() }
        }
        installOutsideClickMonitors()
    }

    private func resize(toContentHeight height: CGFloat) {
        guard let window else { return }
        let target = NSSize(width: baseSize.width, height: min(max(ceil(height), baseSize.height), 168))
        let current = window.contentLayoutRect.size
        guard abs(current.height - target.height) > 1 || abs(current.width - target.width) > 1 else { return }

        let center = NSPoint(x: window.frame.midX, y: window.frame.midY)
        window.setContentSize(target)
        var frame = window.frame
        frame.origin.x = center.x - frame.width / 2
        frame.origin.y = center.y - frame.height / 2
        window.setFrame(frame, display: true, animate: window.isVisible)
        WindowPlacement.clamp(window)
    }

    private func installOutsideClickMonitors() {
        let mask: NSEvent.EventTypeMask = [.leftMouseDown, .rightMouseDown, .otherMouseDown]
        if globalMouseDownMonitor == nil {
            globalMouseDownMonitor = NSEvent.addGlobalMonitorForEvents(matching: mask) { [weak self] event in
                let point = Self.screenPoint(for: event)
                Task { @MainActor [weak self] in self?.hideAfterOutsideClickIfNeeded(at: point) }
            }
        }
        if localMouseDownMonitor == nil {
            localMouseDownMonitor = NSEvent.addLocalMonitorForEvents(matching: mask) { [weak self] event in
                let point = Self.screenPoint(for: event)
                Task { @MainActor [weak self] in self?.hideAfterOutsideClickIfNeeded(at: point) }
                return event
            }
        }
    }

    /// A vertical SwiftUI TextField normally treats Return as submit. Keep that
    /// fast path, while making Command-Return insert a real newline at the
    /// current insertion point in AppKit's field editor.
    private func installKeyDownMonitor(for window: NSWindow) {
        guard localKeyDownMonitor == nil else { return }
        localKeyDownMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            let isReturn = event.keyCode == 36 || event.keyCode == 76
            guard event.window === window,
                  isReturn,
                  event.modifierFlags.intersection(.deviceIndependentFlagsMask).contains(.command),
                  let editor = window.firstResponder as? NSTextView,
                  editor.isFieldEditor else {
                return event
            }
            editor.insertNewlineIgnoringFieldEditor(nil)
            return nil
        }
    }

    private static func screenPoint(for event: NSEvent) -> NSPoint {
        if let window = event.window {
            return window.convertPoint(toScreen: event.locationInWindow)
        }
        return event.locationInWindow
    }

    private func hideAfterOutsideClickIfNeeded(at point: NSPoint) {
        guard let window, window.isVisible else { return }
        guard !window.frame.insetBy(dx: -6, dy: -6).contains(point) else { return }
        hide()
    }

    deinit {
        if let resignObserver { NotificationCenter.default.removeObserver(resignObserver) }
        if let globalMouseDownMonitor { NSEvent.removeMonitor(globalMouseDownMonitor) }
        if let localMouseDownMonitor { NSEvent.removeMonitor(localMouseDownMonitor) }
        if let localKeyDownMonitor { NSEvent.removeMonitor(localKeyDownMonitor) }
    }
}

private struct InputView: View {
    @ObservedObject var settings: AppSettings
    let onSubmit: (String) -> Void
    let onCancel: () -> Void
    let onHeightChange: (CGFloat) -> Void

    @State private var text: String = ""
    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: Theme.Spacing.s12) {
                Image(systemName: "character.bubble")
                    .font(.system(size: 16))
                    .foregroundStyle(Theme.Palette.label3)
                    .frame(width: 26, height: 26)
                TextField(L("输入要翻译的文本…"), text: $text, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(.system(size: 17))
                    .lineLimit(1...4)
                    .focused($focused)
                    .onSubmit { submit() }
                LangPill(from: .auto, to: settings.targetLanguage)
                Button(action: onCancel) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Theme.Palette.label3)
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)
                .help(L("关闭"))
                .accessibilityLabel(L("关闭输入翻译"))
            }
            .padding(.horizontal, Theme.Spacing.s16)
            .frame(minHeight: 60)

            if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Divider()
                HStack(spacing: Theme.Spacing.s8) {
                    hint("↩"); Text(L("翻译")).foregroundStyle(Theme.Palette.label3)
                    hint("⌘↩"); Text(L("换行")).foregroundStyle(Theme.Palette.label3)
                    hint("⎋"); Text(L("关闭")).foregroundStyle(Theme.Palette.label3)
                    Spacer()
                    Button(L("翻译")) { submit() }
                        .buttonStyle(PrimaryActionButtonStyle())
                        .keyboardShortcut(.return, modifiers: [])
                }
                .font(Theme.Font.caption)
                .padding(.horizontal, Theme.Spacing.s16)
                .frame(height: 42)
            }
        }
        .frame(width: 540)
        .background(Theme.Palette.bgPanel)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.input))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.input)
                .strokeBorder(focused ? Theme.Palette.accent : Theme.Palette.separator,
                              lineWidth: focused ? 1.5 : 0.5)
        )
        .background(
            GeometryReader { geo in
                Color.clear.preference(key: InputHeightKey.self, value: geo.size.height)
            }
        )
        .onPreferenceChange(InputHeightKey.self) { onHeightChange($0) }
        .onAppear { focused = true }
        .onExitCommand { onCancel() }
    }

    private func hint(_ key: String) -> some View {
        Text(key)
            .font(Theme.Font.caption)
            .foregroundStyle(Theme.Palette.label2)
            .frame(minWidth: 24, minHeight: 22)
            .padding(.horizontal, 7)
            .background(Theme.Palette.bgControl)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Theme.Palette.separator, lineWidth: 0.5))
    }

    private func submit() {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        onSubmit(t)
        text = ""
    }
}

private struct InputHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 56
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}
