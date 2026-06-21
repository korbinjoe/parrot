import ParrotSocial
import SwiftUI

struct ExpressWorkspaceView: View {
    @EnvironmentObject private var state: IOSAppState

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    composer
                    if state.isProcessing {
                        ProgressView("Generating native replies...")
                            .padding(14)
                            .parrotCard()
                    }
                    candidateList
                }
                .padding(16)
            }
            .background(IOSTheme.paper.ignoresSafeArea())
            .navigationTitle("Express")
        }
    }

    private var composer: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let context = state.activeSession?.contextText, !context.isEmpty {
                HStack(alignment: .top, spacing: 10) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(IOSTheme.cyan)
                        .frame(width: 5)
                    Text(context)
                        .font(.caption)
                        .foregroundStyle(IOSTheme.muted)
                        .lineLimit(4)
                }
                .padding(10)
                .background(IOSTheme.subtleFill)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }

            TextEditor(text: Binding(
                get: { state.activeSession?.userIntentDraft ?? "" },
                set: { state.updateIntentDraft($0) }
            ))
            .accessibilityIdentifier("ExpressIntentEditor")
            .frame(minHeight: 120)
            .scrollContentBackground(.hidden)
            .padding(8)
            .background(IOSTheme.surface2)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    ForEach([TonePreset.natural, .friendly, .firm, .redditStyle, .xShort]) { tone in
                        Button(tone.displayName) {
                            state.selectTone(tone)
                        }
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background((state.activeSession?.selectedTone == tone ? IOSTheme.green.opacity(0.22) : IOSTheme.subtleFill))
                        .clipShape(Capsule())
                    }
                }
            }

            Button {
                Task { await state.generateReplies() }
            } label: {
                Label("Generate replies", systemImage: "sparkles")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(IOSTheme.green)
        }
        .padding(14)
        .parrotCard()
    }

    private var candidateList: some View {
        VStack(spacing: 10) {
            ForEach(state.activeSession?.express?.candidates ?? []) { candidate in
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text(candidate.title)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(IOSTheme.coral)
                        Spacer()
                        Button("Copy") { state.copy(candidate.text) }
                            .font(.caption.weight(.semibold))
                            .buttonStyle(.bordered)
                    }
                    Text(candidate.text)
                        .font(.body)
                        .foregroundStyle(IOSTheme.ink)
                    FlowLayout(spacing: 7) {
                        ForEach(RefinementAction.allCases) { action in
                            Button(action.displayName) {
                                Task { await state.refine(candidate, action: action) }
                            }
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 9)
                            .padding(.vertical, 6)
                            .background(IOSTheme.coral.opacity(0.16))
                            .clipShape(Capsule())
                        }
                    }
                }
                .padding(14)
                .parrotCard()
            }
        }
    }
}
