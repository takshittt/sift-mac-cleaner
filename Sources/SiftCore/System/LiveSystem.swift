import AppKit
import Foundation

/// Disk figures and Full Disk Access status for the real Mac.
public struct LiveSystemInfo: SystemInfo {
    let home: URL

    public init(home: URL = FileManager.default.homeDirectoryForCurrentUser) {
        self.home = home
    }

    public func disk() -> DiskInfo { DiskInfo.current(for: home) }

    /// macOS only lets apps with Full Disk Access list ~/Library/Safari.
    public func hasFullDiskAccess() -> Bool {
        (try? FileManager.default.contentsOfDirectory(
            atPath: home.appending(path: "Library/Safari").path(percentEncoded: false))) != nil
    }

    public func openFullDiskAccessSettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")!
        DispatchQueue.main.async { NSWorkspace.shared.open(url) }
    }
}

extension Engine {
    /// The real engine: scans and cleans the current user's home folder.
    public static func live(home: URL = FileManager.default.homeDirectoryForCurrentUser) -> Engine {
        let apps = LiveAppIndex(home: home)
        let system = LiveSystemInfo(home: home)
        return Engine(scanner: ScanEngine(rules: RuleCatalog.all, home: home, apps: apps, system: system),
                      cleaner: CleanEngine(home: home), apps: apps, system: system)
    }
}
