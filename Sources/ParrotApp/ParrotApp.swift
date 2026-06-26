import AppKit

// Parrot keeps a menu-bar status item, but runs as a regular macOS app so
// Dock and Cmd-Tab expose the active translation workspace predictably.
@main
enum ParrotMain {
    @MainActor static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.regular)
        app.run()
    }
}
