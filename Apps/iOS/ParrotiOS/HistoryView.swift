import ParrotSocial
import SwiftUI

struct HistoryView: View {
    @EnvironmentObject private var state: IOSAppState
    @State private var query = ""

    private var filteredSessions: [SocialTextSession] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return state.recentSessions }
        return state.recentSessions.filter { session in
            session.sourceDraft.lowercased().contains(q)
                || session.userIntentDraft.lowercased().contains(q)
                || session.platform.displayName.lowercased().contains(q)
                || (session.understand?.meaningSummary.lowercased().contains(q) ?? false)
                || (session.express?.candidates.contains { $0.text.lowercased().contains(q) } ?? false)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(filteredSessions) { session in
                    Button {
                        state.reopen(session)
                    } label: {
                        VStack(alignment: .leading, spacing: 5) {
                            Text(session.sourceDraft)
                                .lineLimit(2)
                                .foregroundStyle(IOSTheme.ink)
                            Text("\(session.platform.displayName) · \(session.mode.rawValue)")
                                .font(.caption)
                                .foregroundStyle(IOSTheme.soft)
                        }
                    }
                    .swipeActions {
                        Button(role: .destructive) {
                            Task { await state.delete(session) }
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                        Button(session.isFavorite ? "Unfavorite" : "Favorite") {
                            Task { await state.setFavorite(session, !session.isFavorite) }
                        }
                        .tint(.yellow)
                    }
                }
            }
            .searchable(text: $query, prompt: "Search history")
            .navigationTitle("History")
        }
    }
}
