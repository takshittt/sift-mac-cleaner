import Foundation
import Testing
@testable import SiftCore
@testable import SiftAppModel

@MainActor
@Suite(.serialized) struct AppStateTests {
    let defaults: UserDefaults

    init() throws {
        defaults = try #require(UserDefaults(suiteName: testDefaultsSuite))
        defaults.removePersistentDomain(forName: testDefaultsSuite)
    }

    /// A launched state on fake data (profiles: general + developer).
    private func launched(_ configure: (SettingsStore) -> Void = { _ in }) async -> AppState {
        let settings = SettingsStore(defaults: defaults)
        configure(settings)
        let state = AppState(engine: .fake(delay: .zero), settings: settings)
        await state.onLaunch()
        await state.waitForScan()
        return state
    }

    private func names(_ state: AppState) -> Set<String> {
        Set(state.selectedItems.map(\.name))
    }

    @Test func firstLaunchEnablesDetectedProfiles() async {
        let state = await launched()
        #expect(state.settings.enabledProfiles == [.general, .developer])
        #expect(state.settings.hasCompletedOnboarding)
        #expect(state.phase == .ready)
        #expect(!state.categories.contains { $0.rule.profile == .localAI })
    }

    @Test func preselectsOnlySafeItemsOfAppsNotRunning() async {
        let state = await launched()
        #expect(names(state) == ["com.spotify.client", "com.microsoft.VSCode", "Chrome", "com.apple.Safari",
                                 "JetBrains", "MyApp-abc"])
        #expect(state.selectedItems.allSatisfy { $0.risk == .safe && !$0.isRunningApp })
    }

    @Test func ruleOverrideTurnsOffPreselection() async {
        let state = await launched { $0.ruleOverrides = ["logs": false] }
        #expect(!names(state).contains("JetBrains"))
    }

    @Test func reviewItemsTriggerTheWarning() async throws {
        let state = await launched()
        #expect(!state.selectionHasReviewItems)
        let orphan = try #require(state.allItems.first { $0.risk == .review })
        state.toggle(orphan.id)
        #expect(state.selectionHasReviewItems)
    }

    @Test func checkStateAndToggleAll() async throws {
        let state = await launched()
        let caches = try #require(state.categories.first { $0.rule.id == "appCaches" }).items
        #expect(state.checkState(of: caches) == .some)   // Slack is running, so unticked
        state.toggleAll(caches)
        #expect(state.checkState(of: caches) == .all)
        state.toggleAll(caches)
        #expect(state.checkState(of: caches) == .none)
    }

    @Test func planMatchesTheCleanEngine() async {
        let state = await launched()
        let plan = state.plan
        #expect(plan.permanentCount + plan.trashCount == state.selection.count)
        #expect(plan.permanentBytes + plan.trashBytes == state.selectedBytes)
        if AppState.developmentForcesTrash {
            #expect(plan.permanentCount == 0)   // nothing selected by default is force-permanent
        }
    }

    @Test func requestCleanNeedsASelection() async {
        let state = await launched()
        state.selection = []
        state.requestClean()
        #expect(!state.showConfirm)
    }

    @Test func cleanReportsThenRescans() async throws {
        let state = await launched()
        let selected = state.selection.count
        state.requestClean()
        #expect(state.showConfirm)

        await state.clean()
        #expect(!state.showConfirm)
        #expect(state.phase == .done)
        let report = try #require(state.report)
        #expect(report.deletedCount + report.trashedCount == selected)
        #expect(state.settings.lifetimeFreed == report.deletedBytes)

        state.dismissReport()
        #expect(state.report == nil)
        await state.waitForScan()
        #expect(state.phase == .ready)
    }

    @Test func setRuleStoresOnlyRealOverrides() async throws {
        let state = await launched()
        let logs = try #require(RuleCatalog.rule(id: "logs"))
        state.setRule(logs, on: !logs.defaultOn)
        #expect(state.settings.ruleOverrides == ["logs": !logs.defaultOn])
        state.setRule(logs, on: logs.defaultOn)
        #expect(state.settings.ruleOverrides.isEmpty)
    }

    @Test func resetToRecommendedRestoresDefaultsAndRescans() async throws {
        let state = await launched()
        let logs = try #require(RuleCatalog.rule(id: "logs"))
        state.settings.mode = .permanent
        state.setProfile(.localAI, enabled: true)
        state.setRule(logs, on: false)

        state.resetToRecommended()
        #expect(state.settings.mode == .smart)
        #expect(state.settings.enabledProfiles == [.general, .developer])
        #expect(state.settings.ruleOverrides.isEmpty)
        await state.waitForScan()
        #expect(names(state).contains("JetBrains"))   // logs ticked again
    }

    @Test func groupsCollapseAndExpand() async {
        let state = await launched()
        state.toggleCollapsed("appCaches/Slack")
        #expect(state.collapsedGroups.contains("appCaches/Slack"))
        state.toggleCollapsed("appCaches/Slack")
        #expect(state.collapsedGroups.isEmpty)
    }
}

/// The real scanner and clean engine wired through AppState, on a fixture home.
/// A recording remover stands in for the disk so nothing reaches the real Trash.
@MainActor
@Suite(.serialized) struct LiveWiringTests {
    @Test func scanSelectCleanOnFixtureHome() async throws {
        let home = try FakeHome()
        try home.file("Library/Caches/com.spotify.client/data", bytes: 50_000)
        try home.file("Library/Caches/com.tinyspeck.slackmacgap/data", bytes: 50_000)
        try home.file("Library/Logs/JetBrains/idea.log", bytes: 50_000)
        try home.file(".Trash/old.zip", bytes: 50_000)
        try home.file("\(RuleCatalog.mailDownloadsPath)/x/invoice.pdf", bytes: 50_000)

        let apps = StubApps(running: ["com.tinyspeck.slackmacgap"])
        let remover = RecordingRemover()
        let engine = Engine(scanner: ScanEngine(rules: RuleCatalog.all, home: home.url, apps: apps, system: StubSystem()),
                            cleaner: CleanEngine(home: home.url, remover: remover),
                            apps: apps, system: StubSystem())
        let suite = testDefaultsSuite + ".wiring"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defaults.removePersistentDomain(forName: suite)
        let state = AppState(engine: engine, settings: SettingsStore(defaults: defaults))

        await state.onLaunch()
        await state.waitForScan()

        // Green, not running: Spotify cache, JetBrains logs, the Trash. Not Slack (running), not Mail (caution).
        #expect(Set(state.selectedItems.map(\.name)) == ["com.spotify.client", "JetBrains", "old.zip"])

        await state.clean()
        let report = try #require(state.report)
        let expected: [RecordingRemover.Call] = AppState.developmentForcesTrash
            ? [.trash("com.spotify.client"), .trash("JetBrains"), .remove("old.zip")]
            : [.remove("com.spotify.client"), .remove("JetBrains"), .remove("old.zip")]
        #expect(Set(remover.calls.map { "\($0)" }) == Set(expected.map { "\($0)" }))
        #expect(report.failures.isEmpty)
        #expect(report.deletedCount + report.trashedCount == 3)
        #expect(state.settings.lifetimeFreed == report.deletedBytes)
    }
}
