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
                    modeSelector
                    sourceComposer
                    if let error = state.errorNotice {
                        notice(error)
                    }
                    contentStack
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 78)
            }
            .scrollIndicators(.hidden)
        }
        .background(IOSTheme.paper.ignoresSafeArea())
        .onAppear { state.ensureWorkSession() }
    }

    private var activeMode: SocialMode {
        state.activeSession?.mode ?? .understand
    }

    private var originStrip: some View {
        HStack(spacing: 6) {
            StatusPill(text: state.activeSession?.origin.displayName ?? "Manual input")
            StatusPill(text: activeMode.displayName, tone: activeMode == .polish ? .good : .blue)
            Spacer()
        }
    }

    private var modeSelector: some View {
        HStack(spacing: 6) {
            ForEach([SocialMode.understand, .express, .polish], id: \.self) { mode in
                Button {
                    state.selectWorkspaceMode(mode)
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: modeIcon(mode))
                            .font(.system(size: 10, weight: .heavy))
                        Text(mode.displayName)
                            .font(.system(size: 10, weight: .heavy, design: .rounded))
                    }
                    .foregroundStyle(activeMode == mode ? IOSTheme.greenDeep : IOSTheme.muted)
                    .frame(maxWidth: .infinity, minHeight: 30)
                    .background(activeMode == mode ? IOSTheme.green.opacity(0.16) : IOSTheme.subtleFill)
                    .clipShape(RoundedRectangle(cornerRadius: IOSTheme.controlRadius, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: IOSTheme.controlRadius, style: .continuous)
                            .stroke(activeMode == mode ? IOSTheme.green.opacity(0.28) : IOSTheme.line)
                    )
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("WorkspaceMode\(mode.displayName)")
            }
        }
    }

    private var sourceComposer: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Text(sourceTitle)
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
                StatusPill(text: sourceRouteLabel)
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

            if activeMode == .polish {
                Button {
                    Task { await state.polishActiveDraft() }
                } label: {
                    HStack {
                        Spacer()
                        if state.isProcessing {
                            ProgressView()
                                .controlSize(.small)
                        }
                        Text(state.isProcessing ? "Polishing current draft" : "Native Polish")
                        Spacer()
                    }
                }
                .buttonStyle(.compactGreen)
                .accessibilityLabel("Native Polish")
                .accessibilityIdentifier("NativePolishRun")
            } else if activeMode == .understand || activeMode == .ocr {
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
        }
        .padding(9)
        .parrotCard()
    }

    private var sourceTitle: String {
        activeMode == .polish ? "Draft" : "Source"
    }

    private var sourceRouteLabel: String {
        activeMode == .polish ? "Native -> English" : "Auto -> 中文"
    }

    @ViewBuilder
    private var contentStack: some View {
        switch activeMode {
        case .express:
            replyDock
        case .polish:
            polishStack
        case .understand, .ocr:
            resultStack
        }
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

    @ViewBuilder
    private var polishStack: some View {
        let candidates = state.activeSession?.express?.candidates ?? []

        if state.isProcessing && candidates.isEmpty {
            HStack(spacing: 8) {
                ProgressView()
                    .controlSize(.small)
                Text("Writing native version...")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(IOSTheme.muted)
                Spacer()
            }
            .padding(9)
            .parrotCard()
        }

        if let primary = candidates.first {
            polishCandidateCard(primary, primary: true)

            if candidates.count > 1 {
                SectionTitle(left: "Variants")
                    .padding(.top, 2)
                ForEach(Array(candidates.dropFirst())) { candidate in
                    polishCandidateCard(candidate, primary: false)
                }
            }

            polishNotes(for: primary)
        } else if !state.isProcessing {
            VStack(alignment: .leading, spacing: 6) {
                Text("Native result")
                    .font(.system(size: 10, weight: .heavy, design: .rounded))
                    .foregroundStyle(IOSTheme.muted)
                    .textCase(.uppercase)
                Text("Run Native Polish to create a copy-ready version from the current draft.")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(IOSTheme.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(9)
            .parrotCard()
        }
    }

    private func polishCandidateCard(_ candidate: ReplyCandidate, primary: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 7) {
                Circle()
                    .fill(primary ? IOSTheme.green : IOSTheme.coral)
                    .frame(width: 7, height: 7)
                Text(candidate.title)
                    .font(.system(size: 10, weight: .heavy, design: .rounded))
                    .foregroundStyle(primary ? IOSTheme.greenDeep : IOSTheme.coral)
                    .textCase(.uppercase)
                Spacer()
                MiniIconButton(systemName: "doc.on.doc") {
                    state.copy(candidate.text)
                }
                .accessibilityLabel("Copy")
                .accessibilityIdentifier(primary ? "NativePolishCopyPrimary" : "NativePolishCopyVariant")
                Button("Replace draft") {
                    state.replaceSourceDraft(with: candidate)
                }
                .buttonStyle(.compactGreen)
                .accessibilityIdentifier(primary ? "NativePolishReplaceDraftPrimary" : "NativePolishReplaceDraftVariant")
            }

            Text(candidate.text)
                .font(.system(size: primary ? 13 : 11, weight: primary ? .bold : .semibold, design: .rounded))
                .foregroundStyle(IOSTheme.ink)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier(primary ? "NativePolishPrimary" : "NativePolishVariant")

            FlowLayout(spacing: 6) {
                ForEach(RefinementAction.allCases) { action in
                    Button(action.displayName) {
                        Task { await state.refine(candidate, action: action) }
                    }
                    .font(.system(size: 9.5, weight: .heavy, design: .rounded))
                    .foregroundStyle(IOSTheme.blueDeep)
                    .padding(.horizontal, 8)
                    .frame(minHeight: 24)
                    .background(IOSTheme.cyan.opacity(0.10))
                    .clipShape(Capsule())
                    .accessibilityIdentifier("NativePolishRefine\(primary ? "Primary" : "Variant")\(action.rawValue)")
                }
            }
        }
        .padding(9)
        .background(primary ? IOSTheme.meaningTint : IOSTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: IOSTheme.cardRadius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: IOSTheme.cardRadius, style: .continuous).stroke(IOSTheme.line))
    }

    private func polishNotes(for candidate: ReplyCandidate) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            SectionTitle(left: "Compare")
            ForEach(polishNoteTexts(for: candidate), id: \.self) { note in
                HStack(alignment: .top, spacing: 7) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(IOSTheme.greenDeep)
                    Text(note)
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundStyle(IOSTheme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                }
            }
        }
        .padding(9)
        .parrotCard()
    }

    private func polishNoteTexts(for candidate: ReplyCandidate) -> [String] {
        [
            "Kept the original stance and claims.",
            "Smoothed grammar, word order, and rhythm.",
            "Matched the current tone: \(candidate.tone.displayName)."
        ]
    }

    private func modeIcon(_ mode: SocialMode) -> String {
        switch mode {
        case .understand: return "text.magnifyingglass"
        case .express: return "bubble.left.and.text.bubble.right"
        case .polish: return "sparkles"
        case .ocr: return "viewfinder"
        }
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
