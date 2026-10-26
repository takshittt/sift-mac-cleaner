import Foundation
import Testing
@testable import SiftCore
@testable import SiftAppModel

@Suite struct BundleIDTests {
    @Test(arguments: [
        ("com.spotify.client", "com.spotify.client"),
        ("com.Spotify.Client.plist", "com.spotify.client"),
        ("com.docker", "com.docker"),
        ("UBF8T346G9.com.microsoft.teams", "com.microsoft.teams"),
        ("L82V4Y2P3C.group.com.wireguard.macos", "com.wireguard.macos"),
        ("group.com.docker", "com.docker"),
        ("systemgroup.com.apple.icloud.searchpartyd.sharedsettings.plist", "com.apple.icloud.searchpartyd.sharedsettings"),
        ("com.exafunction.windsurf.binarycookies", "com.exafunction.windsurf"),
    ])
    func parsesBundleIDs(_ name: String, _ expected: String) {
        #expect(BundleIDs.from(name: name) == expected)
    }

    @Test(arguments: ["Google", "Slack", "UBF8T346G9.Office", "foo.bar", "My App.plist", ".GlobalPreferences.plist", "com..x"])
    func rejectsNamesThatAreNotClearlyBundleIDs(_ name: String) {
        #expect(BundleIDs.from(name: name) == nil)
    }

    @Test func orphanMatching() {
        let installed: Set<String> = ["com.microsoft.word", "com.google.chrome"]
        #expect(!BundleIDs.isOrphan("com.microsoft.word", installed: installed, perApp: true))
        #expect(!BundleIDs.isOrphan("com.google.chrome.helper", installed: installed, perApp: true))   // helper of installed app
        #expect(!BundleIDs.isOrphan("com.google", installed: installed, perApp: true))                // parent of installed app
        #expect(BundleIDs.isOrphan("com.microsoft.excel", installed: installed, perApp: true))         // container: exact app only
        #expect(!BundleIDs.isOrphan("com.microsoft.oneauth", installed: installed, perApp: false))    // shared: same vendor installed
        #expect(BundleIDs.isOrphan("com.vmware.fusion", installed: installed, perApp: false))
        #expect(!BundleIDs.isOrphan("com.vmware.fusion", installed: [], perApp: true))                // no app list: assume nothing
    }

    @Test func systemAndSharedVendorsAreNeverOrphans() {
        #expect(BundleIDs.isSystemOrShared("com.apple.finder"))
        #expect(BundleIDs.isSystemOrShared("org.cups.printingprefs"))
        #expect(BundleIDs.isSystemOrShared("org.sparkle-project.sparkle.autoupdate"))
        #expect(!BundleIDs.isSystemOrShared("com.vmware.fusion"))
    }

    @Test func runningMatchesHelpers() {
        let apps = AppSnapshot(runningIDs: ["com.microsoft.VSCode"])
        #expect(apps.isRunning("com.microsoft.vscode.shipit"))
        #expect(apps.isRunning("COM.MICROSOFT.VSCODE"))
        #expect(!apps.isRunning("com.microsoft.vscodeinsiders"))
    }
}

@Suite struct AppIndexTests {
    let home: FakeHome
    init() throws { home = try FakeHome() }

    private func app(_ rel: String, id: String?) throws {
        var info: [String: Any] = ["CFBundleName": "x"]
        if let id { info["CFBundleIdentifier"] = id }
        let data = try PropertyListSerialization.data(fromPropertyList: info, format: .xml, options: 0)
        try home.dir(rel + "/Contents")
        try data.write(to: home.path(rel + "/Contents/Info.plist"))
    }

    @Test func readsBundlesDirectlyAndOneFolderDeep() throws {
        try app("Applications/Spotify.app", id: "com.spotify.client")
        try app("Applications/Setapp/CleanShot X.app", id: "pl.maketheweb.cleanshotx")
        try app("Applications/Broken.app", id: nil)
        try app("Applications/A/B/TooDeep.app", id: "com.too.deep")

        let bundles = InstalledApps.bundles(in: [home.path("Applications")])
        let snapshot = InstalledApps.snapshot(from: bundles, running: ["COM.Spotify.Client"])
        #expect(snapshot.installedIDs == ["com.spotify.client", "pl.maketheweb.cleanshotx"])
        #expect(snapshot.installedNames == ["spotify", "cleanshot x", "broken"])
        #expect(snapshot.runningIDs == ["com.spotify.client"])
    }

    @Test func detectsProfilesFromAppsAndEvidence() {
        let none = ProfileDetector.detect(apps: .empty, home: home.url, exists: { _ in false })
        #expect(none == [.general])

        let xcode = ProfileDetector.detect(apps: AppSnapshot(installedIDs: ["com.apple.dt.Xcode"]),
                                           home: home.url, exists: { _ in false })
        #expect(xcode == [.general, .developer])

        let homePath = home.url.path(percentEncoded: false)
        let ollama = ProfileDetector.detect(apps: .empty, home: home.url,
                                            exists: { $0.hasPrefix(homePath) && $0.hasSuffix("/.ollama") })
        #expect(ollama == [.general, .localAI])

        let brew = ProfileDetector.detect(apps: .empty, home: home.url, exists: { $0 == "/opt/homebrew/bin/brew" })
        #expect(brew == [.general, .developer])
    }
}

@Suite struct LeftoverFinderTests {
    let home: FakeHome
    init() throws { home = try FakeHome() }

    private func orphans(installed: Set<String> = ["com.installed.app", "com.vendor.one"],
                         running: Set<String> = []) async throws -> [String: Set<String>] {
        let context = ScanContext(home: home.url, apps: AppSnapshot(installedIDs: installed, runningIDs: running))
        let result = try await OrphanFinder().candidates(in: context)
        return Dictionary(grouping: result.candidates, by: { $0.group ?? "" })
            .mapValues { Set($0.map(\.name)) }
    }

    @Test func findsLeftoversGroupedByApp() async throws {
        try home.file("Library/Preferences/com.gone.app.plist")
        try home.file("Library/Application Support/com.gone.app/data")
        try home.file("Library/Containers/com.gone.app/Data/x")
        try home.file("Library/Preferences/com.installed.app.plist")
        try home.file("Library/Preferences/com.installed.app.helper.plist")
        let found = try await orphans()
        #expect(found == ["com.gone.app": ["Preferences", "Application Support", "Container"]])
    }

    @Test func skipsSystemSharedRunningProtectedAndNonSettingsFiles() async throws {
        try home.file("Library/Preferences/com.apple.finder.plist")
        try home.file("Library/Preferences/org.cups.PrintingPrefs.plist")
        try home.file("Library/Preferences/com.emtec.ct.fonts.txt")             // not a settings file
        try home.file("Library/Preferences/com.running.tool.plist")              // running
        try home.file("Library/Containers/com.getdropbox.dropbox/x")             // known app with user files
        try home.file("Library/Application Support/Google/x")                    // not a bundle ID
        try home.file("Library/Group Containers/UBF8T346G9.com.vendor.shared/x") // vendor installed, shared folder
        let found = try await orphans(running: ["com.running.tool"])
        #expect(found.isEmpty)
    }

    @Test func containersMatchTheExactApp() async throws {
        try home.file("Library/Containers/com.vendor.two/x")
        #expect(try await orphans().keys.contains("com.vendor.two"))
    }

    @Test func nothingIsOrphanedWhenAppsCouldNotBeListed() async throws {
        try home.file("Library/Preferences/com.gone.app.plist")
        #expect(try await orphans(installed: []).isEmpty)
    }

    @Test func brokenLoginItems() async throws {
        func agent(_ name: String, _ dict: [String: Any]) throws {
            let data = try PropertyListSerialization.data(fromPropertyList: dict, format: .xml, options: 0)
            try home.dir("Library/LaunchAgents")
            try data.write(to: home.path("Library/LaunchAgents/\(name).plist"))
        }
        try agent("com.gone.updater", ["Label": "a", "ProgramArguments": ["/Applications/Gone.app/Contents/MacOS/updater", "--x"]])
        try agent("com.gone.agent", ["Label": "b", "Program": "/opt/gone/bin/agent"])
        try agent("com.ok.agent", ["Label": "c", "ProgramArguments": ["/bin/ls"]])
        try agent("com.external.agent", ["Label": "d", "Program": "/Volumes/Backup/tool"])
        try agent("com.relative.agent", ["Label": "e", "ProgramArguments": ["node", "x.js"]])

        let result = try await BrokenLoginItemFinder().candidates(in: ScanContext(home: home.url))
        #expect(Set(result.candidates.map(\.name)) == ["com.gone.updater.plist", "com.gone.agent.plist"])
        #expect(result.candidates.allSatisfy { $0.detail?.contains("no longer exists") == true })
    }
}

@Suite struct UserDataProtectionTests {
    let home: FakeHome
    init() throws { home = try FakeHome() }

    @Test func knownUserDataFoldersAreRaisedToReview() async throws {
        try home.file("Library/Application Support/Steam/steamapps/game.bin", bytes: 4_000)
        try home.file("Library/Application Support/Other/x", bytes: 4_000)
        let rule = Rule(id: "t", title: "T", subtitle: "", symbol: "", section: .junk, profile: .general,
                        risk: .safe, finder: PathFinder(children: "Library/Application Support"))
        let items = try #require(try await scan(home, rules: [rule])["t"]).items
        let steam = try #require(items.first { $0.name == "Steam" })
        let other = try #require(items.first { $0.name == "Other" })
        #expect(steam.risk == .review)
        #expect(steam.detail == "May contain your own files")
        #expect(!AppState.isRecommended(steam, ruleOn: true))
        #expect(other.risk == .safe)
    }
}

@MainActor
@Suite(.serialized) struct ProfilePickerTests {
    private func launched() async throws -> AppState {
        let suite = testDefaultsSuite + ".profiles"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defaults.removePersistentDomain(forName: suite)
        let state = AppState(engine: .fake(delay: .zero), settings: SettingsStore(defaults: defaults))
        await state.onLaunch()
        await state.waitForScan()
        return state
    }

    @Test func showsOnFirstLaunchOnly() async throws {
        let state = try await launched()
        #expect(state.showProfilePicker)
        state.closeProfilePicker()

        let again = AppState(engine: .fake(delay: .zero), settings: state.settings)
        await again.onLaunch()
        #expect(!again.showProfilePicker)
    }

    @Test func everydayUseCannotBeTurnedOff() async throws {
        let state = try await launched()
        state.setProfile(.general, enabled: false)
        #expect(state.settings.enabledProfiles.contains(.general))
    }

    @Test func changingProfilesRescans() async throws {
        let state = try await launched()
        state.closeProfilePicker()
        #expect(!state.categories.contains { $0.rule.profile == .localAI })

        state.openProfilePicker()
        state.setProfile(.localAI, enabled: true)
        state.closeProfilePicker()
        await state.waitForScan()
        #expect(state.categories.contains { $0.rule.profile == .localAI })
    }

    @Test func closingWithoutChangesDoesNotRescan() async throws {
        let state = try await launched()
        state.closeProfilePicker()
        state.openProfilePicker()
        state.closeProfilePicker()
        #expect(state.phase == .ready)
    }
}
