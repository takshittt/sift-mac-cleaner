import Foundation

/// Installed and running apps at the moment a scan starts. All values lowercased.
public struct AppSnapshot: Sendable {
    public var installedIDs: Set<String>
    public var runningIDs: Set<String>
    /// App file names without `.app`.
    public var installedNames: Set<String>

    public init(installedIDs: Set<String> = [], runningIDs: Set<String> = [], installedNames: Set<String> = []) {
        self.installedIDs = Set(installedIDs.map { $0.lowercased() })
        self.runningIDs = Set(runningIDs.map { $0.lowercased() })
        self.installedNames = Set(installedNames.map { $0.lowercased() })
    }

    /// True if `id` or the app it belongs to (`com.x.app.helper` → `com.x.app`) is running.
    public func isRunning(_ id: String) -> Bool {
        let id = id.lowercased()
        return runningIDs.contains { id == $0 || id.hasPrefix($0 + ".") }
    }

    public static let empty = AppSnapshot()
}

/// Everything a finder may depend on. Injected so tests never see the real home folder.
public struct ScanContext: Sendable {
    public let home: URL
    public let now: Date
    public let apps: AppSnapshot
    public let enabledProfiles: Set<Profile>

    public init(home: URL, now: Date = .now, apps: AppSnapshot = .empty,
                enabledProfiles: Set<Profile> = Set(Profile.allCases)) {
        self.home = home
        self.now = now
        self.apps = apps
        self.enabledProfiles = enabledProfiles
    }
}

/// Storage figures for the disk gauge.
public struct DiskInfo: Sendable, Equatable {
    public let total: Int64
    public let free: Int64
    public var used: Int64 { total - free }

    public init(total: Int64, free: Int64) {
        self.total = total
        self.free = free
    }

    /// Reads the volume that holds `url` (the home folder by default).
    public static func current(for url: URL = FileManager.default.homeDirectoryForCurrentUser) -> DiskInfo {
        let values = try? url.resourceValues(forKeys: [.volumeTotalCapacityKey,
                                                       .volumeAvailableCapacityForImportantUsageKey])
        return DiskInfo(total: Int64(values?.volumeTotalCapacity ?? 0),
                        free: values?.volumeAvailableCapacityForImportantUsage ?? 0)
    }
}
