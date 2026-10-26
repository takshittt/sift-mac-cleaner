import Foundation

/// The filesystem operations cleaning needs. Swapped for a recorder in tests.
public protocol FileRemoving: Sendable {
    /// True if something exists at `url`, without following a final symlink.
    func exists(_ url: URL) -> Bool
    func remove(_ url: URL) throws
    func trash(_ url: URL) throws
}

public struct LiveFileRemover: FileRemoving {
    public init() {}

    public func exists(_ url: URL) -> Bool {
        (try? FileManager.default.attributesOfItem(atPath: url.path(percentEncoded: false))) != nil
    }

    public func remove(_ url: URL) throws {
        try FileManager.default.removeItem(at: url)
    }

    public func trash(_ url: URL) throws {
        try FileManager.default.trashItem(at: url, resultingItemURL: nil)
    }
}

/// Removes items. The only code in Sift that deletes or trashes files, and it
/// re-checks every item with `SafetyGuard` immediately before acting.
public actor CleanEngine: Cleaning {
    private let home: URL
    private let remover: any FileRemoving

    public init(home: URL = FileManager.default.homeDirectoryForCurrentUser,
                remover: any FileRemoving = LiveFileRemover()) {
        self.home = home
        self.remover = remover
    }

    /// Smart mode deletes regenerable items for real (trashing them frees nothing)
    /// and sends anything that might hold user data to the Trash.
    public nonisolated static func disposal(for item: CleanItem, mode: DeletionMode) -> Disposal {
        if item.forcePermanent { return .permanent }
        switch mode {
        case .permanent: return .permanent
        case .trash: return .trash
        case .smart: return item.risk == .safe ? item.disposal : .trash
        }
    }

    /// Processes items one by one. A failure never stops the batch; cancelling
    /// the calling task stops before the next item.
    public func clean(_ items: [CleanItem], mode: DeletionMode,
                      progress: @escaping @Sendable (Double) -> Void) async -> CleanReport {
        var report = CleanReport()
        for (index, item) in items.enumerated() {
            if Task.isCancelled { break }
            defer { progress(Double(index + 1) / Double(items.count)) }

            // Every file of the item must pass before any of them is touched.
            var urls: [URL] = []
            var violation: Violation?
            for url in item.allURLs {
                switch SafetyGuard.validate(url, home: home, exceptions: item.safetyExceptions) {
                case .success(let checked): urls.append(checked)
                case .failure(let v): violation = violation ?? v
                }
            }
            if let violation {
                report.failures.append(.init(item: item, message: violation.message))
                continue
            }

            guard remover.exists(urls[0]) else {
                report.failures.append(.init(item: item, message: "\(item.name), which no longer exists"))
                continue
            }

            let disposal = Self.disposal(for: item, mode: mode)
            do {
                // Main file first (e.g. a model's manifest), so a half-finished
                // removal never leaves an entry that points at missing data.
                for url in urls where url == urls[0] || remover.exists(url) {
                    switch disposal {
                    case .permanent: try remover.remove(url)
                    case .trash: try remover.trash(url)
                    }
                }
                switch disposal {
                case .permanent:
                    report.deletedCount += 1
                    report.deletedBytes += item.size
                case .trash:
                    report.trashedCount += 1
                    report.trashedBytes += item.size
                }
            } catch {
                report.failures.append(.init(item: item, message: error.localizedDescription))
            }
        }
        if items.isEmpty { progress(1) }
        return report
    }
}
