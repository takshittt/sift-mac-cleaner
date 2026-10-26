import Foundation
@testable import SiftCore

/// One fixed preferences name for tests, cleared before each use, so test runs
/// don't leave a new file in ~/Library/Preferences every time.
let testDefaultsSuite = "com.takshitsaini.sift.tests"

/// A throwaway home folder in the temp directory. Tests never touch the real one.
final class FakeHome {
    let url: URL
    let outside: URL

    init() throws {
        let root = FileManager.default.temporaryDirectory
            .appending(path: "sift-tests-\(UUID().uuidString)", directoryHint: .isDirectory)
        url = root.appending(path: "home", directoryHint: .isDirectory)
        outside = root.appending(path: "outside", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: outside, withIntermediateDirectories: true)
    }

    deinit { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }

    func path(_ rel: String) -> URL { url.appending(path: rel) }

    @discardableResult
    func file(_ rel: String, bytes: Int = 16) throws -> URL {
        let target = path(rel)
        try FileManager.default.createDirectory(at: target.deletingLastPathComponent(),
                                                withIntermediateDirectories: true)
        try Data(repeating: 0, count: bytes).write(to: target)
        return target
    }

    func dir(_ rel: String) throws {
        try FileManager.default.createDirectory(at: path(rel), withIntermediateDirectories: true)
    }

    func symlink(_ rel: String, to destination: URL) throws {
        let link = path(rel)
        try FileManager.default.createDirectory(at: link.deletingLastPathComponent(),
                                                withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: destination)
    }

    func exists(_ rel: String) -> Bool { LiveFileRemover().exists(path(rel)) }
}

/// Records calls instead of touching the disk.
final class RecordingRemover: FileRemoving, @unchecked Sendable {
    enum Call: Equatable { case remove(String), trash(String) }

    private let lock = NSLock()
    private var _calls: [Call] = []
    var calls: [Call] { lock.withLock { _calls } }

    let failing: Set<String>
    let missing: Set<String>
    let onCall: @Sendable () -> Void

    init(failing: Set<String> = [], missing: Set<String> = [], onCall: @escaping @Sendable () -> Void = {}) {
        self.failing = failing
        self.missing = missing
        self.onCall = onCall
    }

    func exists(_ url: URL) -> Bool { !missing.contains(url.lastPathComponent) }

    func remove(_ url: URL) throws { try record(.remove(url.lastPathComponent), url) }
    func trash(_ url: URL) throws { try record(.trash(url.lastPathComponent), url) }

    private func record(_ call: Call, _ url: URL) throws {
        lock.withLock { _calls.append(call) }
        onCall()
        if failing.contains(url.lastPathComponent) {
            throw CocoaError(.fileWriteNoPermission)
        }
    }
}

func item(_ url: URL, risk: Risk = .safe, size: Int64 = 100, disposal: Disposal = .permanent,
          forcePermanent: Bool = false, exceptions: [String] = []) -> CleanItem {
    CleanItem(ruleID: "test", url: url, size: size, risk: risk, disposal: disposal,
              forcePermanent: forcePermanent, safetyExceptions: exceptions)
}
