import Foundation

/// Walks folders under home and keeps files that match a test.
///
/// Doesn't look inside packages (.app, .photoslibrary, …), hidden folders or
/// dependency folders, and stops at `maxDepth` so a huge Documents folder
/// stays quick to scan.
public struct FileSearchFinder: ItemFinder {
    public typealias Match = @Sendable (_ url: URL, _ values: URLResourceValues, _ context: ScanContext) -> Candidate?

    let roots: [String]
    let maxDepth: Int
    let match: Match

    /// Folders never worth walking into for user files.
    static let skippedFolders: Set<String> = ["node_modules", ".git", "Pods", "DerivedData", ".build"]

    static let keys: [URLResourceKey] = [.isRegularFileKey, .isDirectoryKey, .isPackageKey, .fileSizeKey,
                                         .contentModificationDateKey, .addedToDirectoryDateKey]

    public init(roots: [String], maxDepth: Int, match: @escaping Match) {
        self.roots = roots
        self.maxDepth = maxDepth
        self.match = match
    }

    public func candidates(in context: ScanContext) async throws -> FinderResult {
        var result = FinderResult()
        for root in roots {
            let folder = context.home.appending(path: root)
            guard let enumerator = FileManager.default.enumerator(
                at: folder, includingPropertiesForKeys: Self.keys,
                options: [.skipsHiddenFiles, .skipsPackageDescendants],
                errorHandler: { _, error in
                    if SizeCalc.isPermissionError(error) { result.denied = true }
                    return true
                })
            else { continue }

            var seen = 0
            while let url = enumerator.nextObject() as? URL {
                seen += 1
                if seen % 500 == 0, Task.isCancelled { break }
                guard let values = try? url.resourceValues(forKeys: Set(Self.keys)) else { continue }
                if values.isDirectory == true, values.isPackage != true {
                    if enumerator.level >= maxDepth || Self.skippedFolders.contains(url.lastPathComponent) {
                        enumerator.skipDescendants()
                    }
                    continue
                }
                if let candidate = match(url, values, context) { result.candidates.append(candidate) }
            }
        }
        return result
    }

    /// The last time the user did anything with an item: changed it, opened it,
    /// or put it in this folder. "Opened" comes from Spotlight's last-used date,
    /// not the file's access time, which background indexing and backups bump.
    /// The added date matters for downloads, which keep the server's modification date.
    @Sendable public static func lastUsed(_ url: URL, _ values: URLResourceValues) -> Date? {
        let opened = NSMetadataItem(url: url)?.value(forAttribute: "kMDItemLastUsedDate") as? Date
        return [values.contentModificationDate, values.addedToDirectoryDate, opened]
            .compactMap { $0 }.max()
    }
}

/// Top-level items in a folder that haven't been used for a while.
public struct UnusedItemsFinder: ItemFinder {
    public typealias LastUsed = @Sendable (URL, URLResourceValues) -> Date?

    let folder: String
    let days: Int
    let lastUsed: LastUsed

    public init(folder: String, days: Int, lastUsed: @escaping LastUsed = FileSearchFinder.lastUsed) {
        self.folder = folder
        self.days = days
        self.lastUsed = lastUsed
    }

    public func candidates(in context: ScanContext) async throws -> FinderResult {
        let cutoff = context.now.addingTimeInterval(-Double(days) * 86_400)
        let url = context.home.appending(path: folder)
        let entries: [URL]
        do {
            entries = try FileManager.default.contentsOfDirectory(
                at: url, includingPropertiesForKeys: FileSearchFinder.keys, options: [.skipsHiddenFiles])
        } catch {
            return FinderResult(denied: SizeCalc.isPermissionError(error))
        }
        let formatter = RelativeDateTimeFormatter()
        var result = FinderResult()
        for entry in entries {
            guard let values = try? entry.resourceValues(forKeys: Set(FileSearchFinder.keys)),
                  let last = lastUsed(entry, values), last < cutoff
            else { continue }
            result.candidates.append(Candidate(
                url: entry, detail: "Last used \(formatter.localizedString(for: last, relativeTo: context.now))"))
        }
        return result
    }
}

/// iPhone and iPad backups made by Finder, one item per device backup.
public struct DeviceBackupFinder: ItemFinder {
    static let folder = "Library/Application Support/MobileSync/Backup"

    public init() {}

    public func candidates(in context: ScanContext) async throws -> FinderResult {
        let url = context.home.appending(path: Self.folder)
        let entries: [URL]
        do {
            entries = try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil,
                                                                  options: [.skipsHiddenFiles])
        } catch {
            return FinderResult(denied: SizeCalc.isPermissionError(error))
        }
        return FinderResult(entries.map { backup in
            let info = Self.info(backup)
            let name = info?["Device Name"] as? String ?? info?["Display Name"] as? String ?? backup.lastPathComponent
            let date = (info?["Last Backup Date"] as? Date).map {
                "Last backed up " + $0.formatted(date: .abbreviated, time: .omitted)
            }
            return Candidate(url: backup, name: name, detail: date)
        })
    }

    static func info(_ backup: URL) -> [String: Any]? {
        guard let data = try? Data(contentsOf: backup.appending(path: "Info.plist")) else { return nil }
        return try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
    }
}
