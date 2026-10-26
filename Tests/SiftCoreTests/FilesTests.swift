import Foundation
import Testing
@testable import SiftCore
@testable import SiftAppModel

@Suite struct FilesRulesTests {
    let home: FakeHome
    init() throws { home = try FakeHome() }

    private func rule(_ id: String) throws -> Rule { try #require(RuleCatalog.rule(id: id)) }

    /// A file that reports `bytes` as its size but takes almost no disk space.
    private func sparse(_ rel: String, bytes: UInt64) throws {
        let url = try home.file(rel, bytes: 0)
        let handle = try FileHandle(forWritingTo: url)
        try handle.truncate(atOffset: bytes - 1)
        try handle.write(contentsOf: Data([1]))
        try handle.close()
    }

    @Test func installersInDownloadsAndDesktopUpToThreeLevels() async throws {
        try home.file("Downloads/Docker.dmg")
        try home.file("Downloads/Setup.PKG")
        try home.file("Desktop/old/macOS.iso")
        try home.file("Downloads/a/b/Xcode.xip")              // level 3: found
        try home.file("Downloads/a/b/c/Too-deep.dmg")         // below the depth limit
        try home.file("Downloads/notes.txt")
        try home.file("Downloads/Tool.app/Contents/inner.dmg") // inside a package
        try home.file("Downloads/proj/node_modules/x/y.dmg")   // dependency folder
        try home.file("Documents/Installer.dmg")              // not a searched folder

        let items = try #require(try await scan(home, rules: [rule("installers")])["installers"]).items
        #expect(Set(items.map(\.name)) == ["Docker.dmg", "Setup.PKG", "macOS.iso", "Xcode.xip"])
        #expect(items.first { $0.name == "Docker.dmg" }?.detail == "Disk image")
        #expect(items.allSatisfy { $0.risk == .caution && !AppState.isRecommended($0, ruleOn: true) })
    }

    @Test func largeFilesIncludingDocuments() async throws {
        try sparse("Documents/Projects/render.mov", bytes: 600_000_000)
        try sparse("Movies/clip.mp4", bytes: 520_000_000)
        try sparse("Downloads/small.zip", bytes: 400_000_000)
        try sparse("Pictures/huge.raw", bytes: 900_000_000)   // not a searched folder

        let items = try #require(try await scan(home, rules: [rule("largeFiles")])["largeFiles"]).items
        #expect(Set(items.map(\.name)) == ["render.mov", "clip.mp4"])
        let render = try #require(items.first { $0.name == "render.mov" })
        #expect(render.detail == "Projects")
        #expect(render.risk == .review)
        // Documents is protected, but this rule has an explicit exception for it.
        #expect(SafetyGuard.validate(render.url, home: home.url, exceptions: render.safetyExceptions).isSuccess)
        #expect(!SafetyGuard.validate(render.url, home: home.url).isSuccess)
    }

    @Test func oldDownloadsUsesTheLatestOfItsDates() async throws {
        try home.file("Downloads/old.pdf")
        try home.file("Downloads/recent.pdf")
        try home.file("Downloads/old-folder/x")
        let now = Date()
        let finder = UnusedItemsFinder(folder: "Downloads", days: 90) { url, _ in
            url.lastPathComponent.hasPrefix("old") ? now.addingTimeInterval(-100 * 86_400)
                                                   : now.addingTimeInterval(-89 * 86_400)
        }
        let result = try await finder.candidates(in: ScanContext(home: home.url, now: now))
        #expect(Set(result.candidates.map(\.name)) == ["old.pdf", "old-folder"])
        #expect(result.candidates.allSatisfy { $0.detail?.hasPrefix("Last used") == true })
    }

    @Test func lastUsedIgnoresAccessTime() throws {
        let url = try home.file("Downloads/x.pdf")
        let old = Date(timeIntervalSinceNow: -200 * 86_400)
        try FileManager.default.setAttributes([.modificationDate: old], ofItemAtPath: url.path(percentEncoded: false))
        var values = try url.resourceValues(forKeys: Set(FileSearchFinder.keys))
        values.contentAccessDate = Date()   // a background process touched it
        let last = try #require(FileSearchFinder.lastUsed(url, values))
        // The added date (now, in a fresh temp folder) wins, never the access date alone.
        #expect(last >= old)
    }

    @Test func eachFileIsListedUnderOneRuleOnly() async throws {
        try sparse("Downloads/Big Installer.dmg", bytes: 700_000_000)  // installer, large and old
        try sparse("Downloads/movie.mkv", bytes: 800_000_000)           // large and old
        try home.file("Downloads/receipt.pdf")                          // old only
        let everythingOld = Rule(id: "oldDownloads", title: "Old Downloads", subtitle: "", symbol: "",
                                 section: .files, profile: .general, risk: .review, pass: 2,
                                 finder: UnusedItemsFinder(folder: "Downloads", days: 90) { _, _ in .distantPast })
        let result = try await scan(home, rules: [rule("installers"), rule("largeFiles"), everythingOld])
        #expect(result["installers"]?.names == ["Big Installer.dmg"])
        #expect(result["largeFiles"]?.names == ["movie.mkv"])
        #expect(result["oldDownloads"]?.names == ["receipt.pdf"])
    }

    @Test func deviceBackupsAreNamedAfterTheDevice() async throws {
        let info: [String: Any] = ["Device Name": "Takshit's iPhone", "Last Backup Date": Date(timeIntervalSince1970: 1_750_000_000)]
        let data = try PropertyListSerialization.data(fromPropertyList: info, format: .xml, options: 0)
        try home.dir("\(DeviceBackupFinder.folder)/00008110-AAAA")
        try data.write(to: home.path("\(DeviceBackupFinder.folder)/00008110-AAAA/Info.plist"))
        try home.file("\(DeviceBackupFinder.folder)/00008110-AAAA/Manifest.db", bytes: 10_000)
        try home.file("\(DeviceBackupFinder.folder)/00008030-BBBB/Manifest.db", bytes: 10_000)  // no Info.plist

        let category = try #require(try await scan(home, rules: [rule("deviceBackups")])["deviceBackups"])
        #expect(category.names == ["Takshit's iPhone", "00008030-BBBB"])
        let phone = try #require(category.items.first { $0.name == "Takshit's iPhone" })
        #expect(phone.detail?.hasPrefix("Last backed up") == true)
        #expect(phone.risk == .review)
        #expect(SafetyGuard.validate(phone.url, home: home.url, exceptions: phone.safetyExceptions).isSuccess)
        // Only backups: the rest of MobileSync stays protected.
        #expect(!SafetyGuard.validate(home.path("Library/Application Support/MobileSync/Other"), home: home.url,
                                      exceptions: phone.safetyExceptions).isSuccess)
    }

    @Test func unreadableBackupsFolderNeedsFullDiskAccess() async throws {
        try home.file("\(DeviceBackupFinder.folder)/X/Manifest.db")
        let path = home.path(DeviceBackupFinder.folder).path(percentEncoded: false)
        chmod(path, 0)
        defer { chmod(path, 0o755) }
        #expect(try await scan(home, rules: [rule("deviceBackups")])["deviceBackups"]?.needsFDA == true)
    }
}

@MainActor
@Suite(.serialized) struct FullDiskAccessTests {
    struct NoFDA: SystemInfo {
        func disk() -> DiskInfo { DiskInfo(total: 0, free: 0) }
        func hasFullDiskAccess() -> Bool { false }
        func openFullDiskAccessSettings() {}
    }

    @Test func hiddenCategoriesStayVisibleWithoutFDA() async throws {
        let home = try FakeHome()
        try home.file("\(DeviceBackupFinder.folder)/X/Manifest.db")
        let path = home.path(DeviceBackupFinder.folder).path(percentEncoded: false)
        chmod(path, 0)
        defer { chmod(path, 0o755) }

        let engine = Engine(scanner: ScanEngine(rules: RuleCatalog.files, home: home.url, apps: StubApps(), system: NoFDA()),
                            cleaner: CleanEngine(home: home.url, remover: RecordingRemover()),
                            apps: StubApps(), system: NoFDA())
        let suite = testDefaultsSuite + ".fda"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defaults.removePersistentDomain(forName: suite)
        let state = AppState(engine: engine, settings: SettingsStore(defaults: defaults))
        await state.onLaunch()
        await state.waitForScan()

        #expect(!state.fullDiskAccess)   // drives the banner
        let backups = try #require(state.categories.first { $0.rule.id == "deviceBackups" })
        #expect(backups.items.isEmpty && backups.needsFDA)
    }
}
