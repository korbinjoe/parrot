import AppKit
import SwiftUI
import ParrotCore

/// After screenshot OCR, presents the recognized lines as a checkable list so the user can pick
/// exactly which lines to translate. Confirming routes the joined selection into the result panel.
@MainActor
final class OCRResultPanel {
    private var window: NSWindow?
    private let onTranslate: (String) -> Void

    init(onTranslate: @escaping (String) -> Void) {
        self.onTranslate = onTranslate
    }

    func present(lines: [String]) {
        let view = OCRResultView(
            lines: lines,
            onTranslate: { [weak self] text in
                self?.window?.orderOut(nil)
                self?.onTranslate(text)
            },
            onCancel: { [weak self] in self?.window?.orderOut(nil) }
        )
        let hosting = NSHostingController(rootView: view)
        let w = NSWindow(contentViewController: hosting)
        w.styleMask = [.titled, .closable, .fullSizeContentView]
        w.titleVisibility = .hidden
        w.titlebarAppearsTransparent = true
        w.level = .floating
        w.backgroundColor = .clear
        w.isOpaque = false
        w.hasShadow = true
        w.standardWindowButton(.closeButton)?.isHidden = true
        w.standardWindowButton(.miniaturizeButton)?.isHidden = true
        w.standardWindowButton(.zoomButton)?.isHidden = true
        w.setContentSize(NSSize(width: 360, height: 380))
        self.window = w

        NSApp.activate(ignoringOtherApps: true)
        w.center()
        w.makeKeyAndOrderFront(nil)
    }
}

private struct OCRResultView: View {
    let lines: [String]
    let onTranslate: (String) -> Void
    let onCancel: () -> Void

    @State private var selected: Set<Int>

    init(lines: [String], onTranslate: @escaping (String) -> Void, onCancel: @escaping () -> Void) {
        self.lines = lines
        self.onTranslate = onTranslate
        self.onCancel = onCancel
        // Default: everything selected — the common case is "translate all of it".
        _selected = State(initialValue: Set(lines.indices))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            ScrollView {
                VStack(spacing: 2) {
                    ForEach(Array(lines.enumerated()), id: \.offset) { idx, line in
                        lineRow(idx, line)
                    }
                }
                .padding(Theme.Spacing.s8)
            }
            Divider()
            footer
        }
        .frame(width: 360, height: 380)
        .background(Theme.Palette.bgPanel)
        .clipShape(RoundedRectangle(cornerRadius: 13))
        .overlay(
            RoundedRectangle(cornerRadius: 13)
                .strokeBorder(Theme.Palette.separator, lineWidth: 0.5)
        )
        .onExitCommand { onCancel() }
    }

    private var header: some View {
        HStack(spacing: Theme.Spacing.s8) {
            Image(systemName: "camera.viewfinder").foregroundStyle(Theme.Palette.accent)
            Text("识别到 \(lines.count) 行").font(Theme.Font.body).foregroundStyle(Theme.Palette.label)
            Spacer(minLength: 0)
            Button(allSelected ? "取消全选" : "全选") { toggleAll() }
                .buttonStyle(.borderless).font(Theme.Font.callout)
                .foregroundStyle(Theme.Palette.accent)
        }
        .padding(.horizontal, Theme.Spacing.s12).frame(height: 42)
    }

    private func lineRow(_ idx: Int, _ line: String) -> some View {
        let on = selected.contains(idx)
        return HStack(alignment: .top, spacing: Theme.Spacing.s8) {
            ZStack {
                Circle()
                    .fill(on ? Theme.Palette.accent : Color.clear)
                    .overlay(Circle().strokeBorder(on ? Theme.Palette.accent : Theme.Palette.label3, lineWidth: 1.5))
                if on {
                    Image(systemName: "checkmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(Theme.Palette.accentInk)
                }
            }
            .frame(width: 18, height: 18)
            Text(line)
                .font(Theme.Font.callout).foregroundStyle(Theme.Palette.label)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(8)
        .background(on ? Theme.Palette.bgSelection : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .contentShape(Rectangle())
        .onTapGesture { toggle(idx) }
    }

    private var footer: some View {
        HStack(spacing: Theme.Spacing.s8) {
            Text("⎋ 关闭").font(Theme.Font.caption).foregroundStyle(Theme.Palette.label3)
            Spacer(minLength: 0)
            Button("复制选中") { copy() }
                .controlSize(.small).disabled(selected.isEmpty)
            Button("翻译选中") { translate() }
                .buttonStyle(PrimaryActionButtonStyle())
                .keyboardShortcut(.return, modifiers: [])
                .disabled(selected.isEmpty)
        }
        .padding(.horizontal, 10).frame(height: 46)
    }

    // MARK: - Helpers

    private var allSelected: Bool { selected.count == lines.count }

    private func toggle(_ idx: Int) {
        if selected.contains(idx) { selected.remove(idx) } else { selected.insert(idx) }
    }

    private func toggleAll() {
        selected = allSelected ? [] : Set(lines.indices)
    }

    private func joinedSelection() -> String {
        lines.enumerated()
            .filter { selected.contains($0.offset) }
            .map { $0.element }
            .joined(separator: "\n")
    }

    private func translate() {
        let text = joinedSelection()
        guard !text.isEmpty else { return }
        onTranslate(text)
    }

    private func copy() {
        let text = joinedSelection()
        guard !text.isEmpty else { return }
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(text, forType: .string)
    }
}
