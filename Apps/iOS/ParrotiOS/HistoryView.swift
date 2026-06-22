import ParrotSocial
import SwiftUI

struct HistoryView: View {
    @EnvironmentObject private var state: IOSAppState
    @State private var query = "onboarding"

    private var filteredSessions: [SocialTextSession] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let sessions = state.recentSessions
        guard !q.isEmpty else { return sessions }
        return sessions.filter { session in
            session.sourceDraft.lowercased().contains(q)
                || session.userIntentDraft.lowercased().contains(q)
                || session.platform.displayName.lowercased().contains(q)
                || (session.understand?.meaningSummary.lowercased().contains(q) ?? false)
                || (session.express?.candidates.contains { $0.text.lowercased().contains(q) } ?? false)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            AppHeader(leadingTitle: "Back", leadingAction: {
                state.selectedTab = .today
            }, title: "History") {
                MiniIconButton(systemName: "star") {}
                    .accessibilityLabel("Favorites")
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    TextField("Search history", text: $query)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .padding(.horizontal, 10)
                        .frame(height: 34)
                        .background(IOSTheme.surface2)
                        .clipShape(RoundedRectangle(cornerRadius: IOSTheme.cardRadius, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: IOSTheme.cardRadius, style: .continuous).stroke(IOSTheme.line))
                        .accessibilityIdentifier("HistorySearch")

                    if filteredRows.isEmpty {
                        emptyState
                    } else {
                        ForEach(filteredRows) { row in
                            historyRow(row)
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 78)
            }
            .scrollIndicators(.hidden)
        }
        .background(IOSTheme.paper.ignoresSafeArea())
    }

    private var filteredRows: [HistoryRowModel] {
        if state.recentSessions.isEmpty {
            return [
                HistoryRowModel(
                    title: "The onboarding asks too much too early.",
                    subtitle: "Quick Lens · Translation + meaning · reopen editable",
                    action: { state.openManualSession() }
                ),
                HistoryRowModel(
                    title: "History seed: the roadmap sounds good...",
                    subtitle: "X · Reply candidates saved · reopen editable",
                    action: { state.openManualSession() }
                ),
                HistoryRowModel(
                    title: "我觉得这个评价挺公平...",
                    subtitle: "Manual input · Express · continue drafting",
                    action: { state.openManualSession() }
                )
            ].filter {
                query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    || $0.title.lowercased().contains(query.lowercased())
                    || $0.subtitle.lowercased().contains(query.lowercased())
            }
        }

        return filteredSessions.map { session in
            HistoryRowModel(
                title: session.sourceDraft,
                subtitle: "\(session.platform.displayName) · \(session.mode.rawValue) · reopen editable",
                action: { state.reopen(session) }
            )
        }
    }

    private func historyRow(_ row: HistoryRowModel) -> some View {
        Button(action: row.action) {
            VStack(alignment: .leading, spacing: 4) {
                Text(row.title)
                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                    .foregroundStyle(IOSTheme.ink)
                    .lineLimit(1)
                Text(row.subtitle)
                    .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(IOSTheme.muted)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
            .parrotCard()
        }
        .buttonStyle(.plain)
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("No matching sessions")
                .font(.system(size: 12, weight: .heavy, design: .rounded))
            Text("Clear search or reopen a recent translation from Today.")
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(IOSTheme.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .parrotCard()
    }
}

private struct HistoryRowModel: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let action: () -> Void
}
