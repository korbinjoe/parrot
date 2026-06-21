import ParrotSocial
import SwiftUI

struct ParrotiOSRootView: View {
    @EnvironmentObject private var state: IOSAppState

    var body: some View {
        TabView(selection: $state.selectedTab) {
            TodayView()
                .tabItem { Label("Today", systemImage: "sparkles") }
                .tag(IOSAppState.AppTab.today)

            UnderstandWorkspaceView()
                .tabItem { Label("Understand", systemImage: "text.bubble") }
                .tag(IOSAppState.AppTab.understand)

            ExpressWorkspaceView()
                .tabItem { Label("Express", systemImage: "square.and.pencil") }
                .tag(IOSAppState.AppTab.express)

            HistoryView()
                .tabItem { Label("History", systemImage: "clock") }
                .tag(IOSAppState.AppTab.history)

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
                .tag(IOSAppState.AppTab.settings)
        }
        .tint(IOSTheme.green)
        .overlay(alignment: .bottom) {
            if let feedback = state.feedback {
                Text(feedback)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color(red: 0.04, green: 0.49, blue: 0.26))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(IOSTheme.surface)
                    .clipShape(Capsule())
                    .shadow(color: .black.opacity(0.12), radius: 14, y: 7)
                    .padding(.bottom, 62)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .fullScreenCover(isPresented: $state.isQuickLensPresented) {
            QuickLensView()
                .environmentObject(state)
        }
    }
}
