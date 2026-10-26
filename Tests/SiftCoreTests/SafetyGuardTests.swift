import Foundation
import Testing
@testable import SiftCore

@Suite struct SafetyGuardTests {
    let home: FakeHome
    init() throws { home = try FakeHome() }

    /// Home path without a trailing slash, for building paths by hand.
    private var homePath: String { SafetyGuard.plainPath(home.url)! }

    private func check(_ url: URL, exceptions: [String] = []) -> Violation? {
        switch SafetyGuard.validate(url, home: home.url, exceptions: exceptions) {
        case .success: nil
        case .failure(let violation): violation
        }
    }

    private func check(_ rel: String, exceptions: [String] = []) -> Violation? {
        check(home.path(rel), exceptions: exceptions)
    }

    // MARK: Allowed

    @Test func allowsCacheInsideHome() throws {
        try home.file("Library/Caches/com.example.app/data")
        #expect(check("Library/Caches/com.example.app") == nil)
        #expect(check("Library/Caches/com.example.app/data") == nil)
    }

    @Test func allowsPathsThatDoNotExistYet() {
        #expect(check("Library/Caches/gone/away") == nil)
    }

    @Test func allowsSymlinkInsideHomeToUnprotectedTarget() throws {
        try home.dir("Library/Caches/real")
        try home.symlink("Library/Caches/alias", to: home.path("Library/Caches/real"))
        #expect(check("Library/Caches/alias/file") == nil)
    }

    @Test func allowsLookalikesOfProtectedNames() {
        #expect(check("Library/Caches/Keychains") == nil)
        #expect(check("Library/Group Containers/group.com.docker") == nil)
        #expect(check("Library/Logs/Mail") == nil)
    }

    // MARK: 1. Normalised

    @Test(arguments: ["Library/../Library/Caches/x", "Library/./Caches/x", "Library//Caches/x"])
    func rejectsUnnormalisedPaths(_ rel: String) {
        let url = URL(filePath: homePath + "/" + rel)
        #expect(check(url) == .notNormalised)
    }

    @Test func rejectsNonFileURLs() {
        #expect(check(URL(string: "https://example.com/Library/Caches")!) == .notNormalised)
    }

    // MARK: 2. Inside home

    @Test func rejectsPathsOutsideHome() {
        #expect(check(URL(filePath: "/tmp/x")) == .outsideHome)
        #expect(check(URL(filePath: "/System/Library/Caches")) == .outsideHome)
        #expect(check(home.outside.appending(path: "x")) == .outsideHome)
    }

    @Test func rejectsSiblingThatSharesHomePrefix() {
        // "/…/home-other" starts with "/…/home" but isn't inside it.
        let sibling = URL(filePath: homePath + "-other/Library/Caches/x")
        #expect(check(sibling) == .outsideHome)
    }

    // MARK: 3. Resolves inside home

    @Test func rejectsParentSymlinkEscapingHome() throws {
        try home.symlink("Library/Caches/escape", to: home.outside)
        #expect(check("Library/Caches/escape/victim") == .resolvesOutsideHome)
    }

    @Test func rejectsItemSymlinkPointingOutsideHome() throws {
        try FileManager.default.createDirectory(at: home.outside.appending(path: "target"),
                                                withIntermediateDirectories: true)
        try home.symlink("Library/Caches/link", to: home.outside.appending(path: "target"))
        #expect(check("Library/Caches/link") == .resolvesOutsideHome)
    }

    @Test func handlesPrivateVarAliasing() throws {
        // Temp dirs live under /var → /private/var; the canonical home must still match.
        try home.file("Library/Caches/a/b")
        let canonical = URL(filePath: SafetyGuard.canonicalPath(home.url.path(percentEncoded: false)))
        #expect(SafetyGuard.validate(canonical.appending(path: "Library/Caches/a"), home: home.url).isSuccess)
    }

    // MARK: 4. Top-level folders

    @Test func rejectsHomeItself() {
        #expect(check(home.url) == .isHomeOrTopLevel)
    }

    @Test(arguments: SafetyGuard.topLevel)
    func rejectsTopLevelFolders(_ rel: String) {
        #expect(check(rel) == .isHomeOrTopLevel)
    }

    @Test func topLevelIsCaseInsensitive() {
        #expect(check("library/CACHES") == .isHomeOrTopLevel)
    }

    // MARK: 5. Protected

    @Test(arguments: SafetyGuard.protectedPaths)
    func rejectsProtectedPathsAndTheirContents(_ pattern: String) {
        let rel = pattern.replacingOccurrences(of: "*", with: "x")
        // A folder that is also top-level is caught by that earlier check.
        let expected: Violation = SafetyGuard.topLevel.contains(rel) ? .isHomeOrTopLevel : .protected
        #expect(check(rel) == expected)
        #expect(check(rel + "/deep/file") == .protected)
    }

    @Test func protectedIsCaseInsensitive() {
        #expect(check("library/keychains/login.keychain-db") == .protected)
        #expect(check("LIBRARY/MAIL/V10") == .protected)
    }

    @Test func protectedGlobsMatchVariants() {
        #expect(check("OneDrive - Personal/report.docx") == .protected)
        #expect(check("Library/Group Containers/group.com.apple.notes/db") == .protected)
    }

    @Test func protectsPhotosLibrariesAnywhere() {
        #expect(check("Pictures/Photos Library.photoslibrary/database") == .protected)
        #expect(check("Movies/Old.photoslibrary") == .protected)
    }

    @Test func rejectsSymlinkInsideHomeIntoProtectedArea() throws {
        try home.file("Library/Keychains/login.keychain-db")
        try home.symlink("Library/Caches/kc", to: home.path("Library/Keychains"))
        #expect(check("Library/Caches/kc/login.keychain-db") == .protected)
    }

    // MARK: Exceptions

    @Test func exceptionLiftsOnlyItsOwnSubtree() {
        let backups = ["Library/Application Support/MobileSync/Backup"]
        #expect(check("Library/Application Support/MobileSync/Backup/0000-1111", exceptions: backups) == nil)
        #expect(check("Library/Application Support/MobileSync/Other", exceptions: backups) == .protected)
        #expect(check("Library/Keychains/x", exceptions: backups) == .protected)
    }

    @Test func exceptionDoesNotLiftOtherChecks() throws {
        try home.symlink("Documents-link", to: home.outside)
        #expect(check("Documents", exceptions: ["Documents"]) == .isHomeOrTopLevel)
        #expect(check("Documents-link/x", exceptions: ["Documents-link"]) == .resolvesOutsideHome)
        #expect(check("Documents/big.mov", exceptions: ["Documents"]) == nil)
    }

    // MARK: Edge cases (keep every branch covered)

    @Test func emptyHomeRejectsEverything() throws {
        let emptyHome = try #require(URL(string: "file://"))
        #expect(SafetyGuard.plainPath(emptyHome) == nil)
        let result = SafetyGuard.validate(home.path("Library/Caches/x"), home: emptyHome)
        #expect(result == .failure(.outsideHome))
    }

    @Test func relativeToRoot() {
        #expect(SafetyGuard.relative("/Users/x", to: "/") == "users/x")
        #expect(SafetyGuard.relative("/", to: "/") == "")
    }

    @Test func canonicalPathKeepsAnUnresolvableRelativePath() {
        let path = "sift-no-such-relative-\(UUID().uuidString)/x"
        #expect(SafetyGuard.canonicalPath(path) == path)
    }

    @Test func everyViolationHasAMessage() {
        let all: [Violation] = [.notNormalised, .outsideHome, .resolvesOutsideHome, .isHomeOrTopLevel, .protected]
        #expect(Set(all.map(\.message)).count == all.count)
        #expect(all.allSatisfy { !$0.message.isEmpty })
    }
}
