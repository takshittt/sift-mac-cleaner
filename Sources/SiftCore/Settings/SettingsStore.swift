import Foundation
import Observation

/// User settings backed by `UserDefaults`. Observable so views update on change.
@MainActor @Observable
public final class SettingsStore: SettingsStoring {
    enum Key {
        static let mode = "mode"
        static let enabledProfiles = "enabledProfiles"
        static let detectedProfiles = "detectedProfiles"
        static let lifetimeFreed = "lifetimeFreed"
        static let ruleOverrides = "ruleOverrides"
        static let hasCompletedOnboarding = "hasCompletedOnboarding"
    }

    @ObservationIgnored private let defaults: UserDefaults

    public var mode: DeletionMode {
        didSet { defaults.set(mode.rawValue, forKey: Key.mode) }
    }
    public var enabledProfiles: Set<Profile> {
        didSet { defaults.set(enabledProfiles.map(\.rawValue).sorted(), forKey: Key.enabledProfiles) }
    }
    public var detectedProfiles: Set<Profile> {
        didSet { defaults.set(detectedProfiles.map(\.rawValue).sorted(), forKey: Key.detectedProfiles) }
    }
    public var lifetimeFreed: Int64 {
        didSet { defaults.set(lifetimeFreed, forKey: Key.lifetimeFreed) }
    }
    public var ruleOverrides: [String: Bool] {
        didSet { defaults.set(ruleOverrides, forKey: Key.ruleOverrides) }
    }
    public var hasCompletedOnboarding: Bool {
        didSet { defaults.set(hasCompletedOnboarding, forKey: Key.hasCompletedOnboarding) }
    }

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        mode = defaults.string(forKey: Key.mode).flatMap(DeletionMode.init) ?? .smart
        enabledProfiles = Self.profiles(defaults, Key.enabledProfiles) ?? [.general]
        detectedProfiles = Self.profiles(defaults, Key.detectedProfiles) ?? []
        lifetimeFreed = (defaults.object(forKey: Key.lifetimeFreed) as? NSNumber)?.int64Value ?? 0
        ruleOverrides = defaults.dictionary(forKey: Key.ruleOverrides) as? [String: Bool] ?? [:]
        hasCompletedOnboarding = defaults.bool(forKey: Key.hasCompletedOnboarding)
    }

    /// Back to the recommended setup: Smart mode, detected profiles, no per-rule overrides.
    public func resetToRecommended() {
        mode = .smart
        enabledProfiles = detectedProfiles.isEmpty ? [.general] : detectedProfiles.union([.general])
        ruleOverrides = [:]
    }

    /// Whether a rule's items are preselected, after the user's override.
    public func isOn(_ rule: Rule) -> Bool {
        ruleOverrides[rule.id] ?? rule.defaultOn
    }

    private static func profiles(_ defaults: UserDefaults, _ key: String) -> Set<Profile>? {
        (defaults.stringArray(forKey: key)).map { Set($0.compactMap(Profile.init)) }
    }
}
