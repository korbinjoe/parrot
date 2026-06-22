import SwiftUI

struct TodayView: View {
    @EnvironmentObject private var state: IOSAppState

    var body: some View {
        VStack(spacing: 0) {
            AppHeader(title: "Parrot") {
                Button("Settings") {
                    state.selectedTab = .engines
                }
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(IOSTheme.cyan)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    Text("New session")
                        .font(.system(size: 18, weight: .heavy, design: .rounded))
                        .foregroundStyle(IOSTheme.ink)

                    HStack {
                        StatusPill(text: "Ready", tone: .good)
                        Spacer()
                        StatusPill(text: "Editable draft")
                    }
                    .padding(.bottom, 6)

                    VStack(spacing: 8) {
                        Button {
                            state.openManualSession()
                        } label: {
                            HStack(spacing: 8) {
                                IconTile(systemName: "pencil.line")
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Manual input")
                                        .font(.system(size: 13, weight: .heavy, design: .rounded))
                                        .foregroundStyle(IOSTheme.ink)
                                    Text("Source editor")
                                        .font(.system(size: 10, weight: .heavy, design: .rounded))
                                        .foregroundStyle(IOSTheme.greenDeep)
                                }
                                Spacer()
                                Image(systemName: "arrow.right")
                                    .font(.system(size: 16, weight: .heavy))
                                    .foregroundStyle(Color(red: 0.02, green: 0.25, blue: 0.13))
                            }
                            .padding(8)
                            .frame(minHeight: 52)
                            .background(
                                LinearGradient(
                                    colors: [IOSTheme.green.opacity(0.24), IOSTheme.cyan.opacity(0.10)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .clipShape(RoundedRectangle(cornerRadius: IOSTheme.cardRadius, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: IOSTheme.cardRadius, style: .continuous)
                                    .stroke(IOSTheme.green.opacity(0.24), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)

                        HStack(spacing: 8) {
                            quickTile(
                                title: "Screenshot OCR",
                                subtitle: "Quick Lens",
                                icon: "viewfinder"
                            ) {
                                Task { await state.openQuickLensFromLatestScreenshot() }
                            }
                            .accessibilityIdentifier("QuickLensButton")

                            quickTile(
                                title: "Clipboard",
                                subtitle: state.clipboardSuggestionText == nil ? "Tap to check" : "Text available",
                                icon: "doc.on.doc"
                            ) {
                                state.refreshClipboardSuggestion()
                                if state.clipboardSuggestionText != nil {
                                    state.openClipboardSuggestion()
                                }
                            }
                        }
                    }

                    SectionTitle(left: "Recent")
                        .padding(.top, 6)

                    recentRows
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 78)
            }
            .scrollIndicators(.hidden)
        }
        .background(IOSTheme.paper.ignoresSafeArea())
    }

    private func quickTile(
        title: String,
        subtitle: String,
        icon: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                IconTile(systemName: icon)
                Spacer(minLength: 0)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 11, weight: .heavy, design: .rounded))
                        .foregroundStyle(IOSTheme.ink)
                    Text(subtitle)
                        .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                        .foregroundStyle(IOSTheme.muted)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 84, alignment: .leading)
            .padding(8)
            .parrotCard()
        }
        .buttonStyle(.plain)
    }

    private var recentRows: some View {
        VStack(spacing: 7) {
            if state.recentSessions.isEmpty {
                recentButton(
                    title: "The onboarding asks too much too early.",
                    subtitle: "X · translated 8 min ago · editable"
                ) {
                    state.openManualSession()
                }
                recentButton(
                    title: "History seed: roadmap sounds good...",
                    subtitle: "Search all saved sessions"
                ) {
                    state.selectedTab = .history
                }
            } else {
                ForEach(state.recentSessions.prefix(4)) { session in
                    recentButton(
                        title: session.sourceDraft,
                        subtitle: "\(session.platform.displayName) · \(session.mode.rawValue) · editable"
                    ) {
                        state.reopen(session)
                    }
                }
            }
        }
    }

    private func recentButton(title: String, subtitle: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                    .foregroundStyle(IOSTheme.ink)
                    .lineLimit(1)
                Text(subtitle)
                    .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(IOSTheme.muted)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 8)
            .padding(.vertical, 7)
            .parrotCard()
        }
        .buttonStyle(.plain)
    }
}
