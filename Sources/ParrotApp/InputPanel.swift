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
    private let baseSize = NSSize(width: 520, height: 56)

    init(state: AppState, onSubmit: @escaping (String) -> Void) {
        self.state = state
        self.onSubmit = onSubmit
    }

    func toggle() {
        if let window, window.isVisible {
            window.orderOut(nil)
        } else {
            show()
        }
    }

    func show() {
        if window == nil { build() }
        window?.center()
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    private func build() {
        let view = InputView(
            target: state.targetLanguage,
            onSubmit: { [weak self] text in
                self?.window?.orderOut(nil)
                self?.onSubmit(text)
            },
            onCancel: { [weak self] in self?.window?.orderOut(nil) },
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
    }
}

private struct InputView: View {
    let target: Language
    let onSubmit: (String) -> Void
    let onCancel: () -> Void
    let onHeightChange: (CGFloat) -> Void

    @State private var text: String = ""
    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: Theme.Spacing.s12) {
                Image(systemName: "character.bubble")
                    .font(.system(size: 18))
                    .foregroundStyle(Theme.Palette.label3)
                TextField("输入要翻译的文本…", text: $text, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(Theme.Font.result)
                    .lineLimit(1...4)
                    .focused($focused)
                    .onSubmit { submit() }
                LangPill(from: .auto, to: target)
            }
            .padding(.horizontal, Theme.Spacing.s16)
            .frame(minHeight: 56)

            if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Divider()
                HStack(spacing: Theme.Spacing.s8) {
                    hint("↩"); Text("翻译").foregroundStyle(Theme.Palette.label3)
                    hint("⎋"); Text("关闭").foregroundStyle(Theme.Palette.label3)
                    Spacer()
                    Button("翻译") { submit() }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        .keyboardShortcut(.return, modifiers: [])
                }
                .font(Theme.Font.caption)
                .padding(.horizontal, Theme.Spacing.s16)
                .frame(height: 38)
            }
        }
        .frame(width: 520)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.window))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.window)
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
            .padding(.horizontal, 5)
            .padding(.vertical, 1)
            .background(Theme.Palette.bgContent2)
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(Theme.Palette.separator, lineWidth: 0.5))
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
