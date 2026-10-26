import Foundation

// The contract between the frontend and SiftCore. The app depends only on these.

public enum ScanEvent: Sendable {
    case progress(Double, currentRule: String)
    case category(CleanCategory)
    case finished(fullDiskAccess: Bool)
}

public protocol Scanning: Sendable {
    /// Streams per-category results as they complete. Cancel the consuming task to stop.
    func scan(profiles: Set<Profile>) -> AsyncThrowingStream<ScanEvent, Error>
}

public protocol Cleaning: Sendable {
    func clean(_ items: [CleanItem], mode: DeletionMode,
               progress: @escaping @Sendable (Double) -> Void) async -> CleanReport
}

public protocol AppIndexing: Sendable {
    func snapshot() async -> AppSnapshot
    func detectProfiles() async -> Set<Profile>
}

public protocol SystemInfo: Sendable {
    func disk() -> DiskInfo
    func hasFullDiskAccess() -> Bool
    func openFullDiskAccessSettings()
}

@MainActor
public protocol SettingsStoring: AnyObject {
    var mode: DeletionMode { get set }
    var enabledProfiles: Set<Profile> { get set }
    var detectedProfiles: Set<Profile> { get set }
    var lifetimeFreed: Int64 { get set }
    var ruleOverrides: [String: Bool] { get set }
    var hasCompletedOnboarding: Bool { get set }
    func resetToRecommended()
}

/// Composition root handed to the frontend.
public struct Engine: Sendable {
    public let scanner: any Scanning
    public let cleaner: any Cleaning
    public let apps: any AppIndexing
    public let system: any SystemInfo

    public init(scanner: any Scanning, cleaner: any Cleaning,
                apps: any AppIndexing, system: any SystemInfo) {
        self.scanner = scanner
        self.cleaner = cleaner
        self.apps = apps
        self.system = system
    }
}
