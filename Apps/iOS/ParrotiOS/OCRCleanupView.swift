import SwiftUI

struct OCRCleanupView: View {
    @EnvironmentObject private var state: IOSAppState

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("OCR Cleanup")
                    .font(.headline)
                Spacer()
                Button {
                    state.copySourceDraft()
                } label: {
                    Image(systemName: "doc.on.doc")
                        .frame(width: 34, height: 34)
                }
                .buttonStyle(.bordered)
                .accessibilityLabel("Copy recognized text")
                .accessibilityIdentifier("OCRCopySource")
                .disabled((state.activeSession?.sourceDraft.trimmingCharacters(in: .whitespacesAndNewlines) ?? "").isEmpty)
            }
            if let image = state.activeOCRThumbnail() {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .frame(height: 150)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(IOSTheme.line))
            }
            TextEditor(text: Binding(
                get: { state.activeSession?.sourceDraft ?? "" },
                set: { state.updateSourceDraft($0) }
            ))
            .accessibilityIdentifier("OCRTextEditor")
            .frame(minHeight: 160)
            .scrollContentBackground(.hidden)
            .padding(8)
            .background(IOSTheme.surface2)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            FlowLayout(spacing: 7) {
                ForEach(OCRCleanupAction.allCases, id: \.title) { action in
                    Button(action.title) {
                        state.applyOCRCleanup(action)
                    }
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(IOSTheme.cyan.opacity(0.15))
                    .clipShape(Capsule())
                }
            }

            HStack {
                Button("Understand") {
                    Task { await state.understandActiveSession() }
                }
                .buttonStyle(.borderedProminent)
                .tint(IOSTheme.green)
                Button("Write reply") {
                    state.openManualExpress()
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(14)
        .parrotCard()
    }
}
