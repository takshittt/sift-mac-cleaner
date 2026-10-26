import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Needed when launched as a bare SwiftPM executable (`swift run`), harmless in the bundle.
        NSApp.setActivationPolicy(.regular)
        // The light purple design is the only theme; ignore the system dark mode.
        NSApp.appearance = NSAppearance(named: .aqua)
        NSApp.activate()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}
