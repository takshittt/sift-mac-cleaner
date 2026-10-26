import Foundation

/// `node_modules` folders in projects nobody has touched for a while (spec §8.6).
///
/// A project's age is the newest modification among its own files (two levels
/// deep, `node_modules` excluded), so editing any source file keeps it fresh.
public struct StaleNodeModulesFinder: ItemFinder {
    let roots: [String]
    let days: Int
    let maxDepth: Int

    public init(roots: [String], days: Int, maxDepth: Int = 5) {
        self.roots = roots
        self.days = days
        self.maxDepth = maxDepth
    }

    public func candidates(in context: ScanContext) async throws -> FinderResult {
        let cutoff = context.now.addingTimeInterval(-Double(days) * 86_400)
        let formatter = RelativeDateTimeFormatter()
        var result = FinderResult()
        var seenProjects = Set<String>()

        for root in roots {
            let folder = context.home.appending(path: root)
            guard let walker = FileManager.default.enumerator(
                at: folder, includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles, .skipsPackageDescendants],
                errorHandler: { _, error in
                    if SizeCalc.isPermissionError(error) { result.denied = true }
                    return true
                })
            else { continue }

            var seen = 0
            while let url = walker.nextObject() as? URL {
                seen += 1
                if seen % 500 == 0, Task.isCancelled { break }
                guard (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true else { continue }
                let name = url.lastPathComponent
                if name == "node_modules" {
                    walker.skipDescendants()
                    let project = url.deletingLastPathComponent()
                    // Roots can overlap (e.g. ~/Documents/GitHub and ~/GitHub via a link).
                    guard seenProjects.insert(ScanEngine.key(project)).inserted,
                          let newest = Self.newestChange(in: project), newest < cutoff
                    else { continue }
                    result.candidates.append(Candidate(
                        url: url, name: project.lastPathComponent,
                        detail: "Project last changed \(formatter.localizedString(for: newest, relativeTo: context.now))"))
                } else if walker.level >= maxDepth || FileSearchFinder.skippedFolders.contains(name) {
                    walker.skipDescendants()
                }
            }
        }
        return result
    }

    /// Newest modification date of the project folder and its files, two levels
    /// deep, ignoring `node_modules` and hidden files.
    static func newestChange(in project: URL) -> Date? {
        var newest = (try? project.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
        guard let walker = FileManager.default.enumerator(
            at: project, includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants])
        else { return newest }
        while let url = walker.nextObject() as? URL {
            if url.lastPathComponent == "node_modules" { walker.skipDescendants(); continue }
            if walker.level >= 2 { walker.skipDescendants() }
            if let date = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate,
               date > (newest ?? .distantPast) {
                newest = date
            }
        }
        return newest
    }
}
