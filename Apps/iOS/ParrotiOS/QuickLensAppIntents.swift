import AppIntents
import Foundation

struct TranslateLatestScreenshotIntent: AppIntent {
    static let title: LocalizedStringResource = "Translate Latest Screenshot"
    static let description = IntentDescription("Open Parrot Quick Lens and translate the screenshot you just took.")
    static let openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult {
        QuickLensLaunchRequest.markRequested()
        return .result()
    }
}

struct ParrotQuickLensShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: TranslateLatestScreenshotIntent(),
            phrases: [
                "Translate latest screenshot with \(.applicationName)",
                "Open Quick Lens in \(.applicationName)"
            ],
            shortTitle: "Quick Lens",
            systemImageName: "viewfinder"
        )
    }
}
