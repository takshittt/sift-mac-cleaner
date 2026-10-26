import Foundation
import Observation
import SiftCore

/// The only object views mutate. Owns the scan/clean lifecycle and the selection.
@MainActor @Observable
public final class AppState {
    /// Set to true while developing to send every clean to the Trash (except
    /// emptying the Trash itself), whatever the setting says, so any mistake
    /// can be undone. Off in shipping builds: the user's deletion mode applies.
    public static let developmentForcesTrash = false

    public internal(set) var phase: Phase = .idle
    public internal(set) var categories: [CleanCategory] = []
    public var selection: Set<CleanItem.ID> = []
    public var collapsedGroups: Set<String> = []
    public internal(set) var report: CleanReport?
    public var showConfirm = false
    public internal(set) var showProfilePicker = false
    public var showSafetyInfo = false
    @ObservationIgnored private var profilesWhenPickerOpened: Set<Profile> = []
    public internal(set) var fullDiskAccess = true
    public internal(set) var disk = DiskInfo(total: 0, free: 0)
    public internal(set) var currentRule = ""

    public let settings: SettingsStore
    @ObservationIgnored private let engine: Engine
    @ObservationIgnored private var scanTask: Task<Void, Never>?

    public init(engine: Engine, settings: SettingsStore) {
        self.engine = engine
        self.settings = settings
    }

    // MARK: Derived

    public var allItems: [CleanItem] { categories.flatMap(\.items) }
    public var foundBytes: Int64 { allItems.reduce(0) { $0 + $1.size } }
    public var selectedItems: [CleanItem] { allItems.filter { selection.contains($0.id) } }
    public var selectedBytes: Int64 { selectedItems.reduce(0) { $0 + $1.size } }
    public var selectionHasReviewItems: Bool { selectedItems.contains { $0.risk == .review } }

    /// The mode a clean will actually use.
    public var effectiveMode: DeletionMode {
        Self.developmentForcesTrash ? .trash : settings.mode
    }

    public struct Plan: Equatable, Sendable {
        public var permanentCount = 0, permanentBytes: Int64 = 0
        public var trashCount = 0, trashBytes: Int64 = 0
    }

    /// What pressing Clean will do with the current selection, for the confirm sheet.
    public var plan: Plan {
        var plan = Plan()
        for item in selectedItems {
            switch CleanEngine.disposal(for: item, mode: effectiveMode) {
            case .permanent:
                plan.permanentCount += 1
                plan.permanentBytes += item.size
            case .trash:
                plan.trashCount += 1
                plan.trashBytes += item.size
            }
        }
        return plan
    }

    public func categories(in section: SectionKind) -> [CleanCategory] {
        categories.filter { $0.rule.section == section }
    }

    public func total(of section: SectionKind) -> Int64 {
        categories(in: section).reduce(0) { $0 + $1.total }
    }

    public var isBusy: Bool {
        switch phase {
        case .scanning, .cleaning: true
        default: false
        }
    }

    // MARK: Lifecycle

    public func onLaunch() async {
        let detected = await engine.apps.detectProfiles()
        settings.detectedProfiles = detected
        if !settings.hasCompletedOnboarding {
            settings.enabledProfiles = detected.union([.general])
            settings.hasCompletedOnboarding = true
            openProfilePicker()
        }
        disk = engine.system.disk()
        fullDiskAccess = engine.system.hasFullDiskAccess()
        scan()
    }

    public func scan() {
        scanTask?.cancel()
        categories = []
        selection = []
        phase = .scanning(progress: 0)
        currentRule = ""
        let stream = engine.scanner.scan(profiles: settings.enabledProfiles)
        scanTask = Task {
            do {
                for try await event in stream {
                    switch event {
                    case .progress(let value, let rule):
                        phase = .scanning(progress: value)
                        currentRule = rule
                    case .category(let category):
                        guard !category.items.isEmpty || category.needsFDA else { continue }
                        categories.append(category)
                        selectRecommended(in: category)
                    case .finished(let fda):
                        fullDiskAccess = fda
                    }
                }
                phase = .ready
            } catch {
                if !Task.isCancelled { phase = .ready }
            }
        }
    }

    /// Waits for the current scan to finish. For tests and scripted flows.
    public func waitForScan() async {
        await scanTask?.value
    }

    public func cancelScan() {
        scanTask?.cancel()
        phase = .ready
    }

    public func openFullDiskAccessSettings() {
        engine.system.openFullDiskAccessSettings()
    }

    // MARK: Profiles

    public func openProfilePicker() {
        profilesWhenPickerOpened = settings.enabledProfiles
        showProfilePicker = true
    }

    /// Everyday use stays on: it's what the app is for.
    public func setProfile(_ profile: Profile, enabled: Bool) {
        guard profile != .general else { return }
        if enabled { settings.enabledProfiles.insert(profile) } else { settings.enabledProfiles.remove(profile) }
    }

    /// Closes the picker and rescans if the choice changed.
    public func closeProfilePicker() {
        showProfilePicker = false
        if settings.enabledProfiles != profilesWhenPickerOpened, !isCleaning { scan() }
    }

    // MARK: Settings

    /// Whether a green rule's items are ticked after a scan. Stores an override
    /// only when it differs from the rule's default. Applies on the next scan.
    public func setRule(_ rule: Rule, on: Bool) {
        if on == rule.defaultOn {
            settings.ruleOverrides[rule.id] = nil
        } else {
            settings.ruleOverrides[rule.id] = on
        }
    }

    /// Back to Smart mode, detected areas and default rules, then rescans.
    public func resetToRecommended() {
        settings.resetToRecommended()
        if !isBusy { scan() }
    }

    var isCleaning: Bool {
        if case .cleaning = phase { true } else { false }
    }

    // MARK: Selection

    /// Only green items whose rule is on and whose app isn't running are ticked for the user.
    public nonisolated static func isRecommended(_ item: CleanItem, ruleOn: Bool) -> Bool {
        item.risk == .safe && ruleOn && !item.isRunningApp
    }

    public func selectRecommended() {
        selection = []
        categories.forEach(selectRecommended(in:))
    }

    private func selectRecommended(in category: CleanCategory) {
        let on = settings.isOn(category.rule)
        for item in category.items where Self.isRecommended(item, ruleOn: on) {
            selection.insert(item.id)
        }
    }

    public func toggle(_ id: CleanItem.ID) {
        if selection.contains(id) { selection.remove(id) } else { selection.insert(id) }
    }

    public enum CheckState: Sendable { case none, some, all }

    public func checkState(of items: [CleanItem]) -> CheckState {
        let picked = items.filter { selection.contains($0.id) }.count
        return picked == 0 ? .none : picked == items.count ? .all : .some
    }

    /// Ticks every item, or clears them if all are already ticked.
    public func toggleAll(_ items: [CleanItem]) {
        if checkState(of: items) == .all {
            items.forEach { selection.remove($0.id) }
        } else {
            items.forEach { selection.insert($0.id) }
        }
    }

    public func toggleCollapsed(_ group: String) {
        if collapsedGroups.contains(group) { collapsedGroups.remove(group) } else { collapsedGroups.insert(group) }
    }

    // MARK: Cleaning

    public func requestClean() {
        guard !selection.isEmpty, !isBusy else { return }
        showConfirm = true
    }

    public func clean() async {
        showConfirm = false
        let items = selectedItems
        guard !items.isEmpty else { return }
        phase = .cleaning(progress: 0)
        let result = await engine.cleaner.clean(items, mode: effectiveMode) { [weak self] value in
            Task { @MainActor in
                // A late update must not pull the UI back out of `.done`.
                guard let self, case .cleaning = self.phase else { return }
                self.phase = .cleaning(progress: value)
            }
        }
        settings.lifetimeFreed += result.deletedBytes
        report = result
        disk = engine.system.disk()
        phase = .done
    }

    /// Closes the report and scans again so the lists reflect what's left.
    public func dismissReport() {
        report = nil
        scan()
    }
}
