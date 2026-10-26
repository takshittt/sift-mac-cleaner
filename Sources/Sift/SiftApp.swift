import SwiftUI
import SiftCore
import SiftAppModel

@main
struct SiftApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    /// `--fake` runs the UI on sample data that never touches the disk.
    /// `--smoke-test` does too, with throwaway settings (see SmokeTest).
    @ViewState private var state = AppState(
        engine: CommandLine.arguments.contains("--fake") || SmokeTest.isEnabled ? .fake() : .live(),
        settings: SmokeTest.isEnabled ? SiftApp.throwawaySettings() : SettingsStore())

    private static func throwawaySettings() -> SettingsStore {
        let suite = "com.takshitsaini.sift.smoke-test"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return SettingsStore(defaults: defaults)
    }

    var body: some Scene {
        WindowGroup("Sift") {
            ContentView()
                .environment(state)
                .frame(minWidth: 900, minHeight: 600)
        }
        .windowStyle(.hiddenTitleBar)
        Settings {
            SettingsView()
                .environment(state)
        }
    }
}
