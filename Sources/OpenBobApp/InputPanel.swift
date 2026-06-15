import AppKit
import SwiftUI

/// Small input window: type text, press Enter to translate (results show in the floating panel).
@MainActor
final class InputPanel {
    private var window: NSWindow?
    private let state: AppState
    private let onSubmit: (String) -> Void

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
        let view = InputView { [weak self] text in
            self?.window?.orderOut(nil)
            self?.onSubmit(text)
        }
        let hosting = NSHostingController(rootView: view)
        let w = NSWindow(contentViewController: hosting)
        w.styleMask = [.titled, .closable, .fullSizeContentView]
        w.titleVisibility = .hidden
        w.titlebarAppearsTransparent = true
        w.level = .floating
        w.setContentSize(NSSize(width: 420, height: 120))
        self.window = w
    }
}

private struct InputView: View {
    @State private var text: String = ""
    @FocusState private var focused: Bool
    let onSubmit: (String) -> Void

    var body: some View {
        VStack(spacing: 8) {
            TextField("输入要翻译的文本，回车翻译…", text: $text, axis: .vertical)
                .textFieldStyle(.plain)
                .font(.system(size: 14))
                .lineLimit(1...4)
                .focused($focused)
                .onSubmit { submit() }
            HStack {
                Spacer()
                Button("翻译") { submit() }
                    .keyboardShortcut(.return, modifiers: [])
            }
        }
        .padding(16)
        .frame(width: 420)
        .onAppear { focused = true }
    }

    private func submit() {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        onSubmit(t)
        text = ""
    }
}
