import Foundation
import Testing
@testable import SiftCore

@Suite struct CleanEngineTests {
    let home: FakeHome
    init() throws { home = try FakeHome() }

    // MARK: Disposal matrix

    struct Case: Sendable, CustomTestStringConvertible {
        let mode: DeletionMode, risk: Risk, ruleDisposal: Disposal, force: Bool
        var testDescription: String { "\(mode) \(risk) \(ruleDisposal) force=\(force)" }

        var expected: Disposal {
            if force { return .permanent }
            switch mode {
            case .permanent: return .permanent
            case .trash: return .trash
            case .smart: return risk == .safe ? ruleDisposal : .trash
            }
        }
    }

    static let matrix: [Case] = DeletionMode.allCases.flatMap { mode in
        Risk.allCases.flatMap { risk in
            [Disposal.permanent, .trash].flatMap { disposal in
                [false, true].map { Case(mode: mode, risk: risk, ruleDisposal: disposal, force: $0) }
            }
        }
    }

    @Test(arguments: matrix)
    func disposalMatrix(_ c: Case) {
        let it = item(home.path("Library/Caches/x"), risk: c.risk, disposal: c.ruleDisposal, forcePermanent: c.force)
        #expect(CleanEngine.disposal(for: it, mode: c.mode) == c.expected)
    }

    @Test func smartNeverDeletesReviewOrCautionPermanently() {
        for risk in [Risk.caution, .review] {
            let it = item(home.path("Downloads/a.dmg"), risk: risk, disposal: .permanent)
            #expect(CleanEngine.disposal(for: it, mode: .smart) == .trash)
        }
    }

    // MARK: Reporting

    @Test func reportsCountsAndBytesPerDisposal() async {
        let remover = RecordingRemover()
        let engine = CleanEngine(home: home.url, remover: remover)
        let items = [
            item(home.path("Library/Caches/a"), risk: .safe, size: 1_000),
            item(home.path("Downloads/b.dmg"), risk: .caution, size: 500, disposal: .trash),
            item(home.path(".Trash/c"), risk: .safe, size: 70, forcePermanent: true),
        ]
        let report = await engine.clean(items, mode: .smart) { _ in }

        #expect(remover.calls == [.remove("a"), .trash("b.dmg"), .remove("c")])
        #expect(report.deletedCount == 2)
        #expect(report.deletedBytes == 1_070)
        #expect(report.trashedCount == 1)
        #expect(report.trashedBytes == 500)
        #expect(report.failures.isEmpty)
    }

    @Test func progressReachesOne() async {
        let values = Mutex<[Double]>([])
        let engine = CleanEngine(home: home.url, remover: RecordingRemover())
        let items = (0..<4).map { item(home.path("Library/Caches/\($0)")) }
        _ = await engine.clean(items, mode: .smart) { v in values.withLock { $0.append(v) } }
        #expect(values.withLock { $0 } == [0.25, 0.5, 0.75, 1.0])
    }

    // MARK: Safety at deletion time

    @Test func protectedItemIsNeverPassedToRemover() async {
        let remover = RecordingRemover()
        let engine = CleanEngine(home: home.url, remover: remover)
        let items = [
            item(home.path("Library/Keychains/login.keychain-db")),
            item(URL(filePath: "/etc/hosts")),
            item(home.url),
        ]
        let report = await engine.clean(items, mode: .permanent) { _ in }

        #expect(remover.calls.isEmpty)
        #expect(report.failures.map(\.message) == [
            Violation.protected.message, Violation.outsideHome.message, Violation.isHomeOrTopLevel.message,
        ])
    }

    @Test func protectedFileSurvivesRealDeletion() async throws {
        try home.file("Library/Keychains/login.keychain-db")
        try home.file("Library/Caches/com.example/data")
        let engine = CleanEngine(home: home.url) // real FileManager, but only inside the fake home
        let items = [
            item(home.path("Library/Keychains/login.keychain-db")),
            item(home.path("Library/Caches/com.example")),
        ]
        let report = await engine.clean(items, mode: .permanent) { _ in }

        #expect(home.exists("Library/Keychains/login.keychain-db"))
        #expect(!home.exists("Library/Caches/com.example"))
        #expect(report.deletedCount == 1)
        #expect(report.failures.count == 1)
    }

    @Test func symlinkEscapeIsBlockedAtDeletionTime() async throws {
        let victim = home.outside.appending(path: "victim")
        try Data([1]).write(to: victim)
        try home.symlink("Library/Caches/escape", to: home.outside)

        let engine = CleanEngine(home: home.url)
        let report = await engine.clean([item(home.path("Library/Caches/escape/victim"))], mode: .permanent) { _ in }

        #expect(FileManager.default.fileExists(atPath: victim.path(percentEncoded: false)))
        #expect(report.failures.first?.message == Violation.resolvesOutsideHome.message)
    }

    @Test func exceptionAllowsRuleSpecificProtectedPath() async {
        let remover = RecordingRemover()
        let engine = CleanEngine(home: home.url, remover: remover)
        let backup = item(home.path("Library/Application Support/MobileSync/Backup/0000"), risk: .review,
                          exceptions: ["Library/Application Support/MobileSync/Backup"])
        _ = await engine.clean([backup], mode: .smart) { _ in }
        #expect(remover.calls == [.trash("0000")])
    }

    // MARK: Failures and cancellation

    @Test func failureDoesNotStopTheBatch() async {
        let remover = RecordingRemover(failing: ["a"], missing: ["b"])
        let engine = CleanEngine(home: home.url, remover: remover)
        let items = ["a", "b", "c"].map { item(home.path("Library/Caches/\($0)")) }
        let report = await engine.clean(items, mode: .smart) { _ in }

        #expect(remover.calls == [.remove("a"), .remove("c")])
        #expect(report.deletedCount == 1)
        #expect(report.failures.count == 2)
        #expect(report.failures[1].message.contains("no longer exists"))
    }

    @Test func cancelledBeforeStartRemovesNothing() async {
        let remover = RecordingRemover()
        let engine = CleanEngine(home: home.url, remover: remover)
        let items = ["a", "b"].map { item(home.path("Library/Caches/\($0)")) }
        let report = await Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return await engine.clean(items, mode: .smart) { _ in }
        }.value
        #expect(remover.calls.isEmpty)
        #expect(report.deletedCount == 0)
    }

    @Test func cancellingMidwayStopsBeforeNextItem() async {
        let remover = RecordingRemover(onCall: { withUnsafeCurrentTask { $0?.cancel() } })
        let engine = CleanEngine(home: home.url, remover: remover)
        let items = ["a", "b", "c"].map { item(home.path("Library/Caches/\($0)")) }
        let report = await Task { await engine.clean(items, mode: .smart) { _ in } }.value
        #expect(remover.calls == [.remove("a")])
        #expect(report.deletedCount == 1)
    }
}

/// Minimal lock box for collecting values from `@Sendable` closures.
final class Mutex<Value>: @unchecked Sendable {
    private var value: Value
    private let lock = NSLock()
    init(_ value: Value) { self.value = value }
    func withLock<R>(_ body: (inout Value) -> R) -> R { lock.withLock { body(&value) } }
}
