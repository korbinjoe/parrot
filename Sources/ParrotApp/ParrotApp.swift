import AppKit

// Parrot menu-bar agent entry point.
// Runs as an accessory app (no Dock icon, lives in the menu bar).
@main
enum ParrotMain {
    @MainActor static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
    }
}
