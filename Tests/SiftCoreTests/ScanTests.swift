import Foundation
import Testing
@testable import SiftCore

struct StubApps: AppIndexing {
    var running: Set<String> = []
    func snapshot() async -> AppSnapshot { AppSnapshot(runningIDs: running) }
    func detectProfiles() async -> Set<Profile> { [.general] }
}

struct StubSystem: SystemInfo {
    func disk() -> DiskInfo { DiskInfo(total: 0, free: 0) }
    func hasFullDiskAccess() -> Bool { true }
    func openFullDiskAccessSettings() {}
}

/// Runs a full scan and returns categories by rule id.
func scan(_ home: FakeHome, rules: [Rule] = RuleCatalog.all, profiles: Set<Profile> = [.general],
          running: Set<String> = []) async throws -> [String: CleanCategory] {
    let engine = ScanEngine(rules: rules, home: home.url, apps: StubApps(running: running), system: StubSystem())
    var result: [String: CleanCategory] = [:]
    for try await event in engine.scan(profiles: profiles) {
        if case .category(let c) = event { result[c.rule.id] = c }
    }
    return result
}

extension CleanCategory {
    var names: Set<String> { Set(items.map(\.name)) }
}

@Suite struct SizeCalcTests {
    let home: FakeHome
    init() throws { home = try FakeHome() }

    @Test func fileAndFolderSizes() throws {
        try home.file("a/one", bytes: 10_000)
        try home.file("a/sub/two", bytes: 20_000)
        let file = SizeCalc.measure(home.path("a/one"))
        let folder = SizeCalc.measure(home.path("a"))
        #expect(file.bytes >= 10_000)
        #expect(folder.bytes >= 30_000)
        #expect(folder.bytes >= file.bytes)
        #expect(folder.modified != nil)
    }

    @Test func symlinksAreNotFollowed() throws {
        try Data(repeating: 1, count: 5_000_000).write(to: home.outside.appending(path: "big"))
        try home.symlink("a/link", to: home.outside.appending(path: "big"))
        try home.symlink("dirlink", to: home.outside)
        #expect(SizeCalc.measure(home.path("a")).bytes < 100_000)
        #expect(SizeCalc.measure(home.path("dirlink")).bytes < 100_000)
    }

    @Test func missingPathIsZero() {
        #expect(SizeCalc.measure(home.path("nope")).bytes == 0)
    }

    @Test func unreadableFolderIsReportedAsDenied() throws {
        try home.file("locked/inner/x")
        let inner = home.path("locked/inner").path(percentEncoded: false)
        chmod(inner, 0)
        defer { chmod(inner, 0o755) }
        #expect(SizeCalc.measure(home.path("locked")).denied)
    }

    @Test func stopsEarlyWhenCancelled() async throws {
        for i in 0..<3_000 { try home.file("many/\(i)", bytes: 1) }
        let many = home.path("many")
        let full = SizeCalc.measure(many).bytes
        let partial = await Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return SizeCalc.measure(many).bytes
        }.value
        #expect(partial < full)
    }
}

@Suite struct PathFinderTests {
    let home: FakeHome
    init() throws { home = try FakeHome() }

    private func found(_ finder: PathFinder) async throws -> [String] {
        try await finder.candidates(in: ScanContext(home: home.url)).candidates.map(\.name).sorted()
    }

    @Test func childrenSkipsIgnoredAndExcludedNames() async throws {
        try home.file("Library/Caches/com.a/x")
        try home.file("Library/Caches/com.B/x")
        try home.file("Library/Caches/.DS_Store")
        let finder = PathFinder(children: "Library/Caches", excluding: ["COM.b"])
        #expect(try await found(finder) == ["com.a"])
    }

    @Test func itselfOnlyWhenPresent() async throws {
        try home.file("Library/Caches/Google/Chrome/x")
        let finder = PathFinder([.init("Library/Caches/Google/Chrome", .itself),
                                 .init("Library/Caches/Missing", .itself)])
        #expect(try await found(finder) == ["Chrome"])
    }

    @Test func globsExpand() async throws {
        try home.file("Library/Application Support/Google/AndroidStudio2024.1/x")
        try home.file("Library/Application Support/Google/AndroidStudio2025.2/x")
        try home.file("Library/Application Support/Google/Chrome/x")
        let finder = PathFinder([.init("Library/Application Support/Google/AndroidStudio*", .itself)])
        #expect(try await found(finder) == ["AndroidStudio2024.1", "AndroidStudio2025.2"])
    }

    @Test func missingFolderIsNotDenied() async throws {
        let result = try await PathFinder(children: "Library/Nope").candidates(in: ScanContext(home: home.url))
        #expect(result.candidates.isEmpty && !result.denied)
    }

    @Test func unreadableFolderIsDenied() async throws {
        try home.file("Library/Locked/x")
        let path = home.path("Library/Locked").path(percentEncoded: false)
        chmod(path, 0)
        defer { chmod(path, 0o755) }
        let result = try await PathFinder(children: "Library/Locked").candidates(in: ScanContext(home: home.url))
        #expect(result.denied)
    }
}

@Suite struct ScanEngineTests {
    let home: FakeHome
    init() throws { home = try FakeHome() }

    /// A home folder with something for every junk rule.
    private func seedJunk() throws {
        try home.file("Library/Caches/com.spotify.client/data", bytes: 4_000)
        try home.file("Library/Caches/com.tinyspeck.slackmacgap/data", bytes: 4_000)
        try home.file("Library/Caches/com.apple.bird/data", bytes: 4_000)           // excluded
        try home.file("Library/Caches/com.apple.Safari/cache.db", bytes: 4_000)      // browser
        try home.file("Library/Caches/Google/Chrome/Default/x", bytes: 4_000)        // browser
        try home.file("Library/Caches/Google/DriveFS/x", bytes: 4_000)               // app cache, split out of Google
        try home.file("Library/Caches/BraveSoftware/x", bytes: 4_000)
        try home.file("Library/Containers/com.apple.Safari/Data/Library/Caches/WebKit/x", bytes: 4_000)
        try home.file("Library/Logs/JetBrains/idea.log", bytes: 4_000)
        try home.file("Library/Logs/DiagnosticReports/App-2026.ips", bytes: 4_000)   // crash, not logs
        try home.file("Library/Application Support/CrashReporter/Intervals.plist", bytes: 4_000)
        try home.file("Library/Saved Application State/com.apple.Terminal.savedState/data", bytes: 4_000)
        try home.file("\(RuleCatalog.mailDownloadsPath)/ABC/invoice.pdf", bytes: 4_000)
        try home.file(".Trash/old.zip", bytes: 4_000)
        try home.file("Library/Caches/empty-dir/.keep", bytes: 0)                    // zero size, dropped
    }

    @Test func eachJunkRuleFindsItsItems() async throws {
        try seedJunk()
        let result = try await scan(home)

        #expect(result["appCaches"]?.names == ["com.spotify.client", "com.tinyspeck.slackmacgap", "DriveFS"])
        #expect(result["browserCaches"]?.names == ["com.apple.Safari", "Chrome", "BraveSoftware", "WebKit"])
        #expect(result["logs"]?.names == ["JetBrains"])
        #expect(result["crashReports"]?.names == ["App-2026.ips", "Intervals.plist"])
        #expect(result["savedState"]?.names == ["com.apple.Terminal.savedState"])
        #expect(result["mailDownloads"]?.names == ["ABC"])
        #expect(result["trash"]?.names == ["old.zip"])
    }

    @Test func itemsCarryTheirRulesRiskAndDeletionFacts() async throws {
        try seedJunk()
        let result = try await scan(home)

        let mail = try #require(result["mailDownloads"]?.items.first)
        #expect(mail.risk == .caution)
        #expect(mail.safetyExceptions == [RuleCatalog.mailDownloadsPath])
        #expect(CleanEngine.disposal(for: mail, mode: .smart) == .trash)

        let trash = try #require(result["trash"]?.items.first)
        #expect(trash.forcePermanent)
        #expect(CleanEngine.disposal(for: trash, mode: .trash) == .permanent)

        let cache = try #require(result["appCaches"]?.items.first)
        #expect(cache.risk == .safe && cache.size >= 4_000)
    }

    @Test func everyFoundItemPassesTheSafetyGuard() async throws {
        try seedJunk()
        for category in try await scan(home).values {
            for item in category.items {
                let check = SafetyGuard.validate(item.url, home: home.url, exceptions: item.safetyExceptions)
                #expect(check.isSuccess, "\(item.url.path(percentEncoded: false))")
            }
        }
    }

    @Test func noPathIsListedTwice() async throws {
        try seedJunk()
        let all = try await scan(home).values.flatMap(\.items).map { ScanEngine.key($0.url) }
        #expect(all.count == Set(all).count)
        for a in all {
            #expect(!all.contains { $0 != a && $0.hasPrefix(a + "/") }, "\(a) contains another item")
        }
    }

    @Test func runningAppsAreMarked() async throws {
        try seedJunk()
        let result = try await scan(home, running: ["com.tinyspeck.slackmacgap"])
        let slack = try #require(result["appCaches"]?.items.first { $0.name == "com.tinyspeck.slackmacgap" })
        #expect(slack.isRunningApp)
        #expect(slack.detail == "App is running")
    }

    /// Browser cache folders aren't named after a bundle ID ("BraveSoftware"),
    /// so the entry names its owner. Found on a real Mac: Brave was running and its cache was ticked.
    @Test func runningBrowserCacheIsMarked() async throws {
        try home.file("Library/Caches/BraveSoftware/Brave-Browser/Default/Cache/data", bytes: 50_000)
        try home.file("Library/Caches/Google/Chrome/Default/Cache/data", bytes: 50_000)
        let result = try await scan(home, running: ["com.brave.Browser"])
        let items = try #require(result["browserCaches"]?.items)
        let brave = try #require(items.first { $0.group == "Brave" })
        let chrome = try #require(items.first { $0.group == "Chrome" })
        #expect(brave.isRunningApp)
        #expect(brave.detail == "Brave is running")
        #expect(!chrome.isRunningApp)
    }

    @Test func itemsAreSortedLargestFirst() async throws {
        try home.file("Library/Caches/small/x", bytes: 1_000)
        try home.file("Library/Caches/big/x", bytes: 900_000)
        let items = try #require(try await scan(home)["appCaches"]?.items)
        #expect(items.map(\.name) == ["big", "small"])
    }

    @Test func onlyEnabledProfilesAreScanned() async throws {
        try seedJunk()
        let result = try await scan(home, profiles: [.developer])
        #expect(!result.isEmpty)
        #expect(result.values.allSatisfy { $0.rule.profile == .developer })
    }

    @Test func unreadableFDAFolderFlagsCategory() async throws {
        try home.file(".Trash/x")
        let path = home.path(".Trash").path(percentEncoded: false)
        chmod(path, 0)
        defer { chmod(path, 0o755) }
        #expect(try await scan(home)["trash"]?.needsFDA == true)
    }

    @Test func progressEndsAtOneAndFinishes() async throws {
        let engine = ScanEngine(rules: RuleCatalog.all, home: home.url, apps: StubApps(), system: StubSystem())
        var last = 0.0, finished = false
        for try await event in engine.scan(profiles: [.general]) {
            switch event {
            case .progress(let p, _): last = p
            case .finished: finished = true
            case .category: break
            }
        }
        #expect(last == 1 && finished)
    }

    @Test func cancellingStopsQuickly() async throws {
        for i in 0..<20_000 { try home.file("Library/Caches/huge/\(i)", bytes: 1) }
        let engine = ScanEngine(rules: RuleCatalog.all, home: home.url, apps: StubApps(), system: StubSystem())
        let clock = ContinuousClock()
        let start = clock.now
        let task = Task {
            for try await _ in engine.scan(profiles: [.general]) {}
        }
        try await Task.sleep(for: .milliseconds(20))
        task.cancel()
        _ = await task.result
        #expect(clock.now - start < .seconds(1))
    }
}
