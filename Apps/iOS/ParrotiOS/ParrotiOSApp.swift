import SwiftUI

@main
struct ParrotiOSApp: App {
    @StateObject private var state = IOSAppState()

    var body: some Scene {
        WindowGroup {
            ParrotiOSRootView()
                .environmentObject(state)
                .task { await state.bootstrap() }
                .onOpenURL { url in
                    Task { await state.handle(url: url) }
                }
        }
    }
}
