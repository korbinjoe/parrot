import SwiftUI

struct ParrotiOSRootView: View {
    @EnvironmentObject private var state: IOSAppState

    var body: some View {
        ZStack(alignment: .bottom) {
            IOSTheme.paper.ignoresSafeArea()

            Group {
                switch state.selectedTab {
                case .today:
                    TodayView()
                case .work:
                    UnderstandWorkspaceView()
                case .lens:
                    QuickLensView()
                case .history:
                    HistoryView()
                case .engines:
                    SettingsView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .transition(.asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal: .move(edge: .leading).combined(with: .opacity)
            ))

            bottomTabs

            if let feedback = state.feedback {
                Text(feedback)
                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color(red: 0.04, green: 0.49, blue: 0.26))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                    .shadow(color: .black.opacity(0.14), radius: 14, y: 7)
                    .padding(.bottom, 70)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.snappy(duration: 0.28), value: state.selectedTab)
        .animation(.snappy(duration: 0.24), value: state.feedback)
    }

    private var bottomTabs: some View {
        HStack(spacing: 4) {
            ForEach([IOSAppState.AppTab.today, .work, .lens, .history, .engines], id: \.self) { tab in
                Button {
                    if tab == .lens, state.quickLensStatus == .idle {
                        Task { await state.openQuickLensFromLatestScreenshot() }
                    } else {
                        state.selectedTab = tab
                    }
                } label: {
                    VStack(spacing: 2) {
                        Image(systemName: tab.systemImage)
                            .font(.system(size: 15, weight: .bold))
                        Text(tab.title)
                            .font(.system(size: 9, weight: .heavy, design: .rounded))
                    }
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .foregroundStyle(state.selectedTab == tab ? IOSTheme.greenDeep : IOSTheme.soft)
                    .background {
                        if state.selectedTab == tab {
                            RoundedRectangle(cornerRadius: IOSTheme.controlRadius, style: .continuous)
                                .fill(IOSTheme.green.opacity(state.selectedTab == .engines ? 0.08 : 0.15))
                        }
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tab.title)
                .accessibilityIdentifier("Tab\(tab.title)")
            }
        }
        .padding(.horizontal, 8)
        .padding(.top, 4)
        .padding(.bottom, 8)
        .background(.regularMaterial)
        .opacity(state.selectedTab == .engines ? 0.84 : 1)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(IOSTheme.line)
                .frame(height: 1)
        }
    }
}
