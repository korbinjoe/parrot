import ParrotSocial
import SwiftUI

struct UnderstandWorkspaceView: View {
    @EnvironmentObject private var state: IOSAppState

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    if state.activeSession?.mode == .ocr {
                        OCRCleanupView()
                    } else {
                        sourceEditor
                    }
                    if let error = state.errorNotice {
                        notice(error)
                    }
                    if state.isProcessing {
                        ProgressView("Explaining context...")
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(14)
                            .parrotCard()
                    }
                    if let result = state.activeSession?.understand {
                        if let translation = visibleTranslation(result) {
                            translationCard(translation)
                        }
                        meaningCard(result)
                        phraseGrid(result)
                    }
                    actionRow
                }
                .padding(16)
            }
            .background(IOSTheme.paper.ignoresSafeArea())
            .navigationTitle("Understand")
            .toolbar {
                Button("Reply") { state.openManualExpress() }
            }
        }
    }

    private var sourceEditor: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(state.activeSession?.platform.displayName ?? "Source", systemImage: "text.quote")
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(IOSTheme.muted)
                Spacer()
                Button {
                    state.copySourceDraft()
                } label: {
                    Image(systemName: "doc.on.doc")
                        .frame(width: 34, height: 34)
                }
                .buttonStyle(.bordered)
                .accessibilityLabel("Copy source")
                .accessibilityIdentifier("UnderstandCopySource")
                .disabled((state.activeSession?.sourceDraft.trimmingCharacters(in: .whitespacesAndNewlines) ?? "").isEmpty)

                Button("Explain") {
                    Task { await state.understandActiveSession() }
                }
                .buttonStyle(.borderedProminent)
                .tint(IOSTheme.green)
            }
            TextEditor(text: Binding(
                get: { state.activeSession?.sourceDraft ?? "" },
                set: { state.updateSourceDraft($0) }
            ))
            .accessibilityIdentifier("UnderstandSourceEditor")
            .frame(minHeight: 110)
            .scrollContentBackground(.hidden)
            .padding(8)
            .background(IOSTheme.surface2)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .padding(14)
        .parrotCard()
    }

    private func meaningCard(_ result: UnderstandResult) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Meaning")
                .font(.caption.weight(.bold))
                .foregroundStyle(Color(red: 0.04, green: 0.49, blue: 0.26))
            Text(result.meaningSummary)
                .font(.title3.weight(.semibold))
                .foregroundStyle(IOSTheme.ink)
            if let note = result.confidenceNote {
                Text(note)
                    .font(.caption)
                    .foregroundStyle(IOSTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            tagRow(result.toneTags)
        }
        .padding(16)
        .background(
            LinearGradient(colors: [IOSTheme.meaningTint, IOSTheme.surface], startPoint: .topLeading, endPoint: .bottomTrailing)
        )
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(IOSTheme.line))
    }

    private func translationCard(_ translation: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Translation")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color(red: 0.04, green: 0.49, blue: 0.26))
                Spacer()
                Button {
                    state.copy(translation)
                } label: {
                    Image(systemName: "doc.on.doc")
                        .frame(width: 34, height: 34)
                }
                .buttonStyle(.bordered)
                .accessibilityLabel("Copy translation")
                .accessibilityIdentifier("UnderstandCopyTranslation")
            }
            Text(translation)
                .font(.title3.weight(.semibold))
                .foregroundStyle(IOSTheme.ink)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("UnderstandTranslation")
        }
        .padding(16)
        .background(IOSTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(IOSTheme.line))
    }

    private func phraseGrid(_ result: UnderstandResult) -> some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            ForEach(result.phraseExplanations) { phrase in
                VStack(alignment: .leading, spacing: 6) {
                    Text(phrase.phrase)
                        .font(.subheadline.weight(.bold))
                    Text(phrase.explanation)
                        .font(.caption)
                        .foregroundStyle(IOSTheme.muted)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .parrotCard()
            }
        }
    }

    private func visibleTranslation(_ result: UnderstandResult) -> String? {
        let translation = result.fullTranslation?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !translation.isEmpty else { return nil }
        let source = state.activeSession?.sourceDraft.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return translation == source ? nil : translation
    }

    private var actionRow: some View {
        HStack(spacing: 10) {
            Button {
                state.openManualExpress()
            } label: {
                Label("Reply", systemImage: "arrowshape.turn.up.left.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(IOSTheme.green)

            Button {
                if let summary = state.activeSession?.understand?.meaningSummary {
                    state.copy(summary)
                }
            } label: {
                Image(systemName: "doc.on.doc")
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.bordered)
        }
    }

    private func tagRow(_ tags: [String]) -> some View {
        FlowLayout(spacing: 7) {
            ForEach(tags, id: \.self) { tag in
                Text(tag)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(IOSTheme.muted)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(IOSTheme.subtleFill)
                    .clipShape(Capsule())
            }
        }
    }

    private func notice(_ text: String) -> some View {
        Text(text)
            .font(.footnote)
            .foregroundStyle(.red)
            .padding(12)
            .parrotCard()
    }
}
