import ParrotSocial
import SwiftUI

struct UnderstandWorkspaceView: View {
    @EnvironmentObject private var state: IOSAppState

    var body: some View {
        VStack(spacing: 0) {
            AppHeader(leadingTitle: "Back", leadingAction: {
                state.selectedTab = .today
            }, title: "Workspace") {
                MiniIconButton(systemName: "gearshape") {
                    state.selectedTab = .engines
                }
                .accessibilityLabel("Settings")
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    originStrip
                    sourceComposer
                    if let error = state.errorNotice {
                        notice(error)
                    }
                    resultStack
                    replyDock
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 78)
            }
            .scrollIndicators(.hidden)
        }
        .background(IOSTheme.paper.ignoresSafeArea())
        .onAppear { state.ensureWorkSession() }
    }

    private var originStrip: some View {
        HStack(spacing: 6) {
            StatusPill(text: state.activeSession?.origin.displayName ?? "Manual input")
            StatusPill(text: "Draft preserved", tone: .good)
            Spacer()
        }
    }

    private var sourceComposer: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Text("Source")
                    .font(.system(size: 10, weight: .heavy, design: .rounded))
                    .foregroundStyle(IOSTheme.muted)
                    .textCase(.uppercase)
                Spacer()
                MiniIconButton(systemName: "doc.on.doc") {
                    state.copySourceDraft()
                }
                .accessibilityLabel("Copy source")
                .accessibilityIdentifier("UnderstandCopySource")
            }

            TextEditor(text: Binding(
                get: { state.activeSession?.sourceDraft ?? "" },
                set: { state.updateSourceDraft($0) }
            ))
            .accessibilityIdentifier("UnderstandSourceEditor")
            .font(.system(size: 12, weight: .semibold, design: .rounded))
            .frame(minHeight: 72)
            .scrollContentBackground(.hidden)
            .padding(8)
            .background(IOSTheme.surface2)
            .clipShape(RoundedRectangle(cornerRadius: IOSTheme.cardRadius, style: .continuous))

            FlowLayout(spacing: 6) {
                StatusPill(text: "Auto -> 中文")
                Button("Google + OpenAI") {
                    state.selectedTab = .engines
                }
                .buttonStyle(.compactBlue)
                Button("Clear") {
                    state.updateSourceDraft("")
                }
                .buttonStyle(.compactMuted)
                Button("Clean lines") {
                    state.applyOCRCleanup(.joinLines)
                }
                .buttonStyle(.compactMuted)
            }

            Button {
                Task { await state.understandActiveSession() }
            } label: {
                HStack {
                    Spacer()
                    if state.isProcessing {
                        ProgressView()
                            .controlSize(.small)
                    }
                    Text(state.isProcessing ? "Translating current draft" : "Translate current draft")
                    Spacer()
                }
            }
            .buttonStyle(.compactGreen)
            .accessibilityLabel("Understand")
        }
        .padding(9)
        .parrotCard()
    }

    @ViewBuilder
    private var resultStack: some View {
        if state.isProcessing && state.activeSession?.understand == nil {
            HStack(spacing: 8) {
                ProgressView()
                    .controlSize(.small)
                Text("Explaining context...")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(IOSTheme.muted)
                Spacer()
            }
            .padding(9)
            .parrotCard()
        }

        if let result = state.activeSession?.understand {
            VStack(spacing: 7) {
                if let translation = visibleTranslation(result) {
                    resultCard(
                        title: "Translation",
                        text: translation,
                        primary: true,
                        copyAction: { state.copy(translation) },
                        accessibilityID: "UnderstandTranslation"
                    )
                }

                resultCard(
                    title: "Meaning",
                    text: result.meaningSummary,
                    primary: false,
                    copyAction: {
                        state.copy(result.meaningSummary)
                    },
                    accessibilityID: "UnderstandMeaning"
                )

                if !result.phraseExplanations.isEmpty {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 7) {
                        ForEach(result.phraseExplanations.prefix(4)) { phrase in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(phrase.phrase)
                                    .font(.system(size: 10.5, weight: .heavy, design: .rounded))
                                    .foregroundStyle(IOSTheme.ink)
                                Text(phrase.explanation)
                                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                                    .foregroundStyle(IOSTheme.muted)
                                    .lineLimit(3)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(8)
                            .parrotCard()
                        }
                    }
                }
            }
        }
    }

    private func resultCard(
        title: String,
        text: String,
        primary: Bool,
        copyAction: @escaping () -> Void,
        accessibilityID: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                HStack(spacing: 6) {
                    Circle()
                        .fill(IOSTheme.green)
                        .frame(width: 7, height: 7)
                    Text(title)
                        .font(.system(size: 10, weight: .heavy, design: .rounded))
                        .foregroundStyle(IOSTheme.greenDeep)
                        .textCase(.uppercase)
                }
                Spacer()
                MiniIconButton(systemName: "doc.on.doc", action: copyAction)
                    .accessibilityIdentifier(title == "Translation" ? "UnderstandCopyTranslation" : "UnderstandCopyMeaning")
            }

            Text(text)
                .font(.system(size: primary ? 13 : 11, weight: primary ? .bold : .semibold, design: .rounded))
                .foregroundStyle(IOSTheme.ink)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier(accessibilityID)
        }
        .padding(9)
        .background(primary ? IOSTheme.meaningTint : IOSTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: IOSTheme.cardRadius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: IOSTheme.cardRadius, style: .continuous).stroke(IOSTheme.line))
    }

    private var replyDock: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Text("Reply intent")
                    .font(.system(size: 10, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white.opacity(0.64))
                    .textCase(.uppercase)
                Spacer()
                Button("Generate replies") {
                    Task { await state.generateReplies() }
                }
                .buttonStyle(.compactGreen)
            }

            TextEditor(text: Binding(
                get: { state.activeSession?.userIntentDraft ?? "" },
                set: { state.updateIntentDraft($0) }
            ))
            .accessibilityIdentifier("ExpressIntentEditor")
            .font(.system(size: 12, weight: .semibold, design: .rounded))
            .frame(minHeight: 54)
            .scrollContentBackground(.hidden)
            .padding(8)
            .foregroundStyle(.white)
            .background(Color.white.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: IOSTheme.cardRadius, style: .continuous))

            FlowLayout(spacing: 6) {
                ForEach([TonePreset.natural, .friendly, .firm, .xShort]) { tone in
                    Button(tone.displayName) {
                        state.selectTone(tone)
                    }
                    .font(.system(size: 9.5, weight: .heavy, design: .rounded))
                    .foregroundStyle(state.activeSession?.selectedTone == tone ? Color(red: 0.02, green: 0.18, blue: 0.09) : .white.opacity(0.78))
                    .padding(.horizontal, 8)
                    .frame(minHeight: 24)
                    .background(state.activeSession?.selectedTone == tone ? IOSTheme.green : Color.white.opacity(0.10))
                    .clipShape(Capsule())
                }
            }

            ForEach(state.activeSession?.express?.candidates ?? []) { candidate in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(candidate.title)
                            .font(.system(size: 10, weight: .heavy, design: .rounded))
                            .foregroundStyle(IOSTheme.green)
                        Spacer()
                        Button("Copy") { state.copy(candidate.text) }
                            .buttonStyle(.compactBlue)
                    }
                    Text(candidate.text)
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(8)
                .background(Color.white.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: IOSTheme.cardRadius, style: .continuous))
            }
        }
        .padding(9)
        .background(Color(red: 0.094, green: 0.125, blue: 0.094))
        .clipShape(RoundedRectangle(cornerRadius: IOSTheme.cardRadius, style: .continuous))
        .shadow(color: .black.opacity(0.16), radius: 16, y: 8)
    }

    private func visibleTranslation(_ result: UnderstandResult) -> String? {
        let translation = result.fullTranslation?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !translation.isEmpty else { return nil }
        let source = state.activeSession?.sourceDraft.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return translation == source ? nil : translation
    }

    private func notice(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .bold, design: .rounded))
            .foregroundStyle(Color(red: 0.48, green: 0.30, blue: 0.01))
            .padding(9)
            .background(IOSTheme.amber.opacity(0.15))
            .clipShape(RoundedRectangle(cornerRadius: IOSTheme.cardRadius, style: .continuous))
    }
}

private extension SourceOrigin {
    var displayName: String {
        switch self {
        case .manualInput: return "Manual input"
        case .clipboard: return "Clipboard"
        case .shareExtension: return "Share"
        case .screenshot: return "Screenshot OCR"
        case .latestScreenshot: return "Latest screenshot"
        case .photoLibrary: return "Photo Library"
        case .history: return "History"
        case .keyboard: return "Keyboard"
        case .shortcut: return "Shortcut"
        }
    }
}
