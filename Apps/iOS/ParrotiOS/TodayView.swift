import SwiftUI

struct TodayView: View {
    @EnvironmentObject private var state: IOSAppState

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    if let clipboard = state.clipboardSuggestionText {
                        clipboardCard(clipboard)
                    } else {
                        Button {
                            state.refreshClipboardSuggestion()
                        } label: {
                            Label("Check clipboard", systemImage: "doc.on.clipboard")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                    }
                    Button {
                        Task { await state.openQuickLensFromLatestScreenshot() }
                    } label: {
                        Label("Quick Lens", systemImage: "viewfinder")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(IOSTheme.cyan)
                    .accessibilityIdentifier("QuickLensButton")

                    Button {
                        state.openDemoSession()
                    } label: {
                        Label("Open demo social post", systemImage: "play.circle.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(IOSTheme.green)

                    recentList
                }
                .padding(18)
            }
            .background(IOSTheme.paper.ignoresSafeArea())
            .navigationTitle("Parrot")
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Read confidently. Reply naturally.")
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(IOSTheme.ink)
            Text("Explain social posts by meaning and tone, then turn rough thoughts into native English replies.")
                .font(.callout)
                .foregroundStyle(IOSTheme.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func clipboardCard(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Copied text", systemImage: "doc.on.clipboard")
                .font(.footnote.weight(.bold))
                .foregroundStyle(IOSTheme.muted)
            Text(text)
                .lineLimit(4)
                .font(.body)
            Button("Explain copied text") {
                state.openClipboardSuggestion()
            }
            .buttonStyle(.borderedProminent)
            .tint(IOSTheme.green)
        }
        .padding(14)
        .parrotCard()
    }

    private var recentList: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Recent")
                .font(.headline)
            ForEach(state.recentSessions.prefix(5)) { session in
                Button {
                    state.reopen(session)
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(session.sourceDraft)
                            .lineLimit(2)
                            .foregroundStyle(IOSTheme.ink)
                        Text(session.platform.displayName + " · " + session.mode.rawValue)
                            .font(.caption)
                            .foregroundStyle(IOSTheme.soft)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(IOSTheme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
            }
        }
    }
}
