import Foundation
import Testing
@testable import SiftCore
@testable import SiftAppModel

@Suite struct DeveloperRulesTests {
    let home: FakeHome
    init() throws { home = try FakeHome() }

    private func rule(_ id: String) throws -> Rule { try #require(RuleCatalog.rule(id: id)) }

    /// Sets a modification date on a file or folder.
    private func touch(_ rel: String, daysAgo: Double) throws {
        try FileManager.default.setAttributes([.modificationDate: Date(timeIntervalSinceNow: -daysAgo * 86_400)],
                                              ofItemAtPath: home.path(rel).path(percentEncoded: false))
    }

    /// A project whose own files were last changed `daysAgo`, with a node_modules folder.
    private func project(_ rel: String, daysAgo: Double) throws {
        try home.file("\(rel)/package.json")
        try home.file("\(rel)/src/index.js")
        try home.file("\(rel)/node_modules/lodash/index.js", bytes: 8_000)
        for part in ["package.json", "src/index.js", "src", ""] {
            try touch(part.isEmpty ? rel : "\(rel)/\(part)", daysAgo: daysAgo)
        }
    }

    @Test func staleNodeModulesUsesTheProjectsNewestFile() async throws {
        try project("Projects/old-site", daysAgo: 61)
        try project("Projects/active-app", daysAgo: 59)
        try project("Documents/GitHub/archived", daysAgo: 200)
        try project("Projects/client/frontend", daysAgo: 90)
        try project("Projects/edited", daysAgo: 90)
        try home.file("Projects/edited/src/new.js")   // one fresh file keeps the project active

        let items = try #require(try await scan(home, rules: [rule("staleNodeModules")], profiles: [.developer])["staleNodeModules"]).items
        #expect(Set(items.map(\.name)) == ["old-site", "archived", "frontend"])
        #expect(items.allSatisfy { $0.url.lastPathComponent == "node_modules" })
        #expect(items.allSatisfy { $0.detail?.hasPrefix("Project last changed") == true })
        // Documents is protected; this rule's exception lets its node_modules through.
        let archived = try #require(items.first { $0.name == "archived" })
        #expect(SafetyGuard.validate(archived.url, home: home.url, exceptions: archived.safetyExceptions).isSuccess)
    }

    @Test func nestedNodeModulesAreNotListedSeparately() async throws {
        try project("Projects/old", daysAgo: 100)
        try home.file("Projects/old/node_modules/pkg/node_modules/dep/x.js")
        let items = try #require(try await scan(home, rules: [rule("staleNodeModules")], profiles: [.developer])["staleNodeModules"]).items
        #expect(items.map(\.name) == ["old"])
    }

    @Test func packageCachesGetTheirOwnNamesAndRisks() async throws {
        try home.file(".npm/_cacache/index", bytes: 4_000)
        try home.file("Library/pnpm/store/v3/x", bytes: 4_000)
        try home.file(".gradle/caches/modules/x", bytes: 4_000)
        try home.file("Library/Caches/Homebrew/downloads/x", bytes: 4_000)

        let items = try #require(try await scan(home, rules: [rule("pkgCaches")], profiles: [.developer])["pkgCaches"]).items
        let byName = Dictionary(uniqueKeysWithValues: items.map { ($0.name, $0) })
        #expect(Set(byName.keys) == ["npm cache", "pnpm store", "Gradle caches", "Homebrew downloads"])
        #expect(byName["npm cache"]?.risk == .safe)
        #expect(byName["Homebrew downloads"]?.risk == .safe)
        #expect(byName["pnpm store"]?.risk == .caution)
        #expect(byName["pnpm store"]?.detail == "Projects re-link on next install")
        #expect(byName["Gradle caches"]?.detail == "Offline builds need a re-download")
    }

    @Test func developerCachesLeaveAppCachesWhenTheProfileIsOn() async throws {
        try home.file("Library/Caches/Homebrew/x", bytes: 4_000)
        try home.file("Library/Caches/com.apple.dt.Xcode/x", bytes: 4_000)
        try home.file("Library/Caches/com.spotify.client/x", bytes: 4_000)

        let on = try await scan(home, profiles: [.general, .developer])
        #expect(on["appCaches"]?.names == ["com.spotify.client"])
        #expect(on["pkgCaches"]?.names == ["Homebrew downloads"])
        #expect(on["xcodeDerivedData"]?.names == ["Xcode cache"])

        // Developer off: they're still plain regenerable caches.
        let off = try await scan(home, profiles: [.general])
        #expect(off["appCaches"]?.names == ["Homebrew", "com.apple.dt.Xcode", "com.spotify.client"])
    }

    @Test func xcodeRunningUnticksItsBuildData() async throws {
        try home.file("Library/Developer/Xcode/DerivedData/MyApp-abc/Build/x", bytes: 4_000)
        try home.file("Library/Developer/Xcode/iOS DeviceSupport/18.0 (22A)/Symbols/x", bytes: 4_000)
        let result = try await scan(home, profiles: [.developer], running: ["com.apple.dt.Xcode"])
        let derived = try #require(result["xcodeDerivedData"]?.items.first)
        #expect(derived.isRunningApp && derived.detail == "Xcode is running")
        #expect(!AppState.isRecommended(derived, ruleOn: true))
        #expect(result["deviceSupport"]?.items.first?.group == "iOS")

        let idle = try #require(try await scan(home, profiles: [.developer])["xcodeDerivedData"]?.items.first)
        #expect(!idle.isRunningApp && AppState.isRecommended(idle, ruleOn: true))
    }

    @Test func archivesAreListedOnePerArchive() async throws {
        try home.file("Library/Developer/Xcode/Archives/2026-01-10/MyApp 10-01-2026.xcarchive/Info.plist", bytes: 4_000)
        try home.file("Library/Developer/Xcode/Archives/2026-03-02/MyApp 02-03-2026.xcarchive/Info.plist", bytes: 4_000)
        let items = try #require(try await scan(home, profiles: [.developer])["xcodeArchives"]).items
        #expect(items.count == 2 && items.allSatisfy { $0.risk == .review })
    }

    @Test func everyDeveloperItemPassesTheSafetyGuard() async throws {
        try project("Projects/old", daysAgo: 100)
        try home.file(".npm/_cacache/x", bytes: 4_000)
        try home.file("Library/Developer/Xcode/DerivedData/A/x", bytes: 4_000)
        try home.file("Library/Developer/CoreSimulator/Caches/dyld/x", bytes: 4_000)
        for category in try await scan(home, profiles: [.developer]).values {
            for item in category.items {
                #expect(SafetyGuard.validate(item.url, home: home.url, exceptions: item.safetyExceptions).isSuccess,
                        "\(item.url.path(percentEncoded: false))")
            }
        }
    }
}
